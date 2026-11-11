#!/usr/bin/env python3
"""Cheap structural regressions for code-built overlays; complements, not replaces, device tests."""
from pathlib import Path
p = Path('mirror/src/main/java/io/github/parsa1012/mirrordash/GameActivity.java').read_text()
def body(start, end):
    return p[p.index(start):p.index(end, p.index(start))]
pause = body('private void buildPausePanel()', 'private SeekBar addPauseVolume')
assert 'panel.setVisibility(View.VISIBLE)' in pause
assert 'panel.setAlpha(1f)' in pause, 'card child must be opaque when its scroll wrapper is shown'
assert 'pausePanel = wrapper' in pause and 'wrapper.setVisibility(View.GONE)' in pause
assert 'hidePause()' in pause and 'startGame()' in pause and 'goToMenu()' in pause
assert 'addPauseVolume(panel, false)' in pause and 'addPauseVolume(panel, true)' in pause
show = body('private void showPause()', 'private void hidePause()')
assert 'gameView.pauseGame()' in show and 'panelIn(pausePanel)' in show
hide = body('private void hidePause()', 'private void showGameOver')
assert 'hideCard(pausePanel)' in hide and 'gameView.resumeGame()' in hide
menu = body('private void buildMenu()', 'private void addTool(')
assert menu.index('TextView appearance') < menu.index('TextView practice') < menu.index('TextView settings')
print('Pause overlay and menu structural checks PASS (device UI test still required)')
