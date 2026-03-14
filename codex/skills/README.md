# skills

本目录存放可复用的 Codex Skills。  
目标是把高频、可标准化的协作任务沉淀为可直接调用的技能。

## Skills 清单

1. `codex-best-practices`
目标：初始化或规范化仓库的 Codex 协作基线。  
入口：`codex-best-practices/SKILL.md`  
典型场景：新项目接入、AGENTS/config 补齐、流程稳定性提升。

## 使用建议

1. 优先选择与任务目标强匹配的 skill，不做无关启用。
2. 执行前先读 `SKILL.md` 的 precheck 和 workflow。
3. 变更后按 skill 中的验证步骤做最小闭环检查。

## 新增 Skill 约定

1. 目录命名建议使用 kebab-case，例如 `my-new-skill`。
2. 必须包含 `SKILL.md`，建议包含 `scripts/` 与 `references/`。
3. `SKILL.md` 需写清“何时使用、何时不使用、如何验证”。
