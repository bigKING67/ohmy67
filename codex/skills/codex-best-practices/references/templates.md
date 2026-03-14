# Templates

## Prompt Template (Kickoff)

```text
Goal:
- [Describe target behavior]

Context:
- [Repo paths / docs / failing commands]

Constraints:
- [Security/compliance/architecture rules]

Done when:
- [Tests/checks/behavioral outcomes]
```

## AGENTS.md Seed (Minimum)

```markdown
# AGENTS.md

## Project Context
- Repo structure and key modules

## Commands
- Install:
- Dev:
- Lint:
- Type-check:
- Test:
- Build:

## Engineering Conventions
- Naming, architecture, error handling rules

## Safety Constraints
- Secret management
- Destructive command policy

## Definition of Done
- Required checks and acceptance criteria
```

## .codex/config.toml Seed (Minimum)

```toml
# Repository-level Codex defaults

# Example:
# model = "gpt-5-codex"
# model_reasoning_effort = "medium"
# approval_policy = "on-request"
# sandbox_mode = "workspace-write"

# Add MCP, profiles, or agents only when needed.
```
