# Astroneer: Missionless

## Credit

Missionless is based on [No Stock Missions](https://thunderstore.io/c/astroneer/p/yzch/No_Stock_Missions/) by **yzch**.

## What it changes

The mod removes the stock mission set except for the opening mission that supplies the oxygenator.

Items only available through missions are added to the catalog:

| Catalog item | Byte cost | Price basis |
| --- | ---: | --- |
| Fault Finder | 8,000 | Project choice |
| XL Resource Canister | 12,000 | Original mod |
| Vault Scanner | 4,000 | Current game value |
| Large Seat B | 2,000 | Original mod |
| D-Cipher | 6,000 | Project choice |
| Ruby | 6,000 | Original mod |
| Megastructure Deconstructor | 1,500 | Current game value |
| Musical Mushroom | 1,500 | Current game value |
| Personal Beepy Shuttle | 5,000 | Project choice |
| Hoverboard | 10,000 | Original mod |
| VTOL | 12,000 | Original mod |

The project-choice prices are supposed to roughly match items of similar utility.

## Install

Requirements:

- Linux x86-64
- Astroneer installed through Steam
- `curl`
- `tar`
- `sha256sum`
- `sha512sum`

Keep one mission-data override active and replace the original No Stock Missions PAK with this package. From the repository root, build and install it with:

```bash
./build.sh --install
```

On its first run, the script downloads pinned versions of `repak` and the .NET 8 SDK into `.tools/`, then restores UAssetAPI through NuGet. It checks the installed `build.version` before extracting assets.

To build the PAK without installing it, run:

```bash
./build.sh
```

The output is written to:

```text
dist/000-AstroneerMissionless-1.0.0_P.pak
```

The default game directory is:

```text
~/.local/share/Steam/steamapps/common/ASTRONEER
```

For another Steam library, set `ASTRONEER_DIR`:

```bash
ASTRONEER_DIR="/path/to/ASTRONEER" ./build.sh --install
```

The default save-data directory is:

```text
~/.local/share/Steam/steamapps/compatdata/361420/pfx/drive_c/users/steamuser/AppData/Local/Astro/Saved
```

For another Proton prefix or platform layout, set `ASTRONEER_SAVED_DIR`:

```bash
ASTRONEER_SAVED_DIR="/path/to/Astro/Saved" ./build.sh --install
```

Both paths can be set together:

```bash
ASTRONEER_DIR="/path/to/ASTRONEER" \
ASTRONEER_SAVED_DIR="/path/to/Astro/Saved" \
./build.sh --install
```

It may work for multiplayer by installing the same package version for the host and each client, but this is untested.
