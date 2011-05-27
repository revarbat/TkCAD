proc plugin_ellipsectr_editfields {canv objid coords} {
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
        datum #0
        title "Center pt"
    }
    lappend out {
        type POINT
        name CORNER
        datum #1
        title "Corner pt"
    }
    return $out
}


proc plugin_ellipsectr_shearobj {canv objid coords sx sy cx cy} {
    foreach {cx cy cpx cpy} $coords break
    set coords [list $cx $cy $cpx $cy $cpx $cpy]
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid ELLIPSECTRTAN
    return 0 ;# Also allow default coordlist rotation
}


proc plugin_ellipsectr_rotateobj {canv objid coords rotang cx cy} {
    foreach {cx cy cpx cpy} $coords break
    set coords [list $cx $cy $cpx $cy $cpx $cpy]
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid ELLIPSECTRTAN
    return 0 ;# Also allow default coordlist rotation
}


proc plugin_ellipsectr_flipobj {canv objid coords x0 y0 x1 y1} {
    foreach {cx cy cpx cpy} $coords break
    set coords [list $cx $cy $cpx $cy $cpx $cpy]
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid ELLIPSECTRTAN
    return 0 ;# Also allow default coordlist rotation
}


proc plugin_ellipsectr_drawobj {canv objid coords tags color fill width dash} {
    set coords [cadobjects_scale_coords $canv $coords]
    foreach {cx cy cpx1 cpy1} $coords break

    set rad1 [expr {abs($cpx1-$cx)}]
    set rad2 [expr {abs($cpy1-$cy)}]
    cadobjects_object_draw_oval_cross $canv $cx $cy $rad1 $rad2 $tags $color 1.0

    return 0 ;# Also draw default decomposed shape.
}


proc plugin_ellipsectr_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid ELLIPSECTR $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_ellipsectr_recalculate {canv objid coords {flags ""}} {
    foreach {cx cy x1 y1} $coords break

    set rad1 [expr {abs($x1-$cx)}]
    set rad2 [expr {abs($y1-$cy)}]
    cadobjects_object_setdatum $canv $objid "RAD1" $rad1
    cadobjects_object_setdatum $canv $objid "RAD2" $rad2
    cadobjects_object_setdatum $canv $objid "CENTER" [list $cx $cy]

    set x0 [expr {$cx-$rad1}]
    set y0 [expr {$cy-$rad2}]
    set x1 [expr {$cx+$rad1}]
    set y1 [expr {$cy+$rad2}]
    cadobjects_object_setdatum $canv $objid "BOX" [list $x0 $y0 $x1 $y1]
}


