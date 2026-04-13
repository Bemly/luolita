# server/src/folding.coffee
# FoldingRange provider: fold each section from marker to last content line.

{ FoldingRangeKind } = require 'vscode-languageserver'
{ parse } = require './parser'

foldingKindMap =
  coffee:   FoldingRangeKind.Imports
  template: FoldingRangeKind.Markup
  style:    FoldingRangeKind.Region

getFoldingRanges = (uri, text) ->
  doc = parse uri, text
  ranges = []

  for section in doc.sections
    if section.endLine > section.startLine
      ranges.push
        startLine: section.startLine
        endLine: section.endLine
        kind: foldingKindMap[section.name] or FoldingRangeKind.Region

  ranges

module.exports = { getFoldingRanges }
