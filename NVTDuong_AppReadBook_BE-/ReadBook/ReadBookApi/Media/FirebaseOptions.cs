namespace ReadBookApi.Media;
public sealed class FirebaseOptions
{
    public const string SectionName="Firebase";
    public string Bucket {get;init;}=string.Empty;
    public string EnvironmentPrefix {get;init;}="test";
    public string? PublicBaseUrl {get;init;}
    public bool AllowOrphanDelete {get;init;}=false;
}
