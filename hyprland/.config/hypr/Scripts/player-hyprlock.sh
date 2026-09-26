#!/usr/bin/env bash
# Media player card for the hyprlock lock screen.
#
# hyprlock has no player widget, so the card is put together from plain widgets
# that all call this script with the part they show. Asking playerctl takes too
# long to do from a widget (see hyprlock-daemon.sh), so the work is split:
#
#   --daemon   follows the player and writes what the card shows to a state
#              file under $XDG_RUNTIME_DIR: at once on every change (play/pause,
#              track, shuffle, repeat), and every second besides, for the
#              progress bar. It also renders the card image -- the background
#              with the album art on its top edge -- when the art or the theme
#              changes, and keeps the old one up while it does.
#   card       reload_cmd of the image widget: prints that image, or a
#              transparent PNG when nothing is playing -- the only way to hide
#              the card, since hyprlock cannot hide a shape.
#   title, artist, controls, progress
#              label text, empty when nothing is playing. controls is the whole
#              button row -- shuffle, previous, play/pause, next, repeat -- in one
#              label, since every widget command costs hyprlock's main thread
#              time; the buttons' click targets are invisible static labels
#              over it. Shuffle and repeat are left blank for players that do
#              not support them, browsers among them, so the card never shows a
#              button that does nothing.
#   ctl ARGS   onclick of the buttons: playerctl ARGS, for the card's player.
#   loop-cycle onclick of repeat: None -> Playlist -> Track -> None.
#
# All but --daemon only read the state file, starting the daemon first if it is
# not up yet. Card geometry here has to match the widget positions in
# hyprlock.conf.

set -u

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/hyprlock-player"
COLORS="$HOME/.config/hypr/colors.conf"
EMPTY="$CACHE/empty.png"
STATE="${XDG_RUNTIME_DIR:-/tmp}/hyprlock-player"
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/hyprlock-player.pid"
# Fields are split on a unit separator, which no title or URL will contain.
US=$'\x1f'

# Card geometry, in pixels. The art is centered on the card's top edge, so the
# image is ART/2 taller than the card itself.
CARD_W=300
CARD_H=176
CARD_R=20
ART=110
ART_BORDER=4
ART_R=16
# Bumped whenever the look of the rendered card changes, so cached cards are
# not reused across such a change.
CARD_REV=4

. "${0%/*}/hyprlock-daemon.sh"

visible() {
    [[ $1 == Playing || $1 == Paused ]]
}

