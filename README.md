PICOLOVE
--------

Implementation of PICO8 API for LOVE

On github at: https://github.com/picolove/picolove

Requires Love 0.9.x

What it is:

 * An implementation of pico-8's api in love

What is Pico-8:

 * See http://www.lexaloffle.com/pico-8.php

What is Love:

 * See https://love2d.org/

Why:

 * For a fun challenge!
 * Allow standalone publishing of pico-8 games on other platforms
  * should work on mobile devices
 * Configurable controls
 * Extendable
 * No arbitrary cpu or memory limitations
 * No arbitrary code size limitations
 * Betting debugging tools available
 * Open source

What it isn't:

 * A replacement for Pico-8
 * A perfect replica
 * No dev tools, no image editor, map editor, sfx editor, music editor
 * No modifying or saving carts
 * Not memory compatible with pico-8

Not Yet Implemented:

 * Memory modification/reading

Differences:

 * Uses floating point numbers not fixed point
 * sqrt doesn't freeze
 * Uses luajit not lua 5.2

Extra features:

 * `ipairs()`, `pairs()` standard lua functions
 * `log(...)` function prints to console for debugging
 * `assert(expr,message)` if expr is not true then errors with message
 * `error(message)` bluescreens with an error message
 * `warning(message)` prints warning and stacktrace to console
 * `setfps(fps)` changes the consoles framerate
 * `_keyup`, `_keydown`, `_textinput` allow using direct keyboard input
