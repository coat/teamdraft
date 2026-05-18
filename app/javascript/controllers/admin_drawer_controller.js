import { Controller } from "@hotwired/stimulus"

// Uncheck the drawer toggle before Turbo caches the page snapshot, so the
// cached version is always saved with the drawer closed. Prevents a flash
// of the open drawer when Turbo previews a cached page on back-navigation.
export default class extends Controller {
  static targets = ["toggle"]

  connect() {
    this.beforeCache = () => {
      if (this.hasToggleTarget) this.toggleTarget.checked = false
    }
    document.addEventListener("turbo:before-cache", this.beforeCache)
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.beforeCache)
  }
}
