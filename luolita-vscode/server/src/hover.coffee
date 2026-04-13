# server/src/hover.coffee
# Hover provider: section type info on marker lines, variable values in coffee sections.

{ parse, sfcVarBridge, extractVariableRanges } = require './parser'

sectionDescriptions =
  coffee:   'CoffeeScript section — compiles to JavaScript'
  template: 'Pug template section — compiles to HTML'
  style:    'Stylus style section — compiles to CSS'

getHover = (uri, text, position) ->
  doc = parse uri, text
  hoverLine = position.line

  # 1. Hover over a marker line
  for section in doc.sections
    if hoverLine is section.startLine
      desc = sectionDescriptions[section.name] or "#{section.name} section"
      endLine = if section.endLine >= 0 then section.endLine + 1 else section.startLine + 1
      return
        contents:
          kind: 'markdown'
          value: "**#{desc}**\n\nLines #{section.contentStartLine + 1}–#{endLine}"
        range:
          start: { line: hoverLine, character: 0 }
          end: { line: hoverLine, character: section.name.length + 1 }

  # 2. Hover over a variable name in coffee section
  for section in doc.sections when section.name is 'coffee'
    if hoverLine >= section.contentStartLine and hoverLine <= section.endLine
      lineOffset = hoverLine - section.contentStartLine
      lineText = (section.content.split '\n')[lineOffset] or ''
      if (match = lineText.match /^(\s*)([a-zA-Z_$][a-zA-Z0-9_$]*)\s*=\s*(.+)$/)
        nameStart = match[1].length
        nameEnd = nameStart + match[2].length
        if position.character >= nameStart and position.character <= nameEnd
          return
            contents:
              kind: 'markdown'
              value: "`#{match[2]}` = `#{match[3].trim()}`"
            range:
              start: { line: hoverLine, character: nameStart }
              end: { line: hoverLine, character: nameEnd }

  null

module.exports = { getHover }
