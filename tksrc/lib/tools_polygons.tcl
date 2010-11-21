proc plugin_rectangle_editfields {canv objid coords} {
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
        type FLOAT
        name XSIZE
        datum ""
        title "Width"
        min 0.0
        max 1e9
        increment 0.125
        width 8
        valgetcb "plugin_rectangle_getfield"
        valsetcb "plugin_rectangle_setfield"
        islength 1
    }
    lappend out {
        type FLOAT
        name YSIZE
        datum ""
        title "Height"
        min 0.0
        max 1e9
        increment 0.125
        width 8
        valgetcb "plugin_rectangle_getfield"
        valsetcb "plugin_rectangle_setfield"
        islength 1
    }
    lappend out {
        type FLOAT
        name XRADIUS
        datum ""
        title "X Radius"
        min 0.0
        max 1e9
        increment 0.0625
        default 0.0
        width 8
        valgetcb "plugin_rectangle_getfield"
        valsetcb "plugin_rectangle_setfield"
        islength 1
    }
    lappend out {
        type FLOAT
        name YRADIUS
        datum ""
        title "Y Radius"
        min 0.0
        max 1e9
        increment 0.0625
        default 0.0
        width 8
        valgetcb "plugin_rectangle_getfield"
        valsetcb "plugin_rectangle_setfield"
        islength 1
    }
    return $out
}


proc plugin_rectangle_getfield {canv objid coords field} {
    constants pi
    foreach {cx0 cy0 cx1 cy1 cx2 cy2} $coords break
    if {[llength $coords] < 6} {
        set cx2 $cx0
        set cy2 $cy1
    }
    switch -exact -- $field {
        XSIZE {
            set d [expr {abs($cx1-$cx0)}]
            return $d
        }
        YSIZE {
            set d [expr {abs($cy1-$cy0)}]
            return $d
        }
        XRADIUS {
            set d [expr {min(abs($cx2-$cx0),abs($cx2-$cx1))}]
            return $d
        }
        YRADIUS {
            set d [expr {min(abs($cy2-$cy0),abs($cy2-$cy1))}]
            return $d
        }
    }
}


proc plugin_rectangle_setfield {canv objid coords field val} {
    foreach {cx0 cy0 cx1 cy1 cx2 cy2} $coords break
    if {[llength $coords] < 6} {
        set cx2 $cx0
        set cy2 $cy1
    }
    set height [expr {abs($cy1-$cy0)}]
    set width [expr {abs($cx1-$cx0)}]

    switch -exact -- $field {
        YSIZE {
            set d 0.0
            if {$height > 1e-6} {
                set d [expr {$val/$height}]
                set cy1 [expr {($cy1-$cy0)*$d+$cy0}]
            } else {
                set cy1 [expr {$val+$cy0}]
            }
            set coords [list $cx0 $cy0 $cx1 $cy1 $cx2 $cy2]
            cadobjects_object_set_coords $canv $objid $coords
        }
        XSIZE {
            set d 0.0
            if {$width > 1e-6} {
                set d [expr {$val/$width}]
                set cx1 [expr {($cx1-$cx0)*$d+$cx0}]
            } else {
                set cx1 [expr {$val+$cx0}]
            }
            set coords [list $cx0 $cy0 $cx1 $cy1 $cx2 $cy2]
            cadobjects_object_set_coords $canv $objid $coords
        }
        XRADIUS {
            set nx2 [expr {$cx1-$val*sign($cx1-$cx0)}]
            if {abs($nx2-$cx2) > 1e-6} {
                set coords [list $cx0 $cy0 $cx1 $cy1 $nx2 $cy2]
                cadobjects_object_set_coords $canv $objid $coords
            }
        }
        YRADIUS {
            set ny2 [expr {$cy1-$val*sign($cy1-$cy0)}]
            if {abs($ny2-$cy2) > 1e-6} {
                set coords [list $cx0 $cy0 $cx1 $cy1 $cx2 $ny2]
                cadobjects_object_set_coords $canv $objid $coords
            }
        }
    }
}


proc plugin_rectangle_initobj {canv objid coords} {
}


proc plugin_rectangle_transformobj {canv objid coords mat} {
    foreach {typ nucoords} [plugin_rectangle_decompose $canv $objid $coords {LINES BEZIER}] break
    cadobjects_object_set_coords $canv $objid $nucoords
    if {$typ == "LINES"} {
        set typ LINE
    }
    cadobjects_object_settype $canv $objid $typ
    return 0 ;# Also allow default coordlist transforms
}


proc plugin_rectangle_flipobj {canv objid coords x0 y0 x1 y1} {
    if {abs($x1-$x0) > 1e-5 && abs($y1-$y0) > 1e-5} {
        plugin_rectangle_transformobj $canv $objid $coords ""
    }
    return 0 ;# Also allow default coordlist transforms
}


proc plugin_rectangle_shearobj {canv objid coords sx sy cx cy} {
    plugin_rectangle_transformobj $canv $objid $coords ""
    return 0 ;# Also allow default coordlist transforms
}


proc plugin_rectangle_rotateobj {canv objid coords rotang cx cy} {
    if {abs(fmod($rotang,90.0)) > 1e-5} {
        plugin_rectangle_transformobj $canv $objid $coords ""
    }
    return 0 ;# Also allow default coordlist transforms
}


