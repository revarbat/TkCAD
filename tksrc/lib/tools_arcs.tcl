proc plugin_arcctr_editfields {canv objid coords} {
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
        name STARTPT
        datum 1
        title "Start pt"
    }
    lappend out {
        type POINT
        name ENDPT
        datum 2
        title "End pt"
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
        valgetcb "plugin_arcctr_getfield"
        valsetcb "plugin_arcctr_setfield"
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
        valgetcb "plugin_arcctr_getfield"
        valsetcb "plugin_arcctr_setfield"
    }
    lappend out {
        type FLOAT
        name EXTENT
        datum ""
        title "Extent Angle"
        min -360.0
        max  360.0
        increment 5.0
        width 8
        valgetcb "plugin_arcctr_getfield"
        valsetcb "plugin_arcctr_setfield"
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
        valgetcb "plugin_arcctr_getfield"
        valsetcb "plugin_arcctr_setfield"
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
        valgetcb "plugin_arcctr_getfield"
        valsetcb "plugin_arcctr_setfield"
        islength 1
    }
    lappend out {
        type FLOAT
        name LENGTH
        datum ""
        title "Length"
        min 0.0001
        max 1e6
        increment 0.125
        width 8
        valgetcb "plugin_arcctr_getfield"
        valsetcb "plugin_arcctr_setfield"
        islength 1
    }
    return $out
}


