# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Luolita (萝莉塔)** is a Vue-like Single-File Component (SFC) generator. It parses `.luoli` files containing three section types (delimited by `coffee:`, `template:` and `style:` markers) and compiles them into standard JS, HTML, and CSS using CoffeeScript, Pug, and a lightweight in-browser Stylus compiler respectively.

Version: 0.1.5 | License: WTFPL

## Commands

| Command | Description |
|---|---|
| `pnpm install` | Install dependencies (runs `prepare` hook that builds `luolita.mjs` from README.md) |
| `pnpm test` | Run `pnpm exec coffee luolita.coffee` — parses `temp/test.luoli` and outputs to `temp/` |
| `pnpm build` | Compile README.md (literate CoffeeScript) into `luolita.mjs` |
| `pnpm readme` | Build luolita.mjs then run it with `node luolita.mjs` |
| `pnpm clean` | Remove generated files (`luolita.mjs`, `temp/` outputs) |
| `pnpm exec coffee luolita.coffee --help` | Show CLI help |

Package manager: **pnpm >= 9** (preferred for JSON5 support). Node.js >= 20 LTS required.

## CLI Usage

```bash
pnpm exec coffee luolita.coffee <input.luoli> [options]

Options:
  -o, --output <dir>   Output directory (default: temp/)
  -n, --name <name>    Output file prefix (default: base name of input)
  -q, --quiet          Suppress debug output
  -h, --help           Show help
```

## Architecture

### File Structure

- `luolita.coffee` — CommonJS entry point / executable (main CLI)
- `luolita.browser.coffee` — Browser SFC compiler entry (bundled with esbuild)
- `luolita.stylus.coffee` — Lightweight in-browser Stylus-to-CSS compiler
- `dist/bundle.cjs` — Browser bundle build script (esbuild + Node.js shim injection)
- `dist/luolita.stylus.js` — Compiled Stylus compiler (used by browser bundle)
- `README.md` — English documentation (ESM source via Literate CoffeeScript, compiled to `luolita.mjs`)
- `README.zh.md` — Chinese documentation
- `package.json5` — Package manifest in JSON5 format (allows comments)
- `docs/` — Static site (GitHub Pages), example `.luoli` files (zh + en) and browser bundle
- `docs/en/` — English version of the homepage

### How It Works

1. Reads input `.luoli` file line-by-line via Node.js `readline`
2. Detects section markers: `coffee:`, `template:`, `style:`
3. Accumulates lines under the current section into `file_segments`
4. On file close:
   - Runs `dedent()` to strip common leading indentation from each section
   - Runs `sfc_var_bridge()` to extract variable assignments from the coffee section
   - Compiles each section (only if present):
     - CoffeeScript → JS (with source maps via `coffeescript` package)
     - Pug → HTML (with bridged variables as locals via `pug` package)
     - Stylus → CSS (via `stylus` package on Node.js, or `luolita.stylus.coffee` in browser)
5. Writes output to `<outputDir>/<name>.{js,html,css}`

### SFC Variable Bridge

The `sfc_var_bridge` function extracts simple variable assignments from the coffee section (e.g., `title = "Hello"`) and makes them available as:
- **Pug locals**: Accessible as `= title` in template interpolation
- **Output name**: Automatically injected as `name` variable (the output file prefix) for resource linking

### Key Design Notes

- **CJS/ESM hybrid**: CoffeeScript doesn't fully support ESM, so the project uses CJS (`luolita.coffee`) as the primary entry and Literate CoffeeScript in README.md for ESM (`luolita.mjs`).
- **In-browser Stylus**: `luolita.stylus.coffee` is a lightweight pure-browser Stylus-to-CSS compiler (no Node.js deps). Supports indentation-based nesting, variables, `&` parent reference, multi-selectors, and CSS custom properties.
- **Browser bundle**: `dist/bundle.cjs` builds an IIFE bundle with Node.js module stubs (`fs`, `path`, `vm`, etc.) injected at build time.
- **Auto-init**: Browser bundle auto-discovers `<link rel="luolita" href="...">` tags and renders them sequentially into the document body.
- **Indentation handling**: A `dedent` function automatically detects the minimum non-zero indentation (2-space, 4-space, tab, etc.) and strips it from all lines. Stylus compiler uses the same auto-detected unit to calculate nesting levels.
- **Missing sections are skipped**: If a `.luoli` file omits a section, that output is an empty string.
- **JSON5**: Used for `package.json5` to allow comments in config.
