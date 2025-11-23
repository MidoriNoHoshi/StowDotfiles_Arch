#!/usr/bin/env bash

volume=$(wpctl get-volume @DEFAULT_SINK@)

volumeFloat=$(echo "$volume" | awk '{print $2}' | sed 's/\[MUTED]//')

volumePercent=$(printf "%.0f" "$(echo "$volumeFloat * 100" | bc)")

audio_source=$(pactl info | grep -oP "Default Sink: alsa_output\.\K.*(?=\.[^.])") # Explaining the Regex bullshit:
# grep -oP. o (print only the part that matches the pattern). P (use Perl Compatible Regular Expressions, basically enable regex)
# \K (Forget everything up to now, chopping off "Default Sink: alsa_output.")
# .* (this is the "main match". The "." includes any character expect for a newline. The "*" quantifier means "zero or more occurances." It tries to match the longest possible string given by the constraints of the next terms (the lookahead))
# (?=) (Positive lookahead. Asserts a condition that must be met by the main match (.*). Does not include any of the matched text by the lookahead in the output)
# \. (Within the lookahead, so (?=\.). So looks for the first . character it encounters from the main match)
# [] (Defines a character set.)
# ^. (Inside of [], so [^.]. ^ means "NOT" whatever the next character\s is or are.)
# So further explaining the lookahead. The positive lookahead checks the condition \.[^.]+ against the text in the main match.
# If the greedy match stops at the end of the line (as this one does), the lookahead fails, and so backtracks (shrinking the greedy match) until the condition is met. The condition being set by \. (the backslash turns the . into a . and not a term that would mean "everything except for whitespace")

isMuted=""
icon=" "

if echo "$volume" | grep -q '\[MUTED\]'; then
  isMuted=" (Muted)"
  icon="󰕿"
fi

if [ "$volumePercent" -ge 60 ]; then
  icon="󰕾"
elif [ "$volumePercent" -ge 20 ]; then
  icon="󰖀"
fi

if echo "$volume" | grep -q '\[MUTED\]'; then
  isMuted=" (Muted)"
  icon="󰝟 "
fi

# --- Send the dunstify notification with the progress bar ---

dunstify -h string:x-dunst-stack-tag:volumePercent -h int:value:"$volumePercent" "$icon Volume: ${volumePercent}%${isMuted}" "$audio_source"
exit 0
