###
luolita.browser.coffee — Luolita SFC compiler for the browser

Bundled with esbuild into dist/luolita.browser.bundle.js.
Usage:
  <script src="luolita.browser.bundle.js"></script>
###

cfs = require "coffeescript"
pug = require "pug"
sty = require "stylus"

do ->
  NAME = '[luolita browser]'

  COFFEE_OPTIONS =
    bare: true
    header: false
    sourceMap: true
    inlineMap: true

  # --- Dedent: strip common leading indentation ---
  dedent = (text) ->
    lines = text.split '\n'
    nonEmpty = lines.filter (l) -> l.trim().length > 0
    return text if nonEmpty.length is 0
    minIndent = Math.min ...nonEmpty.map (l) ->
      m = l.match /^(\s*)/
      if m then m[1].length else 0
    if minIndent > 0
      lines.map((l) -> if l.length >= minIndent then l.substring(minIndent) else l.trimStart()).join '\n'
    else
      text

  # --- Parse .luoli text into sections ---
  parseLuoli = (text) ->
    segments = {}
    status = ''
    for line in text.split '\n'
      switch line.replace /\s+$/, ''
        when 'coffee:' then status = 'coffee'
        when 'template:' then status = 'template'
        when 'style:' then status = 'style'
        else
          if status
            segments[status] ?= ''
            segments[status] += line + '\n'
    segments

  # --- Extract variable assignments from coffee source ---
  sfcVarBridge = (coffeeSrc) ->
    vars = {}
    for line in coffeeSrc.split '\n'
      match = line.match /^\s*([a-zA-Z_$][a-zA-Z0-9_$]*)\s*=\s*(.+)$/
      if match
        try
          vars[match[1]] = cfs.eval match[2], bare: true
        catch e
          vars[match[1]] = match[2].trim()
    vars

  # --- Compile stylus (sync, Node.js API bundled by esbuild) ---
  compileStylus = (src, vars) ->
    Promise.resolve().then ->
      sty(dedent(src), {}).render()

  # --- Main compile API ---
  compile = (text, opts = {}) ->
    debug = opts.debug ? true
    outputName = opts.outputName or 'luolita'

    console.log "#{ NAME } compiling..." if debug

    segments = parseLuoli text
    if Object.keys(segments).length is 0
      return Promise.reject new Error "#{ NAME } Error: no sections found"

    bridgeVars = {}
    outputSegments = {}

    # Compile coffee
    if segments.coffee?
      coffeeSrc = dedent segments.coffee
      bridgeVars = sfcVarBridge coffeeSrc
      bridgeVars.name = outputName
      console.log "#{ NAME } Bridged variables:", Object.keys(bridgeVars) if debug
      outputSegments.coffee = cfs.compile coffeeSrc, COFFEE_OPTIONS
    else
      outputSegments.coffee = js: ''

    # Compile template (synchronous)
    if segments.template?
      fn = pug.compile dedent segments.template
      outputSegments.template = fn bridgeVars
    else
      outputSegments.template = ''

    # Compile style (async in browser)
    stylePromise = if segments.style?
      compileStylus segments.style, bridgeVars
    else
      Promise.resolve ''

    return stylePromise.then (css) ->
      outputSegments.style = css
      console.log "#{ NAME } Compilation complete:", Object.keys(outputSegments) if debug
      Promise.resolve outputSegments

  # --- Render to DOM ---
  renderToDOM = (text, target, opts = {}) ->
    el = if typeof target is 'string' then document.querySelector target else target
    throw new Error "#{ NAME } Target element not found: #{ target }" unless el?

    compile(text, opts).then (result) ->
      if result.style
        styleTag = document.createElement 'style'
        styleTag.textContent = result.style
        document.head.appendChild styleTag

      el.innerHTML = result.template

      if result.coffee?.js
        scriptTag = document.createElement 'script'
        scriptTag.textContent = result.coffee.js
        document.body.appendChild scriptTag

  # Expose
  window.Luolita =
    compile: compile
    renderToDOM: renderToDOM
    VERSION: '0.1.4'

  console.log "#{ NAME } v#{ window.Luolita.VERSION } loaded."
  console.log "#{ NAME } CoffeeScript #{ cfs.VERSION }"
