#!/bin/bash
adb shell settings put secure back_gesture_inset_scale_left 0.5
adb shell settings put secure back_gesture_inset_scale_right -1

echo "Gesture tweaks applied!"

# adb shell settings put secure back_gesture_inset_scale_left 0.5
# adb shell settings put secure back_gesture_inset_scale_right -1

