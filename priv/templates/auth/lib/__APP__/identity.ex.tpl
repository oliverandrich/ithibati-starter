defmodule __MODULE__.Identity do
  @moduledoc """
  What an account is called on this instance: a name, or an address.

  Ithibati binds the identifier field when it compiles. `ithibati_account/0` expands to a literal
  field name, and the option may not even be a module attribute, so two modes cannot be two
  fields. They are one column holding two kinds of thing, and the format is what tells them apart.

  `:format` is therefore not a literal at either schema, where it would be fixed for good. Both
  name this module instead, as `{__MODULE__.Identity, :format}`, and Ithibati asks it on every
  changeset. It requires the value, trims it, lowercases it, caps it at 254 graphemes and applies
  whatever shape this answers with — including the guards that skip minting a token and asking
  the accounts table for a value already refused.

  The mode is chosen once, before the first account. Turning an instance that already has accounts
  from names to addresses would leave every identifier it holds failing the new format.
  """
  alias Ithibati.Schema.Identifier

  @modes [:username, :email]

  @doc "Whether an account here is named or addressed."
  def mode do
    case Application.get_env(:__APP__, :account_identity, :username) do
      mode when mode in @modes ->
        mode

      other ->
        raise """
        config :__APP__, account_identity: #{inspect(other)}

        An account is named or addressed, so this is #{Enum.map_join(@modes, " or ", &inspect/1)}.
        """
    end
  end

  @doc "Whether an account here is addressed, which is also what makes an invitation deliverable."
  def email?, do: mode() == :email

  @doc """
  The shape an identifier has to have, which is the whole of what the two modes differ by.

  Named by both schemas as `format: {__MODULE__.Identity, :format}` rather than carried there as
  a literal, so Ithibati asks per changeset and an instance can answer.

  Nothing this module reaches for may live in this application. A module named at `use` is
  resolved when the schema compiles, so anything here would become a compile-time dependency of
  both schemas, and `mix xref --label compile-connected` refuses one that reaches further.
  """
  def format, do: if(email?(), do: Identifier.email_format(), else: Identifier.username_format())

  @doc """
  The sentence a refused identifier carries, in the mode that refused it.

  Ecto's default is "has invalid format", which names the fault and not the rule. Somebody who
  has just been refused is being asked to type something else, so the message says what.

  Written as the second half of a sentence, because that is where it ends up: Ecto puts the
  field's label in front of it. A message naming the field again reads "Email address must be an
  email address."
  """
  def format_message do
    if email?(),
      do: "must look like grace@example.org",
      else: "must be 1-30 lowercase letters, numbers or underscores"
  end

  @doc """
  Answers `:ok`, or raises when the instance asks for something it cannot do.

  An instance that addresses its accounts has to be able to reach them: in that mode the
  invitation is an address, and an address nobody can send to is an instance nobody can join.
  Asked where an instance starts, so a configuration like that is a refusal to boot rather than
  an operator finding out with a guest waiting.

  Names need no mailer. An invitation link is handed over however its sender likes.
  """
  def verify! do
    if email?() and not Application.get_env(:__APP__, :mail_enabled, false) do
      raise """
      config :__APP__, account_identity: :email

      An account here is an address, so an invitation has to be delivered to one, and nothing is
      configured to send it. Set MAIL_ENABLED and the SMTP variables beside it, or name accounts
      instead: config :__APP__, account_identity: :username. See docs/operations.md.
      """
    end

    :ok
  end
end
