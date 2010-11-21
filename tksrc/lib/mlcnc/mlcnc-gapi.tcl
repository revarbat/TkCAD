proc mlcnc_path_inset_recurse {path inset} {
    set near [expr {abs($inset)*1.4}]

    set pathbreaks(ISOLATED) {}
    set gcode {}

    set paths [mlcnc_path_inset $path $inset]
    set path [mlcnc_breakup_long_lines $path $inset]
    foreach subpath $paths {
        foreach {lx ly} [mlcnc_find_last_path_point_near_path $path $subpath $near] break
        if {$lx != "" && $ly != ""} {
            foreach {px py} [mlcnc_closest_point_on_path $subpath $lx $ly] break
            set subpath [mlcnc_reorder_polygon_path_by_point $subpath $px $py]
            set subpath [mlcnc_path_remove_repeated_points $subpath]
            lappend pathbreaks($lx,$ly) $subpath
        } else {
            # Shouldn't ever occur, I think.
            lappend pathbreaks(ISOLATED) $subpath
        }
    }

    foreach {x y} [lrange $path 0 1] break
    append gcode [format "G1 X%.5f Y%.5f\n" $x $y]
    foreach {x y} [lrange $path 2 end] {
        append gcode [format "G1 X%.5f Y%.5f\n" $x $y]
        if {[info exists pathbreaks($x,$y)]} {
            foreach subpath $pathbreaks($x,$y) {
                append gcode "\n"
                append gcode [mlcnc_path_inset_recurse $subpath $inset]
                append gcode "\n"
            }
            unset pathbreaks($x,$y)
            append gcode [format "G1 X%.5f Y%.5f\n" $x $y]
        }
    }
    append gcode "\n"

    # Commented out to reduce non-spiral paths.  Shouldn't occur anyways.
    #foreach subpath $pathbreaks(ISOLATED) {
    #    set subpath [mlcnc_path_remove_repeated_points $subpath]
    #    append gcode [mlcnc_g_goto [lindex $subpath 0] [lindex $subpath 1]]
    #    append gcode [format "G1 Z%.5f F#1000\n" $z]
    #    append gcode "F#1001\n"
    #    append gcode [mlcnc_path_inset_recurse $subpath $inset]
    #}

    return $gcode
}


# -------------------------------------------------------------------------
#  User API
# -------------------------------------------------------------------------

proc mlcnc_g_start {} {
    set material [mlcnc_stock_material]

    set out {}
    set matesc [string map {( [ ) ]} $material]
    append out "( Optimized for $matesc stock )\n"
    append out "\n"
    append out "G90 G17 G20 G40\n"
    return $out
}


proc mlcnc_g_set_tool {toolnum} {
    mlcnc_select_tool $toolnum

    set diam     [mlcnc_tooldiam]
    set speed    [mlcnc_rpm]
    set gearnum  [mlcnc_gearnum]
    set plunge   [mlcnc_feed -plunge]
    set feed     [mlcnc_feed]
    set cutdepth [mlcnc_cutdepth]

    set diamdivisor 128
    set diamdenom   [expr {int($diam*($diamdivisor+0.0)+0.5)}]
    set diamwhole   ""
    while {$diamdenom % 2 == 0 && $diamdenom != 0} {
        set diamdenom [expr {$diamdenom/2}]
        set diamdivisor [expr {$diamdivisor/2}]
    }
    if {$diamdenom > $diamdivisor} {
        set diamwhole [expr {$diamdenom/$diamdivisor}]
        set diamdenom [expr {$diamdenom%$diamdivisor}]
        append diamwhole " "
    }
    if {$diamdenom == 0} {
        set diamdivisor "0"
    }

    set out {}
    append out [format "\n"]
    append out [format "M9           ( Stop coolant. )\n"]
    append out [format "M5           ( Stop spindle. )\n"]
    append out [format "M6T%-6.0f    ( %.4f or %s%d/%d inches tool diam )\n" $toolnum $diam $diamwhole $diamdenom $diamdivisor]
    if {$gearnum != 0} {
        append out [format "( Use gear or pulley %d \[1 would be slowest\] )\n" $gearnum]
    }
    append out [format "S%-6.0f      ( RPM spindle speed )\n" $speed]
    append out [format "#1000=%-6.1f ( IPM plunge feed )\n" $plunge]
    append out [format "#1001=%-6.1f ( IPM regular feed )\n" $feed]
    append out [format "#1002=%-6.4f ( inches optimal cut depth )\n" $cutdepth]
    append out [format "M3           ( Spin spindle clockwise. )\n"]
    append out [format "M8           ( Start flood Coolant. )\n"]

    return $out
}


