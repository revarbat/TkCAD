proc ruler_create {wname canv orient} {
    global rulerInfo
    set rulerwidth 32.0
    set rulerInfo(CANVAS-$wname) $canv
    set rulerInfo(ORIENT-$wname) $orient
    set rulerInfo(RULERWIDTH-$wname) $rulerwidth
    set rulerInfo(POS-$wname) 0.0
    canvas $wname -borderwidth 0 -highlightthickness 0 \
        -relief flat -width $rulerwidth -height $rulerwidth \
        -confine 0
    return $wname
    ruler_redraw $wname
}


proc ruler_format_fractions {val unit} {
    set out ""
    if {$val < 0.0} {
        append out "-"
        set val [expr {-$val}]
    }
    set whole [expr {sign($val)*int(abs($val)+1e-6)}]
    if {$out != "" || $whole != 0 || abs($val) < 1e-6} {
        # show whole numbers or zero.
        append out [format "%d" $whole]
    }
    if {$unit == "'"} {
        set val [expr {12.0*abs($val-$whole)}]
        set inches [expr {int(1e-6+$val)}]
        set denom 512
        set val [expr {$denom*abs($val-$inches)}]
        set numer [expr {int(0.5+$val)}]
        if {$numer > 0.0 || $inches != 0} {
            if {$out != ""} {
                append out $unit
            }
            while {$denom > 1 && $numer % 2 == 0} {
                set numer [expr {$numer/2}]
                set denom [expr {$denom/2}]
            }
            set fracstr ""
            if {$numer > 0} {
                if {$inches != 0} {
                    append fracstr " "
                }
                append fracstr [format "%d/%d" $numer $denom]
            }
            if {[string length $fracstr] > 3} {
                if {$inches != 0} {
                    append out [format " %d" $inches]
                }
                if {$fracstr != ""} {
                    append out "\n"
                }
            } else {
                if {$inches != 0 || $fracstr != ""} {
                    append out "\n"
                }
                if {$inches != 0} {
                    append out [format "%d" $inches]
                    if {$fracstr != ""} {
                        append out " "
                    }
                }
            }
            append out $fracstr
            if {$fracstr != "" || $inches != 0} {
                append out "\""
            }
        } else {
            append out $unit
            append out "\n"
        }
    } else {
        set denom 512.0
        set numer [expr {int(0.5+$denom*abs($val-$whole))}]
        if {$numer > 0.0} {
            while {$denom > 1.0 && $numer % 2 == 0} {
                set numer [expr {$numer/2}]
                set denom [expr {$denom/2}]
            }
            append out "\n"
            append out [format "%d/%d" $numer [expr {int($denom)}]]
            append out $unit
        } else {
            append out $unit
            append out "\n"
        }
    }
    return $out
}


proc ruler_format_decimal {val unit} {
    if {abs($val) < 1e-6} {
        set out 0
        append out $unit
        set out [string trim $out]
    } elseif {$unit == "'"} {
        set whole [expr {int($val)}]
        set denom 12.0
        set numer [expr {int($denom*abs($val-$whole)+0.5)}]

        set out ""
        if {$whole != 0 || abs($val) < 1e-6} {
            append out [format "%d" $whole]
            append out $unit
        }
        append out " "
        if {$numer > 0.0} {
            append out [format "%d\"" [expr {int($numer)}]]
        }
        set out [string trim $out]
        if {[string length $whole] > 2} {
            set out [string map {" " "\n"} $out]
        }
    } else {
        set out [format "%.6g" $val]
        if {[string length $unit] + [string length [string trim $out]] <= 4} {
            append out [string trim $unit]
        }
        if {[string length $out] > 6} {
            set out [string map {"." ".\n"} $out]
        }
    }
    return $out
}


