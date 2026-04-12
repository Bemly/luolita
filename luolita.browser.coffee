###
luolita.browser.coffee — Luolita SFC compiler for the browser

Usage (load in order):
  <script src="https://cdn.jsdelivr.net/npm/coffeescript@2/dist/coffeescript.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/pug@3/pug.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/stylus@0/dist/stylus.min.js"></script>
  <script src="luolita.browser.coffee" type="text/coffeescript"></script>

Then:
  Luolita.compile(luoliText).then (result) -> ...
  Luolita.renderToDOM(luoliText, document.getElementById('app'))
###

do ->
  NAME = '[luolita browser]'

  # --- Dependency checks ---
  unless window.CoffeeScript?
    throw new Error "#{ NAME } CoffeeScript not loaded. Include coffeescript.min.js first."
  unless window.pug?
    throw new Error "#{ NAME } pug not loaded. Include pug.min.js first."
  unless window.stylus?
    throw new Error "#{ NAME } stylus not loaded. Include stylus.min.js first."

  cfs = window.CoffeeScript
  pug = window.pug
  sty = window.stylus

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

  # --- Main compile API ---
  compile = (text, opts = {}) ->
    debug = opts.debug ? true
    outputName = opts.outputName or 'luolita'

    console.log "#{ NAME } compiling..." if debug

    segments = parseLuoli text
    if Object.keys(segments).length is 0
      return Promise.reject new Error "#{ NAME } Error: no sections (coffee:/template:/style:) found in input"

    outputSegments = {}
    bridgeVars = {}

    if segments.coffee?
      coffeeSrc = dedent segments.coffee
      bridgeVars = sfcVarBridge coffeeSrc
      bridgeVars.name = outputName
      console.log "#{ NAME } Bridged variables:", Object.keys(bridgeVars) if debug
      outputSegments.coffee = cfs.compile coffeeSrc, COFFEE_OPTIONS
    else
      outputSegments.coffee = js: ''

    if segments.template?
      outputSegments.template = pug.compile(dedent segments.template) bridgeVars
    else
      outputSegments.template = ''

    if segments.style?
      outputSegments.style = sty(dedent segments.style, define: bridge_vars: bridgeVars).render()
    else
      outputSegments.style = ''

    console.log "#{ NAME } Compilation complete:", Object.keys(outputSegments) if debug
    Promise.resolve outputSegments

  # --- Render to DOM ---
  renderToDOM = (text, target, opts = {}) ->
    el = if typeof target is 'string' then document.querySelector target else target
    throw new Error "#{ NAME } Target element not found: #{ target }" unless el?

    compile(text, opts).then (result) ->
      # Inject styles
      if result.style
        styleTag = document.createElement 'style'
        styleTag.textContent = result.style
        document.head.appendChild styleTag

      # Inject HTML
      el.innerHTML = result.template

      # Execute JS if present
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
