#################################
# Preferences Dialog
#

global tkcad_prefs_list

# This list specifies all preferences options that are available to TkCAD.
# The Preferences dialog will list all these controls in the order given here,
#  under the notebook tab specified here.  NOTE: A null tabname means that that
#  preference is internal only, and it won't show up in the Preferences dialog.
#  A tabname of "-" is internal only, won't be shown in the prefs dialog, won't
#  be listed in a /prefs:list, and won't be saved to disk.  If a preference
#  name starts with win_ or unix_ or mac_, then it will only be shown in dia-
#  logs on the apropriate platform.

# For OSes, W = Windows, U = Unix, M = MacOS 9, D = Darwin/OS X, - = All
# type name             val min   max tabname  OSes caption
set tkcad_prefs_list {
  combo ruler_units "Inches (Fractions)" {"Inches (Decimal)" "Inches (Fractions)" Feet Millimeters Centimeters Meters} 20 Display  -  "Default Units"
  bool  antialiasing       1   0     1 Display  -  "Enable antialiasing"
  bool  show_direction     1   0     1 Display  -  "Show line direction when editing nodes."
  bool  hide_splash        0   0     1 Display  -  "Don't display splash screen at startup"
  str   recent_files      ""   0     0 ""	-  "Files recently opened."
  bool  show_grid          1   0     1 ""       -  "Show Grid"
  bool  show_origin        1   0     1 ""       -  "Show Origin"
  str   laser_kerf     0.007   0  0.05 ""       -  "Laser Kerf"
}



proc prefs:init {} {
    global tkcad_prefs_list tcl_platform tkcad_prefs_dir tkcad_save_file tkcad_preferences
    foreach {type name val min max tab oses caption} $tkcad_prefs_list {
        prefs:add $type $name $val $min $max $tab $oses $caption
    }
    switch -glob -- $tcl_platform(os) {
        Win* {
            find_windows_prefsfile
        }
        Darwin* -
        Mac* {
            set tkcad_save_file [file join $tkcad_prefs_dir "TkCAD Settings"]
        }
        default {
            set tkcad_save_file [file join $tkcad_prefs_dir ".tkcadrc"]
        }
    }

    # TODO: The following should really be handled with a callback.
    trace add variable [/prefs:getvar ruler_units] write "prefs_redraw_all_windows"
    trace add variable [/prefs:getvar show_origin] write "prefs_redraw_all_windows"
    trace add variable [/prefs:getvar show_grid]   write "prefs_redraw_all_windows"
}



proc prefs_redraw_all_windows {args} {
    mainwin_redraw
}



proc prefs:add {type name val min max tab oses caption} {
    upvar #0 tkcad_preferences var
    if {![info exists var(namelist)]} {
        set var(namelist) {}
    }
    if {![info exists var(tablist)]} {
        set var(tablist) {}
    }
    if {![info exists var(tabitems,$tab)]} {
        set var(tabitems,$tab) {}
    }
    if {[lsearch -exact $var(namelist) $name] == -1} {
        lappend var(namelist) $name
    }
    if {[lsearch -exact $var(tablist) $tab] == -1} {
        lappend var(tablist) $tab
    }
    if {[lsearch -exact $var(tabitems,$tab) $name] == -1} {
        lappend var(tabitems,$tab) $name
    }
    set var(type,$name)    $type
    set var(value,$name)   $val
    set var(min,$name)     $min
    set var(max,$name)     $max
    set var(tab,$name)     $tab
    set var(oses,$name)    $oses
    set var(caption,$name) $caption
}



proc /prefs:exists {name} {
    upvar #0 tkcad_preferences var
    if {[info exists var(value,$name)]} {
        return 1;
    }
    return 0;
}



proc /prefs:get {name} {
    upvar #0 tkcad_preferences var
    if {![/prefs:exists $name]} {
        error "No such preference exists: '$name'"
    } else {
        return $var(value,$name)
    }
}



proc /prefs:getvar {name} {
    if {![/prefs:exists $name]} {
        error "No such preference exists: '$name'"
    } else {
        return "tkcad_preferences(value,$name)"
    }
}



