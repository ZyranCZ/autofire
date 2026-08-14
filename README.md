# Autofire AB

Holding A, B or a direction repeats the press on a timer, so text, battles and
menus can be advanced without mashing.

## Try it

1. Copy the `a_autofire` folder into the game's `mods/` directory.
2. Launch the game and press **F10** to open the mod manager.
3. Enable **Autofire AB**, then open its options to set the timings.

## Game compatibility

- **Pokémon Red / Blue / Yellow:** supported. The established v1.3.1 behavior is preserved.
- **Pokémon Gold / Gen 2:** supported as of v2.0.0. A and B autofire use the same shared core as Gen 1. v2.0.1 fixed Gold option persistence; v2.0.2 migrates repeat injection to Gen1Recomp's public `mod.input` API used by the v0.1.86 target.

The mod declares both `gen1` and `gen2` support in `manifest.json`. There is no engine-version allow-list: a newer Gen1Recomp version will not be rejected merely because its version number changed. If the shared Mod API actually breaks in a future engine build, that should be handled as a compatibility bug rather than a version-number gate.

## Options

| Row | Values | Default |
| --- | --- | --- |
| `AUTOFIRE BUTTONS` | OFF / A ONLY / B ONLY / A AND B | A AND B |
| `HOLD BEFORE REPEAT` | 150 – 500 ms | 250 ms |
| `REPEAT EVERY` | 50 / 100 / 150 / 200 / 300 / 400 / 500 ms | 200 ms |
| `DIRECTIONAL KEYS` | ON / OFF | OFF |
| `AUTOFIRE IN` | EVERYWHERE / BATTLE ONLY / WORLD ONLY | EVERYWHERE |

**HOLD BEFORE REPEAT** is what keeps one tap being one press. Nothing repeats
until the button has been down for the whole window, so an ordinary press
behaves exactly as it does without the mod.

Every button shares one delay and one rate, but each keeps its own countdown —
pressing B partway through an A hold gives B a full delay window rather than
starting it mid-burst.

**DIRECTIONAL KEYS** adds UP/DOWN/LEFT/RIGHT. This does not change walking:
the overworld reads held state, not press edges, so a held direction already
repeats on its own out there. What it buys is cursor repeat in menus — the
Pokédex, the bag, the PC, the naming grid — which move on press edges.

Screens that already implement hold-to-scroll for themselves (a `ListMenu`
with `keyRepeat`, which `pokedex_plus` turns on for five of its lists) keep
their own timing; autofire leaves their directions alone rather than stacking
a second scroll on top. A and B still autofire there.

**AUTOFIRE IN** narrows where autofire applies.

`BATTLE ONLY` is the escape hatch for the overworld's hazards: holding A keeps
re-triggering whatever you are facing, a yes/no prompt that appears mid-hold
answers itself, and held B repeats cancel, which walks back out of menus.

`WORLD ONLY` is the mirror — autofire for overworld text and menus, with
battles left fully manual so a held button can never pick a move or burn a turn
on its own. A battle starting mid-hold cuts autofire off immediately.

## Why the timings are a fixed list

Game logic advances on a fixed 60 Hz clock, so one logic step is 16.67 ms and
that is the smallest interval an input can be repeated at. The offered values
are the ones that land on a whole number of steps — 50 ms is exactly 3 steps,
250 ms is exactly 15. A free-typed number would be rounded to the same grid
without saying so.

## How it works

The engine calls the `input.step` hook once per logic step, immediately before
`Input:step` promotes presses into that step's edges — the shared Gen 1 / Gen 2
seam documented for autoplay and accessibility tools. Once a held button passes
the delay window, Autofire emits the repeat through the public `mod.input:tap`
API. The loader gives each mod its own input source, so an autofire edge cannot
release or overwrite a physical key, touch input, controller input, or another
mod's hold.

Autofire never writes held-state internals. That matters most in `A AND B` mode:
the A+B+SELECT+START soft reset still counts genuinely held buttons, so a real
four-button chord keeps working normally. A tiny read-only queue check remains
only to preserve fast release+press re-arming before `Input:step`; if that
internal queue is hidden by a future engine, Autofire simply loses that
same-tick refinement rather than failing its repeat core.

## Tests

The source regression suite covers timing, independent A/B timers, scopes,
directional repeat suppression, live option changes, same-tick press re-arming,
Gold option persistence, and the public `mod.input` injection path. The
user-facing release ZIP intentionally contains only the files needed by the mod.
