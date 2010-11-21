proc mlcnc_g_gear {pitch helicalangle numteeth gearwidth tableorient} {
    constants pi
    set rapiddist 0.1
    set milldir   1.0 ;# Conventional = 1.0, Climb= -1.0

    set tablerad    [expr {$tableorient*$pi/180.0}]
    set helrad      [expr {$helicalangle*$pi/180.0}]

    set pitchdiam   [expr {((1.0*$numteeth)/$pitch)/cos($helrad)}]
    set outsidediam [expr {$pitchdiam+(2.0/$pitch)}]
    set wholedepth  [expr {2.157/$pitch}]
    set circpitch   [expr {$pi/$pitch}]
    set indexdegs   [expr {360.0/$numteeth}]

    set cutlen      [expr {$gearwidth/cos($helrad)}]
    set aaxismove   [expr {(tan($helrad)*$gearwidth)/($pi*$pitchdiam/360.0)}]

    set perpang     [expr {$tablerad-$pi}]
    if {$helicalangle < 0.0} {
        set approachang [expr {$perpang+$pi/2.0}]
        set milldir [expr {-1.0*$milldir}]
    } else {
        set approachang [expr {$perpang-$pi/2.0}]
    }

    switch -exact -- [format "%.1f" [expr {fmod($tablerad*180.0/$pi+360.0,360.0)}]] {
          0.0 { set tableside "+X" }
         90.0 { set tableside "+Y" }
        180.0 { set tableside "-X" }
        270.0 { set tableside "-Y" }
        default { set tableside [format "%.1f deg" [expr {$tablerad*180.0/$pi}]] }
    }

    switch -exact -- [format "%.1f" [expr {fmod($approachang*180.0/$pi+360.0,360.0)}]] {
          0.0 { set cutside "+X" }
         90.0 { set cutside "+Y" }
        180.0 { set cutside "-X" }
        270.0 { set cutside "-Y" }
        default { set cutside [format "%.1f deg" [expr {$approachang*180.0/$pi}]] }
    }

    set perpxd      [expr {($gearwidth/2.0)*cos($perpang)*cos($helrad)}]
    set perpyd      [expr {($gearwidth/2.0)*sin($perpang)*cos($helrad)}]
    set perpzd      [expr {($gearwidth/2.0)*abs(sin($helrad))}]

    set rapidxb     [expr {$rapiddist*cos($approachang)}]
    set rapidyb     [expr {$rapiddist*sin($approachang)}]
    set rapidzb     0.0

    set aaxismove   [expr {$milldir*$aaxismove}]
    set perpxd      [expr {$milldir*$perpxd}]
    set perpyd      [expr {$milldir*$perpyd}]
    set perpzd      [expr {$milldir*$perpzd}]

    set rapidx1     [expr {$rapidxb-$perpxd}]
    set rapidy1     [expr {$rapidyb-$perpyd}]
    set rapidz1     [expr {$rapidzb-$perpzd}]
    set rapidx2     [expr {$rapidxb+$perpxd}]
    set rapidy2     [expr {$rapidyb+$perpyd}]
    set rapidz2     [expr {$rapidzb+$perpzd}]

    set rotfeedfact [expr {360.0/($pi*$outsidediam)}]
    set cutdepth    [mlcnc_cutdepth -cutwidth [expr {($pi/$pitch)/2.0}]]

    set out {}
    if {abs($helicalangle) <= 0.00001} {
        append out         "(          SPUR GEAR           )\n"
    } else {
        append out         "(         HELICAL GEAR         )\n"
    }
    append out         "( ---------------------------- )\n"
    append out [format "( Rotary table is on %s side.  )\n" $tableside]
    append out [format "( Gear cutter is on %s side.   )\n" $cutside]
    append out         "( ---------------------------- )\n"
    append out [format "( pitch         = %3.0f          )\n" $pitch]
    append out [format "( num. of teeth = %3.0f teeth    )\n" $numteeth]
    append out [format "( pitch diam.   = %8.4f in  )\n" $pitchdiam]
    append out [format "( outside diam. = %8.4f in  )\n" $outsidediam]
    append out [format "( helical angle = %8.4f deg )\n" $helicalangle]
    append out [format "( whole depth   = %8.4f in  )\n" $wholedepth]
    append out [format "( gear width    = %8.4f in  )\n" $gearwidth]
    append out [format "( circ. pitch   = %8.4f in  )\n" $circpitch]
    append out "\n"
    append out "( correct feed for angular motion )\n"
    append out [format "#1020=\[#1001*SIN\[ABS\[%.5f\]\]*%.5f\]\n" $helicalangle $rotfeedfact]
    append out [format "#1021=\[#1001*COS\[ABS\[%.5f\]\]\]\n" $helicalangle]
    append out [format "#1011=\[SQRT\[\[#1020*#1020\]+\[#1021*#1021\]\]\] ( angular feed )\n"]
    append out "\n"

    set curdepth $cutdepth
    while {1} {
        if {$curdepth > $wholedepth-0.02} {
            set curdepth $wholedepth
        }

        set cuttingxb   [expr {-1.0*$curdepth*cos($approachang)}]
        set cuttingyb   [expr {-1.0*$curdepth*sin($approachang)}]
        set cuttingzb   0.0

        set cutx1       [expr {$cuttingxb-$perpxd}]
        set cuty1       [expr {$cuttingyb-$perpyd}]
        set cutz1       [expr {$cuttingzb-$perpzd}]
        set cutx2       [expr {$cuttingxb+$perpxd}]
        set cuty2       [expr {$cuttingyb+$perpyd}]
        set cutz2       [expr {$cuttingzb+$perpzd}]

	set first 1
        for {set i 0} {$i < $numteeth} {incr i} {
            set a1 [expr {$i*$indexdegs}]
            set a2 [expr {$a1+$aaxismove}]
	    if {$first} {
	        set first 0
		append out [format "G00 X%.4f Y%.4f Z%.4f\n" $rapidx1 $rapidy1 $rapidz1]
		append out [format "G00 A%.4f\n" $a1]
	    } else {
		append out [format "G00 X%.4f Y%.4f Z%.4f A%.4f\n" $rapidx1 $rapidy1 $rapidz1 $a1]
	    }
            append out [format "G01 X%.4f Y%.4f Z%.4f F#1000\n" $cutx1 $cuty1 $cutz1]
            append out [format "G01 X%.4f Y%.4f Z%.4f A%.4f F#1011\n" $cutx2 $cuty2 $cutz2 $a2]
            append out [format "G00 X%.4f Y%.4f Z%.4f\n\n" $rapidx2 $rapidy2 $rapidz2]
        }

        if {$curdepth == $wholedepth} {
            break
        }
        set curdepth [expr {$curdepth+$cutdepth}]
    }
    append out "G00 A0.0\n"
    return $out
}


