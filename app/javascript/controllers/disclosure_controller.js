import { Controller } from "@hotwired/stimulus"

// Toggles a panel's visibility. Trigger button rotates if it has the icon target.
export default class extends Controller {
  static targets = ["panel", "icon"]

  toggle(event) {
    const expanded = !this.panelTarget.classList.toggle("hidden")
    event.currentTarget.setAttribute("aria-expanded", String(expanded))
    if (this.hasIconTarget) {
      this.iconTarget.classList.toggle("rotate-90", expanded)
    }
  }
}
