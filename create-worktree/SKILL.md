---
name: create-worktree
description: Use whenever the user asks to create a worktree for a task (e.g. "create a worktree for X", "spin up a worktree", "make a worktree for FRA-1234"). Creates the worktree via herdr, runs repo setup, splits three even panes (worker agent, Hunk review, user shell), and hands the agent the task context. Accepts `--agent <kind>` to choose the worker (claude, codex, gemini, ...); defaults to the agent running the skill.
---

# Create a worktree for a task

Create worktrees with **herdr**, never with raw `git worktree add`. Requires `HERDR_ENV=1`; if herdr is unavailable, stop and tell the user instead of falling back to git.

## 1. Determine the branch name, task context, and worker agent

- **Worker agent kind**: if the arguments include `--agent <kind>`, use that kind and drop the flag from the task text. Otherwise use the kind of the agent executing this skill (Claude Code is `claude`, Codex is `codex`). If that cannot be determined, use `codex`. The kind must be one herdr supports; check with `herdr agent start --help` if unsure.
- **Linear task** (the user names or links an issue like FRA-1234): fetch the issue with the Linear MCP `get_issue` tool. Use Linear's generated branch name (the issue's `gitBranchName`) — do not invent your own variant. Keep the issue title, description, and URL for the agent kickoff prompt in step 5.
- **No Linear task**: use a short kebab-case slug describing the task, no prefix (e.g. `fix-balance-drift`). The user's own task description is the context for step 5.

## 2. Create the worktree

From the repo the task belongs to (default: the current repo), base new branches on that repo's main development branch — for `workspaces` that is `dev`, not `main`.

```bash
herdr worktree create --branch <branch> --base dev --label "<short task label>"
```

The command returns JSON — read the worktree path and the root pane ID (`.result.root_pane.pane_id`) from the response rather than predicting them.

## 3. Run repo setup (bootstrap)

For the `workspaces` repo, run the setup script in the worktree's root pane so progress is visible in the new workspace, and wait on a completion marker:

```bash
herdr pane run <root-pane-id> "./setup_worktree.sh && echo BOOTSTRAP_DONE"
herdr pane wait-output <root-pane-id> --match "BOOTSTRAP_DONE" --timeout 600000
```

- Defaults are `--stage=dev --region=us-east-1`; pass `--stage=<name>` / `--region=<name>` only if the user asked for a specific stage or region (e.g. their personal stage).
- The script runs `yarn`, `yarn prepare`, then `assume` + `aws sso login` + dashboard `yarn gen-env`. The AWS steps complete via the browser; if the wait times out, `herdr pane read <root-pane-id> --source recent-unwrapped --lines 60` to see where it stalled, tell the user, and let them finish it in that pane — do not retry blindly.

For other repos, skip this step.

## 4. Split into three even panes: agent, Hunk, user

Only after bootstrap completes, split the root pane into three vertical columns of equal width — agent on the left, the Hunk review TUI in the middle, the user's shell on the right.

`--ratio` is the **left** side's share of the split being made, so thirds come out of `1/3` then `1/2`; no resizing afterwards:

```bash
# root keeps the left third; the new pane takes the right two thirds
herdr pane split --pane <root-pane-id> --direction right --ratio 0.3333 \
  --cwd <worktree-path> --no-focus
# halve that two thirds: middle for Hunk, right for the user
herdr pane split --pane <middle-pane-id> --direction right --ratio 0.5 \
  --cwd <worktree-path> --no-focus
```

Read each new pane id from the command's JSON rather than predicting it, and confirm the result with `herdr pane layout --pane <root-pane-id>` — the three `rect.width` values should match. If a layout ever needs correcting, `herdr pane resize --pane <id> --direction left|right --amount <fraction-of-split>` adjusts one seam.

Start Hunk in the middle pane, watching the worktree so it picks up the agent's edits as they land:

```bash
herdr pane run <middle-pane-id> "hunk diff --watch"
```

An empty worktree is fine — Hunk sits at zero files and fills in. Confirm the session is live with `hunk session list`; that session is what makes the agent's review notes in step 5 possible.

Then start the worker agent of the chosen kind in the left (root) pane with a name derived from the task (must match `[a-z][a-z0-9_-]{0,31}`, e.g. `fra-7545`):

```bash
herdr agent start <name> --kind <kind> --pane <root-pane-id>
```

When the kind is `claude`, enable remote control mode (`/rc`) in the agent. Other kinds have no equivalent; skip this.

## 5. Kick off the agent with task context

Send one kickoff prompt via `herdr agent prompt <name> "..."` (no `--wait` — the task will outlive any reasonable wait). The prompt must be self-contained; the agent has none of your conversation context. Include:

- The task: Linear issue ID, title, URL, and the full description (or the user's task description if no Linear issue).
- The branch name it is already on, and that it is in a fresh worktree at `<worktree-path>`.
- That bootstrap is done: dependencies installed, SST stage/region set, `dashboard/.env` generated — no setup needed.
- Anything task-relevant the user said when asking for the worktree (constraints, hints, files to look at).
- What to do: implement the task, run the repo's verification (`yarn typecheck-all`, relevant tests), and stop before committing unless told otherwise.
- How to leave comments for the user: **Hunk**, per the rules below. Spell them out in the prompt — the agent will not have read this skill.

### Leaving comments for the user with Hunk

The agent reports what it did in prose, but anything that is *about a specific line* belongs on that line. Instruct the agent to leave those as Hunk review notes once the work is verified:

```bash
# one note
hunk session comment add --repo <worktree-path> --file <path> --new-line <n> \
  --summary "<one sentence>" --rationale "<why, if it needs one>"

# several notes at once, validated as a batch
printf '%s\n' '{"comments":[{"filePath":"...","newLine":12,"summary":"..."}]}' \
  | hunk session comment apply --repo <worktree-path> --stdin
```

Rules to pass on:

- **Never run `hunk diff`, `hunk show`, or any other interactive Hunk command.** The TUI in the middle pane is the user's; the agent only drives that session through `hunk session *`.
- The session from step 4 is already live on the worktree, so `--repo <worktree-path>` resolves it. If `hunk session list` shows no match — the user closed it — say so in the final report and ask them to run `hunk diff` again, rather than dropping the notes.
- Comment on what the user would not spot alone — a decision worth second-guessing, a risk, a deliberate omission, a follow-up. Not every hunk, and never a restatement of the diff.
- Prefer one `comment apply` batch when several notes are already in hand.
- `--summary` is a real sentence; it is what `comment list` shows and the fallback everywhere else.

## 6. Report

Tell the user: branch name, worktree path, bootstrap status, the agent's kind, name and pane (left), that Hunk is watching the worktree in the middle pane and is where the agent's review notes will land, and that the right pane is their own shell. Do not implement the task yourself — the spawned agent owns it.
