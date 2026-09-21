#!/usr/bin/env bash
# Symlinks every skill in this repo into one or more agents' skills directories.
#
#   ./install.sh --claude   ~/.claude/skills
#   ./install.sh --codex    $CODEX_HOME/skills, default ~/.codex/skills
#   ./install.sh --all      both
#
# A skill is any top-level directory that holds a SKILL.md. An existing
# symlink is replaced. An existing real directory is replaced only when its
# contents match the repo copy; otherwise it is left alone and reported.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "usage: $(basename "$0") [--claude] [--codex] [--all]" >&2
  exit 2
}

targets=()
[[ $# -eq 0 ]] && usage
for arg in "$@"; do
  case "$arg" in
    --claude) targets+=("$HOME/.claude/skills") ;;
    --codex) targets+=("${CODEX_HOME:-$HOME/.codex}/skills") ;;
    --all)
      targets+=("$HOME/.claude/skills")
      targets+=("${CODEX_HOME:-$HOME/.codex}/skills")
      ;;
    -h | --help) usage ;;
    *)
      echo "unknown argument: $arg" >&2
      usage
      ;;
  esac
done

skills=()
for skill_md in "$repo_dir"/*/SKILL.md; do
  [[ -f "$skill_md" ]] || continue
  skills+=("$(basename "$(dirname "$skill_md")")")
done
if [[ ${#skills[@]} -eq 0 ]]; then
  echo "no skills found in $repo_dir" >&2
  exit 1
fi

link_skill() {
  local target_dir="$1" skill="$2"
  local src="$repo_dir/$skill" dst="$target_dir/$skill"

  if [[ -L "$dst" ]]; then
    if [[ "$(readlink "$dst")" == "$src" ]]; then
      echo "ok       $dst"
      return
    fi
    rm "$dst"
  elif [[ -d "$dst" ]]; then
    if diff -rq "$src" "$dst" >/dev/null; then
      rm -r "$dst"
    else
      echo "skipped  $dst differs from $src; remove it to link" >&2
      return
    fi
  elif [[ -e "$dst" ]]; then
    echo "skipped  $dst exists and is not a directory" >&2
    return
  fi

  ln -s "$src" "$dst"
  echo "linked   $dst -> $src"
}

for target_dir in "${targets[@]}"; do
  mkdir -p "$target_dir"
  for skill in "${skills[@]}"; do
    link_skill "$target_dir" "$skill"
  done
done
