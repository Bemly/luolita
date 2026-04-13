# server/src/parser.coffee
# Core parser for .luoli files. Extracts section ranges, variable positions,
# and validates marker syntax. All line numbers are 0-based (LSP Position convention).

MARKER_NAMES = ['coffee', 'template', 'style']
MARKER_REGEX = /^(coffee|template|style):\s*$/
# Only flag as invalid marker if whitespace is small (1-3 chars)
# to avoid false positives from markers inside triple-quoted strings
INVALID_MARKER_REGEX = /^(\s{1,3})(coffee|template|style):\s*$/
VAR_ASSIGN_REGEX = /^\s*([a-zA-Z_$][a-zA-Z0-9_$]*)\s*=\s*(.+)$/

# Track triple-quoted string state to avoid false marker detection
_toggleTripleQuote = (inTriple, quoteChar, lineText) ->
  # Count unescaped occurrences of the triple-quote
  count = 0
  pos = 0
  while (pos = lineText.indexOf quoteChar, pos) != -1
    count++
    pos += 3
  # Odd count toggles state, even count keeps it
  if count % 2 is 1 then not inTriple else inTriple

class LuolitaSection
  constructor: (@name, @startLine, @contentStartLine) ->
    @endLine = -1
    @content = ''

class LuolitaDocument
  constructor: (@uri, @text) ->
    @sections = []
    @invalidMarkers = []
    @orphanLines = []

  getBridgeVars: ->
    vars = {}
    for section in @sections when section.name is 'coffee'
      bridge = sfcVarBridge section.content
      Object.assign vars, bridge
    vars

  sectionAtLine: (line) ->
    for section in @sections
      if line >= section.startLine and line <= (if section.endLine >= 0 then section.endLine else section.startLine)
        return section
    null

parse = (uri, text) ->
  doc = new LuolitaDocument(uri, text)
  lines = text.split '\n'

  currentSection = null
  foundFirstMarker = false
  inTripleSingle = false  # inside '''
  inTripleDouble = false  # inside """

  for i in [0...lines.length]
    lineText = lines[i]

    # Track triple-quoted string state (CoffeeScript '''  and """)
    inTripleSingle = _toggleTripleQuote inTripleSingle, "'''", lineText unless inTripleDouble
    inTripleDouble = _toggleTripleQuote inTripleDouble, '"""', lineText unless inTripleSingle

    # Skip marker detection inside triple-quoted strings
    insideString = inTripleSingle or inTripleDouble

    unless insideString
      # Check for valid marker (must start at column 0)
      if MARKER_REGEX.test lineText.trimEnd()
        match = lineText.trimEnd().match /^(coffee|template|style):/
        currentSection = new LuolitaSection(match[1], i, i + 1)
        doc.sections.push currentSection
        foundFirstMarker = true
        continue

      # Check for invalid marker (small leading whitespace)
      if (indentMatch = lineText.match INVALID_MARKER_REGEX)
        doc.invalidMarkers.push
          line: i
          text: lineText
          marker: indentMatch[2]
          leadingWhitespace: indentMatch[1]
        foundFirstMarker = true
        continue

    # Accumulate content
    if currentSection?
      currentSection.content += lineText + '\n'
      currentSection.endLine = i
    else if not foundFirstMarker and lineText.trim().length > 0
      doc.orphanLines.push
        line: i
        text: lineText

  doc

sfcVarBridge = (coffeeSrc) ->
  vars = {}
  for line in coffeeSrc.split '\n'
    if (match = line.match VAR_ASSIGN_REGEX)
      vars[match[1]] =
        value: match[2].trim()
        raw: line.trim()
  vars

# Extract variable ranges with absolute line positions in the document
extractVariableRanges = (coffeeSection) ->
  vars = []
  lines = coffeeSection.content.split '\n'
  for i in [0...lines.length]
    lineText = lines[i]
    if (match = lineText.match /^(\s*)([a-zA-Z_$][a-zA-Z0-9_$]*)\s*=\s*(.+)$/)
      indent = match[1]
      name = match[2]
      absLine = coffeeSection.contentStartLine + i
      startChar = indent.length
      endChar = startChar + name.length
      vars.push
        name: name
        value: match[3].trim()
        range:
          start: { line: absLine, character: startChar }
          end: { line: absLine, character: endChar }
  vars

module.exports = {
  parse, LuolitaDocument, LuolitaSection,
  sfcVarBridge, extractVariableRanges,
  MARKER_NAMES, MARKER_REGEX
}
