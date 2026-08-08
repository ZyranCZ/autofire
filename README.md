# Autofire AB

A configurable autofire mod for **Gen1Recomp**.

Hold **A**, **B**, or optionally the **D-Pad** to automatically repeat button presses without constantly mashing the controls.

Autofire can be used everywhere, restricted to battles, or restricted to the overworld and menus.

<img width="809" height="753" alt="image" src="https://github.com/user-attachments/assets/ddcb6196-9f4c-4631-ad42-07f837f4338f" />

**Check out my other mods:**<br>
* [Autofire A/B + Directional Keys Mod](https://github.com/ZyranCZ/autofire)<br>
* [Steel and/or Fairy and/or Typing Charts](https://github.com/ZyranCZ/Steel-and-or-Fairy-and-or-Typing-Charts)<br>
* [Move Category (PHYS/SPEC) Preview](https://github.com/ZyranCZ/Move-Category-Preview)<br>
* [Special Stat Split
](https://github.com/ZyranCZ/Special-Stat-Split/)<br>
* [Enemy HP Visible](https://github.com/ZyranCZ/Enemy-HP)
* [Can Always Escape](https://github.com/ZyranCZ/Can-Always-Escape)
* [Trainers Let You Choose Lead Pokemon](https://github.com/ZyranCZ/Trainers-Let-You-Choose-Lead-Pokemon)
* [Evolve in Battle](https://github.com/ZyranCZ/Evolve-in-Battle)
---

## Features

* Autofire for **A**
* Autofire for **B**
* Optional autofire for **UP / DOWN / LEFT / RIGHT**
* Adjustable delay before autofire begins
* Adjustable repeat speed
* Separate timing for each held button
* Battle-only mode
* World-only mode
* Protection against double-scrolling in menus that already support held directional input
* Does not interfere with the real **A+B+SELECT+START soft reset**

---

# Installation

1. Download the latest release.
2. Extract the `a_autofire` folder into the Gen1Recomp `mods/` directory.
3. Launch Gen1Recomp.
4. Press **F10** to open the Mod Manager.
5. Enable **Autofire AB**.
6. Open the mod's Options and configure it to your preference.

---

# Options

## AUTOFIRE BUTTONS

Controls which face buttons use autofire.

Available settings:

* **OFF**
* **A ONLY**
* **B ONLY**
* **A AND B**

Default:

**A AND B**

---

## HOLD BEFORE REPEAT

Controls how long a button must remain held before autofire begins.

Available settings:

* 150 ms
* 200 ms
* 250 ms
* 300 ms
* 400 ms
* 500 ms

Default:

**250 ms**

This delay prevents normal button presses from becoming accidental bursts.

A quick tap still behaves like a normal single press.

---

## REPEAT EVERY

Controls how frequently another press is generated once autofire has started.

Available settings:

* 50 ms
* 100 ms
* 150 ms
* 200 ms
* 300 ms
* 400 ms
* 500 ms

Default:

**200 ms**

Lower values are faster.

For example:

* **50 ms** — very fast
* **100 ms** — fast
* **200 ms** — comfortable default
* **500 ms** — slow repeat

---

## DIRECTIONAL KEYS

Controls autofire for:

* UP
* DOWN
* LEFT
* RIGHT

Available settings:

* **OFF**
* **ON**

Default:

**OFF**

Directional autofire is mainly intended for navigating menus such as the:

* Pokédex
* Bag
* PC
* Naming screen
* Other cursor-based interfaces

It does **not** increase normal walking speed.

Gen1Recomp already treats a held direction as continuous movement in the overworld, while many menus instead react to individual button presses.

---

## AUTOFIRE IN

Controls where autofire is allowed.

Available settings:

### EVERYWHERE

Autofire works both in battles and outside battles.

This is the default setting.

### BATTLE ONLY

Autofire only works during battles.

This is useful if you want rapid battle inputs while keeping overworld interaction completely manual.

### WORLD ONLY

Autofire works outside battles but is disabled during battles.

This is useful for quickly advancing dialogue and navigating menus while preventing a held button from accidentally selecting moves or actions during battle.

---

# How Autofire Behaves

Autofire does **not** immediately spam a button when you press it.

For example, with the default settings:

**HOLD BEFORE REPEAT: 250 ms**
**REPEAT EVERY: 200 ms**

A normal quick press of A produces:

`A`

If A remains held past the initial delay, the mod begins generating additional A presses at the selected repeat interval.

Releasing the button immediately stops the repeat cycle.

---

# Independent Button Timing

Each button has its own hold timer.

For example:

1. Hold **A**
2. Autofire begins
3. While still holding A, press and hold **B**

B does **not** inherit A's existing timer.

Instead, B receives its own full **HOLD BEFORE REPEAT** delay before it begins repeating.

The same behavior applies to enabled directional buttons.

---

# Battle and World Safety

Repeated inputs can sometimes have unintended consequences depending on where they are used.

For example, holding A in the overworld could potentially:

1. Talk to an NPC
2. Advance their dialogue
3. Reach a YES/NO prompt
4. Automatically confirm an option

Likewise, repeated B presses may repeatedly cancel through menus.

For this reason, the mod provides **BATTLE ONLY** and **WORLD ONLY** modes so the player can decide where autofire is appropriate.

If a battle begins while **WORLD ONLY** autofire is active, autofire stops immediately for the duration of the battle.

---

# Menu Compatibility

Some Gen1Recomp menus already implement their own hold-to-scroll behavior.

Running both systems simultaneously could cause the cursor to move twice as fast or skip entries.

Autofire AB detects screens that already use Gen1Recomp's `keyRepeat` behavior and automatically disables **directional autofire** on those screens.

A and B autofire remain unaffected.

This also improves compatibility with mods such as **Pokédex Plus**, which use their own directional repeat behavior in several menus.

---

# Soft Reset Safety

Pokémon Red/Blue uses:

**A + B + SELECT + START**

for a soft reset.

Autofire AB does not fake buttons as physically held.

It only generates additional individual button presses.

Because of this:

* Autofire cannot trigger a soft reset by itself.
* Holding only A and B with autofire active will not reset the game.
* Physically holding **A+B+SELECT+START** still performs the normal soft reset.

---

# Timing and Gen1Recomp

Gen1Recomp game logic runs at a fixed **60 Hz**.

One logic step is approximately:

**16.67 ms**

Autofire timings therefore use values that map cleanly to whole game logic steps.

For example:

| Setting | Logic Steps |
| ------- | ----------: |
| 50 ms   |           3 |
| 100 ms  |           6 |
| 150 ms  |           9 |
| 200 ms  |          12 |
| 250 ms  |          15 |
| 300 ms  |          18 |
| 400 ms  |          24 |
| 500 ms  |          30 |

This keeps repeat behavior consistent and predictable.

---

# Technical Details

Autofire AB operates through Gen1Recomp's `input.step` hook.

While a selected button remains physically held, the mod tracks:

* how long it has been held
* how long it has been since the previous generated press

Once the configured delay has passed, additional press events are inserted at the configured interval.

The mod does not directly overwrite the physical held-button state.

This helps preserve normal input behavior and compatibility with systems that need to distinguish between a button being **held** and a button being **pressed**.

---

# Default Configuration

```text
AUTOFIRE BUTTONS    A AND B
HOLD BEFORE REPEAT  250 MS
REPEAT EVERY        200 MS
DIRECTIONAL KEYS    OFF
AUTOFIRE IN         EVERYWHERE
```

This configuration is intended to provide a comfortable autofire speed without turning normal short button presses into bursts.

---

# Compatibility

Designed for **Gen1Recomp**.

Gen1Recomp:

https://github.com/bryanthaboi/gen1recomp

The mod is designed to coexist with other mods where possible and specifically avoids adding directional repeat on screens that already implement their own hold-to-scroll behavior.

As with any input-related mod, unusual UI replacement mods may implement input differently and could require additional compatibility handling.

---

# Version

**1.3.0**

### Highlights

* A and B autofire
* Configurable hold delay
* Configurable repeat rate
* Battle / world scope selection
* Optional D-Pad autofire
* Protection against duplicate directional scrolling
* Soft reset-safe input handling
