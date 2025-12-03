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
  : {ios: true, android: true, react: true, svelte: true, filename: true}

// Filename template helpers
const DEFAULT_FILENAME_TEMPLATE = "{filename}"

// Helper to push events to LiveView - uses a tracker hook element
function pushLiveEvent(event, params) {
  const tracker = document.getElementById('metrics-tracker')
  if (tracker && tracker._pushEvent) {
    console.log('pushLiveEvent:', event, params)
    tracker._pushEvent(event, params)
    return true
  }
  console.warn('pushLiveEvent: tracker not ready')
  return false
}

function toSnakeCase(name) {
  return name.toLowerCase().replace(/\s+/g, '_')
}

function toPascalCase(name) {
  return name.split(/\s+/).map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()).join('')
}

function toKebabCase(name) {
  return name.toLowerCase().replace(/\s+/g, '-')
}

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

// Filename template hook - allows custom filename patterns with client-side evaluation
Hooks.FilenameTemplate = {
  mounted() {
    const savedTemplate = localStorage.getItem("filename_template") || DEFAULT_FILENAME_TEMPLATE
    const input = this.el.querySelector("input[type='text']")
    input.value = savedTemplate

    this.renderFilenames()

    input.addEventListener("input", (e) => {
      localStorage.setItem("filename_template", e.target.value)
      this.renderFilenames()
    })
  },

  renderFilenames() {
    const input = this.el.querySelector("input[type='text']")
    const template = input.value || DEFAULT_FILENAME_TEMPLATE
    const name = this.el.dataset.name
    const style = this.el.dataset.style
    const sizes = JSON.parse(this.el.dataset.sizes)
    const resultsContainer = this.el.querySelector("[id^='filename-results']")

    resultsContainer.innerHTML = sizes.map(size => {
      const filename = this.evaluateTemplate(template, name, size, style)
      const escapedFilename = filename.replace(/"/g, '&quot;')
      return `<div class="flex items-center justify-between bg-white rounded px-3 py-2 border border-gray-200">
        <code class="text-sm text-gray-700">${filename}</code>
        <button type="button" class="copy-filename text-xs text-gray-500 hover:text-gray-700 px-2 py-1 rounded hover:bg-gray-100" data-text="${escapedFilename}">Copy</button>
      </div>`
    }).join("")

    // Add click handlers for copy buttons
    this.el.querySelectorAll(".copy-filename").forEach(btn => {
      btn.onclick = () => {
        navigator.clipboard.writeText(btn.dataset.text).then(() => {
          const originalText = btn.textContent
          btn.textContent = "Copied!"
          setTimeout(() => btn.textContent = originalText, 1500)

          // Track the copy action
          const modal = document.querySelector('[role="dialog"]')
          const downloadLink = modal?.querySelector('a[phx-click="track_download"]')
          const iconId = downloadLink?.getAttribute('phx-value-icon-id')
          if (iconId) {
            pushLiveEvent("track_copy", { "icon-id": iconId, platform: "filename" })
          }
        })
      }
    })
  },

  evaluateTemplate(template, name, size, style) {
    const originalFilename = `ic_fluent_${toSnakeCase(name)}_${size}_${style}.svg`
    return template
      .replace(/{filename}/g, originalFilename)
      .replace(/{name}/g, name)
      .replace(/{name_snake}/g, toSnakeCase(name))
      .replace(/{name_pascal}/g, toPascalCase(name))
      .replace(/{name_kebab}/g, toKebabCase(name))
      .replace(/{size}/g, size)
      .replace(/{style}/g, style)
  }
}

// Color picker hook - handles color changes and updates SVGs
Hooks.ColorPicker = {
  mounted() {
    this.colorInput = this.el.querySelector('.color-input')
    this.textInput = this.el.querySelector('.color-text')

    // Apply saved color
    this.applySavedColor()

    // Color picker changes
    this.colorInput.addEventListener('input', (e) => {
      const color = e.target.value
      this.textInput.value = color
      this.updateSvgColors(color)
    })

    // Text input changes
    this.textInput.addEventListener('input', (e) => {
      let color = e.target.value
      // Auto-add # if missing
      if (color && !color.startsWith('#')) {
        color = '#' + color
        this.textInput.value = color
      }
      // Validate hex color format
      if (/^#[0-9A-Fa-f]{6}$/.test(color)) {
        this.colorInput.value = color
        this.updateSvgColors(color)
      }
    })
  },

  updated() {
    // Re-apply saved color when LiveView updates the DOM
    this.colorInput = this.el.querySelector('.color-input')
    this.textInput = this.el.querySelector('.color-text')
    this.applySavedColor()
  },

  applySavedColor() {
    const savedColor = localStorage.getItem('icon_preview_color') || '#212121'
    // Use requestAnimationFrame to ensure this runs after LiveView finishes patching the DOM
    requestAnimationFrame(() => {
      if (this.colorInput) this.colorInput.value = savedColor
      if (this.textInput) this.textInput.value = savedColor
    })
  },

  updateSvgColors(color) {
    localStorage.setItem('icon_preview_color', color)
    const svgContainer = document.querySelector('[phx-hook="InlineSvg"]')
    if (svgContainer) {
      svgContainer.dataset.color = color
      svgContainer.querySelectorAll('svg path[fill], svg circle[fill], svg rect[fill]').forEach(el => {
        const currentFill = el.getAttribute('fill')
        if (currentFill && currentFill !== 'none') {
          el.setAttribute('fill', color)
        }
      })
    }
    // Notify grid/list to update their color filter
    window.dispatchEvent(new CustomEvent('iconColorChanged'))
  }
}

// Inline SVG hook - fetches SVGs and allows color customization
Hooks.InlineSvg = {
  mounted() {
    this.loadSvgs()
  },

  updated() {
    // Re-fetch SVGs when LiveView updates the DOM
    this.loadSvgs()
  },

  async loadSvgs() {
    // Get color from localStorage first (most reliable during re-renders), then color picker, then default
    const savedColor = localStorage.getItem('icon_preview_color')
    const colorPicker = document.querySelector('.color-input')
    const color = savedColor || (colorPicker ? colorPicker.value : '#212121')
    const urls = JSON.parse(this.el.dataset.urls)
    const containers = this.el.querySelectorAll('.svg-container')

    for (let i = 0; i < containers.length && i < urls.length; i++) {
      const container = containers[i]
      const size = container.dataset.size

      try {
        const response = await fetch(urls[i])
        const svgText = await response.text()
        // Replace all fill colors with selected color (but not fill="none")
        const coloredSvg = svgText.replace(/fill="#[0-9A-Fa-f]{6}"/g, `fill="${color}"`)
        container.innerHTML = coloredSvg

        // Set the SVG size
        const svg = container.querySelector('svg')
        if (svg) {
          svg.style.width = `${size}px`
          svg.style.height = `${size}px`
        }
      } catch (err) {
        console.error('Failed to load SVG:', err)
        container.innerHTML = `<span class="text-xs text-gray-400">Failed to load</span>`
      }
    }
  }
}

// Icon color filter hook - loads inline SVGs for grid/list icons
Hooks.IconColorFilter = {
  mounted() {
    this.svgCache = new Map()
    this.loadAllSvgs()
    // Listen for color changes from the color picker
    window.addEventListener('iconColorChanged', () => this.updateAllColors())
  },

  updated() {
    // First, recolor any icons that are already loaded
    this.updateAllColors()
    // Then load any new icons that don't have SVGs yet
    this.loadAllSvgs()
  },

  async loadAllSvgs() {
    const icons = this.el.querySelectorAll('.inline-svg-icon')

    // Use IntersectionObserver for lazy loading
    if (!this.observer) {
      this.observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            this.loadSvg(entry.target)
            this.observer.unobserve(entry.target)
          }
        })
      }, { rootMargin: '100px' })
    }

    icons.forEach(icon => {
      // Check if icon actually has SVG content, not just data-loaded flag
      const hasSvg = icon.querySelector('svg')
      if (!hasSvg) {
        delete icon.dataset.loaded
        this.observer.observe(icon)
      }
    })
  },

  async loadSvg(container) {
    // Always read fresh color from localStorage
    const color = localStorage.getItem('icon_preview_color') || '#212121'
    const url = container.dataset.svgUrl
    if (!url) return

    try {
      let svgText
      if (this.svgCache.has(url)) {
        svgText = this.svgCache.get(url)
      } else {
        const response = await fetch(url)
        svgText = await response.text()
        this.svgCache.set(url, svgText)
      }

      // Apply color
      const coloredSvg = svgText.replace(/fill="#[0-9A-Fa-f]{6}"/g, `fill="${color}"`)
      container.innerHTML = coloredSvg

      // Make SVG fill container
      const svg = container.querySelector('svg')
      if (svg) {
        svg.style.width = '100%'
        svg.style.height = '100%'
      }

      container.dataset.loaded = 'true'
    } catch (err) {
      console.error('Failed to load SVG:', url, err)
    }
  },

  updateAllColors() {
    const color = localStorage.getItem('icon_preview_color') || '#212121'
    const icons = this.el.querySelectorAll('.inline-svg-icon')

    icons.forEach(icon => {
      // Update fill color on all loaded SVGs
      icon.querySelectorAll('svg path[fill], svg circle[fill], svg rect[fill]').forEach(el => {
        const currentFill = el.getAttribute('fill')
        if (currentFill && currentFill !== 'none') {
          el.setAttribute('fill', color)
        }
      })
    })
  }
}

