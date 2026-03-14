# ohmy67

个人 AI 实战经验与工具沉淀仓库。  
这里主要收集两类内容：

1. 可直接复用的 AI 工作流与规范（尤其是 Codex/Agent 协作相关）。
2. 经过实战验证的工具、脚本、模板与参考资料。

## 仓库目标

- 把“能用一次”的经验，沉淀为“可复用、可迁移、可验证”的资产。
- 减少重复踩坑，提升 AI 协作在真实项目中的稳定性与交付质量。
- 通过结构化文档 + 脚本，形成可执行的实践闭环。

## 当前内容

### 1) Codex Skill：Best Practices

路径：`codex/skills/codex-best-practices/`

包含内容：

- `SKILL.md`：Skill 定义与执行流程
- `scripts/bootstrap_codex_baseline.sh`：初始化/标准化脚本
- `agents/openai.yaml`：代理配置样例
- `references/`：官方映射、检查清单、模板等参考资料

适用场景：

- 新仓库接入 Codex
- 现有仓库规范化 Agent 协作
- AGENTS / config / 测试与评审流程基线搭建

## 快速开始

```bash
# 1) 克隆仓库
git clone https://github.com/bigKING67/ohmy67.git
cd ohmy67

# 2) 查看 Skill 说明
sed -n '1,220p' codex/skills/codex-best-practices/SKILL.md
```

## 目录结构

```text
.
├── codex/
│   └── skills/
│       └── codex-best-practices/
│           ├── agents/
│           ├── references/
│           ├── scripts/
│           └── SKILL.md
└── README.md
```

## 维护原则

- 只收录真实项目中验证过的实践。
- 优先可执行（脚本/模板/检查项），而不是抽象口号。
- 每次更新尽量说明动机、边界和验证方式。

## 后续规划

- 继续补充更多可复用 Skills（研发协作、排障、上线前检查等）。
- 增加按场景组织的实战案例与复盘记录。
- 增加工具对比与选型建议（含适用边界）。
