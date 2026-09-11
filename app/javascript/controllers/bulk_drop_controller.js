import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["zone", "input", "list", "empty", "submit"]
  static values = { uploadUrl: String }

  connect() {
    this._items = []
    this._uploading = false
    this._render()
    this.element.addEventListener("submit", this._handleSubmit.bind(this))
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
    if (!this._uploading) this.inputTarget.click()
  }

  inputChanged() {
    this._addFiles(Array.from(this.inputTarget.files))
    this.inputTarget.value = ""
  }

  remove(event) {
    if (this._uploading) return
    const index = parseInt(event.currentTarget.dataset.index)
    this._items.splice(index, 1)
    this._render()
    this._syncInput()
  }

  async _handleSubmit(event) {
    event.preventDefault()

    const userEmail = this.element.querySelector("[name='user_email']").value
    if (!userEmail) {
      alert("Please select a user")
      return
    }
    if (this._items.length === 0) return

    this._uploading = true
    this._render()

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    for (let i = 0; i < this._items.length; i++) {
      const item = this._items[i]

      let lastError = null
      for (let attempt = 1; attempt <= 2; attempt++) {
        if (attempt === 2) {
          item.status = "retrying"
          this._render()
          await new Promise(r => setTimeout(r, 1500))
        }

        item.status = "uploading"
        this._render()

        try {
          const formData = new FormData()
          formData.append("user_email", userEmail)
          formData.append("file", item.file)

          const response = await fetch(this.uploadUrlValue, {
            method: "POST",
            headers: { "X-CSRF-Token": csrfToken },
            body: formData
          })

          const data = await response.json()
          if (response.ok) {
            item.status = "done"
            item.receiptIds = data.receipt_ids
            lastError = null
            break
          } else {
            lastError = data.error || "Upload failed"
          }
        } catch (err) {
          lastError = err.message
        }
      }

      if (lastError) {
        item.status = "error"
        item.errorMsg = lastError
      }

      this._render()
    }

    this._uploading = false
    this._render()

  }

  _addFiles(newFiles) {
    const valid = newFiles.filter(f =>
      f.type === "application/zip" ||
      f.name.match(/\.(jpg|jpeg|png|gif|pdf|zip)$/i)
    )
    valid.forEach(f => this._items.push({ file: f, name: f.name, status: "pending" }))
    this._render()
    this._syncInput()
  }

  _syncInput() {
    const dt = new DataTransfer()
    this._items.forEach(item => dt.items.add(item.file))
    this.inputTarget.files = dt.files
  }

  _render() {
    const hasFiles = this._items.length > 0
    const allDone = hasFiles && this._items.every(item => item.status === "done" || item.status === "error")

    this.emptyTarget.classList.toggle("hidden", hasFiles)
    this.submitTarget.disabled = !hasFiles || this._uploading || allDone

    this.listTarget.innerHTML = this._items.map((item, i) => {
      let statusHtml = ""
      if (item.status === "uploading" || item.status === "retrying") {
        statusHtml = `<div class="animate-spin h-4 w-4 rounded-full border-2 border-gray-200 border-t-green-600 flex-shrink-0"></div>`
      } else if (item.status === "done") {
        statusHtml = `
          <svg class="h-4 w-4 text-green-600 flex-shrink-0" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7" />
          </svg>`
      } else if (item.status === "error") {
        statusHtml = `
          <svg class="h-4 w-4 text-red-500 flex-shrink-0" title="${this._escHtml(item.errorMsg || 'Upload failed')}" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>`
      } else if (item.status === "pending" && this._uploading) {
        statusHtml = `<div class="w-4 flex-shrink-0"></div>`
      }

      let nameHtml
      if (item.status === "done" && item.receiptIds && item.receiptIds.length > 0) {
        const href = item.receiptIds.length === 1
          ? `/receipts/${item.receiptIds[0]}`
          : `/receipts?ids=${item.receiptIds.join(",")}`
        nameHtml = `<a href="${href}" class="text-sm text-green-700 hover:underline truncate flex-1">${this._escHtml(item.name)}</a>`
      } else {
        nameHtml = `<span class="text-sm text-gray-700 truncate flex-1">${this._escHtml(item.name)}</span>`
      }

      const removeBtn = item.status === "pending" && !this._uploading
        ? `<button type="button" data-action="bulk-drop#remove" data-index="${i}"
                   class="text-gray-300 hover:text-red-500 transition-colors flex-shrink-0 text-lg leading-none">&times;</button>`
        : `<div class="w-4 flex-shrink-0"></div>`

      const errorHtml = item.status === "error" && item.errorMsg
        ? `<div class="text-xs text-red-500 px-3 pb-1.5">${this._escHtml(item.errorMsg)}</div>`
        : ""

      return `
        <div class="rounded-md hover:bg-gray-50">
          <div class="flex items-center gap-2 py-1.5 px-3">
            ${nameHtml}
            ${statusHtml}
            ${removeBtn}
          </div>
          ${errorHtml}
        </div>`
    }).join("")
  }

  _escHtml(str) {
    return (str || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
  }

  _clearHighlight() {
    this.zoneTarget.classList.remove("border-green-camp", "bg-green-50")
    this.zoneTarget.classList.add("border-gray-300")
  }
}
