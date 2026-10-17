// An invitation link carries its token in the fragment, which no request sends and no access log
// records. The token leaves the address before the LiveView socket joins, because the join sends
// the page's URL. The tab keeps it, so a reload still opens the invitation.
// app.js is deferred, so the invitation page's hook element exists when this runs.
const KEY = "invitation-token"
const page = () => document.getElementById("invitation-link") !== null
let held = ""

if (page() && window.location.hash.length > 1) {
  // Tokens are base64url, so the fragment needs no decoding.
  held = window.location.hash.slice(1)
  try { sessionStorage.setItem(KEY, held) } catch {}
  history.replaceState(history.state, "", window.location.pathname + window.location.search)
}

// Another link opened in the same tab changes only the fragment, which reloads nothing.
window.addEventListener("hashchange", () => {
  if (page()) window.location.reload()
})

function stored() {
  if (held) return held
  try { return sessionStorage.getItem(KEY) || "" } catch { return "" }
}

export const InvitationLink = {
  mounted() {
    this.handleEvent("invitation-token-forget", () => {
      held = ""
      try { sessionStorage.removeItem(KEY) } catch {}
    })
    this.send()
  },
  // A rejoin mounts the LiveView again, and it waits for the token once more.
  reconnected() { this.send() },
  send() { this.pushEvent("invitation-token", {token: stored()}) }
}
