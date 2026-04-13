# server/src/server.coffee
# LSP server entry point. Creates connection, registers all providers.

{
  createConnection, ProposedFeatures,
  TextDocuments, TextDocumentSyncKind
} = require 'vscode-languageserver/node'

{ TextDocument } = require 'vscode-languageserver-textdocument'
{ validate } = require './diagnostics'
{ getSymbols } = require './symbols'
{ getFoldingRanges } = require './folding'
{ getHover } = require './hover'
{ getCompletions } = require './completion'
# Semantic tokens temporarily disabled: vscode-languageserver doesn't expose
# onDocumentSemanticTokens directly. Use TextMate grammar for highlighting instead.

connection = createConnection ProposedFeatures.all
documents = new TextDocuments TextDocument

connection.onInitialize (params) ->
  {
    capabilities:
      textDocumentSync: TextDocumentSyncKind.Incremental
      documentSymbolProvider: true
      foldingRangeProvider: true
      hoverProvider: true
      completionProvider:
        resolveProvider: false
        triggerCharacters: ['=', '#', ':']
  }

# Diagnostics on content change
documents.onDidChangeContent (event) ->
  doc = event.document
  diagnostics = validate doc.uri, doc.getText()
  connection.sendDiagnostics { uri: doc.uri, diagnostics }

# Document symbols
connection.onDocumentSymbol (params) ->
  doc = documents.get params.textDocument.uri
  return [] unless doc
  getSymbols doc.uri, doc.getText()

# Folding ranges
connection.onFoldingRanges (params) ->
  doc = documents.get params.textDocument.uri
  return [] unless doc
  getFoldingRanges doc.uri, doc.getText()

# Hover
connection.onHover (params) ->
  doc = documents.get params.textDocument.uri
  return null unless doc
  getHover doc.uri, doc.getText(), params.position

# Completion
connection.onCompletion (params) ->
  doc = documents.get params.textDocument.uri
  return [] unless doc
  getCompletions doc.uri, doc.getText(), params.position

documents.listen connection
connection.listen()
