import { Controller } from "@hotwired/stimulus"

// Submits the closest form when an input changes. Wire any control with
// `data-action="change->auto-submit#submit"` (or "input->auto-submit#submit"
// for text fields). Lets server-rendered filter forms feel instant
// without inline `onchange` handlers Phlex rejects as unsafe.
export default class extends Controller {
  submit(event) {
    const form = event.target.closest("form")
    if (form) form.requestSubmit()
  }
}
