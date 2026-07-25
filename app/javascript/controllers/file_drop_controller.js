import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["zone", "input", "label", "modal"]

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
    const files = event.dataTransfer.files
    if (files.length > 0) {
      this.inputTarget.files = files
      this._handleFile(files[0])
    }
  }

  fileChanged() {
    const file = this.inputTarget.files[0]
    if (file) {
      this._handleFile(file)
    } else {
      this.labelTarget.textContent = "Drop file here or click to browse"
    }
  }

  cancel() {
    if (this._abortController) {
      this._abortController.abort()
    }
    this._hideModal()
    this.labelTarget.textContent = this.inputTarget.files[0]?.name || "Drop file here or click to browse"
  }

  async _handleFile(file) {
    this.labelTarget.textContent = file.name
    await this._analyze(file)
  }

  async _analyze(file) {
    this._showModal()

    const formData = new FormData()
    formData.append("file", file)

    this._abortController = new AbortController()

    try {
      const csrf = document.querySelector('meta[name="csrf-token"]').content
      const response = await fetch("/receipts/analyze", {
        method: "POST",
        headers: { "X-CSRF-Token": csrf },
        body: formData,
        signal: this._abortController.signal
      })

      if (!response.ok) {
        const err = await response.json().catch(() => ({}))
        throw new Error(err.error || "Analysis failed")
      }

      const data = await response.json()
      const form = this.element.querySelector("form")
      ;(form || this.element).dispatchEvent(new CustomEvent("receipt:analyzed", { detail: data, bubbles: true }))
    } catch (e) {
      if (e.name !== "AbortError") console.error("Receipt analysis failed:", e)
    } finally {
      this._hideModal()
    }
  }

  _showModal() {
    this.modalTarget.classList.remove("hidden")
  }

  _hideModal() {
    this.modalTarget.classList.add("hidden")
  }

  _clearHighlight() {
    this.zoneTarget.classList.remove("border-green-camp", "bg-green-50")
    this.zoneTarget.classList.add("border-gray-300")
  }
}
