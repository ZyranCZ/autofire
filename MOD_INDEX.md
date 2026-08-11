# ZyranCZ Gen1Recomp Mod Index

This repository also hosts the machine-readable index for ZyranCZ's public Gen1Recomp Pokémon mods.

## Add it in Gen1Recomp

Open **FIND MODS → Add an index** and enter:

```text
ZyranCZ/autofire
```

The direct feed URL is:

```text
https://raw.githubusercontent.com/ZyranCZ/autofire/main/site/data/index.json
```

The index lists the latest installable stable GitHub Release ZIP for every public ZyranCZ repository that contains a valid root-level Gen1Recomp `manifest.json`.

The published feed is `site/data/index.json`. `scripts/build-zyrancz-mod-index.mjs` can rebuild it from GitHub, and `.github/workflows/update-zyrancz-mod-index.yml` refreshes it on a schedule.
