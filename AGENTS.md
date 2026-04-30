# Skill 编写规范

> 参考：[官方最佳实践](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices.md) · [Skills 概述](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview.md) · [anthropics/claude-code skill-development](https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/skill-development/SKILL.md)

## 一、核心原则

**上下文窗口是公共资源。** Skill 与对话历史、其他 Skill 元数据、系统提示共享上下文。每个 token 都有竞争成本。

- 启动时只加载 frontmatter（name + description，约 100 词）
- SKILL.md 正文在 Skill 触发时才加载
- `references/` 文件仅在 Claude 需要时按需加载

**只加入 Claude 不具备的知识**。不要解释 Claude 已知的通用概念，只提供领域专有的工作流、约束和资源指针。

## 二、frontmatter 字段

```yaml
---
name: skill-name              # 必填；小写字母、数字、连字符；最多 64 字符
description: ...              # 必填；最多 1024 字符；第三人称；含触发短语
---
```

可选字段（按需使用）：

| 字段 | 说明 |
|------|------|
| `when_to_use` | 补充触发场景；与 description 合并后截断于 1536 字符 |
| `disable-model-invocation` | `true` 时禁止自动触发，只能 `/name` 手动调用 |
| `user-invocable` | `false` 时从 `/` 菜单隐藏（背景知识型 Skill） |
| `allowed-tools` | 预授权工具列表，如 `[Read, Grep, Glob]` |
| `context` | `fork` 时在独立 subagent 中运行 |

## 三、description 字段（最关键）

`description` 决定 Claude 能否从 100+ 个 Skill 中选中正确的 Skill。

**格式要求：**
- 使用**第三人称**（"This skill should be used when..."）
- 同时说明**做什么**（what）和**何时触发**（when）
- 前置关键词，因为超出 1536 字符会被截断
- 包含具体的**用户触发短语**

**好的示例：**
```yaml
description: Converts Grafana dashboard JSON exports to Jsonnet using grafana-code mixin conventions. Use when importing dashboards from Grafana UI exports, migrating to infrastructure-as-code, or integrating JSON dashboards into grafana-code.
```

**避免：**
```yaml
description: Helps with Grafana     # 过于模糊
description: Use this when...       # 非第三人称
description: Processes data         # 无触发场景
```

## 四、SKILL.md 正文规范

### 篇幅

- 目标 **1500–2000 词**，上限 **500 行**
- 超出时将详细内容移入 `references/`

### 写作风格

使用**祈使/动词开头**形式，不使用第二人称：

| 正确 | 错误 |
|------|------|
| `Convert panels with unified constructors.` | `You should convert panels...` |
| `Run verification after conversion.` | `You need to run verification...` |
| `To accomplish X, do Y.` | `If you need to do X, you should Y.` |

### 推荐结构

```
1. 标题与用途（1–2 句）
2. "不适用于"说明（防止误触发）
3. 带 checklist 的步骤工作流
4. 关键技术规范（guardrails、格式要求）
5. 最小代码骨架（可选）
6. Quality checklist
7. References 列表（指向 references/ 文件）
```

### 工作流 checklist 模式

复杂任务必须提供可追踪的 checklist，让 Claude 逐步标记完成：

```markdown
**复制此 checklist 追踪进度：**

\`\`\`
Progress:
- [ ] Step 1: ...
- [ ] Step 2: ...
- [ ] Step 3: ...
\`\`\`

**Step 1: ...**
[详细说明]
```

### 反馈循环模式

对质量敏感的任务，显式加入"失败则回退"的循环：

```markdown
运行验证脚本。如果验证失败，返回 Step N 修正后重新验证。
```

## 五、渐进式披露（Progressive Disclosure）

**三层加载模型：**

```
frontmatter  →  始终在上下文（~100 词）
SKILL.md 正文  →  Skill 触发时加载（目标 <500 行）
references/*  →  Claude 按需读取（无预加载成本）
```

**什么放 SKILL.md：**
- 核心工作流和关键规范
- 步骤 checklist
- 最小代码骨架
- 指向 `references/` 的指针

**什么移入 references/：**
- 详细 playbook（step-by-step 操作手册）
- API 参考、字段映射
- 完整示例（输入/输出对）
- 故障排除指南

**引用深度**：只保留一层引用（SKILL.md → references/file.md），不允许嵌套引用链（会导致 Claude 用 `head -100` 预览而非完整读取）。

**长引用文件**（>100 行）在顶部加目录：

```markdown
## Contents
- Authentication and setup
- Core methods
- Error handling
```

## 六、信息不重复原则

同一信息只存放一处：

- 详细内容在 `references/` → SKILL.md 中只留指针
- Step N 已说明的内容 → "Quick reference" 节不重复
- Quality checklist 已列的检查项 → 正文不再重复列举

## 七、文件命名与路径

- 描述性文件名：`full-conversion-playbook.md` 优于 `doc2.md`
- 始终用正斜杠：`references/guide.md`，不用 `references\guide.md`
- 目录按领域组织：`references/finance.md`、`references/sales.md`

## 八、内容质量

- **不写时效性信息**：不要写 "August 2025 之前用旧 API"；如必须保留历史，用 `<details>` 折叠
- **术语一致**：全文统一用同一个词，不混用同义词
- **脚本中不写魔法数字**：每个常量必须有注释说明原因
- **路径使用正斜杠**，避免 Windows 风格路径

## 九、Skill 验证 checklist

发布前检查：

**结构**
- [ ] `name` 只含小写字母/数字/连字符，与目录名一致
- [ ] `description` 第三人称，含具体触发短语，非空
- [ ] SKILL.md 正文 ≤ 500 行
- [ ] 所有 `references/` 中引用的文件真实存在

**内容质量**
- [ ] 正文使用祈使/动词开头形式，无第二人称
- [ ] 含带 checklist 的步骤工作流
- [ ] 无时效性表述
- [ ] 术语全文一致
- [ ] SKILL.md 与 references/ 无重复内容

**渐进式披露**
- [ ] 详细内容已移入 `references/`
- [ ] 引用深度 ≤ 1 层
- [ ] 长引用文件含目录

**测试**
- [ ] 触发短语能命中预期用户查询
- [ ] 构建/编译通过
- [ ] 在真实任务中验证过
