proc plugin_line_editfields {canv objid coords} {
    set out {}
    lappend out {
        type OPTIONS
        pane CAM
        name CUTSIDE
        title "Cut Side"
        width 8
        values {"On Line" center "Left" left "Right" right "Inside" inside "Outside" outside}
        default center
    }
    lappend out {
        type POINTS
        name POINT%d
        datum #%d
        title "Point %d"
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
        valgetcb "plugin_line_getfield"
        valsetcb "plugin_line_setfield"
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
        valgetcb "plugin_line_getfield"
        valsetcb "plugin_line_setfield"
    }
    return $out
}


proc plugin_line_getfield {canv objid coords field} {
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


proc plugin_line_setfield {canv objid coords field val} {
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


proc plugin_line_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set maxcp [expr {[llength $coords]/2}]
    set cpnum 1
    foreach {cpx cpy} $coords {
        if {$cpnum == 1 || $cpnum >= $maxcp} {
            cadobjects_object_draw_controlpoint $canv $objid LINE $cpx $cpy $cpnum "endnode" $color $fillcolor
        } else {
            cadobjects_object_draw_controlpoint $canv $objid LINE $cpx $cpy $cpnum "rectangle" $color $fillcolor
        }
        incr cpnum
    }

    set pi 3.141592653589793236
    set showdir [/prefs:get show_direction]
    if {$showdir == 1} {
        set ox [lindex $coords 0]
        set oy [lindex $coords 1]
        set cpnum 1
        foreach {px py} [lrange $coords 2 end] {
            if {$px != $ox || $py != $oy} {
                set rang [expr {$pi+atan2($py-$oy,$px-$ox)}]
                set dist [expr {hypot($py-$oy,$px-$ox)}]
                set rad 10.0
                set arrowang [expr {$pi/8.0}]
                if {$rad > $dist*0.75} {
                    set rad [expr {$dist*0.75}]
                }
                set x0 [expr {$rad*cos($rang+$arrowang)+$px}]
                set y0 [expr {$rad*sin($rang+$arrowang)+$py}]
                set x1 [expr {$rad*cos($rang-$arrowang)+$px}]
                set y1 [expr {$rad*sin($rang-$arrowang)+$py}]
                set ox $px
                set oy $py
                cadobjects_object_draw_control_line $canv $objid $x0 $y0 $px $py $cpnum $color
                cadobjects_object_draw_control_line $canv $objid $x1 $y1 $px $py $cpnum $color
            }
            incr cpnum
        }
    }
}


proc plugin_line_drawobj {canv objid coords tags color fill width dash} {
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_line_recalculate {canv objid coords {flags ""}} {
    # Nothing to do.  The control points are all the data needed.
}


proc plugin_line_bbox {canv objid coords} {
    return [::math::geometry::bbox $coords]
}


proc plugin_line_pointsofinterest {canv objid coords nearx neary} {
    set poi {}
    set nodenum 0
    foreach {x y} $coords {
        lappend poi "controlpoints" $x $y "Endpoint" [incr nodenum]
    }
    foreach {x0 y0} [lrange $coords 0 end-2] {x1 y1} [lrange $coords 2 end] {
        set mx [expr {($x0+$x1)/2.0}]
        set my [expr {($y0+$y1)/2.0}]
        lappend poi "midpoints" $mx $my "Midpoint" -1
    }
    cadobjects_object_polyline_pois poi "contours" "On Line" $coords $nearx $neary
    return $poi
}


proc plugin_line_decompose {canv objid coords allowed} {
    if {"LINES" in $allowed} {
        if {"GCODE" in $allowed} {
            set cutbit  [cadobjects_object_cutbit $canv $objid]
            set cutside [cadobjects_object_getdatum $canv $objid "CUTSIDE"]
            set cutdiam [mlcnc_tooldiam $cutbit]
            set cutrad [expr {abs($cutdiam/2.0)}]
            set out {}
            if {$cutbit > 0} {
                if {$cutside == "right"} {
                    foreach pline [mlcnc_path_offset $coords $cutrad] {
                        lappend out LINES $pline
                    }
                } elseif {$cutside == "left"} {
                    foreach pline [mlcnc_path_offset $coords -$cutrad] {
                        lappend out LINES $pline
                    }
                } elseif {$cutside == "inside"} {
                    foreach pline [mlcnc_path_inset $coords $cutrad] {
                        lappend out LINES $pline
                    }
                } elseif {$cutside == "outside"} {
                    foreach pline [mlcnc_path_inset $coords -$cutrad] {
                        lappend out LINES $pline
                    }
                } else {
                    lappend out LINES $coords
                }
            }
            return $out
        }
        return [list LINES $coords]
    } elseif {"BEZIER" in $allowed} {
        set coords [bezutil_bezier_from_line $coords]
        return [list BEZIER $coords]
    }
    # TODO: Add tertiary fallback QUADBEZIER support
    return {}
}


proc plugin_line_addnode {canv objid coords x y} {
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set scalemult [expr {$dpi*$scalefactor}]
    set closeenough [expr {[$canv cget -closeenough]/$scalemult}]

    set outcoords {}
    foreach {x0 y0} [lrange $coords 0 1] break
    lappend outcoords $x0 $y0
    foreach {x1 y1} [lrange $coords 2 end] {
        set dist1 [expr {hypot($y-$y0,$x-$x0)}]
        set dist2 [expr {hypot($y0-$y1,$x0-$x1)}]
        if {$dist2 > 1e-6} {
            set t [expr {$dist1/$dist2}]
            if {$t > 1.0} {
                set t 1.0
            } elseif {$t < 0.0} {
                set t 0.0
            }
        } else {
            set t 1.0
        }
        set px [expr {($x1-$x0)*$t+$x0}]
        set py [expr {($y1-$y0)*$t+$y0}]
        set dist3 [expr {hypot($y-$py,$x-$px)}]
        if {abs($dist3) < $closeenough} {
            lappend outcoords $px $py
        }
        lappend outcoords $x1 $y1
        set x0 $x1
        set y0 $y1
    }

    cadobjects_object_set_coords $canv $objid $outcoords
    cadobjects_object_recalculate $canv $objid
    cadobjects_object_draw $canv $objid
    cadobjects_object_draw_controls $canv $objid red

    return 1 ;# We did everything we needed to.  Tell caller we're done.
}


proc plugin_line_partial_position {canv objid coords part} {
    constants pi
    set coordslen [expr {[length $coords]/2}]
    set segnum [expr {int($coordslen*$part)}]
    set part [expr {$coordslen*$part-$segnm}]
    set pos1 [expr {$segnum*2}] 
    set pos2 [expr {$pos1+3}]
    foreach {x0 y0 x1 y1} [lrange $coords $pos1 $pos2] break
    set dx [expr {$x1-$x0}]
    set dy [expr {$y1-$y0}]
    set px [expr {$x0+$dx*$part}]
    set py [expr {$y0+$dy*$part}]
    set ang [expr {atan2($dy,$dx)*180.0/$pi}]
    return [list $px $py $ang]
}


proc plugin_line_sliceobj {canv objid coords x y} {
    set closeenough [cadobjects_get_closeenough $canv $objid]
    set polylines [bezutil_polyline_break_near $x $y $coords $closeenough]
    if {[llength $polylines] < 2} {
        return [list $objid]
    }
    lassign $polylines coords1 coords2
    cadobjects_object_set_coords $canv $objid $coords1
    set nuobj [cadobjects_object_create $canv LINE $coords2 {}]
    return [list $objid $nuobj]
}


proc plugin_line_nearest_point {canv objid coords x y} {
    set pt [list $x $y]
    set min_d 1e99
    set min_ln {}
    set min_seg -1
    set seg 0
    foreach {x0 y0} $coords break
    foreach {x1 y1} [lrange $coords 2 end] {
        set ln [list $x0 $y0 $x1 $y1]
        set d [::math::geometry::calculateDistanceToLineSegment $pt $ln]
        if {$d < $min_d} {
            set min_d $d
            set min_ln $ln
            set min_seg $seg
        }
        set x0 $x1
        set y0 $y1
        incr seg
    }
    set nupt [::math::geometry::findClosestPointOnLineSegment $pt $min_ln]
    return $nupt
}






proc plugin_linemp_drawobj {canv objid coords tags fill color width dash} {
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_linemp_editfields {canv objid coords} {
    set out {}
    lappend out {
        type POINT
        name MIDPOINT
        datum #1
        title "Midpoint"
    }
    lappend out {
        type POINT
        name END
        datum #0
        title "End pt"
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
        valgetcb "plugin_linemp_getfield"
        valsetcb "plugin_linemp_setfield"
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
        valgetcb "plugin_linemp_getfield"
        valsetcb "plugin_linemp_setfield"
    }
    return $out
}


proc plugin_linemp_getfield {canv objid coords field} {
    constants pi
    foreach {cx0 cy0 cx1 cy1} $coords break
    switch -exact -- $field {
        LENGTH {
            set d [expr {hypot($cy1-$cy0,$cx1-$cx0)*2.0}]
            return $d
        }
        ANGLE {
            set d [expr {atan2($cy1-$cy0,$cx1-$cx0)*180.0/$pi}]
            return $d
        }
    }
}


proc plugin_linemp_setfield {canv objid coords field val} {
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
                set d [expr {($val/2.0)/$dist}]
            }
            set cx1 [expr {($cx1-$cx0)*$d+$cx0}]
            set cy1 [expr {($cy1-$cy0)*$d+$cy0}]
            set coords [list $cx0 $cy0 $cx1 $cy1]
            cadobjects_object_set_coords $canv $objid $coords
        }
    }
}


