# Agent Skills 规范摘要

本目录遵循 Claude Code / Codex 的官方 Agent Skills 规范。

## 必需结构

- 一个 skill 是一个文件夹，必须包含 `SKILL.md`
- `SKILL.md` 必须以 YAML frontmatter 开头，随后是 Markdown 指令
- frontmatter 必需字段：
  - `name`（hyphen-case，且与文件夹名一致）
  - `description`（清晰描述技能作用与触发场景）
- 可选字段在部分运行时可能支持（如 `license`、`allowed-tools`、`metadata`），但除非明确需要，否则保持最小化

## 发现与加载机制

- Claude/Codex 只读取 frontmatter 来判断是否触发技能
- 触发后才加载 `SKILL.md` 的正文指令
- 资源按需加载：
  - `scripts/`（可执行脚本）
  - `references/`（参考文档）
  - `assets/`（输出模板/素材）

这是渐进式加载模型：metadata → instructions → resources。

## 打包与 Marketplace

- skill 可打包为 `.skill`（zip 结构，skill 文件夹必须在根路径）
- Marketplace 仓库通常以 `skills/` 作为技能根目录
- 若要通过 `/plugin marketplace add` 分发，请在仓库根目录提供 `.claude-plugin/marketplace.json`