proc mlcnc_g_worm_gear {pitch wormthreads wormdiam wormhand numteeth gearwidth tableorient} {
    set pi 3.141592653589793236

    set addendum     [expr {1.0/$pitch}]
    set pitchdiam    [expr {$wormdiam-(2.0*$addendum)}]
    set axialpitch   [expr {$pi/$pitch}]
    set lead         [expr {$wormthreads*$axialpitch}]
    set leadangle    [expr {atan2($lead,$pi*$pitchdiam)}]
    set helicalangle [expr {$leadangle*180.0/$pi}]

    if {[string tolower $wormhand] == "left"} {
        set helicalangle [expr {-1.0*$helicalangle}]
    }

    return [mlcnc_g_gear $pitch $helicalangle $numteeth $gearwidth $tableorient]
}


proc mlcnc_g_worm {pitch threads hand length outsidediam tableorient} {
    set pi 3.141592653589793236

    set addendum     [expr {1.0/$pitch}]
    set pitchdiam    [expr {$outsidediam-(2.0*$addendum)}]
    set axialpitch   [expr {$pi/$pitch}]
    set lead         [expr {$threads*$axialpitch}]
    set leadangle    [expr {atan2($lead,$pi*$pitchdiam)}]
    set helicalangle [expr {$leadangle*180.0/$pi}]
    if {[string tolower $hand] == "left"} {
        set helicalangle [expr {-1.0*$helicalangle}]
    }
    set complementangle [expr {90.0-$helicalangle}]

    set out {}
    append out         "(             WORM             )\n"
    append out [mlcnc_g_gear $pitch $complementangle $threads $length $tableorient]

    return $out
}




##########################################################################
# Gui dialogs
##########################################################################

proc mlcnc_g_gear_gui_gen {wname} {
    global mlcncGearsInfo

    set tool        [mlcnc_tool_selector_widget_getval $wname.tool]
    set pitch       [$wname.pitch get]
    set helical     [$wname.helical get]
    set numteeth    [$wname.numteeth get]
    set gearwidth   [$wname.gearwidth get]
    set tableorient $mlcncGearsInfo(WIDGETVAL-$wname.orient)

    set base $wname
    if {$base == ""} {
        set base "."
    }
    set filetypes {
        {"NC g-code files" {.nc .cnc .g}}
        {"Text g-code files" {.txt}}
    }
    set file [tk_getSaveFile -initialfile "Unknown.nc" \
        -defaultextension ".nc" -filetypes $filetypes -parent $base \
        -title "Save G-Code to..."]

    if {$file == ""} {
        return
    }

    if {[catch {
        set f [open $file "w"]
        puts $f [mlcnc_g_start]
        puts $f [mlcnc_g_set_tool $tool]
        puts $f [mlcnc_g_gear $pitch $helical $numteeth $gearwidth $tableorient]
        close $f
    } err]} {
        tk_messageBox -type ok -icon error -message $err
    }
}


