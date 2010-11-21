proc plugin_circlectr_editfields {canv objid coords} {
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
    lappend out {
        type POINT
        name CTRLPT
        datum #1
        title "Circle pt"
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
        valgetcb "plugin_circlectr_getfield"
        valsetcb "plugin_circlectr_setfield"
        islength 1
    }
    lappend out {
        type FLOAT
        name DIAMETER
        datum ""
        title "Diameter"
        min 0.0
        max 1e6
        increment 0.125
        width 8
        valgetcb "plugin_circlectr_getfield"
        valsetcb "plugin_circlectr_setfield"
        islength 1
    }
    return $out
}


proc plugin_circlectr_getfield {canv objid coords field} {
    switch -exact -- $field {
        RADIUS {
            foreach {cx cy cpx cpy} $coords break
            set d [expr {hypot($cpy-$cy,$cpx-$cx)}]
            return $d
        }
        DIAMETER {
            foreach {cx cy cpx cpy} $coords break
            set d [expr {2.0*hypot($cpy-$cy,$cpx-$cx)}]
            return $d
        }
    }
}


proc plugin_circlectr_setfield {canv objid coords field val} {
    switch -exact -- $field {
        DIAMETER -
        RADIUS {
            foreach {cx cy cpx cpy} $coords break
            set hy [expr {hypot($cpy-$cy,$cpx-$cx)}]
            if {$field == "DIAMETER"} {
                set hy [expr {$hy*2.0}]
            }
            if {abs($hy) < 1e-9} {
                set d 0.0
            } else {
                set d [expr {$val/$hy}]
            }
            set cpx [expr {($cpx-$cx)*$d+$cx}]
            set cpy [expr {($cpy-$cy)*$d+$cy}]
            set coords [list $cx $cy $cpx $cpy]
            cadobjects_object_set_coords $canv $objid $coords
        }
    }
}


proc plugin_circlectr_transformobj {canv objid coords mat} {
    constants pi
    foreach {cx cy cpx cpy} $coords break
    set rad [expr {hypot($cpy-$cy,$cpx-$cx)}]
    set ang [expr {atan2($cpy-$cy,$cpx-$cx)}]
    set cpx2 [expr {$rad*cos($ang+$pi/2.0)+$cpx}]
    set cpy2 [expr {$rad*sin($ang+$pi/2.0)+$cpy}]
    set coords [list $cx $cy $cpx $cpy $cpx2 $cpy2]
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid ELLIPSECTRTAN
    return 0 ;# Also allow default coordlist transform
}


proc plugin_circlectr_shearobj {canv objid coords sx sy cx cy} {
    constants pi
    foreach {cx cy cpx cpy} $coords break
    set rad [expr {hypot($cpy-$cy,$cpx-$cx)}]
    set ang [expr {atan2($cpy-$cy,$cpx-$cx)}]
    set cpx2 [expr {$rad*cos($ang+$pi/2.0)+$cpx}]
    set cpy2 [expr {$rad*sin($ang+$pi/2.0)+$cpy}]
    set coords [list $cx $cy $cpx $cpy $cpx2 $cpy2]
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid ELLIPSECTRTAN
    return 0 ;# Also allow default coordlist transform
}


proc plugin_circlectr_scaleobj {canv objid coords sx sy cx cy} {
    if {abs($sx-$sy) > 1e-6} {
        constants pi
        foreach {cx cy cpx cpy} $coords break
        set rad [expr {hypot($cpy-$cy,$cpx-$cx)}]
        set ang [expr {atan2($cpy-$cy,$cpx-$cx)}]
        set cpx2 [expr {$rad*cos($ang+$pi/2.0)+$cpx}]
        set cpy2 [expr {$rad*sin($ang+$pi/2.0)+$cpy}]
        set coords [list $cx $cy $cpx $cpy $cpx2 $cpy2]
        cadobjects_object_set_coords $canv $objid $coords
        cadobjects_object_settype $canv $objid ELLIPSECTRTAN
    }
    return 0 ;# Also allow default coordlist transform
}


