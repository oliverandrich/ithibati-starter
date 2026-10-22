# Authentication

The application pins Ithibati __ITHIBATI_VERSION__ at schema version 5. Accounts sign in with
passkeys, or with a recovery code when no passkey is at hand.

## Claim and invitations

An empty instance opens `/setup` only for an operator's code. The claim mode is fixed to
`config :ithibati, initial_claim: :operator_code`, and `__MODULE__.Claim` refuses to start
with any other. [Operations](operations.md) shows how to issue a code.

Every later account needs an invitation. Any signed-in member creates them on
`/account/invitations`. A link is shown once, expires and works once. Its token sits after
`#` in `/invite#TOKEN`, so no request carries it. A member withdraws their own invitations;
an administrator withdraws any.

## Named or addressed

An account is named or addressed. `__MODULE__.Identity` answers which from
`ACCOUNT_IDENTITY`.

- **Named**: the inviter writes a note and passes the link on. The invitee chooses the
  username.
- **Addressed**: the link is mailed to the invitee, which proves the address. A failed
  delivery is reported, and the link can still be passed on by hand.

The identifier field is fixed when a schema compiles, so both schemas take `:format` from
`__MODULE__.Identity` at runtime.

## Administrators

The account that claims the instance is an administrator. `/accounts` lets an administrator
grant or revoke the role and remove accounts, each confirmed with a passkey. Nobody revokes
their own role or removes their own account, so one administrator remains. `bin/grant-admin`
grants the role from the host.

Removing an account deletes its passkeys and recovery codes, revokes its sessions and
withdraws its open invitations.

## Account security

- `/account/passkeys` adds, renames and removes passkeys. The last one stays.
- `/account/recovery-codes` shows the unused count and replaces all codes after
  confirmation. New codes are shown once.
- Adding a passkey or new recovery codes needs a confirmation from the last five minutes.
- **Sign out on all devices** revokes every session and disconnects open LiveViews.
- Session cookies are encrypted, because they briefly carry recovery codes. They last as
  long as Ithibati's `session_validity`.
- `:filter_parameters` keeps tokens, codes and WebAuthn credentials out of the request log.

## Rate limits

| Budget | Default | Counted per |
| --- | --- | --- |
| `setup` | 10 per minute | Visitor address |
| `recovery` | 10 per minute | Visitor address |
| `ceremony` | 120 per minute | Visitor address |
| `invite` | 20 per day | Signed-in account |

Change them in the application config:

```elixir
config :__APP__, :auth_rate_limits,
  recovery: {10, 60}, ceremony: {120, 60}, setup: {10, 60}, invite: {20, 86_400}
```

A refusal answers HTTP 429 with `Retry-After`. An invitation attempt costs one even when the
form is invalid. One IPv6 `/64` counts as one visitor. The counters live in memory on each
node, hold up to 10,000 keys and reset on restart. A cluster needs a shared limiter.

[Operations](operations.md) covers the proxy setup, the hourly auth cleanup and `TRUSTED_PROXIES`.
