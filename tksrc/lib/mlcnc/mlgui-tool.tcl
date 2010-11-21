# Window for specifying information about a milling tool.
#

proc mlgui_tool_create {wname {toolnum ""}} {
    global mlguiToolInfo

    set base [toplevel $wname]
    wm title $base "Tool Data"
    
    if {$toolnum == ""} {
        set toolnum  1
	set diam     [expr 3/16.0]
	set length   0.0
	set cutlen   [expr 5/8.0]
	set flutes   4
	set type     "End"
	set material "HSS"
	set coating  "None"
    } else {
	set diam     [mlcnc_tooldiam $toolnum]
	set length   [mlcnc_toollen $toolnum]
	set cutlen   [mlcnc_toolcutlen $toolnum]
	set flutes   [mlcnc_toolteeth $toolnum]
	set type     [mlcnc_tooltype $toolnum]
	set material [mlcnc_toolmaterial $toolnum]
	set coating  [mlcnc_toolcoating $toolnum]
    }

    label $base.toolnum_lbl   -text "Tool Number"
    spinbox $base.toolnum -width 8 -format "%.0f" \
        -from 0.0 -to 99.0 -increment 1.0 -validate all \
        -validatecommand [list mlcnc_tool_validate_int $base %P]
    $base.toolnum set [format [$base.toolnum cget -format] $toolnum]

    label $base.diam_lbl     -text "Tool Diameter"
    spinbox $base.diam -width 8 -format "%.5f" \
        -from 0.0 -to 99.0 -increment [expr {1/32.0}] -validate all \
        -validatecommand [list mlcnc_tool_validate_float $base %P]
    $base.diam set [format [$base.diam cget -format] $diam]

    label $base.length_lbl   -text "Tool Length Offset"
    spinbox $base.length -width 8 -format "%.4f" \
        -from 0.0 -to 99.0 -increment 0.001 -validate all \
        -validatecommand [list mlcnc_tool_validate_float $base %P]
    $base.length set [format [$base.length cget -format] $length]

    label $base.cutlen_lbl   -text "Cutting Edge Length"
    spinbox $base.cutlen -width 8 -format "%.4f" \
        -from 0.0 -to 99.0 -increment 0.001 -validate all \
        -validatecommand [list mlcnc_tool_validate_float $base %P]
    $base.cutlen set [format [$base.cutlen cget -format] $cutlen]

    label $base.flutes_lbl   -text "Number of Flutes"
    spinbox $base.flutes -width 8 -format "%.0f" \
        -from 1.0 -to 99.0 -increment 1.0 -validate all \
        -validatecommand [list mlcnc_tool_validate_int $base %P]
    $base.flutes set [format [$base.flutes cget -format] $flutes]

    label $base.type_lbl     -text "Tool Type"
    mlgui_optionmenu $base.type $type {{End "End Mill"} {Ball "Ball Mill"} Conic {"Gear Cutter"}}

    label $base.material_lbl -text "Tool Material"
    mlgui_optionmenu $base.material $material {HSS Carbide}

    label $base.coating_lbl  -text "Coating"
    mlgui_optionmenu $base.coating $coating {None TiN TiCN TiAlN AlTiN Diamond Diamondlike}

    button $base.savebtn   -text "Save"   -width 10 -default active -command [list mlgui_tool_save $base]
    button $base.cancelbtn -text "Cancel" -width 10 -command [list destroy $base]
    bind $base <KeyPress-Return> [list $base.savebtn invoke]
    bind $base <KeyPress-Escape> [list $base.cancelbtn invoke]

    grid columnconfigure $base 0 -minsize 25
    grid columnconfigure $base 2 -minsize 10
    grid columnconfigure $base 4 -minsize 50
    grid columnconfigure $base 6 -minsize 10
    grid columnconfigure $base 7 -minsize 150
    grid columnconfigure $base 8 -minsize 25
    grid rowconfigure $base 0 -minsize 25
    grid rowconfigure $base 2 -minsize 20
    grid rowconfigure $base 4 -minsize 20
    grid rowconfigure $base 6 -minsize 20
    grid rowconfigure $base 8 -minsize 30
    grid rowconfigure $base 10 -minsize 30

    set row -1
    set fr [frame $base.frdummy -borderwidth 0 -relief flat]
    grid configure $fr     x            x        x       x       x            x       x        x -in $base
    grid configure ^ $base.toolnum_lbl  x $base.toolnum  x $base.flutes_lbl   x $base.flutes   x
    grid configure ^       x            x        x       x       x            x       x        x -in $base
    grid configure ^ $base.diam_lbl     x $base.diam     x $base.type_lbl     x $base.type     x
    grid configure ^       x            x        x       x       x            x       x        x -in $base
    grid configure ^ $base.length_lbl   x $base.length   x $base.material_lbl x $base.material x
    grid configure ^       x            x        x       x       x            x       x        x -in $base
    grid configure ^ $base.cutlen_lbl   x $base.cutlen   x $base.coating_lbl  x $base.coating  x
    grid configure ^       x            x        x       x       x            x       x        x -in $base
    grid configure ^       x            x        x       x $base.cancelbtn    x $base.savebtn  x -in $base
    grid configure ^       x            x        x       x       x            x       x        x -in $base

    grid configure $base.toolnum_lbl $base.diam_lbl $base.length_lbl $base.cutlen_lbl $base.flutes_lbl $base.type_lbl $base.material_lbl $base.coating_lbl -sticky e
    grid configure $base.diam $base.length $base.cutlen $base.flutes $base.type $base.material $base.coating -sticky w

    return $base
}


proc mlgui_tool_save {wname} {
    set toolnum [$wname.toolnum get]
    set diam [$wname.diam get]
    set length [$wname.length get]
    set cutlen [$wname.cutlen get]
    set flutes [$wname.flutes get]
    set type [mlgui_optionmenu_value_get $wname.type]
    set material [mlgui_optionmenu_value_get $wname.material]
    set coating [mlgui_optionmenu_value_get $wname.coating]

    mlcnc_define_tool $toolnum $diam -length $length -cutlength $cutlen \
        -flutes $flutes -type $type -material $material -coating $coating

    destroy $wname
}


proc mlcnc_tool_validate_int {wname newval} {
    if {![string is integer $newval]} {
        return 0
    }
    return 1
}


proc mlcnc_tool_validate_float {wname newval} {
    if {![string is double $newval]} {
        return 0
    }
    return 1
}


if {0} {
    bind all <Command-KeyPress-q> "exit"
    source ../mlcnc.tcl
    source mlgui-misc.tcl
    mlgui_tool_create .tool
    after 100 raise .tool
}

