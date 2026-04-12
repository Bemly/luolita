###
  luolita.stylus.coffee — Lightweight Stylus-to-CSS compiler for the browser

  Pure browser-side implementation. No Node.js dependencies.
  Supports: indentation-based nesting, variables, & parent reference,
  multi-selectors, CSS pass-through values.

  API: stylus.render src, (err, css) ->
###

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

# --- Resolve variable references in a value string ---
resolveVars = (value, vars) ->
  return value unless vars and Object.keys(vars).length > 0

  parts = value.split /\s+/
  resolved = parts.map (part) ->
    trimmed = part.replace /[,;]$/, ''
    suffix = if part.endsWith ',' then ',' else if part.endsWith ';' then ';' else ''

    isVarName = /^[\w-]+$/.test trimmed
    if isVarName and Object::hasOwnProperty.call(vars, trimmed)
      # Recursively resolve (handles variables referencing other variables)
      resolveVars(vars[trimmed], vars) + suffix
    else
      part
  resolved.join ' '

# --- Tokenize Stylus source into flat token list ---
tokenize = (src) ->
  src = dedent src
  rawLines = src.split '\n'

  # Determine indent unit from smallest non-zero indent
  indents = rawLines
    .filter (l) -> l.trim().length > 0
    .map (l) -> l.match(/^(\s*)/)[1].length
    .filter (n) -> n > 0
  indentUnit = if indents.length > 0 then Math.min ...indents else 2

  tokens = []
  for line in rawLines
    trimmed = line.trim()
    continue if trimmed.length is 0
    continue if trimmed.startsWith '//'

    indent = line.match(/^(\s*)/)[1].length
    level = Math.round indent / indentUnit

    # Variable: name = value
    varMatch = trimmed.match /^([a-zA-Z_$][\w-]*)\s*=\s*(.+)$/
    if varMatch
      tokens.push
        type: 'variable'
        level: level
        name: varMatch[1]
        value: varMatch[2].trim()
      continue

    # Property: propertyName: value
    # Only match if the part before colon looks like a CSS property name
    # Allow digits for CSS custom properties like --vp-c-brand-1
    propMatch = trimmed.match /^([\w-]+)\s*:\s*(.+)$/
    if propMatch
      tokens.push
        type: 'property'
        level: level
        name: propMatch[1]
        value: propMatch[2].trim()
      continue

    # Selector: everything else
    tokens.push
      type: 'selector'
      level: level
      selector: trimmed

  tokens

# --- Build AST from token list ---
# Uses a stack-based approach to correctly handle nesting
buildAST = (tokens) ->
  result = []
  stack = [{ children: result }]  # virtual root

  for token in tokens
    node =
      type: token.type
      selector: token.selector
      name: token.name
      value: token.value
      level: token.level
      children: []

    # Pop stack until we find a parent with lower level
    while stack.length > 1 and stack[stack.length - 1].level >= token.level
      stack.pop()

    # Add this node to parent's children
    stack[stack.length - 1].children.push node

    # Push onto stack (it may have children)
    stack.push node

  # Clean up: remove level property and empty children arrays
  clean = (nodes) ->
    for n in nodes
      delete n.level
      if n.type is 'property'
        # keep name and value
      else if n.type is 'variable'
        # keep name and value
        delete n.selector
        delete n.children
      else if n.type is 'selector'
        delete n.name
        delete n.value
        delete n.children if n.children?.length is 0
        clean n.children if n.children?
    nodes

  clean result

# --- Compile AST to CSS string ---
compileAST = (nodes, parentSelector = '', vars = {}) ->
  cssParts = []

  for node in nodes
    if node.type is 'variable'
      # Top-level variable — register it
      vars[node.name] = node.value
      continue

    if node.type is 'property'
      # Top-level property (shouldn't happen in valid Stylus, skip)
      continue

    if node.type is 'selector'
      selector = node.selector

      # Resolve & parent reference
      if selector.includes '&'
        sel = selector.replace /&/g, parentSelector
      else if parentSelector
        sel = parentSelector + ' ' + selector
      else
        sel = selector

      # Collect properties and child selectors from children
      properties = []
      childSelectors = []
      childVars = {}

      for child in node.children
        if child.type is 'property'
          properties.push child
        else if child.type is 'selector'
          childSelectors.push child
        else if child.type is 'variable'
          childVars[child.name] = child.value

      # Merge child variables into current scope
      Object.assign vars, childVars

      # Compile properties to CSS
      if properties.length > 0
        propLines = properties.map (p) ->
          val = resolveVars p.value, vars
          "  #{ p.name }: #{ val };"
        cssParts.push "#{ sel } {\n#{ propLines.join '\n' }\n}"

      # Recursively compile child selectors
      if childSelectors.length > 0
        childCss = compileAST childSelectors, sel, vars
        cssParts.push childCss

  cssParts.join '\n\n'

# --- Main render API (matches Stylus signature) ---
render = (src, options, callback) ->
  if typeof options is 'function'
    callback = options
    options = {}

  try
    tokens = tokenize src
    ast = buildAST tokens
    css = compileAST ast, '', {}
    callback null, css.trim()
  catch err
    callback err, null

module.exports = { render, tokenize, buildAST, compileAST }
