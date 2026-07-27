import { Controller } from "@hotwired/stimulus"
import List from "list.js"

export default class extends Controller {
  static targets = ["btn", "exportLink", "sortInput", "orderInput"]

  connect() {
    this.list = new List(this.element.id, {
      listClass: "list-tbody",
      valueNames: [
        { name: "col-date",   attr: "data-sort-val" },
        { name: "col-amount", attr: "data-sort-val" },
        "col-method",
        "col-description",
        "col-status"
      ]
    })

    this.list.on("sortComplete", () => {
      this._updateIndicators()
      this._syncSortState()
    })

    // Restore sort from URL, falling back to localStorage
    const url = new URL(window.location)
    let sortField = url.searchParams.get("sort")
    let sortOrder = url.searchParams.get("order")

    if (!sortField || !sortOrder) {
      try {
        const stored = JSON.parse(localStorage.getItem(this._storageKey()))
        if (stored) { sortField = stored.field; sortOrder = stored.order }
      } catch (e) {}
    }

    if (sortField && sortOrder) {
      this.list.sort(sortField, { order: sortOrder })
    }
  }

  disconnect() {
    this.list = null
  }

  _updateIndicators() {
    this.btnTargets.forEach(btn => {
      const icon = btn.querySelector(".sort-icon")
      if (!icon) return
      icon.textContent = btn.classList.contains("asc") ? " ↑" : btn.classList.contains("desc") ? " ↓" : " ↕"
    })
  }

  _syncSortState() {
    const sort = this._currentSort()
    const url = new URL(window.location)

    if (sort) {
      url.searchParams.set("sort", sort.field)
      url.searchParams.set("order", sort.order)
      if (this.hasSortInputTarget)  this.sortInputTarget.value  = sort.field
      if (this.hasOrderInputTarget) this.orderInputTarget.value = sort.order
    } else {
      url.searchParams.delete("sort")
      url.searchParams.delete("order")
      if (this.hasSortInputTarget)  this.sortInputTarget.value  = ""
      if (this.hasOrderInputTarget) this.orderInputTarget.value = ""
    }

    history.replaceState(null, "", url.toString())

    if (sort) {
      try { localStorage.setItem(this._storageKey(), JSON.stringify({ field: sort.field, order: sort.order })) } catch (e) {}
    } else {
      try { localStorage.removeItem(this._storageKey()) } catch (e) {}
    }

    if (this.hasExportLinkTarget) {
      const exportUrl = new URL(this.exportLinkTarget.href)
      if (sort) {
        exportUrl.searchParams.set("sort", sort.field)
        exportUrl.searchParams.set("order", sort.order)
      } else {
        exportUrl.searchParams.delete("sort")
        exportUrl.searchParams.delete("order")
      }
      this.exportLinkTarget.href = exportUrl.toString()
    }
  }

  _storageKey() {
    return `list-sort:${window.location.pathname}`
  }

  _currentSort() {
    const asc  = this.btnTargets.find(b => b.classList.contains("asc"))
    const desc = this.btnTargets.find(b => b.classList.contains("desc"))
    const btn  = asc || desc
    return btn ? { field: btn.dataset.sort, order: asc ? "asc" : "desc" } : null
  }
}
