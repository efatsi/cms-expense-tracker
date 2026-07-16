import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop", "panel"]

  open(event) {
    const id = event.currentTarget.dataset.modalId
    const modal = document.getElementById(id)
    if (!modal) return

    modal.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
  }

  close() {
    document.querySelectorAll("[data-modal]").forEach(m => m.classList.add("hidden"))
    document.body.classList.remove("overflow-hidden")
  }

  closeOnBackdrop(event) {
    if (event.target === event.currentTarget) this.close()
  }
}
