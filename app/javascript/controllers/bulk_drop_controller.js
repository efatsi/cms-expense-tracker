import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["zone", "input", "list", "empty", "submit"]

  connect() {
    this._files = []
    this._render()
  }

  dragover(event) {
    event.preventDefault()
    this.zoneTarget.classList.add("border-green-camp", "bg-green-50")
    this.zoneTarget.classList.remove("border-gray-300")
  }

  dragleave(event) {
    if (!this.zoneTarget.contains(event.relatedTarget)) {
      this._clearHighlight()
    }
  }

  drop(event) {
    event.preventDefault()
    this._clearHighlight()
    this._addFiles(Array.from(event.dataTransfer.files))
  }

  browse() {
    this.inputTarget.click()
  }

  inputChanged() {
    this._addFiles(Array.from(this.inputTarget.files))
    this.inputTarget.value = ""
  }

  remove(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this._files.splice(index, 1)
    this._render()
    this._syncInput()
  }

  _addFiles(newFiles) {
    const valid = newFiles.filter(f =>
      f.type === "application/zip" ||
      f.name.match(/\.(jpg|jpeg|png|gif|pdf|zip)$/i)
    )
    this._files.push(...valid)
    this._render()
    this._syncInput()
  }

  _syncInput() {
    const dt = new DataTransfer()
    this._files.forEach(f => dt.items.add(f))
    this.inputTarget.files = dt.files
  }

  _render() {
    const hasFiles = this._files.length > 0
    this.emptyTarget.classList.toggle("hidden", hasFiles)
    this.submitTarget.disabled = !hasFiles

    this.listTarget.innerHTML = this._files.map((file, i) => `
      <div class="flex items-center justify-between py-1.5 px-3 rounded-md hover:bg-gray-50 group">
        <span class="text-sm text-gray-700 truncate flex-1 mr-2">${file.name}</span>
        <button type="button" data-action="bulk-drop#remove" data-index="${i}"
                class="text-gray-300 hover:text-red-500 transition-colors flex-shrink-0 text-lg leading-none">
          &times;
        </button>
      </div>
    `).join("")
  }

  _clearHighlight() {
    this.zoneTarget.classList.remove("border-green-camp", "bg-green-50")
    this.zoneTarget.classList.add("border-gray-300")
  }
}
