import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rows", "template"]

  connect() {
    this._onAnalyzed = this._handleAnalysis.bind(this)
    this.element.addEventListener("receipt:analyzed", this._onAnalyzed)
  }

  disconnect() {
    this.element.removeEventListener("receipt:analyzed", this._onAnalyzed)
  }

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

  _handleAnalysis(event) {
    const { vendor, date, expenses } = event.detail

    if (vendor) {
      const f = this.element.querySelector('[name="receipt[vendor]"]')
      if (f) f.value = vendor
    }
    if (date) {
      const f = this.element.querySelector('[name="receipt[expense_date]"]')
      if (f) f.value = date
    }
    if (expenses && expenses.length > 0) {
      this._fillExpenses(expenses)
    }
  }

  _fillExpenses(expenses) {
    const existingRows = [...this.rowsTarget.querySelectorAll(".expense-row")]

    expenses.forEach((expense, i) => {
      let row
      if (i < existingRows.length) {
        row = existingRows[i]
      } else {
        const index = Date.now() + i
        const html = this.templateTarget.innerHTML.replace(/NEW_INDEX/g, index)
        this.rowsTarget.insertAdjacentHTML("beforeend", html)
        row = this.rowsTarget.querySelector(".expense-row:last-child")
      }

      const select = row.querySelector("select")
      const desc = row.querySelector('input[type="text"]')
      const amount = row.querySelector('input[type="number"]')

      if (select && expense.category_id) select.value = expense.category_id
      if (desc && expense.description) desc.value = expense.description
      if (amount && expense.amount) amount.value = expense.amount
    })
  }
}
