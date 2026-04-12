#!/usr/bin/env coffee

###
目前coffeescript解释器还不支持ESM模式，本仓库采用CJS+ESM混合开发，战未来！((((
但是捏，cfs又支持ES2015的import modules语法，真是搞不懂捏

Currently, the coffeescript interpreter does not support ESM mode.
This repository adopts CJS+ESM hybrid development to fight for the future!
BUT, coffeescript support ES2015 modules' syntactic sugar : /
###

# This is Node.js CommonJS support.

cfs = require "coffeescript"
pug = require "pug"
sty = require "stylus"
minimist = require "minimist"
{ readFileSync, createReadStream, writeFileSync, mkdirSync, existsSync } = require "fs"
{ resolve, dirname, basename, extname } = require "path"
JSON5 = require "json5"
readline = require "readline"

# --- CLI argument parsing ---

NAME = "[luolita]"
ENCODING = "utf-8"
COFFEE_OPTIONS =
  bare: true
  header: false
  sourceMap: true
  inlineMap: true

args = minimist(process.argv.slice(2), {
  string: ["output", "name"],
  boolean: ["quiet", "help"],
  alias: {
    o: "output",
    n: "name",
    q: "quiet",
    h: "help",
  },
})

if args.help
  console.log """
    Usage: luolita <input.luoli> [options]

    Options:
      -o, --output <dir>   Output directory (default: temp/)
      -n, --name <name>    Output file prefix (default: base name of input)
      -q, --quiet          Suppress debug output
      -h, --help           Show this help message
  """
  process.exit 0

# Resolve input path
inputPath = if args._[0]? then args._[0] else "temp/test.luoli"
inputPath = resolve inputPath
inputName = basename inputPath, extname inputPath

# Resolve output
outputDir = resolve args.output or "temp"
outputName = args.name or inputName

# Debug mode
DEBUG = not args.quiet

# Load config if available
CONFIG = {}
try
  pkgPath = resolve "package.json5"
  { config: CONFIG } = JSON5.parse readFileSync pkgPath, ENCODING
  if DEBUG then console.log "#{ NAME } Loaded config from package.json5"
catch err
  if DEBUG then console.log "#{ NAME } No package.json5 found, using defaults"

# Ensure output directory exists
unless existsSync outputDir
  mkdirSync outputDir, recursive: true

# Check input file exists
unless existsSync inputPath
  console.error "#{ NAME } Error: input file not found: #{ inputPath }"
  process.exit 1

console.log "[luolita] use CommonJS loader."
console.log "[luolita] start converting..."
console.log "#{ NAME } CoffeeScript ver: #{ cfs.VERSION }"
if DEBUG then console.log "#{ NAME } Reading file: #{ inputPath }"
if DEBUG then console.log "#{ NAME } Output directory: #{ outputDir }"

# 0: coffeescript, 1: pug, 2: stylus

file_segments = {}
file_segment_status = ""
output_segments = {}

# Strip common leading indentation from a block of text
dedent = (text) ->
  lines = text.split '\n'
  # Skip empty leading lines when computing indent
  nonEmpty = lines.filter (l) -> l.trim().length > 0
  return text if nonEmpty.length is 0
  minIndent = Math.min ...nonEmpty.map (l) ->
    match = l.match /^(\s*)/
    if match then match[1].length else 0
  if minIndent > 0
    lines.map((l) -> if l.length >= minIndent then l.substring(minIndent) else l.trimStart()).join '\n'
  else
    text

# Bridge variables between SFC sections
# Extracts variables defined in the coffee section and makes them
# available as locals for pug template and as $-prefixed variables in stylus
sfc_var_bridge = (coffee_src) ->
  vars = {}
  lines = coffee_src.split '\n'
  for line in lines
    # Match simple top-level variable assignments (allowing leading whitespace)
    match = line.match /^\s*([a-zA-Z_$][a-zA-Z0-9_$]*)\s*=\s*(.+)$/
    if match
      try
        # Evaluate the value as CoffeeScript to get the actual value
        result = cfs.eval match[2], bare: true
        vars[match[1]] = result
      catch
        # Skip expressions that can't be evaluated statically
        vars[match[1]] = match[2].trim()
  vars

output2file = (json, dir, name) ->
  writeFileSync "#{ dir }/#{ name }.css", json.style
  writeFileSync "#{ dir }/#{ name }.js", json.coffee.js
  writeFileSync "#{ dir }/#{ name }.html", json.template

file = readline.createInterface
  input: createReadStream inputPath, encoding: ENCODING

file.on "line", (line) ->
  if DEBUG then console.log "#{ NAME } #{ inputPath }> #{ line }"
  switch line.trimEnd()
    when "coffee:" then file_segment_status = "coffee"
    when "template:" then file_segment_status = "template"
    when "style:" then file_segment_status = "style"
    else
      if file_segment_status
        file_segments[file_segment_status] ?= ""
        file_segments[file_segment_status] += line + '\n'

file.on "close", ->
  if DEBUG then console.log "#{ NAME } Close file: #{ inputPath }"

  # Check we have at least one section
  unless file_segment_status or Object.keys(file_segments).length > 0
    console.error "#{ NAME } Error: no sections found in #{ inputPath }"
    console.error "  Expected markers: coffee:, template:, style:"
    process.exit 1

  # Compile each section, only if present
  try
    if file_segments.coffee?
      coffee_src = dedent file_segments.coffee
      bridge_vars = sfc_var_bridge coffee_src
      bridge_vars.name = outputName  # inject output name for template resource links
      if DEBUG then console.log "#{ NAME } Bridged variables:", Object.keys(bridge_vars)
      output_segments.coffee = cfs.compile coffee_src, COFFEE_OPTIONS
    else
      bridge_vars = {}
      output_segments.coffee = js: ""

    if file_segments.template?
      output_segments.template = pug.render dedent(file_segments.template), bridge_vars
    else
      output_segments.template = ""

    if file_segments.style?
      output_segments.style = sty(dedent(file_segments.style), { define: { "bridge_vars": bridge_vars } }).render()
    else
      output_segments.style = ""
  catch err
    console.error "#{ NAME } Compilation error: #{ err.message }"
    process.exit 1

  if DEBUG then console.log "#{ NAME } Output:", Object.keys(output_segments)
  output2file output_segments, outputDir, outputName
  console.log "[luolita] conversion complete."
