defmodule __MODULE__Web.InsideLive do
  @moduledoc """
  The home page behind `{:require_account, to: "/login"}`, where the application starts.
  """
  use __MODULE__Web, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.member flash={@flash} current_account={@current_account} section={:home}>
      <.header>
        {gettext("Welcome home")}
        <:subtitle>{gettext("Signed in as %{username}.", username: @current_account.username)}</:subtitle>
      </.header>
    </Layouts.member>
    """
  end
end
