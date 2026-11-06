# Agent Skills

Skills that a coding agent (Claude Code, or any agent that reads `SKILL.md`
skills) can use inside a **Consumer Project**.

| Skill | Purpose |
|---|---|
| [`ff-sec-adopt`](ff-sec-adopt/SKILL.md) | Inspect a project, detect its Filecoin Security Profiles, and add the ff-sec-actions workflows that fit its context, pinned and advisory-first. |

## Install In A Consumer Project

Copy the skill directory into the project's skill folder, for example for
Claude Code:

```bash
git clone --depth 1 https://github.com/filecoin-project/ff-sec-actions /tmp/ff-sec-actions
mkdir -p .claude/skills
cp -R /tmp/ff-sec-actions/skills/ff-sec-adopt .claude/skills/
```

Then ask the agent to "add ff-sec-actions to this project" or invoke
`/ff-sec-adopt`. The skill fetches the Control Repository at run time and
copies pins from its examples and workflow docs, so an older copy of the skill
still produces current reviewed pins. Update the skill copy when its
`metadata.version` changes.
