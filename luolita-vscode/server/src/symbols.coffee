# server/src/symbols.coffee
# DocumentSymbol provider: sections as top-level symbols, coffee variables as children.

{ SymbolKind } = require 'vscode-languageserver'
{ parse, extractVariableRanges } = require './parser'

sectionInfo =
  coffee:   { kind: SymbolKind.Function, label: 'CoffeeScript' }
  template: { kind: SymbolKind.Module,   label: 'Template (Pug)' }
  style:    { kind: SymbolKind.Class,    label: 'Style (Stylus)' }

getSymbols = (uri, text) ->
  doc = parse uri, text
  symbols = []

  for section in doc.sections
    info = sectionInfo[section.name] or { kind: SymbolKind.Namespace, label: section.name }
    endLine = if section.endLine >= 0 then section.endLine else section.startLine
    lastLineContent = if section.endLine >= 0 then (section.content.split('\n').pop() or '') else ''

    symbol =
      name: info.label
      kind: info.kind
      range:
        start: { line: section.startLine, character: 0 }
        end: { line: endLine, character: lastLineContent.length }
      selectionRange:
        start: { line: section.startLine, character: 0 }
        end: { line: section.startLine, character: section.name.length + 1 }

    if section.name is 'coffee'
      varRanges = extractVariableRanges section
      if varRanges.length > 0
        symbol.children = varRanges.map (v) ->
          name: v.name
          kind: SymbolKind.Variable
          range: v.range
          selectionRange: v.range

    symbols.push symbol

  symbols

module.exports = { getSymbols }
