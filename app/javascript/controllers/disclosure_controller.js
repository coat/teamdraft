import { Controller } from "@hotwired/stimulus"

// Toggles a panel's visibility. Trigger button rotates if it has the icon target.
// When given a key value, the expanded state is remembered in sessionStorage and
// restored on connect, so it survives Turbo re-renders of the surrounding markup
// (e.g. switching standings views or sorting a column on the season page).
export default class extends Controller {
  static targets = ["panel", "icon"]
  static values = { key: String }

  connect() {
    if (this.#remembered()) this.#setExpanded(true)
  }

  toggle(event) {
    const expanded = !this.panelTarget.classList.toggle("hidden")
    event.currentTarget.setAttribute("aria-expanded", String(expanded))
    if (this.hasIconTarget) {
      this.iconTarget.classList.toggle("rotate-90", expanded)
    }
    this.#remember(expanded)
  }

  #setExpanded(expanded) {
    this.panelTarget.classList.toggle("hidden", !expanded)
    const trigger = this.element.querySelector("[aria-controls]")
    if (trigger) trigger.setAttribute("aria-expanded", String(expanded))
    if (this.hasIconTarget) {
      this.iconTarget.classList.toggle("rotate-90", expanded)
    }
  }

  #remembered() {
    return this.keyValue !== "" && sessionStorage.getItem(this.#storageKey) === "1"
  }

  #remember(expanded) {
    if (this.keyValue === "") return
    if (expanded) {
      sessionStorage.setItem(this.#storageKey, "1")
    } else {
      sessionStorage.removeItem(this.#storageKey)
    }
  }

  get #storageKey() {
    return `disclosure:${this.keyValue}`
  }
}
