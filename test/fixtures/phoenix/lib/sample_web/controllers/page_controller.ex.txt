defmodule SampleWeb.PageController do
  use SampleWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
