# Changelog

## 1.1.1

- Heating Up: the stack count now comes from Pyroblast's cast time (each stack takes 25 % off it), so a critical strike that gives two stacks at once is counted right, and Pyroblast lights at 3 stacks in combat even when Heating Up isn't tracked in the cooldown manager. `/procglow report` shows the reading.

## 1.1.0

- Proc art: a new **Art side** option shows the art on both sides of your character (as before), or only on one side: left, right, top or bottom. With one side, a second proc goes further out on that side, a third and fourth on the two sides next to it.
- Proc art: **Choose the side per ability** gives each proc a side of its own (both, left, right, top or bottom); the others keep following Art side.
- Proc sounds: fourteen new sounds, each made for a kind of proc: blades clash (Overpower), shield bash (Revenge), axe blow (Execute), victory horn, parry (Riposte, Counterattack), beast snap (Mongoose Bite), holy hammer (Hammer of Wrath), holy echo (the paladin's echoes), shadow whisper (Shadow Trance), arcane shimmer, nature chimes and lightning crackle (Clearcasting for mages, druids and shamans), arcane missiles (Missile Barrage) and fire catching (Heating Up). Pick **Each proc's own sound** and every proc plays the one made for it.
- Proc art: sixteen new art styles for any proc: flames, runes, feathers, crescent moons, lightning, vines, crystal shards, stars, and game themes: swords, daggers, arrows, claw marks, skulls, snowflakes, rays of light and arcane sigils. Pick one for every proc under **Art**, or turn on **Choose the art per ability** to give each proc its own; "Show all arts" shows them too.
- Proc art colour: styles and the arc now show in each proc's own colour (fire orange for Heating Up, purple for Shadow Trance, gold for Hammer of Wrath, ...). **Art colour** switches to the glow colour, or to any colour you pick in the game's colour picker (**Pick**). The drawn pieces keep their own colours.
- Proc art: the "game's art" look is gone. Whoever had it chosen gets the drawn art; procs without a drawn piece show their icon.
- Proc glow and art stay lit through the global cooldown after another spell (Heating Up's art used to blink out after every Fireball). A proc still goes dark while its spell is on its own cooldown or you lack the mana.

## 1.0.0

- First release: Codex's proc glow as an addon of its own, for WoW Forever. Action buttons glow when an ability procs (reactive abilities and buff procs, the cooldown manager too), with seven glow styles, art beside your character (up to four procs at once) and an optional sound per ability.
