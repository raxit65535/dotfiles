#!/usr/bin/env bash
# feature-open <repo> <feature> [--ide code|idea] [--base <branch>] [--no-ide] [--print-path]
# Creates or reuses a feature worktree and optionally opens it in an IDE.

set -euo pipefail

usage() {
	cat <<'EOF'
Usage:
  feature-open <repo> <feature> [--ide code|idea] [--base <branch>] [--no-ide] [--print-path]
  feature-open --help

Options:
  --ide <code|idea>   IDE to open (default: code)
  --base <branch>     Base branch for new feature branches (default: main or FEATURE_BASE_BRANCH)
  --no-ide            Do not open any IDE
  --print-path        Print the resolved worktree path after setup
  -h, --help          Show this help text

Environment:
  WORKSPACE_ROOT          Root directory to search for repos (default: $HOME/workspace)
  FEATURE_BASE_BRANCH     Default base branch name
  FEATURE_OPEN_SKIP_IDE   Legacy escape hatch; equivalent to --no-ide for automation
EOF
}

die() {
	echo "Error: $*" >&2
	exit 1
}

canonical_dir() {
	(
		cd "$1" >/dev/null 2>&1
		pwd -P
	)
}

resolve_joined_path() {
	# Use Python for robust path joining + normalization without shell escaping
	# pitfalls when feature names contain path separators.
	python3 - "$1" "$2" <<'PY'
import os
import sys

base = sys.argv[1]
relative = sys.argv[2]
print(os.path.realpath(os.path.join(base, relative)))
PY
}

ensure_valid_feature_name() {
	local feature_name=$1
	git check-ref-format --branch "$feature_name" >/dev/null 2>&1 ||
		die "Feature name must be a valid git branch name: $feature_name"
}

ensure_within_worktree_root() {
	local worktree_root=$1
	local worktree_path=$2

	case "$worktree_path/" in
	"$worktree_root/"*)
		return 0
		;;
	esac

	die "Feature worktree path escapes $worktree_root: $worktree_path"
}

open_in_ide() {
	local ide=$1
	local worktree_path=$2

	case "$ide" in
	code)
		command -v code >/dev/null 2>&1 || die "VS Code CLI 'code' was not found. Install it or rerun with --ide idea or --no-ide"
		code "$worktree_path"
		printf '%s\n' 'opened in VS Code'
		;;
	idea)
		if command -v idea >/dev/null 2>&1; then
			idea "$worktree_path"
		elif command -v open >/dev/null 2>&1; then
			open -na "IntelliJ IDEA.app" --args "$worktree_path"
		else
			die "IntelliJ launcher not found. Install the 'idea' CLI or rerun with --no-ide"
		fi
		printf '%s\n' 'opened in IntelliJ IDEA'
		;;
	*)
		die "Unsupported IDE '$ide'. Use 'code' or 'idea'"
		;;
	esac
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
	usage
	exit 0
fi

