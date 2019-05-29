std = "luajit+love"

globals = {
  -- variables
  "pico8",
  "cartname",
  "__pico_resolution",
  "currentDirectory",
  "host_time",
  "scale",
  "xpadding",
  "ypadding",
  "loaded_code",

  -- functions
  "warning",
  "log",
  "setColor",
  "restore_clip",
  "patch_lua",
  "shdr_unpack",
  "restore_camera",
}

ignore = {
}

exclude_files = {
  "lib",
  "spec",
}