proc /prefs:set {name val} {
    upvar #0 tkcad_preferences var
    global dirty_preferences
    if {![/prefs:exists $name]} {
        tk_messageBox -type ok -icon warning -title "Bad preference" -message "$name : Obsolete or non-existent preference setting. Ignored."
        set dirty_preferences 1
    } else {
        if {$var(type,$name) == "cust"} {
            return
        }
        set var(value,$name) $val
        if {$var(tab,$name) != "-"} {
            set dirty_preferences 1
        }
    }
    return
}



proc /prefs:list {{pattern *}} {
    upvar #0 tkcad_preferences var
    set oot {}

    foreach name $var(namelist) {
        if {$name != "" &&
            $var(tab,$name) != "-" &&
            $var(type,$name) != "cust"
        } {
            if {$oot != ""} {
                append oot "\n"
            }
            append oot "/prefs:set [list $name] [list [/prefs:get $name]]"
        }
    }
    return $oot
}



proc find_windows_prefsfile {} {
    global tkcad_prefs_dir root_dir tkcad_save_file

    set tkcad_save_file {}
    package require registry 1.0
    set key "HKEY_CURRENT_USER\\Software\\Fuzzball Software\\TkCAD\\1.0"
    if {![catch {registry get $key "prefsfile"} file]} {
        if {[file isfile $file]} {
            if {[file readable $file]} {
                set tkcad_save_file $file
                return ""
            } else {
                tk_messageBox -type "ok" -title "Preferences File Unreadable" \
                    -message "The file '$file' isn't readable.  Please specify a different file, or fix the permissions."
            }
        }
    } else {
        # No registry entry.  Probably first time run on this machine.
        return ""
    }

    # Prefs file was moved or is now unreadable.
    set filetypes {
        {{TkCAD Preferences Files}       {.tkp}    TEXT}
    }
    set initdir $tkcad_prefs_dir
    set initfile "TkCAD_Prefs.tkp"
    if {$file != "" && [file isfile $file]} {
        set initdir [file dirname $file]
        set initfile [file tail $file]
    } elseif {[file isfile [file join $root_dir "TkCAD_Prefs.tkp"]]} {
        set initdir $root_dir
    }
    while (1) {
        set dofind [tk_messageBox -title {TkCAD Preferences File} \
                        -message "Unable to open TkCAD's preferences file.  Would you like to specify its location?" \
                        -type yesno -icon warning -default "no"]

        if {$dofind == "no"} {
            catch {registry delete $key "prefsfile"}
            set tkcad_save_file {}
            return ""
        }

        set tkcad_save_file [tk_getOpenFile -defaultextension .tkp \
                                -initialdir $initdir \
                                -initialfile "TkCAD_Prefs.tkp" \
                                -title {Specify TkCAD Preferences File} \
                                -filetypes $filetypes]

        if {$tkcad_save_file != ""} {
            set dir [file dirname $tkcad_save_file]
            if {![file isdirectory $dir]} {
                tk_messageBox -type "ok" -title "Preferences File Unwritable" \
                    -message "The directory '$dir' does not exist."
            } elseif {![file writable $dir]} {
                tk_messageBox -type "ok" -title "Preferences File Unwritable" \
                    -message "You do not have permission to write to the directory '$dir'.  You will need to save your prefs to a different directory or, fix the directory permissions."
            } elseif {![file readable $tkcad_save_file]} {
                tk_messageBox -type "ok" -title "Preferences File Unreadable" \
                    -message "The file '$file' isn't readable.  Please specify a different file, or fix the permissions."
            } elseif {![file writable $tkcad_save_file]} {
                tk_messageBox -type "ok" -title "Preferences File Unwritable" \
                    -message "You do not have permission to write to the file '$file'.  You will need to save your prefs to a different file, later, or fix the file permissions."
            } else {
                registry set $key "prefsfile" $tkcad_save_file
                return ""
            }
        }
    }
}



proc prefs:load {{file ""}} {
    global tkcad_save_file
    if {$file == ""} {
        set file $tkcad_save_file
    }
    catch {
        source $file
    }
}