proc mlcnc_g_gear_gui_update_stats {wname} {
    global mlcncGearsInfo

    catch {
        set pi 3.141592653589793236
        set sfr $wname.statsfr

        set pitch       [$wname.pitch get]
        set helang      [$wname.helical get]
        set numteeth    [$wname.numteeth get]
        set gearwidth   [$wname.gearwidth get]
        set tableorient $mlcncGearsInfo(WIDGETVAL-$wname.orient)

        if {$helang > 0.0} {
            set approachang [expr {fmod($tableorient+90.0,360.0)}]
        } else {
            set approachang [expr {fmod($tableorient+270.0,360.0)}]
        }
        switch -exact -- $approachang {
            0.0 { set cutside "+X" }
            90.0 { set cutside "+Y" }
            180.0 { set cutside "-X" }
            270.0 { set cutside "-Y" }
            default { set cutside "$approachang˚" }
        }

        set pitchdiam   [expr {(($numteeth+0.0)/($pitch+0.0))/cos($helang*$pi/180.0)}]
        set outsidediam [expr {$pitchdiam+(2.0/($pitch+0.0))}]
        set wholedepth  [expr {2.157/($pitch+0.0)}]

        $sfr.outdiam configure    -text [format "Outside Diam: %.3f" $outsidediam]
        $sfr.pitchdiam configure  -text [format "Pitch Diam: %.3f" $pitchdiam]
        $sfr.wholedepth configure -text [format "Whole Depth: %.3f" $wholedepth]
        $sfr.cutside configure    -text [format "Cut Side: %s" $cutside]
    }
}


proc mlcnc_g_gear_gui_validate_int {wname newval} {
    if {![string is integer $newval]} {
        return 0
    }
    after idle mlcnc_g_gear_gui_update_stats [list $wname]
    return 1
}


proc mlcnc_g_gear_gui_validate_float {wname newval} {
    if {![string is double $newval]} {
        return 0
    }
    after idle mlcnc_g_gear_gui_update_stats [list $wname]
    return 1
}


proc mlcnc_g_gear_gui_set_orientation {wname newval} {
    $wname.orient configure -text $newval
    after idle mlcnc_g_gear_gui_update_stats [list $wname]
}


proc mlcnc_g_gear_gui_create {wname} {
    global mlcncGearsInfo

    set base $wname
    if {$base == ""} {
	set n 1
	while {[winfo exists ".gearwiz$n"]} {
	    incr n
	}
        set base ".gearwiz$n"
	toplevel $base
	wm title $base "Make a Gear Wizard"
	set wname $base
    }

    label $wname.tool_lbl -text "Tool to use"
    mlcnc_tool_selector_widget $wname.tool

    label $wname.pitch_lbl -text "Gear Pitch"
    spinbox $wname.pitch -width 8 -format "%.0f" \
        -from 0.0 -to 99.0 -increment 1.0 -validate all \
        -validatecommand [list mlcnc_g_gear_gui_validate_int $wname %P]

    label $wname.helical_lbl -text "Helical Angle"
    spinbox $wname.helical -width 8 -format "%.4f" \
        -from -89.99 -to 89.99 -increment 0.1 -validate all \
        -validatecommand [list mlcnc_g_gear_gui_validate_float $wname %P]

    label $wname.numteeth_lbl -text "Number of Teeth"
    spinbox $wname.numteeth -width 8 -format "%.0f" \
        -from 0.0 -to 999.0 -increment 1.0 -validate all \
        -validatecommand [list mlcnc_g_gear_gui_validate_int $wname %P]

    label $wname.gearwidth_lbl -text "Gear Width"
    spinbox $wname.gearwidth -width 8 -format "%.4f" \
        -from 0.0 -to 99.9999 -increment 0.1 -validate all \
        -validatecommand [list mlcnc_g_gear_gui_validate_float $wname %P]

    label $wname.orient_lbl -text "Rotary Table Pos"
    set var mlcncGearsInfo(WIDGETVAL-$wname.orient)
    set $var "0.0"
    set orientmenu $wname.orient.menu
    menubutton $wname.orient -width 3 -text " +X" \
        -menu $orientmenu -indicatoron 1 -relief raised \
        -direction flush -takefocus 1
    bind $wname.orient <Destroy> [list unset $var]
    menu $orientmenu -tearoff false
    $orientmenu add radiobutton -label " +X" -value "0.0" -variable $var \
        -command [list mlcnc_g_gear_gui_set_orientation $wname { +X}]
    $orientmenu add radiobutton -label " +Y" -value "90.0" -variable $var \
        -command [list mlcnc_g_gear_gui_set_orientation $wname { +Y}]
    $orientmenu add radiobutton -label " -X" -value "180.0" -variable $var \
        -command [list mlcnc_g_gear_gui_set_orientation $wname { -X}]
    $orientmenu add radiobutton -label " -Y" -value "270.0" -variable $var \
        -command [list mlcnc_g_gear_gui_set_orientation $wname { -Y}]

    set sfr [frame $wname.statsfr -relief solid -borderwidth 1 -padx 10 -pady 10]
    label $sfr.outdiam    -text "Outside Diam:"
    label $sfr.pitchdiam  -text "Pitch Diameter:"
    label $sfr.wholedepth -text "Whole Depth:"
    label $sfr.cutside    -text "Cut Side:"
    grid $sfr.outdiam -sticky nw
    grid $sfr.pitchdiam -sticky nw
    grid $sfr.wholedepth -sticky nw
    grid $sfr.cutside -sticky nw

    button $wname.gen -text "Generate G-Code" -command [list mlcnc_g_gear_gui_gen $wname] -default active
    bind [winfo toplevel $wname.gen] <KeyPress-Return> [list $wname.gen invoke]

    $wname.pitch     set [format [$wname.pitch     cget -format] 24.0]
    $wname.helical   set [format [$wname.helical   cget -format] 45.0]
    $wname.numteeth  set [format [$wname.numteeth  cget -format] 24.0]
    $wname.gearwidth set [format [$wname.gearwidth cget -format] 1.0]

    grid columnconfigure $base 0 -minsize 25
    grid columnconfigure $base 2 -minsize 10
    grid columnconfigure $base 4 -minsize 10
    grid columnconfigure $base 5 -weight 1
    grid columnconfigure $base 6 -minsize 25
    grid rowconfigure $base  0 -minsize 25
    grid rowconfigure $base  2 -minsize 20
    grid rowconfigure $base  4 -minsize 20
    grid rowconfigure $base  6 -minsize 20
    grid rowconfigure $base  8 -minsize 20
    grid rowconfigure $base 10 -minsize 20
    grid rowconfigure $base 12 -minsize 20
    grid rowconfigure $base 14 -minsize 25 -weight 1

    grid configure x $wname.tool_lbl      x $wname.tool      - -    x -sticky w -row 1
    grid configure x $wname.pitch_lbl     x $wname.pitch     x $sfr x -sticky w -row 3
    grid configure x $wname.helical_lbl   x $wname.helical   x x    x -sticky w -row 5
    grid configure x $wname.numteeth_lbl  x $wname.numteeth  x x    x -sticky w -row 7
    grid configure x $wname.gearwidth_lbl x $wname.gearwidth x x    x -sticky w -row 9
    grid configure x $wname.orient_lbl    x $wname.orient    x x    x -sticky w -row 11
    grid configure x $wname.gen           - -                x -sticky ew -row 13

    grid $sfr -rowspan 9 -sticky nsew

    return $base
}





