# server/src/completion.coffee
# CompletionItem provider: suggest section markers at line start,
# suggest coffee variable names inside template interpolations.

{ CompletionItemKind, InsertTextFormat } = require 'vscode-languageserver'
{ parse, MARKER_NAMES } = require './parser'

getCompletions = (uri, text, position) ->
  items = []
  lines = text.split '\n'
  currentLine = lines[position.line] or ''

  # 1. Suggest section markers on empty/whitespace-only lines
  if currentLine.match /^\s*$/
    for marker in MARKER_NAMES
      items.push
        label: "#{marker}:"
        kind: CompletionItemKind.Keyword
        insertText: "#{marker}:\n  "
        insertTextFormat: InsertTextFormat.Snippet
        detail: "Luolita #{marker} section"
        documentation: "Starts a #{marker} section. Content must be indented."

  # 2. Suggest variable names in template section
  doc = parse uri, text
  currentSection = doc.sectionAtLine position.line

  if currentSection?.name is 'template'
    beforeCursor = currentLine.substring 0, position.character
    # Match Pug interpolation contexts: #{  or  =  or  each x in
    if beforeCursor.match /#\{\s*$|=\s*$|each\s+\w*\s+in\s+$/
      bridgeVars = doc.getBridgeVars()
      for name, val of bridgeVars
        displayValue = if typeof val is 'string' then val else JSON.stringify val
        items.push
          label: name
          kind: CompletionItemKind.Variable
          insertText: name
          detail: "CoffeeScript variable"
          documentation: "Value: #{displayValue}"

  items

module.exports = { getCompletions }