proc plugin_linemp_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid LINEMP $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_linemp_recalculate {canv objid coords {flags ""}} {
    # Nothing to do.  The control points are all the data needed.
}


proc plugin_linemp_bbox {canv objid coords} {
    foreach {x1 y1 x2 y2} $coords break
    set x3 [expr {($x2-$x1)*2.0+$x1}]
    set y3 [expr {($y2-$y1)*2.0+$y1}]
    set minx [expr {min($x3,$x1)}]
    set miny [expr {min($y3,$y1)}]
    set maxx [expr {max($x3,$x1)}]
    set maxy [expr {max($y3,$y1)}]
    return [list $minx $miny $maxx $maxy]
}


proc plugin_linemp_pointsofinterest {canv objid coords nearx neary} {
    foreach {x1 y1 x2 y2} $coords break
    set x3 [expr {($x2-$x1)*2.0+$x1}]
    set y3 [expr {($y2-$y1)*2.0+$y1}]

    set poi {}
    lappend poi "controlpoints" $x1 $y1 "Endpoint" 1
    lappend poi "midpoints"     $x2 $y2 "Midpoint" 2
    lappend poi "controlpoints" $x3 $y3 "Endpoint" -1
    cadobjects_object_polyline_pois poi "contours" "On Line" [list $x1 $y1 $x3 $y3]  $nearx $neary
    return $poi
}


