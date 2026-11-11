#!/bin/sh
set -eu
classes="$(mktemp -d)"
trap 'rm -rf "$classes"' EXIT
src=mirror/src/main/java/io/github/parsa1012/mirrordash
javac -d "$classes" tools/tests/android/graphics/Color.java tools/tests/io/github/parsa1012/mirrordash/R.java \
  "$src"/Theme.java "$src"/Difficulty.java "$src"/LevelConfig.java "$src"/Player.java \
  "$src"/ObstacleRow.java "$src"/GameEngine.java tools/tests/io/github/parsa1012/mirrordash/GameEngineFairnessTest.java
java -cp "$classes" io.github.parsa1012.mirrordash.GameEngineFairnessTest
