defmodule __MODULE__Web.Navigation do
  @moduledoc """
  The places `Layouts.member/1` links to: the sidebar from `lg`, the tab bar below it.

  Add an entry for each page that belongs in the navigation. A page passes the entry's `section`
  to `Layouts.member/1`, which marks it. `icon` names a Lucide icon, such as `:house`.
  The tab bar appears once there are two entries.
  """
  use __MODULE__Web, :verified_routes
  use Gettext, backend: __MODULE__Web.Gettext

  @doc "Returns the places the signed-in account can reach."
  def items(_account) do
    [
      %{section: :home, label: gettext("Home"), to: ~p"/", icon: :house}
    ]
  end
end
