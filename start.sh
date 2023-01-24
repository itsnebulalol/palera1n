#!/usr/bin/env bash
export LC_CTYPE="en_US.UTF-8"
MODE=$( gum table < gum/modes.csv -w 24,14 --height="15" --cell.border="rounded" | cut -d ',' -f 1)
IOS=$(gum input --placeholder 'optional' --prompt.foreground "212" --prompt "Whats your iOS version? > ")
echo 'Other flags?'
FLAGS=$(gum choose --no-limit < gum/flags.md)
SHORT_FLAGS=$(echo $FLAGS | cut -d ' ' -f2 | tr -d '()')
./palera1n.sh $IOS $MODE $SHORT_FLAGS
