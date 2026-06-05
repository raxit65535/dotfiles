#!/usr/bin/env bash
# cop - manage tmux AI workspaces for feature worktrees.

set -euo pipefail

SESSION_PATH_OPTION='@cop_session_path'
SESSION_MANAGED_OPTION='@cop_managed'
DEFAULT_LAYOUT_WINDOWS='agent, review, shell, watch'

usage() {
	cat <<'EOF'
Usage:
  cop open <session> [path] [--no-attach]
  cop attach <session>
  cop info <session>
  cop list
  cop doctor <session>
  cop --help

Subcommands:
  open      Create or reopen the standard four-window tmux workspace
  attach    Attach to an existing session
  info      Show stored repo, branch, path, and windows for a session
  list      List cop-managed tmux sessions
  doctor    Inspect a session and validate its stored path/git state

Options:
  --no-attach  Create or reuse the session without attaching (useful for tests/automation)
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
	local fallback_path=${2:-}
	local stored_path

	stored_path=$(tmux show-options -v -t "$session_name" "$SESSION_PATH_OPTION" 2>/dev/null || true)
	if [[ -n "$stored_path" ]]; then
		printf '%s\n' "$stored_path"
		return 0
	fi

	# Recover the path from the standard agent window first, then window index 1,
	# and finally the caller-provided fallback when tmux metadata is missing.
	tmux display-message -p -t "$session_name:agent" '#{pane_current_path}' 2>/dev/null ||
		tmux display-message -p -t "$session_name:1" '#{pane_current_path}' 2>/dev/null ||
		printf '%s\n' "$fallback_path"
}

join_windows() {
	local session_name=$1
	local first=1
	while IFS= read -r window_name; do
		[[ -n "$window_name" ]] || continue
		if [[ $first -eq 1 ]]; then
			printf '%s' "$window_name"
			first=0
		else
			printf ', %s' "$window_name"
		fi
	done < <(tmux list-windows -t "$session_name" -F '#W' 2>/dev/null)
	printf '\n'
}

repo_name_for_path() {
	local target_path=$1
	local common_git_dir git_root

	# For linked worktrees, --git-common-dir points to the main repo metadata,
	# so the parent directory name is the canonical repository name.
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

print_session_metadata() {
	local session_name=$1
	local target_path=$2
	local display_path repo_name branch_name git_root windows

	if [[ -d "$target_path" ]]; then
		display_path=$(canonical_dir "$target_path")
	else
		display_path=$target_path
	fi

	if git_root=$(git -C "$target_path" rev-parse --show-toplevel 2>/dev/null); then
		repo_name=$(repo_name_for_path "$target_path")
		branch_name=$(git -C "$target_path" branch --show-current 2>/dev/null || true)
		[[ -n "$branch_name" ]] || branch_name='detached'
	else
		repo_name=$(basename "$display_path")
		branch_name='not-a-git-repo'
	fi

	windows=$(join_windows "$session_name")
	printf 'Session: %s\n' "$session_name"
	printf 'Repo: %s\n' "$repo_name"
	printf 'Branch: %s\n' "$branch_name"
	printf 'Path: %s\n' "$display_path"
	printf 'Windows: %s\n' "${windows:-$DEFAULT_LAYOUT_WINDOWS}"
}

seed_window() {
	local target=$1
	local title=$2
	tmux send-keys -t "$target" "printf '\\033]2;$title\\033\\\\'" Enter
	tmux send-keys -t "$target" 'clear' Enter
}

create_layout() {
	local session_name=$1
	local repo_path=$2

	# Mark sessions we create so `cop list` can filter to managed workspaces only.
	tmux new-session -d -s "$session_name" -c "$repo_path" -n agent
	tmux set-option -t "$session_name" "$SESSION_PATH_OPTION" "$repo_path" >/dev/null
	tmux set-option -t "$session_name" "$SESSION_MANAGED_OPTION" '1' >/dev/null
	seed_window "$session_name:agent" 'agent'

	tmux new-window -t "$session_name" -n review -c "$repo_path"
	seed_window "$session_name:review" 'review'
	tmux send-keys -t "$session_name:review" "printf 'Review commands:\n'" Enter
	tmux send-keys -t "$session_name:review" "printf '  git log --oneline main..HEAD\n'" Enter
	tmux send-keys -t "$session_name:review" "printf '  git diff --stat main...HEAD\n'" Enter
	tmux send-keys -t "$session_name:review" "printf '  git diff main...HEAD | delta\n'" Enter
	tmux send-keys -t "$session_name:review" "printf '  git show <hash> | delta\n'" Enter

	# Keep shell/watch windows clean and title-labeled for quick role switching.
	tmux new-window -t "$session_name" -n shell -c "$repo_path"
	seed_window "$session_name:shell" 'shell'

	tmux new-window -t "$session_name" -n watch -c "$repo_path"
	seed_window "$session_name:watch" 'watch'

	tmux select-window -t "$session_name:agent"
}

open_session() {
	local session_name=$1
	local requested_path=${2:-}
	local attach_after=${3:-1}
	local repo_path

	repo_path=${requested_path:-"$HOME/code/$session_name"}
	[[ -d "$repo_path" ]] || die "path does not exist: $repo_path"
	repo_path=$(canonical_dir "$repo_path")

	if session_exists "$session_name"; then
		echo "Session '$session_name' already exists."
		print_session_metadata "$session_name" "$(get_session_path "$session_name" "$repo_path")"
		if [[ $attach_after -eq 1 ]]; then
			tmux attach-session -t "$session_name"
		fi
		return 0
	fi

	create_layout "$session_name" "$repo_path"
	print_session_metadata "$session_name" "$repo_path"
	echo "Session '$session_name' created. Review window seeded with review hints."
	if [[ $attach_after -eq 1 ]]; then
		tmux attach-session -t "$session_name"
	fi
}

attach_session() {
	local session_name=$1
	session_exists "$session_name" || die "No session named '$session_name' found"
	tmux attach-session -t "$session_name"
}

info_session() {
	local session_name=$1
	session_exists "$session_name" || die "No session named '$session_name' found"
	print_session_metadata "$session_name" "$(get_session_path "$session_name")"
}

list_sessions() {
	local found=0
	while IFS= read -r session_name; do
		[[ -n "$session_name" ]] || continue
		# Only sessions explicitly tagged by `cop` are included in this listing.
		if [[ "$(tmux show-options -v -t "$session_name" "$SESSION_MANAGED_OPTION" 2>/dev/null || true)" == '1' ]]; then
			found=1
			printf '%s\t%s\n' "$session_name" "$(get_session_path "$session_name")"
		fi
	done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null || true)

	if [[ $found -eq 0 ]]; then
		echo 'No cop-managed sessions found.'
	fi
}

