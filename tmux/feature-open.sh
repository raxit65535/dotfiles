#!/usr/bin/env bash
# feature-open - create or reuse a per-feature git worktree.
#
# Purpose:
# - run from inside a git repo and create/reuse a feature worktree
# - create or reuse `<repo>/.worktrees/<feature>`
# - optionally open the worktree in VS Code or IntelliJ
# - print the next `cop open ...` command for long-running tmux work
#
# Workflow fit:
# - use this when the repo is already open in VS Code and you want a dedicated
#   worktree for a new feature request or bugfix
# - use the printed `cop open ...` command when the feature needs a long-lived
#   tmux execution context for AI-assisted implementation or review
# - use `uncop cleanup <session> --worktree` after the branch is merged or the
#   worktree is no longer needed
#
# Common examples:
#   feature-open my-feature
#   feature-open team/my-feature --no-ide
#   feature-open my-feature --ide idea
#   feature-open my-feature --print-path
#
# Workflow examples:
#   cd ~/.dotfiles && feature-open my-feature
#   feature-open my-feature && cop open dotfiles-my-feature .worktrees/my-feature
#
# Manual command equivalents:
#   git -C . rev-parse --show-toplevel
#   mkdir -p .worktrees
#   git worktree add -b my-feature .worktrees/my-feature master
#   code .worktrees/my-feature

set -euo pipefail

usage() {
	cat <<'EOF'
Usage:
	feature-open <feature> [--ide code|idea] [--base <branch>] [--no-ide] [--print-path]
  feature-open --help

Options:
  --ide <code|idea>   IDE to open (default: code)
  --base <branch>     Base branch for new feature branches (default: main or FEATURE_BASE_BRANCH)
  --no-ide            Do not open any IDE
  --print-path        Print the resolved worktree path after setup
  -h, --help          Show this help text

Environment:
  FEATURE_BASE_BRANCH     Default base branch name
  FEATURE_OPEN_SKIP_IDE   Legacy escape hatch; equivalent to --no-ide for automation

Examples:
	feature-open my-feature
	feature-open team/my-feature --no-ide
	feature-open my-feature --ide idea
	feature-open my-feature --print-path

Workflow examples:
	cd ~/.dotfiles && feature-open my-feature
	feature-open my-feature && cop open dotfiles-my-feature .worktrees/my-feature

Manual command equivalents:
	git -C . rev-parse --show-toplevel
	mkdir -p .worktrees
	git worktree add -b my-feature .worktrees/my-feature master
	code .worktrees/my-feature
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

repo_root_from_cwd() {
	local top_level
	top_level=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)
	[[ -n "$top_level" ]] || die "feature-open must be run from inside a git repository"
	canonical_dir "$top_level"
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

[[ ${#POSITIONAL[@]} -ge 1 ]] || {
	usage >&2
	exit 1
}

FEATURE_NAME=${POSITIONAL[0]}

if [[ ${FEATURE_OPEN_SKIP_IDE:-0} == "1" ]]; then
	OPEN_IDE=0
fi

ensure_valid_feature_name "$FEATURE_NAME"

REPO_PATH=$(repo_root_from_cwd)

WORKTREE_ROOT="$REPO_PATH/.worktrees"
mkdir -p "$WORKTREE_ROOT"
WORKTREE_ROOT=$(canonical_dir "$WORKTREE_ROOT")
WORKTREE_PATH="$WORKTREE_ROOT/$FEATURE_NAME"
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
