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
  # Values may span lines (arrays/objects/implicit objects), use single
  # quotes or bare keys — anything the real CoffeeScript compiler accepts.
  # Evaluation runs in a sandbox (stub window/document/console); any group
  # that throws falls back to the legacy single-value handling below, so a
  # single bad apple never spoils the rest.
  BRIDGE_STUB_NAMES = ['window', 'document', 'console', 'localStorage', 'navigator', 'fetch']
  bridgeStubValues = ->
    silent = log: (->), error: (->), warn: (->), info: (->), debug: (->)
    [{}, {}, silent, {}, {}, (-> Promise.reject new Error 'fetch not available in bridge')]

  indentWidth = (line) ->
    m = line.match /^(\s*)/
    if m then m[1].length else 0

  CONT_RE = /[=,:\[({+\-*\/\%&|?]\s*$|->\s*$|=>\s*$/

  # bracket depth outside strings/comments (rough; eval failure falls back)
  bracketDepth = (text) ->
    depth = 0
    inStr = null
    i = 0
    while i < text.length
      ch = text[i]
      if inStr
        if ch is '\\'
          i += 2
          continue
        if ch is inStr
          inStr = null
      else if ch is '"' or ch is "'" or ch is '`'
        inStr = ch
      else if ch is '#' and text[i+1] isnt '{'
        while i < text.length and text[i] isnt '\n'
          i += 1
        continue
      else if ch is '[' or ch is '{' or ch is '('
        depth += 1
      else if ch is ']' or ch is '}' or ch is ')'
        depth -= 1
      i += 1
    depth

  # Pull out triple-quoted assignments first, keeping legacy raw semantics
  # (no #{} interpolation); blank the region so group collection skips it.
  extractTripleStrings = (lines) ->
    triples = {}
    code = []
    i = 0
    while i < lines.length
      line = lines[i]
      qi = line.indexOf "'''"
      qd = line.indexOf '"""'
      q = null
      if qi isnt -1 and (qd is -1 or qi < qd)
        q = "'''"
      else if qd isnt -1
        q = '"""'
      unless q
        code.push line
        i += 1
        continue
      am = line.match ///^([a-zA-Z_$][a-zA-Z0-9_$]*)\s*=\s*#{q}(.*)$///
      occ = line.split(q).length - 1
      if occ >= 2
        if am
          triples[am[1]] = line.split(q)[1]
        i += 1
        continue
      if am
        acc = []
        if am[2].trim()
          acc.push am[2]
        i += 1
        while i < lines.length and lines[i].indexOf(q) is -1
          acc.push lines[i]
          i += 1
        if i < lines.length
          before = lines[i].split(q)[0]
          if before.trim()
            acc.push before
          i += 1
        triples[am[1]] = dedent acc.join '\n'
      else
        i += 1
        while i < lines.length and lines[i].indexOf(q) is -1
          i += 1
        if i < lines.length
          i += 1
      continue
    {triples, code}

  # Collect top-level `name = value` groups, joining continuation lines.
  # A group starting with an empty value (`cfg =` alone) consumes the whole
  # following indented block (implicit object / indented expression).
  collectAssignGroups = (lines) ->
    groups = []
    i = 0
    while i < lines.length
      line = lines[i]
      m = line.match /^([a-zA-Z_$][a-zA-Z0-9_$]*)\s*=\s*(?![=>])(.*)$/
      unless m
        i += 1
        continue
      buf = [line]
      vals = [m[2]]
      j = i + 1
      blockForm = m[2].trim() is ''
      loop
        depth = bracketDepth buf.join '\n'
        if depth > 0
          break if j >= lines.length
          buf.push lines[j]
          vals.push lines[j]
          j += 1
          continue
        if blockForm
          break if j >= lines.length or indentWidth(lines[j]) is 0
          buf.push lines[j]
          vals.push lines[j]
          j += 1
          continue
        last = buf[buf.length - 1].replace /\s+$/, ''
        if CONT_RE.test(last) and j < lines.length and indentWidth(lines[j]) > 0
          buf.push lines[j]
          vals.push lines[j]
          j += 1
          continue
        break
      groups.push name: m[1], code: buf.join('\n'), value: vals.join('\n')
      i = j
    groups

  # Only JSON-like values cross the bridge (strings/numbers/booleans/null
  # and plain arrays/objects thereof). Anything else — module objects,
  # class instances, functions — falls back to the legacy raw string, so a
  # bare identifier like `title = Luolita` keeps its old meaning instead of
  # resolving against page globals.
  isPlainData = (v, seen = null) ->
    return true if v is null
    t = typeof v
    return true if t is 'string' or t is 'number' or t is 'boolean'
    return false if t isnt 'object'
    seen ?= new Set()
    return false if seen.has v
    seen.add v
    proto = Object.getPrototypeOf v
    if Array.isArray v
      return v.every (x) -> isPlainData x, seen
    return false if proto isnt Object.prototype and proto isnt null
    Object.values(v).every (x) -> isPlainData x, seen

  # Evaluate groups progressively in a sandbox; failed groups are skipped
  # here and handled by the legacy fallback by the caller.
  evalBridgeGroups = (groups) ->
    ok = {}
    scope = ''
    for g in groups
      trial = if scope then scope + '\n' + g.code else g.code
      try
        js = cfs.compile trial, bare: true, header: false
        fn = new Function BRIDGE_STUB_NAMES.join(','), js + '\nreturn ' + g.name + ';'
        v = fn.apply null, bridgeStubValues()
        if isPlainData v
          ok[g.name] = v
          scope = trial
      catch
        continue
    ok

  legacyBridgeValue = (raw) ->
    t = raw.trim()
    return null if t is ''
    if /^".*"$/.test(t) or /^'.*'$/.test(t)
      t.slice 1, -1
    else
      try
        JSON.parse t
      catch
        t

  sfcVarBridge = (coffeeSrc) ->
    {triples, code} = extractTripleStrings coffeeSrc.split '\n'
    vars = triples
    groups = collectAssignGroups code
    ok = evalBridgeGroups groups
    for g in groups
      if g.name of ok
        vars[g.name] = ok[g.name]
      else
        v = legacyBridgeValue g.value
        vars[g.name] = v unless v is null
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
    VERSION: '0.1.5'

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
