using UAssetAPI;
using UAssetAPI.ExportTypes;
using UAssetAPI.PropertyTypes.Objects;
using UAssetAPI.PropertyTypes.Structs;
using UAssetAPI.UnrealTypes;

if (args.Length < 2)
{
    PrintUsage();
    return 2;
}

switch (args[0])
{
    case "audit-catalog" when args.Length == 2:
        AuditCatalog(args[1]);
        break;
    case "audit-rewards" when args.Length == 2:
        AuditResearchRewards(args[1]);
        break;
    case "missions" when args.Length is 3 or 4:
        PatchMissions(args[1], args[2], args.Length == 4 ? args[3] : null);
        break;
    case "catalog" when args.Length == 4 && int.TryParse(args[3], out int unlockCost):
        PatchCatalog(args[1], args[2], unlockCost);
        break;
    default:
        PrintUsage();
        return 2;
}

return 0;

static void AuditCatalog(string inputPath)
{
    UAsset asset = new(inputPath, EngineVersion.VER_UE4_23);
    NormalExport? catalog = asset.Exports
        .OfType<NormalExport>()
        .SingleOrDefault(export => FindProperty<BoolPropertyData>(export.Data, "bHiddenUntilUnlocked") is not null
            && FindProperty<IntPropertyData>(export.Data, "UnlockCost") is not null);

    if (catalog is null)
    {
        Console.WriteLine($"{inputPath}\tuncatalogued");
        return;
    }

    bool hiddenUntilUnlocked = GetProperty<BoolPropertyData>(catalog.Data, "bHiddenUntilUnlocked").Value;
    int unlockCost = GetProperty<IntPropertyData>(catalog.Data, "UnlockCost").Value;
    Console.WriteLine($"{inputPath}\thidden={hiddenUntilUnlocked}\tcost={unlockCost}");
}

static void AuditResearchRewards(string inputPath)
{
    UAsset asset = new(inputPath, EngineVersion.VER_UE4_23);
    ArrayPropertyData? missions = asset.Exports
        .OfType<NormalExport>()
        .Select(export => FindProperty<ArrayPropertyData>(export.Data, "MissionsData"))
        .SingleOrDefault(property => property is not null);

    if (missions is null)
    {
        return;
    }

    foreach (StructPropertyData mission in missions.Value.OfType<StructPropertyData>())
    {
        string missionId = GetProperty<NamePropertyData>(mission.Value, "MissionId").Value.ToString();
        ArrayPropertyData rewards = GetProperty<ArrayPropertyData>(mission.Value, "ResearchRewards");
        foreach (ObjectPropertyData reward in rewards.Value.OfType<ObjectPropertyData>())
        {
            Import rewardImport = reward.ToImport(asset);
            Console.WriteLine($"{missionId}\t{rewardImport.PackageName}\t{rewardImport.ObjectName}");
        }
    }
}

static void PatchMissions(string inputPath, string outputPath, string? preservedMissionId)
{
    UAsset asset = new(inputPath, EngineVersion.VER_UE4_23);
    NormalExport missionExport = asset.Exports
        .OfType<NormalExport>()
        .Single(export => FindProperty<ArrayPropertyData>(export.Data, "MissionsData") is not null);
    ArrayPropertyData missions = GetProperty<ArrayPropertyData>(missionExport.Data, "MissionsData");

    if (preservedMissionId is null)
    {
        missionExport.Data.Remove(missions);
    }
    else
    {
        StructPropertyData preservedMission = missions.Value
            .OfType<StructPropertyData>()
            .Single(mission => GetProperty<NamePropertyData>(mission.Value, "MissionId").Value.ToString() == preservedMissionId);
        ArrayPropertyData nextMissions = GetProperty<ArrayPropertyData>(preservedMission.Value, "NextMissions");
        nextMissions.Value = [];
        missions.Value = [preservedMission];
    }

    WriteAsset(asset, outputPath);
    ValidateMissions(new UAsset(outputPath, EngineVersion.VER_UE4_23), preservedMissionId);
    Console.WriteLine(preservedMissionId is null
        ? $"Removed missions from {Path.GetFileName(inputPath)}."
        : $"Preserved {preservedMissionId} in {Path.GetFileName(inputPath)}.");
}

