# Window for specifying mill capabilities.

proc mlgui_mill_create {wname} {
    global mlguiMillInfo

    set base [toplevel $wname]
    wm title $base "Mill Data"
    wm resizable $base 0 0
    
    set minrpm     [mlcnc_mill_rpm_min]
    set maxrpm     [mlcnc_mill_rpm_max]
    set hp         [mlcnc_mill_hp]
    set maxfeed    [mlcnc_mill_feed_max]
    set fixedrpm   [mlcnc_mill_rpm_is_fixed]
    set rpmlist    [mlcnc_mill_rpm_list]
    set autotool   [mlcnc_mill_has_auto_tool_changer]
    set discrete   [mlcnc_mill_speeds_are_discrete]

    set vfr [labelframe $base.rpmvar  -padx 10 -pady 10]
    set rfr [labelframe $base.rpmlist -padx 10 -pady 10]

    set var mlguiMillInfo(WIDGETVAL-$base.rpmmode)
    set $var $discrete

    radiobutton $vfr.rpmmode -text "Variable Speed" \
        -value 0 -variable $var \
	-command [list mlgui_mill_rpmmode_update $base]
    bind $vfr.rpmmode <KeyPress-Left>  [list focus $rfr.rpmmode]
    bind $vfr.rpmmode <KeyPress-Right> [list focus $rfr.rpmmode]
    bind $vfr.rpmmode <KeyPress-Up>    [list focus $rfr.rpmmode]
    bind $vfr.rpmmode <KeyPress-Down>  [list focus $rfr.rpmmode]

    radiobutton $rfr.rpmmode -text "Discrete Speeds" \
        -value 1 -variable $var \
	-command [list mlgui_mill_rpmmode_update $base]
    bind $rfr.rpmmode <KeyPress-Left>  [list focus $vfr.rpmmode]
    bind $rfr.rpmmode <KeyPress-Right> [list focus $vfr.rpmmode]
    bind $rfr.rpmmode <KeyPress-Up>    [list focus $vfr.rpmmode]
    bind $rfr.rpmmode <KeyPress-Down>  [list focus $vfr.rpmmode]

    $vfr configure -labelwidget $vfr.rpmmode
    $rfr configure -labelwidget $rfr.rpmmode

    label $vfr.minrpm_lbl -text "Minimum RPM"
    spinbox $vfr.minrpm -width 8 -format "%.0f" \
        -from 0.0 -to 999999.0 -increment 100.0 -validate all \
        -validatecommand [list mlcnc_mill_validate_int $base %P]
    $vfr.minrpm set [format [$vfr.minrpm cget -format] $minrpm]

    label $vfr.maxrpm_lbl -text "Maximum RPM"
    spinbox $vfr.maxrpm -width 8 -format "%.0f" \
        -from 0.0 -to 999999.0 -increment 100.0 -validate all \
        -validatecommand [list mlcnc_mill_validate_int $base %P]
    $vfr.maxrpm set [format [$vfr.maxrpm cget -format] $maxrpm]

    grid columnconfigure $vfr 1 -minsize 10
    grid rowconfigure $vfr 1 -minsize 20
    grid configure $vfr.minrpm_lbl x $vfr.minrpm -row 0
    grid configure $vfr.maxrpm_lbl x $vfr.maxrpm -row 1

    grid configure $vfr.minrpm_lbl $vfr.maxrpm_lbl -sticky e
    grid configure $vfr.minrpm $vfr.maxrpm -sticky w

    listbox $rfr.list -width 10 -height 8 -selectmode single \
        -yscrollcommand [list $rfr.scroll set]
    scrollbar $rfr.scroll -command [list $rfr.list yview]
    spinbox $rfr.newrpm -width 6 -format "%.0f" \
        -from 1.0 -to 999999.0 -increment 100.0 -validate all \
        -validatecommand [list mlcnc_mill_validate_int $base %P]
    $rfr.newrpm set [format [$rfr.newrpm cget -format] 1000.0]
    label $rfr.rpmlbl -text "RPM"
    set blank [image create photo blank]
    button $rfr.addbtn -text " + " -image $blank -compound center -command [list mlgui_mill_rpmlist_add $wname]
    button $rfr.delbtn -text " - " -image $blank -compound center -command [list mlgui_mill_rpmlist_del $wname]
    foreach rpm [lsort -integer $rpmlist] {
        $rfr.list insert end $rpm
    }
    grid columnconfigure $rfr 0 -weight 100
    grid columnconfigure $rfr 3 -weight 1
    grid rowconfigure $rfr 0 -weight 100
    grid $rfr.list   -           -           -           $rfr.scroll
    grid $rfr.newrpm $rfr.rpmlbl $rfr.addbtn $rfr.delbtn -            -sticky ews -pady 10

    grid $rfr.list -sticky nsew
    grid $rfr.scroll -sticky nse

    set var mlguiMillInfo(WIDGETVAL-$base.fixedrpm)
    set $var $fixedrpm
    checkbutton $base.fixedrpm -text "Manual Speed Control" -variable $var

    set var mlguiMillInfo(WIDGETVAL-$base.autotool)
    set $var $autotool
    checkbutton $base.autotool -text "Automatic Tool Changer" -variable $var

    label $base.hp_lbl -text "HorsePower"
    spinbox $base.hp -width 8 -format "%.2f" \
        -from 0.0 -to 9999.0 -increment 0.05 -validate all \
        -validatecommand [list mlcnc_mill_validate_float $base %P]
    $base.hp set [format [$base.hp cget -format] $hp]

    label $base.maxfeed_lbl -text "Maximum Feed"
    spinbox $base.maxfeed -width 8 -format "%.2f" \
        -from 0.0 -to 9999.0 -increment 1.0 -validate all \
        -validatecommand [list mlcnc_mill_validate_float $base %P]
    $base.maxfeed set [format [$base.maxfeed cget -format] $maxfeed]

    button $base.savebtn   -text "Save"   -width 10 -default active -command [list mlgui_mill_save $base]
    button $base.cancelbtn -text "Cancel" -width 10 -command [list destroy $base]
    bind $base <KeyPress-Return> [list $base.savebtn invoke]
    bind $base <KeyPress-Escape> [list $base.cancelbtn invoke]

    mlgui_mill_rpmmode_update $base

    grid columnconfigure $base 0 -minsize 25
    grid columnconfigure $base 2 -minsize 10
    grid columnconfigure $base 4 -minsize 50
    grid columnconfigure $base 6 -minsize 25
    grid rowconfigure $base 0 -minsize 25
    grid rowconfigure $base 2 -minsize 20
    grid rowconfigure $base 4 -minsize 10
    grid rowconfigure $base 6 -minsize 20
    grid rowconfigure $base 8 -minsize 20
    grid rowconfigure $base 10 -minsize 20
    grid rowconfigure $base 12 -minsize 30

    set fr [frame $base.frdummy -borderwidth 0 -relief flat]
    grid configure $fr    x             x        x        x       x        x
    grid configure ^ $vfr               -        -        x $rfr           x 
    grid configure ^      x             x        x        x       ^        x -in $base
    grid configure ^ $base.fixedrpm     -        -        x       ^        x 
    grid configure ^      x             x        x        x       ^        x -in $base
    grid configure ^ $base.autotool     -        -        x       ^        x 
    grid configure ^      x             x        x        x       ^        x -in $base
    grid configure ^ $base.hp_lbl       x $base.hp        x       ^        x 
    grid configure ^      x             x        x        x       ^        x -in $base
    grid configure ^ $base.maxfeed_lbl  x $base.maxfeed   x       ^        x 
    grid configure ^      x             x        x        x       x        x -in $base
    grid configure ^      x             x $base.cancelbtn x $base.savebtn  x
    grid configure ^      x             x        x        x       x        x -in $base

    grid configure \
	$base.hp_lbl $base.maxfeed_lbl \
	-sticky e
    grid configure \
	$base.fixedrpm $base.hp $base.maxfeed $base.autotool \
	-sticky w
    grid configure $vfr $rfr -sticky nsew

    return $base
}


