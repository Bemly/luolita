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

  console.log "[luolita] use ES Modules loader."
  console.log "[luolita] #{ cfs.VERSION }"

  export default "????"

```

## 更新内容 CHANGELOG.md

### [0.0.x] - 2024-08-21
- 新建文件夹 Create project
- 删除不需要的配置文件 Delete unnecessary files
- 测试预安装脚本和json5配置文件是否能正常工作和推送 Test preinstall script and package.json5 work

### [0.1.-2] - 2024-08-22
- 完成所有打包工作，测试导出是否正常 Completed all packaging, test export work

## 许可证 License

WTFPL - Do What The F*ck You Want To Public License

[
    ![WTFPL](http://www.wtfpl.net/wp-content/uploads/2012/12/wtfpl-badge-1.png)
](http://www.wtfpl.net/)