tcl::OptProc prefs:save {
    {-request      "If given, pop up a GUI dialog to choose the file to save to."}
    {-all          "If given, save all data types."}
    {-configs      "If given, save general configuration data."}
    {?file?    {}  "The file to save the prefs in."}
} {
    global tkcad_save_file tcl_platform tkcad_prefs_dir root_dir env
    if {!$configs} {
        set all 1
    }
    if {$all} {
        set configs  1
    }
    if {$request} {
        set filetypes {
            {{TkCAD Config Files} {.tkp}    TEXT}
            {{Text Files}         {.txt}    TEXT}
            {{All Files}          *             }
        }
        set defaultfile "Defaults"
        set defaultext "tkcadrc"
        set file [tk_getSaveFile -defaultextension .$defaultext \
                    -initialfile $defaultfile.$defaultext \
                    -title {Export configuration to file} \
                    -filetypes $filetypes]
        if {$file == ""} {
            return ""
        }
    }
    set store_in_reg 0
    set key "HKEY_CURRENT_USER\\Software\\Fuzzball Software\\TkCAD\\1.0"
    if {$file == {}} {
        if {$tcl_platform(platform) == "windows"} {
            package require registry 1.0
            if {[catch {registry get $key "prefsfile"} file]} {
                set file $tkcad_save_file
            }
        } else {
            set file $tkcad_save_file
        }
        while {1} {
            if {$file == ""} {
                set initdir $tkcad_prefs_dir
                if {[info exists env(HOME)]} {
                    set initdir $env(HOME)
                } elseif {$tcl_platform(platform) == "windows"} {
                    if {[file isdirectory "C:\\My Documents"]} {
                        set initdir "C:\\My Documents"
                    } else {
                        set initdir $root_dir
                    }
                } else {
                    set initdir $root_dir
                }
                set file "${initdir}\\TkCAD_Prefs.tkp"
                set dir [file dirname $file]
            } else {
                set dir [file dirname $file]
                if {![file isdirectory $dir]} {
                    tk_messageBox -type "ok" -title "Preferences File Unwritable" \
                        -message "The directory '$dir' does not exist."
                } elseif {![file writable $dir]} {
                    tk_messageBox -type "ok" -title "Preferences File Unwritable" \
                        -message "You do not have permission to write to the directory '$dir'.  You will need to save your prefs to a different directory or, fix the directory permissions."
                } elseif {[file exists $file] && ![file writable $file]} {
                    tk_messageBox -type "ok" -title "Preferences File Unwritable" \
                        -message "You do not have permission to write to the file '$file'.  You will need to save your prefs to a different file, or fix the file permissions."
                } else {
                    set tkcad_save_file $file
                    break
                }
            }
            set file [tk_getSaveFile -defaultextension .tkp -initialdir $dir \
                        -title "Save preferences as" \
                        -filetypes {{{TkCAD Preference Files} {.tkp} }} \
                        -initialfile "TkCAD_Prefs.tkp"]
            if {$file == ""} {
                return ""
            }
            
            set store_in_reg 1
        }
    }
    if {[catch {set f [open $file.tmp w 0600]} errMsg]} {
        error "prefs:save: $errMsg"
        return ""
    }
    set errval [catch {
        if {$file == $tkcad_save_file} {
            puts $f "# Automatically generated on [clock format [clock seconds]]."
            puts $f "# Do not make changes to this file, they will be lost."
        }

        #if {$configs && [/prefs:get save_position]} {
        #    puts $f "# Window geometry follows."
        #    puts $f "/geometry:set [/geometry:get]\n"
        #    flush $f
        #}

        if {$configs} {
            puts $f "# Misc. preference settings follow."
            puts $f "[/prefs:list]\n"
            flush $f
        }
    } errMsg]

    flush $f
    close $f

    if {$errval} {
        file delete -force -- $file.tmp
        error "prefs:save: $errMsg"
        return ""
    } else {
        file rename -force -- $file.tmp $file
        if {$store_in_reg} {
            registry set $key "prefsfile" $tkcad_save_file
        }
    }
    global dirty_preferences
    set dirty_preferences 0
    #/statbar 5 "Preferences saved!"
    return ""
}