proc plugin_arcctr_getfield {canv objid coords field} {
    constants pi
    foreach {cx cy cpx1 cpy1 cpx2 cpy2} $coords break
    switch -exact -- $field {
        STARTANG {
            set a [expr {atan2($cpy1-$cy,$cpx1-$cx)*180.0/$pi}]
            return $a
        }
        ENDANG {
            set a [expr {atan2($cpy2-$cy,$cpx2-$cx)*180.0/$pi}]
            return $a
        }
        EXTENT {
            set sa [expr {atan2($cpy1-$cy,$cpx1-$cx)*180.0/$pi}]
            set ea [expr {atan2($cpy2-$cy,$cpx2-$cx)*180.0/$pi}]
            set xa [expr {$ea-$sa}]
            if {$xa < 1e-6} {
                set xa [expr {$xa+360.0}]
            }
            return $xa
        }
        RADIUS {
            set d [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
            return $d
        }
        DIAMETER {
            set d [expr {2.0*hypot($cpy1-$cy,$cpx1-$cx)}]
            return $d
        }
        LENGTH {
            set r [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
            set a1 [expr {atan2($cpy1-$cy,$cpx1-$cx)}]
            set a2 [expr {atan2($cpy2-$cy,$cpx2-$cx)}]
            if {$a1 < 0.0} {
                set a1 [expr {$a1+$pi*2.0}]
            }
            while {$a2 < $a1} {
                set a2 [expr {$a2+$pi*2.0}]
            }
            set ext [expr {$a2-$a1}]
            if {abs($ext) < 1e-6} {
                set ext [expr {$ext+2.0*$pi}]
            }
            set l [expr {$r*$ext}]
            return $l
        }
    }
}


proc plugin_arcctr_setfield {canv objid coords field val} {
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
            set sang [expr {atan2($cpy1-$cy,$cpx1-$cx)*180.0/$pi}]
            set cpx2 [expr {$hy1*cos(($sang+$val)*$pi/180.0)+$cx}]
            set cpy2 [expr {$hy1*sin(($sang+$val)*$pi/180.0)+$cy}]
            set coords [list $cx $cy $cpx1 $cpy1 $cpx2 $cpy2]
            cadobjects_object_set_coords $canv $objid $coords
        }
        DIAMETER -
        RADIUS {
            if {$field == "DIAMETER"} {
                set hy1 [expr {2.0*$hy1}]
                set hy2 [expr {2.0*$hy2}]
            }
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
        LENGTH {
            set a1 [expr {atan2($cpy1-$cy,$cpx1-$cx)}]
            set a2 [expr {($val/$hy1)+$a1}]
            set cpx2 [expr {$hy1*cos($a2)+$cx}]
            set cpy2 [expr {$hy1*sin($a2)+$cy}]
            set coords [list $cx $cy $cpx1 $cpy1 $cpx2 $cpy2]
            cadobjects_object_set_coords $canv $objid $coords
        }
    }
}


proc plugin_arcctr_shearobj {canv objid coords sx sy cx cy} {
    foreach {dectyp coords} [plugin_arcctr_decompose $canv $objid $coords [list "BEZIER"]] break
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid BEZIER
    return 0 ;# Also allow default coordlist transform
}


proc plugin_arcctr_scaleobj {canv objid coords sx sy cx cy} {
    if {abs($sx-$sy) < 1e-6} {
        return 0 ;# Since we're symmetric, allow default coordlist transform
    }
    foreach {dectyp coords} [plugin_arcctr_decompose $canv $objid $coords [list "BEZIER"]] break
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid BEZIER
    return 0 ;# Also allow default coordlist transform
}


proc plugin_arcctr_flipobj {canv objid coords x0 y0 x1 y1} {
    foreach {cx cy cpx1 cpy1 cpx2 cpy2} $coords break
    set rad [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set ang [expr {atan2($cpy2-$cy,$cpx2-$cx)}]
    set cpx2 [expr {$rad*cos($ang)+$cx}]
    set cpy2 [expr {$rad*sin($ang)+$cy}]
    set coords [list $cx $cy $cpx2 $cpy2 $cpx1 $cpy1]
    cadobjects_object_set_coords $canv $objid $coords
    return 0 ;# Also allow default coordlist transformation
}


proc plugin_arcctr_drawobj {canv objid coords tags color fill width dash} {
    set coords [cadobjects_scale_coords $canv $coords]
    foreach {cx cy cpx1 cpy1 cpx2 cpy2} $coords break
    set radius [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set crrad [expr {$radius/4.0}]
    cadobjects_object_draw_center_cross $canv $cx $cy $crrad $tags $color $width
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_arcctr_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    foreach {cx cy cpx1 cpy1 cpx2 cpy2} $coords break
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid ARCCTR $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
    cadobjects_object_draw_control_line $canv $objid $cx $cy $cpx1 $cpy1 1 $color [dashpat construction]
    set radius [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set rad2 [expr {hypot($cpy2-$cy,$cpx2-$cx)}]
    set ang2 [expr {atan2($cpy2-$cy,$cpx2-$cx)}]
    set cpx3 [expr {$radius*cos($ang2)+$cx}]
    set cpy3 [expr {$radius*sin($ang2)+$cy}]
    if {$radius > $rad2} {
        set cpx2 $cpx3
        set cpy2 $cpy3
    }
    cadobjects_object_draw_control_line $canv $objid $cx $cy $cpx2 $cpy2 1 $color [dashpat construction]
}


proc plugin_arcctr_recalculate {canv objid coords {flags ""}} {
    # Nothing to calculate.
}


proc plugin_arcctr_dragctls {canv objid coords nodes dx dy} {
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


proc plugin_arcctr_decompose {canv objid coords allowed} {
    constants radtodeg
    foreach {cx cy cpx1 cpy1 cpx2 cpy2} $coords break
    set radius [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set start  [expr {atan2($cpy1-$cy,$cpx1-$cx)*$radtodeg}]
    set endang [expr {atan2($cpy2-$cy,$cpx2-$cx)*$radtodeg}]
    set extent [expr {$endang-$start}]
    if {$extent < 1e-6} {
        set extent [expr {$extent+360.0}]
    }
    if {"ARC" in $allowed} {
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
            } else {
                return ""
            }
        }
        return [list ARC [list $cx $cy $radius $start $extent]]
    } elseif {"BEZIER" in $allowed} {
        set arcpath {}
        bezutil_append_bezier_arc arcpath $cx $cy $radius $radius $start $extent
        return [list BEZIER $arcpath]
    } elseif {"LINES" in $allowed} {
        set arcpath {}
        bezutil_append_line_arc arcpath $cx $cy $radius $radius $start $extent
        return [list LINES $arcpath]
    }
    return {}
}


proc plugin_arcctr_pointsofinterest {canv objid coords nearx neary} {
    constants pi
    foreach {cx0 cy0 cx1 cy1 cx2 cy2} $coords break
    set ang1 [expr {atan2($cy1-$cy0,$cx1-$cx0)}]
    set ang2 [expr {atan2($cy2-$cy0,$cx2-$cx0)}]
    set arcrad [expr {hypot($cy1-$cy0,$cx1-$cx0)}]
    set cx2 [expr {$arcrad*cos($ang2)+$cx0}]
    set cy2 [expr {$arcrad*sin($ang2)+$cy0}]

    set arcang [expr {atan2($neary-$cy0,$nearx-$cx0)}]
    if {$ang1 < 0.0} {
        set ang1 [expr {$ang1+$pi*2.0}]
    }
    while {$ang2 < $ang1} {
        set ang2 [expr {$ang2+$pi*2.0}]
    }
    while {$arcang < $ang1} {
        set arcang [expr {$arcang+$pi*2.0}]
    }
    set ax ""
    if {$arcang <= $ang2} {
        set ax [expr {$arcrad*cos($arcang)+$cx0}]
        set ay [expr {$arcrad*sin($arcang)+$cy0}]
    }

    set poi {}

    set prevpt [cadobjects_get_prev_point $canv]
    if {$prevpt != ""} {
        foreach {ox oy} $prevpt break
        cadobjects_calculate_tangent_pois poi $cx0 $cy0 $arcrad $ox $oy $ang1 [expr {$ang2-$ang1}]
    }

    lappend poi "controlpoints" $cx0  $cy0  "Center Point"   1
    lappend poi "controlpoints" $cx1  $cy1  "Start Point"    2
    lappend poi "controlpoints" $cx2  $cy2  "End Point"      3
    if {$ax != ""} {
        lappend poi "contours"  $ax   $ay   "On Arc"        -1
    }
    return $poi
}


proc plugin_arcctr_partial_position {canv objid coords part} {
    constants pi
    foreach {cx0 cy0 cx1 cy1 cx2 cy2} $coords break
    set ang1 [expr {atan2($cy1-$cy0,$cx1-$cx0)}]
    set ang2 [expr {atan2($cy2-$cy0,$cx2-$cx0)}]
    set arcrad [expr {hypot($cy1-$cy0,$cx1-$cx0)}]
    set cx2 [expr {$arcrad*cos($ang2)+$cx0}]
    set cy2 [expr {$arcrad*sin($ang2)+$cy0}]
    set dang [expr {$ang2-$ang1}]
    if {$dang < 1e-6} {
        set dang [expr {$dang+2.0*$pi}]
    }
    set ang [expr {$ang1+$dang*$part}]
    set pang [expr {$ang+$pi/2.0}]
    set x [expr {$arcrad*cos($ang)+$cx0}]
    set y [expr {$arcrad*sin($ang)+$cy0}]
    return [list $x $y $pang]
}


proc plugin_arcctr_length {canv objid coords} {
    constants degtorad radtodeg
    foreach {cx cy cpx1 cpy1 cpx2 cpy2} $coords break
    set radius [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set start  [expr {atan2($cpy1-$cy,$cpx1-$cx)*$radtodeg}]
    set endang [expr {atan2($cpy2-$cy,$cpx2-$cx)*$radtodeg}]
    set extent [expr {$endang-$start}]
    if {$extent < 1e-6} {
        set extent [expr {$extent+360.0}]
    }
    set len [expr {$radius*$extent*$degtorad}]
    return $len
}


proc plugin_arcctr_sliceobj {canv objid coords x y} {
    constants pi
    foreach {cx cy cpx1 cpy1 cpx2 cpy2} $coords break
    set rad [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set ang1 [expr {atan2($cpy1-$cy,$cpx1-$cx)}]
    set ang2 [expr {atan2($cpy2-$cy,$cpx2-$cx)}]
    set sang [expr {atan2($y-$cy,$x-$cx)}]
    set srad [expr {hypot($y-$cy,$x-$cx)}]

    set closeenough [cadobjects_get_closeenough $canv $objid]
    if {abs($srad-$rad) > $closeenough} {
        return $objid
    }

    if {$ang1 < 0.0} {
        set ang1 [expr {$ang1+2.0*$pi}]
    }
    if {$ang2 <= $ang1} {
        set ang2 [expr {$ang2+2.0*$pi}]
    }
    if {$sang < $ang1} {
        set sang [expr {$sang+2.0*$pi}]
    }
    if {$sang >= $ang2 || $sang <= $ang1} {
        return $objid
    }
    if {abs($sang-$ang1) < 1e-6 || abs($sang-$ang2) < 1e-6} {
        return $objid
    }
    set cpx2 [expr {$cx+$rad*cos($ang2)}]
    set cpy2 [expr {$cy+$rad*sin($ang2)}]
    set cpx3 [expr {$cx+$rad*cos($sang)}]
    set cpy3 [expr {$cy+$rad*sin($sang)}]
    set nuobj [cadobjects_object_create $canv ARCCTR [list $cx $cy $cpx3 $cpy3 $cpx2 $cpy2] {}]
    set coords [list $cx $cy $cpx1 $cpy1 $cpx3 $cpy3]
    cadobjects_object_set_coords $canv $objid $coords
    return [list $objid $nuobj]
}


proc plugin_arcctr_offsetcopyobj {canv objid coords offset} {
    foreach {cx cy cpx1 cpy1 cpx2 cpy2} $coords break
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
    set nuobj [cadobjects_object_create $canv ARCCTR [list $cx $cy $cpx1 $cpy1 $cpx2 $cpy2] {}]
    return $nuobj
}



proc plugin_arcctr_bbox {canv objid coords} {
    constants degtorad radtodeg
    foreach {cx cy cpx1 cpy1 cpx2 cpy2} $coords break
    set radius [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set start  [expr {atan2($cpy1-$cy,$cpx1-$cx)*$radtodeg}]
    set endang [expr {atan2($cpy2-$cy,$cpx2-$cx)*$radtodeg}]
    set extent [expr {$endang-$start}]
    if {$extent < 1e-6} {
        set extent [expr {$extent+360.0}]
    }
    set minx $cpx1
    set maxx $cpx1
    set miny $cpy1
    set maxy $cpy1
    set ang [expr {ceil($start/90.0)*90.0}]
    for {} {$ang < $start+$extent} {set ang [expr {$ang+90.0}]} {
        set px [expr {$radius*cos($ang*$degtorad)+$cx}]
        set py [expr {$radius*sin($ang*$degtorad)+$cy}]
        set minx [expr {min($minx,$px)}]
        set maxx [expr {max($maxx,$px)}]
        set miny [expr {min($miny,$py)}]
        set maxy [expr {max($maxy,$py)}]
    }
    set px [expr {$radius*cos($endang*$degtorad)+$cx}]
    set py [expr {$radius*sin($endang*$degtorad)+$cy}]
    set minx [expr {min($minx,$px)}]
    set maxx [expr {max($maxx,$px)}]
    set miny [expr {min($miny,$py)}]
    set maxy [expr {max($maxy,$py)}]

    return [list $minx $miny $maxx $maxy]
}








proc plugin_arc3pt_editfields {canv objid coords} {
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
    lappend out {
        type LABEL
        name RO_LENGTH
        datum ""
        title "Length"
        valgetcb "plugin_arc3pt_getfield"
    }
    return $out
}


proc plugin_arc3pt_getfield {canv objid coords field} {
    switch -exact -- $field {
        RO_LENGTH {
            set totlen [plugin_arc3pt_length $canv $objid $coords]
            return [format "%.4f" $totlen]
        }
    }
    return ""
}



proc plugin_arc3pt_shearobj {canv objid coords sx sy cx cy} {
    foreach {dectyp coords} [plugin_arc3pt_decompose $canv $objid $coords [list "BEZIER"]] break
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid BEZIER
    return 0 ;# Also allow default coordlist transform
}


proc plugin_arc3pt_scaleobj {canv objid coords sx sy cx cy} {
    foreach {dectyp coords} [plugin_arc3pt_decompose $canv $objid $coords [list "BEZIER"]] break
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid BEZIER
    return 0 ;# Also allow default coordlist transform
}


proc plugin_arc3pt_drawobj {canv objid coords tags color fill width dash} {
    set isline [cadobjects_object_getdatum $canv $objid "ISLINE"]
    if {!$isline} {
        set boxcoords [cadobjects_object_getdatum $canv $objid "BOX"]
        foreach {x0 y0 x1 y1} [cadobjects_scale_coords $canv $boxcoords] break
        set cx [expr {($x0+$x1)/2.0}]
        set cy [expr {($y0+$y1)/2.0}]
        set rad [expr {abs($y1-$cy)/4.0}]
        cadobjects_object_draw_center_cross $canv $cx $cy $rad $tags $color $width
    }
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_arc3pt_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid ARC3PT $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_arc3pt_recalculate {canv objid coords {flags ""}} {
    constants pi
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
    set start  [expr {atan2($cpy1-$cy,$cpx1-$cx)*180.0/$pi}]
    set midang [expr {atan2($cpy3-$cy,$cpx3-$cx)*180.0/$pi}]
    set endang [expr {atan2($cpy2-$cy,$cpx2-$cx)*180.0/$pi}]
    set middelta [expr {$midang-$start}]
    if {$middelta < -180.0} {
        set middelta [expr {$middelta+360.0}]
    } elseif {$middelta > 180.0} {
        set middelta [expr {$middelta-360.0}]
    }
    set extent [expr {$endang-$start}]
    if {$extent < -180.0} {
        set extent [expr {$extent+360.0}]
    } elseif {$extent > 180.0} {
        set extent [expr {$extent-360.0}]
    }

    set needflip 0
    if {$extent < 0.0 && $middelta >= 0.0} {
        set needflip 1
    } elseif {$extent >= 0.0 && $middelta < 0.0} {
        set needflip 1
    } elseif {hypot($cpx3-$cpx1,$cpy3-$cpy1) > hypot($cpx2-$cpx1,$cpy2-$cpy1)} {
        set needflip 1
    }
    if {$needflip} {
        if {$extent >= 0.0} {
            set extent [expr {-360.0+$extent}]
        } else {
            set extent [expr {360.0+$extent}]
        }
    }
    set x0 [expr {$cx-$radius}]
    set y0 [expr {$cy-$radius}]
    set x1 [expr {$cx+$radius}]
    set y1 [expr {$cy+$radius}]
    cadobjects_object_setdatum $canv $objid "BOX" [list $x0 $y0 $x1 $y1]
    cadobjects_object_setdatum $canv $objid "START" $start
    cadobjects_object_setdatum $canv $objid "EXTENT" $extent
}


proc plugin_arc3pt_decompose {canv objid coords allowed} {
    foreach {cpx1 cpy1 cpx2 cpy2 cpx3 cpy3} $coords break
    set isline [cadobjects_object_getdatum $canv $objid "ISLINE"]
    if {$isline != 1} {
        set boxcoords [cadobjects_object_getdatum $canv $objid "BOX"]
        set start     [cadobjects_object_getdatum $canv $objid "START"]
        set extent    [cadobjects_object_getdatum $canv $objid "EXTENT"]
        foreach {x0 y0 x1 y1} $boxcoords break
        set cx [expr {($x0+$x1)/2.0}]
        set cy [expr {($y0+$y1)/2.0}]
        set radius [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    }

    if {$isline} {
        if {"LINES" in $allowed} {
            return [list LINES [list $cpx1 $cpy1 $cpx3 $cpy3 $cpx2 $cpy2]]
        }
    } elseif {"ARC" in $allowed && !$isline} {
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
            } else {
                return ""
            }
        }
        return [list ARC [list $cx $cy $radius $start $extent]]
    } elseif {"BEZIER" in $allowed && !$isline} {
        set arcpath {}
        bezutil_append_bezier_arc arcpath $cx $cy $radius $radius $start $extent
        return [list BEZIER $arcpath]
    } elseif {"LINES" in $allowed} {
        if {$isline} {
            return [list LINES [list $cpx1 $cpy1 $cpx3 $cpy3]]
        } else {
            set arcpath {}
            bezutil_append_line_arc arcpath $cx $cy $radius $radius $start $extent
            return [list LINES $arcpath]
        }
    }
    return {}
}


proc plugin_arc3pt_pointsofinterest {canv objid coords nearx neary} {
    foreach {cx0 cy0 cx1 cy1 cx2 cy2} $coords break
    constants pi
    set isline [cadobjects_object_getdatum $canv $objid "ISLINE"]

    set poi {}
    lappend poi "controlpoints" $cx0  $cy0  "Center Point"   1
    lappend poi "controlpoints" $cx1  $cy1  "Start Point"    2
    lappend poi "controlpoints" $cx2  $cy2  "End Point"      3
    if {$isline} {
        return $poi
    }

    set ang1 [cadobjects_object_getdatum $canv $objid "START"]
    set ang2 [cadobjects_object_getdatum $canv $objid "EXTENT"]
    set boxcoords [cadobjects_object_getdatum $canv $objid "BOX"]
    foreach {x0 y0 x1 y1} $boxcoords break

    set cx [expr {($x0+$x1)/2.0}]
    set cy [expr {($y0+$y1)/2.0}]
    set arcrad [expr {hypot($cy0-$cy,$cx0-$cx)}]

    set arcang [expr {atan2($neary-$cy,$nearx-$cx)}]
    set ang1 [expr {$ang1*$pi/180.0}]
    set ang2 [expr {$ang1+$ang2*$pi/180.0}]
    if {$ang1 < 0.0} {
        set ang1 [expr {$ang1+$pi*2.0}]
    }
    while {$ang2 < $ang1} {
        set ang2 [expr {$ang2+$pi*2.0}]
    }
    while {$arcang < $ang1} {
        set arcang [expr {$arcang+$pi*2.0}]
    }
    if {$arcang <= $ang2} {
        set ax [expr {$arcrad*cos($arcang)+$cx}]
        set ay [expr {$arcrad*sin($arcang)+$cy}]
        lappend poi "contours" $ax $ay "On Line" -1
    }

    set prevpt [cadobjects_get_prev_point $canv]
    if {$prevpt != ""} {
        foreach {ox oy} $prevpt break
        cadobjects_calculate_tangent_pois poi $cx $cy $arcrad $ox $oy $ang1 $ang2
    }

    return $poi
}


proc plugin_arc3pt_partial_position {canv objid coords part} {
    set isline [cadobjects_object_getdatum $canv $objid "ISLINE"]
    set start [cadobjects_object_getdatum $canv $objid "START"]
    set extent [cadobjects_object_getdatum $canv $objid "EXTENT"]
    set boxcoords [cadobjects_object_getdatum $canv $objid "BOX"]
    foreach {x0 y0 x1 y1} $boxcoords break
    set cx [expr {($x0+$x1)/2.0}]
    set cy [expr {($y0+$y1)/2.0}]
    set arcrad [expr {abs($y0-$cy)}]

    constants pi degtorad
    set start [expr {$start*$degtorad}]
    set extent [expr {$extent*$degtorad}]

    set ang [expr {$start+$extent*$part}]
    set pang [expr {$ang+$pi/2.0}]
    set x [expr {$arcrad*cos($ang)+$cx}]
    set y [expr {$arcrad*sin($ang)+$cy}]
    return [list $x $y $pang]
}


proc plugin_arc3pt_length {canv objid coords} {
    constants degtorad
    set extent [cadobjects_object_getdatum $canv $objid "EXTENT"]
    set boxcoords [cadobjects_object_getdatum $canv $objid "BOX"]
    foreach {x0 y0 x1 y1} $boxcoords break
    set cx [expr {($x0+$x1)/2.0}]
    set cy [expr {($y0+$y1)/2.0}]
    set arcrad [expr {abs($y0-$cy)}]
    set len [expr {$arcrad*$extent*$degtorad}]
    return $len
}


proc plugin_arc3pt_sliceobj {canv objid coords x y} {
    constants pi radtodeg degtorad
    foreach {cpx1 cpy1 cpx2 cpy2 cpx3 cpy3} $coords break
    set boxcoords [cadobjects_object_getdatum $canv $objid "BOX"]
    set start [cadobjects_object_getdatum $canv $objid "START"]
    set extent [cadobjects_object_getdatum $canv $objid "EXTENT"]

    foreach {x0 y0 x1 y1} $boxcoords break
    set cx [expr {($x0+$x1)/2.0}]
    set cy [expr {($y0+$y1)/2.0}]
    set rad [expr {abs($y0-$cy)}]

    set rad [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set sang [expr {atan2($y-$cy,$x-$cx)*$radtodeg}]
    while {$sang < $start} {
        set sang [expr {$sang+360.0}]
    }
    set ang3 [expr {atan2($cpy3-$cy,$cpx3-$cx)*$radtodeg}]
    while {$ang3 < $start} {
        set ang3 [expr {$ang3+360.0}]
    }

    set mang1 [expr {($start+$sang)/2.0}]
    set mang2 [expr {($start+$extent+$sang)/2.0}]
    if {abs($ang3-$sang) >= abs($sang-$start)/8.0} {
        if {$ang3 < $sang} {
            set mang1 $ang3
        } else {
            set mang2 $ang3
        }
    }

    set eang [expr {$start+$extent}]

    set cpx1 [expr {$cx+$rad*cos($start*$degtorad)}]
    set cpy1 [expr {$cy+$rad*sin($start*$degtorad)}]
    set cpx2 [expr {$cx+$rad*cos($mang1*$degtorad)}]
    set cpy2 [expr {$cy+$rad*sin($mang1*$degtorad)}]
    set cpx3 [expr {$cx+$rad*cos($sang*$degtorad)}]
    set cpy3 [expr {$cy+$rad*sin($sang*$degtorad)}]
    set cpx4 [expr {$cx+$rad*cos($mang2*$degtorad)}]
    set cpy4 [expr {$cy+$rad*sin($mang2*$degtorad)}]
    set cpx5 [expr {$cx+$rad*cos($eang*$degtorad)}]
    set cpy5 [expr {$cy+$rad*sin($eang*$degtorad)}]

    set coords1 [list $cpx1 $cpy1 $cpx3 $cpy3 $cpx2 $cpy2]
    set coords2 [list $cpx3 $cpy3 $cpx5 $cpy5 $cpx4 $cpy4]

    cadobjects_object_set_coords $canv $objid $coords1
    set nuobj [cadobjects_object_create $canv ARC3PT $coords2 {}]
    return [list $objid $nuobj]
}


proc plugin_arc3pt_offsetcopyobj {canv objid coords offset} {
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
    set nuobj [cadobjects_object_create $canv ARC3PT [list $cpx1 $cpy1 $cpx2 $cpy2 $cpx3 $cpy3] {}]
    return $nuobj
}


proc plugin_arc3pt_bbox {canv objid coords} {
    constants degtorad radtodeg
    foreach {cpx1 cpy1 cpx2 cpy2 cpx3 cpy3} $coords break
    set start [cadobjects_object_getdatum $canv $objid "START"]
    set extent [cadobjects_object_getdatum $canv $objid "EXTENT"]
    set boxcoords [cadobjects_object_getdatum $canv $objid "BOX"]
    foreach {x0 y0 x1 y1} $boxcoords break
    set cx [expr {($x0+$x1)/2.0}]
    set cy [expr {($y0+$y1)/2.0}]
    set radius [expr {abs($y0-$cy)}]
    set endang [expr {$start+$extent}]

    set minx $cpx1
    set maxx $cpx1
    set miny $cpy1
    set maxy $cpy1
    set ang [expr {ceil($start/90.0)*90.0}]
    if {$extent > 0.0} {
        for {} {$ang < $start+$extent} {set ang [expr {$ang+90.0}]} {
            set px [expr {$radius*cos($ang*$degtorad)+$cx}]
            set py [expr {$radius*sin($ang*$degtorad)+$cy}]
            set minx [expr {min($minx,$px)}]
            set maxx [expr {max($maxx,$px)}]
            set miny [expr {min($miny,$py)}]
            set maxy [expr {max($maxy,$py)}]
        }
    } else {
        for {} {$ang > $start+$extent} {set ang [expr {$ang-90.0}]} {
            set px [expr {$radius*cos($ang*$degtorad)+$cx}]
            set py [expr {$radius*sin($ang*$degtorad)+$cy}]
            set minx [expr {min($minx,$px)}]
            set maxx [expr {max($maxx,$px)}]
            set miny [expr {min($miny,$py)}]
            set maxy [expr {max($maxy,$py)}]
        }
    }
    set px $cpx2
    set py $cpy2
    set minx [expr {min($minx,$px)}]
    set maxx [expr {max($maxx,$px)}]
    set miny [expr {min($miny,$py)}]
    set maxy [expr {max($maxy,$py)}]

    return [list $minx $miny $maxx $maxy]
}








proc plugin_arctan_editfields {canv objid coords} {
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
        name START
        datum 0
        title "Start pt"
    }
    lappend out {
        type POINT
        name TANGENT
        datum 1
        title "Tangent pt"
    }
    lappend out {
        type POINT
        name END
        datum 2
        title "End pt"
    }
    lappend out {
        type FLOAT
        name TANGENTANG
        datum ""
        title "Tangent Angle"
        min -360.0
        max  360.0
        increment 5.0
        width 8
        valgetcb "plugin_arctan_getfield"
        valsetcb "plugin_arctan_setfield"
    }
    lappend out {
        type FLOAT
        name EXTENT
        datum ""
        title "Arc Extent"
        min -360.0
        max  360.0
        increment 5.0
        width 8
        valgetcb "plugin_arctan_getfield"
        valsetcb "plugin_arctan_setfield"
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
        valgetcb "plugin_arctan_getfield"
        valsetcb "plugin_arctan_setfield"
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
        valgetcb "plugin_arctan_getfield"
        valsetcb "plugin_arctan_setfield"
        islength 1
    }
    return $out
}


proc plugin_arctan_getfield {canv objid coords field} {
    constants pi
    set isline    [cadobjects_object_getdatum $canv $objid "ISLINE"]
    set boxcoords [cadobjects_object_getdatum $canv $objid "BOX"]
    set extent    [cadobjects_object_getdatum $canv $objid "EXTENT"]
    foreach {cpx1 cpy1 cpx2 cpy2 cpx3 cpy3} $coords break

    if {$isline} {
        set radius Inf
    } else {
        foreach {x0 y0 x1 y1} $boxcoords break
        set cx [expr {($x0+$x1)/2.0}]
        set cy [expr {($y0+$y1)/2.0}]
        set radius [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    }

    switch -exact -- $field {
        TANGENTANG {
            set a [expr {atan2($cpy2-$cpy1,$cpx2-$cpx1)*180.0/$pi}]
            return $a
        }
        EXTENT {
            return $extent
        }
        RADIUS {
            return $radius
        }
        DIAMETER {
            return [expr {2.0*$radius}]
        }
    }
}


proc plugin_arctan_setfield {canv objid coords field val} {
    constants pi
    set isline    [cadobjects_object_getdatum $canv $objid "ISLINE"]
    set boxcoords [cadobjects_object_getdatum $canv $objid "BOX"]
    set extent    [cadobjects_object_getdatum $canv $objid "EXTENT"]
    foreach {cpx1 cpy1 cpx2 cpy2 cpx3 cpy3} $coords break
    if {!$isline} {
        foreach {x0 y0 x1 y1} $boxcoords break
        set cx [expr {($x0+$x1)/2.0}]
        set cy [expr {($y0+$y1)/2.0}]
        set radius [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    }

    switch -exact -- $field {
        TANGENTANG {
            set dist [expr {hypot($cpy2-$cpy1,$cpx2-$cpx1)}]
            set cpx2 [expr {$dist*cos($val*$pi/180.0)+$cpx1}]
            set cpy2 [expr {$dist*sin($val*$pi/180.0)+$cpy1}]
            set coords [list $cpx1 $cpy1 $cpx2 $cpy2 $cpx3 $cpy3]
            cadobjects_object_set_coords $canv $objid $coords
        }
        EXTENT {
            if {!$isline} {
                set sang [expr {atan2($cpy1-$cy,$cpx1-$cx)*180.0/$pi}]
                set cpx3 [expr {$radius*cos(($sang+$val)*$pi/180.0)+$cx}]
                set cpy3 [expr {$radius*sin(($sang+$val)*$pi/180.0)+$cy}]
                set coords [list $cpx1 $cpy1 $cpx2 $cpy2 $cpx3 $cpy3]
                if {abs($cpx3-$cpx1)>1e-6 && abs($cpy3-$cpy1)>1e-6} {
                    cadobjects_object_set_coords $canv $objid $coords
                }
            }
        }
        DIAMETER -
        RADIUS {
            if {!$isline && $val > 1e-6} {
                if {$field == DIAMETER} {
                    set val [expr {0.5*$val}]
                }
                set sang [expr {atan2($cpy1-$cy,$cpx1-$cx)*180.0/$pi}]
                set eang [expr {atan2($cpy3-$cy,$cpx3-$cx)*180.0/$pi}]
                set pang [expr {$sang+180.0}]
                set ncx [expr {$val*cos($pang*$pi/180.0)+$cpx1}]
                set ncy [expr {$val*sin($pang*$pi/180.0)+$cpy1}]
                set cpx3 [expr {$val*cos($eang*$pi/180.0)+$ncx}]
                set cpy3 [expr {$val*sin($eang*$pi/180.0)+$ncy}]
                set coords [list $cpx1 $cpy1 $cpx2 $cpy2 $cpx3 $cpy3]
                cadobjects_object_set_coords $canv $objid $coords
            }
        }
    }
}


proc plugin_arctan_shearobj {canv objid coords sx sy cx cy} {
    foreach {dectyp coords} [plugin_arctan_decompose $canv $objid $coords [list "BEZIER"]] break
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid BEZIER
    return 0 ;# Also allow default coordlist transform
}


proc plugin_arctan_scaleobj {canv objid coords sx sy cx cy} {
    foreach {dectyp coords} [plugin_arctan_decompose $canv $objid $coords [list "BEZIER"]] break
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid BEZIER
    return 0 ;# Also allow default coordlist transform
}


proc plugin_arctan_drawobj {canv objid coords tags color fill width dash} {
    set isline [cadobjects_object_getdatum $canv $objid "ISLINE"]
    if {!$isline} {
        set boxcoords [cadobjects_object_getdatum $canv $objid "BOX"]
        foreach {x0 y0 x1 y1} [cadobjects_scale_coords $canv $boxcoords] break
        set cx [expr {($x0+$x1)/2.0}]
        set cy [expr {($y0+$y1)/2.0}]
        set rad [expr {abs($y1-$cy)/4.0}]
        cadobjects_object_draw_center_cross $canv $cx $cy $rad $tags $color $width
    }
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_arctan_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    foreach {cpx1 cpy1 cpx2 cpy2 cpx3 cpy3} $coords break
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid ARCTAN $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
    cadobjects_object_draw_control_line $canv $objid $cpx1 $cpy1 $cpx2 $cpy2 1 $color [dashpat construction]
}


proc plugin_arctan_recalculate {canv objid coords {flags ""}} {
    constants pi
    foreach {cpx1 cpy1 cpx2 cpy2 cpx3 cpy3} $coords break
    set mx1 $cpx1
    set my1 $cpy1
    set mx2 [expr {($cpx1+$cpx3)/2.0}]
    set my2 [expr {($cpy1+$cpy3)/2.0}]
    set pang1 [expr {atan2($cpy2-$cpy1,$cpx2-$cpx1)+$pi/2.0}]
    set pang2 [expr {atan2($cpy3-$cpy1,$cpx3-$cpx1)+$pi/2.0}]
    if {$pang1 > $pi} {
        set pang1 [expr {$pang1-$pi}]
    }
    if {$pang2 > $pi} {
        set pang2 [expr {$pang2-$pi}]
    }
    cadobjects_object_setdatum $canv $objid "ISLINE" 0
    set col [expr {$cpx1*($cpy2-$cpy3)+$cpx2*($cpy3-$cpy1)+$cpx3*($cpy1-$cpy2)}]
    if {abs($col) < 1e-6} {
        # Points are colinear.  Draw this as a straight line.
        cadobjects_object_setdatum $canv $objid "ISLINE" 1
        return
    }
    if {abs(abs($pang1)-$pi/2.0) < 1e-6} {
        # Segment1 is vertical.  We know Segment2 is not colinear.
        set m2 [expr {tan($pang2)}]
        set c2 [expr {$my2-$m2*$mx2}]
        set cx $mx1
        set cy [expr {$m2*$cx+$c2}]
    } elseif {abs(abs($pang2)-$pi/2.0) < 1e-6} {
        # Segment2 is vertical.  We know Segment1 is not colinear.
        set m1 [expr {tan($pang1)}]
        set c1 [expr {$my1-$m1*$mx1}]
        set cx $mx2
        set cy [expr {$m1*$cx+$c1}]
    } else {
        set m1 [expr {tan($pang1)}]
        set m2 [expr {tan($pang2)}]
        set c1 [expr {$my1-$m1*$mx1}]
        set c2 [expr {$my2-$m2*$mx2}]
        set cx [expr {($c2-$c1)/($m1-$m2)}]
        set cy [expr {$m1*$cx+$c1}]
    }
    set radius [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    if {$radius > 180} {
        # Points are colinear.  Draw this as a straight line.
        cadobjects_object_setdatum $canv $objid "ISLINE" 1
    }
    set start  [expr {atan2($cpy1-$cy,$cpx1-$cx)*180.0/$pi}]
    set endang [expr {atan2($cpy3-$cy,$cpx3-$cx)*180.0/$pi}]
    set extent [expr {$endang-$start}]
    if {$extent < -180.0} {
        set extent [expr {$extent+360.0}]
    } elseif {$extent > 180.0} {
        set extent [expr {$extent-360.0}]
    }
    set x0 [expr {$cx-$radius}]
    set y0 [expr {$cy-$radius}]
    set x1 [expr {$cx+$radius}]
    set y1 [expr {$cy+$radius}]
    cadobjects_object_setdatum $canv $objid "BOX" [list $x0 $y0 $x1 $y1]
    cadobjects_object_setdatum $canv $objid "START" $start
    cadobjects_object_setdatum $canv $objid "EXTENT" $extent
}



proc plugin_arctan_decompose {canv objid coords allowed} {
    foreach {cpx1 cpy1 cpx2 cpy2 cpx3 cpy3} $coords break
    set isline    [cadobjects_object_getdatum $canv $objid "ISLINE"]
    set boxcoords [cadobjects_object_getdatum $canv $objid "BOX"]
    set start     [cadobjects_object_getdatum $canv $objid "START"]
    set extent    [cadobjects_object_getdatum $canv $objid "EXTENT"]

    if {!$isline} {
        foreach {x0 y0 x1 y1} $boxcoords break
        set cx [expr {($x0+$x1)/2.0}]
        set cy [expr {($y0+$y1)/2.0}]
        set radius [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    }

    if {$isline} {
        if {"LINES" in $allowed} {
            return [list LINES [list $cpx1 $cpy1 $cpx3 $cpy3]]
        }
    } elseif {"ARC" in $allowed} {
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
            } else {
                return ""
            }
        }
        return [list ARC [list $cx $cy $radius $start $extent]]
    } elseif {"ROTARC" in $allowed} {
        return [list ARC [list $cx $cy $radius $radius $start $extent 0.0]]
    } elseif {"BEZIER" in $allowed && !$isline} {
        set arcpath {}
        bezutil_append_bezier_arc arcpath $cx $cy $radius $radius $start $extent
        return [list BEZIER $arcpath]
    } elseif {"LINES" in $allowed} {
        set arcpath {}
        bezutil_append_line_arc arcpath $cx $cy $radius $radius $start $extent
        return [list LINES $arcpath]
    }
    return {}
}


proc plugin_arctan_pointsofinterest {canv objid coords nearx neary} {
    foreach {cx0 cy0 cx1 cy1 cx2 cy2} $coords break
    constants pi
    set isline [cadobjects_object_getdatum $canv $objid "ISLINE"]

    set poi {}
    lappend poi "controlpoints" $cx0  $cy0  "Start Point"    1
    lappend poi "controlpoints" $cx1  $cy1  "Control Point"  2
    lappend poi "controlpoints" $cx2  $cy2  "End Point"      3
    if {$isline} {
        return $poi
    }

    set ang1 [cadobjects_object_getdatum $canv $objid "START"]
    set ang2 [cadobjects_object_getdatum $canv $objid "EXTENT"]
    set boxcoords [cadobjects_object_getdatum $canv $objid "BOX"]
    foreach {x0 y0 x1 y1} $boxcoords break

    set cx [expr {($x0+$x1)/2.0}]
    set cy [expr {($y0+$y1)/2.0}]
    set arcrad [expr {hypot($cy0-$cy,$cx0-$cx)}]

    set arcang [expr {atan2($neary-$cy,$nearx-$cx)}]
    set ang1 [expr {$ang1*$pi/180.0}]
    set ang2 [expr {$ang1+$ang2*$pi/180.0}]
    if {$ang1 < 0.0} {
        set ang1 [expr {$ang1+$pi*2.0}]
    }
    while {$ang2 < $ang1} {
        set ang2 [expr {$ang2+$pi*2.0}]
    }
    while {$arcang < $ang1} {
        set arcang [expr {$arcang+$pi*2.0}]
    }
    if {$arcang <= $ang2} {
        set ax [expr {$arcrad*cos($arcang)+$cx}]
        set ay [expr {$arcrad*sin($arcang)+$cy}]
        lappend poi "contours" $ax $ay "On Arc" -1
    }

    set prevpt [cadobjects_get_prev_point $canv]
    if {$prevpt != ""} {
        foreach {ox oy} $prevpt break
        cadobjects_calculate_tangent_pois poi $cx $cy $arcrad $ox $oy $ang1 $ang2
    }

    return $poi
}


proc plugin_arctan_partial_position {canv objid coords part} {
    set isline [cadobjects_object_getdatum $canv $objid "ISLINE"]
    set start [cadobjects_object_getdatum $canv $objid "START"]
    set extent [cadobjects_object_getdatum $canv $objid "EXTENT"]
    set boxcoords [cadobjects_object_getdatum $canv $objid "BOX"]
    foreach {x0 y0 x1 y1} $boxcoords break
    set cx [expr {($x0+$x1)/2.0}]
    set cy [expr {($y0+$y1)/2.0}]
    set arcrad [expr {abs($y0-$cy)}]

    constants degtorad pi
    set start [expr {$start*$degtorad}]
    set extent [expr {$extent*$degtorad}]

    set ang [expr {$start+$extent*$part}]
    set pang [expr {$ang+$pi/2.0}]
    set x [expr {$arcrad*cos($ang)+$cx}]
    set y [expr {$arcrad*sin($ang)+$cy}]
    return [list $x $y $pang]
}


proc plugin_arctan_length {canv objid coords} {
    constants degtorad
    set extent [cadobjects_object_getdatum $canv $objid "EXTENT"]
    set boxcoords [cadobjects_object_getdatum $canv $objid "BOX"]
    foreach {x0 y0 x1 y1} $boxcoords break
    set cx [expr {($x0+$x1)/2.0}]
    set cy [expr {($y0+$y1)/2.0}]
    set arcrad [expr {abs($y0-$cy)}]
    set len [expr {$arcrad*$extent*$degtorad}]
    return $len
}


proc plugin_arctan_bbox {canv objid coords} {
    constants degtorad radtodeg
    foreach {cx0 cy0 cx1 cy1 cx2 cy2} $coords break
    set start [cadobjects_object_getdatum $canv $objid "START"]
    set extent [cadobjects_object_getdatum $canv $objid "EXTENT"]
    set boxcoords [cadobjects_object_getdatum $canv $objid "BOX"]
    foreach {x0 y0 x1 y1} $boxcoords break
    set cx [expr {($x0+$x1)/2.0}]
    set cy [expr {($y0+$y1)/2.0}]
    set radius [expr {abs($y0-$cy)}]
    set endang [expr {$start+$extent}]

    set minx $cx0
    set maxx $cx0
    set miny $cy0
    set maxy $cy0
    set ang [expr {ceil($start/90.0)*90.0}]
    if {$extent > 0.0} {
        for {} {$ang < $start+$extent} {set ang [expr {$ang+90.0}]} {
            set px [expr {$radius*cos($ang*$degtorad)+$cx}]
            set py [expr {$radius*sin($ang*$degtorad)+$cy}]
            set minx [expr {min($minx,$px)}]
            set maxx [expr {max($maxx,$px)}]
            set miny [expr {min($miny,$py)}]
            set maxy [expr {max($maxy,$py)}]
        }
    } else {
        for {} {$ang > $start+$extent} {set ang [expr {$ang-90.0}]} {
            set px [expr {$radius*cos($ang*$degtorad)+$cx}]
            set py [expr {$radius*sin($ang*$degtorad)+$cy}]
            set minx [expr {min($minx,$px)}]
            set maxx [expr {max($maxx,$px)}]
            set miny [expr {min($miny,$py)}]
            set maxy [expr {max($maxy,$py)}]
        }
    }
    set px $cx2
    set py $cy2
    set minx [expr {min($minx,$px)}]
    set maxx [expr {max($maxx,$px)}]
    set miny [expr {min($miny,$py)}]
    set maxy [expr {max($maxy,$py)}]

    return [list $minx $miny $maxx $maxy]
}







proc plugin_arcs_register {} {
    tool_register_ex ARCCTR "&Arcs" "Arc by &Center Point" {
        {1    "Centerpoint"}
        {2    "Starting Point"}
        {3    "Ending Point"}
    } -icon "tool-arcctr" -creator
    tool_register_ex ARC3PT "&Arcs" "Arc by 3 &Points" {
        {1    "First Arc Point"}
        {3    "Middle Arc Point"}
        {2    "End Arc Point"}
    } -icon "tool-arc3pt-123" -creator
    tool_register_ex ARC3PT "&Arcs" "Arc by 3 Points, &Middle Last" {
        {1    "First Arc Point"}
        {2    "End Arc Point"}
        {3    "Middle Arc Point"}
    } -icon "tool-arc3pt-132" -creator
    tool_register_ex ARCTAN "&Arcs" "Arc by &Tangent" {
        {1    "Starting Point"}
        {2    "Tangent Line Point"}
        {3    "Ending Point"}
    } -icon "tool-arctan" -creator
}
plugin_arcs_register


# vim: set ts=4 sw=4 nowrap expandtab: settings

