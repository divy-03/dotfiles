"""Shared colour maths for herdr-theme-check and herdr-theme-sync (stdlib only)."""
import colorsys

def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def hexs(r, g, b):
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(c))) for c in (r, g, b))

def lin(c):
    c /= 255
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

def lum(h):
    r, g, b = rgb(h)
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)

def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)

def hls(h):
    return colorsys.rgb_to_hls(*(c / 255 for c in rgb(h)))

def from_hls(h, l, s):
    return hexs(*(c * 255 for c in colorsys.hls_to_rgb(h, max(0, min(1, l)), max(0, min(1, s)))))

def mix(a, b, t):
    """t=0 -> a, t=1 -> b"""
    ra, rb = rgb(a), rgb(b)
    return hexs(*(x + (y - x) * t for x, y in zip(ra, rb)))

def fit(color, bgs, minr=4.5, prefer_lighter=True):
    """Keep hue (and saturation); move only lightness until `color` has >= minr
    contrast against every colour in bgs. Tries the preferred direction first, then
    the other; returns the closest-to-original solution."""
    def ok(c):
        return all(ratio(c, b) >= minr for b in bgs)
    if ok(color):
        return color
    h, l, s = hls(color)
    best = None
    for direction in ((1, -1) if prefer_lighter else (-1, 1)):
        x = l
        while 0 <= x <= 1:
            x += 0.005 * direction
            c = from_hls(h, x, s)
            if ok(c):
                if best is None or abs(x - l) < best[0]:
                    best = (abs(x - l), c)
                break
    if best:
        return best[1]
    # last resort (very mid-tone backgrounds): pure black or white, whichever is better
    return max(("#000000", "#ffffff"), key=lambda c: min(ratio(c, b) for b in bgs))

def pairs(t):
    """(label, fg, bg, minimum ratio) for every text/background pair we promise."""
    c = t.get("colors", {})
    bg, fg = t["background"], t["foreground"]
    surf, chrome = c.get("surface", bg), c.get("chrome", bg)
    out = [("foreground/background", fg, bg, 4.5),
           ("foreground/selection", fg, t["selection"], 4.5),
           ("foreground/surface", fg, surf, 4.5),
           ("foreground/chrome", fg, chrome, 4.5),
           ("cursor/background", t.get("cursor", fg), bg, 3.0)]
    for k in ("muted", "dim"):
        if k in c:
            out += [(f"{k}/{n}", c[k], b, 4.5) for n, b in (("background", bg), ("surface", surf), ("chrome", chrome))]
    if "accent" in c:
        out += [(f"accent/{n}", c["accent"], b, 4.5) for n, b in (("background", bg), ("surface", surf), ("chrome", chrome))]
        if "accent_foreground" in c:
            out.append(("accent_foreground/accent", c["accent_foreground"], c["accent"], 4.5))
    if "solid" in c and "solid_foreground" in c:
        out.append(("solid_foreground/solid", c["solid_foreground"], c["solid"], 4.5))
    for k in ("working", "blocked", "done", "idle"):
        if k in c:
            out += [(f"{k}/background", c[k], bg, 4.5), (f"{k}/surface", c[k], surf, 4.5)]
    names = "black red green yellow blue magenta cyan white".split()
    for i, col in enumerate(t["ansi"]):
        label = ("bright " if i >= 8 else "") + names[i % 8]
        if i == 0:
            # the "black" slot is a *background* in most tools (powerline, highlights) but
            # *text* in a light theme: either role passes.
            role = (fg, col) if ratio(fg, col) >= ratio(col, bg) else (col, bg)
            out.append(("ansi0 black (as bg for fg, or as text on bg)", role[0], role[1], 4.5))
        else:
            out.append((f"ansi{i} {label}/background", col, bg, 4.5))
    return out

def audit(t):
    res = [(l, f, b, m, ratio(f, b)) for l, f, b, m in pairs(t)]
    return res, [r for r in res if r[4] < r[3]]