proc plugin_linemp_decompose {canv objid coords allowed} {
    foreach {x1 y1 x2 y2} $coords break
    set x3 [expr {($x2-$x1)*2.0+$x1}]
    set y3 [expr {($y2-$y1)*2.0+$y1}]

    if {"LINES" in $allowed} {
        return [list LINES [list $x1 $y1 $x3 $y3]]
    } elseif {"BEZIER" in $allowed} {
        set linepath [list $x1 $y1 $x3 $y3]
        set path [bezutil_bezier_from_line $linepath]
        return [list BEZIER $path]
    }
    # TODO: Add tertiary fallback QUADBEZIER support
    return {}
}


proc plugin_linemp_partial_position {canv objid coords part} {
    constants pi
    foreach {x1 y1 x2 y2} $coords break
    set x3 [expr {($x2-$x1)*2.0+$x1}]
    set y3 [expr {($y2-$y1)*2.0+$y1}]
    set dx [expr {$x2-$x3}]
    set dy [expr {$y2-$y3}]
    set px [expr {$x3+$dx*$part}]
    set py [expr {$y3+$dy*$part}]
    set ang [expr {atan2($dy,$dx)*180.0/$pi}]
    return [list $px $py $ang]
}


proc plugin_linemp_sliceobj {canv objid coords x y} {
    foreach {x1 y1 x2 y2} $coords break
    set x3 [expr {($x2-$x1)*2.0+$x1}]
    set y3 [expr {($y2-$y1)*2.0+$y1}]
    set coords [list $x1 $y1 $x3 $y3]
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid LINE
    return [plugin_line_sliceobj $canv $objid $coords $x $y]
}


proc plugin_linemp_nearest_point {canv objid coords x y} {
    set pt [list $x $y]
    foreach {x1 y1 x2 y2} $coords break
    set x3 [expr {($x2-$x1)*2.0+$x1}]
    set y3 [expr {($y2-$y1)*2.0+$y1}]
    set coords [list $x1 $y1 $x3 $y3]
    set nupt [::math::geometry::findClosestPointOnLineSegment $pt $coords]
    return $nupt
}


