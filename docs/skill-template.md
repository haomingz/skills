# Skill 模板

新增技能时使用 `templates/skill-template/` 作为起点。

> 建议：技能内容（`SKILL.md` 正文）继续使用英文，便于 Claude/Codex 精准触发与复用。

## 目录结构

```
skill-name/
├── SKILL.md
├── scripts/
├── references/
└── assets/
```

注意：
- `SKILL.md` frontmatter 仅需 `name` 和 `description`；可选字段见下文。
- 示例输入/输出建议放在 `references/` 内（例如 `references/example-input.json`）。
- 路径统一使用正斜杠（`references/example.md`），避免反斜杠。

## SKILL.md 模板

```
---
name: skill-name
description: Describes what the skill does and when to use it. Use third-person and include trigger keywords.
---

# Skill Title

## Inputs
- List required inputs

## Outputs
- List expected outputs

## Steps
1. Follow a repeatable workflow
2. Reference any bundled files as needed

## References
- `references/example.md`
```

## Frontmatter 规范（摘要）

必填字段：
- `name`：1-64 字符，仅小写字母/数字/连字符，且与目录名一致
- `description`：1-1024 字符，描述“做什么 + 何时用”，使用第三人称

可选字段（按需使用）：
- `license`：许可证标识
- `compatibility`：运行环境或依赖要求
- `metadata`：附加元数据
- `allowed-tools`：允许的工具列表（实验性）

## 最佳实践提示

- `SKILL.md` 控制在 500 行以内，过长内容放到 `references/`
- 长参考文档（>100 行）在顶部加 `## Contents` 目录
- 避免多层引用链（`SKILL.md` 应直接指向所需参考文件）