proc prefs:mkpage {w page} {
    upvar #0 tkcad_preferences var
    global TkCADPrefs
    global tcl_platform

    set master [winfo parent [winfo parent $w]]
    grid columnconfig $w  0 -minsize 25
    grid columnconfig $w 99 -minsize 25 -weight 1
    grid rowconfig $w  0 -minsize 25
    grid rowconfig $w 99 -minsize 25 -weight 1

    set row 1
    set prevspacing {}
    set spacing 25
    set quantum 30

    foreach name $var(tabitems,$page) {
        set TkCADPrefs($master,$name) $var(value,$name)
        set prevspacing $spacing
        set oses $var(oses,$name)

        if {$oses != "-"} {
            switch -exact $tcl_platform(platform) {
                unix {
                    if {$tcl_platform(os) == "Darwin"} {
                        if {[string first "D" $oses] == -1} {
                            continue
                        }
                    } else {
                        if {[string first "U" $oses] == -1} {
                            continue
                        }
                    }
                }
                windows {
                    if {[string first "W" $oses] == -1} {
                        continue
                    }
                }
                mac {
                    if {[string first "M" $oses] == -1} {
                        continue
                    }
                }
                Darwin {
                    if {[string first "D" $oses] == -1} {
                        continue
                    }
                }
            }
        }

        switch -exact $var(type,$name) {
            cust {
                set cmd $var(value,$name)
                append cmd " "
                append cmd $w.$name
                eval $cmd
                set spacing 0
            }
            bool {
                checkbutton $w.$name \
                        -text $var(caption,$name) \
                        -variable TkCADPrefs($master,$name) \
                        -command "prefs:dirty $master" \
                        -offvalue $var(min,$name) \
                        -onvalue $var(max,$name)
                set spacing 5
            }
            int {
                set width [string length $var(min,$name)]
                if {$width < [string length $var(max,$name)]} {
                    set width [string length $var(max,$name)]
                }
                frame $w.$name -relief flat -borderwidth 0
                label $w.$name.l -text $var(caption,$name) \
                        -relief flat -borderwidth 0 -anchor w
                spinner $w.$name.s \
                        -variable TkCADPrefs($master,$name) \
                        -value $TkCADPrefs($master,$name) \
                        -command "prefs:dirty $master" \
                        -min $var(min,$name) -max $var(max,$name) \
                        -width $width

                set font [$w.$name.l cget -font]
                set width [font measure $font $var(caption,$name)]
                set width [expr {$quantum * (1 + int(($width+5) / $quantum))}]

                grid columnconfig $w.$name 0 -weight 0 -minsize $width
                grid columnconfig $w.$name 1 -weight 1
                grid $w.$name.l -row 0 -column 0 -sticky w
                grid $w.$name.s -row 0 -column 1 -sticky ew
                set spacing 0
            }
            str {
                frame $w.$name -relief flat -borderwidth 0
                label $w.$name.l -text $var(caption,$name) \
                        -relief flat -borderwidth 0 -anchor w
                entry $w.$name.e \
                        -width $var(max,$name) \
                        -textvariable TkCADPrefs($master,$name)
                bind $w.$name.e <Key> "+prefs:dirty $master"

                set font [$w.$name.l cget -font]
                set width [font measure $font $var(caption,$name)]
                set width [expr {$quantum * (1 + int(($width+5) / $quantum))}]

                grid columnconfig $w.$name 0 -weight 0 -minsize $width
                grid columnconfig $w.$name 1 -weight 1
                grid $w.$name.l -row 0 -column 0 -sticky w
                grid $w.$name.e -row 0 -column 1 -sticky ew
                set spacing 0
            }
	    combo {
                set width [string length $var(min,$name)]
                if {$width < [string length $var(max,$name)]} {
                    set width [string length $var(max,$name)]
                }
                frame $w.$name -relief flat -borderwidth 0
                label $w.$name.l -text $var(caption,$name) \
                        -relief flat -borderwidth 0 -anchor w
                ttk::combobox $w.$name.e \
			-state readonly \
                        -width $var(max,$name) \
			-values $var(min,$name) \
                        -textvariable TkCADPrefs($master,$name)
                bind $w.$name.e <Key> "+prefs:dirty $master"
                bind $w.$name.e <<ComboboxSelected>> "+prefs:dirty $master"

                set font [$w.$name.l cget -font]
                set width [font measure $font $var(caption,$name)]
                set width [expr {$quantum * (1 + int(($width+5) / $quantum))}]

                grid columnconfig $w.$name 0 -weight 0 -minsize $width
                grid columnconfig $w.$name 1 -weight 1
                grid $w.$name.l -row 0 -column 0 -sticky w
                grid $w.$name.e -row 0 -column 1 -sticky ew
                set spacing 0
	    }
            multi {
                # TODO: Provide for multi-line text editor.
                button $w.$name -text $var(caption,$name) -command "
                    /textdlog -modal -buttons -width 60 -height 12 -nowrap \
                        -autoindent -title [list $var(caption,$name)] \
                        -text \$TkCADPrefs($master,$name) \
                        -variable TkCADPrefs($master,$name)
                    prefs:dirty $master
                "
                set spacing 0
            }
            default {
                error "Bad preference value type.  Must be 'bool', 'int', 'str' or 'multi'."
            }
        }
        grid $w.$name -column 1 -row $row -sticky w
        set divspace [expr {15 - $spacing - $prevspacing}]
        if {$divspace < 0} {
            set divspace 0
        }
        if {$row > 1} {
            grid rowconfig $w [expr {$row - 1}] -minsize $divspace
        }
        incr row 2
    }
}



