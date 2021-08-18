PICOLOVE
--------

Run PICO-8 games and computer programs with free and open-source software.

On github at: https://github.com/picolove/picolove

Requires LÖVE 0.10.2

What it is:

 * An implementation of PICO-8's API in LÖVE

What is PICO-8:

 * See http://www.lexaloffle.com/pico-8.php

What is LÖVE:

 * See https://love2d.org/

Why:

 * For a fun challenge!
 * Allow standalone publishing of PICO-8 games on other platforms
  * Should work on mobile devices [*](#android-packaging)
 * Configurable controls
 * Extendable
 * No arbitrary cpu or memory limitations
 * No arbitrary code size limitations
 * Better debugging tools available
 * Free and open-source software

What it isn't:

 * A replacement for PICO-8
 * A perfect replica
 * No dev tools, no image editor, map editor, sfx editor, music editor
 * No modifying or saving carts
 * Not memory compatible with PICO-8

Not Yet Implemented:

 * Memory modification/reading
 * PICO-8 cartridge versions > 8

Differences:

 * Uses floating point numbers not fixed point
 * sqrt doesn't freeze
 * Uses LuaJIT not lua 5.2

Extra features:

 * `ipairs()` standard lua function
 * `log(...)` function prints to console for debugging
 * `error(message)` bluescreens with an error message
 * `warning(message)` prints warning and stacktrace to console
 * `setfps(fps)` changes the consoles framerate
 * `_keyup`, `_keydown`, `_textinput` allow using direct keyboard input
 * `_touchup`, `_touchdown` allow using touch input
 * `_getcursorx()`, `_getcursory()` allow access to the cursor position
 * `_getpicoloveversion()` returns the version of picolove

Android Packaging:

Replace the default cartridge (nocart.p8) with your game. Text (P8) or PNG (P8.PNG) is supported.  
Follow the [Android Game Packaging](https://bitbucket.org/MartinFelis/love-android-sdl2/wiki/Game_Packaging) steps.  
Optionally, for orientation rotation support (Portrait and Landscape), remove ```android:screenOrientation="landscape"``` in the AndroidManifest.xml