proc mlcnc_g_worm_gear_gui_gen {wname} {
    global mlcncGearsInfo

    set tool      [mlcnc_tool_selector_widget_getval $wname.tool]
    set pitch     [$wname.pitch get]
    set threads   [$wname.threads get]
    set wormdiam  [$wname.wormdiam get]
    set wormhand  [$wname.wormhand cget -text]
    set numteeth  [$wname.numteeth get]
    set gearwidth [$wname.gearwidth get]
    set tableorient $mlcncGearsInfo(WIDGETVAL-$wname.orient)

    set base $wname
    if {$base == ""} {
        set base "."
    }
    set filetypes {
        {"NC g-code files" {.nc .cnc .g}}
        {"Text g-code files" {.txt}}
    }
    set file [tk_getSaveFile -initialfile "Unknown.nc" \
        -defaultextension ".nc" -filetypes $filetypes -parent $base \
        -title "Save G-Code to..."]

    if {$file == ""} {
        return
    }

    if {[catch {
        set f [open $file "w"]
        puts $f [mlcnc_g_start]
        puts $f [mlcnc_g_set_tool $tool]
        puts $f [mlcnc_g_worm_gear $pitch $threads $wormdiam $wormhand $numteeth $gearwidth $tableorient]
        close $f
    } err]} {
        tk_messageBox -type ok -icon error -message $err
    }
}


