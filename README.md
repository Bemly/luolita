# Luolita

A Vue-like Single-File Component generator\
Parses ".luoli" files into 3 syntactic sugars: CoffeeScript, Pug, and Stylus

[中文版](README.zh.md)

## Quick Start

Prerequisites:
1. Node.js
2. npm
3. pnpm >= 9 (optional, recommended, for JSON5 support)

Install dependencies:
```bash
pnpm install
```

Usage:
```bash
# Default: parse temp/test.luoli
pnpm test

# Specify input and output
pnpm exec coffee luolita.coffee src/app.luoli -o dist -n app

# Show help
pnpm exec coffee luolita.coffee --help
```

## Editor Support

Install the **[Luolita Language Support](https://marketplace.visualstudio.com/items?itemName=bemly.luolita-vscode)** extension for full IDE experience in VS Code:

- Real-time diagnostics (CoffeeScript / Pug / Stylus compilation errors with correct line numbers)
- Document symbols (sections + variables) in Outline view
- Code folding by section (`coffee:`, `template:`, `style:`)
- Hover information (section type, variable values)
- Auto-completion (section markers, variable names in template interpolations)
- Syntax highlighting

Requires Node.js >= 20 and VS Code >= 1.85.0.

## Browser Usage

Load `.luoli` files directly in the browser with zero external dependencies:

**Auto-render (recommended)**: Declarative loading with `<link rel="luolita">`, renders on page open:

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>My App</title>
  <link rel="luolita" href="app.luoli">
  <link rel="luolita" href="components.luoli">
  <script src="luolita.browser.bundle.js"></script>
</head>
</html>
```

Multiple `<link>` tags are supported and rendered sequentially.

**Manual render**: Control timing and target via JS API:

```html
<script src="luolita.browser.bundle.js"></script>

<script>
  fetch('example.luoli')
    .then(function (res) { return res.text() })
    .then(function (text) {
      Luolita.renderToDOM(text, '#app', { outputName: 'example' })
    })
</script>
```

## Browser Build

`luolita.browser.bundle.js` is in `docs/`. To build it yourself:

```bash
# 1. Compile CoffeeScript to JS
pnpm exec coffee -c -p luolita.browser.coffee > dist/luolita.browser.js

# 2. esbuild bundle + inject Node.js module stubs
node docs/bundle.cjs

# Output: dist/luolita.browser.bundle.js, also copied to docs/
```

`Luolita` API:

| Method | Description | Returns |
|---|---|---|
| `Luolita.compile(text, opts)` | Compiles `.luoli` text | `Promise<{ coffee: {js, map}, template, style }>` |
| `Luolita.renderToDOM(text, target, opts)` | Compiles and renders to DOM element | void |

- `opts.outputName` — Output file prefix (available as `name` variable in templates)
- `opts.debug` — Print debug logs (default `true`)

See the [live demo](https://bemly.github.io/luolita/) for a complete example.

## Example

Create a `.luoli` file with `coffee:`, `template:`, and `style:` section markers:

```
coffee:
  title = "My App"
  message = "Hello World!"
  count = 42
  console.log "Running #{ title }..."

template:
  doctype html
  html
    head
      title= title
      link(rel="stylesheet", href=name + ".css")
    body
      h1= message
      p Count: #{ count }
      script(src=name + ".js")

style:
  body
    font-family: sans-serif
    display: flex
    justify-content: center
    align-items: center
    min-height: 100vh
    margin: 0

  h1
    color: #333
```

Variables defined in the Coffee section (e.g. `title`, `message`, `count`) are auto-bridged to Template (Pug locals) and Style. The `name` variable is auto-injected as the output file prefix for resource linking.

**Indentation**: `.luoli` files don't require a specific indent unit — 2-space, 4-space, or tab all work. The compiler auto-detects the minimum indentation to determine nesting levels and strips common leading whitespace.

## Changelog

### [0.1.5] - 2026-04-13
- Auto indent detection: 2-space, 4-space, or tab, compiler detects minimum indentation
- `revealDocs` fix: Moved from Pug `script.` block to CoffeeScript section, executed via `<script>` tag injection

### [0.1.4] - 2026-04-12
- Browser-side Stylus compiler: pure browser implementation of Stylus-to-CSS (`luolita.stylus.coffee`)
  - Supports indentation nesting, variables, `&` parent reference, multi-selectors, CSS custom properties
  - Replaces `stylus` npm package (depends on Node.js APIs, cannot run in browser)
- Declarative auto-init: auto-discovers `<link rel="luolita" href="...">` and renders sequentially
- Bundle build script: `dist/bundle.cjs`, esbuild + Node.js module stub injection
- Updated docs/ site: simplified index.html to declarative template
- CSS properties auto-add semicolons for correct browser parsing
- Fixed error handling in `compileStylus` async compilation

### [0.0.x] - 2024-08-21
- Created project
- Removed unnecessary configuration files
- Tested preinstall script and JSON5 package.json5

### [0.1.-2] - 2024-08-22
- Completed all packaging, tested export

### [0.1.3] - 2024-08-22
- Split file into three section types

## License

WTFPL - Do What The F*ck You Want To Public License
![github license](https://img.shields.io/github/license/Bemly/luolita)

[
    ![WTFPL](http://www.wtfpl.net/wp-content/uploads/2012/12/wtfpl-badge-1.png)
](http://www.wtfpl.net/)