proc plugin_circlectr_drawobj {canv objid coords tags color fill width dash} {
    set coords [cadobjects_scale_coords $canv $coords]
    foreach {cx cy cpx1 cpy1} $coords break
    set radius [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    cadobjects_object_draw_center_cross $canv $cx $cy $radius $tags $color $width
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_circlectr_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid CIRCLECTR $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_circlectr_recalculate {canv objid coords {flags ""}} {
    # Nothing to do.  The control points are all the data needed.
}


proc plugin_circlectr_pointsofinterest {canv objid coords nearx neary} {
    foreach {cx cy cpx1 cpy1} $coords break
    set radius [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set x0 [expr {$cx-$radius}]
    set y0 [expr {$cy-$radius}]
    set x1 [expr {$cx+$radius}]
    set y1 [expr {$cy+$radius}]
    set ang [expr {atan2($neary-$cy,$nearx-$cx)}]
    set ix [expr {$radius*cos($ang)+$cx}]
    set iy [expr {$radius*sin($ang)+$cy}]

    set poi {}

    set prevpt [cadobjects_get_prev_point $canv]
    if {$prevpt != ""} {
        foreach {ox oy} $prevpt break
        cadobjects_calculate_tangent_pois poi $cx $cy $radius $ox $oy
    }

    lappend poi "controlpoints" $cx   $cy   "Center Point"   1
    lappend poi "controlpoints" $cpx1 $cpy1 "Control Point"  2
    lappend poi "quadrants"     $x0   $cy   "Quadrant"      -1
    lappend poi "quadrants"     $cx   $y0   "Quadrant"      -1
    lappend poi "quadrants"     $x1   $cy   "Quadrant"      -1
    lappend poi "quadrants"     $cx   $y1   "Quadrant"      -1
    lappend poi "contours"      $ix   $iy   "On Circle"     -1
    return $poi
}


proc plugin_circlectr_dragctls {canv objid coords nodes dx dy} {
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


proc plugin_circlectr_decompose {canv objid coords allowed} {
    foreach {cx cy cpx1 cpy1} $coords break
    set radius [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
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
        return [list ELLIPSE [list $cx $cy $radius $radius]]
    } elseif {"ELLIPSEROT" in $allowed} {
        return [list ELLIPSEROT [list $cx $cy $radius $radius 0.0]]
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


proc plugin_circlectr_nearest_point {canv objid coords x y} {
    foreach {cx cy cpx1 cpy1} $coords break
    set ang [expr {atan2($y-$cy,$x-$cx)}]
    set rad [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set nx [expr {$rad*cos($ang)+$cx}]
    set ny [expr {$rad*sin($ang)+$cx}]
    return [list $nx $ny]
}


proc plugin_circlectr_bbox {canv objid coords} {
    foreach {cx cy cpx1 cpy1} $coords break
    set rad [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set minx [expr {$cx-$rad}]
    set miny [expr {$cy-$rad}]
    set maxx [expr {$cx+$rad}]
    set maxy [expr {$cy+$rad}]
    return [list $minx $miny $maxx $maxy]
}


proc plugin_circlectr_offsetcopyobj {canv objid coords offset} {
    foreach {cx cy cpx1 cpy1} $coords break
    set rad [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set ang1 [expr {atan2($cpy1-$cy,$cpx1-$cx)}]
    if {$offset >= $rad} {
        return ""
    }
    set rad [expr {$rad-$offset}]
    set cpx1 [expr {$cx+$rad*cos($ang1)}]
    set cpy1 [expr {$cy+$rad*sin($ang1)}]
    set nuobj [cadobjects_object_create $canv CIRCLECTR [list $cx $cy $cpx1 $cpy1] {}]
    return $nuobj
}


proc plugin_circlectr_sliceobj {canv objid coords x y} {
    foreach {cx cy cpx1 cpy1} $coords break
    set rad [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set ang [expr {atan2($y-$cy,$x-$cx)}]

    set srad [expr {hypot($y-$cy,$x-$cx)}]
    set closeenough [cadobjects_get_closeenough $canv $objid]
    if {abs($srad-$rad) > $closeenough} {
        return $objid
    }

    set cpx2 [expr {$cx+$rad*cos($ang)}]
    set cpy2 [expr {$cy+$rad*sin($ang)}]
    cadobjects_object_set_coords $canv $objid [list $cx $cy $cpx2 $cpy2 $cpx2 $cpy2]
    cadobjects_object_settype $canv $objid ARCCTR
    return [list $objid]
}









proc plugin_circle2pt_editfields {canv objid coords} {
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
        name POINT1
        datum #0
        title "Point 1"
    }
    lappend out {
        type POINT
        name POINT2
        datum #1
        title "Point 2"
    }
    return $out
}


proc plugin_circle2pt_transformobj {canv objid coords mat} {
    constants pi
    foreach {cpx1 cpy1 cpx2 cpy2} $coords break
    set rad [expr {hypot($cpy2-$cpy1,$cpx2-$cpx1)/2.0}]
    set ang [expr {atan2($cpy2-$cpy1,$cpx2-$cpx1)}]
    set cpx3 [expr {$rad*cos($ang+$pi/2.0)+$cpx2}]
    set cpy3 [expr {$rad*sin($ang+$pi/2.0)+$cpy2}]
    set coords [list $cpx1 $cpy1 $cpx2 $cpy2 $cpx3 $cpy3]
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid ELLIPSEOPPTAN
    return 0 ;# Also allow default coordlist transform
}


proc plugin_circle2pt_shearobj {canv objid coords sx sy cx cy} {
    constants pi
    foreach {cpx1 cpy1 cpx2 cpy2} $coords break
    set rad [expr {hypot($cpy2-$cpy1,$cpx2-$cpx1)/2.0}]
    set ang [expr {atan2($cpy2-$cpy1,$cpx2-$cpx1)}]
    set cpx3 [expr {$rad*cos($ang+$pi/2.0)+$cpx2}]
    set cpy3 [expr {$rad*sin($ang+$pi/2.0)+$cpy2}]
    set coords [list $cpx1 $cpy1 $cpx2 $cpy2 $cpx3 $cpy3]
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid ELLIPSEOPPTAN
    return 0 ;# Also allow default coordlist transform
}


proc plugin_circle2pt_scaleobj {canv objid coords sx sy cx cy} {
    if {abs($sx-$sy) > 1e-6} {
        constants pi
        foreach {cpx1 cpy1 cpx2 cpy2} $coords break
        set rad [expr {hypot($cpy2-$cpy1,$cpx2-$cpx1)/2.0}]
        set ang [expr {atan2($cpy2-$cpy1,$cpx2-$cpx1)}]
        set cpx3 [expr {$rad*cos($ang+$pi/2.0)+$cpx2}]
        set cpy3 [expr {$rad*sin($ang+$pi/2.0)+$cpy2}]
        set coords [list $cpx1 $cpy1 $cpx2 $cpy2 $cpx3 $cpy3]
        cadobjects_object_set_coords $canv $objid $coords
        cadobjects_object_settype $canv $objid ELLIPSEOPPTAN
    }
    return 0 ;# Also allow default coordlist transform
}


proc plugin_circle2pt_drawobj {canv objid coords tags color fill width dash} {
    set coords [cadobjects_scale_coords $canv $coords]
    foreach {cpx1 cpy1 cpx2 cpy2} $coords break
    set radius [expr {hypot($cpy2-$cpy1,$cpx2-$cpx1)/2.0}]
    set cx [expr {($cpx1+$cpx2)/2.0}]
    set cy [expr {($cpy1+$cpy2)/2.0}]
    cadobjects_object_draw_center_cross $canv $cx $cy $radius $tags $color $width
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_circle2pt_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid CIRCLE2PT $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_circle2pt_recalculate {canv objid coords {flags ""}} {
    # Nothing to do.  The control points are all the data needed.
}


proc plugin_circle2pt_pointsofinterest {canv objid coords nearx neary} {
    foreach {cpx1 cpy1 cpx2 cpy2} $coords break
    set cx [expr {($cpx1+$cpx2)/2.0}]
    set cy [expr {($cpy1+$cpy2)/2.0}]
    set radius [expr {hypot($cpy2-$cy,$cpx2-$cx)}]
    set x0 [expr {$cx-$radius}]
    set y0 [expr {$cy-$radius}]
    set x1 [expr {$cx+$radius}]
    set y1 [expr {$cy+$radius}]
    set ang [expr {atan2($neary-$cy,$nearx-$cx)}]
    set ix [expr {$radius*cos($ang)+$cx}]
    set iy [expr {$radius*sin($ang)+$cy}]

    set poi {}

    set prevpt [cadobjects_get_prev_point $canv]
    if {$prevpt != ""} {
        foreach {ox oy} $prevpt break
        cadobjects_calculate_tangent_pois poi $cx $cy $radius $ox $oy
    }

    lappend poi "controlpoints" $cpx1 $cpy1 "Control Point"  1
    lappend poi "controlpoints" $cpx2 $cpy2 "Control Point"  2
    lappend poi "controlpoints" $cx   $cy   "Center Point"  -1
    lappend poi "quadrants"     $x0   $cy   "Quadrant"      -1
    lappend poi "quadrants"     $cx   $y0   "Quadrant"      -1
    lappend poi "quadrants"     $x1   $cy   "Quadrant"      -1
    lappend poi "quadrants"     $cx   $y1   "Quadrant"      -1
    lappend poi "contours"      $ix   $iy   "On Circle"     -1
    return $poi
}


proc plugin_circle2pt_decompose {canv objid coords allowed} {
    foreach {cpx1 cpy1 cpx2 cpy2} $coords break
    set cx [expr {($cpx1+$cpx2)/2.0}]
    set cy [expr {($cpy1+$cpy2)/2.0}]
    set radius [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
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
        return [list ELLIPSE [list $cx $cy $radius $radius]]
    } elseif {"ELLIPSEROT" in $allowed} {
        return [list ELLIPSEROT [list $cx $cy $radius $radius 0.0]]
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


proc plugin_circle2pt_nearest_point {canv objid coords x y} {
    foreach {cpx1 cpy1 cpx2 cpy2} $coords break
    set cx [expr {($cpx1+$cpx2)/2.0}]
    set cy [expr {($cpy1+$cpy2)/2.0}]
    set ang [expr {atan2($y-$cy,$x-$cx)}]
    set rad [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set nx [expr {$rad*cos($ang)+$cx}]
    set ny [expr {$rad*sin($ang)+$cx}]
    return [list $nx $ny]
}


proc plugin_circle2pt_bbox {canv objid coords} {
    foreach {cpx1 cpy1 cpx2 cpy2} $coords break
    set cx [expr {($cpx1+$cpx2)/2.0}]
    set cy [expr {($cpy1+$cpy2)/2.0}]
    set rad [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set minx [expr {$cx-$rad}]
    set miny [expr {$cy-$rad}]
    set maxx [expr {$cx+$rad}]
    set maxy [expr {$cy+$rad}]
    return [list $minx $miny $maxx $maxy]
}


proc plugin_circle2pt_offsetcopyobj {canv objid coords offset} {
    foreach {cpx1 cpy1 cpx2 cpy2} $coords break
    set cx [expr {($cpx1+$cpx2)/2.0}]
    set cy [expr {($cpy1+$cpy2)/2.0}]
    set rad [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set ang1 [expr {atan2($cpy1-$cy,$cpx1-$cx)}]
    set ang2 [expr {atan2($cpy2-$cy,$cpx2-$cx)}]
    if {$offset >= $rad} {
        return ""
    }
    set rad [expr {$rad-$offset}]
    set cpx1 [expr {$cx+$rad*cos($ang1)}]
    set cpy1 [expr {$cy+$rad*sin($ang1)}]
    set cpx2 [expr {$cx+$rad*cos($ang2)}]
    set cpy2 [expr {$cy+$rad*sin($ang2)}]
    set nuobj [cadobjects_object_create $canv CIRCLE2PT [list $cpx1 $cpy1 $cpx2 $cpy2] {}]
    return $nuobj
}


proc plugin_circle2pt_sliceobj {canv objid coords x y} {
    foreach {cpx1 cpy1 cpx2 cpy2} $coords break
    set cx [expr {($cpx1+$cpx2)/2.0}]
    set cy [expr {($cpy1+$cpy2)/2.0}]
    set rad [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set ang [expr {atan2($y-$cy,$x-$cx)}]

    set srad [expr {hypot($y-$cy,$x-$cx)}]
    set closeenough [cadobjects_get_closeenough $canv $objid]
    if {abs($srad-$rad) > $closeenough} {
        return $objid
    }

    set cpx2 [expr {$cx+$rad*cos($ang)}]
    set cpy2 [expr {$cy+$rad*sin($ang)}]
    cadobjects_object_set_coords $canv $objid [list $cx $cy $cpx2 $cpy2 $cpx2 $cpy2]
    cadobjects_object_settype $canv $objid ARCCTR
    return [list $objid]
}






proc plugin_circle3pt_editfields {canv objid coords} {
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
        name POINT1
        datum #0
        title "Point 1"
    }
    lappend out {
        type POINT
        name POINT2
        datum #1
        title "Point 2"
    }
    lappend out {
        type POINT
        name POINT3
        datum #2
        title "Point 3"
    }
    return $out
}


proc plugin_circle3pt_transformobj {canv objid coords mat} {
    set isline [cadobjects_object_getdatum $canv $objid "ISLINE"]
    if {$isline} {
        cadobjects_object_settype $canv $objid LINES
    } else {
        set boxcoords [cadobjects_object_getdatum $canv $objid "BOX"]
        foreach {x0 y0 x1 y1} $boxcoords break
        set cx [expr {($x0+$x1)/2.0}]
        set cy [expr {($y0+$y1)/2.0}]
        set coords [list $cx $cy $x1 $cy $x1 $y1]
        cadobjects_object_set_coords $canv $objid $coords
        cadobjects_object_settype $canv $objid ELLIPSECTRTAN
    }
    return 0 ;# Also allow default coordlist transform
}


proc plugin_circle3pt_shearobj {canv objid coords sx sy cx cy} {
    plugin_circle3pt_transformobj $canv $objid $coords {}
    return 0 ;# Also allow default coordlist transform
}


proc plugin_circle3pt_scaleobj {canv objid coords sx sy cx cy} {
    if {abs($sx-$sy) > 1e-6} {
        plugin_circle3pt_transformobj $canv $objid $coords {}
    }
    return 0 ;# Also allow default coordlist transform
}


proc plugin_circle3pt_drawobj {canv objid coords tags color fill width dash} {
    set isline [cadobjects_object_getdatum $canv $objid "ISLINE"]
    if {!$isline} {
        set boxcoords [cadobjects_object_getdatum $canv $objid "BOX"]
        foreach {x0 y0 x1 y1} [cadobjects_scale_coords $canv $boxcoords] break
        set cx [expr {($x0+$x1)/2.0}]
        set cy [expr {($y0+$y1)/2.0}]
        set radius [expr {abs($cx-$x0)}]
        cadobjects_object_draw_center_cross $canv $cx $cy $radius $tags $color $width
    }
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_circle3pt_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid CIRCLE3PT $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_circle3pt_recalculate {canv objid coords {flags ""}} {
    foreach {cpx1 cpy1 cpx2 cpy2 cpx3 cpy3} $coords break
    set mx1 [expr {($cpx1+$cpx3)/2.0}]
    set my1 [expr {($cpy1+$cpy3)/2.0}]
    set mx2 [expr {($cpx2+$cpx3)/2.0}]
    set my2 [expr {($cpy2+$cpy3)/2.0}]
    cadobjects_object_setdatum $canv $objid "ISLINE" 0
    set col [expr {$cpx1*($cpy2-$cpy3)+$cpx2*($cpy3-$cpy1)+$cpx3*($cpy1-$cpy2)}]
    if {abs($col) < 1e-6} {
        # Points are colinear.  Draw this as a straight line.
        cadobjects_object_setdatum $canv $objid "ISLINE" 1
        return
    }
    if {abs($cpy3-$cpy1) < 1e-6} {
        # Segment1 is Horizontal.  We know Segment2 is not collinear.
        set m2 [expr {-($cpx2-$cpx3)/($cpy2-$cpy3)}]
        set c2 [expr {$my2-$m2*$mx2}]
        set cx $mx1
        set cy [expr {$m2*$cx+$c2}]
    } elseif {abs($cpy3-$cpy2) < 1e-6} {
        # Segment2 is Horizontal.  We know Segment1 is not collinear.
        set m1 [expr {-($cpx3-$cpx1)/($cpy3-$cpy1)}]
        set c1 [expr {$my1-$m1*$mx1}]
        set cx $mx2
        set cy [expr {$m1*$cx+$c1}]
    } else {
        set m1 [expr {-($cpx3-$cpx1)/($cpy3-$cpy1)}]
        set m2 [expr {-($cpx2-$cpx3)/($cpy2-$cpy3)}]
        set c1 [expr {$my1-$m1*$mx1}]
        set c2 [expr {$my2-$m2*$mx2}]
        set cx [expr {($c2-$c1)/($m1-$m2)}]
        set cy [expr {$m1*$cx+$c1}]
    }
    set radius [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set x0 [expr {$cx-$radius}]
    set y0 [expr {$cy-$radius}]
    set x1 [expr {$cx+$radius}]
    set y1 [expr {$cy+$radius}]
    cadobjects_object_setdatum $canv $objid "BOX" [list $x0 $y0 $x1 $y1]
}


proc plugin_circle3pt_pointsofinterest {canv objid coords nearx neary} {
    foreach {cpx1 cpy1 cpx2 cpy2 cpx3 cpy3} $coords break
    set isline [cadobjects_object_getdatum $canv $objid "ISLINE"]
    set boxcoords  [cadobjects_object_getdatum $canv $objid "BOX"]
    if {!$isline} {
        foreach {x0 y0 x1 y1} $boxcoords break
        set cx [expr {($x0+$x1)/2.0}]
        set cy [expr {($y0+$y1)/2.0}]
        set radius [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
        set ang [expr {atan2($neary-$cy,$nearx-$cx)}]
        set ix [expr {$radius*cos($ang)+$cx}]
        set iy [expr {$radius*sin($ang)+$cy}]
    }

    set poi {}

    set prevpt [cadobjects_get_prev_point $canv]
    if {$prevpt != ""} {
        foreach {ox oy} $prevpt break
        cadobjects_calculate_tangent_pois poi $cx $cy $radius $ox $oy
    }

    lappend poi "controlpoints" $cpx1 $cpy1 "Control Point"  1
    lappend poi "controlpoints" $cpx2 $cpy2 "Control Point"  2
    lappend poi "controlpoints" $cpx3 $cpy3 "Control Point"  3
    if {!$isline} {
        lappend poi "controlpoints" $cx   $cy   "Center Point"  -1
        lappend poi "quadrants"     $x0   $cy   "Quadrant"      -1
        lappend poi "quadrants"     $cx   $y0   "Quadrant"      -1
        lappend poi "quadrants"     $x1   $cy   "Quadrant"      -1
        lappend poi "quadrants"     $cx   $y1   "Quadrant"      -1
        lappend poi "contours"      $ix   $iy   "On Circle"     -1
    }
    return $poi
}


proc plugin_circle3pt_decompose {canv objid coords allowed} {
    foreach {cpx1 cpy1 cpx2 cpy2 cpx3 cpy3} $coords break
    plugin_circle3pt_recalculate $canv $objid $coords
    set isline [cadobjects_object_getdatum $canv $objid "ISLINE"]
    if {!$isline} {
        set boxcoords [cadobjects_object_getdatum $canv $objid "BOX"]
        foreach {x0 y0 x1 y1} $boxcoords break
        set cx [expr {($x0+$x1)/2.0}]
        set cy [expr {($y0+$y1)/2.0}]
        set radius [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    }
    if {$isline} {
        if {"LINES" in $allowed} {
            return [list LINES $coords]
        }
    } elseif {"CIRCLE" in $allowed} {
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
        return [list ELLIPSE [list $cx $cy $radius $radius]]
    } elseif {"ELLIPSEROT" in $allowed} {
        return [list ELLIPSEROT [list $cx $cy $radius $radius 0.0]]
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


proc plugin_circle3pt_nearest_point {canv objid coords x y} {
    foreach {cpx1 cpy1 cpx2 cpy2 cpx3 cpy3} $coords break
    set isline [cadobjects_object_getdatum $canv $objid "ISLINE"]
    if {!$isline} {
        set boxcoords [cadobjects_object_getdatum $canv $objid "BOX"]
        foreach {x0 y0 x1 y1} $boxcoords break
        set cx [expr {($x0+$x1)/2.0}]
        set cy [expr {($y0+$y1)/2.0}]
        set rad [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
        set ang [expr {atan2($y-$cy,$x-$cx)}]
        set nx [expr {$rad*cos($ang)+$cx}]
        set ny [expr {$rad*sin($ang)+$cx}]
        return [list $nx $ny]
    }
    return ""
}


proc plugin_circle3pt_bbox {canv objid coords} {
    set isline [cadobjects_object_getdatum $canv $objid "ISLINE"]
    if {$isline} {
        return [geometry_pointlist_bbox $coords]
    } else {
        set coords [cadobjects_object_getdatum $canv $objid "BOX"]
        return [geometry_pointlist_bbox $coords]
    }
}


proc plugin_circle3pt_offsetcopyobj {canv objid coords offset} {
    foreach {cpx1 cpy1 cpx2 cpy2 cpx3 cpy3} $coords break

    foreach {cx cy rad sang eang} [mlcnc_find_arc_from_points $cpx1 $cpy1 $cpx2 $cpy2 $cpx3 $cpy3] break
    if {![info exists cx]} {
        return ""
    }
    set ang1 [expr {atan2($cpy1-$cy,$cpx1-$cx)}]
    set ang2 [expr {atan2($cpy2-$cy,$cpx2-$cx)}]
    set ang3 [expr {atan2($cpy3-$cy,$cpx3-$cx)}]
    if {$offset >= $rad} {
        return ""
    }
    set rad [expr {$rad-$offset}]
    set cpx1 [expr {$cx+$rad*cos($ang1)}]
    set cpy1 [expr {$cy+$rad*sin($ang1)}]
    set cpx2 [expr {$cx+$rad*cos($ang2)}]
    set cpy2 [expr {$cy+$rad*sin($ang2)}]
    set cpx3 [expr {$cx+$rad*cos($ang3)}]
    set cpy3 [expr {$cy+$rad*sin($ang3)}]
    set nuobj [cadobjects_object_create $canv CIRCLE3PT [list $cpx1 $cpy1 $cpx2 $cpy2 $cpx3 $cpy3] {}]
    return $nuobj
}


proc plugin_circle3pt_sliceobj {canv objid coords x y} {
    foreach {cpx1 cpy1 cpx2 cpy2 cpx3 cpy3} $coords break
    set isline [cadobjects_object_getdatum $canv $objid "ISLINE"]
    if {$isline} {
        return [list $objid]
    }

    set boxcoords [cadobjects_object_getdatum $canv $objid "BOX"]
    foreach {x0 y0 x1 y1} $boxcoords break
    set cx [expr {($x0+$x1)/2.0}]
    set cy [expr {($y0+$y1)/2.0}]

    set rad [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set ang [expr {atan2($y-$cy,$x-$cx)}]

    set srad [expr {hypot($y-$cy,$x-$cx)}]
    set closeenough [cadobjects_get_closeenough $canv $objid]
    if {abs($srad-$rad) > $closeenough} {
        return $objid
    }

    set cpx2 [expr {$cx+$rad*cos($ang)}]
    set cpy2 [expr {$cy+$rad*sin($ang)}]
    cadobjects_object_set_coords $canv $objid [list $cx $cy $cpx2 $cpy2 $cpx2 $cpy2]
    cadobjects_object_settype $canv $objid ARCCTR
    return [list $objid]
}






proc plugin_circles_register {} {
    tool_register_ex CIRCLECTR "&Circles" "Circle by &Center pt" {
        {1    "Centerpoint"}
        {2    "Point on Circle"}
    } -icon "tool-circlectr" -creator
    tool_register_ex CIRCLE2PT "&Circles" "Circle by &Opposing pts" {
        {1    "Point on Circle"}
        {2    "Opposite Point on Circle"}
    } -icon "tool-circle2pt" -creator
    tool_register_ex CIRCLE3PT "&Circles" "Circle by &3 pts" {
        {1    "First Point on Circle"}
        {3    "Second Point on Circle"}
        {2    "Third Point on Circle"}
    } -icon "tool-circle3pt" -creator
}
plugin_circles_register 


# vim: set ts=4 sw=4 nowrap expandtab: settings

