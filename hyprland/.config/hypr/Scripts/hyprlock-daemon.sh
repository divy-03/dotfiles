# Helpers for the lock screen's widget scripts (cava-hyprlock.sh and
# player-hyprlock.sh). Sourced, not run.
#
# hyprlock runs widget commands on its main thread, one after another and in
# between drawing frames, so every millisecond a command takes holds up every
# other widget -- the visualizer, which ticks 20x a second, most visibly.
# Asking playerctl over D-Bus takes 10-25ms and cava needs a few hundred to warm
# up, far too slow for that. So each script keeps a daemon doing its slow work
# for as long as hyprlock is up, and its widget commands only read what the
# daemon last wrote, with bash builtins alone.

# Runs "$@" in its own session, detached from hyprlock. hyprlock reads a widget
# command's output from pipes until every copy of them is closed, and the child
# gets extra copies besides stdout and stderr. A background process holding on
# to one makes hyprlock wait on that command forever, which freezes every widget
# on the lock screen, so everything past stdio is closed first.
detach() {
    (
        local fd
        for fd in /proc/"$BASHPID"/fd/*; do
            fd=${fd##*/}
            (( fd > 2 )) && eval "exec $fd>&-" 2>/dev/null
        done
        exec setsid -f "$@" >/dev/null 2>&1 </dev/null
    )
}

# daemon_alive PIDFILE -- whether the daemon recorded there is running. Checked
# without forking, since widget commands run many times a second. A daemon that
# has not written its pid yet counts as alive for a few seconds, so the gap
# between starting it and it recording itself cannot start a second one. The
# pid is only trusted while its command line still names this script, in case
# the pid has been reused.
daemon_alive() {
    local pid rest arg
    [[ -r $1 ]] || return 1
    read -r pid rest < "$1" || return 1
    [[ -n $pid ]] || return 1
    if [[ $pid == starting ]]; then
        (( EPOCHSECONDS - rest < 5 ))
        return
    fi
    [[ -r /proc/$pid/cmdline ]] || return 1
    # Walked argument by argument because /proc/<pid>/cmdline is NUL-separated
    # and slurping it whole makes bash warn about null bytes on every call.
    while read -r -d "" arg; do
        [[ ${arg##*/} == "${0##*/}" ]] && return 0
    done < /proc/"$pid"/cmdline
    return 1
}

# ensure_daemon PIDFILE [FILE...] -- starts "$0 --daemon" unless it is running.
# A daemon older than its script, these helpers or any FILE (its config) runs
# outdated code or settings, and one can outlive an edit: it only exits once no
# hyprlock is left, so a lock screen that was up across the edit carries it into
# the next one. Such a daemon is replaced. -nt is a builtin test, and the
# pidfile's mtime is the daemon's start.
ensure_daemon() {
    local pidfile=$1 file pid
    shift
    if daemon_alive "$pidfile"; then
        for file in "$0" "${BASH_SOURCE[0]}" "$@"; do
            [[ $file -nt $pidfile ]] || continue
            read -r pid _ < "$pidfile"
            # The daemon leads its own process group (setsid), so this takes
            # its children down with it; the next call starts a fresh one.
            [[ $pid == starting ]] || kill -TERM -- -"$pid" 2>/dev/null
            return
        done
        return
    fi
    echo "starting $EPOCHSECONDS" > "$pidfile"
    detach "$0" --daemon
}

# Called by a daemon: ends its process group once hyprlock is gone, so nothing
# is left running on an unlocked session. setsid made the daemon the leader of
# its own group, so `kill 0` reaches it and its children and nothing else.
exit_with_hyprlock() {
    (
        while pgrep -x hyprlock >/dev/null 2>&1; do sleep 2; done
        kill 0 2>/dev/null
    ) &
}
