import { Controller } from "@hotwired/stimulus"

// Replaces a <time> element's text with a date formatted in the visitor's
// browser timezone. The server emits an ISO8601 timestamp; the controller
// keeps that string in `datetime` (the spec-compliant attribute) and just
// rewrites the human-readable text.
export default class extends Controller {
  connect() {
    const iso = this.element.getAttribute("datetime")
    if (!iso) return
    const date = new Date(iso)
    if (isNaN(date)) return
    this.element.textContent = new Intl.DateTimeFormat(undefined, {
      weekday: "short",
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
      timeZoneName: "short"
    }).format(date)
  }
}