proc mlcnc_g_worm_gear_gui_update_stats {wname} {
    global mlcncGearsInfo

    catch {
        set pi 3.141592653589793236
        set sfr $wname.statsfr

        set pitch     [$wname.pitch get]
        set threads   [$wname.threads get]
        set wormdiam  [$wname.wormdiam get]
        set wormhand  [$wname.wormhand cget -text]
        set numteeth  [$wname.numteeth get]
        set gearwidth [$wname.gearwidth get]
        set tableorient $mlcncGearsInfo(WIDGETVAL-$wname.orient)

	set addendum       [expr {1.0/$pitch}]
	set wormpitchdiam  [expr {$wormdiam-(2.0*$addendum)}]
	set wormaxialpitch [expr {$pi/$pitch}]
	set lead           [expr {$threads*$wormaxialpitch}]
	set leadangle      [expr {atan2($lead,$pi*$wormpitchdiam)}]
	set helang         [expr {$leadangle*180.0/$pi}]

        set pitchdiam   [expr {(($numteeth+0.0)/($pitch+0.0))/cos($helang*$pi/180.0)}]
        set outsidediam [expr {$pitchdiam+(2.0/$pitch)}]
        set wholedepth  [expr {2.157/$pitch}]

        if {[string tolower $wormhand] == "left"} {
            set helang [expr {-1.0*$helang}]
        }

        if {$helang > 0.0} {
            set approachang [expr {fmod($tableorient+90.0,360.0)}]
        } else {
            set approachang [expr {fmod($tableorient+270.0,360.0)}]
        }
        switch -exact -- $approachang {
            0.0 { set cutside "+X" }
            90.0 { set cutside "+Y" }
            180.0 { set cutside "-X" }
            270.0 { set cutside "-Y" }
            default { set cutside "$approachang˚" }
        }

        $sfr.helang configure     -text [format "Helical Angle: %.3f˚" $helang]
        $sfr.outdiam configure    -text [format "Outside Diam: %.3f" $outsidediam]
        $sfr.pitchdiam configure  -text [format "Pitch Diam: %.3f" $pitchdiam]
        $sfr.wholedepth configure -text [format "Whole Depth: %.3f" $wholedepth]
        $sfr.cutside configure    -text [format "Cut Side: %s" $cutside]
    } err
}


proc mlcnc_g_worm_gear_gui_validate_int {wname newval} {
    if {![string is integer $newval]} {
        return 0
    }
    after idle mlcnc_g_worm_gear_gui_update_stats [list $wname]
    return 1
}


proc mlcnc_g_worm_gear_gui_validate_float {wname newval} {
    if {![string is double $newval]} {
        return 0
    }
    after idle mlcnc_g_worm_gear_gui_update_stats [list $wname]
    return 1
}


proc mlcnc_g_worm_gear_gui_set_handedness {wname newval} {
    $wname.wormhand configure -text $newval
    after idle mlcnc_g_worm_gear_gui_update_stats [list $wname]
}


proc mlcnc_g_worm_gear_gui_set_orientation {wname newval} {
    $wname.orient configure -text $newval
    after idle mlcnc_g_worm_gear_gui_update_stats [list $wname]
}