proc plugin_rectangle_drawobj {canv objid coords tags color fill width dash} {
    if {[llength $coords] > 4} {
        set coords [cadobjects_scale_coords $canv $coords]
        foreach {x0 y0 x1 y1 x2 y2} $coords break
        set rx [expr {min(abs($x2-$x0),abs($x2-$x1))}]
        set ry [expr {min(abs($y2-$y0),abs($y2-$y1))}]
        if {abs($x2-$x0) < abs($x2-$x1)} {
            cadobjects_object_draw_centerline $canv $x2 $y2 $x0 $y2 $tags $color
        } else {
            cadobjects_object_draw_centerline $canv $x2 $y2 $x1 $y2 $tags $color
        }
        if {abs($y2-$y0) < abs($y2-$y1)} {
            cadobjects_object_draw_centerline $canv $x2 $y2 $x2 $y0 $tags $color
        } else {
            cadobjects_object_draw_centerline $canv $x2 $y2 $x2 $y1 $tags $color
        }
    }
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_rectangle_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid RECTANGLE $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_rectangle_recalculate {canv objid coords {flags ""}} {
    foreach {x0 y0 x1 y1 x2 y2} $coords break
    if {[llength $coords] < 6} {
        set x2 $x0
        set y2 $y1
    }
    set ox2 $x2
    set oy2 $y2
    if {$x2 < min($x0,$x1)} {
        set x2 [expr {min($x0,$x1)}]
    }
    if {$x2 > max($x0,$x1)} {
        set x2 [expr {max($x0,$x1)}]
    }
    if {$y2 < min($y0,$y1)} {
        set y2 [expr {min($y0,$y1)}]
    }
    if {$y2 > max($y0,$y1)} {
        set y2 [expr {max($y0,$y1)}]
    }
    set width [expr {abs($x1-$x0)}]
    set height [expr {abs($y1-$y0)}]
    set cx [expr {($x0+$x1)/2.0}]
    set cy [expr {($y0+$y1)/2.0}]
    set rx [expr {min(abs($x2-$x0),abs($x2-$x1))}]
    set ry [expr {min(abs($y2-$y0),abs($y2-$y1))}]
    if {hypot($oy2-$y2,$ox2-$x2) > 1e-6} {
        if {[llength $coords] > 4} {
            set coords [list $x0 $y0 $x1 $y1 $x2 $y2]
        } else {
            set coords [list $x0 $y0 $x1 $y1]
        }
        cadobjects_object_set_coords $canv $objid $coords
    }

    if {abs($rx) < 1e-6 || abs($ry) < 1e-6} {
        set linepath [list $x0 $y0 $x1 $y0 $x1 $y1 $x0 $y1 $x0 $y0]
        set bezpath [bezutil_bezier_from_line $linepath]
    } else {
        set mx0 [expr {min($x0,$x1)}]
        set my0 [expr {min($y0,$y1)}]
        set mx3 [expr {max($x0,$x1)}]
        set my3 [expr {max($y0,$y1)}]

        set mx1 [expr {$mx0+$rx}]
        set my1 [expr {$my0+$ry}]
        set my2 [expr {$my3-$ry}]
        set mx2 [expr {$mx3-$rx}]

        set bezpath {}
        lappend bezpath $mx1 $my0 $mx1 $my0 $mx2 $my0
        bezutil_append_bezier_arc bezpath $mx2 $my1 $rx $ry 270 90
        lappend bezpath $mx3 $my1 $mx3 $my2
        bezutil_append_bezier_arc bezpath $mx2 $my2 $rx $ry 0 90
        lappend bezpath $mx2 $my3 $mx1 $my3
        bezutil_append_bezier_arc bezpath $mx1 $my2 $rx $ry 90 90
        lappend bezpath $mx0 $my2 $mx0 $my1
        bezutil_append_bezier_arc bezpath $mx1 $my1 $rx $ry 180 90
    }
    cadobjects_object_setdatum $canv $objid "BEZPATH" $bezpath
}


proc plugin_rectangle_pointsofinterest {canv objid coords nearx neary} {
    foreach {x0 y0 x1 y1 x2 y2} $coords break
    if {[llength $coords] < 6} {
        set x2 $x0
        set y2 $y1
    }
    set rx [expr {min(abs($x2-$x0),abs($x2-$x1))}]
    set ry [expr {min(abs($y2-$y0),abs($y2-$y1))}]
    set mx [expr {($x1+$x0)/2.0}]
    set my [expr {($y1+$y0)/2.0}]

    set poi {}
    lappend poi "controlpoints" $x0 $y0 "Endpoint" 1
    lappend poi "controlpoints" $x1 $y1 "Endpoint" 2
    lappend poi "controlpoints" $x1 $y0 "Endpoint" -1
    lappend poi "controlpoints" $x0 $y1 "Endpoint" -1
    lappend poi "midpoints"     $mx $y0 "Midpoint" -1
    lappend poi "midpoints"     $mx $y1 "Midpoint" -1
    lappend poi "midpoints"     $x0 $my "Midpoint" -1
    lappend poi "midpoints"     $x1 $my "Midpoint" -1

    set coords [cadobjects_object_getdatum $canv $objid "BEZPATH"]
    cadobjects_object_bezier_pois poi "contours" "On Rectangle" $coords $nearx $neary

    return $poi
}


proc plugin_rectangle_decompose {canv objid coords allowed} {
    foreach {x0 y0 x1 y1 x2 y2} $coords break
    if {[llength $coords] < 6} {
        set x2 $x0
        set y2 $y1
    }
    set rx [expr {min(abs($x2-$x0),abs($x2-$x1))}]
    set ry [expr {min(abs($y2-$y0),abs($y2-$y1))}]

    if {"RECTANGLE" in $allowed && ($rx < 1e-6 || $ry < 1e-6)} {
        return [list RECTANGLE [lrange $coords 0 3]]
    } elseif {"RRECT" in $allowed} {
        return [list RRECT [concat [lrange $coords 0 3] $rx $ry]]
    } elseif {"LINES" in $allowed && ($rx < 1e-6 || $ry < 1e-6)} {
        if {"GCODE" in $allowed} {
            set cutbit  [cadobjects_object_cutbit $canv $objid]
            set cutside [cadobjects_object_getdatum $canv $objid "CUTSIDE"]
            set cutdiam [mlcnc_tooldiam $cutbit]
            set offset 0.0
            if {$cutbit > 0} {
                if {$cutside == "inside"} {
                    set offset [expr {-$cutdiam/2.0}]
                } elseif {$cutside == "outside"} {
                    set offset [expr {$cutdiam/2.0}]
                }
            }
            if {$x0 > $x1} {
                set x0 [expr {$x0+$offset}]
                set x1 [expr {$x1-$offset}]
            } else {
                set x0 [expr {$x0-$offset}]
                set x1 [expr {$x1+$offset}]
            }
            if {$y0 > $y1} {
                set y0 [expr {$y0+$offset}]
                set y1 [expr {$y1-$offset}]
            } else {
                set y0 [expr {$y0-$offset}]
                set y1 [expr {$y1+$offset}]
            }
        }
        set path [list $x0 $y0  $x0 $y1  $x1 $y1  $x1 $y0  $x0 $y0]
        return [list LINES $path]
    } elseif {"BEZIER" in $allowed} {
        set path [cadobjects_object_getdatum $canv $objid "BEZPATH"]
        return [list BEZIER $path]
    } elseif {"LINES" in $allowed} {
        set bezpath [cadobjects_object_getdatum $canv $objid "BEZPATH"]
        set linepath {}
        bezutil_append_line_from_bezier linepath $bezpath
        if {"GCODE" in $allowed} {
            set cutbit  [cadobjects_object_cutbit $canv $objid]
            set cutside [cadobjects_object_getdatum $canv $objid "CUTSIDE"]
            set cutdiam [mlcnc_tooldiam $cutbit]
            set cutrad [expr {abs($cutdiam/2.0)}]
            set out {}
            if {$cutbit > 0} {
                if {$cutside == "inside"} {
                    foreach pline [mlcnc_path_inset $linepath $cutrad] {
                        lappend out LINES $pline
                    }
                } elseif {$cutside == "outside"} {
                    foreach pline [mlcnc_path_inset $linepath -$cutrad] {
                        lappend out LINES $pline
                    }
                } else {
                    lappend out LINES $linepath
                }
            }
            return $out
        }
        return [list LINES $linepath]
    }
    return {}
}


proc plugin_rectangle_bbox {canv objid coords} {
    return [geometry_pointlist_bbox $coords]
}






proc plugin_regpolygon_editfields {canv objid coords} {
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
        title "Control pt"
    }
    lappend out {
        type OPTIONS
        name STYLE
        title "Style"
        values {Inscribed inscribed Circumscribed circumscribed}
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
        valgetcb "plugin_regpolygon_getfield"
        valsetcb "plugin_regpolygon_setfield"
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
        valgetcb "plugin_regpolygon_getfield"
        valsetcb "plugin_regpolygon_setfield"
    }
    lappend out {
        type INT
        name SIDES
        title "# Sides"
        min 3
        max 999
        width 4
    }
    return $out
}


