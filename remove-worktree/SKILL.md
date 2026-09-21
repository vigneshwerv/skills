---
name: remove-worktree
description: Use whenever the user asks to remove, prune, delete, or clean up a herdr worktree and its workspace/session (e.g. "prune worktree-foo from herdr", "kill the worktree session for X", "remove the FRA-1234 worktree"). Resolves the herdr workspace, verifies nothing unpushed is lost, removes the worktree via herdr, and reports.
---

# Remove a herdr worktree

Remove worktrees with **herdr**, never with raw `git worktree remove`. Requires `HERDR_ENV=1`; if herdr is unavailable, stop and tell the user instead of falling back to git.

## 1. Resolve the workspace

The user names a worktree by its herdr label, a path fragment, or a branch. Match it against live state, not the filesystem:

```bash
herdr workspace list
```

Find the entry whose `label`, `worktree.checkout_path`, or branch matches, and read its `workspace_id` (e.g. `w34`) and `worktree.checkout_path` from the JSON. Labels are often misremembered (`worktree-schema-json` vs the real `worktree-json-schema`); if exactly one entry is a near match, use it and say which one you picked in the report. If several match or none do, list the candidates and ask.

## 2. Verify nothing is lost

Run inside the checkout path before removing anything:

```bash
git status --short                          # must be empty
git branch --show-current
git rev-parse --abbrev-ref @{upstream}      # must resolve
git log --oneline @{upstream}..HEAD         # must be empty
```

If the tree is dirty, the branch has no upstream, or there are unpushed commits, **stop and ask**. Report the branch, the dirty files, and the unpushed commits. Do not use `--force` unless the user explicitly says to discard that work.

## 3. Remove the worktree

```bash
herdr worktree remove --workspace <workspace_id>
```

This one command removes the git worktree, deletes the checkout directory, and closes the herdr workspace with its tab and panes. Do not follow it with `herdr workspace close` — the workspace is already gone and that call returns `workspace_not_found`, which is not an error to fix.

Any agent still running in the workspace's panes is terminated by this removal. If `workspace list` showed `agent_status: working`, mention that to the user before removing.

## 4. Verify

From the main repo:

```bash
herdr workspace list | grep -c <label>      # 0
git worktree list | grep <label>            # no entry
ls <checkout_path>                          # No such file or directory
```

## 5. Report

Tell the user: which workspace and path were removed, the branch name and that it was fully pushed, and that the herdr workspace is closed. **Leave the local branch alone** — the worktree removal does not delete it, and deleting it is a separate request. If you resolved a fuzzy name, say which label you matched.
