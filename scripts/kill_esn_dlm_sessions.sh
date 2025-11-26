#!/usr/bin/env bash
# Kill all tmux sessions whose name starts with "esn_dlm_"

# Get matching session names
sessions=$(tmux ls -F '#S' 2>/dev/null | grep '^esn_dlm_' || true)

if [ -z "$sessions" ]; then
  echo "No tmux sessions found starting with 'esn_dlm_'."
  exit 0
fi

echo "Killing the following tmux sessions:"
printf '%s\n' "$sessions"

# Kill each session
for s in $sessions; do
  tmux kill-session -t "$s"
done

echo "Done."


