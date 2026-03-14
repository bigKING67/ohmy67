# 官方依据映射（检索日期：2026-03-13）

本文件用于回答“为什么这条规则要这样配”的追问。仅记录与 `codex-best-practices` 直接相关的官方结论。

## 1) 用结构化任务输入提高首次成功率

- 结论：任务输入应明确 Goal / Context / Constraints / Done when，能显著降低范围漂移与错误假设。
- 来源：[OpenAI, 2026, https://developers.openai.com/codex/learn/best-practices]

## 2) 复杂任务先计划，再编码

- 结论：复杂或模糊任务优先使用 Plan mode、访谈式澄清或 `PLANS.md` 模板，不要直接改代码。
- 来源：[OpenAI, 2026, https://developers.openai.com/codex/learn/best-practices]

## 3) 用 AGENTS.md 固化长期规则

- 结论：把可复用协作规则写入 `AGENTS.md`，比反复在 prompt 中重述更稳定。
- 来源：[OpenAI, 2026, https://developers.openai.com/codex/learn/best-practices]
- 补充（发现顺序与覆盖关系）：全局到项目到子目录逐层加载，近处优先。
- 来源：[OpenAI, 2026, https://developers.openai.com/codex/guides/agents-md]

## 4) 用 config.toml 做一致性配置

- 结论：个人默认放 `~/.codex/config.toml`，仓库特定放 `.codex/config.toml`，先紧后松管理权限与沙箱。
- 来源：[OpenAI, 2026, https://developers.openai.com/codex/learn/best-practices]
- 补充（配置能力边界）：profile、agents、MCP 等应按真实需求启用。
- 来源：[OpenAI, 2026, https://developers.openai.com/codex/config-advanced]

## 5) 把“改动-测试-复核”作为默认闭环

- 结论：不要停在“改完代码”，应补测试、跑检查、确认行为、审查 diff。
- 来源：[OpenAI, 2026, https://developers.openai.com/codex/learn/best-practices]

## 6) MCP/Skills/Automation 的启用顺序

- 结论：MCP 仅在仓库外上下文是关键且频繁变化时启用；先少量高价值连接。
- 来源：[OpenAI, 2026, https://developers.openai.com/codex/learn/best-practices]
- 结论：高频重复流程应优先技能化；技能描述要清晰表达“做什么、何时触发”。
- 来源：[OpenAI, 2026, https://developers.openai.com/codex/skills]
- 结论：工作流先手动稳定，再进入 Automations 调度。
- 来源：[OpenAI, 2026, https://developers.openai.com/codex/learn/best-practices]

## 7) 会话组织原则

- 结论：一条线程对应一个任务单元，真分叉再 fork；必要时多 agent 分工并行。
- 来源：[OpenAI, 2026, https://developers.openai.com/codex/learn/best-practices]

## 证据边界说明

- 本 skill 的主结论来自 OpenAI 官方文档页面，不依赖社区二手解读。
- 若未来官方页面更新，优先以最新版本为准，并回写本文件的检索日期与映射条目。
