#!/usr/bin/env bash
# uncop - inspect, stop, and optionally clean up cop-managed tmux sessions.

set -euo pipefail

SESSION_PATH_OPTION='@cop_session_path'

usage() {
	cat <<'EOF'
Usage:
  uncop info <session>
  uncop kill <session> [--force]
  uncop cleanup <session> [--worktree] [--force]
  uncop --help

Subcommands:
  info      Show stored cleanup metadata for a session
  kill      Kill the tmux session only
  cleanup   Kill the tmux session and optionally remove its linked worktree

Options:
  --worktree  Also remove the linked worktree after validation
  --force     Skip interactive confirmation prompts
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

ensure_tmux() {
	command -v tmux >/dev/null 2>&1 || die "tmux is not installed or not on PATH"
}

session_exists() {
	tmux has-session -t "$1" 2>/dev/null
}

get_session_path() {
	local session_name=$1
	local stored_path current_path

	stored_path=$(tmux show-options -v -t "$session_name" "$SESSION_PATH_OPTION" 2>/dev/null || true)
	if [[ -n "$stored_path" ]]; then
		printf '%s\n' "$stored_path"
		return 0
	fi

	current_path=$(tmux display-message -p -t "$session_name:agent" '#{pane_current_path}' 2>/dev/null ||
		tmux display-message -p -t "$session_name:1" '#{pane_current_path}' 2>/dev/null || true)
	printf '%s\n' "$current_path"
}

is_linked_worktree() {
	local session_path=$1
	local normalized_path=$session_path

	if [[ -d "$session_path" ]]; then
		normalized_path=$(canonical_dir "$session_path")
	fi

	# Compare canonical paths from `git worktree list` so symlinked or relative
	# representations still match the same on-disk worktree.
	git -C "$session_path" worktree list --porcelain 2>/dev/null | while IFS= read -r line; do
		[[ $line == worktree\ * ]] || continue
		local listed_path=${line#worktree }
		if [[ -d "$listed_path" ]] && [[ "$(canonical_dir "$listed_path")" == "$normalized_path" ]]; then
			return 0
		fi
	done
	return 1
}

repo_name_for_path() {
	local target_path=$1
	local common_git_dir git_root

	common_git_dir=$(git -C "$target_path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
	if [[ -n "$common_git_dir" ]]; then
		printf '%s\n' "$(basename "$(dirname "$common_git_dir")")"
		return 0
	fi

	git_root=$(git -C "$target_path" rev-parse --show-toplevel 2>/dev/null || true)
	if [[ -n "$git_root" ]]; then
		printf '%s\n' "$(basename "$git_root")"
		return 0
	fi

	printf '%s\n' "$(basename "$target_path")"
}

validate_removable_worktree() {
	local session_path=$1
	local abs_git_dir common_git_dir

	[[ -n "$session_path" ]] || die 'Could not determine the stored session path.'
	[[ -d "$session_path" ]] || die "Path does not exist on disk: $session_path"
	git -C "$session_path" rev-parse --show-toplevel >/dev/null 2>&1 || die "Path is not inside a git worktree: $session_path"
	is_linked_worktree "$session_path" || die "Path is not a registered git worktree: $session_path"

	abs_git_dir=$(git -C "$session_path" rev-parse --path-format=absolute --absolute-git-dir 2>/dev/null || true)
	common_git_dir=$(git -C "$session_path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
	[[ -n "$abs_git_dir" && -n "$common_git_dir" ]] || die "Could not resolve git worktree metadata for $session_path"

	# Linked worktrees have their own gitdir file/dir while sharing common git
	# metadata with the main checkout; equal paths indicate the main checkout.
	if [[ "$abs_git_dir" == "$common_git_dir" ]]; then
		die "Path is the main repo worktree, not a linked worktree: $session_path"
	fi
}

confirm_action() {
	local prompt=$1
	local force=${2:-0}
	local confirm
	if [[ $force -eq 1 ]]; then
		return 0
	fi
	read -r -p "$prompt" confirm
	[[ "$confirm" == 'y' ]]
}

print_cleanup_info() {
	local session_name=$1
	local session_path repo_name branch_name linked_status

	session_exists "$session_name" || die "No session named '$session_name' found"
	session_path=$(get_session_path "$session_name")
	if [[ -d "$session_path" ]]; then
		session_path=$(canonical_dir "$session_path")
	fi

	printf 'Session: %s\n' "$session_name"
	printf 'Path: %s\n' "$session_path"
	if git -C "$session_path" rev-parse --show-toplevel >/dev/null 2>&1; then
		repo_name=$(repo_name_for_path "$session_path")
		branch_name=$(git -C "$session_path" branch --show-current 2>/dev/null || true)
		[[ -n "$branch_name" ]] || branch_name='detached'
		if is_linked_worktree "$session_path"; then
			linked_status='yes'
		else
			linked_status='no'
		fi
		printf 'Repo: %s\n' "$repo_name"
		printf 'Branch: %s\n' "$branch_name"
		printf 'Linked worktree: %s\n' "$linked_status"
	else
		printf 'Repo: unknown\n'
		printf 'Branch: unknown\n'
		printf 'Linked worktree: unknown\n'
	fi
}

kill_session_only() {
	local session_name=$1
	local force=$2
	session_exists "$session_name" || die "No session named '$session_name' found"
	confirm_action "Kill session '$session_name'? (y/n) " "$force" || {
		echo 'Aborted.'
		exit 0
	}
	tmux kill-session -t "$session_name"
	echo "Session '$session_name' killed."
}

cleanup_session() {
	local session_name=$1
	local remove_worktree=$2
	local force=$3
	local session_path

	session_exists "$session_name" || die "No session named '$session_name' found"
	session_path=$(get_session_path "$session_name")
	if [[ -d "$session_path" ]]; then
		session_path=$(canonical_dir "$session_path")
	fi

	if [[ $remove_worktree -eq 1 ]]; then
		validate_removable_worktree "$session_path"
	fi

	confirm_action "Cleanup session '$session_name'? (y/n) " "$force" || {
		echo 'Aborted.'
		exit 0
	}
	# Session shutdown is always confirmed before any optional filesystem removal.
	tmux kill-session -t "$session_name"
	echo "Session '$session_name' killed."

	if [[ $remove_worktree -eq 1 ]]; then
		# Ask for explicit second confirmation before removing a linked worktree.
		confirm_action "Also remove linked worktree at $session_path? (y/n) " "$force" || {
			echo "Linked worktree kept at $session_path."
			exit 0
		}
		git -C "$session_path" worktree remove "$session_path" --force
		echo "Worktree at $session_path removed."
	fi
}

ensure_tmux

if [[ $# -eq 0 || ${1:-} == '--help' || ${1:-} == '-h' ]]; then
	usage
	exit 0
fi

SUBCOMMAND=$1
shift
FORCE=0
REMOVE_WORKTREE=0
SESSION=''

case "$SUBCOMMAND" in
info)
	SESSION=${1:-}
	[[ -n "$SESSION" ]] || die "Usage: uncop info <session>"
	[[ $# -eq 1 ]] || die "Usage: uncop info <session>"
	print_cleanup_info "$SESSION"
	;;
kill)
	SESSION=${1:-}
	[[ -n "$SESSION" ]] || die "Usage: uncop kill <session> [--force]"
	shift || true
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--force)
			FORCE=1
			shift
			;;
		*)
			die "Unknown argument: $1"
			;;
		esac
	done
	kill_session_only "$SESSION" "$FORCE"
	;;
cleanup)
	SESSION=${1:-}
	[[ -n "$SESSION" ]] || die "Usage: uncop cleanup <session> [--worktree] [--force]"
	shift || true
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--worktree)
			REMOVE_WORKTREE=1
			shift
			;;
		--force)
			FORCE=1
			shift
			;;
		*)
			die "Unknown argument: $1"
			;;
		esac
	done
	cleanup_session "$SESSION" "$REMOVE_WORKTREE" "$FORCE"
	;;
*)
	usage >&2
	exit 1
	;;
esac
