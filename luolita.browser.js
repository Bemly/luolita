/**
 * luolita.browser.js — Luolita SFC compiler for the browser
 *
 * Usage (load in order):
 *   <script src="https://cdn.jsdelivr.net/npm/coffeescript@2/dist/coffeescript.min.js"></script>
 *   <script src="https://cdn.jsdelivr.net/npm/pug@3/pug.min.js"></script>
 *   <script src="https://cdn.jsdelivr.net/npm/stylus@0/dist/stylus.min.js"></script>
 *   <script src="luolita.browser.js"></script>
 *
 * Then:
 *   Luolita.compile(luoliText).then(result => { ... })
 *   Luolita.renderToDOM(luoliText, document.getElementById('app'))
 */

(function () {
  'use strict'

  var NAME = '[luolita browser]'

  // --- Dependency checks ---
  if (typeof window.CoffeeScript === 'undefined') {
    throw new Error(NAME + ' CoffeeScript not loaded. Include coffeescript.min.js first.')
  }
  if (typeof window.pug === 'undefined') {
    throw new Error(NAME + ' pug not loaded. Include pug.min.js first.')
  }
  if (typeof window.stylus === 'undefined') {
    throw new Error(NAME + ' stylus not loaded. Include stylus.min.js first.')
  }

  var cfs = window.CoffeeScript
  var pug = window.pug
  var sty = window.stylus

  var COFFEE_OPTIONS = {
    bare: true,
    header: false,
    sourceMap: true,
    inlineMap: true
  }

  // --- Dedent: strip common leading indentation ---
  function dedent(text) {
    var lines = text.split('\n')
    var nonEmpty = lines.filter(function (l) { return l.trim().length > 0 })
    if (nonEmpty.length === 0) return text

    var minIndent = Math.min.apply(null, nonEmpty.map(function (l) {
      var m = l.match(/^(\s*)/)
      return m ? m[1].length : 0
    }))

    if (minIndent > 0) {
      return lines.map(function (l) {
        return l.length >= minIndent ? l.substring(minIndent) : l.trimStart()
      }).join('\n')
    }
    return text
  }

  // --- Parse .luoli text into sections ---
  function parseLuoli(text) {
    var segments = {}
    var status = ''
    var lines = text.split('\n')

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      var trimmed = line.replace(/\s+$/, '')
      if (trimmed === 'coffee:') {
        status = 'coffee'
      } else if (trimmed === 'template:') {
        status = 'template'
      } else if (trimmed === 'style:') {
        status = 'style'
      } else if (status) {
        if (!segments[status]) segments[status] = ''
        segments[status] += line + '\n'
      }
    }
    return segments
  }

  // --- Extract variable assignments from coffee source ---
  function sfcVarBridge(coffeeSrc) {
    var vars = {}
    var lines = coffeeSrc.split('\n')
    var re = /^\s*([a-zA-Z_$][a-zA-Z0-9_$]*)\s*=\s*(.+)$/

    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(re)
      if (match) {
        try {
          vars[match[1]] = cfs.eval(match[2], { bare: true })
        } catch (e) {
          vars[match[1]] = match[2].trim()
        }
      }
    }
    return vars
  }

  // --- Main compile API ---
  /**
   * Compile a .luoli source string.
   * @param {string} text - The .luoli file content
   * @param {object} opts - Options: { outputName?: string, debug?: boolean }
   * @returns {Promise<{coffee: {js: string, map: string}, template: string, style: string}>}
   */
  function compile(text, opts) {
    opts = opts || {}
    var debug = opts.debug !== false
    var outputName = opts.outputName || 'luolita'

    if (debug) console.log(NAME + ' compiling...')

    var segments = parseLuoli(text)

    // Check we have at least one section
    var hasSections = Object.keys(segments).length > 0
    if (!hasSections) {
      return Promise.reject(new Error(NAME + ' Error: no sections (coffee:/template:/style:) found in input'))
    }

    // Dedent and bridge variables
    var bridgeVars = {}
    var outputSegments = {}

    if (segments.coffee) {
      var coffeeSrc = dedent(segments.coffee)
      bridgeVars = sfcVarBridge(coffeeSrc)
      bridgeVars.name = outputName
      if (debug) console.log(NAME + ' Bridged variables:', Object.keys(bridgeVars))
      outputSegments.coffee = cfs.compile(coffeeSrc, COFFEE_OPTIONS)
    } else {
      bridgeVars = {}
      outputSegments.coffee = { js: '' }
    }

    if (segments.template) {
      outputSegments.template = pug.compile(dedent(segments.template))(bridgeVars)
    } else {
      outputSegments.template = ''
    }

    if (segments.style) {
      outputSegments.style = sty(dedent(segments.style), { define: { bridge_vars: bridgeVars } }).render()
    } else {
      outputSegments.style = ''
    }

    if (debug) console.log(NAME + ' Compilation complete:', Object.keys(outputSegments))

    return Promise.resolve(outputSegments)
  }

  // --- Render to DOM ---
  /**
   * Compile and render .luoli content into a DOM element.
   * @param {string} text - The .luoli file content
   * @param {Element|string} target - DOM element or selector
   * @param {object} opts - Compile options
   * @returns {Promise<void>}
   */
  function renderToDOM(text, target, opts) {
    opts = opts || {}
    var el = typeof target === 'string' ? document.querySelector(target) : target
    if (!el) throw new Error(NAME + ' Target element not found: ' + target)

    return compile(text, opts).then(function (result) {
      // Inject styles
      if (result.style) {
        var styleTag = document.createElement('style')
        styleTag.textContent = result.style
        document.head.appendChild(styleTag)
      }

      // Inject HTML
      el.innerHTML = result.template

      // Execute JS if present
      if (result.coffee && result.coffee.js) {
        var scriptTag = document.createElement('script')
        scriptTag.textContent = result.coffee.js
        document.body.appendChild(scriptTag)
      }
    })
  }

  // Expose
  window.Luolita = {
    compile: compile,
    renderToDOM: renderToDOM,
    VERSION: '0.1.4'
  }

  console.log(NAME + ' v' + window.Luolita.VERSION + ' loaded.')
  console.log(NAME + ' CoffeeScript ' + cfs.VERSION)
})()
