import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["show", "edit"]

  edit() {
    this.showTargets.forEach(el => el.classList.add("hidden"))
    this.editTargets.forEach(el => el.classList.remove("hidden"))
  }

  cancel() {
    this.editTargets.forEach(el => el.classList.add("hidden"))
    this.showTargets.forEach(el => el.classList.remove("hidden"))
  }
}
