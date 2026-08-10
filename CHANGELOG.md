# Changelog

## [1.3.1]

- Added native Gen1Recomp GitHub release update metadata.

All notable changes to this mod are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this mod uses
semantic versioning.

## [1.3.0]

### Added

- `DIRECTIONAL KEYS` option. When ON, UP/DOWN/LEFT/RIGHT autofire on the same
  shared delay and rate as the face buttons. Off by default.
- Directions are skipped on any screen that already repeats them for itself
  (`ListMenu` with `keyRepeat`, which `pokedex_plus` enables on five of its
  lists), so the cursor cannot advance twice per tick. A and B are unaffected
  there.

## [1.2.0]

### Added

- `WORLD ONLY` value for `AUTOFIRE IN`, the mirror of `BATTLE ONLY`: autofire
  runs everywhere except battles. A battle that begins while a button is held
  cuts autofire off on the spot rather than carrying the elapsed delay into it.

### Changed

- Mod renamed to **Autofire AB** in the manager. The mod id stays `a_autofire`,
  so saved option values carry over untouched.
- `AUTOFIRE BUTTONS` now defaults to `A AND B` instead of `A ONLY`. Anyone who
  already picked a mode keeps their choice; only fresh installs see the new
  default.

## [1.1.0]

### Added

- `AUTOFIRE BUTTONS` option with four modes: `OFF`, `A ONLY`, `B ONLY` and
  `A AND B`. B autofires on the same shared delay and rate as A.
- B's hold countdown is tracked separately from A's, so pressing B partway
  into an A hold gives it a full delay window instead of inheriting A's.

### Removed

- The `A AUTOFIRE` on/off toggle. `OFF` is now a value of `AUTOFIRE BUTTONS`,
  since a separate toggle and a button selector could disagree. A saved value
  for the old key is simply never read; nothing needs migrating.

## [1.0.0]

### Added

- Autofire for the A button, driven from the `input.step` hook.
- `HOLD BEFORE REPEAT` and `REPEAT EVERY` options, in milliseconds that map to
  whole logic steps.
- `AUTOFIRE IN` option to restrict autofire to battles.
