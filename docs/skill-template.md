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

## SKILL.md 模板

```
---
name: skill-name
description: Clear, specific trigger guidance. Mention the input types and the desired output.
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