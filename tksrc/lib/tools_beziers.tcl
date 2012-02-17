proc plugin_bezierquad_editfields {canv objid coords} {
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
        type LABEL
        name RO_LENGTH
        datum ""
        title "Length"
        valgetcb "plugin_bezierquad_getfield"
    }
    lappend out {
        type POINTS
        name POINT%d
        datum #%d
        title "Point %d"
    }
    return $out
}



proc plugin_bezierquad_getfield {canv objid coords field} {
    switch -exact -- $field {
        RO_LENGTH {
            set totlen [bezutil_quadbezier_length $coords]
            return [format "%.4f" $totlen]
        }
    }
    return ""
}



proc plugin_bezierquad_drawobj {canv objid coords tags color fill width dash} {
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_bezierquad_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set maxcp [expr {[llength $coords]/2}]
    set cpnum 1
    set cpnode 1
    foreach {cpx cpy} $coords {
        switch -exact -- $cpnode {
            1 {
                set x0 $cpx
                set y0 $cpy
                if {$cpnum == 1 || $cpnum == $maxcp} {
                    set cptype endnode
                } else {
                    set cptype rectangle
                }
                incr cpnode
            }
            2 {
                cadobjects_object_draw_control_line $canv $objid $x0 $y0 $cpx $cpy 1 $color [dashpat construction]
                set x0 $cpx
                set y0 $cpy
                set cptype oval
                incr cpnode
            }
            3 {
                cadobjects_object_draw_control_line $canv $objid $cpx $cpy $x0 $y0 2 $color [dashpat construction]
                set x0 $cpx
                set y0 $cpy
                set cpnode 2
                set cptype rectangle
            }
        }
        cadobjects_object_draw_controlpoint $canv $objid BEZIERQUAD $cpx $cpy $cpnum $cptype $color $fillcolor
        incr cpnum
    }

    set pi 3.141592653589793236
    set showdir [/prefs:get show_direction]
    if {$showdir == 1} {
        set cpnum 1
        set ox [lindex $coords 0]
        set oy [lindex $coords 1]
        foreach {cpx cpy px py} [lrange $coords 2 end] {
            if {$px == "" || $py == ""} {
                break;
            }
            if {$px != $cpx || $py != $cpy} {
                set ox $cpx
                set oy $cpy
            }
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


proc plugin_bezierquad_recalculate {canv objid coords {flags ""}} {
    # Nothing to do.  The control points are all the data needed.
}


proc plugin_bezierquad_decompose {canv objid coords allowed} {
    set bezcoords {}
    foreach {x0 y0} [lrange $coords 0 1] break
    lappend bezcoords $x0 $y0
    foreach {cpx cpy x3 y3} [lrange $coords 2 end] {
        set x1 [expr {($x0+2.0*$cpx)/3.0}]
        set y1 [expr {($y0+2.0*$cpy)/3.0}]
        set x2 [expr {($x3+2.0*$cpx)/3.0}]
        set y2 [expr {($y3+2.0*$cpy)/3.0}]
        lappend bezcoords $x1 $y1 $x2 $y2 $x3 $y3
        set x0 $x3
        set y0 $y3
    }

    if {"GCODE" in $allowed && "LINES" in $allowed} {
        set cutbit  [cadobjects_object_cutbit $canv $objid]
        set cutside [cadobjects_object_getdatum $canv $objid "CUTSIDE"]
        set cutdiam [mlcnc_tooldiam $cutbit]
        set cutrad [expr {abs($cutdiam/2.0)}]
        set linepath {}
        bezutil_append_line_from_bezier linepath $bezcoords
        set out {}
        if {$cutbit > 0} {
            if {$cutside == "right"} {
                foreach pline [mlcnc_path_offset $linepath $cutrad] {
                    lappend out LINES $pline
                }
            } elseif {$cutside == "left"} {
                foreach pline [mlcnc_path_offset $linepath -$cutrad] {
                    lappend out LINES $pline
                }
            } elseif {$cutside == "inside"} {
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
    } elseif {"QUADBEZ" in $allowed} {
        return [list QUADBEZ $coords]
    } elseif {"BEZIER" in $allowed} {
        return [list BEZIER $bezcoords]
    } elseif {"LINES" in $allowed} {
        set linepath {}
        bezutil_append_line_from_bezier linepath $bezcoords
        return [list LINES $linepath]
    }
    return {}
}


proc plugin_bezierquad_deletenodes {canv objid coords nodes} {

    foreach node [lsort -decreasing -integer $nodes] {
        if {$node == 1} {
            set coords [lrange $coords 4 end]
        } elseif {$node % 2 != 0} {
            set pos1 [expr {($node-2)*2}]
            set pos2 [expr {$pos1+3}]
            set coords [lreplace $coords $pos1 $pos2]
        }
    }

    if {[llength $coords] < 6} {
        cadobjects_object_delete $canv $objid
    } else {
        cadobjects_object_set_coords $canv $objid $coords
        cadobjects_object_recalculate $canv $objid
        cadobjects_object_draw $canv $objid
    }

    return 1 ;# We deleted everything we needed to.  Tell caller we're done.
}


proc plugin_bezierquad_addnode {canv objid coords x y} {
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set scalemult [expr {$dpi*$scalefactor}]
    set linewidth [cadobjects_object_stroke_width $canv $objid]
    set closeenough [$canv cget -closeenough]
    set closeenough [expr {$closeenough/$scalemult+$linewidth/2.0}]
    set tolerance [expr {1.0/$scalemult}]

    set coords [bezutil_quadbezier_split_near $x $y $coords $closeenough $tolerance]
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_setdatum $canv $objid "NODETYPES" ""
    cadobjects_object_recalculate $canv $objid
    cadobjects_object_draw $canv $objid
    cadobjects_object_draw_controls $canv $objid red

    return 1 ;# We did everything we needed to.  Tell caller we're done.
}


proc plugin_bezierquad_bbox {canv objid coords} {
    return [geometry_pointlist_bbox $coords]
}


proc plugin_bezierquad_partial_position {canv objid coords part} {
    set totlen [bezutil_quadbezier_length $coords]
    set destlen [expr {$totlen*$part}]
    foreach {x0 y0} [lrange $coords 0 1] break
    foreach {x1 y1 x2 y2} [lrange $coords 2 end] {
        set seglen [bezutil_quadbezier_segment_length $x0 $y0 $x1 $y1 $x2 $y2]
        if {$seglen > $destlen} {
            set destlen [expr {$destlen-$seglen}]
        } else {
            break
        }
        set x0 $x2
        set y0 $y2
    }
    return [bezutil_quadbezier_segment_partial_pos $x0 $y0 $x1 $y1 $x2 $y2 $destlen 1e-4]
}


proc plugin_bezierquad_length {canv objid coords} {
    return [bezutil_quadbezier_length $coords]
}


proc plugin_bezierquad_sliceobj {canv objid coords x y} {
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set scalemult [expr {$dpi*$scalefactor}]
    set linewidth [cadobjects_object_stroke_width $canv $objid]
    set closeenough [$canv cget -closeenough]
    set closeenough [expr {$closeenough/$scalemult+$linewidth/2.0}]
    set tolerance [expr {1.0/$scalemult}]

    set beziers [bezutil_quadbezier_break_near $x $y $coords $closeenough $tolerance]
    cadobjects_object_set_coords $canv $objid [lindex $beziers 0]
    cadobjects_object_setdatum $canv $objid "NODETYPES" ""

    set out $objid
    if {[llength $beziers] > 1} {
        set nuobj [cadobjects_object_create $canv BEZIERQUAD [lindex $beziers 1] {}]
        lappend out $nuobj
    }
    return $out
}


proc plugin_bezierquad_nearest_point {canv objid coords x y} {
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set scalemult [expr {$dpi*$scalefactor}]
    set linewidth [cadobjects_object_stroke_width $canv $objid]
    set closeenough [$canv cget -closeenough]
    set closeenough [expr {$closeenough/$scalemult+$linewidth/2.0}]
    set tolerance 1e-4
    set pt [bezutil_quadbezier_nearest_point $x $y $coords $closeenough $tolerance]
    return $pt
}







proc plugin_bezier_editfields {canv objid coords} {
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
        type LABEL
        name RO_LENGTH
        datum ""
        title "Length"
        valgetcb "plugin_bezier_getfield"
    }
    lappend out {
        type POINTS
        name POINT%d
        datum #%d
        title "Point %d"
    }
    return $out
}



proc plugin_bezier_getfield {canv objid coords field} {
    switch -exact -- $field {
        RO_LENGTH {
            set totlen [bezutil_bezier_length $coords]
            return [format "%.4f" $totlen]
        }
    }
    return ""
}



proc plugin_bezier_drawobj {canv objid coords tags color fill width dash} {
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_bezier_drawctls {canv objid coords color fillcolor} {
    plugin_bezier_regen_node_data_if_needed $canv $objid $coords
    set nodetypes [cadobjects_object_getdatum $canv $objid "NODETYPES"]
    set showcps [cadobjects_object_getdatum $canv $objid "SHOWCPS"]
    set coords [cadobjects_scale_coords $canv $coords]
    set maxcp [expr {[llength $coords]/2}]
    set cpnum 1
    set cpnode 1
    foreach {cpx cpy} $coords {
        switch -exact -- $cpnode {
            1 {
                set x0 $cpx
                set y0 $cpy
                if {$cpnum == 1} {
                    set cptype endnode
                } else {
                    set cptype diamond
                }
                cadobjects_object_draw_controlpoint $canv $objid BEZIER $cpx $cpy $cpnum $cptype $color $fillcolor
                incr cpnode
            }
            2 {
                incr cpnode
                set cptype oval
                if {$cpnum in $showcps} {
                    cadobjects_object_draw_control_line $canv $objid $x0 $y0 $cpx $cpy 1 $color {} Type_BEZIER
                    cadobjects_object_draw_controlpoint $canv $objid BEZIER $cpx $cpy $cpnum $cptype $color $fillcolor Type_BEZIER
                }
            }
            3 {
                set x0 $cpx
                set y0 $cpy
                incr cpnode
                set cptype oval
                if {$cpnum in $showcps} {
                    cadobjects_object_draw_controlpoint $canv $objid BEZIER $cpx $cpy $cpnum $cptype $color $fillcolor Type_BEZIER
                }
            }
            4 {
                if {($cpnum - 1) in $showcps} {
                    cadobjects_object_draw_control_line $canv $objid $cpx $cpy $x0 $y0 2 $color {} Type_BEZIER
                }
                set x0 $cpx
                set y0 $cpy
                set cpnode 2
                set nodetype [string index $nodetypes [expr {$cpnum/3}]]
                if {$nodetype == "D"} {
                    set cptype diamond
                } else {
                    set cptype rectangle
                }
                if {$cpnum == $maxcp} {
                    set cptype endnode
                }
                cadobjects_object_draw_controlpoint $canv $objid BEZIER $cpx $cpy $cpnum $cptype $color $fillcolor
            }
        }
        incr cpnum
    }

    set pi 3.141592653589793236
    set showdir [/prefs:get show_direction]
    if {$showdir == 1} {
        set cpnum 1
        set ox [lindex $coords 0]
        set oy [lindex $coords 1]
        foreach {cpx0 cpy0 cpx1 cpy1 px py} [lrange $coords 2 end] {
            if {$px == "" || $py == ""} {
                break;
            }
            foreach {ppx ppy} [bezutil_bezier_segment_point 0.95 $ox $oy $cpx0 $cpy0 $cpx1 $cpy1 $px $py] break
            if {$px != $ppx || $py != $ppy} {
                set rang [expr {$pi+atan2($py-$ppy,$px-$ppx)}]
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


proc plugin_bezier_clickctl {canv objid coords node} {
    set maxnode [expr {[llength $coords]/2}]

    if {[cadobjects_modkey_isdown MOD2]} {
        # MOD2-clicked node.

        if {$node <= 1 || $node >= $maxnode} {
            bell
            return
        }
        if {$node % 3 != 1} {
            bell
            return
        }
        plugin_bezier_regen_node_data_if_needed $canv $objid $coords
        set nodetypes [cadobjects_object_getdatum $canv $objid "NODETYPES"]
        set pos1 [expr {($node-2)*2}]
        set pos2 [expr {$pos1+5}]
        foreach {cpx1 cpy1 mpx mpy cpx2 cpy2} [lrange $coords $pos1 $pos2] break
        set nodetype [string index $nodetypes [expr {$node/3}]]
        switch -exact -- $nodetype {
            "C" {
                # Collinear
                set newtype "E"
                set dist1 [expr {hypot($cpy1-$mpy,$cpx1-$mpx)}]
                set dist2 [expr {hypot($cpy2-$mpy,$cpx2-$mpx)}]
                set dist  [expr {($dist1+$dist2)/2.0}]
                set ang   [expr {atan2($mpy-$cpy1,$mpx-$cpx1)}]
                set cpx1  [expr {$mpx-$dist*cos($ang)}]
                set cpy1  [expr {$mpy-$dist*sin($ang)}]
                set cpx2  [expr {$mpx+$dist*cos($ang)}]
                set cpy2  [expr {$mpy+$dist*sin($ang)}]
            }
            "D" {
                # Disjointed
                set newtype "C"
                set dx1 [expr {$mpx-$cpx1}]
                set dy1 [expr {$mpy-$cpy1}]
                set dx2 [expr {$cpx2-$mpx}]
                set dy2 [expr {$cpy2-$mpy}]
                set dist1 [expr {hypot($dy1,$dx1)}]
                set dist2 [expr {hypot($dy2,$dx2)}]
                set nvect1 [vector_normalize [list $dx1 $dy1]]
                set nvect2 [vector_normalize [list $dx2 $dy2]]
                set avevect [vector_multiply [vector_add $nvect1 $nvect2] 0.5]
                set ang [expr {atan2([lindex $avevect 1],[lindex $avevect 0])}]
                set cpx1 [expr {$mpx-$dist1*cos($ang)}]
                set cpy1 [expr {$mpy-$dist1*sin($ang)}]
                set cpx2 [expr {$mpx+$dist2*cos($ang)}]
                set cpy2 [expr {$mpy+$dist2*sin($ang)}]
            }
            "E" {
                # Equidistant
                set newtype "D"
            }
        }

        set coords [lreplace $coords $pos1 $pos2 $cpx1 $cpy1 $mpx $mpy $cpx2 $cpy2]
        cadobjects_object_set_coords $canv $objid $coords

        set pos [expr {$node/3}]
        set nodetypes [string replace $nodetypes $pos $pos $newtype]
        cadobjects_object_setdatum $canv $objid "NODETYPES" $nodetypes

        cadobjects_object_recalculate $canv $objid
        cadobjects_object_draw $canv $objid
        cadobjects_object_draw_controls $canv $objid
        cadselect_add $canv $objid
        cadselect_node_add $canv $objid $node
    }

    set snode [expr {$node-2-$node%3}]
    set enode [expr {$snode+6}]
    if {$snode < 1} {
        set snode 1
    }
    if {$enode > $maxnode} {
        set enode $maxnode
    }
    set showcps {}
    for {set i $snode} {$i <= $enode} {incr i} {
        lappend showcps $i
    }
    cadobjects_object_setdatum $canv $objid "SHOWCPS" $showcps

    set pos1 [expr {($snode-1)*2}]
    set pos2 [expr {($enode-1)*2+1}]
    set dnodes [lrange $coords $pos1 $pos2]
    set dnodes [cadobjects_scale_coords $canv $dnodes]
    set cpnum $snode
    $canv delete "Type_BEZIER&&(NType_oval||CL)"
    foreach {x0 y0} $dnodes break
    foreach {x1 y1  x2 y2  x3 y3} [lrange $dnodes 2 end] {
        set cptype oval
        incr cpnum
        cadobjects_object_draw_control_line $canv $objid $x0 $y0 $x1 $y1 1 black {} Type_BEZIER
        cadobjects_object_draw_controlpoint $canv $objid BEZIER $x1 $y1 $cpnum oval red red Type_BEZIER
        incr cpnum
        cadobjects_object_draw_control_line $canv $objid $x3 $y3 $x2 $y2 1 black {} Type_BEZIER
        cadobjects_object_draw_controlpoint $canv $objid BEZIER $x2 $y2 $cpnum oval red red Type_BEZIER
        incr cpnum
        set x0 $x3
        set y0 $y3
    }
    $canv raise "CL&&Obj_$objid"
    $canv raise "CP&&Obj_$objid&&NType_oval"
    $canv raise "CP&&Obj_$objid&&(NType_diamond||NType_rectangle||NType_endnode)"

    return
}


proc plugin_bezier_clickobj {canv objid coords x y} {
    set toolid [tool_current]
    set tooltoken [tool_token $toolid]
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set scalemult [expr {$dpi*$scalefactor}]
    set linewidth [cadobjects_object_stroke_width $canv $objid]
    set closeenough [$canv cget -closeenough]
    set closeenough [expr {$closeenough/$scalemult+$linewidth/2.0}]
    set tolerance [expr {1.0/$scalemult}]
    set maxnode [expr {[llength $coords]/2}]

    if {$tooltoken == "NODESEL"} {
        set segs [bezutil_bezier_mindist_segpos $x $y $coords $closeenough]
        if {$segs == ""} {
            bell
            return
        }
        foreach {seg t} $segs break
        set snode [expr {$seg*3+1}]
        set enode [expr {$snode+3}]
        if {$snode < 1} {
            set snode 1
        }
        if {$enode > $maxnode} {
            set enode $maxnode
        }
        set showcps {}
        for {set i $snode} {$i <= $enode} {incr i} {
            lappend showcps $i
        }
        cadobjects_object_setdatum $canv $objid "SHOWCPS" $showcps

        set pos1 [expr {($snode-1)*2}]
        set pos2 [expr {($enode-1)*2+1}]
        set dnodes [lrange $coords $pos1 $pos2]
        set dnodes [cadobjects_scale_coords $canv $dnodes]
        set cpnum $snode
        $canv delete "Type_BEZIER&&(NType_oval||CL)"
        foreach {x0 y0} $dnodes break
        foreach {x1 y1  x2 y2  x3 y3} [lrange $dnodes 2 end] {
            set cptype oval
            incr cpnum
            cadobjects_object_draw_control_line $canv $objid $x0 $y0 $x1 $y1 1 black {} Type_BEZIER
            cadobjects_object_draw_controlpoint $canv $objid BEZIER $x1 $y1 $cpnum oval red red Type_BEZIER
            incr cpnum
            cadobjects_object_draw_control_line $canv $objid $x3 $y3 $x2 $y2 2 black {} Type_BEZIER
            cadobjects_object_draw_controlpoint $canv $objid BEZIER $x2 $y2 $cpnum oval red red Type_BEZIER
            incr cpnum
            set x0 $x3
            set y0 $y3
        }
        $canv raise "CL&&Obj_$objid"
        $canv raise "CP&&Obj_$objid&&NType_oval"
        $canv raise "CP&&Obj_$objid&&(NType_diamond||NType_rectangle||NType_endnode)"
    }
}


proc plugin_bezier_dragctls {canv objid coords nodes dx dy} {
    set centernodes {}
    set cp1list {}
    set cp2list {}
    set prevnodepos -1
    set nextnodepos 1
    foreach node [lsort -integer $nodes] {
        if {$node > 0 && $node <= [llength $coords] / 2} {
            if {$node % 3 == 1} {
                lappend centernodes $node
            } elseif {$node % 3 == 0} {
                if {$nextnodepos >= [llength $nodes]} {
                    lappend cp1list $node
                } elseif {[lindex $nodes $nextnodepos] == $node+2} {
                    lappend centernodes [expr {$node+1}]
                } elseif {[lindex $nodes $nextnodepos] != $node+1} {
                    lappend cp1list $node
                }
            } else {
                if {$prevnodepos == -1} {
                    lappend cp2list $node
                } elseif {[lindex $nodes $prevnodepos] == $node-2} {
                    # Centerpoint already noted
                } elseif {[lindex $nodes $prevnodepos] != $node-1} {
                    lappend cp2list $node
                }
            }
        }
        incr prevnodepos
        incr nextnodepos
    }

    foreach node $centernodes {
        set pos1 [expr {($node-1)*2}]
        set pos2 [expr {$pos1+1}]
        set nx [expr {[lindex $coords $pos1]+$dx}]
        set ny [expr {[lindex $coords $pos2]+$dy}]
        set coords [lreplace $coords $pos1 $pos2 $nx $ny]

        incr pos1 -2
        incr pos2 -2
        if {$pos1 >= 0} {
            set nx [expr {[lindex $coords $pos1]+$dx}]
            set ny [expr {[lindex $coords $pos2]+$dy}]
            set coords [lreplace $coords $pos1 $pos2 $nx $ny]
        }

        incr pos1 4
        incr pos2 4
        if {$pos2 < [llength $coords]} {
            set nx [expr {[lindex $coords $pos1]+$dx}]
            set ny [expr {[lindex $coords $pos2]+$dy}]
            set coords [lreplace $coords $pos1 $pos2 $nx $ny]
        }
    }

    plugin_bezier_regen_node_data_if_needed $canv $objid $coords
    set nodetypes [cadobjects_object_getdatum $canv $objid "NODETYPES"]
    foreach node $cp1list {
        set nodetype [string index $nodetypes [expr {$node/3}]]

        set pos1 [expr {($node-1)*2}]
        set pos2 [expr {$pos1+3}]
        foreach {cpx1 cpy1 mpx mpy} [lrange $coords $pos1 $pos2] break

        # Move first control point
        set cpx1 [expr {$cpx1+$dx}]
        set cpy1 [expr {$cpy1+$dy}]

        set pos3 [expr {$pos1+4}]
        set pos4 [expr {$pos3+1}]
        if {$pos4 < [llength $coords]} {
            foreach {cpx2 cpy2} [lrange $coords $pos3 $pos4] break
            switch -exact -- $nodetype {
                "C" {
                    # Collinear.
                    set dist [expr {hypot($cpy2-$mpy,$cpx2-$mpx)}]
                    set ang [expr {atan2($mpy-$cpy1,$mpx-$cpx1)}]
                    set cpx2 [expr {$dist*cos($ang)+$mpx}]
                    set cpy2 [expr {$dist*sin($ang)+$mpy}]
                }
                "E" {
                    # Keep equidistant from midpoint
                    set dist [expr {hypot($cpy1-$mpy,$cpx1-$mpx)}]
                    set ang [expr {atan2($mpy-$cpy1,$mpx-$cpx1)}]
                    set cpx2 [expr {$dist*cos($ang)+$mpx}]
                    set cpy2 [expr {$dist*sin($ang)+$mpy}]
                }
            }
            set coords [lreplace $coords $pos1 $pos4 $cpx1 $cpy1 $mpx $mpy $cpx2 $cpy2]
        } else {
            set coords [lreplace $coords $pos1 $pos2 $cpx1 $cpy1 $mpx $mpy]
        }
    }

    set nodetypes [cadobjects_object_getdatum $canv $objid "NODETYPES"]
    foreach node $cp2list {
        set nodetype [string index $nodetypes [expr {$node/3}]]

        set pos1 [expr {($node-2)*2}]
        set pos2 [expr {$pos1+3}]
        foreach {mpx mpy cpx2 cpy2} [lrange $coords $pos1 $pos2] break

        # Move second control point
        set cpx2 [expr {$cpx2+$dx}]
        set cpy2 [expr {$cpy2+$dy}]

        set pos3 [expr {$pos1-2}]
        set pos4 [expr {$pos3+1}]
        if {$pos3 >= 0} {
            foreach {cpx1 cpy1} [lrange $coords $pos3 $pos4] break
            switch -exact -- $nodetype {
                "C" {
                    # Collinear.
                    set dist [expr {hypot($cpy1-$mpy,$cpx1-$mpx)}]
                    set ang [expr {atan2($mpy-$cpy2,$mpx-$cpx2)}]
                    set cpx1 [expr {$dist*cos($ang)+$mpx}]
                    set cpy1 [expr {$dist*sin($ang)+$mpy}]
                }
                "E" {
                    # Keep equidistant from midpoint
                    set dist [expr {hypot($cpy2-$mpy,$cpx2-$mpx)}]
                    set ang [expr {atan2($mpy-$cpy2,$mpx-$cpx2)}]
                    set cpx1 [expr {$dist*cos($ang)+$mpx}]
                    set cpy1 [expr {$dist*sin($ang)+$mpy}]
                }
            }
            set coords [lreplace $coords $pos3 $pos2 $cpx1 $cpy1 $mpx $mpy $cpx2 $cpy2]
        } else {
            set coords [lreplace $coords $pos1 $pos2 $mpx $mpy $cpx2 $cpy2]
        }
    }

    cadobjects_object_set_coords $canv $objid $coords
    return 1 ;# We moved everything.  Tell caller we need nothing else moved.
}


proc plugin_bezier_regen_node_data_if_needed {canv objid coords} {
    set nodetypes [cadobjects_object_getdatum $canv $objid "NODETYPES"]
    if {$nodetypes == "" || [string length $nodetypes] < [llength $coords]/6} {
        # We need to regenerate the nodetypes data.

        # Start point is disjointed corner by definition
        set nodetypes "D"

        set x3 ""
        foreach {x1 y1 x2 y2 x3 y3} [lrange $coords 4 end] {
            if {$x3 == ""} {
                # Endpoint is disjointed corner by definition
                append nodetypes "D"
            } elseif {[bezutil_segment_is_collinear $x1 $y1 $x2 $y2 $x3 $y3 1e-4]} {
                # control points on either side of this node are linear

                if {abs(hypot($y2-$y1,$x2-$x1)-hypot($y3-$y2,$x3-$x2)) < 1e-4} {
                    # control points on either side of this node are equidistant 
                    append nodetypes "E"
                } else {
                    # This corner is merely collinear
                    append nodetypes "C"
                }
            } else {
                # Disjointed corner
                append nodetypes "D"
            }
        }
        cadobjects_object_setdatum $canv $objid "NODETYPES" $nodetypes
    }
}


proc plugin_bezier_recalculate {canv objid coords {flags ""}} {
    if {"CONSTRUCT" in $flags} {
        constants pi
        set clen [llength $coords]
        if {($clen/2) % 3 == 0} {
            set coords [lrange $coords 0 end-4]
            set clen [llength $coords]
        }
        if {$clen <= 8} {
            lassign [lrange $coords 0 1] x0 y0
            lassign [lrange $coords end-1 end] x3 y3
            set x1 [expr {(2.0*$x0+$x3)/3.0}]
            set y1 [expr {(2.0*$y0+$y3)/3.0}]
            set x2 [expr {(2.0*$x3+$x0)/3.0}]
            set y2 [expr {(2.0*$y3+$y0)/3.0}]
            set coords [list $x0 $y0  $x1 $y1  $x2 $y2  $x3 $y3]
            cadobjects_object_set_coords $canv $objid $coords
        } elseif {$clen >= 10} {
            lassign [lrange $coords 0 7] sx0 sy0 sx1 sy1 sx2 sy2 sx3 sy3
            if {($clen/2) % 3 == 2} {
                lassign [lrange $coords end-9 end] x0 y0 x1 y1 x2 y2 x3 y3 xn yn
                set coords [lrange $coords 0 end-6]
            } else {
                lassign [lrange $coords end-13 end] x0 y0 x1 y1 x2 y2 x3 y3 x4 y4 x5 y5 xn yn
                set coords [lrange $coords 0 end-10]
            }
            set ang0 [expr {atan2($sy3-$sy0,$sx3-$sx0)}]
            set ang1 [expr {atan2($y3-$y0,$x3-$x0)}]
            set ang2 [expr {atan2($yn-$y3,$xn-$x3)}]
            set rad0 [expr {hypot($sy1-$sy0,$sx1-$sx0)}]
            set rad1 [expr {hypot($y3-$y2,$x3-$x2)}]
            set rad2 [expr {hypot($yn-$y3,$xn-$x3)/3.0}]
            set ang5 $ang2
            set ang6 $ang0
            if {abs($rad2) > 1e-6} {
                if {[cadobjects_modkey_isdown MOD2]} {
                    set ang3 $ang1
                    set ang4 $ang2
                } else {
                    set ang3 [expr {($ang1+$ang2)/2.0}]
                    if {abs($ang1-$ang2) > $pi} {
                        set ang3 [expr {$ang3+$pi}]
                    }
                    set ang4 $ang3
                    if {hypot($yn-$sy0,$xn-$sx0) < 1e-6} {
                        set angs [expr {($ang0+$ang2)/2.0}]
                        if {abs($ang0-$ang2) > $pi} {
                            set angs [expr {$angs+$pi}]
                        }
                        set ang4 $ang3
                        set ang5 $angs
                        set ang6 $angs
                    }
                }
            } else {
                set ang3 $ang1
                set ang4 $ang2
            }
            set x2 [expr {$x3-$rad1*cos($ang3)}]
            set y2 [expr {$y3-$rad1*sin($ang3)}]
            set x4 [expr {$x3+$rad2*cos($ang4)}]
            set y4 [expr {$y3+$rad2*sin($ang4)}]
            set x5 [expr {$xn-$rad2*cos($ang5)}]
            set y5 [expr {$yn-$rad2*sin($ang5)}]
            set sx1 [expr {$sx0+$rad0*cos($ang6)}]
            set sy1 [expr {$sy0+$rad0*sin($ang6)}]
            set coords [lreplace $coords 2 3 $sx1 $sy1]
            lappend coords $x2 $y2  $x3 $y3  $x4 $y4  $x5 $y5  $xn $yn
            cadobjects_object_set_coords $canv $objid $coords
        }
    }
    cadobjects_object_setdatum $canv $objid "NODETYPES" ""
}


proc plugin_bezier_decompose {canv objid coords allowed} {
    if {"GCODE" in $allowed && "LINES" in $allowed} {
        set cutbit  [cadobjects_object_cutbit $canv $objid]
        set cutside [cadobjects_object_getdatum $canv $objid "CUTSIDE"]
        set cutdiam [mlcnc_tooldiam $cutbit]
        set cutrad [expr {abs($cutdiam/2.0)}]
        set linepath {}
        bezutil_append_line_from_bezier linepath $coords
        set out {}
        if {$cutbit > 0} {
            if {$cutside == "right"} {
                foreach pline [mlcnc_path_offset $linepath $cutrad] {
                    lappend out LINES $pline
                }
            } elseif {$cutside == "left"} {
                foreach pline [mlcnc_path_offset $linepath -$cutrad] {
                    lappend out LINES $pline
                }
            } elseif {$cutside == "inside"} {
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
    } elseif {"BEZIER" in $allowed} {
        return [list BEZIER $coords]
    } elseif {"LINES" in $allowed} {
        set linepath {}
        bezutil_append_line_from_bezier linepath $coords
        return [list LINES $linepath]
    }
    return {}
}


proc plugin_bezier_pointsofinterest {canv objid coords nearx neary} {
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set scalemult [expr {$dpi*$scalefactor}]
    set linewidth [cadobjects_object_stroke_width $canv $objid]
    set closeenough [$canv cget -closeenough]
    set closeenough [expr {(5+$closeenough)/$scalemult+$linewidth/2.0}]
    set tolerance 1e-4

    set poi {}
    set nodenum 0
    foreach {x0 y0 x1 y1 x2 y2} $coords {
        # Note: last iteration only sets x0 and y0.
        lappend poi "controlpoints" $x0 $y0 "Node point" [incr nodenum]
        incr nodenum 3
    }
    cadobjects_object_bezier_pois poi "contours" "On Curve" $coords $nearx $neary $closeenough $tolerance
    return $poi
}


proc plugin_bezier_bbox {canv objid coords} {
    return [geometry_pointlist_bbox $coords]
}


proc plugin_bezier_deletenodes {canv objid coords nodes} {
    set nodecount [expr {[llength $coords]/2}]
    set delnodes {}
    set cp1list {}
    set cp2list {}
    foreach node [lsort -increasing -integer $nodes] {
        switch -exact -- [expr {$node % 3}] {
            0 {
                lappend cp1list $node
            }
            1 {
                if {$node == 1} {
                    lappend delnodes 1 2 3
                } elseif {$node == $nodecount} {
                    for {set i [expr {$nodecount-2}]} {$i <= $nodecount} {incr i} {
                        lappend delnodes $i
                    }
                } else {
                    lappend delnodes [expr {$node-1}]
                    lappend delnodes $node
                    lappend delnodes [expr {$node+1}]
                }
            }
            2 {
                lappend cp2list $node
            }
        }
    }

    foreach node $cp1list {
        set pos1 [expr {$node*2}]
        set pos2 [expr {$pos1+1}]
        foreach {x y} [lrange $coords $pos1 $pos2] break
        set pos3 [expr {($node-1)*2}]
        set pos4 [expr {$pos3+1}]
        set coords [lreplace $coords $pos3 $pos4 $x $y]
    }

    foreach node $cp2list {
        set pos1 [expr {($node-2)*2}]
        set pos2 [expr {$pos1+1}]
        foreach {x y} [lrange $coords $pos1 $pos2] break
        set pos3 [expr {($node-1)*2}]
        set pos4 [expr {$pos3+1}]
        set coords [lreplace $coords $pos3 $pos4 $x $y]
    }

    foreach node [lsort -decreasing -integer -unique $delnodes] {
        set pos1 [expr {($node-1)*2}]
        set pos2 [expr {$pos1+1}]
        set coords [lreplace $coords $pos1 $pos2]
    }

    cadselect_node_clear $canv
    cadobjects_object_setdatum $canv $objid "NODETYPES" ""
    if {[llength $coords] < 8} {
        cadobjects_object_delete $canv $objid
    } else {
        cadobjects_object_set_coords $canv $objid $coords
        plugin_bezier_regen_node_data_if_needed $canv $objid $coords
        cadobjects_object_recalculate $canv $objid
        cadobjects_object_draw $canv $objid
    }

    return 1 ;# We deleted everything we needed to.  Tell caller we're done.
}


proc plugin_bezier_addnode {canv objid coords x y} {
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set scalemult [expr {$dpi*$scalefactor}]
    set linewidth [cadobjects_object_stroke_width $canv $objid]
    set closeenough [$canv cget -closeenough]
    set closeenough [expr {$closeenough/$scalemult+$linewidth/2.0}]
    set tolerance [expr {1.0/$scalemult}]

    if {[llength $coords] == 2} {
        lappend coords $x $y
        set coords [bezutil_bezier_from_line $coords]
    }
    set coords [bezutil_bezier_split_near $x $y $coords $closeenough $tolerance]
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_setdatum $canv $objid "NODETYPES" ""
    cadobjects_object_recalculate $canv $objid
    cadobjects_object_draw $canv $objid
    cadobjects_object_draw_controls $canv $objid red

    return 1 ;# We did everything we needed to.  Tell caller we're done.
}


proc plugin_bezier_partial_position {canv objid coords part} {
    set totlen [bezutil_bezier_length $coords]
    set destlen [expr {$totlen*$part}]
    foreach {x0 y0} [lrange $coords 0 1] break
    foreach {x1 y1 x2 y2 x3 y3} [lrange $coords 2 end] {
        set seglen [bezutil_bezier_segment_length $x0 $y0 $x1 $y1 $x2 $y2 $x3 $y3]
        if {$seglen > $destlen} {
            set destlen [expr {$destlen-$seglen}]
        } else {
            break
        }
        set x0 $x3
        set y0 $y3
    }
    return [bezutil_bezier_segment_partial_pos $x0 $y0 $x1 $y1 $x2 $y2 $x3 $y3 $destlen 1e-4]
}


proc plugin_bezier_length {canv objid coords} {
    return [bezutil_bezier_length $coords]
}


proc plugin_bezier_sliceobj {canv objid coords x y} {
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set scalemult [expr {$dpi*$scalefactor}]
    set linewidth [cadobjects_object_stroke_width $canv $objid]
    set closeenough [$canv cget -closeenough]
    set closeenough [expr {($closeenough/$scalemult)+($linewidth/2.0)}]
    set tolerance [expr {1.0/$scalemult}]

    set beziers [bezutil_bezier_break_near $x $y $coords $closeenough $tolerance]
    cadobjects_object_set_coords $canv $objid [lindex $beziers 0]
    cadobjects_object_setdatum $canv $objid "NODETYPES" ""

    set out $objid
    if {[llength $beziers] > 1} {
        set nuobj [cadobjects_object_create $canv BEZIER [lindex $beziers 1] {}]
        lappend out $nuobj
    }
    return $out
}


proc plugin_bezier_nearest_point {canv objid coords x y} {
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set scalemult [expr {$dpi*$scalefactor}]
    set linewidth [cadobjects_object_stroke_width $canv $objid]
    set closeenough [$canv cget -closeenough]
    set closeenough [expr {$closeenough/$scalemult+$linewidth/2.0}]
    set tolerance 1e-4
    set pt [bezutil_bezier_nearest_point $x $y $coords $closeenough $tolerance]
    return $pt
}





proc plugin_bezier_register {} {
    tool_register_ex BEZIERQUAD "&Lines" "&Quadratic Bezier Curve" {
        {1    "First Point"}
        {2    "Control Point"}
        {3    "Next Point"}
        {...  ""}
    } -icon "tool-bezierquad" -creator
    tool_register_ex BEZIER "&Lines" "Cubic &Bezier Curve" {
        {1    "First Point"}
        {2    "Next Point"}
        {...  ""}
    } -icon "tool-bezier" -creator
}
plugin_bezier_register


# vim: set ts=4 sw=4 nowrap expandtab: settings

