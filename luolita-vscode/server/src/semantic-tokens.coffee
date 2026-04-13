# server/src/semantic-tokens.coffee
# SemanticTokens provider: highlight section markers and coffee variable declarations.

{ SemanticTokensBuilder } = require 'vscode-languageserver'
{ parse } = require './parser'

# Legend indices
TOKEN_TYPES = keyword: 0, variable: 1
TOKEN_MODIFIERS = declaration: 0

LEGEND =
  tokenTypes: ['keyword', 'variable']
  tokenModifiers: ['declaration']

getSemanticTokens = (uri, text) ->
  doc = parse uri, text
  builder = new SemanticTokensBuilder()

  for section in doc.sections
    # Marker keyword
    builder.push section.startLine, 0, section.name.length + 1, TOKEN_TYPES.keyword, 0

    # Variable declarations in coffee
    if section.name is 'coffee'
      for lineIndex, line in section.content.split '\n'
        if (match = line.match /^(\s*)([a-zA-Z_$][a-zA-Z0-9_$]*)\s*=/)
          absLine = section.contentStartLine + lineIndex
          builder.push absLine, match[1].length, match[2].length, TOKEN_TYPES.variable, TOKEN_MODIFIERS.declaration

  builder.build()

module.exports = { getSemanticTokens, LEGEND }
