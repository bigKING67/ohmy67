---
name: codex-best-practices
description: Bootstrap and standardize Codex setup for a new or existing repository based on official OpenAI best practices. Use when asked to initialize or improve AGENTS.md, .codex/config.toml, instruction layering, planning/testing/review workflow, MCP/skill onboarding, or "new project Codex configuration" tasks (including Chinese requests like "新项目接入 Codex", "初始化 AGENTS.md", "配置 config.toml"). Do not trigger for pure feature implementation or bugfix tasks unrelated to Codex setup and governance.
---

# Codex Best Practices

## Overview

将 OpenAI 官方 Codex best-practices 转成可执行的项目初始化流程，减少“会用但不稳定”的情况。
优先产出可复用配置与最小闭环验证，而不是一次性提示词。

## Invocation

本 skill 采用显式触发策略，不走隐式匹配。
在 CLI/IDE/App 中使用 `$codex-best-practices` 调用。

## Precheck

在改任何文件前先做 3 个检查：

1. 定位落地根目录。
   - 如果当前在 Git 仓库内：`git rev-parse --show-toplevel` 作为落地根目录。
   - 如果不在 Git 仓库内：默认当前目录为落地根目录，并在交付中标注该决策。
2. 检查是否已有指令文件分层。
   - 查找：`AGENTS.override.md`、`AGENTS.md`、fallback 指令文件。
3. 检查是否已有 `.codex/config.toml`。
   - 若已有：最小改动增量更新。
   - 若没有：创建最小可用基线。

## Workflow

按下面顺序执行，除非用户明确要求跳过某一步。

1. 澄清目标与范围。
   - 确认这是“项目配置/协作规范”任务，而不是单一功能编码任务。
   - 要求或推断仓库技术栈、常用构建命令、测试命令、部署边界。

2. 先给任务输入结构，再开始改动。
   - 使用四段式输入模板：
     - Goal: 要达成的行为改变
     - Context: 相关文件/目录/报错
     - Constraints: 架构与安全约束
     - Done when: 验收标准
   - 对复杂任务先计划后实现：优先 Plan mode 或 `PLANS.md`。

3. 生成或更新 `AGENTS.md` 分层指令。
   - 如无文件，先用 `/init` 脚手架，再按项目实际命令和规范补全。
   - 至少包含：
     - repo 结构与关键目录
     - run/build/test/lint 命令
     - 工程约定与 PR 期望
     - 禁止事项与 Definition of Done
   - 规则保持简短、可执行、可验证。重复出错后再增量补规则。

4. 生成或更新 `.codex/config.toml`（必要时同时更新 `~/.codex/config.toml`）。
   - 仓库级配置放在 `.codex/config.toml`，个人默认放在 `~/.codex/config.toml`。
   - 默认权限从“更严格”开始，按需放开（approval/sandbox）。
   - 仅为真实高频流程启用 profile、multi-agent、MCP。

5. 建立“变更-验证-复核”闭环。
   - 明确要求：补/改测试、运行相关检查、确认行为、审查 diff。
   - 需要时显式加入 `/review` 使用约定与 `code_review.md` 参考。

6. 只在有真实收益时接入 MCP 与 Skills。
   - MCP: 上下文在仓库外且变动频繁时再接入，先 1-2 个关键工具。
   - Skills: 一个 skill 只做一类工作；高频重复任务优先技能化。

7. 工作流稳定后再自动化。
   - 手动执行仍不稳定时，不要直接上 Automations。
   - 稳定后把“方法”固化为 skill，把“频率”交给 automation。

8. 组织会话与并行方式。
   - 一条线程对应一个任务单元；真分叉再 fork。
   - 主线程聚焦核心问题，探索/测试/排查可分给子代理并行。

## Smoke Checks

完成基线配置后，至少执行以下 2 条快速验证命令：

```bash
codex --ask-for-approval never "Summarize the current instructions."
codex --cd <target-subdir> --ask-for-approval never "Show which instruction files are active."
```

如果是只读环境或命令不可执行，必须在交付中明确“未验证项 + 原因 + 建议复验命令”。

## Optional Script

对于重复执行的仓库初始化，优先使用脚本：

```bash
./scripts/bootstrap_codex_baseline.sh --root <path> --probe
```

默认行为：
- 若 `AGENTS.md` 已存在，执行块级 upsert（更新或追加 `CODEX-BASELINE` 托管块）。
- 若 `.codex/config.toml` 已存在，默认不覆盖。
- 需要整文件覆盖时显式传 `--force`（会先备份）。

可选参数：
- `--probe`：打印指令发现链（`AGENTS.override.md` / `AGENTS.md` / fallback 文件）并估算 `project_doc_max_bytes` 截断风险。
  包含 `CODEX_HOME` 全局链与仓库项目链的组合视图。
- `--probe-json <path>`：把探测结果输出为 JSON（会自动启用 `--probe`），便于 CI 或自动化流程消费。
- `--strict-simulate`：启用严格模拟（按拼接分隔符与字节上限计算），并给出与基础估算的状态差异。
- `--strict-separator-bytes <n>`：配置严格模拟时文档间分隔字节数（默认 `2`）。
- `--verify-with-codex`：调用真实 `codex` 做链路验证，并将结果写入 JSON 的 `codex_verification`。
  若本机未登录或 `codex` 不可用，会在 `codex_verification.status/reason` 标注失败原因。
- `--no-append-block`：已有 `AGENTS.md` 时跳过块级更新。

## Output Contract

每次执行本 skill 时，输出以下内容：

1. 改动摘要：本次落地了哪些 Codex 配置项，为什么。
2. 具体文件：新增/修改的 `AGENTS.md`、`.codex/config.toml`、相关参考文件。
3. 验证结果：运行了哪些命令、结果如何、哪些未验证。
4. 风险与边界：当前配置的限制、后续需要用户确认的事项。
5. 下一步建议：仅给高价值下一步，不给泛泛建议。

## References

- Read `references/official-source-mapping.md` when user asks for evidence, rationale, or scope boundaries.
- Read `references/new-project-checklist.md` when producing a copy-ready setup checklist for a new repository.
- Read `references/templates.md` when you need prompt templates or file skeletons.