doctor_session() {
	local session_name=$1
	local session_path git_dir common_git_dir

	session_exists "$session_name" || die "No session named '$session_name' found"
	session_path=$(get_session_path "$session_name")
	print_session_metadata "$session_name" "$session_path"
	if [[ -d "$session_path" ]]; then
		echo 'Path status: exists'
	else
		echo 'Path status: missing'
		return 0
	fi

	if git -C "$session_path" rev-parse --show-toplevel >/dev/null 2>&1; then
		echo 'Git status: valid repo'
		git_dir=$(git -C "$session_path" rev-parse --path-format=absolute --absolute-git-dir 2>/dev/null || true)
		common_git_dir=$(git -C "$session_path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
		if [[ -n "$git_dir" && -n "$common_git_dir" && "$git_dir" != "$common_git_dir" ]]; then
			echo 'Worktree status: linked worktree'
		else
			echo 'Worktree status: main checkout or detached metadata'
		fi
	else
		echo 'Git status: invalid repo'
	fi
}

ensure_tmux

if [[ $# -eq 0 || ${1:-} == '--help' || ${1:-} == '-h' ]]; then
	usage
	exit 0
fi

SUBCOMMAND=$1
shift

case "$SUBCOMMAND" in
open)
	SESSION=${1:-}
	[[ -n "$SESSION" ]] || die "Usage: cop open <session> [path] [--no-attach]"
	shift || true
	PATH_ARG=''
	ATTACH_AFTER=1
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--no-attach)
			ATTACH_AFTER=0
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			if [[ -z "$PATH_ARG" ]]; then
				PATH_ARG=$1
				shift
			else
				die "Unknown argument: $1"
			fi
			;;
		esac
	done
	open_session "$SESSION" "$PATH_ARG" "$ATTACH_AFTER"
	;;
attach)
	SESSION=${1:-}
	[[ -n "$SESSION" ]] || die "Usage: cop attach <session>"
	attach_session "$SESSION"
	;;
info)
	SESSION=${1:-}
	[[ -n "$SESSION" ]] || die "Usage: cop info <session>"
	info_session "$SESSION"
	;;
list)
	[[ $# -eq 0 ]] || die 'Usage: cop list'
	list_sessions
	;;
doctor)
	SESSION=${1:-}
	[[ -n "$SESSION" ]] || die "Usage: cop doctor <session>"
	doctor_session "$SESSION"
	;;
*)
	usage >&2
	exit 1
	;;
esac
