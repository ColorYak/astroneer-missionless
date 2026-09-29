# Third-party tools

The build downloads these pinned dependencies into the ignored `.tools/` directory:

- [repak](https://github.com/trumank/repak), licensed under MIT or Apache-2.0. The version and checksum are pinned in `scripts/bootstrap.sh`.
- [.NET SDK](https://dotnet.microsoft.com/), subject to Microsoft's .NET terms. The version and checksum are pinned in `scripts/bootstrap.sh` and `global.json`.
- [UAssetAPI](https://github.com/atenfyr/UAssetAPI), licensed under MIT and restored through NuGet. The version is pinned in the project and package lock files.

These dependencies are not vendored in the repository.