proc mlcnc_g_worm_gear_gui_create {wname} {
    global mlcncGearsInfo

    set base $wname
    if {$base == ""} {
	set n 1
	while {[winfo exists ".gearwiz$n"]} {
	    incr n
	}
        set base ".gearwiz$n"
	toplevel $base
	wm title $base "Make a Worm Gear Wizard"
	set wname $base
    }

    label $wname.tool_lbl -text "Tool to use"
    mlcnc_tool_selector_widget $wname.tool

    label $wname.pitch_lbl -text "Worm Pitch"
    spinbox $wname.pitch -width 8 -format "%.0f" \
        -from 0.0 -to 99.0 -increment 1.0 -validate all \
        -validatecommand [list mlcnc_g_worm_gear_gui_validate_int $wname %P]

    label $wname.threads_lbl -text "Worm Threads"
    spinbox $wname.threads -width 8 -format "%.0f" \
        -from 1.0 -to 9.0 -increment 1.0 -validate all \
        -validatecommand [list mlcnc_g_worm_gear_gui_validate_int $wname %P]

    label $wname.wormdiam_lbl -text "Worm Diameter"
    spinbox $wname.wormdiam -width 8 -format "%.4f" \
        -from 0.0 -to 359.9999 -increment 0.01 -validate all \
        -validatecommand [list mlcnc_g_worm_gear_gui_validate_float $wname %P]

    label $wname.wormhand_lbl -text "Worm Hand"
    set handmenu $wname.wormhand.menu
    set var mlcncGearsInfo(WIDGETVAL-$handmenu)
    set $var "Right"
    menubutton $wname.wormhand -width 8 -textvariable $var \
        -menu $handmenu -indicatoron 1 -relief raised \
        -direction flush -takefocus 1
    menu $handmenu -tearoff false
    $handmenu add radiobutton -label "Right" -value "Right" -variable $var \
        -command [list mlcnc_g_worm_gear_gui_set_handedness $wname Right]
    $handmenu add radiobutton -label "Left"  -value "Left" -variable $var \
        -command [list mlcnc_g_worm_gear_gui_set_handedness $wname Left]

    label $wname.numteeth_lbl -text "Gear Teeth"
    spinbox $wname.numteeth -width 8 -format "%.0f" \
        -from 0.0 -to 999.0 -increment 1.0 -validate all \
        -validatecommand [list mlcnc_g_worm_gear_gui_validate_int $wname %P]

    label $wname.gearwidth_lbl -text "Gear Width"
    spinbox $wname.gearwidth -width 8 -format "%.4f" \
        -from 0.0 -to 99.9999 -increment 0.1 -validate all \
        -validatecommand [list mlcnc_g_worm_gear_gui_validate_float $wname %P]

    label $wname.orient_lbl -text "Rotary Table Pos"
    set var mlcncGearsInfo(WIDGETVAL-$wname.orient)
    set $var "0.0"
    set orientmenu $wname.orient.menu
    menubutton $wname.orient -width 3 -text " +X" \
        -menu $orientmenu -indicatoron 1 -relief raised \
        -direction flush -takefocus 1
    bind $wname.orient <Destroy> [list unset $var]
    menu $orientmenu -tearoff false
    $orientmenu add radiobutton -label " +X" -value "0.0" -variable $var \
        -command [list mlcnc_g_worm_gear_gui_set_orientation $wname { +X}]
    $orientmenu add radiobutton -label " +Y" -value "90.0" -variable $var \
        -command [list mlcnc_g_worm_gear_gui_set_orientation $wname { +Y}]
    $orientmenu add radiobutton -label " -X" -value "180.0" -variable $var \
        -command [list mlcnc_g_worm_gear_gui_set_orientation $wname { -X}]
    $orientmenu add radiobutton -label " -Y" -value "270.0" -variable $var \
        -command [list mlcnc_g_worm_gear_gui_set_orientation $wname { -Y}]

    button $wname.gen -text "Generate G-Code" -command [list mlcnc_g_worm_gear_gui_gen $wname] -default active
    bind [winfo toplevel $wname.gen] <KeyPress-Return> [list $wname.gen invoke]

    set sfr [frame $wname.statsfr -relief solid -borderwidth 1 -padx 10 -pady 10]
    label $sfr.helang     -text "Helical Angle:"
    label $sfr.outdiam    -text "Outside Diam:"
    label $sfr.pitchdiam  -text "Pitch Diameter:"
    label $sfr.wholedepth -text "Whole Depth:"
    label $sfr.cutside    -text "Cut Side:"
    grid $sfr.helang -sticky nw
    grid $sfr.outdiam -sticky nw
    grid $sfr.pitchdiam -sticky nw
    grid $sfr.wholedepth -sticky nw
    grid $sfr.cutside -sticky nw

    $wname.pitch     set [format [$wname.pitch     cget -format] 24.0]
    $wname.threads   set [format [$wname.threads   cget -format] 1.0]
    $wname.wormdiam  set [format [$wname.wormdiam  cget -format] 0.5]
    $wname.numteeth  set [format [$wname.numteeth  cget -format] 36.0]
    $wname.gearwidth set [format [$wname.gearwidth cget -format] 0.5]

    grid columnconfigure $base 0 -minsize 25
    grid columnconfigure $base 2 -minsize 10
    grid columnconfigure $base 4 -minsize 10
    grid columnconfigure $base 5 -weight 1
    grid columnconfigure $base 6 -minsize 25
    grid rowconfigure $base  0 -minsize 25
    grid rowconfigure $base  2 -minsize 20
    grid rowconfigure $base  4 -minsize 20
    grid rowconfigure $base  6 -minsize 20
    grid rowconfigure $base  8 -minsize 20
    grid rowconfigure $base 10 -minsize 20
    grid rowconfigure $base 12 -minsize 20
    grid rowconfigure $base 14 -minsize 20
    grid rowconfigure $base 16 -minsize 20
    grid rowconfigure $base 18 -minsize 25 -weight 1

    grid configure x $wname.tool_lbl      x $wname.tool      - -    -sticky w -row 1
    grid configure x $wname.pitch_lbl     x $wname.pitch     x $sfr -sticky w -row 3
    grid configure x $wname.threads_lbl   x $wname.threads   x x    -sticky w -row 5
    grid configure x $wname.wormdiam_lbl  x $wname.wormdiam  x x    -sticky w -row 7
    grid configure x $wname.wormhand_lbl  x $wname.wormhand  x x    -sticky w -row 9
    grid configure x $wname.numteeth_lbl  x $wname.numteeth  x x    -sticky w -row 11
    grid configure x $wname.gearwidth_lbl x $wname.gearwidth x x    -sticky w -row 13
    grid configure x $wname.orient_lbl    x $wname.orient    x x    -sticky w -row 15
    grid configure x $wname.gen           - -                x x    -sticky ew -row 17

    grid $sfr -rowspan 13 -sticky nsew

    return $base
}




