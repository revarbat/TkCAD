if {[file exists main.tcl]} {
    source lib/profile.tcl
}
set ::tk::mac::useCustomMDEF 1


proc main {} {
    global argv0 env
    global tcl_version
    global tcl_precision
    global tcl_platform
    global tkcad_version
    global tkcad_images_dir
    global tkcad_plugins_dir
    global tkcad_plugin_root
    global tkcad_prefs_dir

    set tkcad_version 0.228
    set tcl_precision 16

    if {[catch {tk windowingsystem} winsys]} {
        if {$tcl_platform(os) == "Darwin"} {
            set winsys "aqua"
        } elseif {$tcl_platform(platform) == "windows"} {
            set winsys "win32"
        } elseif {$tcl_platform(platform) == "macintosh"} {
            set winsys "classic"
        } else {
            set winsys "x11"
        }
    }
    set tcl_platform(winsys) $winsys

    if {$winsys == "aqua"} {
        if {$tcl_version >= 8.6} {
            #option add *.background systemDialogBackgroundActive widgetDefault
            #option add *.highlightBackground systemDialogBackgroundActive widgetDefault
            option add *data.padX 24 startupFile
        }
    }

    # Img allows loading of jpegs, pngs, etc.
    # tkpath provides smoother bezier drawing and better rotated text.
    # MacCarbonPrint provides printing facilities. (OSX)
    # enhimgcopy rescales and rotates images smoothly, for printing.
    # fontdata gets the shape of text, for conversion to beziers. (OSX)
    # mlcnc_critcl provides some fast geometry calculation routines.
    foreach pkg {
        math::constants
        math::geometry
        opt
        tooltip

        Img
        MacCarbonPrint

        enhimgcpy
        mlcnc_critcl
        fontdata
        tkpath
    } {
        #Hall of shame of crashing extensions:
        #    tkpath
        if {[catch {package require $pkg} err]} {
            puts stderr "Could not load $pkg extensions"
        }
    }
    namespace import ::math::constants::*
    namespace import ::tcl::mathop::*
    #namespace import ::tcl::mathfunc::*
    if {[namespace exists ::tkp]} {
        global ::tkp::antialias
        set ::tkp::antialias 1
        global ::tkp::depixelize
        set ::tkp::depixelize 0
    }

    global root_dir
    if {[file exists main.tcl]} {
        set root_dir [pwd]
    }
    set root $root_dir

    set plugdir [file join $root "plugins"]
    set tkcad_plugins_dir $plugdir
    set tkcad_images_dir [file join $root images]
    if {$tcl_platform(os) == "Darwin"} {
        # The "correct" place for preferences files on the mac (OS X)
        # is in ~/Library/Preferences folder
        set tkcad_prefs_dir [file join $env(HOME) Library Preferences]
    } elseif {$tcl_platform(platform) == "macintosh"} {
        # The "correct" place for preferences files on the mac (OS 9)
        # is in the preferences folder
        set tkcad_prefs_dir $env(PREF_FOLDER)
    } elseif {[info exists env(HOME)]} {
        set tkcad_prefs_dir $env(HOME)
        if {$tcl_platform(platform) == "windows"} {
            if {![file exists $tkcad_prefs_dir]} {
                set tkcad_prefs_dir $treb_root_dir
            }
        }
    } else {
        set tkcad_prefs_dir $treb_root_dir
    }


    set filelist {
        "prefs.tcl"
        "utils.tcl"
        "matrixmath.tcl"
        "geometry.tcl"
        "bezutils.tcl"
        "xmlutils.tcl"
        "printing.tcl"
        "cncfont.tcl"

        "tools.tcl"
        "layers.tcl"

        "cadselect.tcl"
        "cutpaste.tcl"
        "cadobjects.tcl"
        "confpane.tcl"
        "cadgcode.tcl"
        "rulers.tcl"

        "subwindows.tcl"
        "progwin.tcl"
        "infopanewin.tcl"
        "editpanewin.tcl"
        "toolwin.tcl"
        "layerwin.tcl"
        "snapswin.tcl"

        "fileformats.tcl"
        "mainmenu.tcl"
        "mainwin.tcl"

        "tools_transforms.tcl"
        "tools_lines.tcl"
        "tools_beziers.tcl"
        "tools_arcs.tcl"
        "tools_conics.tcl"
        "tools_circles.tcl"
        "tools_ellipses.tcl"
        "tools_screwholes.tcl"
        "tools_text.tcl"
        "tools_polygons.tcl"
        "tools_images.tcl"
        "tools_points.tcl"
        "tools_dimensions.tcl"
        "tools_duplicators.tcl"
        "tools_layout.tcl"

        "ffmt-native.tcl"
        "ffmt-svg.tcl"
        "ffmt-dxf.tcl"

        "mlcnc/mlcnc-mill.tcl"
        "mlcnc/mlcnc-stock.tcl"
        "mlcnc/mlcnc-tool.tcl"
        "mlcnc/mlcnc-calc.tcl"
        "mlcnc/mlcnc-excellon.tcl"
        "mlcnc/mlcnc-path.tcl"
        "mlcnc/mlcnc-gapi.tcl"
        "mlcnc/mlcnc-shortapi.tcl"
        "mlcnc/mlcnc-screws.tcl"

        "mlcnc/mlgui-misc.tcl"
        "mlcnc/mlgui-mill.tcl"
        "mlcnc/mlgui-stock.tcl"
        "mlcnc/mlgui-tool.tcl"

        "feedwiz.tcl"
    }
    foreach file $filelist {
        source [file join $root "lib" $file]
    }

    set wizards [glob -nocomplain [file join $root "lib" "wizards" "*.tcl"]]
    foreach file $wizards {
        source $file
    }

    set plugins {}
    if {[file isdirectory $plugdir]} {
        set plugins [glob -nocomplain [file join $plugdir "plugin_*.tcl"]]
    }
    foreach file $plugins {
        if {[file isdirectory $file]} {
            set tkcad_plugin_root $file
            source [file join $file "tkcadplugin.tcl"]
        } elseif {[file extension $file] == ".tcl"} {
            set tkcad_plugin_root $tkcad_plugins_dir
            source $file
        }
    }

    set cncfonts [glob -nocomplain [file join $root "cncfonts" "*.cncfont"]]
    foreach file $cncfonts {
        if {[catch {cncfont_load $file} err]} {
            puts stderr "Failed to load CNC Font $file"
        }
    }

    # Pre-render font names for font menu.
    set fams [font_families]
    text .foo -width 40 -height 1
    foreach fam $fams {
        .foo tag config $fam -font [list $fam 10]
        .foo insert 0.0 "$fam\n" $fam
    }
    destroy .foo

    prefs:init
    trace add variable [/prefs:getvar antialiasing] write "tkcad_update_antialiasing"
    prefs:load

    wm withdraw .
    mainmenu_nowin_create
    set mainwin [mainwin_create]
}



