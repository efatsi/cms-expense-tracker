import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  async start(event) {
    event.preventDefault()
    this.modalTarget.classList.remove("hidden")
    const url = event.currentTarget.dataset.url
    const csrf = document.querySelector('meta[name="csrf-token"]').content
    try {
      await fetch(url, { method: "POST", headers: { "X-CSRF-Token": csrf } })
    } finally {
      this.modalTarget.classList.add("hidden")
      window.location.reload()
    }
  }
}
