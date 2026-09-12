import { Controller } from "@hotwired/stimulus"

const TIMEOUT_MS = 15000

export default class extends Controller {
  static targets = ["zone", "input", "label", "modal", "loadingState", "errorState", "errorMessage", "preview"]

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
      this._abortController.abort("cancelled")
    }
    this._hideModal()
    this.labelTarget.textContent = this.inputTarget.files[0]?.name || "Drop file here or click to browse"
  }

  dismissError() {
    this._hideModal()
  }

  async _handleFile(file) {
    this.labelTarget.textContent = file.name
    this._showPreview(file)
    await this._analyze(file)
  }

  _showPreview(file) {
    if (!this.hasPreviewTarget) return
    const url = URL.createObjectURL(file)
    const isImage = file.type.startsWith("image/")
    const isPdf = file.type === "application/pdf"
    let mediaHtml = ""
    if (isImage) {
      mediaHtml = `<img src="${url}" class="w-full rounded border border-gray-200 object-contain" style="max-height:600px">`
    } else if (isPdf) {
      mediaHtml = `<iframe src="${url}#navpanes=0" class="w-full rounded border border-gray-200" style="height:700px" title="Receipt preview"></iframe>`
    }
    if (mediaHtml) {
      this.previewTarget.innerHTML = `<p class="text-sm font-medium text-gray-700 mb-2">File Preview</p>${mediaHtml}`
      this.previewTarget.classList.remove("hidden")
    }
  }

  async _analyze(file) {
    this._showLoading()

    const formData = new FormData()
    formData.append("file", file)

    this._abortController = new AbortController()
    const timeoutId = setTimeout(() => this._abortController.abort("timeout"), TIMEOUT_MS)

    try {
      const csrf = document.querySelector('meta[name="csrf-token"]').content
      const response = await fetch("/receipts/analyze", {
        method: "POST",
        headers: { "X-CSRF-Token": csrf },
        body: formData,
        signal: this._abortController.signal
      })

      clearTimeout(timeoutId)

      if (!response.ok) {
        const err = await response.json().catch(() => ({}))
        throw new Error(err.error || `Server error (${response.status})`)
      }

      const data = await response.json()
      const form = this.element.querySelector("form")
      ;(form || this.element).dispatchEvent(new CustomEvent("receipt:analyzed", { detail: data, bubbles: true }))
      this._hideModal()
    } catch (e) {
      clearTimeout(timeoutId)
      if (e.name === "AbortError" && this._abortController.signal.reason === "cancelled") {
        this._hideModal()
      } else {
        const msg = this._abortController.signal.reason === "timeout"
          ? "Analysis timed out after 15 seconds. You can fill in the details manually."
          : (e.message || "Something went wrong. You can fill in the details manually.")
        this._showError(msg)
      }
    }
  }

  _showLoading() {
    this.errorStateTarget.classList.add("hidden")
    this.loadingStateTarget.classList.remove("hidden")
    this.modalTarget.classList.remove("hidden")
  }

  _showError(message) {
    this.loadingStateTarget.classList.add("hidden")
    this.errorMessageTarget.textContent = message
    this.errorStateTarget.classList.remove("hidden")
  }

  _hideModal() {
    this.modalTarget.classList.add("hidden")
  }

  _clearHighlight() {
    this.zoneTarget.classList.remove("border-green-camp", "bg-green-50")
    this.zoneTarget.classList.add("border-gray-300")
  }
}
