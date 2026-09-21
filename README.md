# skills

Agent skills in the SKILL.md format (YAML frontmatter and a markdown body).
Each skill is one directory with a `SKILL.md` at its root.

| Skill | Purpose |
| --- | --- |
| `create-worktree` | Create a git worktree through herdr, run repo setup, split panes, and start a worker agent with the task context. `--agent <kind>` picks the worker; the default is the agent running the skill. |
| `remove-worktree` | Remove a herdr worktree after a check that no work is lost. |

## Install

`install.sh` symlinks every skill into an agent's skills directory:

```bash
./install.sh --claude   # ~/.claude/skills
./install.sh --codex    # $CODEX_HOME/skills, default ~/.codex/skills
./install.sh --all      # both
```

An existing symlink is replaced. An existing real directory is replaced only
when its contents match the repo copy; otherwise it is left alone and reported.
