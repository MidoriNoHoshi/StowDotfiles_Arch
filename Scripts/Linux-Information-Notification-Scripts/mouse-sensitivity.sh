#!/bin/bash

currentSense=$(hyprctl getoption input:sensitivity | awk 'NR==1{print $2}')
addition=0.1
maxSense=1.0
minSense=-1.0

# btw, not for self. $1 is the first argument passed onto the script.
if [ "$1" == "up" ]; then
  newSense=$(echo "scale=2; $currentSense + $addition" | bc)
elif [ "$1" == "down" ]; then
  newSense=$(echo "scale=2; $currentSense - $addition" | bc)
else
  exit 1
fi

if (( $(echo "$newSense > $maxSense" | bc -l) )); then
  finalSense=$maxSense
elif (( $(echo "$newSense < $minSense" | bc -l) )); then
  finalSense=$minSense
else
  finalSense=$newSense
fi


linearScaling=$(echo "scale=3; ($finalSense + 1) / 2" | bc)
percentex=$(echo "scale=1; 100 * $linearScaling" | bc | sed 's/\(\.[0-9]*[1-9]\)0*$/\1/; s/\.0*$//; s/\.$//')
# Using some fuckwit regex that only an AI model like Gemini or ChatGPT could write. What the actual fuck.
hyprctl keyword input:sensitivity $finalSense
dunstify -h string:x-dunst-stack-tag:mouse_sensitivity -h int:value:"$percentex" -- " 󰇀 $percentex"
exit 0
