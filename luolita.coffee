#!/usr/bin/env coffee

###
目前coffeescript解释器还不支持ESM模式，本仓库采用CJS+ESM混合开发，战未来！((((
但是捏，cfs又支持ES2015的import modules语法，真是搞不懂捏

Currently, the coffeescript interpreter does not support ESM mode.
This repository adopts CJS+ESM hybrid development to fight for the future!
BUT, coffeescript support ES2015 modules' syntactic sugar : /
###

require 'coffeescript/register'

# This is Node.js CommonJS support.
console.log "[luolita] use CommonJS loader."


console.log "[luolita] start converting..."

args = require("minimist") process.argv.slice 2
a = => 3
b = -> 4

console.log(a(), b(), __dirname, args)