std = "luajit+love"

globals = {
  -- variables
  "pico8",
  "cartname",
  "__pico_resolution",
  "currentDirectory",

  -- functions
  "warning",
  "log",
  "setColor",
}

ignore = {
}

exclude_files = {
  "lib",
  "spec",
}
