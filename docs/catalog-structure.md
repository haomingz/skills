# 目录结构

本仓库面向长期维护与 Claude Code marketplace 兼容性。

```
.
├── README.md
├── .claude-plugin/
├── docs/
├── skills/
└── templates/
```

## 约定

- 所有真实技能都在 `skills/` 下，且自动发现
- skill 文件夹名必须与 `SKILL.md` 的 `name` 一致
- skill 文件夹内不要放额外文档（仅允许 `SKILL.md` 和可选的 `scripts/`、`references/`、`assets/`）
- `templates/` 用于存放模板，不会被自动发现
- `.claude-plugin/marketplace.json` 用于 `/plugin marketplace add` 的 marketplace 配置