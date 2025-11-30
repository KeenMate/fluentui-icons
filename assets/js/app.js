// CSS is built by Tailwind separately (see config/config.exs)
// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Load preferences from localStorage BEFORE connecting
const savedViewMode = localStorage.getItem("icon_view_mode") || "grid"
const savedPlatformPrefs = localStorage.getItem("icon_platform_prefs")
const platformPrefs = savedPlatformPrefs
  ? JSON.parse(savedPlatformPrefs)
  : {ios: true, android: true, react: true, svelte: true}

// LiveView Hooks
let Hooks = {}

// Platform preferences hook - persists user's platform visibility choices to localStorage
Hooks.PlatformPrefs = {
  mounted() {
    // Listen for preference changes from LiveView and save to localStorage
    this.handleEvent("save_platform_prefs", (prefs) => {
      localStorage.setItem("icon_platform_prefs", JSON.stringify(prefs))
    })
  }
}

// View mode hook - persists grid/list preference to localStorage and updates CSS attribute
Hooks.ViewMode = {
  mounted() {
    // Listen for view mode changes from LiveView
    this.handleEvent("save_view_mode", ({mode}) => {
      localStorage.setItem("icon_view_mode", mode)
      // Update CSS attribute immediately for instant visual switch
      document.documentElement.setAttribute('data-view-mode', mode)
    })
  }
}

let liveSocket = new LiveSocket("/live", Socket, {
  params: {
    _csrf_token: csrfToken,
    view_mode: savedViewMode,
    platform_prefs: platformPrefs
  },
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// Copy to clipboard handler
window.addEventListener("phx:copy", (event) => {
  console.log("phx:copy event received, full detail:", JSON.stringify(event.detail, null, 2))
  console.log("event.detail keys:", Object.keys(event.detail))
  console.log("dispatcher:", event.detail.dispatcher)

  // The dispatcher is the button that was clicked
  // We need to find the target element from the button's data or sibling
  const button = event.detail.dispatcher
  if (button) {
    // Find the code element in the same container
    const container = button.closest('.flex')
    const codeEl = container ? container.querySelector('code') : null
    // Also check for hidden span (used by iOS/Android)
    const hiddenSpan = container ? container.querySelector('span.hidden') : null
    const target = hiddenSpan || codeEl

    console.log("Button:", button, "Container:", container, "Target:", target)

    if (target) {
      const text = target.textContent
      console.log("Copying text:", text)
      navigator.clipboard.writeText(text).then(() => {
        console.log("Copy successful!")
        const originalText = button.textContent
        button.textContent = "Copied!"
        setTimeout(() => button.textContent = originalText, 1500)
      }).catch(err => {
        console.error('Failed to copy:', err)
      })
    }
  }
})

