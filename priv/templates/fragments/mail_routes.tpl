  if Application.compile_env(:__APP__, :dev_routes, false) do
    scope "/dev" do
      pipe_through :browser
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