// Metrics tracker hook - provides a way to push events from any JS code
Hooks.MetricsTracker = {
  mounted() {
    // Expose pushEvent function on the element so other JS can use it
    this.el._pushEvent = (event, params) => {
      this.pushEvent(event, params)
    }
  }
}

// Svelte color toggle hook - adds color to generated Svelte code
Hooks.SvelteColor = {
  mounted() {
    const checkbox = this.el.querySelector('.svelte-include-color')
    const name = this.el.dataset.name
    const style = this.el.dataset.style
    const sizes = JSON.parse(this.el.dataset.sizes)

    // Load saved preference
    const savedPref = localStorage.getItem('svelte_include_color') === 'true'
    checkbox.checked = savedPref
    if (savedPref) {
      this.updateCode(name, style, sizes, true)
    }

    checkbox.addEventListener('change', (e) => {
      const includeColor = e.target.checked
      localStorage.setItem('svelte_include_color', includeColor)
      this.updateCode(name, style, sizes, includeColor)
    })

    // Also listen for color picker changes when checkbox is checked
    document.addEventListener('input', (e) => {
      if (e.target.classList.contains('color-input') || e.target.classList.contains('color-text')) {
        if (checkbox.checked) {
          this.updateCode(name, style, sizes, true)
        }
      }
    })
  },

  updateCode(name, style, sizes, includeColor) {
    const codeElements = this.el.querySelectorAll('code[data-size]')
    const colorPicker = document.querySelector('.color-input')
    const color = colorPicker ? colorPicker.value : (localStorage.getItem('icon_preview_color') || '#212121')

    codeElements.forEach(code => {
      const size = code.dataset.size
      if (includeColor) {
        code.textContent = `<Icon name="${name}" size={${size}} variant="${style}" color="custom" customColor="${color}" />`
      } else {
        code.textContent = `<Icon name="${name}" size={${size}} variant="${style}" />`
      }
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

// Direct copy to clipboard handler (text passed in event detail)
window.addEventListener("phx:copy_text", (event) => {
  const { text, icon_id, platform } = event.detail
  if (text) {
    navigator.clipboard.writeText(text).then(() => {
      // Show brief feedback on the button
      const button = event.target
      if (button) {
        const svg = button.querySelector('svg')
        if (svg) {
          svg.style.color = '#22c55e'
          setTimeout(() => svg.style.color = '', 1000)
        }
      }
      // Track the copy
      if (icon_id && platform) {
        pushLiveEvent("track_copy", { "icon-id": String(icon_id), platform: String(platform) })
      }
    }).catch(err => console.error('Failed to copy:', err))
  }
})

// Copy to clipboard handler
window.addEventListener("phx:copy", (event) => {
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

    if (target) {
      const text = target.textContent
      navigator.clipboard.writeText(text).then(() => {
        const originalText = button.textContent
        button.textContent = "Copied!"
        setTimeout(() => button.textContent = originalText, 1500)

        // Track the copy action via LiveView
        trackCopy(target)
      }).catch(err => {
        console.error('Failed to copy:', err)
      })
    }
  }
})

// Track copy actions for metrics
function trackCopy(targetEl) {
  // Find the modal to get icon ID
  const modal = document.querySelector('[role="dialog"]')
  if (!modal) return

  // Get icon ID from an element with data-icon-id, or parse from DOM structure
  const downloadLink = modal.querySelector('a[phx-click="track_download"]')
  if (!downloadLink) return

  const iconId = downloadLink.getAttribute('phx-value-icon-id')
  if (!iconId) return

  // Determine platform from element ID or parent section
  const targetId = targetEl.id || ''
  let platform = 'unknown'
  let size = null

  if (targetId.startsWith('ios-')) {
    platform = 'ios'
    size = targetId.split('-').pop()
  } else if (targetId.startsWith('android-')) {
    platform = 'android'
    size = targetId.split('-').pop()
  } else if (targetId.startsWith('react-')) {
    platform = 'react'
    size = targetId.split('-').pop()
  } else if (targetId.startsWith('svelte-')) {
    platform = 'svelte'
    size = targetEl.dataset.size
  } else if (targetEl.closest('[id^="filename-section"]')) {
    platform = 'filename'
  }

  // Push event to LiveView
  const params = { "icon-id": iconId, platform: platform }
  if (size) params.size = size
  pushLiveEvent("track_copy", params)
}

