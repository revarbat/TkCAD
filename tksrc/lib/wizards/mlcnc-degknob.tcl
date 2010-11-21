
proc mlcnc_g_degree_lines_on_cylinder {diam width cutdepth} {

    set angquants [list 1 5 10 15 30 45 90]
    set angmajors [list 45 30 10 5]
    set pi 3.141592653589793238

    set out {}
    set safez [expr {[mlcnc_stock_top]+0.05}]

    set angd [expr {atan2([mlcnc_tooldiam],$diam/2.0)*180.0/$pi}]
    append out [format "( each line is %.4f degrees thick )\n\n" $angd]
    append out [format "#1012=%.4f ( Cutting depth we'll use )\n\n" [expr {-1.0*$cutdepth}]]

    set angd [expr {int(ceil($angd*2.0))}]
    foreach angquant $angquants {
        if {$angd <= $angquant} {
            set angd $angquant
            break
        }
    }

    for {set ang 0} {$ang < 360} {incr ang $angd} {
        set linelen $width
        foreach angmajor $angmajors {
            if {$ang % $angmajor == 0} {
                break
            }
            set linelen [expr {$linelen*0.75}]
        }
        append out [format "G0 Z%.4f\n" $safez]
        append out [format "G0 X%.4f Y%.4f\n" 0.0 0.0]
        append out [format "G0 A%.4f\n" $ang]
        append out [format "G1 Z#1012 F#1000\n"]
        append out [format "G1 X%.4f Y%.4f F#1001\n" $linelen 0.0]
        append out "\n"
    }
    append out [format "G0 Z%.4f\n" $safez]
    append out [format "G0 X%.4f Y%.4f\n" 0.0 0.0]
    append out [format "G0 A%.4f\n" 0.0]

    return $out
}


proc mlcnc_g_degree_lines_on_cylinder_gui_gen {wname} {
    set tool     [mlcnc_tool_selector_widget_getval $wname.tool]
    set diam     [$wname.diam get]
    set width    [$wname.width get]
    set cutdepth [$wname.cut get]

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
	-title "Save G-Code to..." \
	-message "Select a file to save the gear G-Code to."]

    if {$file == ""} {
        return
    }

    if {[catch {
	set f [open $file "w"]
	puts $f [mlcnc_g_start]
	puts $f [mlcnc_g_set_tool $tool]
	puts $f [mlcnc_g_degree_lines_on_cylinder $diam $width $cutdepth]
	close $f
    } err]} {
        tk_messageBox -type ok -icon error -message $err
    }
}


proc mlcnc_g_degree_lines_on_cylinder_gui_create {wname} {
    set base $wname
    if {$base == ""} {
        set base "."
    }

    label $wname.tool_lbl -text "Tool to use"
    mlcnc_tool_selector_widget $wname.tool

    label $wname.diam_lbl -text "Diameter of Cylinder"
    spinbox $wname.diam -width 7 -format "%.4f" \
        -from 0.0 -to 99.9999 -increment 0.1 \
	-validate all -validatecommand "string is double %P"

    label $wname.width_lbl -text "Length of Indicator Lines"
    spinbox $wname.width -width 7 -format "%.4f" \
        -from 0.0 -to 99.9999 -increment 0.05 \
	-validate all -validatecommand "string is double %P"

    label $wname.cut_lbl -text "Depth of Indicator Lines"
    spinbox $wname.cut -width 7 -format "%.4f" \
        -from 0.0 -to 0.9999 -increment 0.001 \
	-validate all -validatecommand "string is double %P"

    button $wname.gen -text "Generate G-Code" -command [list mlcnc_g_degree_lines_on_cylinder_gui_gen $wname]

    $wname.diam  set [format [$wname.diam  cget -format] 2.0]
    $wname.width set [format [$wname.width cget -format] 0.25]
    $wname.cut   set [format [$wname.cut   cget -format] 0.002]

    grid columnconfigure $base 0 -minsize 25
    grid columnconfigure $base 2 -minsize 10
    grid columnconfigure $base 3 -weight 1
    grid columnconfigure $base 4 -minsize 25
    grid rowconfigure $base 0 -minsize 25
    grid rowconfigure $base 2 -minsize 20
    grid rowconfigure $base 4 -minsize 20
    grid rowconfigure $base 6 -minsize 20
    grid rowconfigure $base 8 -minsize 20
    grid rowconfigure $base 10 -minsize 25 -weight 1

    grid configure x $wname.tool_lbl  x $wname.tool  x -sticky w  -row 1
    grid configure x $wname.diam_lbl  x $wname.diam  x -sticky w  -row 3
    grid configure x $wname.width_lbl x $wname.width x -sticky w  -row 5
    grid configure x $wname.cut_lbl   x $wname.cut   x -sticky w  -row 7
    grid configure x $wname.gen       - -            x -sticky ew -row 9

    return $base
}


#mlcnc_register_wizard "Creating degree lines on a cylinder" \
#    mlcnc_g_degrees_on_cylinder {
#        diam     "Diameter of cylinder"
#        width    "Longest indicator line length"
#        cutdepth "Milling depth of indicator lines"
#    } mlcnc_g_degree_lines_on_cylinder_gui_create