proc tkcad_update_antialiasing {args} {
    if {[namespace exists ::tkp]} {
        global ::tkp::antialias
        set ::tkp::antialias [/prefs:get antialiasing]
    }
}



rename exit tkcad_exit

proc exit {} {
    if {[catch {prefs:save} err]} {
        global errorInfo
        puts stderr $errorInfo
        tk_messageBox -type ok -message $errorInfo
    }
    mainwin_quit
}


proc tracelineenter {str op} {
    puts stderr "--> $str"
}

proc tracelineleave {str code result op} {
    puts stderr "<-- [lindex [info level -1] 0]"
}

if {[catch {main} err]} {
    global errorInfo
    tk_messageBox -type ok -icon error -message $errorInfo
}


#trace add execution confpane_populate enterstep tracelineenter
#trace add execution confpane_populate leavestep tracelineleave

# TODO: make dialogs for the setting below.
mlcnc_define_mill \
    -discretespeeds 1 \
    -rpmlist {1100 1900 2900 4300 6500 10500} \
    -fixedrpm 1 \
    -autotoolchanger 0 \
    -hp 0.167 \
    -maxfeed 15.0

mlcnc_define_stock 9 5.5 0.0625 -material "Aluminum"

mlcnc_define_tool  1 1/32 -flutes 2 -material Carbide
mlcnc_define_tool  2 1/32 -flutes 3 -material Carbide
mlcnc_define_tool  3 1/16 -flutes 2 -material Carbide
mlcnc_define_tool  4 1/16 -flutes 3 -material Carbide
mlcnc_define_tool  5 1/16 -flutes 4 -material Carbide
mlcnc_define_tool  6 1/16 -flutes 4 -material HSS
mlcnc_define_tool  7 1/8  -flutes 2 -material HSS
mlcnc_define_tool  8 1/8  -flutes 3 -material Carbide
mlcnc_define_tool  9 1/8  -flutes 4 -material Carbide
mlcnc_define_tool 10 3/16 -flutes 3 -material Carbide
mlcnc_define_tool 11 3/16 -flutes 4 -material Carbide
mlcnc_define_tool 12 1/4  -flutes 4 -material Carbide
mlcnc_define_tool 13 1/4  -flutes 4 -material HSS
mlcnc_define_tool 18 0.001 -flutes 4 -bevel 90 -material Carbide
mlcnc_define_tool 20 0.012 -flutes 1 -material HSS
mlcnc_define_tool 25 1.025 -flutes 23 -material HSS

# vim: set ts=4 sw=4 nowrap expandtab: settings

