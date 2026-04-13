# client/src/extension.coffee
# VS Code extension entry point. Starts the Luolita language server.

path = require 'path'
{ workspace, extensions, commands, window } = require 'vscode'
{
  LanguageClient, TransportKind, ServerOptions
} = require 'vscode-languageclient/node'

client = null

activate = (context) ->
  # Server module path (compiled JS output)
  serverModule = context.asAbsolutePath path.join 'out', 'server', 'server.js'

  serverOptions =
    module: serverModule
    transport: TransportKind.ipc

  clientOptions =
    documentSelector: [{ scheme: 'file', language: 'luolita' }]
    synchronize:
      fileEvents: workspace.createFileSystemWatcher '**/*.luoli'
    initializationOptions:
      outputDir: workspace.getConfiguration('luolita').get('outputDir', 'temp')

  client = new LanguageClient(
    'luolita'
    'Luolita Language Server'
    serverOptions
    clientOptions
  )

  client.start()

  # Register compile command
  compileCmd = commands.registerCommand 'luolita.compile', ->
    window.showInformationMessage 'Luolita compile command — connect to your CLI build pipeline.'

  context.subscriptions.push compileCmd
  client

deactivate = ->
  if client
    client.stop()
  undefined

module.exports = { activate, deactivate }
