import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rows", "template"]

  addRow() {
    const index = Date.now()
    const html = this.templateTarget.innerHTML.replace(/NEW_INDEX/g, index)
    this.rowsTarget.insertAdjacentHTML("beforeend", html)
  }

  removeRow(event) {
    const row = event.target.closest(".expense-row")
    const destroyField = row.querySelector("[data-destroy-field]")
    if (destroyField) {
      destroyField.value = "1"
      row.style.display = "none"
    } else {
      row.remove()
    }
  }
}
