# Test log (2026-11-06)

Legend: VERIFIED = run here and observed. DOCS = taken from AGENTS.md, not tested. UNVERIFIED = not tested.

## Part 1 themes
- VERIFIED `herdr-theme-check`: selecao-minimal 40/40 (min 5.58), ink-minimal 40/40 (min 5.22), paper-minimal 40/40 (min 4.79).
  Pairs: fg/bg/selection/surface/chrome, muted, dim, accent, accent_fg/accent, working/blocked/done/idle on bg+surface,
  ansi1-15 on bg, ansi0 (as bg for fg, or as text), cursor 3:1.
- VERIFIED `app.theme` accepts all three new names and rejects an unknown one (`no theme "nonexistent-zzz"`), so they are
  registered with the picker. Not looked at in the picker UI itself (UNVERIFIED visually); `themes()` in herdr.d.ts feeds it (DOCS).
- VERIFIED `layout.clone main -> main-themed`, root `"theme": {"light":"paper-minimal","dark":"ink-minimal"}` loads with no error.
  NOT verified: that the light half actually renders (system is dark).
- Note: `app.theme` writes its pick into `layouts/.state/<layout>.json`, not the layout file (matches DOCS).

## Part 2 animation
- Findings (DOCS + d.ts): no pixel-art/sprite/room rendering exists in herdr-app; the shipped `agents` mod is a list. Animatable natively:
  `loop` (opacity/width/height/left/top, ~30 fps, only while drawn), `frames` (text), `spin` (svg), `transition`/`spring`.
  NOT available: colour animation, rotation/scale, box-shadow glow, keyframes/one-shot, reduced-motion signal.
  Workarounds used: pulsing border = overlay ring whose opacity loops; bounce = `loop top`; glow = tinted layer opacity loop;
  pop = spring with damping 0.45 on width/height (overshoot) started by a one-shot `cx.timer.after`.
- VERIFIED (window visible, 8 screenshots 0.3 s apart, all hashes differ): ring pulses, "!" bounces, glow/dot breathe, z z drift,
  DONE card goes from a 4px dot to the check circle.
- VERIFIED reduced motion (forced on): 5 frames byte-identical, all states still legible.
- UNVERIFIED: the Motion toggle *click* (no way to click from CLI; logic checked by forcing the flag), the overshoot of the pop
  (frames too coarse), "+N" flash on count change, real (non-demo) blocked/working/done agents. Periods: ring 2.0 s, "!" 1.2 s (0.83 Hz), all < 1 Hz.
- NOT DONE: the pixel-art rooms, and the Reddit GIF motion reference (the placeholder in the prompt was left unfilled).

## Part 3 dynamic theme
- VERIFIED tool = matugen 4.2.0 via `~/.config/theme/theme` (+ awww). Hook added as a normal `[[output]]`.
- VERIFIED offline pipeline reproduces the real cache (sword.png -> accent #ffb694, base #221a16).
- VERIFIED contrast fix: sword 40/40 (min 4.50), cyber-city 40/40 (min 4.55); only ansi8 needed lifting; state colours identical hues
  (blocked #ff4f4f, working #f7b446, done #63d999).
- VERIFIED LIVE RELOAD: with the window visible, rewriting the active `themes/dynamic.json` in place (no `app.theme`) changed
  `theme().background` within 2.5 s, twice (#101a2b, #2b1010). => in-place mode is the default.
  IMPORTANT: while the window is on a hidden workspace nothing re-renders or reloads (probe/zoom tests were inconclusive until the
  window was visible). A change made while hidden is applied when it becomes visible (not separately timed).
- VERIFIED before/after through the real script on the live app: sword -> bg/sidebar/tabbar pixels (34,26,22)/(26,18,14)/(26,18,14);
  cyber-city -> (31,26,31)/(23,18,22)/(23,18,22) = generated values exactly. Screenshots: scratchpad `before-after.png`.
- VERIFIED idempotent (same palette -> no write, no app.theme), app-down (HERDR_APP_HOME bogus -> wrote file, warned, exit 0),
  bad/missing palette (exit 1, nothing written), refuses to write a theme that fails AA.
- VERIFIED `ab` fallback: slots alternate b->a->b, app switches each time, idle slot mirrored. Found + fixed a bug (stale `slot: null` made
  `dynamic-None.json`).
- VERIFIED end to end: your own `theme refresh` rendered the palette, ran the hook, wrote dynamic.json, applied it (state applied=true).
- NOT run: a real wallpaper change via `set-wallpaper.sh`/awww (it would repaint the desktop and LED/keyboard devices); only `theme refresh`
  on the unchanged wallpaper. Offline pipeline stood in for the second wallpaper.
- Flicker: single atomic replace + single `app.theme`; no visible flicker was seen in two sequential screenshots, but not measured.
- Side effect to know: deleting the *active* theme file left a sticky `not applied` error until the layout was re-saved (cleared).