proc plugin_regpolygon_getfield {canv objid coords field} {
    constants pi
    foreach {cx cy cpx cpy} $coords break
    switch -exact -- $field {
        RADIUS {
            set d [expr {hypot($cpy-$cy,$cpx-$cx)}]
            return $d
        }
        ANGLE {
            set d [expr {atan2($cpy-$cy,$cpx-$cx)*180.0/$pi}]
            return $d
        }
    }
}


proc plugin_regpolygon_setfield {canv objid coords field val} {
    constants pi
    foreach {cx cy cpx cpy} $coords break
    set rad [expr {hypot($cpy-$cy,$cpx-$cx)}]

    switch -exact -- $field {
        RADIUS {
            if {abs($rad) < 1e-9} {
                set d 0.0
            } else {
                set d [expr {$val/$rad}]
            }
            set cpx [expr {($cpx-$cx)*$d+$cx}]
            set cpy [expr {($cpy-$cy)*$d+$cy}]
            set coords [list $cx $cy $cpx $cpy]
            cadobjects_object_set_coords $canv $objid $coords
        }
        ANGLE {
            set cpx [expr {$rad*cos($val*$pi/180.0)+$cx}]
            set cpy [expr {$rad*sin($val*$pi/180.0)+$cy}]
            set coords [list $cx $cy $cpx $cpy]
            cadobjects_object_set_coords $canv $objid $coords
        }
    }
}


proc plugin_regpolygon_initobj {canv objid coords} {
    cadobjects_object_setdatum $canv $objid "SIDES" 6
    cadobjects_object_setdatum $canv $objid "STYLE" "inscribed"
}


proc plugin_regpolygon_transformobj {canv objid coords mat} {
    set coords [cadobjects_object_getdatum $canv $objid "LINEPATH"]
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid LINE
    return 0 ;# Also allow default coordlist transforms
}


proc plugin_regpolygon_shearobj {canv objid coords sx sy cx cy} {
    plugin_regpolygon_transformobj $canv $objid $coords ""
    return 0 ;# Also allow default coordlist transforms
}


proc plugin_regpolygon_scaleobj {canv objid coords sx sy cx cy} {
    if {abs(abs($sx)-abs($sy)) > 1e-6} {
        plugin_regpolygon_transformobj $canv $objid $coords ""
    }
    return 0 ;# Also allow default coordlist transforms
}