proc mlcnc_g_plunge {x y z} {
    set top [mlcnc_stock_top]
    if {$z > $top} {
        return
    }
    set rapid_z [mlcnc_rapid_z]
    set maxdepth [mlcnc_cutdepth -plunge]
    set curz $top
    set out {}
    append out [mlcnc_g_goto $x $y]
    while {$curz-$maxdepth > $z} {
        set curz [expr {$curz-$maxdepth}]
        append out [format "G1 Z%.5f F#1001\n" $curz]
        append out [format "G0 Z%.5f\n" $top]
    }
    append out [format "G1 Z%.5f\n" $z]
    return $out
}


proc mlcnc_g_goto {x y} {
    set out {}
    set rapid_z [mlcnc_rapid_z]
    set top [mlcnc_stock_top]
    append out [format "G0 Z%.5f\n" $rapid_z]
    append out [format "G0 X%.5f Y%.5f\n" $x $y]
    append out [format "G0 Z%.5f\n" [expr {$top+0.05}]]
    return $out
}


proc mlcnc_g_follow_path {path} {
    set gcode {}
    foreach {x y} $path {
        append gcode [format "G1 X%.5f Y%.5f\n" $x $y]
    }
    append gcode "\n"
    return $gcode
}


proc mlcnc_g_circle_nofinish {x y z cutdepth orad irad} {
    set out {}

    set top [mlcnc_stock_top]
    if {$z > $top} {
        return
    }
    set rapid_z [mlcnc_rapid_z]
    set tooldiam [mlcnc_tooldiam]
    set cutwidth [expr {$tooldiam/2.0}]
    set plunge   [mlcnc_feed -plunge]
    set feed     [mlcnc_feed]

    #set deltaz [expr {($top-$z)/ceil(($top-$z)/$cutdepth)}]
    set deltaz $cutdepth
    set deltar [expr {($orad-$irad)/ceil(0.000001+($orad-$irad)/$cutwidth)}]
    constants pi

    set doplunge 0
    set firstcut 1
    set curz $top
    while {1} {
        set prevz $curz
        set curz [expr {$curz-$deltaz}]
        if {$curz < $z+2e-3} {
            set curz $z
            set doplunge 1
        }
        set midz [expr {($curz+$prevz)/2}]

        set crad $orad
        set rx [expr {$x+$crad}]

        if {abs($orad) >= 0.0005 || $firstcut} {
            append out [format "G0 X%.5f Y%.5f\n" $rx $y]
        }
        if {$firstcut} {
            append out [format "G0 Z%.5f\n" [expr {$top+0.01}]]
            append out [format "G1 Z%.5f F#1000\n" $top]
            set firstcut 0
        }

        if {abs($orad) >= 0.0005} {
            if {abs(($deltaz/2.0)/$plunge) > abs(2.0*$pi*$orad/$feed)} {
                set feedrate "#1000" ; # Use plunge feed rate.
            } else {
                set feedrate "#1001" ; # Use regular feed rate.
            }

            # Helix down into piece in two steps, to compensate for full cutwidth.
            append out [format "G2 X%.5f Y%.5f Z%.5f I%.7f F%s ( Helix plunge )\n" $rx $y $midz -$crad $feedrate]

            if {$doplunge} {
                # If near bottom, just finish up.  Helps with cutouts.
                append out [format "G1 Z%.5f F#1000\n" $curz]
            }

            append out [format "G2 X%.5f Y%.5f Z%.5f I%.7f F%s\n\n" $rx $y $curz -$crad $feedrate]

            if {$deltar > 0.0} {
                # Close in on inner circle
                set cang 0.0
                set spiral_offset [expr {$deltar/8.0}]
                append out [format "G2 X%.5f Y%.5f I%.7f F#1001\n" $rx $y -$crad]
                while {$crad-(2.0*$spiral_offset) >= $irad-0.000001} {
                    set crad2 [expr {$crad-$spiral_offset}]
                    set crad3 [expr {$crad2-$spiral_offset}]
                    set px1 [expr {$x+$crad*cos($cang)}]
                    set py1 [expr {$y+$crad*sin($cang)}]
                    set px2 [expr {$x+$crad2*cos($cang-$pi/4.0)}]
                    set py2 [expr {$y+$crad2*sin($cang-$pi/4.0)}]
                    set px3 [expr {$x+$crad3*cos($cang-$pi/2.0)}]
                    set py3 [expr {$y+$crad3*sin($cang-$pi/2.0)}]
                    foreach {cx cy rad sang eang} [mlcnc_find_arc_from_points $px1 $py1 $px2 $py2 $px3 $py3] break
                    set dx [expr {$cx-$px1}]
                    set dy [expr {$cy-$py1}]
                    append out [format "G2 X%.5f Y%.5f R%.5f F#1001 ( spiral in )\n" $px3 $py3 $rad]
                    set cang [expr {fmod($cang-($pi/2.0),2.0*$pi)}]
                    set crad $crad3
                }
                set rx [expr {$x+$irad}]
                append out [format "\nG0 X%.5f Y%.5f F#1001\n" $rx $y]
                append out [format "G2 X%.5f Y%.5f I%.7f ( Finish inside )\n" $rx $y -$irad]
            }
        } else {
            # Circle too small; Do peck drill instead
            append out [format "G1 Z%.5f F#1000\n" $curz]
            append out [format "G0 Z%.5f\n" [expr {$top+0.01}]]
        }

        if {$curz <= $z} break
    }

    # Return to safe rapid-Z height
    append out [format "G0 Z%.5f\n" $rapid_z]

    return $out
}


