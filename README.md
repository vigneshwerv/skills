# skills

Agent skills in the SKILL.md format (YAML frontmatter and a markdown body).
Each skill is one directory with a `SKILL.md` at its root.

| Skill | Purpose |
| --- | --- |
| `create-worktree` | Create a git worktree through herdr, run repo setup, split panes, and start a Codex agent with the task context. |
| `remove-worktree` | Remove a herdr worktree after a check that no work is lost. |

## Install

Symlink a skill into the agent's skills directory:

```bash
ln -s ~/code/skills/create-worktree ~/.claude/skills/create-worktree
ln -s ~/code/skills/remove-worktree ~/.claude/skills/remove-worktree
```