proc mlgui_mill_rpmmode_update {wname} {
    global mlguiMillInfo

    set discrete $mlguiMillInfo(WIDGETVAL-$wname.rpmmode)
    if {$discrete} {
        set discstate "normal"
        set varstate  "disabled"
    } else {
        set discstate "disabled"
        set varstate  "normal"
    }

    foreach w [winfo children $wname.rpmvar] {
	if {[lindex [split $w "."] end] == "rpmmode"} continue
	catch {
	    $w configure -state $varstate
	}
    }
    foreach w [winfo children $wname.rpmlist] {
	if {[lindex [split $w "."] end] == "rpmmode"} continue
	catch {
	    $w configure -state $discstate
	}
    }
}


proc mlgui_mill_save {wname} {
    global mlguiMillInfo

    set minrpm   [$wname.rpmvar.minrpm get]
    set maxrpm   [$wname.rpmvar.minrpm get]
    set rpmlist  [$wname.rpmlist.list get 0 end]
    set fixedrpm $mlguiMillInfo(WIDGETVAL-$wname.fixedrpm)

    set autotool $mlguiMillInfo(WIDGETVAL-$wname.autotool)
    set hp       [$wname.hp get]
    set maxfeed  [$wname.maxfeed get]

    mlcnc_define_mill -minrpm $minrpm -maxrpm $maxrpm \
        -fixedrpm $fixedrpm -rpmlist $rpmlist \
        -hp $hp -maxfeed $maxfeed -autotoolchanger $autotool

    destroy $wname
}


proc mlgui_mill_rpmlist_add {wname} {
    set newrpm [$wname.rpmlist.newrpm get]
    set rpmlist [$wname.rpmlist.list get 0 end]
    if {[lsearch -exact $rpmlist $newrpm] == -1} {
        lappend rpmlist $newrpm
	set rpmlist [lsort -integer $rpmlist]
	$wname.rpmlist.list delete 0 end
	foreach rpm $rpmlist {
	    $wname.rpmlist.list insert end $rpm
	}
    }
}


proc mlgui_mill_rpmlist_del {wname} {
    set selection [$wname.rpmlist.list curselection]
    if {[llength $selection] > 0} {
        foreach pos [lsort -integer -decreasing $selection] {
	    $wname.rpmlist.list delete $pos
	}
    }
}


proc mlcnc_mill_validate_int {wname newval} {
    if {![string is integer $newval]} {
        return 0
    }
    return 1
}


proc mlcnc_mill_validate_float {wname newval} {
    if {![string is double $newval]} {
        return 0
    }
    return 1
}


if {[info commands main] == {}} {
    package require opt
    bind all <Command-KeyPress-q> "exit"

    cd [file dirname [info script]]

    source mlcnc-mill.tcl
    source mlcnc-stock.tcl
    source mlcnc-tool.tcl
    source mlcnc-calc.tcl
    source mlcnc-gapi.tcl

    mlcnc_define_mill \
	-hp 0.25 \
	-fixedrpm 1 \
	-rpmlist {1100 1900 2900 4300 6500 10500} \
	-maxfeed 15.0 \
	-autotoolchanger 0 \
	-discretespeeds 1

    source mlgui-misc.tcl
    mlgui_mill_create .mill
    after 100 raise .mill
}