# Label text is pango markup, so titles like "Tom & Jerry" would otherwise
# break the whole label. The replacements are quoted because bash 5.2 expands
# an unquoted & in them to the matched text.
escape() {
    local s=$1
    s=${s//&/"&amp;"}
    s=${s//</"&lt;"}
    s=${s//>/"&gt;"}
    printf '%s' "$s"
}

# Cut before escaping, so an entity is never cut in half.
clip() {
    local s=$1 max=$2
    (( ${#s} > max )) && s="${s:0:max-1}…"
    escape "$s"
}

# duration VAR MICROSECONDS [long] -- sets VAR to m:ss, or to h:mm:ss for an
# hour or more or when "long" is given. printf -v rather than printing, so the
# progress label needs no subshells.
duration() {
    local s=$(( ${2:-0} / 1000000 ))
    if (( s >= 3600 )) || [[ ${3-} == long ]]; then
        printf -v "$1" '%d:%02d:%02d' $(( s / 3600 )) $(( s % 3600 / 60 )) $(( s % 60 ))
    else
        printf -v "$1" '%d:%02d' $(( s / 60 )) $(( s % 60 ))
    fi
}

# Theme colors as bare hex, read from the file hyprlock.conf sources, so the
# card follows ~/.config/theme like the rest of the lock screen.
declare -A C=(
    [text]=cdd6f4 [subtext0]=a6adc8 [overlay0]=6c7086
    [surface1]=45475a [surface2]=585b70 [base]=1e1e2e [accent]=cba6f7
)
load_colors() {
    local name eq val
    [[ -r $COLORS ]] || return 0
    while read -r name eq val; do
        [[ $name == \$* && $val == rgb\(*\) ]] || continue
        val=${val#rgb(}
        C[${name#\$}]=${val%)}
    done < "$COLORS"
}

# "rrggbb" + alpha 0-1 -> the rgba() ImageMagick understands.
rgba() {
    printf 'rgba(%d,%d,%d,%s)' "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}" "$2"
}

urldecode() {
    local s=${1//+/ }
    printf '%b' "${s//%/\\x}"
}

build_card() {
    local out=$1 url=$2 src="" font
    # Global rather than local: the EXIT trap runs after this function returns.
    tmp=$(mktemp -d "$CACHE/build.XXXXXX") || return
    trap 'rm -rf "$tmp"' EXIT
    load_colors

    case $url in
        file://*) src=$(urldecode "${url#file://}") ;;
        http://* | https://*)
            curl -fsSL --max-time 8 -o "$tmp/src" "$url" && src=$tmp/src ;;
    esac

    local inner=$(( ART - 2 * ART_BORDER ))
    # [0] takes the first frame of animated art; the crop keeps non-square art
    # (video thumbnails) from being squashed.
    if [[ -z $src || ! -r $src ]] || ! magick "$src[0]" -auto-orient \
        -resize "${inner}x${inner}^" -gravity center -extent "${inner}x${inner}" \
        "$tmp/art.png" 2>/dev/null; then
        font=$(fc-match -f '%{file}' 'JetBrainsMono Nerd Font')
        magick -size "${inner}x${inner}" "xc:#${C[surface1]}" \
            -font "$font" -pointsize 48 -fill "#${C[overlay0]}" \
            -gravity center -annotate +0+0 '󰝚' "$tmp/art.png" || return
    fi

    local canvas_h=$(( ART / 2 + CARD_H )) top=$(( ART / 2 ))
    magick "$tmp/art.png" \
        \( -size "${inner}x${inner}" xc:black -fill white \
           -draw "roundrectangle 0,0,$(( inner - 1 )),$(( inner - 1 )),$(( ART_R - ART_BORDER )),$(( ART_R - ART_BORDER ))" \) \
        -alpha off -compose CopyOpacity -composite "$tmp/art.png" &&
    magick -size "${ART}x${ART}" xc:none -fill "#${C[surface2]}" \
        -draw "roundrectangle 0,0,$(( ART - 1 )),$(( ART - 1 )),$ART_R,$ART_R" \
        "$tmp/art.png" -gravity center -compose over -composite "$tmp/framed.png" &&
    magick -size "${CARD_W}x${canvas_h}" xc:none \
        -fill "$(rgba "${C[base]}" 0.78)" -stroke "$(rgba "${C[overlay0]}" 0.45)" -strokewidth 1 \
        -draw "roundrectangle 0.5,$top.5,$(( CARD_W - 1 )).5,$(( canvas_h - 1 )).5,$CARD_R,$CARD_R" \
        \( "$tmp/framed.png" \( +clone -background black -shadow 45x6+0+4 \) +swap \
           -background none -layers merge +repage \) \
        -gravity north -geometry +0-8 -compose over -composite "$tmp/card.png" &&
    mv -f "$tmp/card.png" "$out" || return

    # Cards are cheap to rebuild; do not let a year of tracks pile up.
    find "$CACHE" -maxdepth 1 -name 'card-*.png' -mmin +1440 -delete 2>/dev/null
}

# One look at the player: what the card shows, written to $STATE in one go.
# Runs in the daemon, which keeps card, card_for and card_want between calls.
snapshot() {
    local status inst title artist pos len art shuffle="" loop="" mtime key
    IFS=$US read -r status inst title artist pos len art < <(playerctl metadata \
        --format "{{status}}$US{{playerInstance}}$US{{title}}$US{{artist}}$US{{position}}$US{{mpris:length}}$US{{mpris:artUrl}}" 2>/dev/null)
    if ! visible "${status-}"; then
        # An empty state: nothing playing.
        : > "$STATE.new" && mv -f "$STATE.new" "$STATE"
        return
    fi

    # Asked of this player: a bare `playerctl shuffle` answers for the first
    # player that supports it, which need not be this one. Browsers support
    # neither, and for them both stay empty.
    shuffle=$(playerctl -p "$inst" shuffle 2>/dev/null)
    loop=$(playerctl -p "$inst" loop 2>/dev/null)

    # The theme is part of the key, so switching themes re-renders the card.
    mtime=$(stat -c %Y "$COLORS" 2>/dev/null)
    if [[ "${art-}|$mtime" != "$card_for" ]]; then
        card_for="${art-}|$mtime"
        key=$(printf '%s|%s' "$CARD_REV" "$card_for" | md5sum)
        card_want="$CACHE/card-${key%% *}.png"
        [[ -e $card_want ]] || ( build_card "$card_want" "${art-}" ) &
    fi
    [[ -e $card_want ]] && card=$card_want

    # Written aside and renamed into place, so a reader never sees half of it.
    # The timestamp lets the progress label move on between snapshots.
    printf '%s\n' "$status$US$inst$US$title$US$artist$US${pos:-0}$US${len:-0}$US$shuffle$US$loop$US$card$US${EPOCHREALTIME/./}" \
        > "$STATE.new" && mv -f "$STATE.new" "$STATE"
}

run_daemon() {
    echo "$$" > "$PIDFILE"
    trap 'rm -f "$PIDFILE" "$STATE" "$STATE.new"' EXIT TERM INT
    exit_with_hyprlock
    [[ -e $EMPTY ]] || magick -size 1x1 xc:none "$EMPTY" 2>/dev/null

    card="" card_for="" card_want=""
    # playerctl --follow prints a line on every change to the fields in its
    # format, which wakes the loop at once; without any, it still runs every
    # second for the progress bar. read returns 1 once playerctl is gone, and
    # then the loop just polls.
    playerctl --follow metadata --format '{{status}}{{title}}{{shuffle}}{{loop}}' 2>/dev/null |
        while :; do
            snapshot
            read -r -t 1 _
            (( $? == 1 )) && sleep 1
        done
}

# Sets status, inst, title, ... from the state file; fails when nothing is
# playing or the daemon has not written it yet.
read_state() {
    ensure_daemon "$PIDFILE"
    [[ -s $STATE ]] || return 1
    IFS=$US read -r status inst title artist pos len shuffle loop card stamp < "$STATE"
}

case ${1-} in
    --daemon)
        mkdir -p "$CACHE"
        run_daemon
        ;;
    card)
        if read_state; then
            [[ -n $card ]] && printf '%s\n' "$card"
        elif [[ -e $STATE ]]; then
            printf '%s\n' "$EMPTY"
        fi
        ;;
    title)
        read_state || exit 0
        clip "$title" 24
        echo
        ;;
    artist)
        read_state || exit 0
        clip "$artist" 34
        echo
        ;;
    controls)
        read_state || exit 0
        # One cell per button, three spaces apart; a blank cell keeps the
        # others in place when shuffle or repeat is not supported.
        case $shuffle in
            On) row='󰒟' ;;
            Off) row='<span alpha="40%">󰒟</span>' ;;
            *) row=' ' ;;
        esac
        if [[ $status == Playing ]]; then icon='󰏤'; else icon='󰐊'; fi
        row+="   󰒮   <span size=\"19456\">$icon</span>   󰒭   "
        case $loop in
            Track) row+='󰑘' ;;
            Playlist) row+='󰑖' ;;
            None) row+='<span alpha="40%">󰑖</span>' ;;
            *) row+=' ' ;;
        esac
        printf '%s\n' "$row"
        ;;
    ctl)
        read_state && playerctl -p "$inst" "${@:2}"
        ;;
    loop-cycle)
        read_state || exit 0
        case $loop in
            None) playerctl -p "$inst" loop Playlist ;;
            Playlist) playerctl -p "$inst" loop Track ;;
            Track) playerctl -p "$inst" loop None ;;
        esac
        ;;
    progress)
        read_state || exit 0
        load_colors
        # The state is up to a second old; while playing, catch up to now.
        [[ $status == Playing ]] && pos=$(( pos + ${EPOCHREALTIME/./} - stamp ))
        # Some players report a position past the end while switching tracks.
        (( len > 0 && pos > len )) && pos=$len
        if (( len > 0 )); then
            form=short
            (( len >= 3600000000 )) && form=long
            duration elapsed "$pos" "$form"
            duration total "$len"
        else
            # Streams have no length: the clock runs, the knob stays at the start.
            duration elapsed "$pos"
            total=--:--
        fi
        time="$elapsed / $total"
        # The bar gives up a cell for every character the times grow by, so the
        # row keeps one width: it stays inside the card, and the label, which
        # is centered, does not shift as the clock ticks over.
        cells=$(( 34 - ${#time} ))
        filled=0
        (( len > 0 )) && filled=$(( pos * (cells - 1) / len ))
        printf -v done_bar '%*s' "$filled" ''
        printf -v rest_bar '%*s' $(( cells - 1 - filled )) ''
        printf '<span foreground="#%s">%s</span><span foreground="#%s">●</span><span foreground="#%s">%s</span>  %s\n' \
            "${C[accent]}" "${done_bar// /━}" "${C[text]}" "${C[overlay0]}" "${rest_bar// /━}" "$time"
        ;;
esac
exit 0
