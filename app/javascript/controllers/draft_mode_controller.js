import { Controller } from "@hotwired/stimulus"

// Toggles visibility of the live-only fields (scheduled date, pick clock)
// based on the currently selected draft_mode radio. Reads initial state on
// connect so we don't depend on a particular default.
export default class extends Controller {
  static targets = ["liveOnly"]

  connect() {
    this.sync()
  }

  sync() {
    const selected = this.element.querySelector('input[type="radio"][name$="[draft_mode]"]:checked')
    const isLive = !selected || selected.value === "live"
    this.liveOnlyTargets.forEach((el) => el.classList.toggle("hidden", !isLive))
  }
}
