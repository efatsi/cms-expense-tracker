import { Controller } from "@hotwired/stimulus"
import List from "list.js"

export default class extends Controller {
  static targets = ["btn"]

  connect() {
    this.list = new List(this.element.id, {
      listClass: "list-tbody",
      valueNames: [
        { name: "col-date",    attr: "data-sort-val" },
        { name: "col-amount",  attr: "data-sort-val" },
        "col-method",
        "col-description",
        "col-status"
      ]
    })

    this.list.on("sortComplete", () => this._updateIndicators())
  }

  disconnect() {
    this.list = null
  }

  _updateIndicators() {
    this.btnTargets.forEach(btn => {
      const icon = btn.querySelector(".sort-icon")
      if (!icon) return
      icon.textContent = btn.classList.contains("asc") ? " ↑" : btn.classList.contains("desc") ? " ↓" : " ↕"
    })
  }
}
