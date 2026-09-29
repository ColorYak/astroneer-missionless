#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$ROOT_DIR/.tools"
DOWNLOADS_DIR="$TOOLS_DIR/downloads"

REPAK_VERSION="0.2.3"
REPAK_ARCHIVE="repak_cli-x86_64-unknown-linux-gnu.tar.xz"
REPAK_SHA256="933bdb8e26f34e8fd70ea50201efca39df041de58aa83b1cd6eb83da124a2046"
REPAK_URL="https://github.com/trumank/repak/releases/download/v${REPAK_VERSION}/${REPAK_ARCHIVE}"
REPAK_DIR="$TOOLS_DIR/repak-${REPAK_VERSION}"

DOTNET_VERSION="8.0.425"
DOTNET_ARCHIVE="dotnet-sdk-${DOTNET_VERSION}-linux-x64.tar.gz"
DOTNET_SHA512="934b8060a7190e5909ad1fd0785db542f487b3bbf6cdd14826b02095fdd0d0394298b1634085eff302928fccc33f7c1a7253e9b87df555fc36fce819bcd2e798"
DOTNET_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_VERSION}/${DOTNET_ARCHIVE}"
DOTNET_DIR="$TOOLS_DIR/dotnet"
BIN_DIR="$TOOLS_DIR/bin"

if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
    printf 'This bootstrap currently supports Linux x86-64.\n' >&2
    exit 1
fi

for command_name in curl tar sha256sum sha512sum; do
    if ! command -v "$command_name" >/dev/null; then
        printf 'Required command is unavailable: %s\n' "$command_name" >&2
        exit 1
    fi
done

mkdir -p "$DOWNLOADS_DIR"

if [[ ! -x "$REPAK_DIR/repak" ]]; then
    archive_path="$DOWNLOADS_DIR/$REPAK_ARCHIVE"
    curl --fail --location --retry 3 "$REPAK_URL" --output "$archive_path"
    printf '%s  %s\n' "$REPAK_SHA256" "$archive_path" | sha256sum --check --status
    mkdir -p "$REPAK_DIR"
    tar --extract --xz --file "$archive_path" --strip-components 1 --directory "$REPAK_DIR"
fi

if [[ ! -x "$DOTNET_DIR/dotnet" ]]; then
    archive_path="$DOWNLOADS_DIR/$DOTNET_ARCHIVE"
    curl --fail --location --retry 3 "$DOTNET_URL" --output "$archive_path"
    printf '%s  %s\n' "$DOTNET_SHA512" "$archive_path" | sha512sum --check --status
    mkdir -p "$DOTNET_DIR"
    tar --extract --gzip --file "$archive_path" --directory "$DOTNET_DIR"
fi

mkdir -p "$BIN_DIR"
ln -sfn "../repak-${REPAK_VERSION}/repak" "$BIN_DIR/repak"

printf 'repak %s and .NET SDK %s are ready in %s\n' "$REPAK_VERSION" "$DOTNET_VERSION" "$TOOLS_DIR"