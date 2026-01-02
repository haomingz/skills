# Agent Skills 目录

Grafana Jsonnet 工作流和仪表板管理的 Claude Code 技能集合。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude-Code-blue.svg)](https://claude.ai/code)

## 概述

这是一个长期维护的 Claude Code / Codex 技能目录仓库，遵循官方 Agent Skills 规范。每个 skill 都是一个自包含的包，提供专门的知识、工作流程和工具，用于处理 Grafana 仪表板、Jsonnet 和数据可视化。

## 快速开始

### 安装

1. **添加本仓库为 Claude Code marketplace：**
   ```bash
   /plugin marketplace add https://github.com/haomingz/skills
   ```

2. **安装插件：**
   ```bash
   /plugin install grafana-skills@haoming-skills
   ```

3. **开始使用：**
   Skills 会被 Claude 自动发现并在相关场景下触发。只需自然地描述你的任务即可！

### 前置要求

- 已安装 Claude Code CLI
- Python 3.8+ (用于转换脚本)
- Git (版本控制)

## 包含的技能

### 1. grafana-json-to-jsonnet

将 Grafana 导出的仪表板 JSON 转换为符合 grafana-code mixin 风格的 Jsonnet。

**触发短语：** "convert grafana json", "grafana export to jsonnet", "import grafana dashboard"

**使用示例：**
```
你：我有一个 Grafana 仪表板的 JSON 导出文件，能帮我转换成遵循 grafana-code 规范的 Jsonnet 吗？
Claude: [自动触发 grafana-json-to-jsonnet skill]
```

**功能：**
- 将 Grafana JSON 导出转换为结构化的 Jsonnet
- 将代码拆分为 entrypoint + library 结构
- 参数化数据源
- 将 panel 映射到 grafana-code builders

**了解更多：** [grafana-json-to-jsonnet](skills/grafana-json-to-jsonnet/SKILL.md)

---

### 2. grafana-jsonnet-refactor

将单体 Grafana Jsonnet 仪表板重构为清晰、可维护的拆分结构。

**触发短语：** "refactor grafana jsonnet", "split dashboard", "extract lib helpers"

**使用示例：**
```
你：这个 dashboard.jsonnet 文件太大了，能帮我重构一下吗？
Claude: [自动触发 grafana-jsonnet-refactor skill]
```

**功能：**
- 将单体仪表板拆分为 entrypoint + lib
- 提取可复用的 panel builders
- 消除代码重复
- 遵循 grafana-code mixin 规范

**了解更多：** [grafana-jsonnet-refactor](skills/grafana-jsonnet-refactor/SKILL.md)

---

### 3. grafana-report-to-dashboard

将 Python 报表脚本转换为支持多数据源的 Grafana Jsonnet 仪表板。

**触发短语：** "migrate report to grafana", "convert python report", "elasticsearch to grafana"

**使用示例：**
```
你：我有一个查询 Elasticsearch 并生成报表的 Python 脚本，能把它转成 Grafana 仪表板吗？
Claude: [自动触发 grafana-report-to-dashboard skill]
```

**功能：**
- 将 Python Elasticsearch 报表迁移到 Grafana
- 添加 ClickHouse + Elasticsearch 双数据源支持
- 将聚合查询映射到 Grafana panels
- 保持报表逻辑和指标

**了解更多：** [grafana-report-to-dashboard](skills/grafana-report-to-dashboard/SKILL.md)

## 仓库结构

```
.
├── README.md                    # 本文件
├── LICENSE                      # MIT 许可证
├── .gitignore                   # Git 忽略规则
├── .claude-plugin/              # Marketplace 配置
│   └── marketplace.json
├── skills/                      # 技能目录（自动发现）
│   ├── grafana-json-to-jsonnet/
│   │   ├── SKILL.md            # 技能定义
│   │   ├── scripts/            # 转换脚本
│   │   ├── references/         # 参考文档
│   │   └── examples/           # 示例文件
│   ├── grafana-jsonnet-refactor/
│   └── grafana-report-to-dashboard/
├── templates/                   # 技能模板（不会被自动发现）
│   └── skill-template/
└── docs/                        # 文档
    ├── skills-spec.md          # Skills 规范
    ├── catalog-structure.md    # 结构指南
    └── skill-template.md       # 模板文档
```

## 文档

- **[Skills 规范](docs/skills-spec.md)** - 官方 Agent Skills 规范摘要
- **[目录结构](docs/catalog-structure.md)** - 仓库结构约定
- **[Skill 模板](docs/skill-template.md)** - 创建新技能的模板

## Skills 工作原理

Skills 使用**渐进式披露**加载模型：

1. **元数据（YAML frontmatter）** - 始终在上下文中（约100字）
   - `name`: Skill 标识符
   - `description`: 何时以及如何触发该 skill

2. **SKILL.md 正文** - Skill 触发时加载（<5k 字）
   - 指令、步骤和工作流程

3. **打包资源** - 按需加载
   - `scripts/`: 可执行代码
   - `references/`: 参考文档
   - `examples/`: 示例输入/输出
   - `assets/`: 输出模板

这种设计在保持 Claude 上下文高效的同时，在需要时提供深度领域知识。

## 创建新技能

1. 复制技能模板：
   ```bash
   cp -r templates/skill-template skills/my-new-skill
   ```

2. 编辑 `SKILL.md`：
   - 更新 frontmatter（name、带触发短语的 description）
   - 编写清晰的指令
   - 添加示例和参考资料

3. 本地测试：
   ```bash
   /plugin reload
   ```

4. 提交 pull request！

详细指南参见 [docs/skill-template.md](docs/skill-template.md)。

## 贡献

欢迎贡献！请遵循以下指南：

1. **Fork 仓库**并创建功能分支
2. **遵循官方 Agent Skills 规范**（参见 docs/skills-spec.md）
3. **在 skill 描述中使用清晰的触发短语**
4. **在 `examples/` 目录中包含示例**
5. **提交前充分测试**
6. **提交带有清晰描述的 pull request**

### 开发环境设置

```bash
# 克隆仓库
git clone https://github.com/haomingz/skills.git
cd skills

# 安装 Python 依赖（如需要）
pip install -r requirements.txt

# 验证 skill 结构
bash scripts/validate-skills.sh
```

## 故障排除

### Skills 没有触发？

- 检查 description 是否包含清晰的触发短语
- 重新加载插件：`/plugin reload`
- 查看 Claude Code 日志中的错误

### 脚本执行失败？

- 验证 Python 版本（3.8+）
- 检查脚本依赖：`pip install -r requirements.txt`
- 查看脚本输出中的具体错误

### 需要帮助？

- 查看 `skills/*/SKILL.md` 中的技能文档
- 查看官方 Claude Code 文档
- 在 GitHub 上提出 issue

## 许可证

本项目基于 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 致谢

- 为 [Claude Code](https://claude.ai/code) 构建
- 遵循官方 [Agent Skills 规范](https://docs.claude.com)
- 受 Grafana 社区启发

---

**维护者：** Haoming Zhang
**版本：** 0.1.0
**最后更新：** 2026-01-02