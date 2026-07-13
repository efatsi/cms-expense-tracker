import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["zone", "input", "label"]

  dragover(event) {
    event.preventDefault()
    this.zoneTarget.classList.add("border-indigo-400", "bg-indigo-50")
    this.zoneTarget.classList.remove("border-gray-300")
  }

  dragleave(event) {
    // Only clear if leaving the zone entirely (not entering a child element)
    if (!this.zoneTarget.contains(event.relatedTarget)) {
      this._clearHighlight()
    }
  }

  drop(event) {
    event.preventDefault()
    this._clearHighlight()
    const files = event.dataTransfer.files
    if (files.length > 0) {
      this.inputTarget.files = files
      this.labelTarget.textContent = files[0].name
    }
  }

  fileChanged() {
    const file = this.inputTarget.files[0]
    this.labelTarget.textContent = file ? file.name : "Drop file here or click to browse"
  }

  _clearHighlight() {
    this.zoneTarget.classList.remove("border-indigo-400", "bg-indigo-50")
    this.zoneTarget.classList.add("border-gray-300")
  }
}
