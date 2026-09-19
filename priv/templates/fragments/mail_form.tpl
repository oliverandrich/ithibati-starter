      <section class="mt-8 border-t border-zinc-200 pt-6 dark:border-zinc-800">
        <h2 class="text-lg font-semibold">{gettext("Send an invitation by email")}</h2>
        <p class="mt-2 text-sm opacity-70">{gettext("The email address is only used for delivery. Your guest signs in with a passkey.")}</p>
        <.form for={%{}} id="mail-invitation-form" action={~p"/account/invitations"} class="mt-4">
          <.input name="invitation[username]" value="" label={gettext("Their username")} required pattern={Layouts.username_pattern()} />
          <.input name="invitation[email]" value="" type="email" label={gettext("Their email address")} required />
          <.button variant="primary">{gettext("Send invitation")}</.button>
        </.form>
      </section>
