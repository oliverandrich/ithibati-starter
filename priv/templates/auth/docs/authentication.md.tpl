# Authentication

The application pins Ithibati 0.6.0 and applies its schema version 4. On an empty
database, an operator-issued code must unlock `/setup` before the first account
can register a username and passkey. Issue
the code after migration as described in [Operations](operations.md); enter it over
HTTPS. The code is printed only by that command, stored only as a digest, and
consumed with the first account claim. Later registrations require a valid
invitation; every authenticated member can create links on `/`. Links are
shown once, expire, and are accepted once. There is no administrator role.

The same page lists what is outstanding: for whom, by whom and when it runs
out. Any member can take any of them back, and the link stops working at once.
This example has no way to remove an account, so that is the only moment
anybody has a say over who joins. `__MODULE__.Invitations` holds the queries,
and they come from Ithibati rather than being written again: `pending_query/0`
is the predicate `fetch/1` uses, and `withdraw/1` rechecks the acceptance
inside its delete.

An account is named or addressed, which `__MODULE__.Identity` answers from
`ACCOUNT_IDENTITY`. Named is the default: the link is shared through whatever
channel its sender likes. Addressed means the invitee's identifier is an email
address, the link is delivered to it, and that delivery is what proves the address.
Both schemas leave Ithibati's `:format` off and take it from the mode instead,
because the identifier field itself is fixed when the schema compiles. An instance
that addresses accounts without a mail configuration does not start. A delivery
that fails is reported and the link stays shareable by hand. See
[Operations](operations.md) for the variables.

The claim mode is fixed to `config :ithibati, initial_claim: :operator_code`, and
`__MODULE__.Claim` checks it where the application starts. Ithibati's `:open` mode is
therefore a refusal to boot rather than a setup page offering a field nobody can satisfy.

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
visitor address in a 60-second fixed window. Responses use HTTP 429, `Retry-After`, and a
translated ceremony message. Making an invitation allows 20 per signed-in account in a
24-hour window. Configure `:auth_rate_limits` on the application as
`[recovery: {10, 60}, ceremony: {120, 60}, setup: {10, 60}, invite: {20, 86_400}]`
(positive counts and seconds). A refused inviter is told how long to wait, in minutes
for a window shorter than an hour and in hours otherwise.

The invitation budget is counted against the account through `AuthRateLimit.key/2`,
not the browser: a session, a name or an address would each let the same person start
over. It is spent before the form is validated, so an attempt that fails for any other
reason still costs one; otherwise the budget is emptied by typing nonsense. A refusal
writes no invitation, sends nothing, and leaves a link already on screen where it is,
because that link exists nowhere else. A day rather than an hour, because what this
guards against is not a burst but an account somebody else is holding, spending the
operator's mail credentials at a steady drip.
The setup-code form allows 10 submissions per visitor address per minute by default.
Replacing a code revokes earlier authorizations but does not reset that budget.
The form redirects with `Retry-After` and a translated message when the budget
is exhausted.

The supervised in-memory counters are atomic and bounded to 10,000 keys per node;
their windows expire and a restart resets them. Ceremony and setup limits count per
`conn.remote_ip`, which `__MODULE__Web.ClientIp` takes from `X-Forwarded-For` only on a
connection from the loopback or an address named in `TRUSTED_PROXIES`; see
[Operations](operations.md). No other forwarding header is read, because a proxy
hands those through exactly as the visitor wrote them. One IPv6 allocation is one
budget: `ClientIp.bucket/1` counts the `/64`, which a visitor cannot rotate out of. Behind a reverse proxy every
request otherwise arrives from one socket, and one stranger would spend the budget
of everybody sharing it.
Multiple nodes need a shared client-IP limit, and a shared account-keyed
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
