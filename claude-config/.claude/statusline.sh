#!/usr/bin/env bash
# Claude Code status line script
# Receives JSON via stdin with session context

input=$(cat)

# --- Extract fields from JSON ---
model=$(echo "$input" | jq -r '.model.display_name // "Unknown Model"')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "."')

# Abbreviate home directory
display_dir="${current_dir/#$HOME/\~}"

# --- ANSI colors ---
RESET=$'\033[0m'
BOLD=$'\033[1m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
CYAN=$'\033[36m'
DIM=$'\033[2m'

# --- Git info with 5-second cache ---
git_info=""
if git -C "$current_dir" rev-parse --git-dir >/dev/null 2>&1; then
  # Build a cache key from the directory path
  cache_key=$(printf '%s' "$current_dir" | cksum | awk '{print $1}')
  cache_file="/tmp/claude_sl_git_${cache_key}"

  # Check if cache exists and is fresh (modified within last 5 seconds)
  if [ -f "$cache_file" ] && [ -n "$(find "$cache_file" -newermt "$(date -v-5S '+%Y-%m-%d %H:%M:%S')" 2>/dev/null)" ]; then
    cached=$(cat "$cache_file")
  else
    branch=$(git -C "$current_dir" symbolic-ref --short HEAD 2>/dev/null \
             || git -C "$current_dir" rev-parse --short HEAD 2>/dev/null \
             || echo "detached")
    staged=$(git -C "$current_dir" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    modified=$(git -C "$current_dir" diff --name-only 2>/dev/null | wc -l | tr -d ' ')
    cached="${branch}|${staged}|${modified}"
    printf '%s' "$cached" > "$cache_file"
  fi

  IFS='|' read -r branch staged modified <<< "$cached"

  # Build git segment
  git_segment="${CYAN}${branch}${RESET}"
  if [ "$staged" -gt 0 ] 2>/dev/null; then
    git_segment="${git_segment} ${GREEN}+${staged}${RESET}"
  fi
  if [ "$modified" -gt 0 ] 2>/dev/null; then
    git_segment="${git_segment} ${YELLOW}~${modified}${RESET}"
  fi

  git_info=" | 🌿 ${git_segment}"
fi

# --- Line 1: Model, directory, git ---
printf "${DIM}[%s]${RESET} 📁 %s%s\n" "$model" "$display_dir" "$git_info"

# --- Line 2: Context window progress bar ---
BAR_WIDTH=20

if [ -z "$used_pct" ]; then
  printf "${DIM}[--------------------] no context data${RESET}\n"
else
  # Round to integer
  pct=$(printf '%.0f' "$used_pct")

  # Choose bar color by threshold
  if [ "$pct" -ge 90 ]; then
    bar_color="$RED"
  elif [ "$pct" -ge 70 ]; then
    bar_color="$YELLOW"
  else
    bar_color="$GREEN"
  fi

  # Calculate filled and empty segments
  filled=$(( pct * BAR_WIDTH / 100 ))
  [ "$filled" -gt "$BAR_WIDTH" ] && filled=$BAR_WIDTH
  empty=$(( BAR_WIDTH - filled ))

  bar_filled=$(printf '%0.s#' $(seq 1 $filled) 2>/dev/null || python3 -c "print('#' * $filled, end='')")
  bar_empty=$(printf '%0.s-' $(seq 1 $empty) 2>/dev/null || python3 -c "print('-' * $empty, end='')")

  printf "${DIM}[${RESET}${bar_color}%s${RESET}${DIM}%s]${RESET} %s%%\n" \
    "$bar_filled" "$bar_empty" "$pct"
fi
