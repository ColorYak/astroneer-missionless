#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$ROOT_DIR/.tools"
REPAK="$TOOLS_DIR/bin/repak"
DOTNET="$TOOLS_DIR/dotnet/dotnet"
PROJECT="$ROOT_DIR/src/AstroneerMissionless.Builder/AstroneerMissionless.Builder.csproj"
BUILDER_DLL="$ROOT_DIR/src/AstroneerMissionless.Builder/bin/Release/net8.0/AstroneerMissionless.Builder.dll"
PACKAGE_METADATA="$ROOT_DIR/package/metadata.json"

MOD_ID="$(sed -nE 's/^[[:space:]]*"mod_id"[[:space:]]*:[[:space:]]*"([^"]+)".*$/\1/p' "$PACKAGE_METADATA")"
MOD_VERSION="$(sed -nE 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*$/\1/p' "$PACKAGE_METADATA")"
TARGET_GAME_BUILD="$(sed -nE 's/^[[:space:]]*"game_build"[[:space:]]*:[[:space:]]*"([^"]+)".*$/\1/p' "$PACKAGE_METADATA")"
if [[ -z "$MOD_ID" || -z "$MOD_VERSION" || -z "$TARGET_GAME_BUILD" || "$MOD_ID" == *[!A-Za-z0-9._-]* || "$MOD_VERSION" == *[!A-Za-z0-9.+-]* ]]; then
    printf 'Package metadata contains a missing or filename-unsafe mod ID, version, or game build.\n' >&2
    exit 1
fi
OUTPUT_NAME="000-${MOD_ID}-${MOD_VERSION}_P.pak"

ASTRONEER_DIR="${ASTRONEER_DIR:-$HOME/.local/share/Steam/steamapps/common/ASTRONEER}"
ASTRONEER_SAVED_DIR="${ASTRONEER_SAVED_DIR:-$HOME/.local/share/Steam/steamapps/compatdata/361420/pfx/drive_c/users/steamuser/AppData/Local/Astro/Saved}"
GAME_PAK="$ASTRONEER_DIR/Astro/Content/Paks/pakchunk0-WindowsNoEditor.pak"
GAME_VERSION_FILE="$ASTRONEER_DIR/build.version"
INSTALL=false

if [[ "${1:-}" == "--install" ]]; then
    INSTALL=true
elif [[ $# -ne 0 ]]; then
    printf 'Usage: %s [--install]\n' "$0" >&2
    exit 2
fi

if [[ ! -f "$GAME_PAK" || ! -f "$GAME_VERSION_FILE" ]]; then
    printf 'Astroneer game files were not found under: %s\n' "$ASTRONEER_DIR" >&2
    printf 'Set ASTRONEER_DIR to the game installation directory.\n' >&2
    exit 1
fi

installed_game_build="$(sed -nE '1s/^([^[:space:]]+).*/\1/p' "$GAME_VERSION_FILE")"
if [[ "$installed_game_build" != "$TARGET_GAME_BUILD" ]]; then
    printf 'This source targets Astroneer %s, but the installed build is %s.\n' "$TARGET_GAME_BUILD" "$installed_game_build" >&2
    exit 1
fi

"$ROOT_DIR/scripts/bootstrap.sh"

export DOTNET_CLI_HOME="$TOOLS_DIR/dotnet-home"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
export NUGET_PACKAGES="$TOOLS_DIR/nuget"

WORK_DIR="$(mktemp --directory "$ROOT_DIR/.build.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
STOCK_DIR="$WORK_DIR/stock"
PACKAGE_DIR="$WORK_DIR/package"
mkdir -p "$STOCK_DIR" "$PACKAGE_DIR" "$ROOT_DIR/dist"

MISSION_ASSETS=(
    "Astro/Content/Missions/AutomationMissionPathData"
    "Astro/Content/Missions/CraftingAndExplorationMissionPathData"
    "Astro/Content/Missions/MissionLTEs"
    "Astro/Content/Missions/MissionPreExpansion01"
    "Astro/Content/Missions/MissionRails-DepotA"
    "Astro/Content/Missions/MissionRails-DepotB"
    "Astro/Content/Missions/MissionRails-DepotC"
    "Astro/Content/Missions/MissionSnails-Atrox"
    "Astro/Content/Missions/MissionSnails-Calidor"
    "Astro/Content/Missions/MissionSnails-Desolo"
    "Astro/Content/Missions/MissionSnails-Glacio"
    "Astro/Content/Missions/MissionSnails-Novus"
    "Astro/Content/Missions/MissionSnails-Sylva"
    "Astro/Content/Missions/MissionSnails-Vesania"
    "Astro/Content/Missions/MissionTrailhead01-Base"
    "Astro/Content/Missions/MissionTrailhead02-Gateways"
    "Astro/Content/Missions/MissionTrailhead03-Wanderer"
    "Astro/Content/Missions/MissionTrailhead04-Vehicle"
    "Astro/Content/Missions/MissionTrailhead05-Snails"
    "Astro/Content/Missions/MissionTrailhead06-Railways"
    "Astro/Content/Missions/MissionTrailhead07-Chronos"
    "Astro/Content/Missions/PowerMissionPathData"
    "Astro/Content/Missions/ResearchMissionPathData"
    "Astro/Content/U32_Expansion/MissionU32_Expansion"
    "Astro/Content/U36_Expansion/Missions/U36Missions_Biodome"
    "Astro/Content/U36_Expansion/Missions/U36Missions_Ending"
    "Astro/Content/U36_Expansion/Missions/U36Missions_LogisticsComplex"
    "Astro/Content/U36_Expansion/Missions/U36Missions_Museum"
    "Astro/Content/U36_Expansion/Missions/U36Missions_OrbitalPlatform"
    "Astro/Content/U36_Expansion/Missions/U36Missions_Wreck"
)

CATALOG_ASSETS=(
    "Astro/Content/Items/FaultFinder/FaultFinder_Crafted_IT"
    "Astro/Content/Items/ItemTypes/Components/ExtraLargeResourceCanister_IT"
    "Astro/Content/Items/ItemTypes/Components/ItemType_Scanner_Vault"
    "Astro/Content/Items/ItemTypes/Components/Seat_Large_B"
    "Astro/Content/U32_Expansion/Items/GlitchShelter/DCipher/GW_DCipher_IT"
    "Astro/Content/U32_Expansion/Items/Ruby/Ruby_IT"
    "Astro/Content/U36_Expansion/Items/Megadeconstructor/IT_MegastructureDeconstructor"
    "Astro/Content/U36_Expansion/Items/MusicalMushroom/IT_MusicalMushroom"
    "Astro/Content/U36_Expansion/Items/Shuttle/IT_PersonalBeepyShuttle"
    "Astro/Content/Vehicles/Hoverboard_IT"
    "Astro/Content/Vehicles/VTOL/VTOL_IT"
)
CATALOG_COSTS=(8000 12000 4000 2000 6000 6000 1500 1500 5000 10000 12000)

extract_asset() {
    local asset_path="$1"
    mkdir -p "$STOCK_DIR/$(dirname "$asset_path")"
    for extension in uasset uexp; do
        "$REPAK" get "$GAME_PAK" "$asset_path.$extension" > "$STOCK_DIR/$asset_path.$extension"
    done
}

"$DOTNET" restore "$PROJECT" --locked-mode
"$DOTNET" build "$PROJECT" --configuration Release --no-restore

for asset_path in "${MISSION_ASSETS[@]}"; do
    extract_asset "$asset_path"
    output_path="$PACKAGE_DIR/$asset_path.uasset"
    if [[ "$asset_path" == "Astro/Content/Missions/MissionTrailhead01-Base" ]]; then
        "$DOTNET" "$BUILDER_DLL" missions "$STOCK_DIR/$asset_path.uasset" "$output_path" "Trailhead01_1.1"
    else
        "$DOTNET" "$BUILDER_DLL" missions "$STOCK_DIR/$asset_path.uasset" "$output_path"
    fi
done

for index in "${!CATALOG_ASSETS[@]}"; do
    asset_path="${CATALOG_ASSETS[$index]}"
    extract_asset "$asset_path"
    "$DOTNET" "$BUILDER_DLL" catalog \
        "$STOCK_DIR/$asset_path.uasset" \
        "$PACKAGE_DIR/$asset_path.uasset" \
        "${CATALOG_COSTS[$index]}"
done

cp "$PACKAGE_METADATA" "$PACKAGE_DIR/metadata.json"
"$REPAK" pack --version V8B --mount-point ../../../ "$PACKAGE_DIR" "$WORK_DIR/$OUTPUT_NAME"
install -m 0644 "$WORK_DIR/$OUTPUT_NAME" "$ROOT_DIR/dist/$OUTPUT_NAME"

if [[ "$INSTALL" == true ]]; then
    mkdir -p "$ASTRONEER_SAVED_DIR/Paks"
    install -m 0644 "$WORK_DIR/$OUTPUT_NAME" "$ASTRONEER_SAVED_DIR/Paks/$OUTPUT_NAME"
    printf 'Installed %s\n' "$ASTRONEER_SAVED_DIR/Paks/$OUTPUT_NAME"
else
    printf 'Built %s\n' "$ROOT_DIR/dist/$OUTPUT_NAME"
fi