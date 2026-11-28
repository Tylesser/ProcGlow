<img src="branding/procglow-icon-512.png" width="96" align="right" alt="">

# Tylesser - Proc Glow

A World of Warcraft addon for **WoW Forever** that makes your **action buttons glow when an ability procs**, shows **art beside your character** like later expansions do, and can **play a sound** when a proc starts. It is the proc glow of [Tylesser - Codex](https://tylesser.com/codex/) as an addon of its own, for players who don't use Codex.

## Features

- **Reactive abilities glow** while they can be used: Overpower, Revenge, Execute, Riposte, Counterattack, Mongoose Bite, Hammer of Wrath (and Victory Rush where the game has it).
- **Buff procs glow** the spells they empower: Shadow Bolt with Shadow Trance (Nightfall), Arcane Missiles with Missile Barrage, Pyroblast at 3 stacks of Heating Up, the paladin's seals with Unsealed Wrath's echoes at 3 stacks. Clearcasting shows only its art, no glow on the buttons.
- What the game already lights itself keeps the game's glow.
- **Glow styles**: the game's spell alert, a pulsing border, marching sparkles, a soft glow, a flash or a ring. Colour (gold, class or a fixed colour), pulse speed and thickness.
- **Cooldown manager**: the glow on its icons too, and optionally in place of the game's square glow.
- **Art beside your character**: a piece drawn for each proc, sixteen styles for any proc (flames, runes, feathers, crescent moons, lightning, vines, crystal shards, stars, swords, daggers, arrows, claw marks, skulls, snowflakes, rays of light, arcane sigils), the spell's icon or a plain arc, for all procs or per ability. Each proc shows in its own colour, or in the glow colour or one you pick. Several procs show together: two left and right, a third on top, a fourth below; or all on one side you choose, left, right, top or bottom (**Art side**). Each ability can also get a side of its own. Size and opacity, with "Show the art" and "Show all arts".
- **Sound** when a proc starts (off until you switch it on): 14 sounds made for procs (or each proc its own: blades for Overpower, fire for Heating Up, ...) and 14 of the game's, soft or loud, only in combat if you like, on the Master channel if you want, and a different sound per ability. The per-ability lists show your class's procs and fold up, and each ability can get its own art colour.

- **Your own procs**: a buff of yours lights a spell on your bars. Pick them from a window: your buffs, gear, consumables in your bags and your spells, by category. In a fight the game hides most buffs from addons, so track the buff in the cooldown manager.
- **Profiles**: keep several sets of settings (a glow and sound for each of your characters, a quiet one for levelling, ...) and switch between them at the top of the options page or with `/procglow profile <name>`, also from a macro. Each character remembers its own profile; a new one starts as a copy of the settings in use.
- **Warning before a proc ends** (off until you switch it on): in a buff proc's last seconds (2 by default, 1 to 5) its glow pulses faster and its art flashes, with a sound if you pick one. Buff procs only (Shadow Trance, Clearcasting, Heating Up, Missile Barrage, the seal echoes, your own procs): Overpower and the other abilities that light up after a dodge or parry have no time the game gives. In a fight the game hides your buffs' times, so there it counts from when the proc lit, for buffs you track in the cooldown manager.
- **More**: a faint glow while you can't cast the spell yet, a glow style and colour per ability, stacking procs building up (one arc, two arcs, then the symbol), Move the art (also in Edit Mode), art only in combat, the time between sounds, and one preview on the options page that shows any ability's glow, art and side together (hover it in a list), with Play.

If you use Codex, its own proc glow does the same; while this addon is loaded, Codex leaves the job to it.

## Usage

- `/procglow`, or Esc > Options > AddOns > **Tylesser** > Open Tylesser settings. The options open in Tylesser's own settings window.
- `/procglow test` shows the art for a few seconds, `/procglow arts` every piece of art.
- `/procglow on` / `/procglow off` switches it.
- `/procglow profile` lists your profiles, `/procglow profile <name>` switches to one (not in a fight).
- `/procglow report` prints what each glow is doing (handy in a bug report).

## Why doesn't a proc glow?

- **In a fight the game hides your buffs from addons.** Buff procs (the paladin's echoes, Shadow Trance, Missile Barrage, your own procs) then light only while that buff is tracked in the game's **cooldown manager**, which Proc Glow can still read. Add the buff to its tracked buffs (icons or bars). Heating Up is the exception: its stacks show in Pyroblast's cast time, which stays readable.
- **The paladin's echoes** come from the **Unsealed Wrath** talent. At 3 stacks of an echo the seals you could switch to glow (not the one you have on), and the echo's art shows; one or two stacks only build up the glow. Seal of the Crusader has no echo. In a fight, track Unsealed Wrath in the cooldown manager.
- **Reactive abilities** (Overpower, Execute, Hammer of Wrath, ...) need no setup: they glow whenever the game lets you use them.
- Still nothing? Type `/procglow report` while the proc is up and send what it prints with `/procglow feedback`.

Languages: English, German, French, Spanish (Spain and Mexico), Russian and Brazilian Portuguese, following your game client.

## Feedback

Found a bug or have an idea? Click **Feedback** on the options page or type `/procglow feedback` in game to get the link, or go straight to [tylesser.com/feedback](https://tylesser.com/feedback/#procglow).

No GitHub account? Join the [Tylesser Discord](https://discord.gg/n2rEB6mRxF) and post in #bug-reports or #ideas with the addon's tag; each post is copied to GitHub and the bot answers with the link.

## Installation

Install from CurseForge or Wago, or download the latest zip from [Releases](https://github.com/Tylesser/ProcGlow/releases) and extract it to `Interface/AddOns`. The folder must be named `ProcGlow`.

## Releasing (maintainers)

Releases are built by [BigWigsMods/packager](https://github.com/BigWigsMods/packager). Push a version tag to publish to GitHub Releases, CurseForge and Wago Addons:

```
git tag v1.0.0
git push origin v1.0.0
```

## License

[MIT](LICENSE)