POSITIONAL=()
OPEN_IDE=1
PRINT_PATH=0
IDE=${FEATURE_OPEN_IDE:-code}
BASE_BRANCH=${FEATURE_BASE_BRANCH:-main}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--ide)
		[[ $# -ge 2 ]] || die "Missing value for --ide"
		IDE=$2
		shift 2
		;;
	--base)
		[[ $# -ge 2 ]] || die "Missing value for --base"
		BASE_BRANCH=$2
		shift 2
		;;
	--no-ide)
		OPEN_IDE=0
		shift
		;;
	--print-path)
		PRINT_PATH=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		POSITIONAL+=("$1")
		shift
		;;
	esac
done

[[ ${#POSITIONAL[@]} -ge 2 ]] || {
	usage >&2
	exit 1
}

REPO_NAME=${POSITIONAL[0]}
FEATURE_NAME=${POSITIONAL[1]}
WORKSPACE_ROOT=${WORKSPACE_ROOT:-"$HOME/workspace"}

if [[ ${FEATURE_OPEN_SKIP_IDE:-0} == "1" ]]; then
	OPEN_IDE=0
fi

[[ -d "$WORKSPACE_ROOT" ]] || die "Workspace root does not exist: $WORKSPACE_ROOT"
ensure_valid_feature_name "$FEATURE_NAME"

REPO_PATH=""
# Find an actual repository root (not a nested folder) that matches the
# requested name and ignore existing .worktrees directories.
while IFS= read -r candidate; do
	[[ -n "$candidate" ]] || continue
	git -C "$candidate" rev-parse --show-toplevel >/dev/null 2>&1 || continue
	candidate_path=$(canonical_dir "$candidate")
	top_level=$(git -C "$candidate" rev-parse --show-toplevel 2>/dev/null || true)
	if [[ -n "$top_level" && "$(canonical_dir "$top_level")" == "$candidate_path" ]]; then
		REPO_PATH=$candidate_path
		break
	fi
done < <(find "$WORKSPACE_ROOT" -maxdepth 4 -type d -name "$REPO_NAME" ! -path '*/.worktrees/*' | sort)

[[ -n "$REPO_PATH" ]] || die "Could not find repo '$REPO_NAME' under $WORKSPACE_ROOT"

WORKTREE_ROOT="$REPO_PATH/.worktrees"
mkdir -p "$WORKTREE_ROOT"
WORKTREE_ROOT=$(canonical_dir "$WORKTREE_ROOT")
WORKTREE_PATH=$(resolve_joined_path "$WORKTREE_ROOT" "$FEATURE_NAME")
ensure_within_worktree_root "$WORKTREE_ROOT" "$WORKTREE_PATH"
mkdir -p "$(dirname "$WORKTREE_PATH")"

if [[ -e "$WORKTREE_PATH" && ! -e "$WORKTREE_PATH/.git" ]]; then
	die "Path exists but is not a git worktree: $WORKTREE_PATH"
fi

CREATED_WORKTREE=0
# Decision tree:
# 1) Existing valid worktree path => reuse.
# 2) Existing local branch => create linked worktree from that branch.
# 3) No branch yet => create branch from base and add worktree.
if git -C "$WORKTREE_PATH" rev-parse --show-toplevel >/dev/null 2>&1; then
	:
elif git -C "$REPO_PATH" show-ref --verify --quiet "refs/heads/$FEATURE_NAME"; then
	git -C "$REPO_PATH" worktree add "$WORKTREE_PATH" "$FEATURE_NAME" >/dev/null 2>&1
	CREATED_WORKTREE=1
else
	BASE_REF=""
	if git -C "$REPO_PATH" show-ref --verify --quiet "refs/heads/$BASE_BRANCH"; then
		BASE_REF=$BASE_BRANCH
	elif git -C "$REPO_PATH" show-ref --verify --quiet "refs/remotes/origin/$BASE_BRANCH"; then
		BASE_REF="origin/$BASE_BRANCH"
	else
		die "Base branch '$BASE_BRANCH' not found in $REPO_PATH"
	fi

	git -C "$REPO_PATH" worktree add -b "$FEATURE_NAME" "$WORKTREE_PATH" "$BASE_REF" >/dev/null 2>&1
	CREATED_WORKTREE=1
fi

BRANCH_NAME=$(git -C "$WORKTREE_PATH" branch --show-current 2>/dev/null || true)
[[ -n "$BRANCH_NAME" ]] || BRANCH_NAME="detached"

OPEN_STATUS='skipped (--no-ide)'
if [[ $OPEN_IDE -eq 1 ]]; then
	OPEN_STATUS=$(open_in_ide "$IDE" "$WORKTREE_PATH")
fi

printf '\nfeature-open ready\n'
printf '  repo: %s\n' "$REPO_PATH"
printf '  worktree: %s\n' "$WORKTREE_PATH"
printf '  branch: %s\n' "$BRANCH_NAME"
printf '  status: %s\n' "$OPEN_STATUS"
printf '  worktree-action: %s\n' "$([[ $CREATED_WORKTREE -eq 1 ]] && echo created || echo reused)"
printf '  next: cop open %s %s\n\n' "$(basename "$REPO_PATH")-$FEATURE_NAME" "$WORKTREE_PATH"

if [[ $PRINT_PATH -eq 1 ]]; then
	printf '%s\n' "$WORKTREE_PATH"
fi