proc mlcnc_g_worm_gui_gen {wname} {
    global mlcncGearsInfo

    set tool      [mlcnc_tool_selector_widget_getval $wname.tool]
    set pitch     [$wname.pitch get]
    set threads   [$wname.threads get]
    set wormhand  [$wname.wormhand cget -text]
    set cutlen    [$wname.cutlen get]
    set wormdiam  [$wname.wormdiam get]
    set orient    $mlcncGearsInfo(WIDGETVAL-$wname.orient)

    set base $wname
    if {$base == ""} {
        set base "."
    }
    set filetypes {
        {"NC g-code files" {.nc .cnc .g}}
        {"Text g-code files" {.txt}}
    }
    set file [tk_getSaveFile -initialfile "Unknown.nc" \
        -defaultextension ".nc" -filetypes $filetypes -parent $base \
        -title "Save G-Code to..."]

    if {$file == ""} {
        return
    }

    if {[catch {
        set f [open $file "w"]
        puts $f [mlcnc_g_start]
        puts $f [mlcnc_g_set_tool $tool]
        puts $f [mlcnc_g_worm $pitch $threads $wormhand $cutlen $wormdiam $orient]
        close $f
    } err]} {
        tk_messageBox -type ok -icon error -message $err
    }
}


proc mlcnc_g_worm_gui_update_stats {wname} {
    global mlcncGearsInfo

    catch {
        set pi 3.141592653589793236
        set sfr $wname.statsfr

        set pitch     [$wname.pitch get]
        set threads   [$wname.threads get]
        set wormdiam  [$wname.wormdiam get]
        set wormhand  [$wname.wormhand cget -text]
        set cutlen    [$wname.cutlen get]
	set orient    $mlcncGearsInfo(WIDGETVAL-$wname.orient)

	set addendum     [expr {1.0/$pitch}]
	set pitchdiam    [expr {$wormdiam-(2.0*$addendum)}]
	set axialpitch   [expr {$pi/$pitch}]
	set lead         [expr {$threads*$axialpitch}]
	set leadangle    [expr {atan2($lead,$pi*$pitchdiam)}]
	set helang       [expr {$leadangle*180.0/$pi}]
	set numteeth     [expr {$cutlen/$lead}]

        if {[string tolower $wormhand] == "left"} {
            set helang [expr {-1.0*$helang}]
        }

        if {$helang > 0.0} {
            set approachang [expr {fmod($orient+90.0,360.0)}]
        } else {
            set approachang [expr {fmod($orient+270.0,360.0)}]
        }
        switch -exact -- $approachang {
            0.0 { set cutside "+X" }
            90.0 { set cutside "+Y" }
            180.0 { set cutside "-X" }
            270.0 { set cutside "-Y" }
            default { set cutside "$approachang˚" }
        }

        $sfr.helang configure   -text [format "Helical Angle: %.3f˚" $helang]
        $sfr.numteeth configure -text [format "Thread Rotations: %.1f" $numteeth]
        $sfr.pitchdiam configure  -text [format "Pitch diameter: %.4f" $pitchdiam]
        $sfr.cutside configure  -text [format "Cut Side: %s" $cutside]
    } err
}


proc mlcnc_g_worm_gui_validate_int {wname newval} {
    if {![string is integer $newval]} {
        return 0
    }
    after idle mlcnc_g_worm_gui_update_stats [list $wname]
    return 1
}


proc mlcnc_g_worm_gui_validate_float {wname newval} {
    if {![string is double $newval]} {
        return 0
    }
    after idle mlcnc_g_worm_gui_update_stats [list $wname]
    return 1
}


proc mlcnc_g_worm_gui_set_handedness {wname newval} {
    $wname.wormhand configure -text $newval
    after idle mlcnc_g_worm_gui_update_stats [list $wname]
}


proc mlcnc_g_worm_gui_set_orientation {wname newval} {
    $wname.orient configure -text $newval
    after idle mlcnc_g_worm_gui_update_stats [list $wname]
}


