# Localization

Every HTTP request picks the first supported base language in `Accept-Language`, `en` or
`de`, and falls back to `en`. q-values are ignored. There is no stored preference. A
connected LiveView keeps its language until the next full page load.

`:locales` on the application and `:default_locale` on the Gettext backend configure the
choice. A new `live_session` needs the `{Locale, :set}` hook after the account is loaded.

## Translations

English is the source language. German catalogs live in `priv/gettext/de/LC_MESSAGES`.
After adding `gettext` calls, run `mix gettext.extract --merge` and fill in the PO files.
