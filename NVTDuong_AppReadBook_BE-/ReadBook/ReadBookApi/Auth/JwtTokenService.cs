using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using ReadBookService.Auth;

namespace ReadBookApi.Auth;

public sealed class JwtTokenService(IOptions<JwtOptions> options) : ITokenService
{
    private readonly JwtOptions _options = options.Value;

    public (string Token, DateTime ExpiresAtUtc) CreateAccessToken(AuthUserDto user)
    {
        if (Encoding.UTF8.GetByteCount(_options.Key) < 32)
            throw new InvalidOperationException("Jwt:Key must contain at least 32 bytes.");

        var expiresAt = DateTime.UtcNow.AddMinutes(_options.AccessTokenMinutes);
        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, user.UserId.ToString()),
            new Claim(JwtRegisteredClaimNames.Email, user.Email),
            new Claim(ClaimTypes.NameIdentifier, user.UserId.ToString()),
            new Claim(ClaimTypes.Name, user.DisplayName ?? user.FullName),
            new Claim(ClaimTypes.Role, user.Role.ToString())
        };
        var credentials = new SigningCredentials(
            new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_options.Key)),
            SecurityAlgorithms.HmacSha256);
        var token = new JwtSecurityToken(_options.Issuer, _options.Audience, claims,
            expires: expiresAt, signingCredentials: credentials);
        return (new JwtSecurityTokenHandler().WriteToken(token), expiresAt);
    }
}
