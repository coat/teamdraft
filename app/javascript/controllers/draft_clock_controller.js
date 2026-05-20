import { Controller } from "@hotwired/stimulus"

// `M:SS` once we have at least a minute left, then `SSs` under a minute.
// Shorter remaining strings are easier to scan when the clock is critical.
function formatRemaining(seconds) {
  if (seconds < 60) return `${seconds}s`
  const minutes = Math.floor(seconds / 60)
  const rem = seconds % 60
  return `${minutes}:${rem.toString().padStart(2, "0")}`
}

// daisyUI's `.countdown` reveals digits via a CSS counter on `--value`.
// Update the custom property alongside aria-label and textContent so the
// animation runs and assistive tech still reads the current value.
function setCountdownValue(el, n) {
  el.style.setProperty("--value", n)
  el.setAttribute("aria-label", String(n))
  el.textContent = String(n)
}

// Renders a countdown to the deadline. The server is the source of truth;
// when the clock hits zero, PickClockJob has already fired (or is about to)
// and a Turbo refresh will replace this element with the new draft state.
//
// Driven by `deadlineValueChanged` rather than `connect` so when Turbo morphs
// the element with a new deadline the countdown restarts cleanly. Stimulus
// fires `<name>ValueChanged` on initial connect too, so this covers both
// first render and subsequent updates.
export default class extends Controller {
  static targets = ["display", "autopick", "days", "hours", "min", "sec"]
  static values = {
    deadline: String,
    warnAt: { type: Number, default: 15 },
    expiredText: { type: String, default: "auto-picking…" },
    mode: { type: String, default: "text" }
  }

  deadlineValueChanged() {
    clearInterval(this.interval)
    this.element.classList.remove("draft-clock--expired", "draft-clock--warning")
    this.autopickTargets.forEach((el) => el.classList.add("hidden"))
    this.tick()
    this.interval = setInterval(() => this.tick(), 1000)
  }

  // When the tab regains focus after a phone lock or app switch, JS timers
  // were paused — so the displayed clock is stale and the next Cable
  // broadcast may be minutes away. If the deadline has already passed,
  // pull a fresh page so the user sees the real draft state.
  connect() {
    this.onVisible = () => {
      if (document.visibilityState !== "visible") return
      if (new Date(this.deadlineValue) <= new Date()) {
        window.Turbo ? Turbo.visit(window.location.href, { action: "replace" }) : window.location.reload()
      }
    }
    document.addEventListener("visibilitychange", this.onVisible)
    window.addEventListener("pageshow", this.onVisible)
  }

  disconnect() {
    clearInterval(this.interval)
    document.removeEventListener("visibilitychange", this.onVisible)
    window.removeEventListener("pageshow", this.onVisible)
  }

  tick() {
    const remaining = Math.max(0, Math.round((new Date(this.deadlineValue) - new Date()) / 1000))
    if (remaining <= 0) {
      this.renderExpired()
      this.element.classList.add("draft-clock--expired")
      clearInterval(this.interval)
      return
    }
    this.render(remaining)
    if (this.modeValue !== "boxes" && remaining <= this.warnAtValue) {
      this.element.classList.add("draft-clock--warning")
      this.autopickTargets.forEach((el) => el.classList.remove("hidden"))
    }
  }

  render(remaining) {
    if (this.modeValue === "boxes") {
      const days = Math.floor(remaining / 86400)
      const hours = Math.floor((remaining % 86400) / 3600)
      const min = Math.floor((remaining % 3600) / 60)
      const sec = remaining % 60
      if (this.hasDaysTarget) setCountdownValue(this.daysTarget, days)
      if (this.hasHoursTarget) setCountdownValue(this.hoursTarget, hours)
      if (this.hasMinTarget) setCountdownValue(this.minTarget, min)
      if (this.hasSecTarget) setCountdownValue(this.secTarget, sec)
      return
    }
    if (this.modeValue === "seconds") {
      setCountdownValue(this.displayTarget, remaining)
      return
    }
    this.displayTarget.textContent = formatRemaining(remaining)
  }

  renderExpired() {
    if (this.modeValue === "boxes") {
      if (this.hasDaysTarget) setCountdownValue(this.daysTarget, 0)
      if (this.hasHoursTarget) setCountdownValue(this.hoursTarget, 0)
      if (this.hasMinTarget) setCountdownValue(this.minTarget, 0)
      if (this.hasSecTarget) setCountdownValue(this.secTarget, 0)
      return
    }
    if (this.modeValue === "seconds") {
      setCountdownValue(this.displayTarget, 0)
      return
    }
    this.displayTarget.textContent = this.expiredTextValue
  }
}