proc plugin_ellipsectr_dragctls {canv objid coords nodes dx dy} {
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


proc plugin_ellipsectr_decompose {canv objid coords allowed} {
    foreach {cpx1 cpy1 cpx2 cpy2} $coords break
    set rad1 [cadobjects_object_getdatum $canv $objid "RAD1"]
    set rad2 [cadobjects_object_getdatum $canv $objid "RAD2"]
    foreach {cx cy} [cadobjects_object_getdatum $canv $objid "CENTER"] break

    if {"GCODE" in $allowed} {
        set cutbit  [cadobjects_object_cutbit $canv $objid]
        set cutside [cadobjects_object_getdatum $canv $objid "CUTSIDE"]
        set cutdiam [mlcnc_tooldiam $cutbit]
    }

    if {"ELLIPSE" in $allowed} {
        return [list ELLIPSE [list $cx $cy $rad1 $rad2]]
    } elseif {"ELLIPSEROT" in $allowed} {
        return [list ELLIPSE [list $cx $cy $rad1 $rad2 0.0]]
    } elseif {"CIRCLE" in $allowed && abs($rad1-$rad2) < 1e-6} {
        if {"GCODE" in $allowed} {
            if {$cutbit > 0} {
                if {$cutside == "inside"} {
                    set rad1 [expr {$rad1-$cutdiam/2.0}]
                } elseif {$cutside == "outside"} {
                    set rad1 [expr {$rad1+$cutdiam/2.0}]
                }
            } else {
                return ""
            }
        }
        return [list CIRCLE [list $cx $cy $rad1]]
    } elseif {"ARC" in $allowed && abs($rad1-$rad2) < 1e-6} {
        return [list ARC [list $cx $cy $rad1 0.0 360.0]]
    } elseif {"BEZIER" in $allowed} {
        set path {}
        bezutil_append_bezier_arc path $cx $cy $rad1 $rad2 0.0 360.0
        return [list BEZIER $path]
    } elseif {"LINES" in $allowed} {
        set path {}
        bezutil_append_line_arc path $cx $cy $rad1 $rad2 0.0 360.0
        if {"GCODE" in $allowed} {
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
    }
    return {}
}


proc plugin_ellipsectr_bbox {canv objid coords} {
    foreach {cx cy x1 y1} $coords break

    set rad1 [expr {abs($x1-$cx)}]
    set rad2 [expr {abs($y1-$cy)}]

    set x0 [expr {$cx-$rad1}]
    set y0 [expr {$cy-$rad2}]
    set x1 [expr {$cx+$rad1}]
    set y1 [expr {$cy+$rad2}]
    return [geometry_pointlist_bbox [list $x0 $y0 $x1 $y1]]
}







proc plugin_ellipsediag_editfields {canv objid coords} {
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
        datum 0
        title "Point 1"
    }
    lappend out {
        type POINT
        name POINT2
        datum 1
        title "Point 2"
    }
    return $out
}


proc plugin_ellipsediag_initobj {canv objid coords} {
}


proc plugin_ellipsediag_shearobj {canv objid coords sx sy cx cy} {
    foreach {cpx1 cpy1 cpx2 cpy2} $coords break
    set coords [list $cpx1 $cpy1 $cpx2 $cpy1 $cpx2 $cpy2]
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid ELLIPSE3CRN
    return 0 ;# Also allow default coordlist rotation
}


proc plugin_ellipsediag_rotateobj {canv objid coords rotang cx cy} {
    foreach {cpx1 cpy1 cpx2 cpy2} $coords break
    set coords [list $cpx1 $cpy1 $cpx2 $cpy1 $cpx2 $cpy2]
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid ELLIPSE3CRN
    return 0 ;# Also allow default coordlist rotation
}


proc plugin_ellipsediag_flipobj {canv objid coords x0 y0 x1 y1} {
    foreach {cpx1 cpy1 cpx2 cpy2} $coords break
    set coords [list $cpx1 $cpy1 $cpx2 $cpy1 $cpx2 $cpy2]
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid ELLIPSE3CRN
    return 0 ;# Also allow default coordlist rotation
}


proc plugin_ellipsediag_drawobj {canv objid coords tags color fill width dash} {
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_ellipsediag_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid ELLIPSEDIAG $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_ellipsediag_recalculate {canv objid coords {flags ""}} {
    foreach {x0 y0 x1 y1} $coords break
    set cx [expr {($x0+$x1)/2.0}]
    set cy [expr {($y0+$y1)/2.0}]

    set rad1 [expr {abs($x1-$cx)}]
    set rad2 [expr {abs($y1-$cy)}]
    cadobjects_object_setdatum $canv $objid "RAD1" $rad1
    cadobjects_object_setdatum $canv $objid "RAD2" $rad2
    cadobjects_object_setdatum $canv $objid "CENTER" [list $cx $cy]

    set x0 [expr {$cx-$rad1}]
    set y0 [expr {$cy-$rad2}]
    set x1 [expr {$cx+$rad1}]
    set y1 [expr {$cy+$rad2}]
    cadobjects_object_setdatum $canv $objid "BOX" [list $x0 $y0 $x1 $y1]
}


proc plugin_ellipsediag_decompose {canv objid coords allowed} {
    foreach {cpx1 cpy1 cpx2 cpy2} $coords break
    set rad1 [cadobjects_object_getdatum $canv $objid "RAD1"]
    set rad2 [cadobjects_object_getdatum $canv $objid "RAD2"]
    foreach {cx cy} [cadobjects_object_getdatum $canv $objid "CENTER"] break

    if {"GCODE" in $allowed} {
        set cutbit  [cadobjects_object_cutbit $canv $objid]
        set cutside [cadobjects_object_getdatum $canv $objid "CUTSIDE"]
        set cutdiam [mlcnc_tooldiam $cutbit]
    }

    if {"CIRCLE" in $allowed && abs($rad1-$rad2) < 1e-6} {
        if {"GCODE" in $allowed} {
            if {$cutbit > 0} {
                if {$cutside == "inside"} {
                    set rad1 [expr {$rad1-$cutdiam/2.0}]
                } elseif {$cutside == "outside"} {
                    set rad1 [expr {$rad1+$cutdiam/2.0}]
                }
            } else {
                return ""
            }
        }
        return [list CIRCLE [list $cx $cy $rad1]]
    } elseif {"ELLIPSE" in $allowed} {
        return [list ELLIPSE [list $cx $cy $rad1 $rad2 0.0]]
    } elseif {"ARC" in $allowed && abs($rad1-$rad2) < 1e-6} {
        return [list ARC [list $cx $cy $rad1 0.0 360.0]]
    } elseif {"BEZIER" in $allowed} {
        set path {}
        bezutil_append_bezier_arc path $cx $cy $rad1 $rad2 0.0 360.0
        return [list BEZIER $path]
    } elseif {"LINES" in $allowed} {
        set path {}
        bezutil_append_line_arc path $cx $cy $rad1 $rad2 0.0 360.0
        if {"GCODE" in $allowed} {
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
    }
    return {}
}


proc plugin_ellipsediag_bbox {canv objid coords} {
    return [geometry_pointlist_bbox $coords]
}







proc plugin_ellipseopptan_editfields {canv objid coords} {
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
        type POINT
        name TANGENT
        datum 2
        title "Tangent"
    }
    return $out
}


proc plugin_ellipseopptan_drawobj {canv objid coords tags color fill width dash} {
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_ellipseopptan_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    foreach {cpx1 cpy1 cpx2 cpy2 cpx3 cpy3} $coords break
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid ELLIPSEOPPTAN $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
    cadobjects_object_draw_control_line $canv $objid $cpx2 $cpy2 $cpx3 $cpy3 1 $color [dashpat construction]
}


proc plugin_ellipseopptan_recalculate {canv objid coords {flags ""}} {
    # TODO: This is a hack!  Need to replace this bezier approximation
    # with real rotated-ellipse calculation code.
    # Bezier approximation has about a 0.1% error.
    # Not good enough for machining operations.
    foreach {x1 y1 x2 y2 x3 y3} $coords break

    set cx [expr {($x1+$x2)/2.0}]
    set cy [expr {($y1+$y2)/2.0}]

    set cx1 [expr {$cx-($x3-$cx)}]
    set cy1 [expr {$cy-($y3-$cy)}]
    set cx2 [expr {$x2-($x3-$x2)}]
    set cy2 [expr {$y2-($y3-$y2)}]
    set cx3 $x3
    set cy3 $y3
    set cx4 [expr {$cx-($cx2-$cx)}]
    set cy4 [expr {$cy-($cy2-$cy)}]

    set mx1 [expr {($cx1+$cx2)/2.0}]
    set my1 [expr {($cy1+$cy2)/2.0}]
    set mx2 [expr {($cx2+$cx3)/2.0}]
    set my2 [expr {($cy2+$cy3)/2.0}]
    set mx3 [expr {($cx3+$cx4)/2.0}]
    set my3 [expr {($cy3+$cy4)/2.0}]
    set mx4 [expr {($cx4+$cx1)/2.0}]
    set my4 [expr {($cy4+$cy1)/2.0}]

    set m1 0.447707
    set m2 [expr {1.0-$m1}]
    set ellipsepath {}
    lappend ellipsepath $mx1 $my1
    foreach {ex1 ey1 ex2 ey2 ex3 ey3} [list \
        $mx1 $my1 $mx2 $my2 $cx2 $cy2 \
        $mx2 $my2 $mx3 $my3 $cx3 $cy3 \
        $mx3 $my3 $mx4 $my4 $cx4 $cy4 \
        $mx4 $my4 $mx1 $my1 $cx1 $cy1 \
    ] {
        set ix1 [expr {($m1*$ex1+$m2*$ex3)}]
        set iy1 [expr {($m1*$ey1+$m2*$ey3)}]
        set ix2 [expr {($m1*$ex2+$m2*$ex3)}]
        set iy2 [expr {($m1*$ey2+$m2*$ey3)}]
        lappend ellipsepath $ix1 $iy1  $ix2 $iy2  $ex2 $ey2
    }
    cadobjects_object_setdatum $canv $objid "BEZIERPATH" $ellipsepath
}


proc plugin_ellipseopptan_decompose {canv objid coords allowed} {
    set bezpath [cadobjects_object_getdatum $canv $objid "BEZIERPATH"]

    constants pi
    foreach {x1 y1 x2 y2 x3 y3} $coords break
    set dist1 [expr {hypot($y1-$y2,$x1-$x2)}]
    set dist2 [expr {hypot($y3-$y2,$x3-$x2)}]
    set ang1 [expr {atan2($y1-$y2,$x1-$x2)}]
    set ang2 [expr {atan2($y3-$y2,$x3-$x2)}]
    set dang [expr {abs(fmod($ang2-$ang1,$pi))}]
    set ishoriz [expr {abs($ang1) < 1e-6 || abs(abs($ang1)-$pi) < 1e-6}]
    set isvert [expr {abs(abs($ang1)-$pi/2.0) < 1e-6}]
    set isequal [expr {abs($dist1-(2.0*$dist2)) < 1e-6}]
    set isperp [expr {abs($dang-$pi/2.0) < 1e-6}]
    set cx [expr {($x1+$x2)/2.0}]
    set cy [expr {($y1+$y2)/2.0}]

    if {"GCODE" in $allowed} {
        set cutbit  [cadobjects_object_cutbit $canv $objid]
        set cutside [cadobjects_object_getdatum $canv $objid "CUTSIDE"]
        set cutdiam [mlcnc_tooldiam $cutbit]
    }

    if {"CIRCLE" in $allowed && $isperp && $isequal} {
        set rad1 $dist2
        if {"GCODE" in $allowed} {
            if {$cutbit > 0} {
                if {$cutside == "inside"} {
                    set rad1 [expr {$rad1-$cutdiam/2.0}]
                } elseif {$cutside == "outside"} {
                    set rad1 [expr {$rad1+$cutdiam/2.0}]
                }
            } else {
                return ""
            }
        }
        return [list CIRCLE [list $cx $cy $rad1]]
    } elseif {"ELLIPSE" in $allowed && $isperp && $isequal} {
        set rad1 $dist2
        set rad2 $dist2
        return [list ELLIPSE [list $cx $cy $rad1 $rad2]]
    } elseif {"ELLIPSE" in $allowed && $isperp && $isvert} {
        set rad1 $dist2
        set rad2 [expr {$dist1/2.0}]
        return [list ELLIPSE [list $cx $cy $rad1 $rad2]]
    } elseif {"ELLIPSE" in $allowed && $isperp && $ishoriz} {
        set rad1 [expr {$dist1/2.0}]
        set rad2 $dist2
        return [list ELLIPSE [list $cx $cy $rad1 $rad2]]
    } elseif {"ELLIPSEROT" in $allowed && $isperp} {
        set rot [expr {fmod($ang1*180.0/$pi+180.0,360.0)}]
        set rad1 [expr {$dist1/2.0}]
        set rad2 $dist2
        return [list ELLIPSEROT [list $cx $cy $rad1 $rad2 $rot]]
    } elseif {"ELLIPSEROT" in $allowed && $isequal} {
        set rotr [expr {atan2($y3-$cy,$x3-$cx)}]
        set rot [expr {$rotr*180.0/$pi}]
        set mx1 [expr {($cx+$x3)/2.0}]
        set my1 [expr {($cy+$y3)/2.0}]
        set rad1 [expr {hypot($cy-$my1,$cx-$mx1)/cos($rotr)}]
        set rad2 [expr {hypot($y2-$my1,$x2-$mx1)/sin($rotr)}]
        return [list ELLIPSEROT [list $cx $cy $rad1 $rad2 $rot]]
    } elseif {"ARC" in $allowed && $isperp && $isequal} {
        return [list ARC [list $cx $cy $dist2 0.0 360.0]]
    } elseif {"BEZIER" in $allowed} {
        return [list BEZIER $bezpath]
    } elseif {"LINES" in $allowed} {
        set path {}
        bezutil_append_line_from_bezier path $bezpath
        if {"GCODE" in $allowed} {
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
    }
    return {}
}


proc plugin_ellipseopptan_pointsofinterest {canv objid coords nearx neary} {
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set scalemult [expr {$dpi*$scalefactor}]
    set linewidth [cadobjects_object_stroke_width $canv $objid]
    set closeenough [$canv cget -closeenough]
    set closeenough [expr {(5+$closeenough)/$scalemult+$linewidth/2.0}]
    set tolerance 1e-4

    set poi {}
    set bezpath [cadobjects_object_getdatum $canv $objid "BEZIERPATH"]
    set nodenum 0
    foreach {x y} $coords {
        lappend poi "controlpoints" $x $y "Control point" [incr nodenum]
        incr nodenum 3
    }
    cadobjects_object_bezier_pois poi "contours" "On Ellipse" $bezpath $nearx $neary $closeenough $tolerance
    return $poi
}


proc plugin_ellipseopptan_bbox {canv objid coords} {
    foreach {x1 y1 x2 y2 x3 y3} $coords break

    set cx [expr {($x1+$x2)/2.0}]
    set cy [expr {($y1+$y2)/2.0}]
    set cx1 [expr {$cx-($x3-$cx)}]
    set cy1 [expr {$cy-($y3-$cy)}]

    return [geometry_pointlist_bbox [list $x3 $y3 $cx1 $cy1]]
}







proc plugin_ellipsectrtan_editfields {canv objid coords} {
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
        datum #0
        title "Center pt"
    }
    lappend out {
        type POINT
        name CTRLPT
        datum #1
        title "Edge pt"
    }
    lappend out {
        type POINT
        name TANGENT
        datum #2
        title "Tangent"
    }
    return $out
}


proc plugin_ellipsectrtan_drawobj {canv objid coords tags color fill width dash} {
    set coords [cadobjects_scale_coords $canv $coords]
    foreach {cx cy cpx1 cpy1 cpx2 cpy2} $coords break
    set rad [expr {hypot($cpy1-$cy,$cpx1-$cx)/4.0}]
    cadobjects_object_draw_center_cross $canv $cx $cy $rad $tags $color $width
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_ellipsectrtan_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    foreach {cpx1 cpy1 cpx2 cpy2 cpx3 cpy3} $coords break
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid ELLIPSECTRTAN $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
    cadobjects_object_draw_control_line $canv $objid $cpx2 $cpy2 $cpx3 $cpy3 1 $color [dashpat construction]
}


proc plugin_ellipsectrtan_recalculate {canv objid coords {flags ""}} {
    # TODO: This is a hack!  It looks good, though.
    # Need to replace this bezier approximation with real
    # rotated-ellipse calculation code.
    foreach {x1 y1 x2 y2 x3 y3} $coords break

    set cx $x1
    set cy $y1

    set cx1 [expr {$cx-($x3-$cx)}]
    set cy1 [expr {$cy-($y3-$cy)}]
    set cx2 [expr {$x2-($x3-$x2)}]
    set cy2 [expr {$y2-($y3-$y2)}]
    set cx3 $x3
    set cy3 $y3
    set cx4 [expr {$cx-($cx2-$cx)}]
    set cy4 [expr {$cy-($cy2-$cy)}]

    set mx1 [expr {($cx1+$cx2)/2.0}]
    set my1 [expr {($cy1+$cy2)/2.0}]
    set mx2 [expr {($cx2+$cx3)/2.0}]
    set my2 [expr {($cy2+$cy3)/2.0}]
    set mx3 [expr {($cx3+$cx4)/2.0}]
    set my3 [expr {($cy3+$cy4)/2.0}]
    set mx4 [expr {($cx4+$cx1)/2.0}]
    set my4 [expr {($cy4+$cy1)/2.0}]

    set ellipsepath {}
    lappend ellipsepath $mx1 $my1
    foreach {ex1 ey1 ex2 ey2 ex3 ey3} [list \
        $mx1 $my1 $mx2 $my2 $cx2 $cy2 \
        $mx2 $my2 $mx3 $my3 $cx3 $cy3 \
        $mx3 $my3 $mx4 $my4 $cx4 $cy4 \
        $mx4 $my4 $mx1 $my1 $cx1 $cy1 \
    ] {
        set m1 0.447707
        set m2 [expr {1.0-$m1}]
        set ix1 [expr {($m1*$ex1+$m2*$ex3)}]
        set iy1 [expr {($m1*$ey1+$m2*$ey3)}]
        set ix2 [expr {($m1*$ex2+$m2*$ex3)}]
        set iy2 [expr {($m1*$ey2+$m2*$ey3)}]
        lappend ellipsepath $ix1 $iy1  $ix2 $iy2  $ex2 $ey2
    }
    cadobjects_object_setdatum $canv $objid "BEZIERPATH" $ellipsepath
}


proc plugin_ellipsectrtan_dragctls {canv objid coords nodes dx dy} {
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


proc plugin_ellipsectrtan_decompose {canv objid coords allowed} {
    set bezpath [cadobjects_object_getdatum $canv $objid "BEZIERPATH"]

    constants pi
    foreach {x1 y1 x2 y2 x3 y3} $coords break
    set dist1 [expr {hypot($y1-$y2,$x1-$x2)}]
    set dist2 [expr {hypot($y3-$y2,$x3-$x2)}]
    set ang1 [expr {atan2($y1-$y2,$x1-$x2)}]
    set ang2 [expr {atan2($y3-$y2,$x3-$x2)}]
    set dang [expr {abs(fmod($ang2-$ang1,$pi))}]
    set ishoriz [expr {abs($ang1) < 1e-6 || abs(abs($ang1)-$pi) < 1e-6}]
    set isvert [expr {abs(abs($ang1)-$pi/2.0) < 1e-6}]
    set isequal [expr {abs($dist1-$dist2) < 1e-6}]
    set isperp [expr {abs($dang-$pi/2.0) < 1e-6}]
    set cx $x1
    set cy $y1

    if {"GCODE" in $allowed} {
        set cutbit  [cadobjects_object_cutbit $canv $objid]
        set cutside [cadobjects_object_getdatum $canv $objid "CUTSIDE"]
        set cutdiam [mlcnc_tooldiam $cutbit]
    }

    if {"CIRCLE" in $allowed && $isperp && $isequal} {
        set rad1 $dist1
        if {"GCODE" in $allowed} {
            if {$cutbit > 0} {
                if {$cutside == "inside"} {
                    set rad1 [expr {$rad1-$cutdiam/2.0}]
                } elseif {$cutside == "outside"} {
                    set rad1 [expr {$rad1+$cutdiam/2.0}]
                }
            } else {
                return ""
            }
        }
        return [list CIRCLE [list $cx $cy $rad1]]
    } elseif {"ELLIPSE" in $allowed && $isperp && $isequal} {
        set rad1 $dist2
        set rad2 $dist2
        return [list ELLIPSE [list $cx $cy $rad1 $rad2]]
    } elseif {"ELLIPSE" in $allowed && $isperp && $isvert} {
        set rad1 $dist2
        set rad2 $dist1
        return [list ELLIPSE [list $cx $cy $rad1 $rad2]]
    } elseif {"ELLIPSE" in $allowed && $isperp && $ishoriz} {
        set rad1 $dist1
        set rad2 $dist2
        return [list ELLIPSE [list $cx $cy $rad1 $rad2]]
    } elseif {"ELLIPSEROT" in $allowed && $isperp} {
        set rot [expr {fmod($ang1*180.0/$pi+180.0,360.0)}]
        set rad1 $dist1
        set rad2 $dist2
        return [list ELLIPSEROT [list $cx $cy $rad1 $rad2 $rot]]
    } elseif {"ELLIPSEROT" in $allowed && $isequal} {
        set rotr [expr {atan2($y3-$cy,$x3-$cx)}]
        set rot [expr {$rotr*180.0/$pi}]
        set mx1 [expr {($cx+$x3)/2.0}]
        set my1 [expr {($cy+$y3)/2.0}]
        set rad1 [expr {hypot($cy-$my1,$cx-$mx1)/cos($rotr)}]
        set rad2 [expr {hypot($y2-$my1,$x2-$mx1)/sin($rotr)}]
        return [list ELLIPSEROT [list $cx $cy $rad1 $rad2 $rot]]
    } elseif {"ARC" in $allowed && $isperp && $isequal} {
        return [list ARC [list $cx $cy $dist1 0.0 360.0]]
    } elseif {"BEZIER" in $allowed} {
        # TODO: This is a hack!  Need to replace this bezier approximation
        # with real rotated-ellipse calculation code.
        # Bezier approximation has about a 0.1% error.
        # Not good enough for machining operations.
        return [list BEZIER $bezpath]
    } elseif {"LINES" in $allowed} {
        set path {}
        bezutil_append_line_from_bezier path $bezpath
        if {"GCODE" in $allowed} {
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
    }
    return {}
}


proc plugin_ellipsectrtan_pointsofinterest {canv objid coords nearx neary} {
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set scalemult [expr {$dpi*$scalefactor}]
    set linewidth [cadobjects_object_stroke_width $canv $objid]
    set closeenough [$canv cget -closeenough]
    set closeenough [expr {(5+$closeenough)/$scalemult+$linewidth/2.0}]
    set tolerance 1e-4

    set poi {}
    set bezpath [cadobjects_object_getdatum $canv $objid "BEZIERPATH"]
    set nodenum 0
    foreach {x y} $coords {
        lappend poi "controlpoints" $x $y "Control point" [incr nodenum]
        incr nodenum 3
    }
    cadobjects_object_bezier_pois poi "contours" "On Ellipse" $bezpath $nearx $neary $closeenough $tolerance
    return $poi
}


proc plugin_ellipsectrtan_bbox {canv objid coords} {
    foreach {x1 y1 x2 y2 x3 y3} $coords break

    set cx $x1
    set cy $y1
    set cx1 [expr {$cx-($x3-$cx)}]
    set cy1 [expr {$cy-($y3-$cy)}]

    return [geometry_pointlist_bbox [list $x3 $y3 $cx1 $cy1]]
}








proc plugin_ellipse3crn_editfields {canv objid coords} {
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
        type POINT
        name POINT3
        datum 2
        title "Point 3"
    }
    return $out
}


proc plugin_ellipse3crn_drawobj {canv objid coords tags color fill width dash} {
    set coords [cadobjects_scale_coords $canv $coords]
    foreach {cpx1 cpy1 cpx2 cpy2 cpx3 cpy3} $coords break
    set cx [expr {($cpx1+$cpx3)/2.0}]
    set cy [expr {($cpy1+$cpy3)/2.0}]
    set rad [expr {hypot($cpy1-$cpy2,$cpx1-$cpx2)/8.0}]
    cadobjects_object_draw_center_cross $canv $cx $cy $rad $tags $color $width
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_ellipse3crn_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    foreach {cpx1 cpy1 cpx2 cpy2 cpx3 cpy3} $coords break
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid ELLIPSE3CRN $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
    set cx [expr {($cpx1+$cpx3)/2.0}]
    set cy [expr {($cpy1+$cpy3)/2.0}]
    set cpx4 [expr {$cx-($cpx2-$cx)}]
    set cpy4 [expr {$cy-($cpy2-$cy)}]
    cadobjects_object_draw_control_line $canv $objid $cpx1 $cpy1 $cpx2 $cpy2 1 $color [dashpat construction]
    cadobjects_object_draw_control_line $canv $objid $cpx2 $cpy2 $cpx3 $cpy3 2 $color [dashpat construction]
    cadobjects_object_draw_control_line $canv $objid $cpx3 $cpy3 $cpx4 $cpy4 3 $color [dashpat construction]
    cadobjects_object_draw_control_line $canv $objid $cpx4 $cpy4 $cpx1 $cpy1 4 $color [dashpat construction]
}


proc plugin_ellipse3crn_recalculate {canv objid coords {flags ""}} {
    # TODO: This is a hack!  It looks good, though.
    # Need to replace this bezier approximation with real
    # rotated-ellipse calculation code.
    foreach {x1 y1 x2 y2 x3 y3} $coords break

    set cx [expr {($x1+$x3)/2.0}]
    set cy [expr {($y1+$y3)/2.0}]
    set x4 [expr {$cx-($x2-$cx)}]
    set y4 [expr {$cy-($y2-$cy)}]

    set mx1 [expr {($x1+$x2)/2.0}]
    set my1 [expr {($y1+$y2)/2.0}]
    set mx2 [expr {($x2+$x3)/2.0}]
    set my2 [expr {($y2+$y3)/2.0}]
    set mx3 [expr {($x3+$x4)/2.0}]
    set my3 [expr {($y3+$y4)/2.0}]
    set mx4 [expr {($x4+$x1)/2.0}]
    set my4 [expr {($y4+$y1)/2.0}]

    set ellipsepath {}
    lappend ellipsepath $mx1 $my1
    foreach {ex1 ey1 ex2 ey2 ex3 ey3} [list \
        $mx1 $my1 $mx2 $my2 $x2 $y2 \
        $mx2 $my2 $mx3 $my3 $x3 $y3 \
        $mx3 $my3 $mx4 $my4 $x4 $y4 \
        $mx4 $my4 $mx1 $my1 $x1 $y1 \
    ] {
        set m1 0.447707
        set m2 [expr {1.0-$m1}]
        set ix1 [expr {($m1*$ex1+$m2*$ex3)}]
        set iy1 [expr {($m1*$ey1+$m2*$ey3)}]
        set ix2 [expr {($m1*$ex2+$m2*$ex3)}]
        set iy2 [expr {($m1*$ey2+$m2*$ey3)}]
        lappend ellipsepath $ix1 $iy1  $ix2 $iy2  $ex2 $ey2
    }
    cadobjects_object_setdatum $canv $objid "BEZIERPATH" $ellipsepath
}


proc plugin_ellipse3crn_decompose {canv objid coords allowed} {
    # TODO: This is a hack!  Need to replace this bezier approximation
    # with real rotated-ellipse calculation code.
    set bezpath [cadobjects_object_getdatum $canv $objid "BEZIERPATH"]

    constants pi
    foreach {x1 y1 x2 y2 x3 y3} $coords break
    set dist1 [expr {hypot($y1-$y2,$x1-$x2)}]
    set dist2 [expr {hypot($y3-$y2,$x3-$x2)}]
    set ang1 [expr {atan2($y1-$y2,$x1-$x2)}]
    set ang2 [expr {atan2($y3-$y2,$x3-$x2)}]
    set dang [expr {abs(fmod($ang2-$ang1,$pi))}]
    set ishoriz [expr {abs($ang1) < 1e-6 || abs(abs($ang1)-$pi) < 1e-6}]
    set isvert [expr {abs(abs($ang1)-$pi/2.0) < 1e-6}]
    set isequal [expr {abs($dist1-$dist2) < 1e-6}]
    set isperp [expr {abs($dang-$pi/2.0) < 1e-6}]
    set cx [expr {($x1+$x3)/2.0}]
    set cy [expr {($y1+$y3)/2.0}]

    if {"GCODE" in $allowed} {
        set cutbit  [cadobjects_object_cutbit $canv $objid]
        set cutside [cadobjects_object_getdatum $canv $objid "CUTSIDE"]
        set cutdiam [mlcnc_tooldiam $cutbit]
    }

    if {"CIRCLE" in $allowed && $isperp && $isequal} {
        set rad1 [expr {$dist1/2.0}]
        if {"GCODE" in $allowed} {
            if {$cutbit > 0} {
                if {$cutside == "inside"} {
                    set rad1 [expr {$rad1-$cutdiam/2.0}]
                } elseif {$cutside == "outside"} {
                    set rad1 [expr {$rad1+$cutdiam/2.0}]
                }
            } else {
                return ""
            }
        }
        return [list CIRCLE [list $cx $cy $rad1]]
    } elseif {"ELLIPSE" in $allowed && $isperp && $isequal} {
        set rad1 [expr {$dist1/2.0}]
        set rad2 $rad1
        return [list ELLIPSE [list $cx $cy $rad1 $rad2]]
    } elseif {"ELLIPSE" in $allowed && $isperp && $isvert} {
        set rad1 [expr {$dist2/2.0}]
        set rad2 [expr {$dist1/2.0}]
        return [list ELLIPSE [list $cx $cy $rad1 $rad2]]
    } elseif {"ELLIPSE" in $allowed && $isperp && $ishoriz} {
        set rad1 [expr {$dist1/2.0}]
        set rad2 [expr {$dist2/2.0}]
        return [list ELLIPSE [list $cx $cy $rad1 $rad2]]
    } elseif {"ELLIPSEROT" in $allowed && $isperp} {
        set rot [expr {fmod($ang1*180.0/$pi+180.0,360.0)}]
        set rad1 [expr {$dist1/2.0}]
        set rad2 [expr {$dist2/2.0}]
        return [list ELLIPSEROT [list $cx $cy $rad1 $rad2 $rot]]
    } elseif {"ELLIPSEROT" in $allowed && $isequal} {
        set rotr [expr {atan2($y3-$cy,$x3-$cx)}]
        set rot [expr {$rotr*180.0/$pi}]
        set mx1 [expr {($x2+$x3)/2.0}]
        set my1 [expr {($y2+$y3)/2.0}]
        set mx2 [expr {($cx+$x3)/2.0}]
        set my2 [expr {($cy+$y3)/2.0}]
        set rad1 [expr {hypot($cy-$my2,$cx-$mx2)/cos($rotr)}]
        set rad2 [expr {hypot($my1-$my2,$mx1-$mx2)/sin($rotr)}]
        return [list ELLIPSEROT [list $cx $cy $rad1 $rad2 $rot]]
    } elseif {"ARC" in $allowed && $isperp && $isequal} {
        return [list ARC [list $cx $cy [expr {$dist1/2.0}] 0.0 360.0]]
    } elseif {"BEZIER" in $allowed} {
        return [list BEZIER $bezpath]
    } elseif {"LINES" in $allowed} {
        set path {}
        bezutil_append_line_from_bezier path $bezpath
        if {"GCODE" in $allowed} {
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
    }
    return {}
}


proc plugin_ellipse3crn_pointsofinterest {canv objid coords nearx neary} {
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set scalemult [expr {$dpi*$scalefactor}]
    set linewidth [cadobjects_object_stroke_width $canv $objid]
    set closeenough [$canv cget -closeenough]
    set closeenough [expr {(5+$closeenough)/$scalemult+$linewidth/2.0}]
    set tolerance 1e-4

    set poi {}
    set bezpath [cadobjects_object_getdatum $canv $objid "BEZIERPATH"]
    set nodenum 0
    foreach {x y} $coords {
        lappend poi "controlpoints" $x $y "Control point" [incr nodenum]
        incr nodenum 3
    }
    cadobjects_object_bezier_pois poi "contours" "On Ellipse" $bezpath $nearx $neary $closeenough $tolerance
    return $poi
}


proc plugin_ellipse3crn_bbox {canv objid coords} {
    return [geometry_pointlist_bbox $coords]
}





proc plugin_ellipses_register {} {
    tool_register_ex ELLIPSECTR "&Ellipses" "Ellipse by &Center and Corner Point" {
        {1    "Centerpoint"}
        {2    "Corner"}
    } -icon "tool-ellipsectr" -creator
    tool_register_ex ELLIPSEDIAG "&Ellipses" "Ellipse by &Diagonal Points" {
        {1    "First Corner"}
        {2    "Opposite Corner"}
    } -icon "tool-ellipsediag" -creator
    tool_register_ex ELLIPSECTRTAN "&Ellipses" "Ellipse by Center and &Tangent" {
        {1    "Centerpoint"}
        {2    "Point on Ellipse"}
        {3    "Tangential Line Point"}
    } -icon "tool-ellipsectrtan" -creator
    tool_register_ex ELLIPSEOPPTAN "&Ellipses" "Ellipse by &Opposing Points and Tangent" {
        {1    "Point on Ellipse"}
        {2    "Opposite Point on Ellipse"}
        {3    "Tangential Line Point"}
    } -icon "tool-ellipseopptan" -creator
    tool_register_ex ELLIPSE3CRN "&Ellipses" "Ellipse by &3 Corner Points" {
        {1    "First Corner"}
        {2    "Second Corner"}
        {3    "Third Corner"}
    } -icon "tool-ellipse3crn" -creator
}
plugin_ellipses_register 


# vim: set ts=4 sw=4 nowrap expandtab: settings

