# Luolita Language Support

Language server for `.luoli` Single-File Component (SFC) files.

[![Version](https://img.shields.io/visual-studio-marketplace/v/bemly.luolita-vscode)](https://marketplace.visualstudio.com/items?itemName=bemly.luolita-vscode)

## Features

| Feature | Description |
|---|---|
| **Diagnostics** | Real-time compilation errors for CoffeeScript, Pug, and Stylus sections, mapped to correct source lines |
| **Document Symbols** | Sections and variables visible in Outline view and Breadcrumbs |
| **Folding** | Collapse `coffee:`, `template:`, and `style:` sections |
| **Hover** | Section type info and variable values on hover |
| **Completion** | Suggests section markers on empty lines and variable names in template interpolations |
| **Syntax Highlighting** | Colorized section markers and embedded language regions |

## What is `.luoli`?

Luolita (萝莉塔) is a Vue-like Single-File Component generator. A `.luoli` file contains up to three sections:

```luoli
coffee:
  title = "Hello World"

template:
  h1= title

style:
  h1
    color: #6b9f93
```

Each section is compiled into its respective language:
- `coffee:` → CoffeeScript → JavaScript
- `template:` → Pug → HTML
- `style:` → Stylus → CSS

Learn more: [GitHub Repository](https://github.com/Bemly/luolita)

## Commands

| Command | Description |
|---|---|
| `Luolita: Compile Current File` | Compile the active `.luoli` file |

## Configuration

| Setting | Default | Description |
|---|---|---|
| `luolita.outputDir` | `temp` | Default output directory for compiled files |
| `luolita.trace.server` | `off` | Trace communication between VS Code and the language server (useful for debugging) |

## Requirements

- Node.js >= 20 LTS
- VS Code >= 1.85.0

## Building from Source

```bash
git clone https://github.com/Bemly/luolita.git
cd luolita/luolita-vscode
pnpm install
pnpm run build
```

Press `F5` in VS Code to launch the extension in debug mode.

## License

[WTFPL](http://www.wtfpl.net/)
