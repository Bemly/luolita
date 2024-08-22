#!/usr/bin/env coffee

###
目前coffeescript解释器还不支持ESM模式，本仓库采用CJS+ESM混合开发，战未来！((((
但是捏，cfs又支持ES2015的import modules语法，真是搞不懂捏

Currently, the coffeescript interpreter does not support ESM mode.
This repository adopts CJS+ESM hybrid development to fight for the future!
BUT, coffeescript support ES2015 modules' syntactic sugar : /
###

# This is Node.js CommonJS support.
console.log "[luolita] use CommonJS loader."
console.log "[luolita] start converting..."

args = require("minimist") process.argv.slice 2

cfs = require "coffeescript"
pug = require "pug"
sty = require "stylus"

PATH = "temp/test.luoli"
NAME = "[luolita]"
ENCODING = "utf-8"
COFFEE_OPTIONS =
  bare: true,
  header: false,
  sourceMap: true,
  inlineMap: true,

console.log "#{ NAME } use ES Modules loader."
console.log "#{ NAME } CoffeeScript ver: #{ cfs.VERSION }"

{ readFileSync, createReadStream, writeFileSync } = require "fs"

JSON = require 'json5'
readline = require "readline"

DEBUG = true

{ config: CONFIG } = JSON.parse readFileSync "package.json5", "utf-8"

file = readline.createInterface
  input: createReadStream PATH, encoding: ENCODING
if DEBUG then console.log "#{ NAME } Reading file: #{ PATH }"

# 0: coffeescript, 1: pug, 2: stylus

file_segments = {}
file_segment_status = ""
output_segments = {}
sfc_var_bridge = ->
output2file = (json) ->
  writeFileSync "temp/test.css", json.style
  writeFileSync "temp/test.js", json.coffee.js
  writeFileSync "temp/test.html", json.template

file.on "line", (line) ->
  if DEBUG then console.log "#{ NAME } #{ PATH }> #{ line }"
  switch line.trimEnd()
    when "coffee:" then file_segment_status = "coffee"
    when "template:" then file_segment_status = "template"
    when "style:" then file_segment_status = "style"
    else
      file_segments[file_segment_status] ?= ""
      file_segments[file_segment_status] += line + '\n'

file.on "close", ->
  if DEBUG then console.log "#{ NAME } Close file: #{ PATH }"
  sfc_var_bridge()
  output_segments.coffee = cfs.compile file_segments.coffee, COFFEE_OPTIONS
  output_segments.template = pug.render file_segments.template
  output_segments.style = await sty file_segments.style
    .render()
  if DEBUG then console.log output_segments
  output2file output_segments

console.log(__dirname, args)