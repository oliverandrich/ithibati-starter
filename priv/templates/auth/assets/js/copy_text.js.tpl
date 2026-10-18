// Puts text on the clipboard. Answers false when there is no clipboard, as on a page outside a
// secure context, or when the browser refuses the write.
export async function copyText(text) {
  if (!navigator.clipboard) return false
  try {
    await navigator.clipboard.writeText(text)
    return true
  } catch {
    return false
  }
}

// A button that copies the text in its `data-copy-text`. It names its status line in
// `data-copy-status` and the two sentences in `data-copy-success` and `data-copy-error`. The
// status line carries `phx-update="ignore"`, so a patch keeps the sentence. After a copy the
// button carries `data-copied` for two seconds, which shows a check instead of the copy icon.
// Attributes go through `js()`, so a patch that arrives meanwhile keeps them. Give each text its
// own button id, so a new text mounts a new hook without the last one's check.
export const CopyText = {
  mounted() {
    this.onClick = async () => {
      const {copyText: text, copyStatus, copySuccess, copyError} = this.el.dataset

      this.js().setAttribute(this.el, "disabled", "")
      const copied = await copyText(text)
      // The button may have been removed while the clipboard answered.
      if (!this.el.isConnected) return
      this.js().removeAttribute(this.el, "disabled")

      const status = document.getElementById(copyStatus)
      if (status) status.textContent = copied ? copySuccess : copyError

      if (copied) {
        this.js().setAttribute(this.el, "data-copied", "")
        clearTimeout(this.reset)
        this.reset = setTimeout(() => this.js().removeAttribute(this.el, "data-copied"), 2000)
      }
    }
    this.el.addEventListener("click", this.onClick)
  },
  destroyed() {
    clearTimeout(this.reset)
    this.el.removeEventListener("click", this.onClick)
  }
}
