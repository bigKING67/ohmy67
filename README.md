# ohmy67

个人 AI 实战经验与工具沉淀仓库。  
目标是把“临时可用的经验”沉淀成“可复用、可验证、可迁移”的资产。

## 仓库定位

- 主题：AI 工程协作、Codex 落地实践、实用脚本与模板。
- 形式：`Skill + Script + Reference` 组合，避免只给抽象方法论。
- 风格：优先可执行与可验证，尽量减少一次性提示词和不可复现经验。

## 导航入口

- `codex/`：Codex 相关资产总目录。
- `codex/skills/`：可复用 Skills 清单与说明。
- `codex/skills/codex-best-practices/`：当前核心 Skill，聚焦 Codex 基线初始化与规范化。

## 快速开始

```bash
# 1) 克隆仓库
git clone https://github.com/bigKING67/ohmy67.git
cd ohmy67

# 2) 阅读技能说明
sed -n '1,220p' codex/skills/codex-best-practices/SKILL.md

# 3) 查看初始化脚本
sed -n '1,220p' codex/skills/codex-best-practices/scripts/bootstrap_codex_baseline.sh
```

## 当前能力

`codex-best-practices` 提供以下能力：

- 新仓库接入 Codex 的最小可用基线。
- 现有仓库的 AGENTS / config / 流程规范化改造。
- 指令分层、验证闭环、评审约束的标准化落地。

## 目录结构

```text
.
├── README.md
└── codex/
    ├── README.md
    └── skills/
        ├── README.md
        └── codex-best-practices/
            ├── SKILL.md
            ├── agents/
            ├── references/
            └── scripts/
```

## 维护原则

- 只收录真实项目里验证过的内容。
- 脚本与说明同步更新，确保“能看懂也能执行”。
- 变更尽量附带动机、边界和验证方式。
