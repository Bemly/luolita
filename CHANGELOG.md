# Changelog

### [0.1.5] - 2026-09-27
- Bridge fix (browser + CLI): top-level coffee values may now span lines
  (arrays/objects/implicit objects), use single quotes or bare keys — anything
  the real CoffeeScript compiler accepts. Evaluation runs sandboxed; failures
  fall back per-group to legacy handling. Triple-quoted blocks keep raw
  (non-interpolated) semantics. Bare identifiers keep old meaning via a
  plain-data gate (e.g. `title = Luolita` stays the string "Luolita").

### [0.1.3] - 2024-08-22
- 简单分割文件为三段类型分开解释 Simple split files into three types to explain

### [0.1.2] - 2024-08-22
- 完成所有打包工作，测试导出是否正常 Completed all packaging, test export work

### [0.0.x] - 2024-08-21
- 新建文件夹 Create project
- 删除不需要的配置文件 Delete unnecessary files
- 测试预安装脚本和json5配置文件是否能正常工作和推送 Test preinstall script and package.json5 work
