# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Luolita (萝莉塔)** is a Vue-like Single-File Component (SFC) generator. It parses `.luoli` files containing three section types (delimited by `coffee:`, `template:`, `style:` markers) and compiles them into standard JS, HTML, and CSS using CoffeeScript, Pug, and Stylus respectively.

Version: 0.1.3 | License: WTFPL

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
- `README.md` — Also serves as ESM source via Literate CoffeeScript (compiled to `luolita.mjs`)
- `package.json5` — Package manifest in JSON5 format (allows comments)
- `temp/test.luoli` — Example input SFC file
- `temp/test.{js,html,css}` — Compiled output files

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
     - Stylus → CSS (via `stylus` package)
5. Writes output to `<outputDir>/<name>.{js,html,css}`

### SFC Variable Bridge

The `sfc_var_bridge` function extracts simple variable assignments from the coffee section (e.g., `title = "Hello"`) and makes them available as:
- **Pug locals**: Accessible as `= title` in template interpolation
- **Output name**: Automatically injected as `name` variable (the output file prefix) for resource linking

### Key Design Notes

- **CJS/ESM hybrid**: CoffeeScript doesn't fully support ESM, so the project uses CJS (`luolita.coffee`) as the primary entry and Literate CoffeeScript in README.md for ESM (`luolita.mjs`).
- **Indentation handling**: A `dedent` function strips common leading whitespace from section content, allowing indented `.luoli` files.
- **Missing sections are skipped**: If a `.luoli` file omits a section, that output is an empty string.
- **JSON5**: Used for `package.json5` to allow comments in config.
