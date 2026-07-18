import { Controller } from "@hotwired/stimulus"

// daisyUI dropdowns open/close purely via CSS :focus-within. This
// controller mirrors that state onto the trigger's aria-expanded and
// closes the menu on Escape by dropping focus. The click->focusTrigger
// action exists because Safari doesn't focus <button> elements on click,
// which would otherwise keep the CSS dropdown from ever opening there.
export default class extends Controller {
  static targets = ["trigger"]

  connect() {
    this.sync = this.sync.bind(this)
    this.element.addEventListener("focusin", this.sync)
    this.element.addEventListener("focusout", this.sync)
  }

  disconnect() {
    this.element.removeEventListener("focusin", this.sync)
    this.element.removeEventListener("focusout", this.sync)
  }

  sync() {
    // Wait a tick so document.activeElement reflects where focus settled -
    // during focusout it still points at the element being left.
    requestAnimationFrame(() => {
      const open = this.element.contains(document.activeElement)
      this.triggerTarget.setAttribute("aria-expanded", open.toString())
    })
  }

  focusTrigger() {
    this.triggerTarget.focus()
  }

  close() {
    if (this.element.contains(document.activeElement)) document.activeElement.blur()
  }
}
