import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  navigate(event) {
    if (event.target.closest("a, button, input, select, textarea")) return
    window.location = this.element.dataset.href
  }
}