proc plugin_regpolygon_drawobj {canv objid coords tags color fill width dash} {
    set coords [cadobjects_scale_coords $canv $coords]
    foreach {cx cy cpx cpy} $coords break
    set radius [expr {hypot($cpy-$cy,$cpx-$cx)/1.0}]
    cadobjects_object_draw_center_cross $canv $cx $cy $radius $tags $color $width
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_regpolygon_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid REGPOLYGON $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_regpolygon_recalculate {canv objid coords {flags ""}} {
    constants pi
    foreach {cx cy cpx cpy} $coords break
    set sides [cadobjects_object_getdatum $canv $objid "SIDES"]
    set style [cadobjects_object_getdatum $canv $objid "STYLE"]
    set ang [expr {atan2($cpy-$cy,$cpx-$cx)}]
    set radius [expr {hypot($cpy-$cy,$cpx-$cx)}]
    set stepang [expr {($pi*2.0)/$sides}]
    if {$style == "circumscribed"} {
        set ang [expr {$ang+$stepang/2.0}]
        set radius [expr {$radius/cos($stepang/2.0)}]
    }
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


proc plugin_regpolygon_pointsofinterest {canv objid coords nearx neary} {
    set linepath [cadobjects_object_getdatum $canv $objid "LINEPATH"]
    foreach {cx cy cpx cpy} $coords break
    set poi {}

    lappend poi "controlpoints" $cx $cy "Center Point" 1
    lappend poi "controlpoints" $cpx $cpy "Control Point" 2

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


proc plugin_regpolygon_dragctls {canv objid coords nodes dx dy} {
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


proc plugin_regpolygon_decompose {canv objid coords allowed} {
    foreach {cx cy cpx cpy} $coords break
    set linepath [cadobjects_object_getdatum $canv $objid "LINEPATH"]

    if {"REGPOLYGON" in $allowed} {
        return [list REGPOLYGON [list $cx $cy $cpx $cpy $sides $style]]
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


proc plugin_regpolygon_bbox {canv objid coords} {
    set linepath [cadobjects_object_getdatum $canv $objid "LINEPATH"]
    return [geometry_pointlist_bbox $linepath]
}







proc plugin_spiral_editfields {canv objid coords} {
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
        name ICTRLPT
        datum #1
        title "Inner pt"
    }
    lappend out {
        type POINT
        name OCTRLPT
        datum #2
        title "Outer pt"
    }
    lappend out {
        type FLOAT
        name IRADIUS
        datum ""
        title "Inner Radius"
        min 0.0
        max 1e6
        increment 0.125
        width 8
        valgetcb "plugin_spiral_getfield"
        valsetcb "plugin_spiral_setfield"
        islength 1
    }
    lappend out {
        type FLOAT
        name IANGLE
        datum ""
        title "Inner Angle"
        min -360.0
        max 360.0
        increment 5.0
        width 8
        valgetcb "plugin_spiral_getfield"
        valsetcb "plugin_spiral_setfield"
    }
    lappend out {
        type OPTIONS
        name SPINDIR
        title "Direction"
        values {Clockwise cw Counter-Clockwise ccw}
    }
    lappend out {
        type FLOAT
        name RADIUS
        datum ""
        title "Outer Radius"
        min 0.0
        max 1e6
        increment 0.125
        width 8
        valgetcb "plugin_spiral_getfield"
        valsetcb "plugin_spiral_setfield"
        islength 1
    }
    lappend out {
        type FLOAT
        name ANGLE
        datum ""
        title "Outer Angle"
        min -360.0
        max 360.0
        increment 5.0
        width 8
        valgetcb "plugin_spiral_getfield"
        valsetcb "plugin_spiral_setfield"
    }
    lappend out {
        type FLOAT
        name TURNS
        title "Turns"
        min 0.01
        max 1e6
        increment 1.0
        width 8
        valsetcb "plugin_spiral_setfield"
    }
    lappend out {
        type FLOAT
        name DIVERGENCE
        title "Exponent"
        min 0.01
        max 1000.00
        increment 0.1
        width 8
        valsetcb "plugin_spiral_setfield"
        default 1.0
    }
    return $out
}


proc plugin_spiral_getfield {canv objid coords field} {
    constants pi
    foreach {cx cy cpx1 cpy1 cpx2 cpy2} $coords break
    switch -exact -- $field {
        IRADIUS {
            set d [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
            return $d
        }
        RADIUS {
            set d [expr {hypot($cpy2-$cy,$cpx2-$cx)}]
            return $d
        }
        IANGLE {
            set d [expr {atan2($cpy1-$cy,$cpx1-$cx)*180.0/$pi}]
            return $d
        }
        ANGLE {
            set d [expr {atan2($cpy2-$cy,$cpx2-$cx)*180.0/$pi}]
            return $d
        }
    }
}


proc plugin_spiral_setfield {canv objid coords field val} {
    constants pi
    foreach {cx cy cpx1 cpy1 cpx2 cpy2} $coords break
    set irad [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set rad [expr {hypot($cpy2-$cy,$cpx2-$cx)}]

    switch -exact -- $field {
        IRADIUS {
            if {abs($irad) < 1e-9} {
                set cpx1 [expr {$cx+$val}]
                set cpy1 $cy
            } else {
                set d [expr {$val/$irad}]
                set cpx1 [expr {($cpx1-$cx)*$d+$cx}]
                set cpy1 [expr {($cpy1-$cy)*$d+$cy}]
            }
            set coords [list $cx $cy $cpx1 $cpy1 $cpx2 $cpy2]
            cadobjects_object_set_coords $canv $objid $coords
        }
        RADIUS {
            if {abs($rad) < 1e-9} {
                set cpx2 [expr {$cx+$val}]
                set cpy2 $cy
            } else {
                set d [expr {$val/$rad}]
                set cpx2 [expr {($cpx2-$cx)*$d+$cx}]
                set cpy2 [expr {($cpy2-$cy)*$d+$cy}]
            }
            set coords [list $cx $cy $cpx1 $cpy1 $cpx2 $cpy2]
            cadobjects_object_set_coords $canv $objid $coords
        }
        IANGLE {
            set cpx1 [expr {$irad*cos($val*$pi/180.0)+$cx}]
            set cpy1 [expr {$irad*sin($val*$pi/180.0)+$cy}]
            set coords [list $cx $cy $cpx1 $cpy1 $cpx2 $cpy2]
            cadobjects_object_set_coords $canv $objid $coords
        }
        ANGLE {
            set cpx2 [expr {$rad*cos($val*$pi/180.0)+$cx}]
            set cpy2 [expr {$rad*sin($val*$pi/180.0)+$cy}]
            set coords [list $cx $cy $cpx1 $cpy1 $cpx2 $cpy2]
            cadobjects_object_set_coords $canv $objid $coords
        }
        TURNS {
            set rad [expr {hypot($cpy2-$cy,$cpx2-$cx)}]
            set ang [expr {atan2($cpy2-$cy,$cpx2-$cx)}]
            set iang [expr {atan2($cpy1-$cy,$cpx1-$cx)}]
            if {$irad < 1e-6} {
                return
            }
            set frac [expr {$val-floor($val)}]
            set iang [expr {$ang-$frac*2.0*$pi}]
            set cpx1 [expr {$cx+cos($iang)*$irad}]
            set cpy1 [expr {$cy+sin($iang)*$irad}]
            set coords [list $cx $cy $cpx1 $cpy1 $cpx2 $cpy2]
            cadobjects_object_set_coords $canv $objid $coords
            cadobjects_object_setdatum $canv $objid "TURNS" $val
        }
    }
}


proc plugin_spiral_initobj {canv objid coords} {
    cadobjects_object_setdatum $canv $objid "SPINDIR" "cw"
    cadobjects_object_setdatum $canv $objid "TURNS" 5.0
    cadobjects_object_setdatum $canv $objid "DIVERGENCE" 1.0
}


proc plugin_spiral_transformobj {canv objid coords mat} {
    set coords [cadobjects_object_getdatum $canv $objid "BEZPATH"]
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid BEZIER
    return 0 ;# Also allow default coordlist transforms
}


proc plugin_spiral_shearobj {canv objid coords sx sy cx cy} {
    plugin_spiral_transformobj $canv $objid $coords ""
    return 0 ;# Also allow default coordlist transforms
}


proc plugin_spiral_scaleobj {canv objid coords sx sy cx cy} {
    if {abs(abs($sx)-abs($sy)) > 1e-6} {
        plugin_spiral_transformobj $canv $objid $coords ""
    }
    return 0 ;# Also allow default coordlist transforms
}


proc plugin_spiral_drawobj {canv objid coords tags color fill width dash} {
    set coords [cadobjects_scale_coords $canv $coords]
    foreach {cx cy cpx1 cpy1 cpx2 cpy2} $coords break
    set radius [expr {hypot($cpy2-$cy,$cpx2-$cx)/1.0}]
    cadobjects_object_draw_center_cross $canv $cx $cy $radius $tags $color $width
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_spiral_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid SPIRAL $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_spiral_recalculate {canv objid coords {flags ""}} {
    constants pi
    foreach {cx cy cpx1 cpy1 cpx2 cpy2} $coords break
    set spindir [cadobjects_object_getdatum $canv $objid "SPINDIR"]
    set turns [cadobjects_object_getdatum $canv $objid "TURNS"]
    set diverge [cadobjects_object_getdatum $canv $objid "DIVERGENCE"]

    set segments 16.0
    set ang [expr {atan2($cpy2-$cy,$cpx2-$cx)}]
    set rad [expr {hypot($cpy2-$cy,$cpx2-$cx)}]
    set iang [expr {atan2($cpy1-$cy,$cpx1-$cx)}]
    set irad [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    if {$irad < 1e-6} {
        set iang $ang
    }

    set dir 1.0
    if {$spindir == "ccw"} {
        set dir -1.0
    }

    if {$iang < 0} {
        set iang [expr {$iang+$pi*2.0}]
    }
    if {$ang < 0} {
        set ang [expr {$ang+$pi*2.0}]
    }
    if {$ang < $iang} {
        set ang [expr {$ang+$pi*2.0}]
    }
    set dang [expr {$ang-$iang}]
    set turns [expr {$turns+0.0}]
    if {$dir < 0.0} {
        set realturns [expr {ceil($turns)-$dang/(2.0*$pi)}]
    } else {
        set realturns [expr {floor($turns)+$dang/(2.0*$pi)}]
    }
    if {$realturns-$turns > 1.0} {
        set realturns [expr {$realturns-1.0}]
    } elseif {$turns-$realturns > 1.0} {
        set realturns [expr {$realturns+1.0}]
    }
    cadobjects_object_setdatum $canv $objid "TURNS" $realturns

    set steps [expr {int($realturns*$segments)}]
    set stepang [expr {$realturns*$dir*2.0*$pi/$steps}]
    set drad [expr {$rad-$irad}]
    set steprad [expr {$drad/pow($turns,$diverge)}]

    set bezpath {}
    for {set i 0.0} {$i <= $steps} {set i [expr {$i+$nxtincr}]} {
        set nxtincr [expr {$i<1.0? 0.0625: 1.0}]
        set rots [expr {abs($i*$stepang)/(2.0*$pi)}]

        set crad [expr {$irad+$steprad*pow($rots,$diverge)}]
        set cang [expr {$iang+$i*$stepang}]
        set px [expr {$crad*cos($cang)+$cx}]
        set py [expr {$crad*sin($cang)+$cy}]

        set qrots [expr {abs(($i+$nxtincr)*$stepang)/(2.0*$pi)}]
        set qrad [expr {$irad+$steprad*pow($qrots,$diverge)}]
        set qang [expr {$iang+($i+$nxtincr)*$stepang}]
        set qx [expr {$qrad*cos($qang)+$cx}]
        set qy [expr {$qrad*sin($qang)+$cy}]

        set prots [expr {$rots+1e-3}]
        set prad [expr {$irad+$steprad*pow($prots,$diverge)}]
        set pang [expr {$iang+$dir*$prots*2.0*$pi}]
        set perpx [expr {$prad*cos($pang)+$cx}]
        set perpy [expr {$prad*sin($pang)+$cy}]
        set perpang [expr {atan2($perpy-$py,$perpx-$px)}]
        if {abs($i) < 1e-6} {
            set perpang $iang
        }
        set perprad [expr {hypot($qy-$py,$qx-$px)/3.0}]

        if {$i > 0} {
            set pprad $perprad
            if {abs($i-1.0) < 1e-6} {
                set pprad [expr {$pprad*0.0625}]
            }
            set apx [expr {$px-cos($perpang)*$pprad}]
            set apy [expr {$py-sin($perpang)*$pprad}]
            lappend bezpath $apx $apy
        }
        lappend bezpath $px $py
        if {$i < $steps} {
            set zpx [expr {$px+cos($perpang)*$perprad}]
            set zpy [expr {$py+sin($perpang)*$perprad}]
            lappend bezpath $zpx $zpy
        }
    }
    cadobjects_object_setdatum $canv $objid "BEZPATH" $bezpath
}


proc plugin_spiral_pointsofinterest {canv objid coords nearx neary} {
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set scalemult [expr {$dpi*$scalefactor}]
    set linewidth [cadobjects_object_stroke_width $canv $objid]
    set closeenough [$canv cget -closeenough]
    set closeenough [expr {(5+$closeenough)/$scalemult+$linewidth/2.0}]
    set tolerance 1e-4

    set bezpath [cadobjects_object_getdatum $canv $objid "BEZPATH"]
    foreach {cx cy cpx1 cpy1 cpx2 cpy2} $coords break
    set poi {}

    lappend poi "controlpoints" $cx $cy "Center Point" 1
    lappend poi "controlpoints" $cpx1 $cpy1 "Control Point" 2
    lappend poi "controlpoints" $cpx2 $cpy2 "Control Point" 3

    cadobjects_object_bezier_pois poi "contours" "On Spiral" $bezpath $nearx $neary $closeenough $tolerance

    return $poi
}


proc plugin_spiral_dragctls {canv objid coords nodes dx dy} {
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


proc plugin_spiral_decompose {canv objid coords allowed} {
    foreach {cx cy cpx1 cpy1 cpx2 cpy2} $coords break
    set bezpath [cadobjects_object_getdatum $canv $objid "BEZPATH"]
    set spindir [cadobjects_object_getdatum $canv $objid "SPINDIR"]
    set diverge [cadobjects_object_getdatum $canv $objid "DIVERGENCE"]

    if {"GCODE" in $allowed && "LINES" in $allowed} {
        set linepath {}
        bezutil_append_line_from_bezier linepath $bezpath
        set cutbit  [cadobjects_object_cutbit $canv $objid]
        set cutside [cadobjects_object_getdatum $canv $objid "CUTSIDE"]
        set cutdiam [mlcnc_tooldiam $cutbit]
        set cutrad [expr {abs($cutdiam/2.0)}]
        set out {}
        if {$cutbit > 0} {
            if {$cutside == "inside"} {
                foreach pline [mlcnc_path_inset $linepath $cutrad] {
                    lappend out LINES $pline
                }
            } elseif {$cutside == "outside"} {
                foreach pline [mlcnc_path_inset $linepath -$cutrad] {
                    lappend out LINES $pline
                }
            } else {
                lappend out LINES $linepath
            }
        }
        return $out
    } elseif {"SPIRAL" in $allowed} {
        return [list SPIRAL [list $cx $cy $cpx1 $cpy1 $cpx2 $cpy2 $spindir $diverge]]
    } elseif {"BEZIER" in $allowed} {
        return [list BEZIER $bezpath]
    } elseif {"LINES" in $allowed} {
        set linepath {}
        bezutil_append_line_from_bezier linepath $bezpath
        return [list LINES $linepath]
    }
    return {}
}


proc plugin_spiral_bbox {canv objid coords} {
    foreach {cx cy cpx1 cpy1 cpx2 cpy2} $coords break
    set rad [expr {hypot($cpy2-$cy,$cpx2-$cx)}]
    set x0 [expr {$cx-$rad}]
    set y0 [expr {$cy-$rad}]
    set x1 [expr {$cx+$rad}]
    set y1 [expr {$cy+$rad}]
    set bbox [geometry_pointlist_bbox [list $x0 $y0 $x1 $y1]]
    return $bbox
}







proc plugin_spurgear_editfields {canv objid coords} {
    set out {}
    lappend out {
        type OPTIONS
        pane CAM
        name CUTSIDE
        title "Cut Side"
        width 8
        values {"On Line" center "Inside" inside "Outside" outside}
        default outside
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
        title "Control pt"
    }
    lappend out {
        type OPTIONS
        name STYLE
        title "Tooth Style"
        values {Involute involute Equilaeral equilateral "Ratchet CW" ratchetcw "Ratchet CCW" ratchetccw}
        default involute
    }
    lappend out {
        type INT
        name TEETH
        title "Teeth"
        min 4
        max 999
        width 4
        valgetcb "plugin_spurgear_getfield"
        valsetcb "plugin_spurgear_setfield"
    }
    lappend out {
        type FLOAT
        name PITCH
        title "Pitch"
        min 0.1
        max 100.0
        increment 1.0
        width 8
        valsetcb "plugin_spurgear_setfield"
        default 16.0
    }
    lappend out {
        type OPTIONS
        name "LOCKVAL"
        title "Lock Value"
        width 8
        values {Teeth teeth Pitch pitch Radius radius}
        default teeth
    }
    lappend out {
        type FLOAT
        name PRESSANG
        title "Pressure Ang."
        min 0.0
        max 30.00001
        increment 0.5
        width 8
        default 14.5
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
        valgetcb "plugin_spurgear_getfield"
        valsetcb "plugin_spurgear_setfield"
        islength 1
    }
    lappend out {
        type FLOAT
        name ANGLE
        datum ""
        title "Angle"
        min -360.0
        max 360.0
        increment 1.0
        width 8
        valgetcb "plugin_spurgear_getfield"
        valsetcb "plugin_spurgear_setfield"
    }
    return $out
}


proc plugin_spurgear_getfield {canv objid coords field} {
    constants pi radtodeg
    foreach {cx cy cpx cpy} $coords break
    set pitch [cadobjects_object_getdatum $canv $objid "PITCH"]
    set teeth [cadobjects_object_getdatum $canv $objid "TEETH"]
    set vlock [cadobjects_object_getdatum $canv $objid "LOCKVAL"]
    switch -exact -- $field {
        ANGLE {
            set ang [expr {atan2($cpy-$cy,$cpx-$cx)*$radtodeg}]
            return $ang
        }
        RADIUS {
            set r [expr {hypot($cpy-$cy,$cpx-$cx)}]
            if {$vlock == "pitch"} {
                set t [expr {int(2.0*$r*$pitch+0.5)}]
                if {$t < 3} {
                    set t 3
                }
                set r [expr {0.5*$t/$pitch}]
            }
            return $r
        }
        TEETH {
            if {$vlock == "pitch"} {
                # D = T / P
                # D * P = T
                set d [expr {hypot($cpy-$cy,$cpx-$cx)}]
                set t [expr {int(2.0*$d*$pitch+0.5)}]
                if {$t < 3} {
                    set t 3
                }
                return $t
            }
            return $teeth
        }
    }
}


proc plugin_spurgear_setfield {canv objid coords field val} {
    constants pi degtorad
    foreach {cx cy cpx cpy} $coords break
    set pitch [cadobjects_object_getdatum $canv $objid "PITCH"]
    set teeth [cadobjects_object_getdatum $canv $objid "TEETH"]
    set vlock [cadobjects_object_getdatum $canv $objid "LOCKVAL"]
    set rad [expr {hypot($cpy-$cy,$cpx-$cx)}]

    switch -exact -- $field {
        ANGLE {
            set cpx [expr {$rad*cos($val*$degtorad)+$cx}]
            set cpy [expr {$rad*sin($val*$degtorad)+$cy}]
            set coords [list $cx $cy $cpx $cpy]
            cadobjects_object_set_coords $canv $objid $coords
        }
        RADIUS {
            set t $teeth
            set p $pitch
            if {$vlock == "pitch"} {
                # T = D*P
                set t [expr {int(2.0*$val*$pitch+0.5)}]
                if {$t < 3} {
                    set t 3
                }
                set val [expr {0.5*$t/$pitch}]
            } else {
                # Num teeth or radius is locked.  Change pitch instead.
                # P = T/D
                set p [expr {0.5*$teeth/$val}]
            }
            if {abs($rad) < 1e-9} {
                set cpx [expr {$cx+$val}]
                set cpy $cy
            } else {
                set d [expr {$val/$rad}]
                set cpx [expr {($cpx-$cx)*$d+$cx}]
                set cpy [expr {($cpy-$cy)*$d+$cy}]
            }
            set coords [list $cx $cy $cpx $cpy]
            cadobjects_object_set_coords $canv $objid $coords
            if {$vlock == "pitch" || $vlock == "radius"} {
                cadobjects_object_setdatum $canv $objid "TEETH" $t
            } else {
                cadobjects_object_setdatum $canv $objid "PITCH" $p
            }
        }
        TEETH {
            if {$vlock == "pitch" || $vlock == "teeth"} {
                # D = T/P
                set nurad [expr {0.5*$val/$pitch}]
                if {abs($rad) < 1e-9} {
                    set cpx [expr {$cx+$nurad}]
                    set cpy $cy
                } else {
                    set d [expr {$nurad/$rad}]
                    set cpx [expr {($cpx-$cx)*$d+$cx}]
                    set cpy [expr {($cpy-$cy)*$d+$cy}]
                }
                set coords [list $cx $cy $cpx $cpy]
                cadobjects_object_set_coords $canv $objid $coords
            } else {
                # Radius is locked.  Change pitch instead.
                # P = T/D
                set p [expr {0.5*$val/$rad}]
                cadobjects_object_setdatum $canv $objid "PITCH" $p
            }
            cadobjects_object_setdatum $canv $objid "TEETH" $val
        }
        PITCH {
            if {$vlock == "pitch" || $vlock == "teeth"} {
                # D = T/P
                set nurad [expr {0.5*$teeth/$val}]
                if {abs($rad) < 1e-9} {
                    set cpx [expr {$cx+$nurad}]
                    set cpy $cy
                } else {
                    set d [expr {$nurad/$rad}]
                    set cpx [expr {($cpx-$cx)*$d+$cx}]
                    set cpy [expr {($cpy-$cy)*$d+$cy}]
                }
                set coords [list $cx $cy $cpx $cpy]
                cadobjects_object_set_coords $canv $objid $coords
            } else {
                # Radius is locked.  Change teeth instead.  Quantize pitch.
                set t [expr {int(2.0*$rad*$val+0.5)}]
                if {$t < 3} {
                    # Can't have fewer than 3 teeth.
                    set t 3
                    set nurad [expr {0.5*$t/$val}]
                    if {abs($rad) < 1e-9} {
                        set cpx [expr {$cx+$nurad}]
                        set cpy $cy
                    } else {
                        set d [expr {$nurad/$rad}]
                        set cpx [expr {($cpx-$cx)*$d+$cx}]
                        set cpy [expr {($cpy-$cy)*$d+$cy}]
                    }
                    set coords [list $cx $cy $cpx $cpy]
                    cadobjects_object_set_coords $canv $objid $coords
                }
                cadobjects_object_setdatum $canv $objid "TEETH" $t
                set p [expr {0.5*$t/$rad}]
                cadobjects_object_setdatum $canv $objid "PITCH" $p
            }
            cadobjects_object_setdatum $canv $objid "PITCH" $val
        }
    }
}


proc plugin_spurgear_initobj {canv objid coords} {
    cadobjects_object_setdatum $canv $objid "CUTSIDE" "outside"
    cadobjects_object_setdatum $canv $objid "PITCH" 16
    cadobjects_object_setdatum $canv $objid "TEETH" 20
    cadobjects_object_setdatum $canv $objid "STYLE" "involute"
    cadobjects_object_setdatum $canv $objid "PRESSANG" 14.5
    cadobjects_object_setdatum $canv $objid "LOCKVAL" "pitch"
}


proc plugin_spurgear_transformobj {canv objid coords mat} {
    set coords [cadobjects_object_getdatum $canv $objid "LINEPATH"]
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid LINE
    return 0 ;# Also allow default coordlist transforms
}


proc plugin_spurgear_shearobj {canv objid coords sx sy cx cy} {
    plugin_spurgear_transformobj $canv $objid $coords ""
    return 0 ;# Also allow default coordlist transforms
}


proc plugin_spurgear_scaleobj {canv objid coords sx sy cx cy} {
    if {abs(abs($sx)-abs($sy)) > 1e-6} {
        plugin_spurgear_transformobj $canv $objid $coords ""
    }
    return 0 ;# Also allow default coordlist transforms
}


proc plugin_spurgear_drawobj {canv objid coords tags color fill width dash} {
    foreach {cx cy cpx cpy} $coords break
    set teeth [cadobjects_object_getdatum $canv $objid "TEETH"]
    set pitch [cadobjects_object_getdatum $canv $objid "PITCH"]
    set vlock [cadobjects_object_getdatum $canv $objid "LOCKVAL"]
    set radius [expr {hypot($cpy-$cy,$cpx-$cx)}]
    if {$vlock == "pitch"} {
        set teeth [expr {int(2.0*$radius*$pitch+0.5)}]
        if {$teeth < 3} {
            set teeth 3
        }
    } elseif {$vlock == "radius"} {
        set pitch [expr {0.5*$teeth/$radius}]
    }
    set radius [expr {0.5*$teeth/$pitch}]

    set coords [cadobjects_scale_coords $canv [list $cx $cy $radius 0.0]]
    foreach {cx cy radius dummy} $coords break

    cadobjects_object_draw_center_cross $canv $cx $cy $radius $tags $color $width
    cadobjects_object_draw_center_arc $canv $cx $cy $radius   0.0 -90.0 $tags $color
    cadobjects_object_draw_center_arc $canv $cx $cy $radius   0.0  90.0 $tags $color
    cadobjects_object_draw_center_arc $canv $cx $cy $radius 180.0 -90.0 $tags $color
    cadobjects_object_draw_center_arc $canv $cx $cy $radius 180.0  90.0 $tags $color
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_spurgear_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid REGPOLYGON $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_spurgear_recalculate {canv objid coords {flags ""}} {
    constants pi radtodeg
    foreach {cx cy cpx cpy} $coords break
    set pitch [cadobjects_object_getdatum $canv $objid "PITCH"]
    set teeth [cadobjects_object_getdatum $canv $objid "TEETH"]
    set style [cadobjects_object_getdatum $canv $objid "STYLE"]
    set pressang [cadobjects_object_getdatum $canv $objid "PRESSANG"]
    set vlock [cadobjects_object_getdatum $canv $objid "LOCKVAL"]
    set radius [expr {hypot($cpy-$cy,$cpx-$cx)}]
    set startang [expr {atan2($cpy-$cy,$cpx-$cx)*$radtodeg}]

    if {$vlock == "pitch"} {
        set teeth [expr {int(2.0*$radius*$pitch+0.5)}]
        if {$teeth < 3} {
            set teeth 3
        }
        set radius [expr {0.5*$teeth/$pitch}]
        cadobjects_object_setdatum $canv $objid "TEETH" $teeth
    } else {
        # P = T/D
        set pitch [expr {0.5*$teeth/$radius}]
        cadobjects_object_setdatum $canv $objid "PITCH" $pitch
    }

    set diam [expr {$radius*2.0}]
    set linepath [plugin_spurgear_genpath $cx $cy $pitch $teeth $pressang $startang $diam $style]
    cadobjects_object_setdatum $canv $objid "LINEPATH" $linepath
}


proc plugin_spurgear_dragctls {canv objid coords nodes dx dy} {
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


proc plugin_spurgear_genpath {cx cy pitch numteeth pressang startang {pitchdiam ""} {style "involute"}} {
    constants pi degtorad
    set expdiam   [expr {((1.0*$numteeth)/$pitch)}]
    if {$pitchdiam == ""} {
        set pitchdiam $expdiam
        set diamult 1.0
    } else {
        set diamult [expr {$pitchdiam/$expdiam}]
    }
    set pitchrad [expr {$pitchdiam*0.5}]
    if {$style == "involute"} {
        set basediam    [expr {$pitchdiam*cos($pressang*$degtorad)}]
        set addendum    [expr {$diamult*1.0/$pitch}]
        set dedendum    [expr {$diamult*1.157/$pitch}]
        set outsidediam [expr {$pitchdiam+(2.0*$addendum)}]
        set rootdiam    [expr {$pitchdiam-(2.05*$dedendum)}]
    } else {
        set tang   [expr {2.0*$pi/$numteeth}]
        set s [expr {$pi/2.0-$tang/2.0}]
        set basediam $pitchdiam
        # y = mx + c
        # y = tan(-60)x + (D+a)
        # y = tan(s)x + 0
        # y = (D-a)sin(s)
        # tan(s)x - tan(-60)x = D+a
        # k = tan(s) - tan(-60)
        # kx = D+a
        # x = (D+a)/k
        # x = (D-a)cos(s)
        # (D+a)/k = (D-a)cos(s)
        # n = cos(s)k
        # D + a = nD - na
        # a + na = nD - D
        # a(1+n) = (n-1)D
        # a = D(n-1)/(n+1)
        set k [expr {tan($s)-tan(-$pi/3.0)}]
        set n [expr {cos($s)*$k}]
        set addendum [expr {$basediam*($n-1)/($n+1)}]
        set outsidediam [expr {$pitchdiam+$addendum}]
        set rootdiam    [expr {$pitchdiam-$addendum}]
    }
    set baserad [expr {0.5*$basediam}]

    set idiv 10
    set gt  [expr {$pi*2.0/$numteeth}]
    set te  [expr {sqrt(pow($outsidediam*0.5,2.0)-pow($baserad,2.0))/$baserad}]
    set td  [expr {$te/$idiv}]
    set tl  [expr {$baserad*$td}]
    set tfa [expr {sqrt(pow($pitchdiam*0.5,2.0)-pow($baserad,2.0))/$baserad}]
    set tfl [expr {$baserad*$tfa}]
    set px0 [expr {$baserad*cos($tfa)+$cx}]
    set py0 [expr {$baserad*sin($tfa)+$cy}]
    set px1 [expr {$tfl*cos($tfa-$pi/2.0)+$px0}]
    set py1 [expr {$tfl*sin($tfa-$pi/2.0)+$py0}]
    set offa [expr {abs(atan2($py1-$cy,$px1-$cx))/1.0}]

    set path {}
    for {set tooth 0} {$tooth < $numteeth} {incr tooth} {
        if {$style == "involute"} {
            set trueang [expr {$tooth*$gt+$startang*$degtorad}]
            set baseang [expr {$trueang-$offa}]
            set px0 [expr {$rootdiam*0.5*cos($baseang)+$cx}]
            set py0 [expr {$rootdiam*0.5*sin($baseang)+$cy}]
            set ox $px0
            set oy $py0

            if {$rootdiam < $basediam} {
                lappend path $px0 $py0
            }

            for {set invol 0} {$invol <= $idiv} {incr invol} {
                set segang [expr {$baseang+$td*$invol}]
                set px0 [expr {$baserad*cos($segang)+$cx}]
                set py0 [expr {$baserad*sin($segang)+$cy}]
                set px1 [expr {$invol*$tl*cos($segang-$pi/2.0)+$px0}]
                set py1 [expr {$invol*$tl*sin($segang-$pi/2.0)+$py0}]
                set dist [expr {hypot($py1-$cy,$px1-$cx)}]
                if {$dist < $rootdiam*0.5} {
                    set px1 [expr {0.5*$rootdiam*cos($trueang-$offa)+$cx}]
                    set py1 [expr {0.5*$rootdiam*sin($trueang-$offa)+$cy}]
                }
                set dang [expr {atan2($py1-$cy,$px1-$cx)-$trueang}]
                while {$dang < -$pi} {
                    set dang [expr {$dang+2.0*$pi}]
                }
                while {$dang > $pi} {
                    set dang [expr {$dang-2.0*$pi}]
                }
                if {abs($dang) > abs(0.25*$gt)} {
                    if {$dist > $rootdiam*0.5} {
                        set ex [expr {$outsidediam*cos($trueang+0.25*$gt)+$cx}]
                        set ey [expr {$outsidediam*sin($trueang+0.25*$gt)+$cy}]
                        set isect [::math::geometry::findLineSegmentIntersection [list $cx $cy $ex $ey] [list $ox $oy $px1 $py1]]
                        lassign $isect ix iy
                        lappend path $ix $iy
                        break
                    } else {
                        set px1 [expr {0.5*$rootdiam*cos($trueang-0.25*$gt)+$cx}]
                        set py1 [expr {0.5*$rootdiam*sin($trueang-0.25*$gt)+$cy}]
                    }
                }
                lappend path $px1 $py1
                set ox $px1
                set oy $py1
            }

            set trueang [expr {($tooth+0.5)*$gt+$startang*$degtorad}]
            set baseang [expr {$trueang+$offa}]
            for {incr invol -1} {$invol >= 0} {incr invol -1} {
                set segang [expr {$baseang-$td*$invol}]
                set px0 [expr {$baserad*cos($segang)+$cx}]
                set py0 [expr {$baserad*sin($segang)+$cy}]
                set px1 [expr {$invol*$tl*cos($segang+$pi/2.0)+$px0}]
                set py1 [expr {$invol*$tl*sin($segang+$pi/2.0)+$py0}]
                set dist [expr {hypot($py1-$cy,$px1-$cx)}]
                if {$dist < $rootdiam*0.5} {
                    if {$offa > 0.25*$gt} {
                        set px1 [expr {0.5*$rootdiam*cos($trueang+0.25*$gt)+$cx}]
                        set py1 [expr {0.5*$rootdiam*sin($trueang+0.25*$gt)+$cy}]
                    } else {
                        set px1 [expr {0.5*$rootdiam*cos($trueang+$offa)+$cx}]
                        set py1 [expr {0.5*$rootdiam*sin($trueang+$offa)+$cy}]
                    }
                    lappend path $px1 $py1
                    break
                }
                lappend path $px1 $py1
            }

            if {$rootdiam < $basediam} {
                set px0 [expr {$rootdiam*0.5*cos($baseang)+$cx}]
                set py0 [expr {$rootdiam*0.5*sin($baseang)+$cy}]
                lappend path $px0 $py0
            }

        } elseif {$style == "equilateral"} {
            set baseang [expr {$tooth*$gt+$startang*$degtorad}]
            set px0 [expr {$outsidediam*0.5*cos($baseang)+$cx}]
            set py0 [expr {$outsidediam*0.5*sin($baseang)+$cy}]
            lappend path $px0 $py0

            set baseang [expr {($tooth+0.5)*$gt+$startang*$degtorad}]
            set px0 [expr {$rootdiam*0.5*cos($baseang)+$cx}]
            set py0 [expr {$rootdiam*0.5*sin($baseang)+$cy}]
            lappend path $px0 $py0

        } elseif {$style == "ratchetcw"} {
            set baseang [expr {$tooth*$gt+$startang*$degtorad}]
            set px0 [expr {$outsidediam*0.5*cos($baseang)+$cx}]
            set py0 [expr {$outsidediam*0.5*sin($baseang)+$cy}]
            lappend path $px0 $py0

            set px0 [expr {$rootdiam*0.5*cos($baseang)+$cx}]
            set py0 [expr {$rootdiam*0.5*sin($baseang)+$cy}]
            lappend path $px0 $py0

        } elseif {$style == "ratchetccw"} {
            set baseang [expr {$tooth*$gt+$startang*$degtorad}]
            set px0 [expr {$rootdiam*0.5*cos($baseang)+$cx}]
            set py0 [expr {$rootdiam*0.5*sin($baseang)+$cy}]
            lappend path $px0 $py0

            set px0 [expr {$outsidediam*0.5*cos($baseang)+$cx}]
            set py0 [expr {$outsidediam*0.5*sin($baseang)+$cy}]
            lappend path $px0 $py0

        } else {
            error "Unknown tooth style: '$style'"
        }
    }

    lappend path [lindex $path 0] [lindex $path 1]
    return $path
}


proc plugin_spurgear_pointsofinterest {canv objid coords nearx neary} {
    set linepath [cadobjects_object_getdatum $canv $objid "LINEPATH"]
    foreach {cx cy cpx cpy} $coords break
    set radius [expr {hypot($cpy-$cy,$cpx-$cx)}]
    set ang [expr {atan2($neary-$cy,$nearx-$cx)}]
    set ix [expr {$radius*cos($ang)+$cx}]
    set iy [expr {$radius*sin($ang)+$cy}]

    set poi {}

    lappend poi "controlpoints"  $cx  $cy  "Center Point"     1
    lappend poi "controlpoints" $cpx $cpy "Control Point"    2
    lappend poi "centerlines"   $ix  $iy  "On Pitch Circle" -1

    cadobjects_object_polyline_pois poi "contours" "On Polygon" $linepath $nearx $neary

    return $poi
}


proc plugin_spurgear_decompose {canv objid coords allowed} {
    foreach {cx cy cpx cpy} $coords break
    set linepath [cadobjects_object_getdatum $canv $objid "LINEPATH"]
    set teeth [cadobjects_object_getdatum $canv $objid "TEETH"]
    set pitch [cadobjects_object_getdatum $canv $objid "PITCH"]
    set pressang [cadobjects_object_getdatum $canv $objid "PRESSANG"]
    set style [cadobjects_object_getdatum $canv $objid "STYLE"]

    if {"SPURGEAR" in $allowed} {
        return [list SPURGEAR [list $cx $cy $teeth $pitch $pressang $style]]
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
        } elseif {"LASER" in $allowed} {
            set tol 5.0e-4
            set bezpath [bezutil_bezier_from_line $path]
            set bezpath [bezutil_bezier_smooth $bezpath $tol]
            set bezpath [bezutil_bezier_simplify $bezpath $tol]
            set path {}
            bezutil_append_line_from_bezier path $bezpath
        }
        return [list LINES $path]
    } elseif {"BEZIER" in $allowed} {
        set linepath [cadobjects_object_getdatum $canv $objid "LINEPATH"]
        set tol 5.0e-4
        set bezpath [bezutil_bezier_from_line $linepath]
        set bezpath [bezutil_bezier_smooth $bezpath $tol]
        set bezpath [bezutil_bezier_simplify $bezpath $tol]
        return [list BEZIER $bezpath]
    }
    return {}
}


proc plugin_spurgear_bbox {canv objid coords} {
    set linepath [cadobjects_object_getdatum $canv $objid "LINEPATH"]
    return [geometry_pointlist_bbox $linepath]
}







proc plugin_polygons_register {} {
    tool_register_ex RECTANGLE "&Miscellaneous" "&Rectangle" {
        {1    "First Corner"}
        {2    "Opposite Corner"}
    } -icon "tool-rectangle" -creator
    tool_register_ex RECTANGLE "&Miscellaneous" "R&ounded Rectangle" {
        {1    "First Corner"}
        {2    "Opposite Corner"}
        {3    "Radius Center"}
    } -icon "tool-rrect" -creator
    tool_register_ex REGPOLYGON "&Miscellaneous" "Regular &Polygon" {
        {1    "Center Point"}
        {2    "Polygon Vertex"}
    } -icon "tool-regpolygon" -creator -impfields {SIDES STYLE}
    tool_register_ex SPIRAL "&Miscellaneous" "&Spiral" {
        {1    "Center Point"}
        {2    "Inner Point"}
        {3    "Outer Point"}
    } -icon "tool-spiral" -creator -impfields {TURNS SPINDIR DIVERGENCE}
    tool_register_ex SPURGEAR "&Miscellaneous" "Spur &Gear" {
        {1    "Center Point"}
        {2    "Pitch Radius"}
    } -icon "tool-spurgear" -creator -impfields {TEETH PITCH PRESSANG STYLE LOCKVAL}
}
plugin_polygons_register 


# vim: set ts=4 sw=4 nowrap expandtab: settings

