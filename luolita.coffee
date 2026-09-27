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
# available as locals for pug template and as $-prefixed variables in stylus.
# Values may span lines (arrays/objects/implicit objects), use single quotes
# or bare keys — anything CoffeeScript accepts. Evaluation runs in a sandbox
# (stub window/document/console); groups that throw fall back to direct
# cfs.eval of the value text, then to the raw string, so one bad apple never
# spoils the rest.
bridge_stub_names = ['window', 'document', 'console', 'localStorage', 'navigator', 'fetch']
bridge_stub_values = ->
  silent = log: (->), error: (->), warn: (->), info: (->), debug: (->)
  [{}, {}, silent, {}, {}, (-> Promise.reject new Error 'fetch not available in bridge')]

bridge_indent_width = (line) ->
  m = line.match /^(\s*)/
  if m then m[1].length else 0

bridge_cont_re = /[=,:\[({+\-*\/\%&|?]\s*$|->\s*$|=>\s*$/

bridge_bracket_depth = (text) ->
  depth = 0
  in_str = null
  i = 0
  while i < text.length
    ch = text[i]
    if in_str
      if ch is '\\'
        i += 2
        continue
      if ch is in_str
        in_str = null
    else if ch is '"' or ch is "'" or ch is '`'
      in_str = ch
    else if ch is '#' and text[i+1] isnt '{'
      while i < text.length and text[i] isnt '\n'
        i += 1
      continue
    else if ch is '[' or ch is '{' or ch is '('
      depth += 1
    else if ch is ']' or ch is '}' or ch is ')'
      depth -= 1
    i += 1
  depth

# Pull out triple-quoted assignments first with legacy raw semantics
# (no #{} interpolation); blank the region so grouping skips it.
bridge_extract_triples = (lines) ->
  triples = {}
  code = []
  i = 0
  while i < lines.length
    line = lines[i]
    qi = line.indexOf "'''"
    qd = line.indexOf '"""'
    q = null
    if qi isnt -1 and (qd is -1 or qi < qd)
      q = "'''"
    else if qd isnt -1
      q = '"""'
    unless q
      code.push line
      i += 1
      continue
    am = line.match ///^([a-zA-Z_$][a-zA-Z0-9_$]*)\s*=\s*#{q}(.*)$///
    occ = line.split(q).length - 1
    if occ >= 2
      if am
        triples[am[1]] = line.split(q)[1]
      i += 1
      continue
    if am
      acc = []
      if am[2].trim()
        acc.push am[2]
      i += 1
      while i < lines.length and lines[i].indexOf(q) is -1
        acc.push lines[i]
        i += 1
      if i < lines.length
        before = lines[i].split(q)[0]
        if before.trim()
          acc.push before
        i += 1
      triples[am[1]] = dedent acc.join '\n'
    else
      i += 1
      while i < lines.length and lines[i].indexOf(q) is -1
        i += 1
      if i < lines.length
        i += 1
    continue
  {triples, code}

# Collect top-level `name = value` groups, joining continuation lines.
# A group starting with an empty value (`cfg =` alone) consumes the whole
# following indented block (implicit object / indented expression).
bridge_collect_groups = (lines) ->
  groups = []
  i = 0
  while i < lines.length
    line = lines[i]
    m = line.match /^([a-zA-Z_$][a-zA-Z0-9_$]*)\s*=\s*(?![=>])(.*)$/
    unless m
      i += 1
      continue
    buf = [line]
    vals = [m[2]]
    j = i + 1
    block_form = m[2].trim() is ''
    loop
      depth = bridge_bracket_depth buf.join '\n'
      if depth > 0
        break if j >= lines.length
        buf.push lines[j]
        vals.push lines[j]
        j += 1
        continue
      if block_form
        break if j >= lines.length or bridge_indent_width(lines[j]) is 0
        buf.push lines[j]
        vals.push lines[j]
        j += 1
        continue
      last = buf[buf.length - 1].replace /\s+$/, ''
      if bridge_cont_re.test(last) and j < lines.length and bridge_indent_width(lines[j]) > 0
        buf.push lines[j]
        vals.push lines[j]
        j += 1
        continue
      break
    groups.push name: m[1], code: buf.join('\n'), value: vals.join('\n')
    i = j
  groups

bridge_eval_groups = (groups) ->
  ok = {}
  scope = ''
  for g in groups
    trial = if scope then scope + '\n' + g.code else g.code
    try
      js = cfs.compile trial, bare: true, header: false
      fn = new Function bridge_stub_names.join(','), js + '\nreturn ' + g.name + ';'
      ok[g.name] = fn.apply null, bridge_stub_values()
      scope = trial
    catch
      continue
  ok

sfc_var_bridge = (coffee_src) ->
  {triples, code} = bridge_extract_triples coffee_src.split '\n'
  vars = triples
  groups = bridge_collect_groups code
  ok = bridge_eval_groups groups
  for g in groups
    if g.name of ok
      vars[g.name] = ok[g.name]
    else if g.value.trim() is ''
      continue
    else
      try
        vars[g.name] = cfs.eval g.value, bare: true
      catch
        vars[g.name] = g.value.trim()
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
