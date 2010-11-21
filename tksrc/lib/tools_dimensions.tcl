proc plugin_dimlineh_initobj {canv objid coords} {
    cadobjects_object_setdatum $canv $objid "LINEWIDTH" "0.0"
    set dimlayername "Dimensions"
    set dimlayer [layer_name_id $canv $dimlayername]
    if {$dimlayer == ""} {
        set dimlayer [layer_create $canv $dimlayername]
    }
    cadobjects_object_setlayer $canv $objid $dimlayer
    mainwin_update_layerwin [cadobjects_mainwin $canv]
}


proc plugin_dimlineh_drawobj {canv objid coords tags color fill width dash} {
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_dimlineh_editfields {canv objid coords} {
    set out {}
    lappend out {
        type POINT
        name STARTPT
        datum #0
        title "Start Point"
    }
    lappend out {
        type POINT
        name ENDPT
        datum #1
        title "End Point"
    }
    lappend out {
        type FLOAT
        name LENGTH
        datum ""
        title "Length"
        min 0.0
        max 1e9
        increment 0.125
        width 8
        maxcoords 2
        valgetcb "plugin_dimlineh_getfield"
        valsetcb "plugin_dimlineh_setfield"
        islength 1
    }
    return $out
}


proc plugin_dimlineh_getfield {canv objid coords field} {
    constants pi
    foreach {cx0 cy0 cx1 cy1} [lrange $coords 0 3] break
    switch -exact -- $field {
        LENGTH {
            set d [expr {$cx1-$cx0}]
            return $d
        }
    }
}


proc plugin_dimlineh_setfield {canv objid coords field val} {
    constants degtorad
    foreach {cx0 cy0 cx1 cy1} [lrange $coords 0 3] break
    set dist [expr {$cx1-$cx0}]

    switch -exact -- $field {
        LENGTH {
            set d 0.0
            if {$dist > 1e-6} {
                set d [expr {$val/$dist}]
            }
            set cx1 [expr {($cx1-$cx0)*$d+$cx0}]
            set coords [list $cx0 $cy0 $cx1 $cy1]
            cadobjects_object_set_coords $canv $objid $coords
        }
    }
}


proc plugin_dimlineh_drawctls {canv objid coords color fillcolor} {
    plugin_dimlineh_recalculate $canv $objid $coords
    set coords [cadobjects_object_get_coords $canv $objid]
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid LINE $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_dimlineh_recalculate {canv objid coords {flags ""}} {
    constants radtodeg
    if {[llength $coords] >= 6} {
        foreach {x0 y0 x1 y1 x2 y2} $coords break
        if {abs($x1-$x2)>1e-6} {
            set coords [list $x0 $y0 $x1 $y1 $x1 $y2]
            cadobjects_object_set_coords $canv $objid $coords
        }
    }
}


proc plugin_dimlineh_bbox {canv objid coords} {
    return [::math::geometry::bbox $coords]
}


proc plugin_dimlineh_decompose {canv objid coords allowed} {
    if {"LINES" in $allowed} {
        constants radtodeg

        set out {}
        foreach {x0 y0 x1 y1 x2 y2} $coords break
        set ang 0.0

        set elen1 [expr {abs($y2-$y0)}]
        set elen2 [expr {abs($y2-$y1)}]
        if {$elen1>0.2} {
            set gap1 0.05
            set elen1 [expr {$elen1+0.1}]
        } else {
            set gap1 [expr {$elen1*0.25}]
            set elen1 [expr {$elen1*1.5}]
        }
        if {$elen2>0.2} {
            set gap2 0.05
            set elen2 [expr {$elen2+0.1}]
        } else {
            set gap2 [expr {$elen2*0.25}]
            set elen2 [expr {$elen2*1.5}]
        }

        set tlen [expr {abs($y2-$y1)}]
        set dist [expr {abs($x1-$x0)}]

        set units "\""
        set txt [format "%.4f" $dist]
        set txt [string trimright $txt "0"]
        set txt [string trimright $txt "."]
        append txt $units

        set ffam "Courier"
        set fwid [font measure [list $ffam 8] -displayof $canv $txt]
        set twid [expr {$fwid/72.0}]
        if {$twid + 0.1 > $dist/2.0} {
            set fscl [expr {$dist*0.5/($twid+0.1)}]
            if {$fscl < 0.063} {
                set fscl 0.063
            }
            set fsiz [expr {int($fscl*8.0+0.5)}]
            set alen [expr {0.1*$fscl}]
        } else {
            set fsiz 8
            set fscl 1.0
            set alen 0.1
        }
        set font [cadobjects_object_getdatum $canv $objid "FONT"]
        if {$font != [list $ffam $fsiz]} {
            cadobjects_object_setdatum $canv $objid "FONT" [list $ffam $fsiz]
        }

        set fmid [expr {$fscl*3.0/72.0}]
        set tgap [expr {(abs($x1-$x0)-$twid*$fscl-0.05)*0.5}]

        # Perp endline 1
        if {$y2>$y0} {
            set py0 [expr {$y0+$gap1}]
            set py1 [expr {$y0+$elen1}]
        } else {
            set py0 [expr {$y0-$gap1}]
            set py1 [expr {$y0-$elen1}]
        }
        lappend out LINES [list $x0 $py0 $x0 $py1]

        # Perp endline 2
        if {$y2>$y1} {
            set py0 [expr {$y1+$gap2}]
            set py1 [expr {$y1+$elen2}]
        } else {
            set py0 [expr {$y1-$gap2}]
            set py1 [expr {$y1-$elen2}]
        }
        lappend out LINES [list $x1 $py0 $x1 $py1]

        # calc dimline endpoints
        if {$y2>$y1} {
            set ly [expr {$y1+$tlen}]
        } else {
            set ly [expr {$y1-$tlen}]
        }

        # Dimline with gap in middle
        foreach {px0 py0} [geometry_line_rot_point $x0 $ly $x1 $ly $tgap 0.0] break
        foreach {px1 py1} [geometry_line_rot_point $x1 $ly $x0 $ly $tgap 0.0] break
        lappend out LINES [list $x0 $ly $px0 $py0]
        lappend out LINES [list $x1 $ly $px1 $py1]

        # Dimline arrow 1
        foreach {ax1 ay1} [geometry_line_rot_point $x0 $ly $x1 $ly $alen  15.0] break
        foreach {ax2 ay2} [geometry_line_rot_point $x0 $ly $x1 $ly $alen -15.0] break
        lappend out LINES [list $x0 $ly $ax1 $ay1]
        lappend out LINES [list $x0 $ly $ax2 $ay2]

        # Dimline arrow 2
        foreach {ax1 ay1} [geometry_line_rot_point $x1 $ly $x0 $ly $alen  15.0] break
        foreach {ax2 ay2} [geometry_line_rot_point $x1 $ly $x0 $ly $alen -15.0] break
        lappend out LINES [list $x1 $ly $ax1 $ay1]
        lappend out LINES [list $x1 $ly $ax2 $ay2]

        # Dimension text
        set mx [expr {($x0+$x1)/2.0}]
        set my [expr {$ly-$fmid}]
        if {"ROTTEXT" in $allowed} {
            lappend out ROTTEXT [list $mx $my $txt [list $ffam $fsiz] "center" $ang]
        } elseif {"TEXT" in $allowed} {
            lappend out TEXT [list $mx $my $txt [list $ffam $fsiz] "center"]
        }

        return $out
    }
    return {}
}







proc plugin_dimlinev_initobj {canv objid coords} {
    cadobjects_object_setdatum $canv $objid "LINEWIDTH" "0.0"
    set dimlayername "Dimensions"
    set dimlayer [layer_name_id $canv $dimlayername]
    if {$dimlayer == ""} {
        set dimlayer [layer_create $canv $dimlayername]
    }
    cadobjects_object_setlayer $canv $objid $dimlayer
    mainwin_update_layerwin [cadobjects_mainwin $canv]
}


proc plugin_dimlinev_drawobj {canv objid coords tags color fill width dash} {
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_dimlinev_editfields {canv objid coords} {
    set out {}
    lappend out {
        type POINT
        name STARTPT
        datum #0
        title "Start Point"
    }
    lappend out {
        type POINT
        name ENDPT
        datum #1
        title "End Point"
    }
    lappend out {
        type FLOAT
        name LENGTH
        datum ""
        title "Length"
        min 0.0
        max 1e9
        increment 0.125
        width 8
        maxcoords 2
        valgetcb "plugin_dimlinev_getfield"
        valsetcb "plugin_dimlinev_setfield"
        islength 1
    }
    return $out
}


proc plugin_dimlinev_getfield {canv objid coords field} {
    constants pi
    foreach {cx0 cy0 cx1 cy1} [lrange $coords 0 3] break
    switch -exact -- $field {
        LENGTH {
            set d [expr {$cy1-$cy0}]
            return $d
        }
    }
}


proc plugin_dimlinev_setfield {canv objid coords field val} {
    constants degtorad
    foreach {cx0 cy0 cx1 cy1} [lrange $coords 0 3] break
    set dist [expr {$cy1-$cy0}]

    switch -exact -- $field {
        LENGTH {
            set d 0.0
            if {$dist > 1e-6} {
                set d [expr {$val/$dist}]
            }
            set cy1 [expr {($cy1-$cy0)*$d+$cy0}]
            set coords [list $cx0 $cy0 $cx1 $cy1]
            cadobjects_object_set_coords $canv $objid $coords
        }
    }
}


proc plugin_dimlinev_drawctls {canv objid coords color fillcolor} {
    plugin_dimlinev_recalculate $canv $objid $coords
    set coords [cadobjects_object_get_coords $canv $objid]
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid LINE $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_dimlinev_recalculate {canv objid coords {flags ""}} {
    constants radtodeg
    if {[llength $coords] >= 6} {
        foreach {x0 y0 x1 y1 x2 y2} $coords break
        if {abs($y1-$y2)>1e-6} {
            set coords [list $x0 $y0 $x1 $y1 $x2 $y1]
            cadobjects_object_set_coords $canv $objid $coords
        }
    }
}


proc plugin_dimlinev_bbox {canv objid coords} {
    return [::math::geometry::bbox $coords]
}


proc plugin_dimlinev_decompose {canv objid coords allowed} {
    if {"LINES" in $allowed} {
        constants radtodeg

        set out {}
        foreach {x0 y0 x1 y1 x2 y2} $coords break
        set ang 90.0

        set elen1 [expr {abs($x2-$x0)}]
        set elen2 [expr {abs($x2-$x1)}]
        if {$elen1>0.2} {
            set gap1 0.05
            set elen1 [expr {$elen1+0.1}]
        } else {
            set gap1 [expr {$elen1*0.25}]
            set elen1 [expr {$elen1*1.5}]
        }
        if {$elen2>0.2} {
            set gap2 0.05
            set elen2 [expr {$elen2+0.1}]
        } else {
            set gap2 [expr {$elen2*0.25}]
            set elen2 [expr {$elen2*1.5}]
        }

        set tlen [expr {abs($x2-$x1)}]
        set dist [expr {abs($y1-$y0)}]

        set units "\""
        set txt [format "%.4f" $dist]
        set txt [string trimright $txt "0"]
        set txt [string trimright $txt "."]
        append txt $units

        set ffam "Courier"
        set fwid [font measure [list $ffam 8] -displayof $canv $txt]
        set twid [expr {$fwid/72.0}]
        if {$twid + 0.1 > $dist/2.0} {
            set fscl [expr {$dist*0.5/($twid+0.1)}]
            if {$fscl < 0.063} {
                set fscl 0.063
            }
            set fsiz [expr {int($fscl*8.0+0.5)}]
            set alen [expr {0.1*$fscl}]
        } else {
            set fsiz 8
            set fscl 1.0
            set alen 0.1
        }
        set font [cadobjects_object_getdatum $canv $objid "FONT"]
        if {$font != [list $ffam $fsiz]} {
            cadobjects_object_setdatum $canv $objid "FONT" [list $ffam $fsiz]
        }

        set fmid [expr {$fscl*3.0/72.0}]
        set tgap [expr {(abs($y1-$y0)-$twid*$fscl-0.05)*0.5}]

        # Perp endline 1
        if {$x2>$x0} {
            set px0 [expr {$x0+$gap1}]
            set px1 [expr {$x0+$elen1}]
        } else {
            set px0 [expr {$x0-$gap1}]
            set px1 [expr {$x0-$elen1}]
        }
        lappend out LINES [list $px0 $y0 $px1 $y0]

        # Perp endline 2
        if {$x2>$x1} {
            set px0 [expr {$x1+$gap2}]
            set px1 [expr {$x1+$elen2}]
        } else {
            set px0 [expr {$x1-$gap2}]
            set px1 [expr {$x1-$elen2}]
        }
        lappend out LINES [list $px0 $y1 $px1 $y1]

        # calc dimline endpoints
        if {$x2>$x1} {
            set lx [expr {$x1+$tlen}]
        } else {
            set lx [expr {$x1-$tlen}]
        }

        # Dimline with gap in middle
        foreach {px0 py0} [geometry_line_rot_point $lx $y0 $lx $y1 $tgap 0.0] break
        foreach {px1 py1} [geometry_line_rot_point $lx $y1 $lx $y0 $tgap 0.0] break
        lappend out LINES [list $lx $y0 $px0 $py0]
        lappend out LINES [list $lx $y1 $px1 $py1]

        # Dimline arrow 1
        foreach {ax1 ay1} [geometry_line_rot_point $lx $y0 $lx $y1 $alen  15.0] break
        foreach {ax2 ay2} [geometry_line_rot_point $lx $y0 $lx $y1 $alen -15.0] break
        lappend out LINES [list $lx $y0 $ax1 $ay1]
        lappend out LINES [list $lx $y0 $ax2 $ay2]

        # Dimline arrow 2
        foreach {ax1 ay1} [geometry_line_rot_point $lx $y1 $lx $y0 $alen  15.0] break
        foreach {ax2 ay2} [geometry_line_rot_point $lx $y1 $lx $y0 $alen -15.0] break
        lappend out LINES [list $lx $y1 $ax1 $ay1]
        lappend out LINES [list $lx $y1 $ax2 $ay2]

        # Dimension text
        set mx [expr {$lx+$fmid}]
        set my [expr {($y0+$y1)/2.0}]
        if {"ROTTEXT" in $allowed} {
            lappend out ROTTEXT [list $mx $my $txt [list $ffam $fsiz] "center" $ang]
        } elseif {"TEXT" in $allowed} {
            lappend out TEXT [list $mx $my $txt [list $ffam $fsiz] "center"]
        }

        return $out
    }
    return {}
}







proc plugin_dimline_initobj {canv objid coords} {
    cadobjects_object_setdatum $canv $objid "LINEWIDTH" "0.0"
    set dimlayername "Dimensions"
    set dimlayer [layer_name_id $canv $dimlayername]
    if {$dimlayer == ""} {
        set dimlayer [layer_create $canv $dimlayername]
    }
    cadobjects_object_setlayer $canv $objid $dimlayer
    mainwin_update_layerwin [cadobjects_mainwin $canv]
}


proc plugin_dimline_drawobj {canv objid coords tags color fill width dash} {
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_dimline_editfields {canv objid coords} {
    set out {}
    lappend out {
        type POINT
        name STARTPT
        datum #0
        title "Start Point"
    }
    lappend out {
        type POINT
        name ENDPT
        datum #1
        title "End Point"
    }
    lappend out {
        type FLOAT
        name LENGTH
        datum ""
        title "Length"
        min 0.0
        max 1e9
        increment 0.125
        width 8
        maxcoords 2
        valgetcb "plugin_dimline_getfield"
        valsetcb "plugin_dimline_setfield"
        islength 1
    }
    lappend out {
        type FLOAT
        name ANGLE
        datum ""
        title "Angle"
        min -360.0
        max 360.0
        increment 5.0
        width 8
        maxcoords 2
        valgetcb "plugin_dimline_getfield"
        valsetcb "plugin_dimline_setfield"
    }
    return $out
}


proc plugin_dimline_getfield {canv objid coords field} {
    constants pi
    foreach {cx0 cy0 cx1 cy1} [lrange $coords 0 3] break
    switch -exact -- $field {
        LENGTH {
            set d [expr {hypot($cy1-$cy0,$cx1-$cx0)}]
            return $d
        }
        ANGLE {
            set d [expr {atan2($cy1-$cy0,$cx1-$cx0)*180.0/$pi}]
            return $d
        }
    }
}


proc plugin_dimline_setfield {canv objid coords field val} {
    constants degtorad
    foreach {cx0 cy0 cx1 cy1} [lrange $coords 0 3] break
    set dist [expr {hypot($cy1-$cy0,$cx1-$cx0)}]

    switch -exact -- $field {
        ANGLE {
            set cx1 [expr {$dist*cos($val*$degtorad)+$cx0}]
            set cy1 [expr {$dist*sin($val*$degtorad)+$cy0}]
            set coords [list $cx0 $cy0 $cx1 $cy1]
            cadobjects_object_set_coords $canv $objid $coords
        }
        LENGTH {
            set d 0.0
            if {$dist > 1e-6} {
                set d [expr {$val/$dist}]
            }
            set cx1 [expr {($cx1-$cx0)*$d+$cx0}]
            set cy1 [expr {($cy1-$cy0)*$d+$cy0}]
            set coords [list $cx0 $cy0 $cx1 $cy1]
            cadobjects_object_set_coords $canv $objid $coords
        }
    }
}


proc plugin_dimline_drawctls {canv objid coords color fillcolor} {
    plugin_dimline_recalculate $canv $objid $coords
    set coords [cadobjects_object_get_coords $canv $objid]
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid LINE $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_dimline_recalculate {canv objid coords {flags ""}} {
    constants radtodeg
    if {[llength $coords] >= 6} {
        foreach {x0 y0 x1 y1 x2 y2} $coords break
        set ang  [expr {atan2($y1-$y0,$x1-$x0)*$radtodeg}]
        set ang2 [expr {atan2($y2-$y0,$x2-$x0)*$radtodeg}]
        set r [::math::geometry::calculateDistanceToLine [list $x2 $y2] [list $x0 $y0 $x1 $y1]]

        if {abs($ang-$ang2) > 180.0} {
            if {$ang > $ang2} {
                set ang2 [expr {$ang2+360.0}]
            } else {
                set ang2 [expr {$ang2-360.0}]
            }
        }

        if {$ang > $ang2} {
            set r [expr {-$r}]
        }

        foreach {x3 y3} [geometry_line_rot_point $x1 $y1 $x0 $y0 $r -90.0] break
        if {abs($y3-$y2)>1e-6 || abs($x3-$x2)>1e-6} {
            cadobjects_object_set_coords $canv $objid [list $x0 $y0 $x1 $y1 $x3 $y3]
            set coords [list $x0 $y0 $x1 $y1 $x3 $y3]
        }
    }
}


proc plugin_dimline_bbox {canv objid coords} {
    return [::math::geometry::bbox $coords]
}


proc plugin_dimline_decompose {canv objid coords allowed} {
    if {"LINES" in $allowed} {
        constants radtodeg

        set out {}
        foreach {x0 y0 x1 y1 x2 y2} $coords break
        set ang  [expr {atan2($y1-$y0,$x1-$x0)*$radtodeg}]
        set ang2 [expr {atan2($y2-$y0,$x2-$x0)*$radtodeg}]
        if {abs($ang-$ang2) > 180.0} {
            if {$ang > $ang2} {
                set ang2 [expr {$ang2+360.0}]
            } else {
                set ang2 [expr {$ang2-360.0}]
            }
        }

        set elen [expr {hypot($y2-$y1,$x2-$x1)}]
        if {$elen>0.2} {
            set gap 0.05
            set elen [expr {$elen+0.1}]
        } else {
            set gap [expr {$elen*0.25}]
            set elen [expr {$elen*1.5}]
        }
        set tlen [expr {hypot($y2-$y1,$x2-$x1)}]
        set dist [expr {hypot($y1-$y0,$x1-$x0)}]

        set units "\""
        set txt [format "%.4f" $dist]
        set txt [string trimright $txt "0"]
        set txt [string trimright $txt "."]
        append txt $units

        set ffam "Courier"
        set fwid [font measure [list $ffam 8] -displayof $canv $txt]
        set twid [expr {$fwid/72.0}]
        if {$twid + 0.1 > $dist/2.0} {
            set fscl [expr {$dist*0.5/($twid+0.1)}]
            set fsiz [expr {int($fscl*8.0+0.5)}]
            set alen [expr {0.1*$fscl}]
        } else {
            set fsiz 8
            set fscl 1.0
            set alen 0.1
        }
        set font [cadobjects_object_getdatum $canv $objid "FONT"]
        if {$font != [list $ffam $fsiz]} {
            cadobjects_object_setdatum $canv $objid "FONT" [list $ffam $fsiz]
        }

        set fmid [expr {$fscl*3.0/72.0}]
        set tgap [expr {(hypot($y1-$y0,$x1-$x0)-$twid*$fscl-0.05)*0.5}]
        set ang1 $ang
        if {abs($ang)>90.05} {
            set ang [expr {$ang+180.0}]
            set fmid [expr {-$fmid}]
        }

        if {$ang1 > $ang2} {
            set gap  [expr {-$gap}]
            set elen [expr {-$elen}]
            set tlen [expr {-$tlen}]
        }

        # Perp end line 1
        foreach {px0 py0} [geometry_line_rot_point $x0 $y0 $x1 $y1 $gap 90.0] break
        foreach {px1 py1} [geometry_line_rot_point $x0 $y0 $x1 $y1 $elen 90.0] break
        lappend out LINES [list $px0 $py0 $px1 $py1]

        # Perp end line 2
        foreach {px0 py0} [geometry_line_rot_point $x1 $y1 $x0 $y0 $gap -90.0] break
        foreach {px1 py1} [geometry_line_rot_point $x1 $y1 $x0 $y0 $elen -90.0] break
        lappend out LINES [list $px0 $py0 $px1 $py1]

        # dimline end points
        foreach {lx0 ly0} [geometry_line_rot_point $x0 $y0 $x1 $y1 $tlen  90.0] break
        foreach {lx1 ly1} [geometry_line_rot_point $x1 $y1 $x0 $y0 $tlen -90.0] break

        # Dimline with gap in middle
        foreach {px0 py0} [geometry_line_rot_point $lx0 $ly0 $lx1 $ly1 $tgap 0.0] break
        foreach {px1 py1} [geometry_line_rot_point $lx1 $ly1 $lx0 $ly0 $tgap 0.0] break
        lappend out LINES [list $lx0 $ly0 $px0 $py0]
        lappend out LINES [list $lx1 $ly1 $px1 $py1]

        # Dimline arrow 1
        foreach {ax1 ay1} [geometry_line_rot_point $lx0 $ly0 $lx1 $ly1 $alen  15.0] break
        foreach {ax2 ay2} [geometry_line_rot_point $lx0 $ly0 $lx1 $ly1 $alen -15.0] break
        lappend out LINES [list $lx0 $ly0 $ax1 $ay1]
        lappend out LINES [list $lx0 $ly0 $ax2 $ay2]

        # Dimline arrow 2
        foreach {ax1 ay1} [geometry_line_rot_point $lx1 $ly1 $lx0 $ly0 $alen  15.0] break
        foreach {ax2 ay2} [geometry_line_rot_point $lx1 $ly1 $lx0 $ly0 $alen -15.0] break
        lappend out LINES [list $lx1 $ly1 $ax1 $ay1]
        lappend out LINES [list $lx1 $ly1 $ax2 $ay2]

        # Dimension text
        set mx [expr {($lx0+$lx1)/2.0}]
        set my [expr {($ly0+$ly1)/2.0}]
        foreach {tx ty} [geometry_line_rot_point $mx $my $lx0 $ly0 $fmid 90.0] break
        if {"ROTTEXT" in $allowed} {
            lappend out ROTTEXT [list $tx $ty $txt [list $ffam $fsiz] "center" $ang]
        } elseif {"TEXT" in $allowed} {
            lappend out TEXT [list $tx $ty $txt [list $ffam $fsiz] "center"]
        }

        return $out
    }
    return {}
}






proc plugin_dimarc_initobj {canv objid coords} {
    cadobjects_object_setdatum $canv $objid "LINEWIDTH" "0.0"
    set dimlayername "Dimensions"
    set dimlayer [layer_name_id $canv $dimlayername]
    if {$dimlayer == ""} {
        set dimlayer [layer_create $canv $dimlayername]
    }
    cadobjects_object_setlayer $canv $objid $dimlayer
    mainwin_update_layerwin [cadobjects_mainwin $canv]
}


proc plugin_dimarc_drawobj {canv objid coords tags color fill width dash} {
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_dimarc_editfields {canv objid coords} {
    set out {}
    lappend out {
        type POINT
        name CENTERPT
        datum #0
        title "Center Point"
    }
    lappend out {
        type POINT
        name ANGPT1
        datum #1
        title "Angle1"
    }
    lappend out {
        type POINT
        name ANGPT2
        datum #2
        title "Angle2"
    }
    lappend out {
        type FLOAT
        name ANGLE
        datum ""
        title "Delta Angle"
        min -360.0
        max 360.0
        increment 5.0
        width 8
        valgetcb "plugin_dimarc_getfield"
        valsetcb "plugin_dimarc_setfield"
    }
    return $out
}


proc plugin_dimarc_getfield {canv objid coords field} {
    constants pi radtodeg
    foreach {cx0 cy0 cx1 cy1 cx2 cy2 cx3 cy3} $coords break
    switch -exact -- $field {
        ANGLE {
            set a1 [expr {atan2($cy1-$cy0,$cx1-$cx0)*$radtodeg}]
            set a2 [expr {atan2($cy2-$cy0,$cx2-$cx0)*$radtodeg}]
            set a [expr {$a2-$a1}]
            if {$a < -180.0} { set a [expr {$a+360.0}] }
            if {$a >  180.0} { set a [expr {$a-360.0}] }
            return $a
        }
    }
}


proc plugin_dimarc_setfield {canv objid coords field val} {
    constants degtorad
    foreach {cx0 cy0 cx1 cy1 cx2 cy2 cx3 cy3} $coords break
    set dist [expr {hypot($cy1-$cy0,$cx1-$cx0)}]

    switch -exact -- $field {
        ANGLE {
            set a1 [expr {atan2($cy1-$cy0,$cx1-$cx0)}]
            set cx2 [expr {$dist*cos($a1+$val*$degtorad)+$cx0}]
            set cy2 [expr {$dist*sin($a1+$val*$degtorad)+$cy0}]
            set coords [list $cx0 $cy0 $cx1 $cy1 $cx2 $cy2 $cx3 $cy3]
            cadobjects_object_set_coords $canv $objid $coords
        }
    }
}


proc plugin_dimarc_drawctls {canv objid coords color fillcolor} {
    plugin_dimarc_recalculate $canv $objid $coords
    set coords [cadobjects_object_get_coords $canv $objid]
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid LINE $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_dimarc_recalculate {canv objid coords {flags ""}} {
}


proc plugin_dimarc_bbox {canv objid coords} {
    return [::math::geometry::bbox $coords]
}


proc plugin_dimarc_decompose {canv objid coords allowed} {
    if {"LINES" in $allowed} {
        constants radtodeg degtorad pi

        set out {}
        if {[llength $coords] > 6} {
            foreach {x0 y0 x1 y1 x2 y2 x3 y3} $coords break
        } else {
            foreach {x0 y0 x1 y1 x2 y2} $coords break
            set x3 $x2
            set y3 $y2
        }

        set dist [expr {hypot($y1-$y0,$x1-$x0)}]
        set tlen [expr {hypot($y3-$y0,$x3-$x0)}]
        set ang  [expr {atan2($y1-$y0,$x1-$x0)*$radtodeg}]
        set ang2 [expr {atan2($y2-$y0,$x2-$x0)*$radtodeg}]
        set ang3 [expr {atan2($y3-$y0,$x3-$x0)*$radtodeg}]

        if {abs($ang-$ang2) > 180.0} {
            if {$ang > $ang2} {
                set ang2 [expr {$ang2+360.0}]
            } else {
                set ang2 [expr {$ang2-360.0}]
            }
        }

        if {abs($ang-$ang3) > 180.0} {
            if {$ang > $ang3} {
                set ang3 [expr {$ang3+360.0}]
            } else {
                set ang3 [expr {$ang3-360.0}]
            }
        }
        if {$ang>$ang2} {
            swapvars ang ang2
            swapvars x1 x2
            swapvars y1 y2
        }

        set longside 1
        if {($ang3 >= $ang-1e-6 && $ang3+1e-6 <= $ang2) || ($ang3 <= $ang+1e-6 && $ang3 >= $ang2-1e-6)} {
            set longside 0
        }

        set dang [expr {abs($ang2-$ang)}]
        if {$dang > 180.0} {
            if {$ang > $ang2} {
                set ang2 [expr {$ang2+360.0}]
            } else {
                set ang2 [expr {$ang2-360.0}]
            }
        }
        set val $dang
        if {$longside} {
            set dang [expr {360.0-$dang}]
        }

        set elen1 [expr {hypot($y1-$y0,$x1-$x0)}]
        if {$elen1 < $tlen} {set elen1 $tlen}
        if {$elen1>0.2} {
            set elen1 [expr {$elen1+0.1}]
        } else {
            set elen1 [expr {$elen1*1.5}]
        }

        set elen2 [expr {hypot($y2-$y0,$x2-$x0)}]
        if {$elen2 < $tlen} {set elen2 $tlen}
        if {$elen2>0.2} {
            set elen2 [expr {$elen2+0.1}]
        } else {
            set elen2 [expr {$elen2*1.5}]
        }

        if {$val < 0.0} {
            set val [expr {-$val}]
        }
        if {$val > 180.0} {
            # normalize value.
            set val [expr {abs(360.0-$val)}]
        }
        if {$longside} {
            # For long sides, display complementary angle.
            set val [expr {abs(360.0-$val)}]
        }
        set units "˚"
        set txt [format "%.2f" $val]
        set txt [string trimright $txt "0"]
        set txt [string trimright $txt "."]
        append txt $units

        set ffam "Courier"
        set fwid [font measure [list $ffam 8] -displayof $canv $txt]
        set twid [expr {$fwid/72.0}]
        if {$twid + 0.1 > $dist/2.0} {
            set fscl [expr {$dist*0.5/($twid+0.1)}]
            set fsiz [expr {int($fscl*8.0+0.5)}]
            set alen [expr {0.1*$fscl}]
        } else {
            set fsiz 8
            set fscl 1.0
            set alen 0.1
        }
        set font [cadobjects_object_getdatum $canv $objid "FONT"]
        if {$font != [list $ffam $fsiz]} {
            cadobjects_object_setdatum $canv $objid "FONT" [list $ffam $fsiz]
        }

        set fmid [expr {$fscl*3.0/72.0}]
        set tgap [expr {($tlen*$pi*2.0-8.0/72.0-0.05)*0.5}]
        set txtang [expr {($ang+$ang2)/2.0}]
        if {abs($txtang) > 90.05} {
            set txtang [expr {fmod($txtang+180.0,360.0)}]
            set fmid [expr {-$fmid}]
        }

        # Perp end line 1
        foreach {px0 py0} [list $x0 $y0] break
        foreach {px1 py1} [geometry_line_rot_point $x0 $y0 $x1 $y1 $elen1 0.0] break
        lappend out LINES [list $px0 $py0 $px1 $py1]

        # Perp end line 2
        foreach {px0 py0} [list $x0 $y0] break
        foreach {px1 py1} [geometry_line_rot_point $x0 $y0 $x2 $y2 $elen2 0.0] break
        lappend out LINES [list $px0 $py0 $px1 $py1]

        # Arc end points
        foreach {lx0 ly0} [geometry_line_rot_point $x0 $y0 $x1 $y1 $tlen 0.0] break
        foreach {lx1 ly1} [geometry_line_rot_point $x0 $y0 $x2 $y2 $tlen 0.0] break

        # Arc with gap in middle
        set extang [expr {$dang/2.0-atan2(1.0/18.0+0.010,$tlen)*$radtodeg}]
        if {$longside} {
            set sang2 [expr {$ang-$extang}]
            lappend out ARC [list $x0 $y0 $tlen $ang2 $extang]
            lappend out ARC [list $x0 $y0 $tlen $sang2 $extang]
        } else {
            set sang2 [expr {$ang2-$extang}]
            lappend out ARC [list $x0 $y0 $tlen $ang $extang]
            lappend out ARC [list $x0 $y0 $tlen $sang2 $extang]
        }

        # Arrow 1
        if {$longside} {
            foreach {ax1 ay1} [geometry_line_rot_point $lx0 $ly0 $x0 $y0 $alen  75.0] break
            foreach {ax2 ay2} [geometry_line_rot_point $lx0 $ly0 $x0 $y0 $alen 105.0] break
        } else {
            foreach {ax1 ay1} [geometry_line_rot_point $lx0 $ly0 $x0 $y0 $alen  -75.0] break
            foreach {ax2 ay2} [geometry_line_rot_point $lx0 $ly0 $x0 $y0 $alen -105.0] break
        }
        lappend out LINES [list $lx0 $ly0 $ax1 $ay1]
        lappend out LINES [list $lx0 $ly0 $ax2 $ay2]

        # Arrow 2
        if {$longside} {
            foreach {ax1 ay1} [geometry_line_rot_point $lx1 $ly1 $x0 $y0 $alen  -75.0] break
            foreach {ax2 ay2} [geometry_line_rot_point $lx1 $ly1 $x0 $y0 $alen -105.0] break
        } else {
            foreach {ax1 ay1} [geometry_line_rot_point $lx1 $ly1 $x0 $y0 $alen  75.0] break
            foreach {ax2 ay2} [geometry_line_rot_point $lx1 $ly1 $x0 $y0 $alen 105.0] break
        }
        lappend out LINES [list $lx1 $ly1 $ax1 $ay1]
        lappend out LINES [list $lx1 $ly1 $ax2 $ay2]

        # Dimension text
        if {$longside} {
            set mx [expr {$tlen*cos((($ang+$ang2)/2.0-180.0)*$degtorad)+$x0}]
            set my [expr {$tlen*sin((($ang+$ang2)/2.0-180.0)*$degtorad)+$y0}]
            foreach {tx ty} [geometry_line_rot_point $mx $my $x0 $y0 $fmid -90.0] break
        } else {
            set mx [expr {$tlen*cos((($ang+$ang2)/2.0)*$degtorad)+$x0}]
            set my [expr {$tlen*sin((($ang+$ang2)/2.0)*$degtorad)+$y0}]
            foreach {tx ty} [geometry_line_rot_point $mx $my $x0 $y0 $fmid 90.0] break
        }
        if {"ROTTEXT" in $allowed} {
            lappend out ROTTEXT [list $tx $ty $txt [list $ffam $fsiz] "center" $ang]
        } elseif {"TEXT" in $allowed} {
            lappend out TEXT [list $tx $ty $txt [list $ffam $fsiz] "center"]
        }

        return $out
    }
    return {}
}








# TODO: Circle and Arc radius dimensions
# TODO: Bezier arc length
# TODO: User typed label with Arrow.
# TODO: Default dimensions to thin linewidth.
# TODO: Allow resizing of dimension font.
# TODO: Allow dimension text format tweaking.


proc plugin_dimline_register {} {
    tool_register_ex DIMLINEH "&Dimensions" "&Horizontal Dimension" {
        {1    "Start Point"}
        {2    "End Point"}
        {3    "Line Offset"}
    } -icon "tool-dimlineh" -creator
    tool_register_ex DIMLINEV "&Dimensions" "&Vertical Dimension" {
        {1    "Start Point"}
        {2    "End Point"}
        {3    "Line Offset"}
    } -icon "tool-dimlinev" -creator
    tool_register_ex DIMLINE "&Dimensions" "&Linear Dimension" {
        {1    "Start Point"}
        {2    "End Point"}
        {3    "Line Offset"}
    } -icon "tool-dimline" -creator
    tool_register_ex DIMARC "&Dimensions" "&Angle Dimension" {
        {1    "Center Point"}
        {2    "Start Point"}
        {3    "End Point"}
        {4    "Arc Offset"}
    } -icon "tool-dimarc" -creator
}
plugin_dimline_register 

# vim: set ts=4 sw=4 nowrap expandtab: settings

