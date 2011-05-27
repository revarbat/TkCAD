proc plugin_screwhole_initobj {canv objid coords} {
    cadobjects_object_setdatum $canv $objid "SIZE" "#10"
    cadobjects_object_setdatum $canv $objid "FIT" "close"
    cadobjects_object_setdatum $canv $objid "CUTSIDE" "inside"
}


proc plugin_screwhole_editfields {canv objid coords} {
    set out {}
    lappend out {
        type OPTIONS
        pane CAM
        name CUTSIDE
        title "Cut Side"
        width 8
        values {"Inside" inside "Outside" outside}
        default inside
    }
    lappend out {
        type POINT
        name CENTER
        datum #0
        title "Center pt"
    }
    lappend out [list \
        type COMBO \
        name SIZE \
        title "Screw Size" \
        width 5 \
        values [mlcnc_screw_size_list] \
        validatecb plugin_screwhole_validate_screwsize \
    ]
    lappend out {
        type OPTIONS
        name FIT
        title "Screw Fit"
        values {Loose loose Close close Exact exact}
    }
    return $out
}


proc plugin_screwhole_validate_screwsize {size} {
    set diam [mlcnc_screw_size $size]
    if {$diam != ""} {
        return 1
    }
    return 0
}


proc plugin_screwhole_drawobj {canv objid coords tags color fill width dash} {
    foreach {cx cy} $coords break
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set fit [cadobjects_object_getdatum $canv $objid "FIT"]
    set diam [mlcnc_screw_hole_size $size $fit]
    set radius [expr {$diam/2.0}]

    set osrad [expr {$radius*0.75}]
    set israd [expr {$radius*0.2}]

    set x0 [expr {$cx-$osrad}]
    set x1 [expr {$cx-$israd}]
    set x2 [expr {$cx+$israd}]
    set x3 [expr {$cx+$osrad}]

    set y0 [expr {$cy-$osrad}]
    set y1 [expr {$cy-$israd}]
    set y2 [expr {$cy+$israd}]
    set y3 [expr {$cy+$osrad}]

    set slotpts [cadobjects_scale_coords $canv [list $x0 $y0 $x1 $y1 $x2 $y2 $x3 $y3]]
    foreach {x0 y0 x1 y1 x2 y2 x3 y3} $slotpts break
    set poly [list $x0 $y1  $x1 $y1  $x1 $y0  $x2 $y0  $x2 $y1  $x3 $y1  $x3 $y2  $x2 $y2  $x2 $y3  $x1 $y3  $x1 $y2  $x0 $y2  $x0 $y1]
    if {[namespace exists ::tkp]} {
        set pdash [pathdash $dash]
        $canv create polyline $poly -strokelinejoin round -strokelinecap round -tags $tags -stroke $color -strokewidth $width -strokedasharray $pdash
        $canv create polyline [list $x1 $y1 $x2 $y2] -strokelinejoin round -strokelinecap round -tags $tags -stroke $color -strokewidth $width -strokedasharray $pdash
        $canv create polyline [list $x1 $y2 $x2 $y1] -strokelinejoin round -strokelinecap round -tags $tags -stroke $color -strokewidth $width -strokedasharray $pdash
    } else {
        $canv create line $poly -tags $tags -fill $color -width $width -dash $dash
        $canv create line [list $x1 $y1 $x2 $y2] -tags $tags -fill $color -width $width -dash $dash
        $canv create line [list $x1 $y2 $x2 $y1] -tags $tags -fill $color -width $width -dash $dash
    }
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_screwhole_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid CIRCLECTR $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_screwhole_recalculate {canv objid coords {flags ""}} {
    # Nothing to do.  The control points are all the data needed.
}


proc plugin_screwhole_pointsofinterest {canv objid coords nearx neary} {
    foreach {cx cy} $coords break
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set fit [cadobjects_object_getdatum $canv $objid "FIT"]
    set diam [mlcnc_screw_hole_size $size $fit]
    set radius [expr {$diam/2.0}]

    set x0 [expr {$cx-$radius}]
    set y0 [expr {$cy-$radius}]
    set x1 [expr {$cx+$radius}]
    set y1 [expr {$cy+$radius}]

    set poi {}
    lappend poi "controlpoints" $cx   $cy   "Center Point"   1
    lappend poi "quadrants"     $x0   $cy   "Quadrant"      -1
    lappend poi "quadrants"     $cx   $y0   "Quadrant"      -1
    lappend poi "quadrants"     $x1   $cy   "Quadrant"      -1
    lappend poi "quadrants"     $cx   $y1   "Quadrant"      -1

    cadobjects_object_arc_pois $canv poi "contours" "On Circle" $cx $cy $radius 0.0 360.0 $nearx $neary

    return $poi
}


proc plugin_screwhole_decompose {canv objid coords allowed} {
    foreach {cx cy} $coords break
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set fit [cadobjects_object_getdatum $canv $objid "FIT"]
    set diam [mlcnc_screw_hole_size $size $fit]
    set radius [expr {$diam/2.0}]

    if {"CIRCLE" in $allowed} {
        if {"GCODE" in $allowed} {
            set cutbit  [cadobjects_object_cutbit $canv $objid]
            set cutside [cadobjects_object_getdatum $canv $objid "CUTSIDE"]
            set cutdiam [mlcnc_tooldiam $cutbit]
            if {$cutbit > 0} {
                if {$cutside == "inside"} {
                    set radius [expr {$radius-$cutdiam/2.0}]
                } elseif {$cutside == "outside"} {
                    set radius [expr {$radius+$cutdiam/2.0}]
                }
                return [list CIRCLE [list $cx $cy $radius]]
            }
            return ""
        }
        return [list CIRCLE [list $cx $cy $radius]]
    } elseif {"ELLIPSE" in $allowed} {
        return [list ELLIPSE [list $cx $cy $radius $radius 0.0]]
    } elseif {"ARC" in $allowed} {
        return [list ARC [list $cx $cy $radius 0.0 360.0]]
    } elseif {"BEZIER" in $allowed} {
        set path {}
        bezutil_append_bezier_arc path $cx $cy $radius $radius 0.0 360.0
        return [list BEZIER $path]
    } elseif {"LINES" in $allowed} {
        set path {}
        bezutil_append_line_arc path $cx $cy $radius $radius 0.0 360.0
        return [list LINES $path]
    }
    return {}
}


proc plugin_screwhole_offsetcopyobj {canv objid coords offset} {
    foreach {cx cy} $coords break
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set fit [cadobjects_object_getdatum $canv $objid "FIT"]
    set diam [mlcnc_screw_hole_size $size $fit]
    set rad [expr {$diam/2.0}]
    set rad [expr {$rad-$offset}]
    set cpx1 [expr {$cx+$rad}]
    set cpy1 $cy
    set nuobj [cadobjects_object_create $canv CIRCLECTR [list $cx $cy $cpx1 $cpy1] {}]
    return $nuobj
}





proc plugin_taphole_initobj {canv objid coords} {
    cadobjects_object_setdatum $canv $objid "SIZE" "#10"
    cadobjects_object_setdatum $canv $objid "PITCH" "fine"
    cadobjects_object_setdatum $canv $objid "CUTSIDE" "inside"
}


proc plugin_taphole_editfields {canv objid coords} {
    set out {}
    lappend out {
        type OPTIONS
        pane CAM
        name CUTSIDE
        title "Cut Side"
        width 8
        values {"Inside" inside}
        default inside
    }
    lappend out {
        type POINT
        name CENTER
        datum #0
        title "Center pt"
    }
    lappend out [list \
        type COMBO \
        name SIZE \
        title "Screw Size" \
        width 5 \
        values [mlcnc_screw_size_list] \
        validatecb plugin_screwhole_validate_tapsize \
    ]
    lappend out {
        type OPTIONS
        name PITCH
        title "Screw Pitch"
        values {Coarse coarse Fine fine}
    }
    return $out
}


proc plugin_screwhole_validate_tapsize {size} {
    set diam [mlcnc_screw_tap_size $size "loose"]
    if {$diam != ""} {
        return 1
    }
    return 0
}


proc plugin_taphole_drawobj {canv objid coords tags color fill width dash} {
    foreach {cx cy} $coords break
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set pitch [cadobjects_object_getdatum $canv $objid "PITCH"]
    set diam [mlcnc_screw_tap_size $size $pitch]
    set radius [expr {$diam/2.0}]

    set diam [mlcnc_screw_size $size]
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set radius [expr {$diam/2.0}]

    foreach {cx cy rad1 dummy} [cadobjects_scale_coords $canv [list $cx $cy $radius 0.0]] break
    cadobjects_object_draw_circle $canv $cx $cy $rad1 $tags $color [dashpat construction] 1.0
    cadobjects_object_draw_center_cross $canv $cx $cy $rad1 $tags $color $width

    return 0 ;# Also draw default decomposed shape.
}


proc plugin_taphole_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid CIRCLECTR $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_taphole_recalculate {canv objid coords {flags ""}} {
    # Nothing to do.  The control points are all the data needed.
}


proc plugin_taphole_pointsofinterest {canv objid coords nearx neary} {
    foreach {cx cy} $coords break
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set pitch [cadobjects_object_getdatum $canv $objid "PITCH"]
    set diam [mlcnc_screw_tap_size $size $pitch]
    set radius [expr {$diam/2.0}]
    set scdiam [mlcnc_screw_size $size]
    set scrad [expr {$scdiam/2.0}]

    set x0 [expr {$cx-$radius}]
    set y0 [expr {$cy-$radius}]
    set x1 [expr {$cx+$radius}]
    set y1 [expr {$cy+$radius}]

    set poi {}
    lappend poi "controlpoints" $cx   $cy   "Center Point"   1
    lappend poi "quadrants"     $x0   $cy   "Quadrant"      -1
    lappend poi "quadrants"     $cx   $y0   "Quadrant"      -1
    lappend poi "quadrants"     $x1   $cy   "Quadrant"      -1
    lappend poi "quadrants"     $cx   $y1   "Quadrant"      -1

    cadobjects_object_arc_pois $canv poi "contours" "On Circle" $cx $cy $radius 0.0 360.0 $nearx $neary
    cadobjects_object_arc_pois $canv poi "contours" "On Circle" $cx $cy $scrad 0.0 360.0 $nearx $neary

    return $poi
}


proc plugin_taphole_decompose {canv objid coords allowed} {
    foreach {cx cy} $coords break
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set pitch [cadobjects_object_getdatum $canv $objid "PITCH"]
    set diam [mlcnc_screw_tap_size $size $pitch]
    set radius [expr {$diam/2.0}]

    if {"CIRCLE" in $allowed} {
        if {"GCODE" in $allowed} {
            set cutbit  [cadobjects_object_cutbit $canv $objid]
            set cutside [cadobjects_object_getdatum $canv $objid "CUTSIDE"]
            set cutdiam [mlcnc_tooldiam $cutbit]
            if {$cutbit > 0} {
                if {$cutside == "inside"} {
                    set radius [expr {$radius-$cutdiam/2.0}]
                } elseif {$cutside == "outside"} {
                    set radius [expr {$radius+$cutdiam/2.0}]
                }
                return [list CIRCLE [list $cx $cy $radius]]
            }
            return ""
        }
        return [list CIRCLE [list $cx $cy $radius]]
    } elseif {"ELLIPSE" in $allowed} {
        return [list ELLIPSE [list $cx $cy $radius $radius 0.0]]
    } elseif {"ARC" in $allowed} {
        return [list ARC [list $cx $cy $radius 0.0 360.0]]
    } elseif {"BEZIER" in $allowed} {
        set path {}
        bezutil_append_bezier_arc path $cx $cy $radius $radius 0.0 360.0
        return [list BEZIER $path]
    } elseif {"LINES" in $allowed} {
        set path {}
        bezutil_append_line_arc path $cx $cy $radius $radius 0.0 360.0
        return [list LINES $path]
    }
    return {}
}


proc plugin_taphole_offsetcopyobj {canv objid coords offset} {
    foreach {cx cy} $coords break
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set pitch [cadobjects_object_getdatum $canv $objid "PITCH"]
    set diam [mlcnc_screw_tap_size $size $pitch]
    set rad [expr {$diam/2.0}]
    set rad [expr {$rad-$offset}]
    set cpx1 [expr {$cx+$rad}]
    set cpy1 $cy
    set nuobj [cadobjects_object_create $canv CIRCLECTR [list $cx $cy $cpx1 $cpy1] {}]
    return $nuobj
}





proc plugin_screwslot_initobj {canv objid coords} {
    cadobjects_object_setdatum $canv $objid "SIZE" "#10"
    cadobjects_object_setdatum $canv $objid "FIT" "close"
    cadobjects_object_setdatum $canv $objid "CAPSTYLE" "round"
    cadobjects_object_setdatum $canv $objid "CUTSIDE" "inside"
}


proc plugin_screwslot_editfields {canv objid coords} {
    set out {}
    lappend out {
        type OPTIONS
        pane CAM
        name CUTSIDE
        title "Cut Side"
        width 8
        values {"Inside" inside "Outside" outside}
        default inside
    }
    lappend out {
        type POINT
        name POINT1
        datum 0
        title "Point 1"
    }
    lappend out {
        type POINT
        name POINT2
        datum 1
        title "Point 2"
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
        valgetcb "plugin_screwslot_getfield"
        valsetcb "plugin_screwslot_setfield"
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
        valgetcb "plugin_screwslot_getfield"
        valsetcb "plugin_screwslot_setfield"
    }
    lappend out [list \
        type COMBO \
        name SIZE \
        title "Screw Size" \
        width 5 \
        values [mlcnc_screw_size_list] \
        validatecb plugin_screwhole_validate_screwsize \
    ]
    lappend out {
        type OPTIONS
        name FIT
        title "Screw Fit"
        values {Loose loose Close close Exact exact}
    }
    lappend out {
        type OPTIONS
        name CAPSTYLE
        title "Cap Style"
        values {Round round Square square}
    }
    return $out
}


proc plugin_screwslot_getfield {canv objid coords field} {
    constants pi
    foreach {cx0 cy0 cx1 cy1} $coords break
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


proc plugin_screwslot_setfield {canv objid coords field val} {
    constants pi
    foreach {cx0 cy0 cx1 cy1} $coords break
    set dist [expr {hypot($cy1-$cy0,$cx1-$cx0)}]

    switch -exact -- $field {
        ANGLE {
            set cx1 [expr {$dist*cos($val*$pi/180.0)+$cx0}]
            set cy1 [expr {$dist*sin($val*$pi/180.0)+$cy0}]
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


proc plugin_screwslot_drawobj {canv objid coords tags color fill width dash} {
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set capstyle [cadobjects_object_getdatum $canv $objid "CAPSTYLE"]
    set fit [cadobjects_object_getdatum $canv $objid "FIT"]
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set scdiam [mlcnc_screw_hole_size $size $fit]
    set scrad [expr {$scdiam*$dpi*$scalefactor/2.0}]

    foreach {cx1 cy1 cx2 cy2} [cadobjects_scale_coords $canv $coords] break
    if {$capstyle == "round"} {
        cadobjects_object_draw_center_cross $canv $cx1 $cy1 $scrad $tags $color $width
        cadobjects_object_draw_center_cross $canv $cx2 $cy2 $scrad $tags $color $width
    }
    cadobjects_object_draw_centerline $canv $cx1 $cy1 $cx2 $cy2 $tags $color

    return 0 ;# Also draw default decomposed shape.
}


proc plugin_screwslot_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid CIRCLECTR $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_screwslot_recalculate {canv objid coords {flags ""}} {
    constants pi
    foreach {cx1 cy1 cx2 cy2} $coords break
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set capstyle [cadobjects_object_getdatum $canv $objid "CAPSTYLE"]
    set fit [cadobjects_object_getdatum $canv $objid "FIT"]
    set diam [mlcnc_screw_hole_size $size $fit]
    set radius [expr {$diam/2.0}]

    if {$capstyle == "square"} {
        foreach {ax0 ay0 ax1 ay1} [geometry_line_offset $cx1 $cy1 $cx2 $cy2 $radius] break
        foreach {bx0 by0 bx1 by1} [geometry_line_offset $cx1 $cy1 $cx2 $cy2 -$radius] break
        set path [list $ax0 $ay0  $ax0 $ay0  $ax1 $ay1  $ax1 $ay1  $ax1 $ay1  $bx1 $by1  $bx1 $by1  $bx1 $by1  $bx0 $by0  $bx0 $by0  $bx0 $by0  $ax0 $ay0  $ax0 $ay0]
    } elseif {$capstyle == "round"} {
        set relang [expr {atan2($cy2-$cy1,$cx2-$cx1)*180.0/$pi}]
        set perpang1 [expr {fmod($relang+90.0,360.0)}]
        set perpang2 [expr {fmod($perpang1+180.0,360.0)}]

        set path {}
        bezutil_append_bezier_arc path $cx1 $cy1 $radius $radius $perpang1 180.0
        bezutil_append_bezier_arc path $cx2 $cy2 $radius $radius $perpang2 180.0
        lappend path [lindex $path end-1] [lindex $path end]
        lappend path [lindex $path 0] [lindex $path 1]
        lappend path [lindex $path 0] [lindex $path 1]
    }

    cadobjects_object_setdatum $canv $objid "BEZPATH" $path
}



proc plugin_screwslot_decompose {canv objid coords allowed} {
    foreach {cx1 cy1 cx2 cy2} $coords break
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set fit [cadobjects_object_getdatum $canv $objid "FIT"]
    set diam [mlcnc_screw_hole_size $size $fit]
    set radius [expr {$diam/2.0}]
    set capstyle [cadobjects_object_getdatum $canv $objid "CAPSTYLE"]
    set bez [cadobjects_object_getdatum $canv $objid "BEZPATH"]

    if {"GCODE" in $allowed} {
        set cutbit  [cadobjects_object_cutbit $canv $objid]
        set cutside [cadobjects_object_getdatum $canv $objid "CUTSIDE"]
        set cutdiam [mlcnc_tooldiam $cutbit]
        if {$cutbit <= 0} {
            return ""
        }
        if {$cutside == "inside"} {
            set radius [expr {$radius-$cutdiam/2.0}]
        } elseif {$cutside == "outside"} {
            set radius [expr {$radius+$cutdiam/2.0}]
        }
    }

    constants pi
    set relang [expr {atan2($cy2-$cy1,$cx2-$cx1)*180.0/$pi}]
    set perpang1 [expr {fmod($relang+90.0,360.0)}]
    set perpang2 [expr {fmod($perpang1+180.0,360.0)}]
    set x0 [expr {$cx1+$radius*cos($perpang1*$pi/180.0)}]
    set y0 [expr {$cy1+$radius*sin($perpang1*$pi/180.0)}]
    set x1 [expr {$cx1+$radius*cos($perpang2*$pi/180.0)}]
    set y1 [expr {$cy1+$radius*sin($perpang2*$pi/180.0)}]
    set x2 [expr {$cx2+$radius*cos($perpang1*$pi/180.0)}]
    set y2 [expr {$cy2+$radius*sin($perpang1*$pi/180.0)}]
    set x3 [expr {$cx2+$radius*cos($perpang2*$pi/180.0)}]
    set y3 [expr {$cy2+$radius*sin($perpang2*$pi/180.0)}]

    if {$capstyle == "square" && "LINES" in $allowed} {
        set out {}
        lappend out LINES [list $x0 $y0  $x1 $y1  $x3 $y3  $x2 $y2  $x0 $y0]
        return $out
    } elseif {$capstyle == "round" && "GCODE" in $allowed && "ARC" in $allowed && "LINES" in $allowed} {
        set out {}
        lappend out ARC [list $cx1 $cy1 $radius $perpang1 180.0]
        lappend out LINES [list $x1 $y1 $x3 $y3]
        lappend out ARC [list $cx2 $cy2 $radius $perpang2 180.0]
        lappend out LINES [list $x2 $y2 $x0 $y0 $x0 $y0]
        return $out
    } elseif {"BEZIER" in $allowed} {
        return [list BEZIER $bez]
    } elseif {"LINES" in $allowed} {
        set bezpath {}
        bezutil_append_line_from_bezier bezpath $bez
        return [list LINES $bezpath]
    }
    return {}
}


proc plugin_screwslot_pointsofinterest {canv objid coords nearx neary} {
    foreach {cx1 cy1 cx2 cy2} $coords break
    constants pi radtodeg
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set capstyle [cadobjects_object_getdatum $canv $objid "CAPSTYLE"]
    set fit [cadobjects_object_getdatum $canv $objid "FIT"]
    set diam [mlcnc_screw_hole_size $size $fit]
    set radius [expr {$diam/2.0}]
    set slotang [expr {atan2($cy2-$cy1,$cx2-$cx1)}]

    set mpx [expr {($cx1+$cx2)/2.0}]
    set mpy [expr {($cy1+$cy2)/2.0}]

    foreach {ax0 ay0 ax1 ay1} [geometry_line_offset $cx1 $cy1 $cx2 $cy2 $radius] break
    foreach {bx0 by0 bx1 by1} [geometry_line_offset $cx1 $cy1 $cx2 $cy2 -$radius] break

    set poi {}
    lappend poi "controlpoints" $cx1  $cy1  "Center Point"   1
    lappend poi "controlpoints" $cx2  $cy2  "Center Point"   2
    lappend poi "midpoints"     $mpx  $mpy  "Midpoint"      -1

    cadobjects_object_polyline_pois poi "contours" "On Line" [list $ax0 $ay0 $ax1 $ay1] $nearx $neary
    cadobjects_object_polyline_pois poi "contours" "On Line" [list $bx0 $by0 $bx1 $by1] $nearx $neary
    cadobjects_object_polyline_pois poi "centerlines" "On Centerline" [list $cx1 $cy1 $cx2 $cy2] $nearx $neary

    if {$capstyle == "round"} {
        set pang1 [expr {($slotang-$pi/2.0)*$radtodeg}]
        set pang2 [expr {($slotang+$pi/2.0)*$radtodeg}]
        cadobjects_object_arc_pois $canv poi "contours" "On Arc" $cx1 $cy1 $radius $pang2 180.0 $nearx $neary
        cadobjects_object_arc_pois $canv poi "contours" "On Arc" $cx2 $cy2 $radius $pang1 180.0 $nearx $neary
    } elseif {$capstyle == "square"} {
        cadobjects_object_polyline_pois poi "contours" "On Line" [list $ax0 $ay0 $bx0 $by0] $nearx $neary
        cadobjects_object_polyline_pois poi "contours" "On Line" [list $ax1 $ay1 $bx1 $by1] $nearx $neary
    }

    return $poi
}




proc plugin_screwslotarc_initobj {canv objid coords} {
    cadobjects_object_setdatum $canv $objid "SIZE" "#10"
    cadobjects_object_setdatum $canv $objid "FIT" "close"
    cadobjects_object_setdatum $canv $objid "CAPSTYLE" "round"
    cadobjects_object_setdatum $canv $objid "CUTSIDE" "inside"
}


proc plugin_screwslotarc_editfields {canv objid coords} {
    set out {}
    lappend out {
        type OPTIONS
        pane CAM
        name CUTSIDE
        title "Cut Side"
        width 8
        values {"Inside" inside "Outside" outside}
        default inside
    }
    lappend out {
        type POINT
        name CENTER
        datum 0
        title "Center pt"
    }
    lappend out {
        type POINT
        name POINT1
        datum #1
        title "Point 1"
    }
    lappend out {
        type POINT
        name POINT2
        datum #2
        title "Point 2"
    }
    lappend out {
        type FLOAT
        name STARTANG
        datum ""
        title "Start Angle"
        min -360.0
        max  360.0
        increment 5.0
        width 8
        valgetcb "plugin_screwslotarc_getfield"
        valsetcb "plugin_screwslotarc_setfield"
    }
    lappend out {
        type FLOAT
        name ENDANG
        datum ""
        title "End Angle"
        min -360.0
        max  360.0
        increment 5.0
        width 8
        valgetcb "plugin_screwslotarc_getfield"
        valsetcb "plugin_screwslotarc_setfield"
    }
    lappend out {
        type FLOAT
        name EXTENT
        datum ""
        title "Extent"
        min 0.0
        max 360.0
        increment 5.0
        width 8
        valgetcb "plugin_screwslotarc_getfield"
        valsetcb "plugin_screwslotarc_setfield"
    }
    lappend out {
        type FLOAT
        name RADIUS
        datum ""
        title "Radius"
        min 0.0
        max 1e6
        increment 0.125
        width 8
        valgetcb "plugin_screwslotarc_getfield"
        valsetcb "plugin_screwslotarc_setfield"
        islength 1
    }
    lappend out [list \
        type COMBO \
        name SIZE \
        title "Screw Size" \
        width 5 \
        values [mlcnc_screw_size_list] \
        validatecb plugin_screwhole_validate_screwsize \
    ]
    lappend out {
        type OPTIONS
        name FIT
        title "Screw Fit"
        values {Loose loose Close close Exact exact}
    }
    lappend out {
        type OPTIONS
        name CAPSTYLE
        title "Cap Style"
        values {Round round Square square}
    }
    return $out
}


proc plugin_screwslotarc_getfield {canv objid coords field} {
    constants pi
    foreach {cx0 cy0 cx1 cy1 cx2 cy2} $coords break
    switch -exact -- $field {
        STARTANG {
            set a [expr {atan2($cy1-$cy0,$cx1-$cx0)*180.0/$pi}]
            return $a
        }
        ENDANG {
            set a [expr {atan2($cy2-$cy0,$cx2-$cx0)*180.0/$pi}]
            return $a
        }
        EXTENT {
            set a [expr {atan2($cy1-$cy0,$cx1-$cx0)*180.0/$pi}]
            set b [expr {atan2($cy2-$cy0,$cx2-$cx0)*180.0/$pi}]
            if {$a>$b} {
                set b [expr {$b+360.0}]
            }
            if {$b-$a > 360.0} {
                set a [expr {$a+360.0}]
            }
            return [expr {$b-$a}]
        }
        RADIUS {
            set d [expr {hypot($cy1-$cy0,$cx1-$cx0)}]
            return $d
        }
    }
}


proc plugin_screwslotarc_setfield {canv objid coords field val} {
    constants pi
    foreach {cx cy cpx1 cpy1 cpx2 cpy2} $coords break
    set hy1 [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set hy2 [expr {hypot($cpy2-$cy,$cpx2-$cx)}]

    switch -exact -- $field {
        STARTANG {
            set cpx1 [expr {$hy1*cos($val*$pi/180.0)+$cx}]
            set cpy1 [expr {$hy1*sin($val*$pi/180.0)+$cy}]
            set coords [list $cx $cy $cpx1 $cpy1 $cpx2 $cpy2]
            cadobjects_object_set_coords $canv $objid $coords
        }
        ENDANG {
            set cpx2 [expr {$hy1*cos($val*$pi/180.0)+$cx}]
            set cpy2 [expr {$hy1*sin($val*$pi/180.0)+$cy}]
            set coords [list $cx $cy $cpx1 $cpy1 $cpx2 $cpy2]
            cadobjects_object_set_coords $canv $objid $coords
        }
        EXTENT {
            set ang1 [expr {atan2($cpy1-$cy,$cpx1-$cx)*180.0/$pi}]
            set ang2 [expr {$ang1+$val}]
            set cpx2 [expr {$hy1*cos($ang2*$pi/180.0)+$cx}]
            set cpy2 [expr {$hy1*sin($ang2*$pi/180.0)+$cy}]
            set coords [list $cx $cy $cpx1 $cpy1 $cpx2 $cpy2]
            cadobjects_object_set_coords $canv $objid $coords
        }
        RADIUS {
            if {abs($hy1) < 1e-9} {
                set d 0.0
            } else {
                set d [expr {$val/$hy1}]
            }
            set cpx1 [expr {($cpx1-$cx)*$d+$cx}]
            set cpy1 [expr {($cpy1-$cy)*$d+$cy}]
            if {abs($hy2) < 1e-9} {
                set d 0.0
            } else {
                set d [expr {$val/$hy2}]
            }
            set cpx2 [expr {($cpx2-$cx)*$d+$cx}]
            set cpy2 [expr {($cpy2-$cy)*$d+$cy}]
            set coords [list $cx $cy $cpx1 $cpy1 $cpx2 $cpy2]
            cadobjects_object_set_coords $canv $objid $coords
        }
    }
}


proc plugin_screwslotarc_flipobj {canv objid coords x0 y0 x1 y1} {
    foreach {cx cy cpx1 cpy1 cpx2 cpy2} $coords break
    set rad [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set ang [expr {atan2($cpy2-$cy,$cpx2-$cx)}]
    set cpx2 [expr {$rad*cos($ang)+$cx}]
    set cpy2 [expr {$rad*sin($ang)+$cy}]
    set coords [list $cx $cy $cpx2 $cpy2 $cpx1 $cpy1]
    cadobjects_object_set_coords $canv $objid $coords
    return 0 ;# Also allow default coordlist transformation
}


proc plugin_screwslotarc_drawobj {canv objid coords tags color fill width dash} {
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set fit [cadobjects_object_getdatum $canv $objid "FIT"]
    set capstyle [cadobjects_object_getdatum $canv $objid "CAPSTYLE"]
    set start [cadobjects_object_getdatum $canv $objid "STARTANG"]
    set extent [cadobjects_object_getdatum $canv $objid "EXTENT"]
    set bez [cadobjects_object_getdatum $canv $objid "BEZPATH"]

    constants pi
    foreach {cx0 cy0 cx1 cy1 cx2 cy2} [cadobjects_scale_coords $canv $coords] break
    set rad [expr {hypot($cy1-$cy0,$cx1-$cx0)}]
    set ang2 [expr {atan2($cy2-$cy0,$cx2-$cx0)}]
    set cx2 [expr {$rad*cos($ang2)+$cx0}]
    set cy2 [expr {$rad*sin($ang2)+$cy0}]

    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set scdiam [mlcnc_screw_hole_size $size $fit]
    set scrad [expr {$scdiam*$dpi*$scalefactor/2.0}]

    cadobjects_object_draw_center_cross $canv $cx0 $cy0 $scrad $tags $color $width
    if {$capstyle == "round"} {
        cadobjects_object_draw_center_cross $canv $cx1 $cy1 $scrad $tags $color $width
        cadobjects_object_draw_center_cross $canv $cx2 $cy2 $scrad $tags $color $width
    }
    cadobjects_object_draw_center_arc $canv $cx0 $cy0 $rad $start $extent $tags $color

    return 0 ;# Also draw default decomposed shape.
}


proc plugin_screwslotarc_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid CIRCLECTR $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
    foreach {cx0 cy0 cx1 cy1 cx2 cy2} $coords break
    set start [cadobjects_object_getdatum $canv $objid "STARTANG"]
    set extent [cadobjects_object_getdatum $canv $objid "EXTENT"]
    set radius [expr {hypot($cy1-$cy0,$cx1-$cx0)}]
    set rad2 [expr {hypot($cy2-$cy0,$cx2-$cx0)}]
    set ang2 [expr {atan2($cy2-$cy0,$cx2-$cx0)}]
    set cx3 [expr {$radius*cos($ang2)+$cx0}]
    set cy3 [expr {$radius*sin($ang2)+$cy0}]
    if {$radius > $rad2} {
        set cx2 $cx3
        set cy2 $cy3
    }
    cadobjects_object_draw_control_line $canv $objid $cx0 $cy0 $cx1 $cy1 1 $color {2 2 2 2}
    cadobjects_object_draw_control_line $canv $objid $cx0 $cy0 $cx2 $cy2 2 $color {2 2 2 2}
}


proc plugin_screwslotarc_recalculate {canv objid coords {flags ""}} {
    constants pi
    foreach {cx0 cy0 cx1 cy1 cx2 cy2} $coords break
    set hy1 [expr {hypot($cy1-$cy0,$cx1-$cx0)}]
    set ang2 [expr {atan2($cy2-$cy0,$cx2-$cx0)}]
    set cx2 [expr {$hy1*cos($ang2)+$cx0}]
    set cy2 [expr {$hy1*sin($ang2)+$cy0}]
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set fit [cadobjects_object_getdatum $canv $objid "FIT"]
    set capstyle [cadobjects_object_getdatum $canv $objid "CAPSTYLE"]
    set diam [mlcnc_screw_hole_size $size $fit]
    set radius [expr {$diam/2.0}]
    set longrad [expr {hypot($cy1-$cy0,$cx1-$cx0)}]

    set orad [expr {$longrad+$radius}]
    set irad [expr {$longrad-$radius}]

    set relang1 [expr {atan2($cy1-$cy0,$cx1-$cx0)*180.0/$pi}]
    set oppang1 [expr {fmod($relang1+180.0,360.0)}]
    set relang2 [expr {atan2($cy2-$cy0,$cx2-$cx0)*180.0/$pi}]
    set oppang2 [expr {fmod($relang2+180.0,360.0)}]

    set spanang [expr {fmod($relang2-$relang1,360.0)}]
    if {$spanang < 0} {
        set spanang [expr {$spanang+360.0}]
    }
    set nspanang [expr {-$spanang}]

    set path {}
    if {hypot($cy2-$cy1,$cx2-$cx1) > 1e-6} {
        bezutil_append_bezier_arc path $cx0 $cy0 $irad $irad $relang1 $spanang
        if {$capstyle == "round"} {
            bezutil_append_bezier_arc path $cx2 $cy2 $radius $radius $oppang2 -180.0
        } elseif {$capstyle == "square"} {
            set apx1 [expr {($irad+$radius*0.667)*cos($relang2*$pi/180.0)+$cx0}]
            set apy1 [expr {($irad+$radius*0.667)*sin($relang2*$pi/180.0)+$cy0}]
            set apx2 [expr {($orad-$radius*0.667)*cos($relang2*$pi/180.0)+$cx0}]
            set apy2 [expr {($orad-$radius*0.667)*sin($relang2*$pi/180.0)+$cy0}]
            lappend path $apx1 $apy1 $apx2 $apy2
        }
        bezutil_append_bezier_arc path $cx0 $cy0 $orad $orad $relang2 $nspanang
        if {$capstyle == "round"} {
            bezutil_append_bezier_arc path $cx1 $cy1 $radius $radius $relang1 -180.0
        } elseif {$capstyle == "square"} {
            set apx1 [expr {($orad-$radius*0.667)*cos($relang1*$pi/180.0)+$cx0}]
            set apy1 [expr {($orad-$radius*0.667)*sin($relang1*$pi/180.0)+$cy0}]
            set apx2 [expr {($irad+$radius*0.667)*cos($relang1*$pi/180.0)+$cx0}]
            set apy2 [expr {($irad+$radius*0.667)*sin($relang1*$pi/180.0)+$cy0}]
            lappend path $apx1 $apy1 $apx2 $apy2
        }
        lappend path [lindex $path end-1] [lindex $path end]
        lappend path [lindex $path 0] [lindex $path 1]
        lappend path [lindex $path 0] [lindex $path 1]
    } else {
        bezutil_append_bezier_arc path $cx1 $cy1 $radius $radius 0.0 360.0
    }
    cadobjects_object_setdatum $canv $objid "BEZPATH" $path
    cadobjects_object_setdatum $canv $objid "STARTANG" $relang1
    cadobjects_object_setdatum $canv $objid "EXTENT" $spanang
}



proc plugin_screwslotarc_dragctls {canv objid coords nodes dx dy} {
    if {"1" in $nodes} {
        set nodes {1 2 3}
    }
    foreach node $nodes {
        set pos1 [expr {($node-1)*2}]
        set pos2 [expr {$pos1+1}]
        lset coords $pos1 [expr {[lindex $coords $pos1]+$dx}]
        lset coords $pos2 [expr {[lindex $coords $pos2]+$dy}]
    }
    cadobjects_object_set_coords $canv $objid $coords
    return 1 ;# We moved everything.  Tell caller we need nothing else moved.
}


proc plugin_screwslotarc_decompose {canv objid coords allowed} {
    foreach {cx0 cy0 cx1 cy1 cx2 cy2} $coords break
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set fit [cadobjects_object_getdatum $canv $objid "FIT"]
    set diam [mlcnc_screw_hole_size $size $fit]
    set radius [expr {$diam/2.0}]
    set capstyle [cadobjects_object_getdatum $canv $objid "CAPSTYLE"]
    set bez [cadobjects_object_getdatum $canv $objid "BEZPATH"]

    if {"GCODE" in $allowed} {
        set cutbit  [cadobjects_object_cutbit $canv $objid]
        set cutside [cadobjects_object_getdatum $canv $objid "CUTSIDE"]
        set cutdiam [mlcnc_tooldiam $cutbit]
        if {$cutbit <= 0} {
            return ""
        }
        if {$cutside == "inside"} {
            set radius [expr {$radius-$cutdiam/2.0}]
        } elseif {$cutside == "outside"} {
            set radius [expr {$radius+$cutdiam/2.0}]
        }
    }

    if {$capstyle == "round" && "GCODE" in $allowed && "ARC" in $allowed} {
        constants pi
        set longrad [expr {hypot($cy1-$cy0,$cx1-$cx0)}]
        set orad [expr {$longrad+$radius}]
        set irad [expr {$longrad-$radius}]
        set relang1 [expr {atan2($cy1-$cy0,$cx1-$cx0)*180.0/$pi}]
        set oppang1 [expr {fmod($relang1+180.0,360.0)}]
        set relang2 [expr {atan2($cy2-$cy0,$cx2-$cx0)*180.0/$pi}]
        set oppang2 [expr {fmod($relang2+180.0,360.0)}]
        set spanang [expr {fmod($relang2-$relang1,360.0)}]
        if {$spanang < 0} {
            set spanang [expr {$spanang+360.0}]
        }
        set nspanang [expr {-$spanang}]
        set hy1 [expr {hypot($cy1-$cy0,$cx1-$cx0)}]
        set ang2 [expr {atan2($cy2-$cy0,$cx2-$cx0)}]
        set cx2 [expr {$hy1*cos($ang2)+$cx0}]
        set cy2 [expr {$hy1*sin($ang2)+$cy0}]

        set out {}
        lappend out ARC [list $cx0 $cy0 $irad $relang1 $spanang]
        lappend out ARC [list $cx2 $cy2 $radius $oppang2 -180.0]
        lappend out ARC [list $cx0 $cy0 $orad $relang2 $nspanang]
        lappend out ARC [list $cx1 $cy1 $radius $relang1 -180.0]
        return $out
    } elseif {$capstyle == "square" && "GCODE" in $allowed && "ARC" in $allowed && "LINES" in $allowed} {
        constants pi
        set longrad [expr {hypot($cy1-$cy0,$cx1-$cx0)}]
        set orad [expr {$longrad+$radius}]
        set irad [expr {$longrad-$radius}]
        set relang1 [expr {atan2($cy1-$cy0,$cx1-$cx0)*180.0/$pi}]
        set oppang1 [expr {fmod($relang1+180.0,360.0)}]
        set relang2 [expr {atan2($cy2-$cy0,$cx2-$cx0)*180.0/$pi}]
        set oppang2 [expr {fmod($relang2+180.0,360.0)}]
        set spanang [expr {fmod($relang2-$relang1,360.0)}]
        if {$spanang < 0} {
            set spanang [expr {$spanang+360.0}]
        }
        set nspanang [expr {-$spanang}]
        set hy1 [expr {hypot($cy1-$cy0,$cx1-$cx0)}]
        set ang2 [expr {atan2($cy2-$cy0,$cx2-$cx0)}]
        set cx2 [expr {$hy1*cos($ang2)+$cx0}]
        set cy2 [expr {$hy1*sin($ang2)+$cy0}]

        set apx1 [expr {$irad*cos($relang2*$pi/180.0)+$cx0}]
        set apy1 [expr {$irad*sin($relang2*$pi/180.0)+$cy0}]
        set apx2 [expr {$orad*cos($relang2*$pi/180.0)+$cx0}]
        set apy2 [expr {$orad*sin($relang2*$pi/180.0)+$cy0}]

        set apx3 [expr {$orad*cos($relang1*$pi/180.0)+$cx0}]
        set apy3 [expr {$orad*sin($relang1*$pi/180.0)+$cy0}]
        set apx4 [expr {$irad*cos($relang1*$pi/180.0)+$cx0}]
        set apy4 [expr {$irad*sin($relang1*$pi/180.0)+$cy0}]

        set out {}
        lappend out ARC [list $cx0 $cy0 $irad $relang1 $spanang]
        lappend out LINES [list $apx1 $apy1  $apx2 $apy2]
        lappend out ARC [list $cx0 $cy0 $orad $relang2 $nspanang]
        lappend out LINES [list $apx3 $apy3  $apx4 $apy4]
        return $out
    } elseif {"BEZIER" in $allowed} {
        return [list BEZIER $bez]
    } elseif {"LINES" in $allowed} {
        set bezpath {}
        bezutil_append_line_from_bezier bezpath $bez
        return [list LINES $bezpath]
    }
    return {}
}


proc plugin_screwslotarc_pointsofinterest {canv objid coords nearx neary} {
    foreach {cx0 cy0 cx1 cy1 cx2 cy2} $coords break
    constants pi radtodeg
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set capstyle [cadobjects_object_getdatum $canv $objid "CAPSTYLE"]
    set fit [cadobjects_object_getdatum $canv $objid "FIT"]
    set diam [mlcnc_screw_hole_size $size $fit]
    set radius [expr {$diam/2.0}]
    set slotang1 [expr {atan2($cy1-$cy0,$cx1-$cx0)}]
    set slotang2 [expr {atan2($cy2-$cy0,$cx2-$cx0)}]
    set arcrad [expr {hypot($cy1-$cy0,$cx1-$cx0)}]
    set cx2 [expr {$arcrad*cos($slotang2)+$cx0}]
    set cy2 [expr {$arcrad*sin($slotang2)+$cy0}]

    if {$slotang1 < 0.0} {
        set slotang1 [expr {$slotang1+$pi*2.0}]
    }
    while {$slotang2 < $slotang1} {
        set slotang2 [expr {$slotang2+$pi*2.0}]
    }
    set midang [expr {($slotang1+$slotang2)/2.0}]
    set mpx [expr {$arcrad*cos($midang)+$cx0}]
    set mpy [expr {$arcrad*sin($midang)+$cy0}]

    set irad [expr {$arcrad-$radius}]
    set orad [expr {$arcrad+$radius}]
    set start [expr {$slotang1*180.0/$pi}]
    set extent [expr {($slotang2-$slotang1)*180.0/$pi}]

    set poi {}
    lappend poi "controlpoints" $cx0 $cy0  "Center Point"   1
    lappend poi "controlpoints" $cx1 $cy1  "Center Point"   2
    lappend poi "controlpoints" $cx2 $cy2  "Center Point"   3
    lappend poi "midpoints"     $mpx $mpy  "Midpoint"      -1
    cadobjects_object_arc_pois $canv poi "contours"    "On Arc" $cx0 $cy0 $irad $start $extent $nearx $neary
    cadobjects_object_arc_pois $canv poi "contours"    "On Arc" $cx0 $cy0 $orad $start $extent $nearx $neary
    cadobjects_object_arc_pois $canv poi "centerlines" "On Centerline" $cx0 $cy0 $arcrad $start $extent $nearx $neary
    if {$capstyle == "round"} {
        set start1 [expr {normang($slotang1+$pi)*$radtodeg}]
        set start2 [expr {normang($slotang2)*$radtodeg}]
        cadobjects_object_arc_pois $canv poi "contours" "On Arc" $cx1 $cy1 $radius $start1 180.0 $nearx $neary
        cadobjects_object_arc_pois $canv poi "contours" "On Arc" $cx2 $cy2 $radius $start2 180.0 $nearx $neary
    } elseif {$capstyle == "square"} {
        set slotang3 [expr {normang($slotang1+$pi)}]
        set slotang4 [expr {normang($slotang2+$pi)}]
        set px0 [expr {$cx1+$radius*cos($slotang1)}]
        set py0 [expr {$cy1+$radius*sin($slotang1)}]
        set px1 [expr {$cx1+$radius*cos($slotang3)}]
        set py1 [expr {$cy1+$radius*sin($slotang3)}]
        set px2 [expr {$cx2+$radius*cos($slotang2)}]
        set py2 [expr {$cy2+$radius*sin($slotang2)}]
        set px3 [expr {$cx2+$radius*cos($slotang4)}]
        set py3 [expr {$cy2+$radius*sin($slotang4)}]
        set line1 [list $px0 $py0 $px1 $py1]
        set line2 [list $px2 $py2 $px3 $py3]
        cadobjects_object_polyline_pois poi "contours" "On Line" $line1 $nearx $neary
        cadobjects_object_polyline_pois poi "contours" "On Line" $line2 $nearx $neary
    }

    return $poi
}








proc plugin_hexnut_editfields {canv objid coords} {
    set out {}
    lappend out {
        type OPTIONS
        pane CAM
        name CUTSIDE
        title "Cut Side"
        width 8
        values {"On Line" center "Inside" inside "Outside" outside}
        default center
    }
    lappend out {
        type POINT
        name CENTER
        datum 0
        title "Center pt"
    }
    lappend out [list \
        type OPTIONS \
        name SIZE \
        title "Nut Size" \
        width 5 \
        values [mlcnc_get_standard_nut_sizes] \
        validatecb plugin_hexnut_validate_screwsize \
    ]
    lappend out {
        type FLOAT
        name ANGLE
        title "Angle"
        min -360.0
        max 360.0
        increment 5.0
        width 8
    }
    return $out
}


proc plugin_hexnut_validate_screwsize {size} {
    set sizes [mlcnc_get_standard_nut_sizes]
    if {$size in $sizes} {
        return 1
    }
    return 0
}


proc plugin_hexnut_initobj {canv objid coords} {
    cadobjects_object_setdatum $canv $objid "SIZE" "#10"
    cadobjects_object_setdatum $canv $objid "ANGLE" 0.0
    cadobjects_object_setdatum $canv $objid "CUTSIDE" "inside"
}


proc plugin_hexnut_transformobj {canv objid coords mat} {
    set coords [cadobjects_object_getdatum $canv $objid "LINEPATH"]
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid LINE
    return 0 ;# Also allow default coordlist transforms
}


proc plugin_hexnut_shearobj {canv objid coords sx sy cx cy} {
    plugin_hexnut_transformobj $canv $objid $coords ""
    return 0 ;# Also allow default coordlist transforms
}


proc plugin_hexnut_scaleobj {canv objid coords sx sy cx cy} {
    if {abs(abs($sx)-abs($sy)) > 1e-6} {
        plugin_hexnut_transformobj $canv $objid $coords ""
    }
    return 0 ;# Also allow default coordlist transforms
}


proc plugin_hexnut_rotateobj {canv objid coords rotang cx cy} {
    set ang [cadobjects_object_getdatum $canv $objid "ANGLE"]
    set ang [expr {fmod($ang+$rotang,360.0)}]
    if {$ang > 180.0} {
        set ang [expr {$ang-360.0}]
    } elseif {$ang < -180.0} {
        set ang [expr {$ang+360.0}]
    }
    cadobjects_object_setdatum $canv $objid "ANGLE" $ang
    return 0 ;# Also allow default coordlist rotation
}


proc plugin_hexnut_drawobj {canv objid coords tags color fill width dash} {
    constants degtorad
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set diam [mlcnc_get_standard_nut_width $size]
    set radius [expr {$diam/2.0}]

    lappend coords $radius 0.0
    set coords [cadobjects_scale_coords $canv $coords]
    foreach {cx cy radius dummy} $coords break
    set outrad $radius

    cadobjects_object_draw_circle $canv $cx $cy $outrad $tags $color [dashpat construction] 1.0
    cadobjects_object_draw_center_cross $canv $cx $cy $radius $tags $color $width
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_hexnut_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid HEXNUT $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_hexnut_recalculate {canv objid coords {flags ""}} {
    constants pi
    foreach {cx cy cpx cpy} $coords break
    set angle [cadobjects_object_getdatum $canv $objid "ANGLE"]
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set diam [mlcnc_get_standard_nut_width $size]
    set radius [expr {$diam/2.0}]
    set sides 6
    set ang [expr {$angle*$pi/180.0}]
    set stepang [expr {($pi*2.0)/$sides}]
    set radius [expr {$radius/cos($stepang/2.0)}]
    set linepath {}
    for {set i 0} {$i < $sides} {incr i} {
        set px [expr {$radius*cos($ang)+$cx}]
        set py [expr {$radius*sin($ang)+$cy}]
        lappend linepath $px $py
        set ang [expr {$ang+$stepang}]
    }
    lappend linepath [lindex $linepath 0] [lindex $linepath 1]
    cadobjects_object_setdatum $canv $objid "LINEPATH" $linepath
}


proc plugin_hexnut_pointsofinterest {canv objid coords nearx neary} {
    set linepath [cadobjects_object_getdatum $canv $objid "LINEPATH"]
    foreach {cx cy} $coords break
    set poi {}

    lappend poi "controlpoints" $cx $cy "Center Point" 1

    set cnt 1
    foreach {x y} [lrange $linepath 0 end-2] {
        lappend poi "controlpoints" $x $y "Vertex" $cnt
        incr cnt
    }

    set ox [lindex $linepath 0]
    set oy [lindex $linepath 1]
    foreach {x y} [lrange $linepath 2 end] {
        set mx [expr {($ox+$x)/2.0}]
        set my [expr {($oy+$y)/2.0}]
        lappend poi "midpoints" $mx $my "Midpoint" -1
        set ox $x
        set oy $y
    }

    cadobjects_object_polyline_pois poi "contours" "On Polygon" $linepath $nearx $neary

    return $poi
}


proc plugin_hexnut_dragctls {canv objid coords nodes dx dy} {
    if {"1" in $nodes} {
        set nodes {1 2}
    }
    foreach node $nodes {
        set pos1 [expr {($node-1)*2}]
        set pos2 [expr {$pos1+1}]
        lset coords $pos1 [expr {[lindex $coords $pos1]+$dx}]
        lset coords $pos2 [expr {[lindex $coords $pos2]+$dy}]
    }
    cadobjects_object_set_coords $canv $objid $coords
    return 1 ;# We moved everything.  Tell caller we need nothing else moved.
}


proc plugin_hexnut_decompose {canv objid coords allowed} {
    foreach {cx cy} $coords break
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set angle [cadobjects_object_getdatum $canv $objid "ANGLE"]
    set linepath [cadobjects_object_getdatum $canv $objid "LINEPATH"]

    if {"HEXNUT" in $allowed} {
        return [list HEXNUT [list $cx $cy $size $angle]]
    } elseif {"LINES" in $allowed} {
        set path [cadobjects_object_getdatum $canv $objid "LINEPATH"]
        if {"GCODE" in $allowed} {
            set cutbit  [cadobjects_object_cutbit $canv $objid]
            set cutside [cadobjects_object_getdatum $canv $objid "CUTSIDE"]
            set cutdiam [mlcnc_tooldiam $cutbit]
            set cutrad [expr {abs($cutdiam/2.0)}]
            set out {}
            if {$cutbit > 0} {
                if {$cutside == "inside"} {
                    foreach pline [mlcnc_path_inset $path $cutrad] {
                        lappend out LINES $pline
                    }
                } elseif {$cutside == "outside"} {
                    foreach pline [mlcnc_path_inset $path -$cutrad] {
                        lappend out LINES $pline
                    }
                } else {
                    lappend out LINES $path
                }
            }
            return $out
        }
        return [list LINES $path]
    } elseif {"BEZIER" in $allowed} {
        set linepath [cadobjects_object_getdatum $canv $objid "LINEPATH"]
        set bezpath [bezutil_bezier_from_line $linepath]
        return [list BEZIER $bezpath]
    }
    return {}
}


proc plugin_hexnut_bbox {canv objid coords} {
    set linepath [cadobjects_object_getdatum $canv $objid "LINEPATH"]
    return [geometry_pointlist_bbox $linepath]
}







proc plugin_captiveslot_initobj {canv objid coords} {
    cadobjects_object_setdatum $canv $objid "SIZE" "#10"
    cadobjects_object_setdatum $canv $objid "OFFSET" "0.125"
    cadobjects_object_setdatum $canv $objid "FIT" "close"
    cadobjects_object_setdatum $canv $objid "CAPSTYLE" "square"
    cadobjects_object_setdatum $canv $objid "CUTSIDE" "inside"
}


proc plugin_captiveslot_editfields {canv objid coords} {
    set out {}
    lappend out {
        type OPTIONS
        pane CAM
        name CUTSIDE
        title "Cut Side"
        width 8
        values {"Inside" inside "Outside" outside}
        default inside
    }
    lappend out {
        type POINT
        name POINT1
        datum 0
        title "Point 1"
    }
    lappend out {
        type POINT
        name POINT2
        datum 1
        title "Point 2"
    }
    lappend out {
        type FLOAT
        name OFFSET
        datum ""
        title "Offset"
        min 0.0
        max 1e9
        increment 0.0625
        width 8
        valgetcb "plugin_captiveslot_getfield"
        valsetcb "plugin_captiveslot_setfield"
        islength 1
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
        valgetcb "plugin_captiveslot_getfield"
        valsetcb "plugin_captiveslot_setfield"
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
        valgetcb "plugin_captiveslot_getfield"
        valsetcb "plugin_captiveslot_setfield"
    }
    lappend out [list \
        type OPTIONS \
        name SIZE \
        title "Nut Size" \
        width 5 \
        values [mlcnc_get_standard_nut_sizes] \
        validatecb plugin_hexnut_validate_screwsize \
    ]
    lappend out {
        type OPTIONS
        name FIT
        title "Screw Fit"
        values {Loose loose Close close Exact exact}
    }
    lappend out {
        type OPTIONS
        name CAPSTYLE
        title "Cap Style"
        values {Round round Square square}
    }
    return $out
}


proc plugin_captiveslot_getfield {canv objid coords field} {
    constants pi
    if {[llength $coords] < 6} {
        return
    }
    foreach {cx0 cy0 cx1 cy1 cx2 cy2} $coords break
    switch -exact -- $field {
        LENGTH {
            set d [expr {hypot($cy1-$cy0,$cx1-$cx0)}]
            return $d
        }
        OFFSET {
            set size [cadobjects_object_getdatum $canv $objid "SIZE"]
            set nuth [mlcnc_get_standard_nut_height $size]
            set dist [expr {hypot($cy1-$cy0,$cx1-$cx0)}]
            set d [expr {hypot($cy2-$cy0,$cx2-$cx0)}]
            set a1 [expr {atan2($cy1-$cy0,$cx1-$cx0)}]
            set a2 [expr {atan2($cy2-$cy0,$cx2-$cx0)}]
            set ang [expr {abs($a1-$a2)}]
            if {$ang > $pi} {
                set ang [expr {(2.0*$pi)-$ang}]
            }
            if {$ang >= $pi/2.0} {
                return 0.0
            }
            set off [expr {$d*cos($ang)}]
            return $off
        }
        ANGLE {
            set d [expr {atan2($cy1-$cy0,$cx1-$cx0)*180.0/$pi}]
            return $d
        }
    }
}


proc plugin_captiveslot_setfield {canv objid coords field val} {
    constants pi
    if {[llength $coords] < 6} {
        return
    }
    foreach {cx0 cy0 cx1 cy1 cx2 cy2} $coords break
    set dist [expr {hypot($cy1-$cy0,$cx1-$cx0)}]

    switch -exact -- $field {
        ANGLE {
            set cx1 [expr {$dist*cos($val*$pi/180.0)+$cx0}]
            set cy1 [expr {$dist*sin($val*$pi/180.0)+$cy0}]
            set coords [list $cx0 $cy0 $cx1 $cy1 $cx2 $cy2]
            cadobjects_object_set_coords $canv $objid $coords
        }
        OFFSET {
            set size [cadobjects_object_getdatum $canv $objid "SIZE"]
            set nuth [mlcnc_get_standard_nut_height $size]
            set minbase 0.0625
            if {$val > $dist-$nuth-$minbase} {
                set val [expr {$dist-$nuth-$minbase}]
                if {$val < $minbase} {
                    set val $minbase
                }
                cadobjects_object_setdatum $canv $objid "OFFSET" $val
            }
            if {$dist > 1e-6} {
                set d [expr {$val/$dist}]
                set cx2 [expr {($cx1-$cx0)*$d+$cx0}]
                set cy2 [expr {($cy1-$cy0)*$d+$cy0}]
            } else {
                set cx2 [expr {$cx0}]
                set cy2 [expr {$cy0+$minbase}]
            }
            set coords [list $cx0 $cy0 $cx1 $cy1 $cx2 $cy2]
            cadobjects_object_set_coords $canv $objid $coords
        }
        LENGTH {
            set d 0.0
            if {$dist > 1e-6} {
                set d [expr {$val/$dist}]
            }
            set cx1 [expr {($cx1-$cx0)*$d+$cx0}]
            set cy1 [expr {($cy1-$cy0)*$d+$cy0}]
            set coords [list $cx0 $cy0 $cx1 $cy1 $cx2 $cy2]
            cadobjects_object_set_coords $canv $objid $coords
        }
    }
}


proc plugin_captiveslot_drawobj {canv objid coords tags color fill width dash} {
    set capstyle [cadobjects_object_getdatum $canv $objid "CAPSTYLE"]
    set fit [cadobjects_object_getdatum $canv $objid "FIT"]
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set nuth [mlcnc_get_standard_nut_height $size]
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set scdiam [mlcnc_screw_hole_size $size $fit]
    set scrad [expr {$scdiam*$dpi*$scalefactor/2.0}]

    foreach {cx1 cy1 cx2 cy2} [cadobjects_scale_coords $canv $coords] break
    if {$capstyle == "round"} {
        cadobjects_object_draw_center_cross $canv $cx2 $cy2 $scrad $tags $color $width
    }
    cadobjects_object_draw_centerline $canv $cx1 $cy1 $cx2 $cy2 $tags $color

    return 0 ;# Also draw default decomposed shape.
}


proc plugin_captiveslot_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid CIRCLECTR $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_captiveslot_recalculate {canv objid coords {flags ""}} {
    constants pi
    if {[llength $coords] > 4} {
        foreach {cx0 cy0 cx1 cy1 cx2 cy2} $coords break
    } else {
        foreach {cx0 cy0 cx1 cy1} $coords break
        set d1  [expr {hypot($cy1-$cy0,$cx1-$cx0)}]
        set a1  [expr {atan2($cy1-$cy0,$cx1-$cx0)}]
        if {$d1 < 1e-6} {
            return
        }
        set cx2 [expr {$cx0+0.125*cos($a1)}]
        set cy2 [expr {$cy0+0.125*sin($a1)}]
    }
    set capstyle [cadobjects_object_getdatum $canv $objid "CAPSTYLE"]
    set fit [cadobjects_object_getdatum $canv $objid "FIT"]
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set nuth [mlcnc_get_standard_nut_height $size]
    set nutw [mlcnc_get_standard_nut_width $size]
    set diam [mlcnc_screw_hole_size $size $fit]
    set radius [expr {$diam/2.0}]

    set d1  [expr {hypot($cy1-$cy0,$cx1-$cx0)}]
    set d2  [expr {hypot($cy2-$cy0,$cx2-$cx0)}]
    set a1  [expr {atan2($cy1-$cy0,$cx1-$cx0)}]
    set a2  [expr {atan2($cy2-$cy0,$cx2-$cx0)}]
    set ang [expr {abs($a1-$a2)}]
    if {$ang > $pi} {
        set ang [expr {(2.0*$pi)-$ang}]
    }
    set minbase 0.0625
    if {$ang >= $pi/2.0} {
        set off $minbase
    } else {
        set off [expr {$d2*cos($ang)}]
        if {$off > $d1-$nuth-$minbase} {
            set off [expr {$d1-$nuth-$minbase}]
            if {$off < $minbase} {
                set off $minbase
            }
            cadobjects_object_setdatum $canv $objid "OFFSET" $off
        }
        if {$off < $minbase} {
            set off $minbase
            cadobjects_object_setdatum $canv $objid "OFFSET" $off
        }
    }
    set d 0.0
    if {$d1 > 1e-6} {
        set d [expr {$off/$d1}]
    }
    set ncx [expr {($cx1-$cx0)*$d+$cx0}]
    set ncy [expr {($cy1-$cy0)*$d+$cy0}]
    if {hypot($ncy-$cy2,$ncx-$cx2) > 1e-6} {
        set cx2 $ncx
        set cy2 $ncy
        if {[llength $coords] > 4} {
            set coords [list $cx0 $cy0 $cx1 $cy1 $cx2 $cy2]
            cadobjects_object_set_coords $canv $objid $coords
        }
    }
    if {hypot($cy1-$cy0,$cx1-$cx0) < $nuth+2.0*$minbase} {
        if {$d1 > 1e-6} {
            set d [expr {(2.0*$minbase+$nuth)/$d1}]
            set cx1 [expr {($cx1-$cx0)*$d+$cx0}]
            set cy1 [expr {($cy1-$cy0)*$d+$cy0}]
        } else {
            set cx1 [expr {$cx0}]
            set cy1 [expr {$cy0+$nuth+2.0*$minbase}]
        }
        if {[llength $coords] > 4} {
            set coords [list $cx0 $cy0 $cx1 $cy1 $cx2 $cy2]
            cadobjects_object_set_coords $canv $objid $coords
        }
    }

    set ang [expr {atan2($cy1-$cy0,$cx1-$cx0)}]
    set mx0 [expr {$cx0+cos($ang)*$off}]
    set my0 [expr {$cy0+sin($ang)*$off}]
    set mx1 [expr {$cx0+cos($ang)*($off+$nuth)}]
    set my1 [expr {$cy0+sin($ang)*($off+$nuth)}]

    foreach {ax0 ay0 ax1 ay1} [geometry_line_offset $cx0 $cy0 $cx1 $cy1  $radius] break
    foreach {bx0 by0 bx1 by1} [geometry_line_offset $cx0 $cy0 $cx1 $cy1 -$radius] break
    foreach {px0 py0 px1 py1} [geometry_line_offset $mx0 $my0 $mx1 $my1  $radius] break
    foreach {qx0 qy0 qx1 qy1} [geometry_line_offset $mx0 $my0 $mx1 $my1 -$radius] break
    foreach {rx0 ry0 rx1 ry1} [geometry_line_offset $mx0 $my0 $mx1 $my1 [expr { $nutw*0.5}]] break
    foreach {sx0 sy0 sx1 sy1} [geometry_line_offset $mx0 $my0 $mx1 $my1 [expr {-$nutw*0.5}]] break
    set rmx [expr {($rx0+$rx1)/2.0}]
    set rmy [expr {($ry0+$ry1)/2.0}]
    set smx [expr {($sx0+$sx1)/2.0}]
    set smy [expr {($sy0+$sy1)/2.0}]
    if {$capstyle == "square"} {
        set path [list $ax0 $ay0  $ax0 $ay0  $px0 $py0  $px0 $py0  $px0 $py0  $rx0 $ry0  $rx0 $ry0  $rx0 $ry0  $rx1 $ry1  $rx1 $ry1  $rx1 $ry1  $px1 $py1  $px1 $py1  $px1 $py1  $ax1 $ay1  $ax1 $ay1  $ax1 $ay1  $bx1 $by1  $bx1 $by1  $bx1 $by1  $qx1 $qy1  $qx1 $qy1  $qx1 $qy1  $sx1 $sy1  $sx1 $sy1  $sx1 $sy1  $sx0 $sy0  $sx0 $sy0  $sx0 $sy0  $qx0 $qy0  $qx0 $qy0  $qx0 $qy0  $bx0 $by0  $bx0 $by0  $bx0 $by0  $ax0 $ay0  $ax0 $ay0]
    } elseif {$capstyle == "round"} {
        set relang [expr {atan2($cy1-$cy0,$cx1-$cx0)*180.0/$pi}]
        set perpang1 [expr {fmod($relang+90.0,360.0)}]
        set perpang2 [expr {fmod($perpang1+180.0,360.0)}]
        set nutrad [expr {$nuth/2.0}]

        set path {}
        lappend path $bx0 $by0
        lappend path $bx0 $by0

        lappend path $qx0 $qy0
        lappend path $qx0 $qy0
        lappend path $qx0 $qy0

        lappend path $sx0 $sy0
        bezutil_append_bezier_arc path $smx $smy $nutrad $nutrad [expr {$relang-180}] 180.0
        lappend path $sx1 $sy1

        lappend path $qx1 $qy1
        lappend path $qx1 $qy1
        lappend path $qx1 $qy1

        lappend path $bx1 $by1
        bezutil_append_bezier_arc path $cx1 $cy1 $radius $radius $perpang2 180.0
        lappend path $ax1 $ay1

        lappend path $px1 $py1
        lappend path $px1 $py1
        lappend path $px1 $py1

        lappend path $rx1 $ry1
        bezutil_append_bezier_arc path $rmx $rmy $nutrad $nutrad $relang 180.0
        lappend path $rx0 $ry0

        lappend path $px0 $py0
        lappend path $px0 $py0
        lappend path $px0 $py0

        lappend path $ax0 $ay0
        lappend path $ax0 $ay0
        lappend path $ax0 $ay0

        lappend path $bx0 $by0
        lappend path $bx0 $by0
    }

    cadobjects_object_setdatum $canv $objid "BEZPATH" $path
}



proc plugin_captiveslot_decompose {canv objid coords allowed} {
    if {[llength $coords] > 4} {
        foreach {cx0 cy0 cx1 cy1 cx2 cy2} $coords break
    } else {
        foreach {cx0 cy0 cx1 cy1} $coords break
        set d1  [expr {hypot($cy1-$cy0,$cx1-$cx0)}]
        set a1  [expr {atan2($cy1-$cy0,$cx1-$cx0)}]
        if {$d1 < 1e-6} {
            return
        }
        set cx2 [expr {$cx0+0.125*cos($a1)}]
        set cy2 [expr {$cy0+0.125*sin($a1)}]
    }
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set fit [cadobjects_object_getdatum $canv $objid "FIT"]
    set diam [mlcnc_screw_hole_size $size $fit]
    set radius [expr {$diam/2.0}]
    set capstyle [cadobjects_object_getdatum $canv $objid "CAPSTYLE"]
    set bez [cadobjects_object_getdatum $canv $objid "BEZPATH"]

    if {"GCODE" in $allowed} {
        set cutbit  [cadobjects_object_cutbit $canv $objid]
        set cutside [cadobjects_object_getdatum $canv $objid "CUTSIDE"]
        set cutdiam [mlcnc_tooldiam $cutbit]
        if {$cutbit <= 0} {
            return ""
        }
        if {$cutside == "inside"} {
            set radius [expr {$radius-$cutdiam/2.0}]
        } elseif {$cutside == "outside"} {
            set radius [expr {$radius+$cutdiam/2.0}]
        }
    }

    constants pi
    set relang [expr {atan2($cy1-$cy0,$cx1-$cx0)*180.0/$pi}]
    set perpang1 [expr {fmod($relang+90.0,360.0)}]
    set perpang2 [expr {fmod($perpang1+180.0,360.0)}]
    set x0 [expr {$cx0+$radius*cos($perpang1*$pi/180.0)}]
    set y0 [expr {$cy0+$radius*sin($perpang1*$pi/180.0)}]
    set x1 [expr {$cx0+$radius*cos($perpang2*$pi/180.0)}]
    set y1 [expr {$cy0+$radius*sin($perpang2*$pi/180.0)}]
    set x2 [expr {$cx1+$radius*cos($perpang1*$pi/180.0)}]
    set y2 [expr {$cy1+$radius*sin($perpang1*$pi/180.0)}]
    set x3 [expr {$cx1+$radius*cos($perpang2*$pi/180.0)}]
    set y3 [expr {$cy1+$radius*sin($perpang2*$pi/180.0)}]

    if {"BEZIER" in $allowed} {
        return [list BEZIER $bez]
    } elseif {"LINES" in $allowed} {
        set bezpath {}
        bezutil_append_line_from_bezier bezpath $bez
        return [list LINES $bezpath]
    }
    return {}
}


proc plugin_captiveslot_pointsofinterest {canv objid coords nearx neary} {
    foreach {cx1 cy1 cx2 cy2} $coords break
    constants pi radtodeg
    set size [cadobjects_object_getdatum $canv $objid "SIZE"]
    set capstyle [cadobjects_object_getdatum $canv $objid "CAPSTYLE"]
    set fit [cadobjects_object_getdatum $canv $objid "FIT"]
    set diam [mlcnc_screw_hole_size $size $fit]
    set radius [expr {$diam/2.0}]
    set slotang [expr {atan2($cy2-$cy1,$cx2-$cx1)}]

    set mpx [expr {($cx1+$cx2)/2.0}]
    set mpy [expr {($cy1+$cy2)/2.0}]

    foreach {ax0 ay0 ax1 ay1} [geometry_line_offset $cx1 $cy1 $cx2 $cy2 $radius] break
    foreach {bx0 by0 bx1 by1} [geometry_line_offset $cx1 $cy1 $cx2 $cy2 -$radius] break

    set poi {}
    lappend poi "controlpoints" $cx1  $cy1  "Center Point"   1
    lappend poi "controlpoints" $cx2  $cy2  "Center Point"   2
    lappend poi "midpoints"     $mpx  $mpy  "Midpoint"      -1

    cadobjects_object_polyline_pois poi "contours" "On Line" [list $ax0 $ay0 $ax1 $ay1] $nearx $neary
    cadobjects_object_polyline_pois poi "contours" "On Line" [list $bx0 $by0 $bx1 $by1] $nearx $neary
    cadobjects_object_polyline_pois poi "centerlines" "On Centerline" [list $cx1 $cy1 $cx2 $cy2] $nearx $neary

    if {$capstyle == "round"} {
        set pang1 [expr {($slotang-$pi/2.0)*$radtodeg}]
        set pang2 [expr {($slotang+$pi/2.0)*$radtodeg}]
        cadobjects_object_arc_pois $canv poi "contours" "On Arc" $cx1 $cy1 $radius $pang2 180.0 $nearx $neary
        cadobjects_object_arc_pois $canv poi "contours" "On Arc" $cx2 $cy2 $radius $pang1 180.0 $nearx $neary
    } elseif {$capstyle == "square"} {
        cadobjects_object_polyline_pois poi "contours" "On Line" [list $ax0 $ay0 $bx0 $by0] $nearx $neary
        cadobjects_object_polyline_pois poi "contours" "On Line" [list $ax1 $ay1 $bx1 $by1] $nearx $neary
    }

    return $poi
}










proc plugin_screwholes_register {} {
    set groupname "&Screws, Bolts, Nuts"
    tool_register_ex SCREWHOLE $groupname "Screw &Hole" {
        {1    "Centerpoint"}
    } -icon "tool-screwhole" -creator -impfields {SIZE FIT}
    tool_register_ex TAPHOLE $groupname "&Tap Hole" {
        {1    "Centerpoint"}
    } -icon "tool-taphole" -creator -impfields {SIZE PITCH}
    tool_register_ex SCREWSLOT $groupname "Screw &Slot" {
        {1    "Endpoint1"}
        {2    "Endpoint2"}
    } -icon "tool-screwslot" -creator -impfields {SIZE FIT CAPSTYLE}
    tool_register_ex SCREWSLOTARC $groupname "&Arced Screw Slot" {
        {1    "Centerpoint of Arc"}
        {2    "Endpoint1"}
        {3    "Endpoint2"}
    } -icon "tool-screwslotarc" -creator -impfields {SIZE FIT CAPSTYLE}
    tool_register_ex HEXNUT $groupname "Hex &Nut" {
        {1    "Center Point"}
    } -icon "tool-hexnut" -creator -impfields {SIZE ANGLE}
    tool_register_ex CAPTIVESLOT $groupname "&Captive Nut Slot" {
        {1    "Endpoint1"}
        {2    "Endpoint2"}
        {3    "Slot Position"}
    } -icon "tool-captiveslot" -creator -impfields {SIZE FIT CAPSTYLE}
}
plugin_screwholes_register 


# vim: set ts=4 sw=4 nowrap expandtab: settings

