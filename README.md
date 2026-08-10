# Autofire AB

Holding A, B or a direction repeats the press on a timer, so text, battles and
menus can be advanced without mashing.

## Try it

1. Copy the `a_autofire` folder into the game's `mods/` directory.
2. Launch the game and press **F10** to open the mod manager.
3. Enable **Autofire AB**, then open its options to set the timings.

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
`Input:step` promotes queued presses into that step's edges — the seam it
documents for autoplay and accessibility tools. While a button is held past the
delay window, this mod pushes its name onto `input.pressQueue` on schedule, and
the engine turns it into a press edge indistinguishable from a real one.

It never writes `input.state`, so held-button bookkeeping stays owned by real
input sources. That matters most in `A AND B` mode: the A+B+SELECT+START soft
reset still counts only genuinely held buttons, so autofire can never trip it,
and a real four-button chord still works.

## Tests

`tests/autofire_test.lua` drives the mod against the engine's real
`src/core/Input.lua` and a stand-in for `Game:step` that preserves the call
order. Run it from the game's root:

```
lua tests/autofire_test.lua
```
