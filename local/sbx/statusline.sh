#!/bin/bash
# Claude Code status line: model | dir branch ✓, with used/window $cost anchored right
input=$(cat)
g() { printf '%s' "$input" | jq -r "$1" 2>/dev/null; }

# Columns Claude Code keeps free at the right edge of the status line
right_margin=4

model=$(g '.model.display_name // ""')
cwd=$(g '.workspace.current_dir // .cwd // ""')
used=$(g '.context_window.total_input_tokens // 0')
size=$(g '.context_window.context_window_size // 0')
cost=$(g '.cost.total_cost_usd // 0')

esc=$'\033'
reset="${esc}[0m"
dim="${esc}[2m"
red="${esc}[31m"
green="${esc}[32m"
yellow="${esc}[33m"
blue="${esc}[34m"
magenta="${esc}[35m"
cyan="${esc}[36m"
sep=" ${dim}|${reset} "

case "$cwd" in
  "$HOME"*) dir="~${cwd#"$HOME"}" ;;
  *) dir="$cwd" ;;
esac

out="${cyan}${model}${reset}${sep}${blue}${dir}${reset}"
# Visible width of out, without the colour codes
left_len=$((${#model} + 3 + ${#dir}))

if [ -n "$cwd" ] && git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null ||
    git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
    mark="${red}✗${reset}"
  else
    mark="${green}✓${reset}"
  fi
  out="${out} ${magenta}${branch}${reset} ${mark}"
  left_len=$((left_len + 1 + ${#branch} + 2))
fi

# Context colour follows how full the window is
right=$(awk -v u="${used:-0}" -v s="${size:-0}" -v c="${cost:-0}" \
  -v g="$green" -v y="$yellow" -v r="$red" -v reset="$reset" 'BEGIN {
    p = (s > 0) ? u / s : 0
    col = (p >= 0.8) ? r : (p >= 0.5) ? y : g
    printf "%s%6.1fk/%4dk%s %s%7s%s", col, u / 1000, s / 1000, reset, y, sprintf("$%.2f", c), reset
  }')

# Fill the gap so the right block ends at the window edge; fall back to a separator when it will not fit
right_len=21
gap=$((${COLUMNS:-0} - right_margin - left_len - right_len))
if [ "$gap" -ge 2 ]; then
  printf '%s%*s%s' "$out" "$gap" '' "$right"
else
  printf '%s%s%s' "$out" "$sep" "$right"
fi
