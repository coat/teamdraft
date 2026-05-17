import { Controller } from "@hotwired/stimulus"

// Wraps a <input type="datetime-local"> with:
//   1. A connect-time conversion from the server's naive UTC string into
//      the browser's local time, so the user sees their wall-clock value
//      and not a UTC time that's hours off.
//   2. A hidden field carrying the browser's IANA timezone name so the
//      server can re-interpret the submitted local string correctly.
//   3. A hint line under the input showing both the friendly zone short
//      name (e.g. PST) and the IANA name (e.g. America/Los_Angeles).
//
// Expected markup:
//   <div data-controller="local-datetime-field">
//     <input type="datetime-local" data-local-datetime-field-target="input"
//            data-action="change->local-datetime-field#update">
//     <input type="hidden" name="…[time_zone]"
//            data-local-datetime-field-target="timezone">
//     <span data-local-datetime-field-target="hint"></span>
//   </div>
export default class extends Controller {
  static targets = ["input", "timezone", "hint"]

  connect() {
    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone || ""
    if (this.hasTimezoneTarget) this.timezoneTarget.value = zone
    if (this.hasInputTarget) this.convertInputToLocal()
    this.renderHint(zone)
  }

  update() {
    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone || ""
    this.renderHint(zone)
  }

  convertInputToLocal() {
    const raw = this.inputTarget.value
    if (!raw) return
    // The server emits "YYYY-MM-DDTHH:MM" in UTC (no offset). Re-parse it
    // as UTC, then rewrite the input with the same instant in local time.
    const date = new Date(`${raw}Z`)
    if (isNaN(date)) return
    this.inputTarget.value = toLocalDatetimeString(date)
  }

  renderHint(zone) {
    if (!this.hasHintTarget) return
    const date = this.hasInputTarget && this.inputTarget.value
      ? new Date(this.inputTarget.value)
      : new Date()
    const short = shortZoneName(date)
    const parts = [short, zone].filter(Boolean)
    this.hintTarget.textContent = `Your timezone: ${parts.join(" · ")}`
  }
}

function toLocalDatetimeString(date) {
  const pad = (n) => n.toString().padStart(2, "0")
  return [
    date.getFullYear(),
    "-",
    pad(date.getMonth() + 1),
    "-",
    pad(date.getDate()),
    "T",
    pad(date.getHours()),
    ":",
    pad(date.getMinutes())
  ].join("")
}

function shortZoneName(date) {
  try {
    const parts = new Intl.DateTimeFormat(undefined, { timeZoneName: "short" }).formatToParts(date)
    return parts.find((p) => p.type === "timeZoneName")?.value || ""
  } catch (_) {
    return ""
  }
}
