# Agent Skills 目录

这是一个长期维护的 Codex / Claude Code Skills 目录仓库。遵循官方 Agent Skills 规范：每个 skill 位于 `skills/` 下的独立文件夹，且包含必需的 `SKILL.md`（YAML frontmatter + Markdown 指令）。可选资源放在 skill 文件夹内的 `scripts/`、`references/`、`assets/`。

## 快速开始

- 添加本仓库为 Claude Code marketplace：`/plugin marketplace add <repo-path-or-url>`
- 安装插件：`/plugin install grafana-skills@haoming-skills`
- 插件会暴露 `skills/` 供 Claude/Codex 自动发现并触发

## 仓库结构

- `skills/` - 技能目录（每个 skill 文件夹包含 `SKILL.md`）
- `.claude-plugin/` - marketplace 配置（`marketplace.json`）
- `docs/` - 规范与维护说明
- `templates/` - skill 模板（不会被自动发现）

## 已包含技能

- `grafana-json-to-jsonnet` - 将 Grafana 导出的 JSON 转换为符合 `grafana-code` 风格的 Jsonnet
- `grafana-jsonnet-refactor` - 将单一 Jsonnet Dashboard 拆分为 entrypoint + lib 结构
- `grafana-report-to-dashboard` - 将 Python 报表脚本迁移为 Grafana Jsonnet，并支持 ClickHouse + Elasticsearch (ES7/ES8)

## 文档

- `docs/skills-spec.md`
- `docs/catalog-structure.md`
- `docs/skill-template.md`