std = "luajit+love"

globals = {
  -- variables
  "pico8",
  "__pico_resolution",
  "__picolove_version",
  "currentDirectory",
  "host_time",
  "scale",
  "xpadding",
  "ypadding",
  "love.graphics.point",
  "love.handlers",
  "love.graphics.newScreenshot",
  "love.graphics.isActive",

  -- functions
  "warning",
  "log",
  "setColor",
  "restore_clip",
  "patch_lua",
  "shdr_unpack",
  "restore_camera",
  "flip_screen",
  "_load",
  "new_sandbox",
}

ignore = {
}

exclude_files = {
  "lib",
  "spec",
  ".DS_Store",
}