static void ValidateMissions(UAsset asset, string? preservedMissionId)
{
    ArrayPropertyData? missions = asset.Exports
        .OfType<NormalExport>()
        .Select(export => FindProperty<ArrayPropertyData>(export.Data, "MissionsData"))
        .SingleOrDefault(property => property is not null);

    if (preservedMissionId is null)
    {
        if (missions is not null)
        {
            throw new InvalidDataException("The written asset still contains mission data.");
        }

        return;
    }

    if (missions?.Value is not [StructPropertyData preservedMission])
    {
        throw new InvalidDataException("The written asset does not contain exactly one mission.");
    }

    string writtenMissionId = GetProperty<NamePropertyData>(preservedMission.Value, "MissionId").Value.ToString();
    ArrayPropertyData nextMissions = GetProperty<ArrayPropertyData>(preservedMission.Value, "NextMissions");
    if (writtenMissionId != preservedMissionId || nextMissions.Value.Length != 0)
    {
        throw new InvalidDataException("The written mission ID or continuation list is incorrect.");
    }
}

static void PatchCatalog(string inputPath, string outputPath, int unlockCost)
{
    UAsset asset = new(inputPath, EngineVersion.VER_UE4_23);
    NormalExport catalog = asset.Exports
        .OfType<NormalExport>()
        .Single(export => FindProperty<BoolPropertyData>(export.Data, "bHiddenUntilUnlocked") is not null
            && FindProperty<IntPropertyData>(export.Data, "UnlockCost") is not null);

    GetProperty<BoolPropertyData>(catalog.Data, "bHiddenUntilUnlocked").Value = false;
    GetProperty<IntPropertyData>(catalog.Data, "UnlockCost").Value = unlockCost;

    WriteAsset(asset, outputPath);
    ValidateCatalog(new UAsset(outputPath, EngineVersion.VER_UE4_23), unlockCost);
    Console.WriteLine($"Unlocked {Path.GetFileName(inputPath)} for {unlockCost} bytes.");
}

static void ValidateCatalog(UAsset asset, int unlockCost)
{
    NormalExport catalog = asset.Exports
        .OfType<NormalExport>()
        .Single(export => FindProperty<BoolPropertyData>(export.Data, "bHiddenUntilUnlocked") is not null
            && FindProperty<IntPropertyData>(export.Data, "UnlockCost") is not null);

    bool hiddenUntilUnlocked = GetProperty<BoolPropertyData>(catalog.Data, "bHiddenUntilUnlocked").Value;
    int writtenUnlockCost = GetProperty<IntPropertyData>(catalog.Data, "UnlockCost").Value;
    if (hiddenUntilUnlocked || writtenUnlockCost != unlockCost)
    {
        throw new InvalidDataException("The written catalog visibility or unlock cost is incorrect.");
    }
}

static T? FindProperty<T>(IEnumerable<PropertyData> properties, string name) where T : PropertyData =>
    properties.OfType<T>().SingleOrDefault(property => property.Name.ToString() == name);

static T GetProperty<T>(IEnumerable<PropertyData> properties, string name) where T : PropertyData =>
    FindProperty<T>(properties, name)
        ?? throw new InvalidDataException($"Property {name} ({typeof(T).Name}) was not found.");

static void WriteAsset(UAsset asset, string outputPath)
{
    string? outputDirectory = Path.GetDirectoryName(outputPath);
    if (!string.IsNullOrEmpty(outputDirectory))
    {
        Directory.CreateDirectory(outputDirectory);
    }

    asset.Write(outputPath);
}

static void PrintUsage()
{
    Console.Error.WriteLine("Usage:");
    Console.Error.WriteLine("  AstroneerMissionless.Builder audit-catalog <input.uasset>");
    Console.Error.WriteLine("  AstroneerMissionless.Builder audit-rewards <input.uasset>");
    Console.Error.WriteLine("  AstroneerMissionless.Builder missions <input.uasset> <output.uasset> [preserved-mission-id]");
    Console.Error.WriteLine("  AstroneerMissionless.Builder catalog <input.uasset> <output.uasset> <unlock-cost>");
}