proc mlcnc_g_circle {x y z orad irad {finish "outside"}} {
    set out {}

    set top [mlcnc_stock_top]
    if {$z > $top} {
        return
    }
    set rapid_z [mlcnc_rapid_z]
    set tooldiam [mlcnc_tooldiam]
    set cutwidth [expr {$tooldiam/2.0}]
    set cutdepth [mlcnc_cutdepth -cutwidth $cutwidth]

    set orad [expr {$orad-$tooldiam/2.0}]
    if {$orad <= -1e-6} {
        if {$finish == "both" || $finish == "outside"} {
            error "Cutting tool is too large of diameter for the given circle's size and required finish constraints."
        }
    }
    if {abs($irad) >= 1e-6} {
        set irad [expr {$irad+$tooldiam/2.0}]
    } else {
        set irad [expr {$cutwidth/2.0}]
        if {$finish == "both" || $finish == "outside"} {
            set finish "outside"
        } else {
            set finish "none"
        }
    }

    set finishwidth 0.002
    if {$finish == "neither" || $finish == "none"} {
        set finishwidth 0.000
    }
    set f_irad $irad
    set f_orad $orad
    if {$orad <= $irad - 1e-6} {
        switch -exact -- $finish {
            "neither" -
            "none" {
                set arad [expr {($orad+$irad)/2.0}]
                set f_irad $arad
                set f_orad $arad
                set irad $arad
                set orad $arad
            }
            "inside" {
                set orad $irad
                set f_orad $irad
                set f_irad $irad
            }
            "outside" {
                set irad $orad
                set f_orad $orad
                set f_irad $orad
            }
            "both" {
                error "Cutting tool is too large of diameter for the given circle's size and required finish constraints."
            }
            default {
                error "'finish' must be one of inside, outside, both, or neither."
            }
        }
        set finishwidth 0.0
    } elseif {$orad-$irad < 2.0*$finishwidth} {
        set finishwidth [expr {abs($orad-$irad)/2.0}]
    }
    if {$finishwidth*3>$cutwidth} {
        set finishwidth [expr {$cutwidth/2.0}]
    }
    set irad [expr {$f_irad+$finishwidth}]
    set orad [expr {$f_orad-$finishwidth}]

    set finishdepth [mlcnc_cutdepth -cutwidth $finishwidth]

    append out "\n"
    append out [format "G0 Z%.5f\n" $rapid_z]
    append out [mlcnc_g_circle_nofinish $x $y $z $cutdepth $orad $irad]
    if {$finishwidth > 1e-6} {
        if {$finish == "outside" || $finish == "both"} {
            append out [mlcnc_g_circle_nofinish $x $y $z $finishdepth $f_orad $f_orad]
        }
        if {$finish == "inside" || $finish == "both"} {
            append out [mlcnc_g_circle_nofinish $x $y $z $finishdepth $f_irad $f_irad]
        }
    }

    return $out
}


