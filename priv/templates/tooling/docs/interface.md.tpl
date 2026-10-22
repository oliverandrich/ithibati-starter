# Interface

## Layouts

| Layout | For | Examples |
| --- | --- | --- |
| `Layouts.auth/1` | One step without navigation | `/login`, `/setup`, `/invite`, `/account/verify` |
| `Layouts.member/1` | Signed-in pages in the navigation | `/`, `/account/settings`, `/account/passkeys` |

`Layouts.auth/1` shows a narrow card under the wordmark, with `title` and `subtitle`.
`Layouts.auth_button/1` is its primary action.

`Layouts.member/1` needs `flash` and `current_account`. Its routes belong in the router's
`:members` live session. From `lg` it shows a sidebar; below, a top bar and, with two or more
places, a tab bar. The account menu in the header leads to the settings and signs out. Add
entries to the `<nav>` in `#user-menu`. The sidebar's foot links the source code when
`source_url/0` returns an address.

`Layouts.app/1` comes from the Phoenix scaffold and is unused.

## Shapes

| `layout` | For | Slots |
| --- | --- | --- |
| `:sidebar` (default) | One piece of content | inner block |
| `:columns` | A list and its selected item | `:list`, `:detail` |

From `lg`, `:columns` shows both panes side by side. A phone shows the detail when `selected`
is true, otherwise the list. Derive `selected` and `back` from the same assign:

```heex
<Layouts.member
  flash={@flash}
  current_account={@current_account}
  layout={:columns}
  selected={@item != nil}
  title={@item && @item.name}
  back={@item && %{to: ~p"/items", label: gettext("Items")}}
>
  <:list>...</:list>
  <:detail>...</:detail>
</Layouts.member>
```

## Navigation

`__MODULE__Web.Navigation.items/1` lists the places for the signed-in account. Sidebar and
tab bar render the same list:

```elixir
%{section: :reports, label: gettext("Reports"), to: ~p"/reports", icon: :chart_bar}
```

`icon` is a [Lucide](https://lucide.dev/icons/) name in snake case. A page passes its
`section` to mark the current entry. `navigation` overrides the list for one page.

## Subpages

A page below another sets `title` and `back`:

```heex
<Layouts.member
  flash={@flash}
  current_account={@current_account}
  section={:reports}
  title={gettext("Quarterly report")}
  back={%{to: ~p"/reports", label: gettext("Reports")}}
  breadcrumb
>
```

- `back` is `%{to: path, label: text}`, or `patch:` to stay in the LiveView. Phones show it
  as a back link.
- `title` appears in the top bar once the `.header` heading has scrolled away.
- `breadcrumb` shows both on wide screens. `:columns` ignores it.

## Settings

`/account/settings` is reached through the account menu, and its pages pass
`section={:settings}`. Rows come from `group/1`, and `group_link/1` links to a subpage:

```heex
<.group id="settings-account" heading={gettext("Account & security")} tag="nav">
  <.group_link to={~p"/account/passkeys"} detail={@passkeys}>{gettext("Passkeys")}</.group_link>
</.group>
```

An administrator page declares `on_mount {__MODULE__Web.Admin, :require_admin}`.
`__MODULE__.Accounts` checks the role again. `current_account.admin` stays current on every
page of the live session.

`confirm_dialog/1` asks before a change that cannot be undone. `CoreComponents` documents
its events.

## Colours

`assets/css/app.css` defines colour roles as Tailwind theme variables in `@theme`. Each role
becomes a utility for every colour property: `bg-surface`, `text-muted`, `border-edge`,
`outline-accent`, `ring-line`.

| Role | For |
| --- | --- |
| `ground`, `surface` | Page background, raised areas |
| `ink`, `muted` | Text, secondary text |
| `line`, `edge` | Dividers, input borders |
| `accent`, `on-accent` | Primary buttons and focus, text on them |
| `selection` | Hover and selected rows |
| `signal`, `signal-strong` | Brand colour, its shade for text and links |
| `danger`, `danger-surface` | Errors, destructive actions |
| `scrim` | The backdrop behind a dialog |

The dark block in `app.css` redefines the roles for `prefers-color-scheme: dark`. A template
that names roles needs no `dark:` variant. Write `text-muted`, not `text-neutral-600`: a
palette colour looks the same in both modes. The `signal` roles carry the brand colour.

Add a role to `@theme` and to the dark block, named for its use. `text-link` underlines a
link in running text.

## Type and shape

| Token | Size | For |
| --- | --- | --- |
| `text-meta` | 12px | Counts, group headings, secondary lines |
| `text-label` | 13px | Field labels, alerts, errors |
| `text-body` | 15px | Running text, rows |
| `text-title` | 22px | Titles of the `Layouts.auth/1` screens |
| `rounded-control` | 6px | Inputs, buttons, boxes |
