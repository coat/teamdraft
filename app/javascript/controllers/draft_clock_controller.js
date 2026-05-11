import { Controller } from "@hotwired/stimulus"

// Renders a countdown to the deadline. The server is the source of truth;
// when the clock hits zero, PickClockJob has already fired (or is about to)
// and a Turbo refresh will replace this element with the new draft state.
//
// Driven by `deadlineValueChanged` rather than `connect` so when Turbo morphs
// the element with a new deadline the countdown restarts cleanly. Stimulus
// fires `<name>ValueChanged` on initial connect too, so this covers both
// first render and subsequent updates.
export default class extends Controller {
  static targets = ["display", "autopick"]
  static values = {
    deadline: String,
    warnAt: { type: Number, default: 15 },
    expiredText: { type: String, default: "auto-picking…" }
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
      this.displayTarget.textContent = this.expiredTextValue
      this.element.classList.add("draft-clock--expired")
      clearInterval(this.interval)
      return
    }
    this.displayTarget.textContent = `${remaining}s`
    if (remaining <= this.warnAtValue) {
      this.element.classList.add("draft-clock--warning")
      this.autopickTargets.forEach((el) => el.classList.remove("hidden"))
    }
  }
}
