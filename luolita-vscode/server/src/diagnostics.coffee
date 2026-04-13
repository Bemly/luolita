# server/src/diagnostics.coffee
# Validates .luoli files: checks markers, compiles each section,
# maps compiler errors back to absolute source line numbers.

cfs = require 'coffeescript'
pug = require 'pug'
stylus = require 'stylus'
{ parse, sfcVarBridge } = require './parser'

# Strip common leading indentation (matches luolita.coffee dedent behavior)
dedent = (text) ->
  lines = text.split '\n'
  nonEmpty = lines.filter (l) -> l.trim().length > 0
  return text if nonEmpty.length is 0

  minIndent = null
  for line in nonEmpty
    indent = line.match(/^(\s*)/)[1].length
    if minIndent is null or indent < minIndent
      minIndent = indent

  return text if minIndent is 0
  (line.substring(minIndent) for line in lines).join '\n'

Severity =
  Error: 1
  Warning: 2
  Information: 3
  Hint: 4

validate = (uri, text) ->
  doc = parse uri, text
  diagnostics = []

  # 1. Invalid markers (leading whitespace)
  for inv in doc.invalidMarkers
    diagnostics.push
      severity: Severity.Error
      range:
        start: { line: inv.line, character: 0 }
        end: { line: inv.line, character: inv.text.length }
      message: "Marker '#{inv.marker}:' must not have leading whitespace. Markers must start at column 0."
      source: 'luolita'
      code: 'INVALID_MARKER'

  # 2. Orphan lines before first marker
  for info in doc.orphanLines
    diagnostics.push
      severity: Severity.Information
      range:
        start: { line: info.line, character: 0 }
        end: { line: info.line, character: info.text.length }
      message: "Lines before the first section marker are ignored."
      source: 'luolita'
      code: 'ORPHAN_LINE'

  # 3. No sections at all
  if doc.sections.length is 0
    diagnostics.push
      severity: Severity.Warning
      range:
        start: { line: 0, character: 0 }
        end: { line: 0, character: 0 }
      message: "No sections found. Expected markers: coffee:, template:, style:"
      source: 'luolita'
      code: 'NO_SECTIONS'

  # 4. Collect bridge variables from all coffee sections
  bridgeVars = {}
  coffeeContent = (s.content for s in doc.sections when s.name is 'coffee').join '\n'
  if coffeeContent
    for key, val of sfcVarBridge coffeeContent
      try
        bridgeVars[key] = cfs.eval val, bare: true
      catch
        bridgeVars[key] = val

  # 5. Compile each section
  for section in doc.sections
    switch section.name
      when 'coffee'
        content = section.content.replace /\n+$/, ''
        if content
          try
            cfs.compile dedent(content), bare: true, header: false
          catch err
            diagnostics.push mapCoffeeError section, err

      when 'template'
        content = section.content.replace /\n+$/, ''
        if content
          try
            fn = pug.compile dedent(content)
            fn bridgeVars
          catch err
            diagnostics.push mapPugError section, err

      when 'style'
        content = section.content.replace /\n+$/, ''
        if content
          try
            stylus.render dedent(content)
          catch err
            diagnostics.push mapStylusError section, err

  diagnostics

mapCoffeeError = (section, err) ->
  relLine = null
  # CoffeeScript provides location as error property
  if err.location?.first_line?
    relLine = err.location.first_line + 1  # Convert to 1-based for consistency
  else
    relLine = extractLineFromError err.message
  absLine = if relLine? then section.contentStartLine + relLine - 1 else section.startLine
  {
    severity: Severity.Error
    range:
      start: { line: absLine, character: 0 }
      end: { line: absLine, character: 9999 }
    message: "CoffeeScript: #{err.message}"
    source: 'luolita'
    code: 'COFFEESCRIPT'
  }

mapPugError = (section, err) ->
  relLine = if err.line? then err.line else extractLineFromError err.message
  absLine = if relLine? then section.contentStartLine + relLine - 1 else section.startLine
  {
    severity: Severity.Error
    range:
      start: { line: absLine, character: 0 }
      end: { line: absLine, character: 9999 }
    message: "Pug: #{err.message}"
    source: 'luolita'
    code: 'PUG'
  }

mapStylusError = (section, err) ->
  # Stylus errors often look like "stylus:3:5: expected ..."
  relLine = extractLineFromError err.message
  # Also try stylus-specific format
  if not relLine?
    stylusMatch = err.message?.match /stylus:(\d+)/
    relLine = parseInt(stylusMatch[1]) if stylusMatch

  absLine = if relLine? then section.contentStartLine + relLine - 1 else section.startLine
  {
    severity: Severity.Error
    range:
      start: { line: absLine, character: 0 }
      end: { line: absLine, character: 9999 }
    message: "Stylus: #{err.message}"
    source: 'luolita'
    code: 'STYLUS'
  }

# Extract 1-based line number from compiler error messages
extractLineFromError = (msg) ->
  return null unless msg
  # Common patterns: "on line 3", ":3:5", "line 3"
  if (m = msg.match /\bon line (\d+)/)
    return parseInt m[1]
  if (m = msg.match /^(\w+):(\d+)/)
    return parseInt m[2]
  null

module.exports = { validate }
