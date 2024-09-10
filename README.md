# 萝莉塔 - Luolita

一个类似 Vue 的单文件组件生成器\
将 ".luoli" 文件解析为 3 种语法糖：coffeescript、pug、stylus

A like-vue Single-File Components generator that parses HTML+CSS+JS\
'.luoli' into 3-Syntactic sugar: coffeescript, pug, and stylus.

## 快速开始 Quick Start

你需要先安装最基本的开发工具和依赖才能使用此工具链
1. Node.js >= 20 LTS
2. npm >= 10
3. pnpm >= 9 (Optional, Recommended, .json5 support)

然后在项目根目录下执行以下命令推拉取依赖\
TODO: 之后写

## 执行代码 Code

本 **代码段** 由 文学咖啡脚本 构建\
this **gist** Powered by Literate CoffeeScript

此文件适用于 ESM 模块支援 \
This is ESM module support.

```coffeescript

  import * as cfs from "coffeescript"
  import * as pug from "pug"
  import sty from "stylus"
  

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

  import { readFileSync, createReadStream, writeFileSync } from "fs"
  import JSON from 'json5'
  import readline from "readline"
  
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
    export default output_segments

```

## 更新内容 CHANGELOG.md

### [0.0.x] - 2024-08-21
- 新建文件夹 Create project
- 删除不需要的配置文件 Delete unnecessary files
- 测试预安装脚本和json5配置文件是否能正常工作和推送 Test preinstall script and package.json5 work

### [0.1.-2] - 2024-08-22
- 完成所有打包工作，测试导出是否正常 Completed all packaging, test export work

### [0.1.3] - 2024-08-22
- 简单分割文件为三段类型分开解释 Simple split files into three types to explain

## 许可证 License

WTFPL - Do What The F*ck You Want To Public License
![github license](https://img.shields.io/github/license/Bemly/luolita)

[
    ![WTFPL](http://www.wtfpl.net/wp-content/uploads/2012/12/wtfpl-badge-1.png)
](http://www.wtfpl.net/)