proc mlcnc_g_rectangle {x1 y1 x2 y2 z {finish 1}} {
    set out {}

    set top [mlcnc_stock_top]
    if {$z > $top} {
        return
    }
    set rapid_z [mlcnc_rapid_z]
    set tooldiam [mlcnc_tooldiam]
    set cutwidth [expr {$tooldiam/2.2}]
    set cutdepth [mlcnc_cutdepth]

    if {$x1 > $x2} {
        set tmp $x1
        set x1 $x2
        set x2 $tmp
    }

    if {$y1 > $y2} {
        set tmp $y1
        set y1 $y2
        set y2 $tmp
    }

    set finishwidthx 0.002
    if {$x2 - $x1 < $tooldiam} {
        if {$finish} {
            error "Cutting tool is too large of diameter for the given rectangle's size and required finish constraints."
        } else {
            set x [expr {($x1+$x2)/2.0}]
            set x1 [expr {$x-$cutwidth}]
            set x2 [expr {$x+$cutwidth}]
            set finishwidthx 0.0
        }
    } elseif {$x2-$x1 < $tooldiam+$finishwidthx} {
        set finishwidthx [expr {($x2-$x1-$tooldiam)/2.0}]
    }

    set finishwidthy 0.002
    if {$y2 - $y1 < $tooldiam} {
        if {$finish} {
            error "Cutting tool is too large of diameter for the given rectangle's size and required finish constraints."
        } else {
            set y [expr {($y1+$y2)/2.0}]
            set y1 [expr {$y-$cutwidth}]
            set y2 [expr {$y+$cutwidth}]
            set finishwidthy 0.0
        }
    } elseif {$y2-$y1 < $tooldiam+$finishwidthy} {
        set finishwidthy [expr {($y2-$y1-$tooldiam)/2.0}]
    }

    set x1 [expr {$x1+$cutwidth}]
    set x2 [expr {$x2-$cutwidth}]
    set y1 [expr {$y1+$cutwidth}]
    set y2 [expr {$y2-$cutwidth}]

    append out [format "G0 Z%.4f\n" $rapid_z]

    set curz [expr {$top-$cutdepth}]
    while {1} {
        if {$curz < $z+0.02} {
            set curz $z
        }

        set minx [expr {$x1+$finishwidthx}]
        set maxx [expr {$x2-$finishwidthx}]
        set miny [expr {$y1+$finishwidthy}]
        set maxy [expr {$y2-$finishwidthy}]

        append out [format "G0 X%.5f Y%.5f\n" $minx $miny]
        append out [format "G0 Z%.5f\n" [expr {$top+0.01}]]
        append out [format "G1 Z%.5f F#1000\n" $curz]
        append out "F#1001\n"
        
        while {$minx < $maxx && $miny < $maxy} {
            if {$maxx > $minx} {
                append out [format "G1 X%.5f\n" $maxx]
                set miny [expr {$miny+$cutwidth}]
            }
            if {$maxy > $miny} {
                append out [format "G1 Y%.5f\n" $maxy]
                set maxx [expr {$maxx-$cutwidth}]
            }
            if {$maxx > $minx} {
                append out [format "G1 X%.5f\n" $minx]
                set maxy [expr {$maxy-$cutwidth}]
            }
            if {$maxy > $miny} {
                append out [format "G1 Y%.5f\n" $miny]
                set minx [expr {$minx+$cutwidth}]
            }
        }
        append out [format "G1 X%.5f Y%.5f\n" $x1 $y1]
        if {$finishwidthx > 0.0} {
            append out [format "G1 X%.5f\n" $x2]
        }
        if {$finishwidthy > 0.0} {
            append out [format "G1 Y%.5f\n" $y2]
        }
        if {$finishwidthx > 0.0} {
            append out [format "G1 X%.5f\n" $x1]
        }
        if {$finishwidthy > 0.0} {
            append out [format "G1 Y%.5f\n" $y1]
        }

        if {$curz == $z} {
            break
        }
        append out [format "G0 Z%.5f\n" [expr {$top+0.01}]]
        set curz [expr {$curz-$cutdepth}]
    }

    return $out
}


