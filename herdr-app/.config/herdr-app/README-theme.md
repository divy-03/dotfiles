# Herdr themes: static + wallpaper-driven

## What's here
| Path | What |
|---|---|
| `themes/selecao-minimal.json` | Brazil-inspired, restrained: near-black green, canary-yellow accent (focus/active only), deep-blue selection |
| `themes/ink-minimal.json` | monochrome graphite, one accent (`#8fa8ff`), hairline borders |
| `themes/paper-minimal.json` | light counterpart of ink-minimal |
| `themes/dynamic.json` | **generated** from the wallpaper palette; do not edit by hand |
| `layouts/main-themed.json` | clone of `main`, pinned `{"light":"paper-minimal","dark":"ink-minimal"}` |
| `mods/agent-cards/` | animated agent state cards (open: `herdr-app do mod.open '{"name":"agent-cards"}'`) |
| `bin/herdr-theme-sync` | palette -> `themes/dynamic.json` -> `app.theme dynamic` |
| `bin/herdr-theme-check` | WCAG AA audit of any theme file |
| `bin/herdr_theme_lib.py` | shared contrast maths |
| `~/dotfiles/theme/.config/theme/templates/herdr-palette.json` | template: your desktop palette as JSON |
| `~/dotfiles/theme/.config/theme/outputs.toml` | +1 `[[output]]` that runs `herdr-theme-sync` as a hook |

## How the dynamic theme flows
wallpaper change -> `set-wallpaper.sh` -> `theme refresh` (matugen, your palette) -> renders
`~/.cache/theme/herdr-palette.json` (same palette as kitty/nvim) -> hook `herdr-theme-sync`
-> contrast-fixes (hue kept, lightness moved until AA) -> atomic write `themes/dynamic.json`
-> `herdr-app do app.theme '{"name":"dynamic"}'`. Same path runs on `theme set <preset>`.
Herdr re-reads the rewritten file by itself (verified), so there is no flicker.

## Add a theme
Copy `themes/ink-minimal.json`, change colours, then:
`bin/herdr-theme-check themes/<name>.json` (must say N/N pass). It appears in the picker
(Settings, theme menu) with no restart. Pin per layout: `"theme": {"light": "a", "dark": "b"}`
on a **cloned** layout (`herdr-app do layout.clone '{"name":"main","as":"mine"}'`).

## Switch
- Static: theme picker, or `herdr-app do app.theme '{"name":"selecao-minimal"}'`
- Dynamic: `herdr-app do app.theme '{"name":"dynamic"}'` (or just change wallpaper / `theme set ...`)
- Layout: `herdr-app do layout.switch '{"name":"main-themed"}'` / `'{"name":"main"}'`
- Force a re-sync: `bin/herdr-theme-sync --force`; preview without writing: `--dry-run`

## Fallback mode
If a future Herdr stops re-reading rewritten theme files: `echo ab > bin/herdr-theme-sync.mode`
(alternates `dynamic-a/-b.json`). Do not delete the *active* theme file: the layout reports
"not applied" until the layout is reloaded.

## Roll back
1. Remove the hook: delete the last `[[output]]` block in `~/dotfiles/theme/.config/theme/outputs.toml`
   and `templates/herdr-palette.json`.
2. `herdr-app do layout.switch '{"name":"main"}'`
3. Delete what you don't want: `themes/{selecao,ink,paper}-minimal.json themes/dynamic*.json
   layouts/main-themed.json layouts/.state/main-themed.json mods/agent-cards bin/ ~/.cache/herdr-theme-sync`
Nothing shipped was edited.

## Agent cards: motion + reduced motion
State colours come from `theme().blocked/working/idle/done` (red/amber/grey/green, fixed hue
anchors in every theme incl. dynamic). Motion is only native: `loop`, `spring`, `transition`.
"Motion: reduced" in the card header (shared `motion.reduced`) freezes every loop/spring.
There is no OS reduced-motion signal in herdr-app, so this is the mod's own switch.
