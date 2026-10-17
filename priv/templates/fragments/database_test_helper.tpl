# SQLite allows one writer, and each test holds a write transaction while it runs.
# So SQLite tests run one module at a time. The browser features test the interface, which
# behaves alike on both databases, so they run on SQLite alone.
if Application.fetch_env!(:__APP__, :database) == :sqlite,
  do: ExUnit.start(max_cases: 1),
  else: ExUnit.start(exclude: [:feature])
