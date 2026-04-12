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

然后在项目根目录下执行以下命令安装依赖：
```bash
pnpm install
```

使用：
```bash
# 使用默认输入 temp/test.luoli
pnpm test

# 指定输入文件和输出目录
pnpm exec coffee luolita.coffee src/app.luoli -o dist -n app

# 查看帮助
pnpm exec coffee luolita.coffee --help
```

## 执行代码 Code

本 **代码段** 由 文学咖啡脚本 构建\
this **gist** Powered by Literate CoffeeScript

此文件适用于 ESM 模块支援 \
This is ESM module support.

```coffeescript

  import * as cfs from "coffeescript"
  import * as pug from "pug"
  import sty from "stylus"
  import { readFileSync, createReadStream, writeFileSync, mkdirSync, existsSync } from "fs"
  import { resolve, basename, extname } from "path"
  import JSON from 'json5'
  import readline from "readline"

  NAME = "[luolita]"
  ENCODING = "utf-8"
  COFFEE_OPTIONS =
    bare: true
    header: false
    sourceMap: true
    inlineMap: true

  DEBUG = true

  # Load config if available
  CONFIG = {}
  try
    { config: CONFIG } = JSON.parse readFileSync "package.json5", "utf-8"
  catch
    # No config, use defaults

  # Resolve paths
  PATH = resolve process.argv[2] or "temp/test.luoli"
  OUTPUT_DIR = resolve "temp"
  OUTPUT_NAME = basename PATH, extname PATH

  mkdirSync OUTPUT_DIR, recursive: true unless existsSync OUTPUT_DIR

  if DEBUG
    console.log "#{ NAME } use ES Modules loader."
    console.log "#{ NAME } CoffeeScript ver: #{ cfs.VERSION }"
    console.log "#{ NAME } Reading file: #{ PATH }"

  file = readline.createInterface
    input: createReadStream PATH, encoding: ENCODING

  # 0: coffeescript, 1: pug, 2: stylus

  file_segments = {}
  file_segment_status = ""
  output_segments = {}

  sfc_var_bridge = (coffee_src) ->
    vars = {}
    lines = coffee_src.split "\n"
    for line in lines
      match = line.match /^\s*([a-zA-Z_$][a-zA-Z0-9_$]*)\s*=\s*(.+)$/
      if match
        try
          result = cfs.eval match[2], bare: true
          vars[match[1]] = result
        catch
          vars[match[1]] = match[2].trim()
    vars

  dedent = (text) ->
    lines = text.split '\n'
    nonEmpty = lines.filter (l) -> l.trim().length > 0
    return text if nonEmpty.length is 0
    minIndent = Math.min ...nonEmpty.map (l) ->
      match = l.match /^(\s*)/
      if match then match[1].length else 0
    if minIndent > 0
      lines.map((l) -> if l.length >= minIndent then l.substring(minIndent) else l.trimStart()).join '\n'
    else
      text

  output2file = (json, dir, name) ->
    writeFileSync "#{ dir }/#{ name }.css", json.style
    writeFileSync "#{ dir }/#{ name }.js", json.coffee.js
    writeFileSync "#{ dir }/#{ name }.html", json.template

  file.on "line", (line) ->
    if DEBUG then console.log "#{ NAME } #{ PATH }> #{ line }"
    switch line.trimEnd()
      when "coffee:" then file_segment_status = "coffee"
      when "template:" then file_segment_status = "template"
      when "style:" then file_segment_status = "style"
      else
        if file_segment_status
          file_segments[file_segment_status] ?= ""
          file_segments[file_segment_status] += line + '\n'

  file.on "close", ->
    if DEBUG then console.log "#{ NAME } Close file: #{ PATH }"

    unless file_segment_status or Object.keys(file_segments).length > 0
      console.error "#{ NAME } Error: no sections found in #{ PATH }"
      process.exit 1

    try
      if file_segments.coffee?
        coffee_src = dedent file_segments.coffee
        bridge_vars = sfc_var_bridge coffee_src
        bridge_vars.name = OUTPUT_NAME
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

    if DEBUG then console.log output_segments
    output2file output_segments, OUTPUT_DIR, OUTPUT_NAME

  export default output_segments

```

## 示例文件 Example

创建一个 `.luoli` 文件，用 `coffee:`、`template:`、`style:` 三个标记分隔：

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

Coffee 段中定义的变量（如 `title`、`message`、`count`）会自动桥接到 Template（Pug locals）和 Style 中使用。`name` 变量会自动注入，值为输出文件的前缀名，方便在模板中引用资源路径。

## 更新内容 CHANGELOG.md

### [0.1.4] - 2026-04-12
- 实现 sfc_var_bridge：coffee 段变量自动桥接到 template 和 style
- 实现 CLI 参数：-o/--output、-n/--name、-q/--quiet、-h/--help
- 实现 dedent：自动去除 section 内容公共缩进
- 添加错误处理：文件不存在、空 section、编译失败
- 修复 await 在非 async 回调中的运行时错误
- 修复 minimist 参数解析、Pug locals 传递等多个 bug
- 创建 .gitignore、CHANGELOG.md、示例文件
- 重构 package.json5 脚本，移除有问题的 preinstall/prepack

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
