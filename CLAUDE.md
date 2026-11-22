# Tylesser - Proc Glow

Codex's proc glow (Codex `Modules/QoL/ProcGlow.lua` + `ProcArt.lua`) as a standalone addon (started 2026-11-22, the
user's request). **WoW Forever only** (Interface 16001), like Codex. Workspace conventions in `E:/Games/Wow/CLAUDE.md`.

- **ProcGlow.lua and ProcArt.lua are Codex's files, byte for byte** (`pg_test.lua` checks). Change them in Codex and
  copy them here (or the other way round), never one alone. They read `ns.PROC_MEDIA` / `PROC_CIRCLE` / `PROC_RING`
  (media paths), `ns.PROC_BRAND`, `ns.PROC_ART_NAME`, `ns.PROC_FRAMES` (names), set by `Shim.lua` here; in Codex these
  are nil and the Codex paths and names are used.
- `Shim.lua` stands in for Codex: `ns.qol` (Q: `DB` = `ProcGlowDB`, account wide, defaults from the toggle's option
  list, the toggle on by default; `On`, `Set`, `AddToggle`, `Toggle`, `Option`, `ChoiceText`, `OpenChoice` through
  `MenuUtil.CreateContextMenu`), `ns.UI` (Text, Button, Picker, Panel, CloseButton on the shared Tylesser look;
  `Radius` nil = everything square), `ns.Theme()` (accent = Tylesser gold), `ns.PREFIX`. Start-up: ADDON_LOADED fills
  the settings, PLAYER_LOGIN runs the toggle's Enable.
- `Options.lua`: the options page (T.OptionsPage + a scroll) built from the toggle's option list (check, choice with
  preview / extra button, stepper, button, the per-ability sound list as the custom option); `/procglow` (`/pglow`).
- Codex leaves the feature to this addon while it is loaded (the toggle's `Elsewhere` in ProcGlow.lua).
- Media: flat in `Media/` (Glow*, ProcSide, ProcIconMask, ProcArt/*.tga from Codex's `Modules/QoL/Media`, Circle from
  Codex's Media, Ring from Codex's Buffs). New Codex art (`branding/source/proc-codex-art.py` in Codex) is copied here too.
- Icon: `branding/source/icons.js <depsDir> <outDir>` (resvg-js), `Media/Icon.tga` from its Icon.tga.
- Test: `node tools/harness/run.js pg_test.lua E:/Games/Wow/Addons/ProcGlow` (from tools/harness).