proc plugin_linemp_bbox {canv objid coords} {
    foreach {x1 y1 x2 y2} $coords break
    set x3 [expr {($x2-$x1)*2.0+$x1}]
    set y3 [expr {($y2-$y1)*2.0+$y1}]
    set coords [list $x1 $y1 $x3 $y3]
    return [geometry_pointlist_bbox $coords]
}








proc plugin_line_smooth_selected {canv {tolerance 1e-2}} {
    set converts 0
    set sellist [cadselect_list $canv]
    foreach objid $sellist {
        set type [cadobjects_object_gettype $canv $objid]
        if {$type == "BEZIER"} {
            set coords [cadobjects_object_get_coords $canv $objid]
            set coords [bezutil_bezier_smooth $coords $tolerance]
            cadobjects_object_set_coords $canv $objid $coords
            cadobjects_object_setdatum $canv $objid "NODETYPES" ""
            cadobjects_object_recalculate $canv $objid
            incr converts
        } elseif {$type == "LINE"} {
            set coords [cadobjects_object_get_coords $canv $objid]
            set coords [bezutil_bezier_from_line $coords]
            set coords [bezutil_bezier_smooth $coords $tolerance]
            cadobjects_object_set_coords $canv $objid $coords
            cadobjects_object_settype $canv $objid "BEZIER"
            cadobjects_object_setdatum $canv $objid "NODETYPES" ""
            cadobjects_object_recalculate $canv $objid
            incr converts
        }
    }
    cadobjects_redraw $canv
}


proc plugin_line_simplify_selected {canv {tolerance 1e-4}} {
    set converts 0
    set sellist [cadselect_list $canv]
    foreach objid $sellist {
        set type [cadobjects_object_gettype $canv $objid]
        if {$type == "BEZIER"} {
            set coords [cadobjects_object_get_coords $canv $objid]
            set coords [bezutil_bezier_simplify $coords $tolerance]
            #set coords [bezutil_bezier_smooth $coords $tolerance]
            #set coords [bezutil_bezier_simplify $coords $tolerance]
            cadobjects_object_set_coords $canv $objid $coords
            cadobjects_object_setdatum $canv $objid "NODETYPES" ""
            cadobjects_object_recalculate $canv $objid
            incr converts
        } elseif {$type == "BEZIERQUAD"} {
            set coords [cadobjects_object_get_coords $canv $objid]
            set coords [bezutil_quadbezier_simplify $coords $tolerance]
            cadobjects_object_set_coords $canv $objid $coords
            cadobjects_object_recalculate $canv $objid
            incr converts
        } elseif {$type == "LINE"} {
            set coords [cadobjects_object_get_coords $canv $objid]
            set coords [bezutil_bezier_from_line $coords]
            set coords [bezutil_bezier_smooth $coords $tolerance]
            set coords [bezutil_bezier_simplify $coords $tolerance]
            cadobjects_object_set_coords $canv $objid $coords
            cadobjects_object_settype $canv $objid "BEZIER"
            cadobjects_object_setdatum $canv $objid "NODETYPES" ""
            cadobjects_object_recalculate $canv $objid
            incr converts
        }
    }
    cadobjects_redraw $canv
}



proc plugin_line_union_selected {canv} {
    return [plugin_line_boolean_selected $canv "union"]
}



proc plugin_line_diff_selected {canv} {
    return [plugin_line_boolean_selected $canv "diff"]
}



proc plugin_line_intersect_selected {canv} {
    return [plugin_line_boolean_selected $canv "intersect"]
}



proc plugin_line_boolean_selected {canv oper} {
    set converts 0
    set sellist [cadobjects_topmost_objects $canv "SELECTED"]
    cadselect_clear $canv
    set usedobjs {}
    set objpaths {}
    foreach topobjid $sellist {
        set currpaths {}
        foreach objid [cadobjects_grouped_objects $canv [list $topobjid]] {
            set decdata [cadobjects_object_decompose $canv $objid {LINES}]
            if {$decdata == ""} {
                continue
            }
            foreach {dectype coords} $decdata {
                if {[llength $coords] < 4} continue
                lappend currpaths $coords
            }
        }
        if {[llength $currpaths] > 0} {
            if {[llength $objpaths] == 0} {
                set objpaths $currpaths
            } else {
                set objpaths [geometry_polygons_boolean_operation $objpaths $currpaths $oper]
            }
            lappend usedobjs $objid
        }
    }
    foreach objid $usedobjs {
        cadobjects_object_delete $canv $objid
    }
    foreach path $objpaths {
        set newobj [cadobjects_object_create $canv LINE $path {}]
        cadobjects_object_recalculate $canv $newobj
        cadselect_add $canv $newobj
    }
    cadobjects_redraw $canv
}



