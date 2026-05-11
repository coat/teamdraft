import { Controller } from "@hotwired/stimulus"

// Copies the value of the source input to the clipboard and briefly swaps
// the trigger button's label so the user gets feedback.
export default class extends Controller {
  static targets = ["source", "label"]
  static values = { copiedText: { type: String, default: "Copied!" } }

  async copy() {
    const text = this.sourceTarget.value
    try {
      await navigator.clipboard.writeText(text)
    } catch {
      this.sourceTarget.select()
      document.execCommand("copy")
    }
    this.flashCopied()
  }

  select() {
    this.sourceTarget.select()
  }

  flashCopied() {
    if (!this.hasLabelTarget) return
    const original = this.labelTarget.textContent
    this.labelTarget.textContent = this.copiedTextValue
    clearTimeout(this.resetTimeout)
    this.resetTimeout = setTimeout(() => {
      this.labelTarget.textContent = original
    }, 1500)
  }
}
