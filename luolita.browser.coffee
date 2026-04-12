###
luolita.browser.coffee — Luolita SFC compiler for the browser

Bundled with esbuild into dist/luolita.browser.bundle.js.
Usage:
  <script src="luolita.browser.bundle.js"></script>
###

cfs = require "coffeescript"
pug = require "pug"
sty = require "./luolita.stylus.js"

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
    inTripleQuote = false
    tripleQuoteChar = null
    tripleName = ''
    tripleLines = []
    for line in coffeeSrc.split '\n'
      # Track triple-quote blocks
      if inTripleQuote
        if line.includes tripleQuoteChar
          # Closing triple-quote — save accumulated content
          beforeClose = line.split(tripleQuoteChar)[0]
          if beforeClose.trim()
            tripleLines.push beforeClose
          # Join lines, strip common indent
          content = tripleLines.join '\n'
          vars[tripleName] = dedent content
          inTripleQuote = false
          tripleQuoteChar = null
          tripleName = ''
          tripleLines = []
        else
          tripleLines.push line
        continue
      if /'''|"""/.test line
        inTripleQuote = true
        tripleQuoteChar = if line.includes "'''" then "'''" else '"""'
        # Check if this is a variable assignment line: varName = '''
        assignMatch = line.match /^\s*([a-zA-Z_$][a-zA-Z0-9_$]*)\s*=\s*'''$/
        if assignMatch
          tripleName = assignMatch[1]
          tripleLines = []
          continue
        # If opening and closing triple-quote on same line, toggle off immediately
        parts = line.split tripleQuoteChar
        if parts.length >= 3
          inTripleQuote = false
          tripleQuoteChar = null
        continue

      match = line.match /^\s*([a-zA-Z_$][a-zA-Z0-9_$]*)\s*=\s*(.+)$/
      if match
        raw = match[2].trim()
        # Triple-quote start
        if /^'''|^"""/.test raw
          inTripleQuote = true
          tripleName = match[1]
          tripleQuoteChar = if raw.startsWith "'''" then "'''" else '"""'
          tripleLines = []
          # Check if content is on same line after opening quotes
          afterOpen = raw.substring 3
          if afterOpen.length > 0
            tripleLines.push afterOpen
          continue
        # Quoted string literals — extract directly
        if /^".*"$/.test raw
          vars[match[1]] = raw.slice 1, -1
        else if /^'.*'$/.test raw
          vars[match[1]] = raw.slice 1, -1
        else
          # Try to parse as JSON (arrays, objects, numbers, booleans)
          try
            vars[match[1]] = JSON.parse raw
          catch e
            # Bare identifier or invalid — store as raw string
            vars[match[1]] = raw
    vars

  # --- Compile stylus (returns CSS string via callback) ---
  compileStylus = (src, vars) ->
    new Promise (resolve, reject) ->
      sty.render dedent(src), (err, css) ->
        if err then reject err else resolve css

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
    .catch (err) ->
      console.error "#{ NAME } compile error:", err
      el.textContent = 'Compile error: ' + err.message

  # Expose
  window.Luolita =
    compile: compile
    renderToDOM: renderToDOM
    VERSION: '0.1.4'

  console.log "#{ NAME } v#{ window.Luolita.VERSION } loaded."
  console.log "#{ NAME } CoffeeScript #{ cfs.VERSION }"

  # --- Auto-init: find all <link rel="luolita" href="..."> and render ---
  init = ->
    links = document.querySelectorAll 'link[rel="luolita"]'
    return if links.length is 0
    console.log "#{ NAME } Auto-init: found #{ links.length } luolita link(s)"
    for link in links
      do (link) ->
        href = link.getAttribute 'href'
        return unless href?
        console.log "#{ NAME } Auto-init: loading #{ href }"
        fetch(href)
          .then (res) -> res.text()
          .then (text) ->
            compile(text, {}).then (result) ->
              if result.style
                styleTag = document.createElement 'style'
                styleTag.textContent = result.style
                document.head.appendChild styleTag

              if result.template
                wrapper = document.createElement 'div'
                wrapper.innerHTML = result.template
                while wrapper.firstChild
                  document.body.appendChild wrapper.firstChild

              if result.coffee?.js
                scriptTag = document.createElement 'script'
                scriptTag.textContent = result.coffee.js
                document.body.appendChild scriptTag
            .catch (err) ->
              console.error "#{ NAME } Compile error:", err
          .catch (err) ->
            console.error "#{ NAME } Fetch error (#{ href }):", err

  init()
