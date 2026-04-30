# Agent Skills 目录

Grafana Jsonnet 工作流的 Claude Code 技能集合。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude-Code-blue.svg)](https://claude.ai/code)

## 安装

### 方式一：npx skills（推荐）

使用 [skills CLI](https://github.com/vercel-labs/skills) 安装：

```bash
# 列出可用技能
npx skills add haomingz/skills --list

# 安装全部技能到 Claude Code
npx skills add haomingz/skills -a claude-code

# 安装特定技能
npx skills add haomingz/skills --skill grafana-json-to-jsonnet -a claude-code

# 全局安装（跨项目生效）
npx skills add haomingz/skills -a claude-code -g -y
```

### 方式二：Claude Code 插件市场

```bash
/plugin marketplace add https://github.com/haomingz/skills
/plugin install grafana-skills@haoming-skills
```

## 技能列表

| 技能 | 用途 | 触发短语 |
|------|------|----------|
| [grafana-json-to-jsonnet](skills/grafana-json-to-jsonnet/SKILL.md) | Grafana UI 导出 JSON 转 Jsonnet | "convert grafana json", "import grafana dashboard" |
| [grafana-jsonnet-refactor](skills/grafana-jsonnet-refactor/SKILL.md) | 重构 Jsonnet，消除重复、对齐规范 | "refactor grafana jsonnet", "split dashboard" |
| [grafana-report-to-dashboard](skills/grafana-report-to-dashboard/SKILL.md) | Python 报表脚本迁移为 Grafana 仪表板 | "migrate report to grafana", "convert python report" |
| [grafana-dashboard-optimize](skills/grafana-dashboard-optimize/SKILL.md) | 仪表板可观测性审计与优化（RED/USE） | "optimize grafana dashboard", "dashboard audit" |

## 目录结构

```
skills/{name}/
├── SKILL.md          # 技能定义（YAML frontmatter + 工作流）
├── scripts/          # 可选：辅助脚本
└── references/       # 参考文档（按需加载）
```

技能采用**渐进式披露**加载：frontmatter 常驻上下文，SKILL.md 触发时加载，`references/` 按需加载。

## 创建新技能

```bash
cp -r templates/skill-template skills/my-new-skill
# 编辑 SKILL.md，更新 name、description 和工作流
/plugin reload
```

详见 [docs/skill-template.md](docs/skill-template.md) 和 [docs/skills-spec.md](docs/skills-spec.md)。

## 许可证

MIT — 详见 [LICENSE](LICENSE)
