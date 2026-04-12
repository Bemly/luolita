# 萝莉塔 - Luolita

一个类似 Vue 的单文件组件生成器\
将 ".luoli" 文件解析为 3 种语法糖：coffeescript、pug、stylus

## 快速开始

你需要先安装最基本的开发工具和依赖才能使用此工具链
1. Node.js
2. npm
3. pnpm >= 9 (可选，推荐，支持 JSON5)

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

## 浏览器使用

在网页中直接加载 `.luoli` 文件并编译，零外部依赖，单个 `<link>` 标签即可使用：

**自动渲染（推荐）**：使用 `<link rel="luolita">` 声明式加载，页面打开即渲染：

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

支持多个 `<link>` 标签，会按顺序依次渲染到页面中。

**手动渲染**：通过 JS API 控制渲染时机和目标元素：

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

## 浏览器构建

`luolita.browser.bundle.js` 在 docs/ 中，如需自行构建：

```bash
# 1. 编译 CoffeeScript 为 JS
pnpm exec coffee -c -p luolita.browser.coffee > dist/luolita.browser.js

# 2. esbuild 打包 + 注入 Node.js 模块 stub
node docs/bundle.cjs

# 输出到 dist/luolita.browser.bundle.js，同时复制到 docs/
```

`Luolita` API：

| 方法 | 说明 | 返回 |
|---|---|---|
| `Luolita.compile(text, opts)` | 编译 `.luoli` 文本 | `Promise<{ coffee: {js, map}, template, style }>` |
| `Luolita.renderToDOM(text, target, opts)` | 编译并渲染到 DOM 元素 | 无 |

- `opts.outputName` — 输出文件名前缀（模板中可用 `name` 变量引用资源路径）
- `opts.debug` — 是否打印调试日志（默认 `true`）

打开 [在线演示](https://bemly.github.io/luolita/) 即可在浏览器中查看完整效果。

## 示例文件

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

**缩进**：`.luoli` 文件不限制具体缩进单位——2 空格、4 空格、Tab 均可，编译器会自动检测最小缩进单位并据此解析嵌套层级，公共前导缩进会被自动去除。

## 更新内容

### [0.1.5] - 2026-04-13
- 缩进自动检测：支持 2 空格、4 空格、Tab，编译器自动检测最小缩进单位
- `revealDocs` 修复：从 Pug `script.` 块移至 CoffeeScript 段，通过 `<script>` 标签注入执行

### [0.1.4] - 2026-04-12
- 浏览器端 Stylus 编译器：纯浏览器实现的轻量级 Stylus-to-CSS 编译器（`luolita.stylus.coffee`）
  - 支持缩进嵌套、变量、`&` 父选择器、多选择器、CSS 自定义属性
  - 替代原 `stylus` npm 包（依赖 Node.js API，无法在浏览器运行）
- 声明式 auto-init：自动发现 `<link rel="luolita" href="...">` 并按顺序渲染
- Bundle 构建脚本：`dist/bundle.cjs`，esbuild 打包 + Node.js 内置模块 stub 注入
- 更新 docs/ 站点：简化 index.html 为纯声明式模板
- CSS 属性自动添加分号，确保浏览器正确解析
- 修复 `compileStylus` 异步编译中的错误处理

### [0.0.x] - 2024-08-21
- 新建文件夹 Create project
- 删除不需要的配置文件 Delete unnecessary files
- 测试预安装脚本和json5配置文件是否能正常工作和推送

### [0.1.-2] - 2024-08-22
- 完成所有打包工作，测试导出是否正常 Completed all packaging, test export work

### [0.1.3] - 2024-08-22
- 简单分割文件为三段类型分开解释 Simple split files into three types to explain

## 许可证

WTFPL - Do What The F*ck You Want To Public License
![github license](https://img.shields.io/github/license/Bemly/luolita)

[
    ![WTFPL](http://www.wtfpl.net/wp-content/uploads/2012/12/wtfpl-badge-1.png)
](http://www.wtfpl.net/)
