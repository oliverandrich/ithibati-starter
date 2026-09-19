
## Invitation email

Generated with `--with-mail`. Accounts still use usernames and passkeys; the email
address is a delivery destination, not stored on the account or invitation.
The original manual-link form remains available.

- Development: inspect messages at `/dev/mailbox`; nothing is sent externally.
- Tests: `Swoosh.Adapters.Test`; no network delivery.
- Production: SMTP submission with authenticated STARTTLS (default port 587) and
  certificate verification. Configure these variables before booting a release:

| Variable | Purpose |
| --- | --- |
| `MAIL_FROM` | Verified sender email address |
| `SMTP_HOST` | SMTP submission server |
| `SMTP_PORT` | Submission port; default `587` |
| `SMTP_USERNAME` | SMTP username |
| `SMTP_PASSWORD` | SMTP password |
| `PHX_HOST` | Public hostname used for invitation links |

The sender display name defaults to the project name. Customize `InvitationEmail`
and `Mailer` for other delivery providers. `/dev/mailbox` is not compiled into
production. Keep development servers private: the preview contains usable links.

Any signed-in member can invite. Delivery is synchronous, after invitation creation
commits, limited to 10 attempts per member and 3 per recipient per hour per node.
Configure an edge/shared limit when deploying multiple nodes. Mail follows the
inviter's browser language; the recipient's browser chooses the acceptance page's language.

A successful response means the mail transport accepted the message, not confirmed
receipt. A failed delivery leaves the invitation valid; it may have been delivered
if the transport timed out. There are no automatic retries or background jobs.
Create a new invitation or use the manual link form after resolving delivery issues.
Never log invitation URLs. Release migration commands also load the mail runtime
configuration and therefore require the SMTP environment variables.
