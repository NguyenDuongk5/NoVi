using System.Data.Common;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using ReadBookApi.Auth;
using ReadBookApi.Email;
using ReadBookRepo.Auth;
using ReadBookRepo.Novels;
using ReadBookRepo.Publishing;
using ReadBookRepo.Media;
using ReadBookRepo.PersonalReading;
using ReadBookRepo.Administration;
using ReadBookRepo.ContentReports;
using ReadBookApi.Media;
using ReadBookApi.Controllers.PersonalReading;
using ReadBookRepo.Base.IRepo;
using ReadBookRepo.Base.Repo;
using ReadBookRepo.IRepo.Category;
using ReadBookRepo.IRepo.Chapters;
using ReadBookRepo.Repo;
using ReadBookRepo.Repo.Category;
using ReadBookRepo.Repo.Chapters;
using ReadBookService.Auth;
using ReadBookService.Base;
using ReadBookService.IService.Category;
using ReadBookService.IService.Chapters;
using ReadBookService.IService.Home;
using ReadBookService.Service.Base;
using ReadBookService.Service.Category;
using ReadBookService.Service.Chapters;
using ReadBookService.Service.Home;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("Default");
if (string.IsNullOrWhiteSpace(connectionString))
    throw new InvalidOperationException(
        "ConnectionStrings:Default is missing. Configure it with user-secrets or ConnectionStrings__Default.");

if (builder.Environment.IsDevelopment())
{
    var parsedConnectionString = new DbConnectionStringBuilder { ConnectionString = connectionString };
    var database = parsedConnectionString.TryGetValue("Database", out var databaseValue)
        ? Convert.ToString(databaseValue)
        : null;

    if (!string.Equals(database, "novi_test", StringComparison.OrdinalIgnoreCase))
        throw new InvalidOperationException(
            "Development is restricted to the novi_test database. Configure ConnectionStrings:Default accordingly.");
}

builder.Services.AddControllers();
builder.Services.AddRouting(options => options.LowercaseUrls = true);
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header
    });
    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        [new OpenApiSecurityScheme
        {
            Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" }
        }] = Array.Empty<string>()
    });
});

var jwt = builder.Configuration.GetSection(JwtOptions.SectionName).Get<JwtOptions>()
    ?? throw new InvalidOperationException("Jwt configuration is missing.");
if (Encoding.UTF8.GetByteCount(jwt.Key) < 32)
    throw new InvalidOperationException("Jwt:Key must contain at least 32 bytes. Configure it with user-secrets or Jwt__Key.");

builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection(JwtOptions.SectionName));
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwt.Issuer,
            ValidateAudience = true,
            ValidAudience = jwt.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromSeconds(30)
        };
    });
builder.Services.AddAuthorization();

builder.Services.AddScoped<IAuthRepository, AuthRepository>();
builder.Services.AddScoped<INovelRepository, NovelRepository>();
builder.Services.AddScoped<IPublishingRepository, PublishingRepository>();
builder.Services.AddScoped<IMediaRepository, MediaRepository>();
builder.Services.AddScoped<IPersonalReadingRepository, PersonalReadingRepository>();
builder.Services.AddScoped<IAdministrationRepository, AdministrationRepository>();
builder.Services.AddScoped<IContentReportRepository, ContentReportRepository>();
builder.Services.Configure<ReadingOptions>(builder.Configuration.GetSection(ReadingOptions.SectionName));
builder.Services.Configure<FirebaseOptions>(builder.Configuration.GetSection(FirebaseOptions.SectionName));
builder.Services.Configure<MediaOptions>(builder.Configuration.GetSection(MediaOptions.SectionName));
builder.Services.AddHttpContextAccessor();
builder.Services.AddSingleton<FirebaseMediaStorage>();
builder.Services.AddSingleton<LocalMediaStorage>();
builder.Services.AddSingleton<IMediaStorage>(services =>
{
    var provider = services.GetRequiredService<Microsoft.Extensions.Options.IOptions<MediaOptions>>().Value.Provider;
    return provider.Equals("Local", StringComparison.OrdinalIgnoreCase)
        ? services.GetRequiredService<LocalMediaStorage>()
        : provider.Equals("Firebase", StringComparison.OrdinalIgnoreCase)
            ? services.GetRequiredService<FirebaseMediaStorage>()
            : throw new InvalidOperationException("Media:Provider must be Local or Firebase.");
});
builder.Services.AddScoped<OrphanMediaService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<ITokenService, JwtTokenService>();
builder.Services.Configure<SmtpOptions>(builder.Configuration.GetSection(SmtpOptions.SectionName));
builder.Services.AddScoped<IEmailSender, SmtpEmailSender>();

builder.Services.AddScoped(typeof(IMySqlBaseRepo<,>), typeof(MySqlBaseRepo<,>));
builder.Services.AddScoped<IMangaRepo, MysqlMangaRepo>();
builder.Services.AddScoped<ICategoryRepo, CategoryRepo>();
builder.Services.AddScoped<IChapterRepo, ChapterRepo>();
builder.Services.AddScoped(typeof(IBaseService<,>), typeof(BaseService<,>));
builder.Services.AddScoped<IMangaService, MangaService>();
builder.Services.AddScoped<ICategoryService, CategoryService>();
builder.Services.AddScoped<IChapterService, ChapterService>();

builder.Services.AddCors(options =>
{
    options.AddPolicy("DevCors", policy =>
    {
        policy
            .SetIsOriginAllowed(origin =>
                origin.StartsWith("http://localhost", StringComparison.OrdinalIgnoreCase) ||
                origin.StartsWith("https://localhost", StringComparison.OrdinalIgnoreCase))
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

var app = builder.Build();
app.Use(async (context, next) =>
{
    var path = context.Request.Path.Value?.TrimEnd('/').ToLowerInvariant();
    if (path is not null && (path == "/manga" || path.StartsWith("/manga/") ||
        path == "/chapter" || path.StartsWith("/chapter/") ||
        path == "/category" || path.StartsWith("/category/")))
    {
        context.Response.StatusCode = StatusCodes.Status410Gone;
        await context.Response.WriteAsJsonAsync(new { message = "Legacy CRUD API is disabled. Use /api/novels or /api/author endpoints." });
        return;
    }
    await next();
});
app.UseCors("DevCors");
if (!app.Environment.IsDevelopment())
    app.UseHttpsRedirection();
app.UseStaticFiles();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseAuthentication();
app.Use(async (context, next) =>
{
    if (context.User.Identity?.IsAuthenticated == true)
    {
        var idValue = context.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        if (!Guid.TryParse(idValue, out var userId))
        {
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            return;
        }
        var user = await context.RequestServices.GetRequiredService<IAuthRepository>()
            .GetByIdAsync(userId, context.RequestAborted);
        if (user is null || user.Status != 1)
        {
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            await context.Response.WriteAsJsonAsync(
                new { message = "Tài khoản đang bị khóa." }, context.RequestAborted);
            return;
        }
    }
    await next();
});
app.UseAuthorization();
app.MapControllers();
app.Run();
