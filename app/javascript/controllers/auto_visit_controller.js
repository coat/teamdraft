import { Controller } from "@hotwired/stimulus"

// On connect, navigate to the given URL via Turbo. Used on the
// post-draft "complete" state so every viewer ends up on the standings
// page after the final pick - even ones that only saw the morph
// (subscribers who weren't the picker themselves don't hit the
// controller-level redirect in DraftPicksController#create).
//
// We can't just redirect server-side because the auto-pick broadcast
// triggers a Turbo refresh of /draft; morphing across a redirect leaves
// stale clock UI on screen. Letting the morph finish, then visiting,
// gives a clean handoff.
export default class extends Controller {
  static values = { url: String }

  connect() {
    if (!this.urlValue) return
    if (window.Turbo) {
      window.Turbo.visit(this.urlValue)
    } else {
      window.location.href = this.urlValue
    }
  }
}
