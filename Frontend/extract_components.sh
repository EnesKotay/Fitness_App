#!/bin/bash
TARGET="lib/features/workout/screens/workout_screen.dart"
COMPONENTS="lib/features/workout/screens/workout_screen_components.dart"

echo "part of 'workout_screen.dart';" > $COMPONENTS
echo "" >> $COMPONENTS

# Extract from line 2490 to end
tail -n +2490 $TARGET >> $COMPONENTS

# Truncate original file at line 2489
head -n 2489 $TARGET > temp.dart
mv temp.dart $TARGET
