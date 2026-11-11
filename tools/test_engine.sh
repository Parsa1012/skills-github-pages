#!/bin/sh
set -eu
classes="$(mktemp -d)"
trap 'rm -rf "$classes"' EXIT
src=mirror/src/main/java/io/github/parsa1012/mirrordash
javac -d "$classes" tools/tests/android/graphics/Color.java tools/tests/android/content/Context.java tools/tests/android/content/SharedPreferences.java tools/tests/io/github/parsa1012/mirrordash/R.java \
  "$src"/Theme.java "$src"/Difficulty.java "$src"/LevelConfig.java "$src"/Player.java \
  "$src"/ObstacleRow.java "$src"/GameEngine.java "$src"/Lang.java "$src"/Progress.java "$src"/GamePrefs.java \
  tools/tests/io/github/parsa1012/mirrordash/GameEngineFairnessTest.java tools/tests/io/github/parsa1012/mirrordash/ProgressTest.java tools/tests/io/github/parsa1012/mirrordash/ModesTest.java
java -cp "$classes" io.github.parsa1012.mirrordash.GameEngineFairnessTest
java -cp "$classes" io.github.parsa1012.mirrordash.ProgressTest
java -cp "$classes" io.github.parsa1012.mirrordash.ModesTest
