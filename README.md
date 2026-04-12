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

## 浏览器使用 Browser

在网页中直接加载 `.luoli` 文件并编译，零外部依赖，单个 `<script>` 标签即可使用：

```html
<!-- 引入打包好的 bundle，已内置 CoffeeScript / Pug / Stylus 运行时 -->
<script src="luolita.browser.bundle.js"></script>

<script>
  fetch('example.luoli')
    .then(function (res) { return res.text() })
    .then(function (text) {
      Luolita.renderToDOM(text, '#app', { outputName: 'example' })
    })
</script>
```

`Luolita` API：

| 方法 | 说明 | 返回 |
|---|---|---|
| `Luolita.compile(text, opts)` | 编译 `.luoli` 文本 | `Promise<{ coffee: {js, map}, template, style }>` |
| `Luolita.renderToDOM(text, target, opts)` | 编译并渲染到 DOM 元素 | 无 |

- `opts.outputName` — 输出文件名前缀（模板中可用 `name` 变量引用资源路径）
- `opts.debug` — 是否打印调试日志（默认 `true`）

打开 [在线演示](https://bemly.github.io/luolita/) 即可在浏览器中查看完整效果。

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
- 浏览器 bundle：零依赖单文件，内置 CoffeeScript / Pug / Stylus 运行时
- 实现 sfc_var_bridge：coffee 段变量自动桥接到 template 和 style
- 实现 CLI 参数：-o/--output、-n/--name、-q/--quiet、-h/--help
- 实现 dedent：自动去除 section 内容公共缩进
- 添加错误处理：文件不存在、空 section、编译失败
- 修复 await 在非 async 回调中的运行时错误
- 修复 minimist 参数解析、Pug locals 传递等多个 bug
- 创建 .gitignore、CHANGELOG.md、示例文件
- 重构 package.json5 脚本，移除有问题的 preinstall/prepack
- docs/ 类 Wiki 站点：VitePress 风格，展示 Node.js 和浏览器两种使用方式

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
