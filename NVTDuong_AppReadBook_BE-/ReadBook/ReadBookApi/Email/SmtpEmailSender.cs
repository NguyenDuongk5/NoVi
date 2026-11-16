using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Options;
using ReadBookService.Auth;

namespace ReadBookApi.Email;

public sealed class SmtpEmailSender(IOptions<SmtpOptions> options) : IEmailSender
{
    private readonly SmtpOptions _options = options.Value;

    public async Task SendPasswordResetOtpAsync(string recipientEmail, string otp, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_options.Host) || string.IsNullOrWhiteSpace(_options.FromEmail))
            throw new InvalidOperationException("SMTP is not configured.");
        using var message = new MailMessage
        {
            From = new MailAddress(_options.FromEmail, _options.FromName),
            Subject = "Mã OTP đặt lại mật khẩu Novi",
            Body = $"Mã OTP của bạn là: {otp}. Mã có hiệu lực trong 10 phút.",
            IsBodyHtml = false
        };
        message.To.Add(recipientEmail);
        using var client = new SmtpClient(_options.Host, _options.Port)
        {
            EnableSsl = _options.EnableSsl,
            Credentials = new NetworkCredential(_options.Username, _options.Password)
        };
        cancellationToken.ThrowIfCancellationRequested();
        await client.SendMailAsync(message, cancellationToken);
    }
}