proc plugin_line_lineize_selected {canv} {
    set converts 0
    set sellist [cadselect_list $canv]
    cadselect_clear $canv
    foreach objid $sellist {
        set decdata [cadobjects_object_decompose $canv $objid {LINES}]
        if {$decdata == ""} {
            continue
        }
        foreach {dectype coords} [lrange $decdata 0 1] break
        cadobjects_object_settype $canv $objid "LINE"
        cadobjects_object_setdatum $canv $objid "NODETYPES" ""
        cadobjects_object_set_coords $canv $objid $coords
        cadobjects_object_recalculate $canv $objid
        cadselect_add $canv $objid
        foreach {dectype coords} [lrange $decdata 2 end] {
            set newobj [cadobjects_object_create $canv LINE $coords {}]
            cadobjects_object_recalculate $canv $newobj
            cadselect_add $canv $newobj
        }
        incr converts
    }
    cadobjects_redraw $canv
}


proc plugin_line_bezierize_selected {canv} {
    set converts 0
    set sellist [cadselect_list $canv]
    cadselect_clear $canv
    foreach objid $sellist {
        set decdata [cadobjects_object_decompose $canv $objid {BEZIER}]
        if {$decdata == ""} {
            continue
        }
        foreach {dectype coords} [lrange $decdata 0 1] break
        cadobjects_object_settype $canv $objid "BEZIER"
        cadobjects_object_setdatum $canv $objid "NODETYPES" ""
        cadobjects_object_set_coords $canv $objid $coords
        cadobjects_object_recalculate $canv $objid
        cadselect_add $canv $objid
        foreach {dectype coords} [lrange $decdata 2 end] {
            set newobj [cadobjects_object_create $canv BEZIER $coords {}]
            cadobjects_object_recalculate $canv $newobj
            cadselect_add $canv $newobj
        }
        incr converts
    }
    cadobjects_redraw $canv
}


