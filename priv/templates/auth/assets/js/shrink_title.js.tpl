// iOS-style large title. An IntersectionObserver watches the [data-large-title] heading.
// The hook sets data-shrunk on its element once the heading has scrolled under it.
// The observer's top root margin is the element's height.
// The group-data-[shrunk] variant on #nav-title then shows the title.
// A patch can replace the heading without touching the header, so every page load looks again.
// The header's height changes across lg and on rotation, so a resize renews the margin.
export const ShrinkTitle = {
  mounted() {
    this.onPage = () => this.watch()
    window.addEventListener("phx:page-loading-stop", this.onPage)
    this.resize = new ResizeObserver(() => this.watch())
    this.resize.observe(this.el)
    this.watch()
  },
  updated() { this.watch() },
  watch() {
    const heading = document.querySelector("[data-large-title]")
    const height = this.el.offsetHeight
    if (heading === this.watched && height === this.height) return
    this.observer?.disconnect()
    this.watched = heading
    this.height = height
    this.el.toggleAttribute("data-shrunk", false)
    if (!heading) return
    this.observer = new IntersectionObserver(([entry]) => {
      this.el.toggleAttribute("data-shrunk", !entry.isIntersecting)
    }, {rootMargin: `-${height}px 0px 0px 0px`})
    this.observer.observe(heading)
  },
  destroyed() {
    window.removeEventListener("phx:page-loading-stop", this.onPage)
    this.resize.disconnect()
    this.observer?.disconnect()
  }
}
