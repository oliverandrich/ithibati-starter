# Authentication

The application pins Ithibati 0.5.0 and applies its schema version 3. On an empty
database, an operator-issued code must unlock `/setup` before the first account
can register a username and passkey. Issue
the code after migration as described in [Operations](operations.md); enter it over
HTTPS. The code is printed only by that command, stored only as a digest, and
consumed with the first account claim. Later registrations require a valid
invitation; every authenticated member can create links on `/`. Links are
shown once, expire, and are accepted once. There is no administrator role or mail
delivery; share links through your chosen channel.

Sessions are revocable and cookies are encrypted because they temporarily carry
recovery codes. Recovery codes are displayed once after registration. Adapt the
account policy to the application.

The public auth screens are `/login` (passkey), `/recover` (recovery code), and
`/setup` (first account only). Signed-in visitors go to `/`. The project name and
auth appearance live in `Layouts.auth/1`; the one-time code screen includes a copy
button and a manual-copy fallback when clipboard permission is unavailable.

The member header in `Layouts.member/1` takes `current_account` and displays the
username menu. `/account/passkeys` supports enrollment, naming and removal; the
last passkey cannot be removed. `/account/recovery-codes` shows the unused count
and requires explicit confirmation before replacing every old code. New codes
use the same one-time display and copy flow as registration.

Passkey changes and code regeneration use controller requests with a freshly
validated session and CSRF protection. Enrollment binds the challenge to the
signed-in account and checks the account again when registration completes.
Adding a passkey or generating new recovery codes also requires a confirmation
with the current account's passkey or recovery code within the last five minutes.
Enrollment rechecks confirmation at both challenge creation and completion. All settings and feedback are translated into English
and German.

## Authentication limits and maintenance

`AuthRateLimit` allows 10 recovery requests and 120 other ceremony requests per
peer IP in a 60-second fixed window. Responses use HTTP 429, `Retry-After`, and a
translated ceremony message. The manual-link form allows 10 creation attempts per
signed-in account per hour; invalid attempts also use that budget. A rejected attempt
creates no invitation and shows a translated message. Configure `:auth_rate_limits`
on the application as
`[recovery: {10, 60}, ceremony: {120, 60}, setup: {10, 60}, manual_invitation: {10, 3600}]`
(positive counts and seconds). The manual limit is separate from the mail sender
and recipient limits when mail delivery is enabled; neither spends the other's budget.
The setup-code form allows 10 submissions per peer IP per minute by default.
Replacing a code revokes earlier authorizations but does not reset that budget.
The form redirects with `Retry-After` and a translated message when the budget
is exhausted.

The supervised in-memory counters are atomic and bounded to 10,000 keys per node;
their windows expire and a restart resets them. Ceremony and setup limits use
`conn.remote_ip` and do not trust arbitrary `X-Forwarded-For` headers. Behind a
reverse proxy, configure trusted proxy handling or enforce client-IP limits at the
edge. Multiple nodes need a shared client-IP limit, and a shared account-keyed
limiter if the manual-link quota must hold across nodes. These defaults are not a
distributed rate-limit service.

The passkey settings page provides **Sign out on all devices**, including the
current session. Ithibati revokes stored sessions and broadcasts disconnects to
live sockets. Passkeys remain valid for future logins.

Schedule [auth cleanup](operations.md#authentication-maintenance) on the running
release. It removes expired sessions, abandoned challenges and expired,
unaccepted invitations. Valid credentials, recovery codes and accepted invitations
are preserved.

Phoenix request logs filter passwords, secrets, tokens, recovery codes and WebAuthn
credentials through `:filter_parameters`. Preserve this filtering when adding logging.
