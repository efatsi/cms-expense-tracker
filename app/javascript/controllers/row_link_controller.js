import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  navigate(event) {
    if (event.target.closest("a, button, input, select, textarea")) return
    if (this.element.dataset.newTab === "true" || event.metaKey || event.ctrlKey) {
      window.open(this.element.dataset.href, "_blank")
    } else {
      window.location = this.element.dataset.href
    }
  }
}