proc ruler_redraw {ruler} {
    global rulerInfo
    set canv $rulerInfo(CANVAS-$ruler)
    set orient $rulerInfo(ORIENT-$ruler)
    set rulerwidth $rulerInfo(RULERWIDTH-$ruler)
    set pos $rulerInfo(POS-$ruler)

    set font {helvetica 8}
    set rulerbg white

    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    foreach {minorspacing majorspacing superspacing labelspacing divisor units formatfunc conversion} \
        [cadobjects_grid_info $canv] break

    set scalemult [expr {$dpi*$scalefactor/$conversion}]
    set srx0 [$canv canvasx 0]
    set sry0 [$canv canvasy 0]
    set srx1 [$canv canvasx [winfo width $canv]]
    set sry1 [$canv canvasy [winfo height $canv]]

    $ruler delete "RulerPos"
    if {$orient == "vertical"} {
        set ystart [expr {$sry1/-$scalemult}]
        set yend   [expr {$sry0/-$scalemult}]
        set x0     -1.0
        set y0     -1.0
        set x1     [expr {$x0+$rulerwidth}]
        set y1     [expr {$y0+($sry1-$sry0)}]

        $ruler delete "RulerY"
        $ruler create rectangle $x0 $y0 $x1 $y1 -fill $rulerbg -outline $rulerbg -width 0 -tags {RulerY RulerBG}
        $ruler create line $x1 $y1 $x1 0 0 0 -fill black -tags {RulerY RulerFG}
        set ys [expr {floor($ystart/$minorspacing+1e-6)*$minorspacing}]
        for {} {$ys <= $yend} {set ys [expr {$ys+$minorspacing}]} {
            set ypos [expr {-$scalemult*$ys-$sry0}]
            if {abs(floor($ys/$labelspacing+1e-6)-$ys/$labelspacing) < 1e-3} {
                set ticklen 6
                set xpos [expr {$x1-$ticklen-1}]
                set majortext [$formatfunc [expr {$ys/$divisor}] $units]
                set majortext [string trim $majortext]
                $ruler create text $xpos $ypos -text $majortext -anchor e -justify center -fill black -tags {RulerY RulerFG} -font $font
            } elseif {abs(floor($ys/$majorspacing+1e-6)-$ys/$majorspacing) < 1e-3} {
                set ticklen 4
            } else {
                set ticklen 2
            }
            set xpos [expr {$x1-$ticklen}]
            $ruler create line $x1 $ypos $xpos $ypos -fill black -tags {RulerY RulerFG}
        }
        set ypos [expr {-$scalemult*$pos-$sry0}]
        $ruler create line $x0 $ypos $x1 $ypos -fill "#ff4fff" -tags {RulerY RulerPos}
    } else {
        set xstart [expr {$srx0/$scalemult}]
        set xend   [expr {$srx1/$scalemult}]
        set x0     -1.0
        set y0     -1.0
        set x1     [expr {$x0+($srx1-$srx0)}]
        set y1     [expr {$y0+$rulerwidth}]

        $ruler delete "RulerX"
        $ruler create rectangle $x0 $y0 $x1 $y1 -fill $rulerbg -outline $rulerbg -width 0 -tags {RulerX RulerBG}
        $ruler create line $x1 $y1 0 $y1 0 0 -fill black -tags {RulerX RulerFG}
        set xs [expr {floor($xstart/$minorspacing+1e-6)*$minorspacing}]
        for {} {$xs <= $xend} {set xs [expr {$xs+$minorspacing}]} {
            set xpos [expr {$scalemult*$xs-$srx0}]
            if {abs(floor($xs/$labelspacing+1e-6)-$xs/$labelspacing) < 1e-3} {
                set ticklen 6
                set ypos [expr {$y1-$ticklen}]
                set majortext [$formatfunc [expr {$xs/$divisor}] $units]
                $ruler create text $xpos $ypos -text $majortext -anchor s -justify center -fill black -tags {RulerX RulerFG} -font $font
            } elseif {abs(floor($xs/$majorspacing+1e-6)-$xs/$majorspacing) < 1e-3} {
                set ticklen 4
            } else {
                set ticklen 2
            }
            set ypos [expr {$y1-$ticklen}]
            $ruler create line $xpos $y1 $xpos $ypos -fill black -tags {RulerX RulerFG}
        }
        set xpos [expr {$scalemult*$pos-$srx0}]
        $ruler create line $xpos $y0 $xpos $y1 -fill "#ff4fff" -tags {RulerX RulerPos}
    }
    $ruler raise RulerBG
    $ruler raise RulerPos
    $ruler raise RulerFG
    return
}



proc ruler_update_mousepos {ruler pos} {
    global rulerInfo
    set canv $rulerInfo(CANVAS-$ruler)
    set orient $rulerInfo(ORIENT-$ruler)
    set rulerwidth $rulerInfo(RULERWIDTH-$ruler)
    set rulerInfo(POS-$ruler) $pos

    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    foreach {minorspacing majorspacing superspacing labelspacing divisor units formatfunc conversion} \
        [cadobjects_grid_info $canv] break

    set scalemult [expr {$dpi*$scalefactor/$conversion}]
    set srx0 [$canv canvasx 0]
    set sry0 [$canv canvasy 0]
    set srx1 [$canv canvasx [winfo width $canv]]
    set sry1 [$canv canvasy [winfo height $canv]]

    $ruler delete "RulerPos"
    if {$orient == "vertical"} {
        set x0     -1.0
        set x1     [expr {$x0+$rulerwidth}]

        set ypos [expr {-$scalemult*$pos-$sry0}]
        $ruler create line $x0 $ypos $x1 $ypos -fill "#ff4fff" -tags {RulerY RulerPos}
    } else {
        set y0     -1.0
        set y1     [expr {$y0+$rulerwidth}]

        set xpos [expr {$scalemult*$pos-$srx0}]
        $ruler create line $xpos $y0 $xpos $y1 -fill "#ff4fff" -tags {RulerX RulerPos}
    }
    $ruler raise RulerBG
    $ruler raise RulerPos
    $ruler raise RulerFG
    return
}



# vim: set ts=4 sw=4 nowrap expandtab: settings