proc prefs:apply {w} {
    global TkCADPrefs
    upvar #0 tkcad_preferences var
    foreach name $var(namelist) {
        if {$var(tab,$name) != {} && $var(tab,$name) != "-"} {
            /prefs:set $name $TkCADPrefs($w,$name)
        }
    }

    if {[$w.apply cget -state] != "disabled"} {
        global dirty_preferences; set dirty_preferences 1
        $w.apply config -state disabled
    }
}



proc prefs:dirty {w} {
    if {[winfo exists $w]} {
        $w.apply config -state normal
    }
}



proc prefs:close {w} {
    destroy $w
}



proc /prefs:edit {} {
    set base .prefs
    if {[winfo exists $base]} {
        wm deiconify $base
        focus $base
    } else {
        set parent [focus]
        if {$parent != {}} {
            set parent [winfo toplevel $parent]
        }

        toplevel $base
        wm resizable $base 0 0
        wm protocol $base WM_DELETE_WINDOW "$base.cancel invoke"
        wm title $base "Preferences"

        #place_window_default $base $parent

        upvar #0 tkcad_preferences var
        set nb $base.nb

        ttk::notebook $nb

	set pnum 0
        foreach tabname $var(tablist) {
            if {$tabname != {} && $tabname != "-"} {
		set fr [frame "$nb.[incr pnum]"]
                $nb add $fr -text $tabname
                prefs:mkpage $fr $tabname
            }
        }

        button $base.ok     -text Ok     -width 10 \
                -command "prefs:apply $base ; prefs:close $base" -default active
        button $base.cancel -text Cancel -width 10 \
                -command "prefs:close $base"
        button $base.apply  -text Apply  -width 10 \
                -command "prefs:apply $base" -state disabled


        grid columnconfig $base 0 -minsize 15
        grid columnconfig $base 1 -minsize 5 -weight 1
        grid columnconfig $base 2 -minsize 5
        grid columnconfig $base 4 -minsize 10
        grid columnconfig $base 6 -minsize 10
        grid columnconfig $base 8 -minsize 15

        grid rowconfig $base 0 -minsize 15
        grid rowconfig $base 1 -minsize 5 -weight 1
        grid rowconfig $base 2 -minsize 10
        grid rowconfig $base 4 -minsize 15

        grid $nb -row 1 -column 1 -columnspan 7 -sticky nsew
        grid $base.ok     -row 3 -column 3 -sticky nsew
        grid $base.cancel -row 3 -column 5 -sticky nsew
        grid $base.apply  -row 3 -column 7 -sticky nsew

        bind $base <Key-Escape> "$base.cancel invoke"
        bind $base <Key-Return> "$base.ok invoke"

        focus $base.ok
    }
}



global tcl_platform
if {$tcl_platform(winsys) == "aqua"} {
    namespace eval ::tk::mac {
        proc ShowPreferences {} {
	    if {[catch {/prefs:edit} err]} {
		global errorInfo
		puts stderr $errorInfo
	        tk_messageBox -type ok -message $errorInfo
	    }
        }
    }
}