proc mlcnc_g_polygon {path z {finish 1}} {
    if {[llength $path] < 4} {
        error "path must have at least two X Y coordinate pairs. (4 floats minimum)"
    }
    if {[llength $path] % 2} {
        error "path must have an even number of floats, so every X has a Y value."
    }

    set finishwidth 0.002
    set out {}
    set top [mlcnc_stock_top]
    if {$z > $top} {
        return
    }
    set rapid_z [mlcnc_rapid_z]
    set tooldiam [mlcnc_tooldiam]
    set toolrad [expr {$tooldiam/2.0}]

    # TODO: reduce cutwidth based on material hardness.
    # Base on Vickers or Brinell hardness scales maybe?
    set cutwidth [expr {$tooldiam/3.0}]
    set cutdepth [mlcnc_cutdepth]

    set path [mlcnc_path_remove_repeated_points $path]
    set paths [mlcnc_path_inset $path $toolrad]

    set finishpaths {}
    if {$finish} {
        set finishpaths $paths
        set newpaths {}
        foreach subpath $paths {
            set subpaths [mlcnc_path_inset $subpath $finishwidth]
            foreach newpath $subpaths {
                lappend newpaths $newpath
            }
        }
        set paths $newpaths
        unset newpaths
    }

    append out [format "G0 Z%.4f\n" $rapid_z]

    foreach subpath $paths {
        if {[llength $subpath] % 2} {
            error "Say what?  count = [llength $subpath].  Should be even."
        }
        if {$subpath != {}} {
            set subpath [mlcnc_path_remove_repeated_points $subpath]
            set pocketcode [mlcnc_path_inset_recurse $subpath $cutwidth]
            append out [mlcnc_g_goto [lindex $subpath 0] [lindex $subpath 1]]
            set curz [expr {$top-$cutdepth}]
            while {1} {
                if {$curz < $z+0.02} {
                    set curz $z
                }
                append out [format "G1 Z%.5f F#1000\n" $curz]
                append out "F#1001\n"
                append out $pocketcode
                if {$curz == $z} {
                    break
                }
                set curz [expr {$curz-$cutdepth}]
            }
        }
        append out [format "G0 Z%.5f\n" [expr {$top+0.01}]]
    }

    if {$finish} {
        set cutdepth [mlcnc_cutdepth -cutwidth $finishwidth]
        foreach subpath $finishpaths {
            if {$subpath != {}} {
                set subpath [mlcnc_path_remove_repeated_points $subpath]
                set finishcode [mlcnc_g_follow_path $subpath]
                append out [mlcnc_g_goto [lindex $subpath 0] [lindex $subpath 1]]
                set curz [expr {$top-$cutdepth}]
                while {1} {
                    if {$curz < $z+0.02} {
                        set curz $z
                    }
                    append out [format "G1 Z%.5f F#1000\n" $curz]
                    append out "F#1001\n"
                    append out $finishcode
                    if {$curz == $z} {
                        break
                    }
                    set curz [expr {$curz-$cutdepth}]
                }
            }
            append out [format "G0 Z%.5f\n" [expr {$top+0.1}]]
        }
    }

    return $out
}


proc mlcnc_g_path {path z {offset "none"}} {
    if {[llength $path] < 4} {
        error "path must have at least two X Y coordinate pairs. (4 floats minimum)"
    }
    if {[llength $path] % 2} {
        error "path must have an even number of floats, so every X has a Y value."
    }
    if {$offset != "none" && $offset != "left" && $offset != "right"} {
        error "Offset must be 'left', 'right', or 'none'."
    }

    set out {}
    set top [mlcnc_stock_top]
    if {$z > $top} {
        return
    }
    set rapid_z [mlcnc_rapid_z]
    set tooldiam [mlcnc_tooldiam]
    set toolrad [expr {$tooldiam/2.0}]
    set cutdepth [mlcnc_cutdepth -cutwidth $tooldiam]

    set path [mlcnc_path_remove_repeated_points $path]

    if {$offset == "right"} {
        set path [lindex [mlcnc_path_offset $path -$toolrad] 0]
    } elseif {$offset == "left"} {
        set path [lindex [mlcnc_path_offset $path $toolrad] 0]
    }

    set pathcode [mlcnc_g_follow_path [lrange $path 2 end]]
    lassign [lrange $path 0 1] x0 y0
    lassign [lrange $path end-1 end] xe ye
    set endstart 0
    if {hypot($ye-$y0,$xe-$x0) < 1e-3} {
        set endstart 1
    }

    set first 1
    set curz [expr {$top-$cutdepth}]
    while {1} {
        if {$curz < $z+0.02} {
            set curz $z
        }
        if {$first || !$endstart} {
            append out [mlcnc_g_goto $x0 $y0]
        }
        append out [format "G1 Z%.5f F#1000\n" $curz]
        append out "F#1001\n"
        append out $pathcode
        append pathcode "\n"
        if {$curz == $z} {
            break
        }
        set curz [expr {$curz-$cutdepth}]
        set first 0
    }
    append out [format "G0 Z%.5f\n" $rapid_z]

    return $out
}


# vim: set ts=4 sw=4 nowrap expandtab: settings

