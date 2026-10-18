import {copyText} from "./copy_text"

// This screen is rendered by a controller, so copying does not depend on a LiveView hook.
window.addEventListener("click", async event => {
  const button = event.target.closest("[data-copy-recovery]")
  if (!button) return

  const status = document.getElementById("copy-status")
  const codes = Array.from(document.querySelectorAll("#recovery-codes li"), item => item.textContent.trim())
  button.disabled = true
  const copied = await copyText(codes.join("\n"))
  button.disabled = false
  status.textContent = copied ? button.dataset.copySuccess : button.dataset.copyError
})
