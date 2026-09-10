import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]
  static values = { key: String }

  connect() {
    if (localStorage.getItem(this.keyValue)) {
      this.containerTarget.remove()
    }
  }

  close() {
    localStorage.setItem(this.keyValue, "1")
    this.containerTarget.remove()
  }
}
