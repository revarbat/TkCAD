global argv0
global env
set root_dir [file join [file dirname $argv0] tkCAD]
set env(ROOT_DIR) $root_dir
source [file join $root_dir main.tcl]

