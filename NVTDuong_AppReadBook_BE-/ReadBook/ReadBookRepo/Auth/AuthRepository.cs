using Dapper;
using Microsoft.Extensions.Configuration;
using MySqlConnector;

namespace ReadBookRepo.Auth;

public sealed class AuthRepository : IAuthRepository
{
    private readonly string _connectionString;

    public AuthRepository(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("Default")
            ?? throw new InvalidOperationException("ConnectionStrings:Default is not configured.");
    }

    public async Task<bool> EmailExistsAsync(string email, CancellationToken cancellationToken = default)
    {
        const string sql = "SELECT EXISTS(SELECT 1 FROM `user` WHERE email = @Email LIMIT 1);";
        await using var connection = new MySqlConnection(_connectionString);
        return await connection.ExecuteScalarAsync<bool>(new CommandDefinition(sql, new { Email = email }, cancellationToken: cancellationToken));
    }

    public async Task<AuthUserRecord?> GetByEmailAsync(string email, CancellationToken cancellationToken = default)
    {
        const string sql = """
            SELECT user_id AS UserId, full_name AS FullName, display_name AS DisplayName,
                   avatar_url AS AvatarUrl, username AS Username, email AS Email,
                   password_hash AS PasswordHash, role AS Role, status AS Status
            FROM `user`
            WHERE email = @Email
            LIMIT 1;
            """;
        await using var connection = new MySqlConnection(_connectionString);
        return await connection.QuerySingleOrDefaultAsync<AuthUserRecord>(
            new CommandDefinition(sql, new { Email = email }, cancellationToken: cancellationToken));
    }

    public async Task<AuthUserRecord?> GetByIdAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        const string sql = """
            SELECT user_id AS UserId, full_name AS FullName, display_name AS DisplayName,
                   avatar_url AS AvatarUrl, username AS Username, email AS Email,
                   password_hash AS PasswordHash, role AS Role, status AS Status
            FROM `user`
            WHERE user_id = @UserId
            LIMIT 1;
            """;
        await using var connection = new MySqlConnection(_connectionString);
        return await connection.QuerySingleOrDefaultAsync<AuthUserRecord>(
            new CommandDefinition(sql, new { UserId = userId }, cancellationToken: cancellationToken));
    }

    public async Task CreateAsync(AuthUserRecord user, CancellationToken cancellationToken = default)
    {
        const string sql = """
            INSERT INTO `user`
                (user_id, full_name, display_name, username, email, password_hash, role, status)
            VALUES
                (@UserId, @FullName, @DisplayName, @Username, @Email, @PasswordHash, @Role, @Status);
            """;
        await using var connection = new MySqlConnection(_connectionString);
        await connection.ExecuteAsync(new CommandDefinition(sql, user, cancellationToken: cancellationToken));
    }

    public async Task UpdateProfileAsync(Guid userId, string fullName, string? displayName, string? avatarUrl, CancellationToken cancellationToken = default)
    {
        const string sql = """
            UPDATE `user`
            SET full_name = @FullName,
                display_name = @DisplayName,
                avatar_url = @AvatarUrl
            WHERE user_id = @UserId;
            """;
        await using var connection = new MySqlConnection(_connectionString);
        await connection.ExecuteAsync(new CommandDefinition(sql,
            new { UserId = userId, FullName = fullName, DisplayName = displayName, AvatarUrl = avatarUrl },
            cancellationToken: cancellationToken));
    }

    public async Task UpdatePasswordAsync(Guid userId, string passwordHash, CancellationToken cancellationToken = default)
    {
        const string sql = "UPDATE `user` SET password_hash = @PasswordHash WHERE user_id = @UserId;";
        await using var connection = new MySqlConnection(_connectionString);
        await connection.ExecuteAsync(new CommandDefinition(sql,
            new { UserId = userId, PasswordHash = passwordHash }, cancellationToken: cancellationToken));
    }

    public async Task CreatePasswordResetAsync(PasswordResetRecord reset, CancellationToken cancellationToken = default)
    {
        const string sql = """
            INSERT INTO password_reset (reset_id, user_id, otp_hash, expires_at, attempt_count)
            VALUES (@ResetId, @UserId, @OtpHash, @ExpiresAt, 0);
            """;
        await using var connection = new MySqlConnection(_connectionString);
        await connection.ExecuteAsync(new CommandDefinition(sql, reset, cancellationToken: cancellationToken));
    }

    public async Task<PasswordResetRecord?> GetActivePasswordResetAsync(string email, CancellationToken cancellationToken = default)
    {
        const string sql = """
            SELECT pr.reset_id AS ResetId, pr.user_id AS UserId, pr.otp_hash AS OtpHash,
                   pr.expires_at AS ExpiresAt, pr.used_at AS UsedAt, pr.attempt_count AS AttemptCount
            FROM password_reset pr
            INNER JOIN `user` u ON u.user_id = pr.user_id
            WHERE u.email = @Email AND pr.used_at IS NULL
            ORDER BY pr.created_at DESC
            LIMIT 1;
            """;
        await using var connection = new MySqlConnection(_connectionString);
        return await connection.QuerySingleOrDefaultAsync<PasswordResetRecord>(
            new CommandDefinition(sql, new { Email = email }, cancellationToken: cancellationToken));
    }

    public async Task IncrementPasswordResetAttemptAsync(Guid resetId, CancellationToken cancellationToken = default)
    {
        const string sql = "UPDATE password_reset SET attempt_count = attempt_count + 1 WHERE reset_id = @ResetId;";
        await using var connection = new MySqlConnection(_connectionString);
        await connection.ExecuteAsync(new CommandDefinition(sql, new { ResetId = resetId }, cancellationToken: cancellationToken));
    }

    public async Task CompletePasswordResetAsync(Guid resetId, Guid userId, string passwordHash, CancellationToken cancellationToken = default)
    {
        await using var connection = new MySqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        const string updatePassword = "UPDATE `user` SET password_hash = @PasswordHash WHERE user_id = @UserId;";
        const string consumeReset = "UPDATE password_reset SET used_at = UTC_TIMESTAMP() WHERE reset_id = @ResetId AND used_at IS NULL;";
        await connection.ExecuteAsync(new CommandDefinition(updatePassword,
            new { UserId = userId, PasswordHash = passwordHash }, transaction, cancellationToken: cancellationToken));
        var consumed = await connection.ExecuteAsync(new CommandDefinition(consumeReset,
            new { ResetId = resetId }, transaction, cancellationToken: cancellationToken));
        if (consumed != 1)
            throw new InvalidOperationException("Password reset request is no longer active.");
        await transaction.CommitAsync(cancellationToken);
    }
}
