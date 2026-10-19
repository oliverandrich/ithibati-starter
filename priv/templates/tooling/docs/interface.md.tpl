# Interface

Pages render inside one of two layouts in `__MODULE__Web.Layouts`. The layouts are named
for the situation, not the shape. A page's shape is an attribute of `Layouts.member/1`.

## Choosing a layout

| Layout | Use it for | Examples |
| --- | --- | --- |
| `Layouts.auth/1` | One focused step without navigation | `/login`, `/setup`, `/invite`, `/account/verify`, `/recovery-codes` |
| `Layouts.member/1` | Every page a signed-in account reaches through the navigation | `/`, `/account/settings`, `/account/passkeys` |

`Layouts.auth/1` centres a narrow card under the wordmark. It takes a `title` and a
`subtitle`. Some of its steps run while signed in, such as confirming the identity.
`Layouts.auth_button/1` is the primary action on these screens.

`Layouts.member/1` needs `flash` and `current_account`. Its routes belong in the router's
`:members` live session, which requires a signed-in account.

`Layouts.app/1` and `PageController` come from the Phoenix scaffold. No route renders them.

## The member shell

From `lg`, the header and the navigation form a sidebar on the left. Below `lg`, the header
is a sticky top bar. A tab bar at the bottom appears once the navigation has two places.
The bars keep clear of the safe-area insets of phones with a notch.

The account menu sits in the header. It opens from an icon whose accessible name carries
the username. It leads to the settings and signs out. Add entries to the `<nav>` inside
`#user-menu`. On wide screens, the sidebar's foot links the source code when `source_url/0`
returns an address.

## Choosing a shape

`layout` selects the shape of a member page.

| `layout` | Use it for | Slots |
| --- | --- | --- |
| `:sidebar` (default) | One piece of content: an overview, a form, settings | the inner block |
| `:columns` | A list and the item selected from it: messages, entries, accounts | `:list` and `:detail` |

In `:columns`, both panes stand side by side from `lg` and scroll on their own. A phone
shows one pane. It shows the detail when `selected` is true, otherwise the list. Set
`selected` and `back` from the same assign, so the phone's back link returns to the list:

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

`:columns` renders nothing outside its slots. The panes fill the screen's height.

## Navigation

`__MODULE__Web.Navigation.items/1` lists the places. The sidebar and the tab bar render the
same list. Each entry is a map:

```elixir
%{section: :reports, label: gettext("Reports"), to: ~p"/reports", icon: :chart_bar}
```

`icon` names a [Lucide](https://lucide.dev/icons/) icon in snake case. A page passes its
entry's `section`, which marks the entry as the current page:

```heex
<Layouts.member flash={@flash} current_account={@current_account} section={:reports}>
```

`items/1` receives the signed-in account, so the list can depend on it. A page can pass its
own list through `navigation` instead.

## Settings

`/account/settings` is not a place in the navigation. The account menu leads to it. The
settings page and every page under it pass `section={:settings}`, which marks the menu.

The page groups its rows with `group/1` from `CoreComponents`. `group_link/1` is a row that
leads to another page. Its `detail` shows a short value, such as a count:

```heex
<.group id="settings-account" heading={gettext("Account & security")} tag="nav">
  <.group_link to={~p"/account/passkeys"} detail={@passkeys}>{gettext("Passkeys")}</.group_link>
</.group>
```

Add a group for each new topic. A page under the settings sets
`back={%{to: ~p"/account/settings", label: gettext("Settings")}}` and `breadcrumb`.

## Pages below another page

A page reached from another one sets `title` and `back`:

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

- `back` is `%{to: path, label: text}`. A phone's top bar links to it. Write `patch:`
  instead of `to:` to stay in the same LiveView.
- `title` appears in the top bar once the page's large heading has scrolled away.
- `breadcrumb` shows `back` and `title` as a breadcrumb on wide screens, which have no
  back link. It needs both.
  `:columns` never shows it, because the list stands beside the detail.

The large heading is the element with `data-large-title`. `.header` from `CoreComponents`
sets it. The `ShrinkTitle` hook in `assets/js/shrink_title.js` watches that heading. It
sets `data-shrunk` on `#app-header` while the heading is out of view.
