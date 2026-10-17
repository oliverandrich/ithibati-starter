defmodule __MODULE__.RuntimeConfig do
  @moduledoc "Reads `config/runtime.exs` with chosen environment variables, as a boot would."

  import ExUnit.Callbacks, only: [on_exit: 1]

  # The variables a production boot requires. Mail stays off, so it asks for nothing more.
  @prod %{
    "SECRET_KEY_BASE" => String.duplicate("k", 64),
    "MAIL_ENABLED" => nil,
    "ACCOUNT_IDENTITY" => nil,
    "__APP_UPCASE___DATABASE" => nil,
    "DATABASE_PATH" => "/var/lib/__APP__/__APP__.db",
    "DATABASE_URL" => nil
  }

  @doc """
  Reads the file for `mix_env`. A `nil` value removes its variable. For `:prod`, `env` overrides
  the variables a production boot requires. The variables come back after the test, because a
  value exported in the developer's shell would otherwise decide the result.
  """
  def read(mix_env, env) do
    env = if mix_env == :prod, do: Map.merge(@prod, env), else: env
    previous = Map.new(env, fn {name, _value} -> {name, System.get_env(name)} end)
    on_exit(fn -> put_env(previous) end)
    put_env(env)

    Config.Reader.read!("config/runtime.exs", env: mix_env)
  end

  defp put_env(env) do
    Enum.each(env, fn
      {name, nil} -> System.delete_env(name)
      {name, value} -> System.put_env(name, value)
    end)
  end
end
