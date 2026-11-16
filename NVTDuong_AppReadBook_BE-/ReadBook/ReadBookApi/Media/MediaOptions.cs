namespace ReadBookApi.Media;

public sealed class MediaOptions
{
    public const string SectionName = "Media";
    public string Provider { get; init; } = "Firebase";
    public string EnvironmentPrefix { get; init; } = "test";
    public string LocalRoot { get; init; } = "uploads";
    public string? PublicBaseUrl { get; init; }
    public bool AllowOrphanDelete { get; init; }
}