proc mlcnc_g_worm_gui_create {wname} {
    global mlcncGearsInfo

    set base $wname
    if {$base == ""} {
	set n 1
	while {[winfo exists ".gearwiz$n"]} {
	    incr n
	}
        set base ".gearwiz$n"
	toplevel $base
	wm title $base "Make a Worm Wizard"
	set wname $base
    }

    label $wname.tool_lbl -text "Tool to use"
    mlcnc_tool_selector_widget $wname.tool

    label $wname.pitch_lbl -text "Worm Pitch"
    spinbox $wname.pitch -width 8 -format "%.0f" \
        -from 0.0 -to 99.0 -increment 1.0 -validate all \
        -validatecommand [list mlcnc_g_worm_gui_validate_int $wname %P]

    label $wname.threads_lbl -text "Worm Threads"
    spinbox $wname.threads -width 8 -format "%.0f" \
        -from 1.0 -to 9.0 -increment 1.0 -validate all \
        -validatecommand [list mlcnc_g_worm_gui_validate_int $wname %P]

    label $wname.wormhand_lbl -text "Handedness"
    set handmenu $wname.wormhand.menu
    set var mlcncGearsInfo(WIDGETVAL-$wname.wormhand)
    set $var "Right"
    menubutton $wname.wormhand -width 8 -textvariable $var \
        -menu $handmenu -indicatoron 1 -relief raised \
        -direction flush -takefocus 1
    bind $wname.wormhand <Destroy> [list unset $var]
    menu $handmenu -tearoff false
    $handmenu add radiobutton -label "Right" -value "Right" -variable $var \
        -command [list mlcnc_g_worm_gui_set_handedness $wname Right]
    $handmenu add radiobutton -label "Left"  -value "Left" -variable $var \
        -command [list mlcnc_g_worm_gui_set_handedness $wname Left]

    label $wname.cutlen_lbl -text "Threaded Length"
    spinbox $wname.cutlen -width 8 -format "%.4f" \
        -from 0.0 -to 99.9999 -increment 0.1 -validate all \
        -validatecommand [list mlcnc_g_worm_gui_validate_float $wname %P]

    label $wname.wormdiam_lbl -text "Outside Diameter"
    spinbox $wname.wormdiam -width 8 -format "%.4f" \
        -from 0.0 -to 359.9999 -increment 0.01 -validate all \
        -validatecommand [list mlcnc_g_worm_gui_validate_float $wname %P]

    label $wname.orient_lbl -text "Rotary Table Pos"
    set var mlcncGearsInfo(WIDGETVAL-$wname.orient)
    set $var "0.0"
    set orientmenu $wname.orient.menu
    menubutton $wname.orient -width 3 -text " +X" \
        -menu $orientmenu -indicatoron 1 -relief raised \
        -direction flush -takefocus 1
    bind $wname.orient <Destroy> [list unset $var]
    menu $orientmenu -tearoff false
    $orientmenu add radiobutton -label " +X" -value "0.0" -variable $var \
        -command [list mlcnc_g_worm_gui_set_orientation $wname { +X}]
    $orientmenu add radiobutton -label " +Y" -value "90.0" -variable $var \
        -command [list mlcnc_g_worm_gui_set_orientation $wname { +Y}]
    $orientmenu add radiobutton -label " -X" -value "180.0" -variable $var \
        -command [list mlcnc_g_worm_gui_set_orientation $wname { -X}]
    $orientmenu add radiobutton -label " -Y" -value "270.0" -variable $var \
        -command [list mlcnc_g_worm_gui_set_orientation $wname { -Y}]

    button $wname.gen -text "Generate G-Code" -command [list mlcnc_g_worm_gui_gen $wname] -default active
    bind [winfo toplevel $wname.gen] <KeyPress-Return> [list $wname.gen invoke]

    set sfr [frame $wname.statsfr -relief solid -borderwidth 1 -padx 10 -pady 10]
    label $sfr.helang -text "Helical Angle:"
    label $sfr.numteeth -text "Number of Teeth:"
    label $sfr.pitchdiam -text "Pitch Diameter:"
    label $sfr.cutside -text "Cut Side:"
    grid $sfr.helang -sticky nw
    grid $sfr.numteeth -sticky nw
    grid $sfr.pitchdiam -sticky nw
    grid $sfr.cutside -sticky nw

    $wname.pitch    set [format [$wname.pitch    cget -format] 24.0]
    $wname.threads  set [format [$wname.threads  cget -format] 1.0]
    $wname.cutlen   set [format [$wname.cutlen   cget -format] 0.5]
    $wname.wormdiam set [format [$wname.wormdiam cget -format] 0.5]

    grid columnconfigure $base 0 -minsize 25
    grid columnconfigure $base 2 -minsize 10
    grid columnconfigure $base 4 -minsize 10
    grid columnconfigure $base 5 -weight 1
    grid columnconfigure $base 6 -minsize 25
    grid rowconfigure $base  0 -minsize 25
    grid rowconfigure $base  2 -minsize 20
    grid rowconfigure $base  4 -minsize 20
    grid rowconfigure $base  6 -minsize 20
    grid rowconfigure $base  8 -minsize 20
    grid rowconfigure $base 10 -minsize 20
    grid rowconfigure $base 12 -minsize 20
    grid rowconfigure $base 14 -minsize 20
    grid rowconfigure $base 16 -minsize 25 -weight 1

    grid configure x $wname.tool_lbl      x $wname.tool      - -    x -sticky w -row 1
    grid configure x $wname.pitch_lbl     x $wname.pitch     x $sfr x -sticky w -row 3
    grid configure x $wname.threads_lbl   x $wname.threads   x x    x -sticky w -row 5
    grid configure x $wname.wormhand_lbl  x $wname.wormhand  x x    x -sticky w -row 7
    grid configure x $wname.cutlen_lbl    x $wname.cutlen    x x    x -sticky w -row 9
    grid configure x $wname.wormdiam_lbl  x $wname.wormdiam  x x    x -sticky w -row 11
    grid configure x $wname.orient_lbl    x $wname.orient    x x    x -sticky w -row 13
    grid configure x $wname.gen           - -                x -sticky ew -row 15

    grid $sfr -rowspan 11 -sticky nsew

    mlcnc_g_worm_gui_update_stats $wname

    return $base
}