proc plugin_line_join_selected {canv {tolerance 1e-3}} {
    set joins 0
    set prevjoins $joins
    while {1} {
        set sellist [cadselect_list $canv]
        while {[llength $sellist] > 1} {
            set objid [lindex $sellist 0]
            set type [cadobjects_object_gettype $canv $objid]
            if {$type == "LINE"} {
                set coords [cadobjects_object_get_coords $canv $objid]
            } else {
                foreach {dectype coords} [cadobjects_object_decompose $canv $objid {BEZIER}] break
                set type "BEZIER"
            }
            set x0 [lindex $coords 0]
            set y0 [lindex $coords 1]

            set x1 [lindex $coords end-1]
            set y1 [lindex $coords end]

            foreach {sx0 sy0 sx1 sy1} [cadobjects_scale_coords $canv [list $x0 $y0 $x1 $y1]] break

            set foundlink 0
            set prelimset1 [cadobjects_get_objids_near $canv $sx0 $sy0 0.5]
            foreach objid2 $prelimset1 {
                if {$objid2 == $objid || $objid2 == ""} {
                    continue
                }
                if {[cadselect_ismember $canv $objid2]} {
                    set type2 [cadobjects_object_gettype $canv $objid2]
                    if {$type2 == "LINE"} {
                        set coords2 [cadobjects_object_get_coords $canv $objid2]
                        set outtype "LINE"
                        if {$type == "BEZIER"} {
                            set coords2 [bezutil_bezier_from_line $coords2]
                            set outtype "BEZIER"
                        }
                    } else {
                        foreach {dectype coords2} [cadobjects_object_decompose $canv $objid2 {BEZIER}] break
                        set outtype "BEZIER"
                        if {$type == "LINE"} {
                            set coords [bezutil_bezier_from_line $coords]
                        }
                    }
                    if {hypot([lindex $coords2 0]-$x0,[lindex $coords2 1]-$y0) < $tolerance} {
                        set coords2 [concat [line_coords_reverse $coords2] [lrange $coords 2 end]]
                        cadobjects_object_settype $canv $objid2 $outtype
                        cadobjects_object_setdatum $canv $objid2 "NODETYPES" ""
                        cadobjects_object_set_coords $canv $objid2 $coords2
                        cadobjects_object_recalculate $canv $objid2
                        cadobjects_object_delete $canv $objid
                        set sellist [lrange $sellist 1 end]
                        incr joins
                        set foundlink 1
                        break
                    } elseif {hypot([lindex $coords2 end-1]-$x0,[lindex $coords2 end]-$y0) < $tolerance} {
                        set coords2 [concat $coords2 [lrange $coords 2 end]]
                        cadobjects_object_settype $canv $objid2 $outtype
                        cadobjects_object_setdatum $canv $objid2 "NODETYPES" ""
                        cadobjects_object_set_coords $canv $objid2 $coords2
                        cadobjects_object_recalculate $canv $objid2
                        cadobjects_object_delete $canv $objid
                        set sellist [lrange $sellist 1 end]
                        incr joins
                        set foundlink 1
                        break
                    }
                }
            }
            if {$foundlink} {
                continue
            }

            set foundlink 0
            set prelimset2 [cadobjects_get_objids_near $canv $sx1 $sy1 1.0]
            foreach objid2 $prelimset2 {
                if {$objid2 == $objid || $objid2 == ""} {
                    continue
                }
                if {[cadselect_ismember $canv $objid2]} {
                    set type2 [cadobjects_object_gettype $canv $objid2]
                    if {$type2 == "LINE"} {
                        set coords2 [cadobjects_object_get_coords $canv $objid2]
                        set outtype "LINE"
                        if {$type == "BEZIER"} {
                            set coords2 [bezutil_bezier_from_line $coords2]
                            set outtype "BEZIER"
                        }
                    } else {
                        foreach {dectype coords2} [cadobjects_object_decompose $canv $objid2 {BEZIER}] break
                        set outtype "BEZIER"
                        if {$type == "LINE"} {
                            set coords [bezutil_bezier_from_line $coords]
                        }
                    }
                    if {hypot([lindex $coords2 0]-$x1,[lindex $coords2 1]-$y1) < $tolerance} {
                        set coords2 [concat $coords [lrange $coords2 2 end]]
                        cadobjects_object_settype $canv $objid2 $outtype
                        cadobjects_object_setdatum $canv $objid2 "NODETYPES" ""
                        cadobjects_object_set_coords $canv $objid2 $coords2
                        cadobjects_object_recalculate $canv $objid2
                        cadobjects_object_delete $canv $objid
                        set sellist [lrange $sellist 1 end]
                        incr joins
                        set foundlink 1
                        break
                    } elseif {hypot([lindex $coords2 end-1]-$x1,[lindex $coords2 end]-$y1) < $tolerance} {
                        set coords2 [concat $coords [lrange [line_coords_reverse $coords2] 2 end]]
                        cadobjects_object_settype $canv $objid2 $outtype
                        cadobjects_object_setdatum $canv $objid2 "NODETYPES" ""
                        cadobjects_object_set_coords $canv $objid2 $coords2
                        cadobjects_object_recalculate $canv $objid2
                        cadobjects_object_delete $canv $objid
                        set sellist [lrange $sellist 1 end]
                        incr joins
                        set foundlink 1
                        break
                    }
                }
            }

            if {$foundlink} {
                continue
            }
            set sellist [lrange $sellist 1 end]
        }
        if {$joins == $prevjoins} {
            break
        }
        set prevjoins $joins
        cadobjects_redraw $canv
    }
    if {$joins == 0} {
        bell
    }
    #tk_messageBox -parent [winfo toplevel $canv] -icon info -type ok -message "$joins joins performed."
}





proc plugin_line_register {} {
    tool_register_ex LINE "&Lines" "&Single Line" {
        {1    "First Point"}
        {2    "Next Point"}
    } -icon "tool-line" -creator
    tool_register_ex LINE "&Lines" "&Lines" {
        {1    "First Point"}
        {2    "Next Point"}
        {...  ""}
    } -icon "tool-lines" -creator
    tool_register_ex LINEMP "&Lines" "&Midpoint Line" {
        {2    "Midpoint"}
        {1    "Endpoint"}
    } -icon "tool-linemp" -creator
    tool_register_ex LINEMP "&Lines" "Midpoint Line, &End First" {
        {1    "Endpoint"}
        {2    "Midpoint"}
    } -icon "tool-linemp21" -creator
}
plugin_line_register 

# vim: set ts=4 sw=4 nowrap expandtab: settings

