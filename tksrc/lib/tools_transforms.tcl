proc plugin_nodeadd_execute {canv coords isconf} {
    foreach {x y} [cadobjects_scale_coords $canv $coords] break
    set closeenough 5
    set x0 [expr {$x-$closeenough}]
    set y0 [expr {$y-$closeenough}]
    set x1 [expr {$x+$closeenough}]
    set y1 [expr {$y+$closeenough}]
    set cids [$canv find overlapping $x0 $y0 $x1 $y1]
    set objid ""
    foreach cid $cids {
        set oid [cadobjects_objid_from_cid $canv $cid]
        if {[cadselect_ismember $canv $oid]} {
            set objid $oid
            break
        }
    }
    if {$objid == ""} {
        bell
        return
    }
    if {![cadselect_ismember $canv $objid]} {
        if {![cadobjects_modkey_isdown SHIFT]} {
            cadselect_clear $canv
        }
        cadselect_add $canv $objid
        return
    }
    cadobjects_object_node_add $canv $objid [lindex $coords 0] [lindex $coords 1]
}





proc plugin_nodedel_execute {canv coords isconf} {
    set cid [$canv find withtag {current&&CP}]
    if {$cid == ""} {
        set cid [$canv find withtag {current}]
        if {$cid == ""} {
            bell
            return
        }
        set objid [cadobjects_objid_from_cid $canv $cid]
        if {$objid == ""} {
            bell
            return
        }
        if {![cadobjects_modkey_isdown SHIFT]} {
            cadselect_clear $canv
        }
        cadselect_add $canv $objid
        return
    }
    foreach {objid nodenum} [cadobjects_objid_and_node_from_cid $canv $cid] break
    if {$objid == ""} {
        bell
        return
    }
    cadobjects_object_nodes_delete $canv $objid $nodenum
}





proc plugin_slice_execute {canv coords isconf} {
    foreach {x y} [cadobjects_scale_coords $canv $coords] break
    set closeenough 5
    set x0 [expr {$x-$closeenough}]
    set y0 [expr {$y-$closeenough}]
    set x1 [expr {$x+$closeenough}]
    set y1 [expr {$y+$closeenough}]
    set cids [$canv find overlapping $x0 $y0 $x1 $y1]
    set objid ""
    set foundcid ""
    foreach cid $cids {
        set oid [cadobjects_objid_from_cid $canv $cid]
        if {[cadselect_ismember $canv $oid]} {
            set objid $oid
            set foundcid $cid
            break
        }
    }
    if {$objid == ""} {
        bell
        return
    }
    if {![cadselect_ismember $canv $objid]} {
        if {![cadobjects_modkey_isdown SHIFT]} {
            cadselect_clear $canv
        }
        cadselect_add $canv $objid
        return
    }
    set selids [cadselect_list $canv]
    if {[llength $selids] == 0} {
        set cid $foundcid
        set selids [cadobjects_objid_from_cid $canv $cid]
    }
    set selobjs {}
    foreach objid $selids {
        set nuobjs [cadobjects_object_slice $canv $objid [lindex $coords 0] [lindex $coords 1]]
        if {[llength $nuobjs] > 0} {
            lappend selobjs {*}$nuobjs
        }
    }
    cadselect_clear $canv
    foreach objid $selobjs {
        cadselect_add $canv $objid
    }
}





proc plugin_reorient_execute {canv coords isconf} {
    set cid [$canv find withtag {current&&CP}]
    if {$cid == ""} {
        set cid [$canv find withtag {current}]
        if {$cid == ""} {
            bell
            return
        }
        set objid [cadobjects_objid_from_cid $canv $cid]
        if {$objid == ""} {
            bell
            return
        }
        if {![cadobjects_modkey_isdown SHIFT]} {
            cadselect_clear $canv
        }
        cadselect_add $canv $objid
        return
    }
    foreach {objid nodenum} [cadobjects_objid_and_node_from_cid $canv $cid] break
    if {$objid == ""} {
        bell
        return
    }
    cadobjects_object_node_reorient $canv $objid $nodenum
}







proc plugin_connect_wasclicked {canv coords} {
    set toolid [tool_current]
    if {[llength $coords] < 2} {
        cadselect_clear $canv
        tool_setdatum $toolid "OBJ1" ""
        return
    }
    if {[llength $coords] < 4} {
        foreach {x0 y0} [cadobjects_scale_coords $canv $coords] break
        set objids [cadobjects_get_objids_near $canv $x0 $y0 1.0]
        if {[llength $objids] == 0} {
            cadobjects_tool_clear_coords $canv
            bell
            return
        }
        set objid [lindex $objids 0]

        cadselect_clear $canv
        cadselect_add $canv $objid
        tool_setdatum $toolid "OBJ1" $objid
    }
}



proc plugin_connect_preview {canv coords isconf} {
    set toolid [tool_current]
    if {[llength $coords] < 4} {
        return
    }
    foreach {x0 y0 x1 y1} [cadobjects_scale_coords $canv $coords] break
    $canv delete Preview
    set linecoords [list $x0 $y0 $x1 $y1]
    $canv create line $linecoords -fill blue -tags Preview
}



proc plugin_connect_execute {canv coords isconf} {
    $canv delete Preview
    foreach {x0 y0 x1 y1} [cadobjects_scale_coords $canv $coords] break
    set objids [cadobjects_get_objids_near $canv $x1 $y1 1.0]
    if {[llength $objids] == 0} {
        bell
        return
    }
    set toolid [tool_current]
    set obj1 [tool_getdatum $toolid "OBJ1"]
    set obj2 [lindex $objids 0]
    if {$obj2 == $obj1} {
        bell
        return
    } else {
        cadselect_add $canv $obj2
    }

    cadselect_clear $canv
    foreach {x0 y0 x1 y1} $coords break
    set nuobj [cadobjects_objects_connect $canv $obj1 $x0 $y0 $obj2 $x1 $y1]
    #cadselect_add $canv $nuobj
}









proc plugin_translate_editfields {canv} {
    set out {}
    lappend out {
        type FLOAT
        name DELTAX
        title "Delta X"
        min -1e6
        max 1e6
        increment 0.125
        width 8
        valgetcb "plugin_translate_getfield"
        default 0.0
        islength 1
    }
    lappend out {
        type FLOAT
        name DELTAY
        title "Delta Y"
        min -1e6
        max 1e6
        increment 0.125
        width 8
        valgetcb "plugin_translate_getfield"
        default 0.0
        islength 1
    }
    lappend out {
        type EXEC
        name EXEC
        title "Move"
    }
    return $out
}


proc plugin_translate_getfield {canv coords name} {
    constants pi
    switch -exact -- $name {
        "DELTAX" {
            if {[llength $coords] < 4} {
                return 0.0
            }
            foreach {x0 y0 x1 y1} $coords break
            set dist [expr {$x1-$x0}]
            return $dist
        }
        "DELTAY" {
            if {[llength $coords] < 4} {
                return 0.0
            }
            foreach {x0 y0 x1 y1} $coords break
            set dist [expr {$y1-$y0}]
            return $dist
        }
    }
}




proc plugin_translate_preview {canv coords isconf} {
    set toolid [tool_current]
    if {!$isconf} {
        if {[llength $coords] < 4} {
            return
        }
        foreach {refx refy newx newy} $coords break
        set dx [expr {$newx-$refx}]
        set dy [expr {$newy-$refy}]
        if {[cadobjects_modkey_isdown SHIFT]} {
            set ddiag [expr {abs(abs($dx)-abs($dy))}]
            if {$ddiag < abs($dx) && $ddiag < abs($dy)} {
                if {abs($dx) > abs($dy)} {
                    set dy [expr {abs($dx)*(($dy>=0)?1.0:-1.0)}]
                } else {
                    set dx [expr {abs($dy)*(($dx>=0)?1.0:-1.0)}]
                }
            } elseif {abs($dx) > abs($dy)} {
                set dy 0.0
            } else {
                set dx 0.0
            }
        }
    } else {
        set dx [tool_getdatum $toolid "DELTAX"]
        set dy [tool_getdatum $toolid "DELTAY"]
        if {$dx == ""} {
            set dx 0.0
        }
        if {$dy == ""} {
            set dy 0.0
        }
    }
    foreach {dx dy} [cadobjects_scale_coords $canv [list $dx $dy]] break
    foreach {ox0 oy0 ox1 oy1} [$canv bbox Selected] break
    if {![info exists ox0]} {
        # Nothing selected.
        return
    }
    $canv delete Preview
    foreach {x0 y0 x1 y1} [list \
        $ox0 $oy0 $ox0 $oy1 \
        $ox0 $oy0 $ox1 $oy0 \
        $ox0 $oy0 $ox1 $oy1 \
        $ox1 $oy0 $ox1 $oy1 \
        $ox0 $oy1 $ox1 $oy1 \
        $ox0 $oy1 $ox1 $oy0 \
    ] {
        set nx0 [expr {$x0+$dx}]
        set ny0 [expr {$y0+$dy}]
        set nx1 [expr {$x1+$dx}]
        set ny1 [expr {$y1+$dy}]
        set linecoords [list $nx0 $ny0 $nx1 $ny1]
        $canv create line $linecoords -fill blue -tags Preview
    }
}


proc plugin_translate_execute {canv coords isconf} {
    $canv delete Preview
    set toolid [tool_current]
    if {!$isconf} {
        if {[llength $coords] < 4} {
            return
        }
        foreach {refx refy newx newy} $coords break
        set dx [expr {$newx-$refx}]
        set dy [expr {$newy-$refy}]
        if {[cadobjects_modkey_isdown SHIFT]} {
            set ddiag [expr {abs(abs($dx)-abs($dy))}]
            if {$ddiag < abs($dx) && $ddiag < abs($dy)} {
                if {abs($dx) > abs($dy)} {
                    set dy [expr {abs($dx)*(($dy>=0)?1.0:-1.0)}]
                } else {
                    set dx [expr {abs($dy)*(($dx>=0)?1.0:-1.0)}]
                }
            } elseif {abs($dx) > abs($dy)} {
                set dy 0.0
            } else {
                set dx 0.0
            }
        }
    } else {
        set dx [tool_getdatum $toolid "DELTAX"]
        set dy [tool_getdatum $toolid "DELTAY"]
        if {$dx == ""} {
            set dx 0.0
        }
        if {$dy == ""} {
            set dy 0.0
        }
    }
    foreach objid [cadselect_list $canv] {
        cadobjects_object_translate $canv $objid $dx $dy
    }
    tool_setdatum $toolid "DELTA" {0.0 0.0}
    cadobjects_reset
}





proc plugin_rotate_editfields {canv} {
    set out {}
    lappend out {
        type POINT
        name CENTER
        datum 0
        title "Rotation Pt"
        default {0.0 0.0}
    }
    lappend out {
        type FLOAT
        name ANGLE
        title "Rot Angle"
        min -360.0
        max 360.0
        increment 5.0
        width 8
        valgetcb "plugin_rotate_getfield"
        default 0.0
    }
    lappend out {
        type EXEC
        name EXEC
        title "Rotate"
    }
    return $out
}


proc plugin_rotate_getfield {canv coords name} {
    constants pi
    if {$name == "ANGLE"} {
        if {[llength $coords] < 6} {
            return 0.0
        }
        foreach {cx cy refx refy newx newy} $coords break
        set ang1 [expr {atan2($refy-$cy,$refx-$cx)*180.0/$pi}]
        set ang2 [expr {atan2($newy-$cy,$newx-$cx)*180.0/$pi}]
        set drot [expr {$ang2-$ang1}]
        if {$drot > 180.0} {
            set drot [expr {$drot-360.0}]
        } elseif {$drot < -180.0} {
            set drot [expr {$drot+360.0}]
        }
        return $drot
    }
}


proc plugin_rotate_preview {canv coords isconf} {
    constants pi
    set toolid [tool_current]
    set coords [cadobjects_scale_coords $canv $coords]
    if {!$isconf} {
        if {[llength $coords] < 6} {
            return
        }
        foreach {cx cy refx refy newx newy} $coords break
        set ang1 [expr {atan2($refy-$cy,$refx-$cx)*180.0/$pi}]
        set ang2 [expr {atan2($newy-$cy,$newx-$cx)*180.0/$pi}]
        set drot [expr {$ang2-$ang1}]
        if {$drot > 180.0} {
            set drot [expr {$drot-360.0}]
        } elseif {$drot < -180.0} {
            set drot [expr {$drot+360.0}]
        }
    } else {
        if {[llength $coords] < 2} {
            return
        }
        foreach {cx cy} $coords break
        set drot [tool_getdatum $toolid "ANGLE"]
        if {$drot == ""} {
            return
        }
        set drot [expr {-$drot}]
    }
    set rotr [expr {$drot*$pi/180.0}]
    set sinv [expr {sin($rotr)}]
    set cosv [expr {cos($rotr)}]
    foreach {ox0 oy0 ox1 oy1} [$canv bbox Selected] break
    if {![info exists ox0]} {
        # Nothing selected.  Don't rotate.
        return
    }
    $canv delete Preview
    foreach {x0 y0 x1 y1} [list \
        $ox0 $oy0 $ox0 $oy1 \
        $ox0 $oy0 $ox1 $oy0 \
        $ox0 $oy0 $ox1 $oy1 \
        $ox1 $oy0 $ox1 $oy1 \
        $ox0 $oy1 $ox1 $oy1 \
        $ox0 $oy1 $ox1 $oy0 \
    ] {
        set nx0 [expr {$cosv*($x0-$cx)-$sinv*($y0-$cy)+$cx}]
        set ny0 [expr {$sinv*($x0-$cx)+$cosv*($y0-$cy)+$cy}]
        set nx1 [expr {$cosv*($x1-$cx)-$sinv*($y1-$cy)+$cx}]
        set ny1 [expr {$sinv*($x1-$cx)+$cosv*($y1-$cy)+$cy}]
        set linecoords [list $nx0 $ny0 $nx1 $ny1]
        $canv create line $linecoords -fill blue -tags Preview
    }
}


proc plugin_rotate_execute {canv coords isconf} {
    constants pi
    $canv delete Preview
    set toolid [tool_current]
    set cx ""
    set cy ""
    if {!$isconf} {
        if {[llength $coords] < 6} {
            return
        }
        foreach {cx cy refx refy newx newy} $coords break
        set ang1 [expr {atan2($refy-$cy,$refx-$cx)*180.0/$pi}]
        set ang2 [expr {atan2($newy-$cy,$newx-$cx)*180.0/$pi}]
        set drot [expr {$ang2-$ang1}]
        if {$drot > 180.0} {
            set drot [expr {$drot-360.0}]
        } elseif {$drot < -180.0} {
            set drot [expr {$drot+360.0}]
        }
    } else {
        if {[llength $coords] >= 2} {
            foreach {cx cy} $coords break
        }
        set drot [tool_getdatum $toolid "ANGLE"]
        if {$drot == ""} {
            return
        }
    }
    foreach objid [cadselect_list $canv] {
        cadobjects_object_rotate $canv $objid $drot $cx $cy
    }
    tool_setdatum $toolid "ANGLE" ""
    cadobjects_reset
}


proc plugin_rotate_selected_by {canv degrees} {
    set objids [cadselect_list $canv]
    foreach {x0 y0 x1 y1} [cadobjects_objects_bbox $canv $objids] break
    set cx [expr {($x0+$x1)/2.0}]
    set cy [expr {($y0+$y1)/2.0}]
    foreach objid $objids {
        cadobjects_object_rotate $canv $objid $degrees $cx $cy
    }
}



proc plugin_scale_editfields {canv} {
    set out {}
    lappend out {
        type FLOAT
        name SCALEX
        title "Scale % X"
        min 0.0
        max 1e6
        increment 5.0
        width 8
        valgetcb "plugin_scale_getfield"
        default 100.0
    }
    lappend out {
        type FLOAT
        name SCALEY
        title "Scale % Y"
        min 0.0
        max 1e6
        increment 5.0
        width 8
        valgetcb "plugin_scale_getfield"
        default 100.0
    }
    lappend out {
        type EXEC
        name EXEC
        title "Scale"
    }
    return $out
}


proc plugin_scale_getfield {canv coords name} {
    if {$name == "SCALEX"} {
        if {[llength $coords] < 6} {
            return 100.0
        }
        foreach {cx cy refx refy newx newy} $coords break
        set odx [expr {$refx-$cx}]
        if {$odx == 0.0} {
            return 100.0
        }
        return [expr {100.0*($newx-$cx)/$odx}]
    } elseif {$name == "SCALEY"} {
        if {[llength $coords] < 6} {
            return 100.0
        }
        foreach {cx cy refx refy newx newy} $coords break
        set ody [expr {$refy-$cy}]
        if {$ody == 0.0} {
            return 100.0
        }
        return [expr {100.0*($newy-$cy)/$ody}]
    }
}


proc plugin_scale_preview {canv coords isconf} {
    set coords [cadobjects_scale_coords $canv $coords]
    $canv delete Preview
    if {!$isconf} {
        if {[llength $coords] < 6} {
            return
        }
        foreach {cx cy refx refy newx newy} $coords break
        if {$refx != $cx} {
            set sx [expr {($newx-$cx)/($refx-$cx)}]
        } else {
            set sx 1.0
        }
        if {$refy != $cy} {
            set sy [expr {($newy-$cy)/($refy-$cy)}]
        } else {
            set sy 1.0
        }
        if {[cadobjects_modkey_isdown SHIFT]} {
            if {abs($sx)>abs($sy)} {
                set sy [expr {abs($sx)*(($sy>=0)?1.0:-1.0)}]
            } else {
                set sx [expr {abs($sy)*(($sx>=0)?1.0:-1.0)}]
            }
        }
    } else {
        if {[llength $coords] >= 2} {
            foreach {cx cy} $coords break
        }
        set toolid [tool_current]
        set sx [tool_getdatum $toolid "SCALEX"]
        set sy [tool_getdatum $toolid "SCALEY"]
        if {$sx == ""} {
            set sx 100.0
        }
        if {$sy == ""} {
            set sy 100.0
        }
        set sx [expr {$sx/100.0}]
        set sy [expr {$sy/100.0}]
    }
    foreach {ox0 oy0 ox1 oy1} [$canv bbox Selected] break
    if {![info exists ox0]} {
        # Nothing selected.
        return
    }
    foreach {x0 y0 x1 y1} [list \
        $ox0 $oy0 $ox0 $oy1 \
        $ox0 $oy0 $ox1 $oy0 \
        $ox0 $oy0 $ox1 $oy1 \
        $ox1 $oy0 $ox1 $oy1 \
        $ox0 $oy1 $ox1 $oy1 \
        $ox0 $oy1 $ox1 $oy0 \
    ] {
        set nx0 [expr {($x0-$cx)*$sx+$cx}]
        set ny0 [expr {($y0-$cy)*$sy+$cy}]
        set nx1 [expr {($x1-$cx)*$sx+$cx}]
        set ny1 [expr {($y1-$cy)*$sy+$cy}]
        set linecoords [list $nx0 $ny0 $nx1 $ny1]
        $canv create line $linecoords -fill blue -tags Preview
    }
}


proc plugin_scale_execute {canv coords isconf} {
    $canv delete Preview
    set toolid [tool_current]
    if {!$isconf} {
        if {[llength $coords] < 6} {
            return
        }
        foreach {cx cy refx refy newx newy} $coords break
        if {$refx != $cx} {
            set sx [expr {($newx-$cx)/($refx-$cx)}]
        } else {
            set sx 1.0
        }
        if {$refy != $cy} {
            set sy [expr {($newy-$cy)/($refy-$cy)}]
        } else {
            set sy 1.0
        }
        if {[cadobjects_modkey_isdown SHIFT]} {
            if {abs($sx)>abs($sy)} {
                set sy [expr {abs($sx)*(($sy>=0)?1.0:-1.0)}]
            } else {
                set sx [expr {abs($sy)*(($sx>=0)?1.0:-1.0)}]
            }
        }
    } else {
        if {[llength $coords] >= 2} {
            foreach {cx cy} $coords break
        }
        set sx [tool_getdatum $toolid "SCALEX"]
        set sy [tool_getdatum $toolid "SCALEY"]
        if {$sx == ""} {
            set sx 100.0
        }
        if {$sy == ""} {
            set sy 100.0
        }
        set sx [expr {$sx/100.0}]
        set sy [expr {$sy/100.0}]
    }
    foreach objid [cadselect_list $canv] {
        cadobjects_object_scale $canv $objid $sx $sy $cx $cy
    }
    tool_setdatum $toolid "SCALEX" ""
    tool_setdatum $toolid "SCALEY" ""
}




proc plugin_shear_preview {canv coords isconf} {
    if {[llength $coords] < 6} {
        # Can't preview with fewer than 2 points.
        return
    }
    set coords [cadobjects_scale_coords $canv $coords]
    foreach {cx cy refx refy newx newy} $coords break
    $canv delete Preview
    if {$refy != $cy} {
        set sx [expr {($newx-$refx)/($refy-$cy)}]
    } else {
        set sx 0.0
    }
    if {$refx != $cx} {
        set sy [expr {($newy-$refy)/($refx-$cx)}]
    } else {
        set sy 0.0
    }
    if {[cadobjects_modkey_isdown SHIFT]} {
        if {abs($sx) > abs($sy)} {
            set sy 0.0
        } else {
            set sx 0.0
        }
    }
    foreach {ox0 oy0 ox1 oy1} [$canv bbox Selected] break
    if {![info exists ox0]} {
        # Nothing selected.
        return
    }
    foreach {x0 y0 x1 y1} [list \
        $ox0 $oy0 $ox0 $oy1 \
        $ox0 $oy0 $ox1 $oy0 \
        $ox0 $oy0 $ox1 $oy1 \
        $ox1 $oy0 $ox1 $oy1 \
        $ox0 $oy1 $ox1 $oy1 \
        $ox0 $oy1 $ox1 $oy0 \
    ] {
        set mat [matrix_skew_xy $sx $sy $cx $cy]
        set linecoords [list $x0 $y0 $x1 $y1]
        set linecoords [matrix_transform_coords $mat $linecoords]
        $canv create line $linecoords -fill blue -tags Preview
    }
}


proc plugin_shear_execute {canv coords isconf} {
    $canv delete Preview
    foreach {cx cy refx refy newx newy} $coords break
    if {$refy != $cy} {
        set sx [expr {($newx-$refx)/($refy-$cy)}]
    } else {
        set sx 0.0
    }
    if {$refx != $cx} {
        set sy [expr {($newy-$refy)/($refx-$cx)}]
    } else {
        set sy 0.0
    }
    if {[cadobjects_modkey_isdown SHIFT]} {
        if {abs($sx) > abs($sy)} {
            set sy 0.0
        } else {
            set sx 0.0
        }
    }
    foreach objid [cadselect_list $canv] {
        cadobjects_object_shear $canv $objid $sx $sy $cx $cy
    }
}





proc plugin_flip_preview {canv coords isconf} {
    $canv delete Preview
    foreach {ox0 oy0 ox1 oy1} [$canv bbox Selected] break
    if {![info exists ox0]} {
        # Nothing selected.
        return
    }
    set cx [expr {($ox0+$ox1)/2.0}]
    set cy [expr {($oy0+$oy1)/2.0}]
    set qx1 [expr {($ox0+$ox1*3.0)/4.0}]
    set qy1 [expr {($oy0+$oy1*3.0)/4.0}]

    if {[llength $coords] < 4} {
        # Can't preview with fewer than 2 points.
        return
    }
    set coords [cadobjects_scale_coords $canv $coords]
    foreach {x0 y0 x1 y1} $coords break
    if {hypot($y1-$y0,$x1-$x0) < 1e-6} {
        return
    }
    set mat [matrix_reflect_line $x0 $y0 $x1 $y1]

    foreach {x0 y0 x1 y1} [list \
        $ox0 $oy0 $ox0 $oy1 \
        $ox0 $oy1 $ox1 $oy1 \
        $ox1 $oy1 $ox1 $oy0 \
        $ox1 $oy0 $ox0 $oy0 \
        $cx  $oy0 $cx  $oy1 \
        $ox0 $cy  $ox1 $cy  \
        $cx  $oy0 $qx1 $qy1 \
    ] {
        set linecoords [list $x0 $y0 $x1 $y1]
        $canv create line $linecoords -fill "#7f7fff" -tags Preview
        set linecoords [matrix_transform_coords $mat $linecoords]
        $canv create line $linecoords -fill blue -tags Preview
    }
}


proc plugin_flip_execute {canv coords isconf} {
    $canv delete Preview
    foreach {x0 y0 x1 y1} $coords break
    cadobjects_object_flip $canv [cadselect_list $canv] $x0 $y0 $x1 $y1
}








proc plugin_bend_preview {canv coords isconf} {
    constants pi degtorad

    if {[llength $coords] < 6} {
        return
    }
    $canv delete Preview
    set sels [$canv bbox Selected]
    if {[llength $sels] == 0} {
        return
    }
    foreach {ox0 oy0 ox1 oy1} [cadobjects_descale_coords $canv $sels] break
    foreach {lx0 ly0 lx1 ly1 px py} $coords break
    foreach {cx cy rad sang eang} [mlcnc_find_arc_from_points $lx0 $ly0 $px $py $lx1 $ly1] break
    if {![info exists cx]} {
        return ""
    }
    set pang [expr {atan2($py-$cy,$px-$cx)}]
    if {$sang < 0} {
        set sang [expr {$sang+2.0*$pi}]
    }
    while {$pang < $sang} {
        set pang [expr {$pang+2.0*$pi}]
    }
    while {$eang < $sang} {
        set eang [expr {$eang+2.0*$pi}]
    }
    if {$pang > $eang} {
        set eang [expr {$eang-2.0*$pi}]
        set pang [expr {$pang-2.0*$pi}]
    }
    set dang [expr {$eang-$sang}]
    set lang [expr {-atan2($ly1-$ly0,$lx1-$lx0)}]
    set ldst [expr {hypot($ly1-$ly0,$lx1-$lx0)}]

    foreach {x0 y0 x1 y1} [list \
        $ox0 $oy0 $ox0 $oy1 \
        $ox0 $oy1 $ox1 $oy1 \
        $ox1 $oy1 $ox1 $oy0 \
        $ox1 $oy0 $ox0 $oy0 \
        $ox0 $oy0 $ox1 $oy1 \
        $ox0 $oy1 $ox1 $oy0 \
        $lx0 $ly0 $lx1 $ly1 \
    ] {
        set path [list $x0 $y0 $x1 $y1]
        set path [bezutil_bezier_from_line $path]
        set path [bezutil_bezier_split_long_segments $path [expr {5.0*$degtorad*$rad}]]
        set nupath {}
        foreach {x y} $path {
            set dx [expr {$x-$lx0}]
            set dy [expr {$y-$ly0}]
            set tx [expr {$dx*cos($lang)-$dy*sin($lang)}]
            set ty [expr {$dx*sin($lang)+$dy*cos($lang)}]
            set nurad [expr {$rad-sign($dang)*$ty}]
            set nuang [expr {$sang+$dang*$tx/$ldst}]
            set x [expr {$nurad*cos($nuang)+$cx}]
            set y [expr {$nurad*sin($nuang)+$cy}]
            lappend nupath $x $y
        }
        set path [cadobjects_scale_coords $canv $nupath]
        $canv create line $path -smooth raw -fill "#7f7fff" -tags Preview
    }
}


proc plugin_bend_execute {canv coords isconf} {
    $canv delete Preview
    foreach {x0 y0 x1 y1 x2 y2} $coords break
    cadobjects_object_bend $canv [cadselect_list $canv] $x0 $y0 $x1 $y1 $x2 $y2
}






proc plugin_wrap_preview {canv coords isconf} {
    constants pi degtorad

    foreach {cx cy lx0 ly0} $coords break
    if {[llength $coords] < 4} {
        return
    }
    if {[llength $coords] < 6} {
        set pang [expr {atan2($ly0-$cy,$lx0-$cx)-$pi/2.0}]
        set perpx [expr {$lx0+cos($pang)}]
        set perpy [expr {$ly0+sin($pang)}]
        lappend coords $perpx $perpy
    }
    $canv delete Preview
    set sels [$canv bbox Selected]
    if {[llength $sels] == 0} {
        return
    }
    foreach {cx cy lx0 ly0 lx1 ly1} $coords break
    foreach {ox0 oy0 ox1 oy1} [cadobjects_descale_coords $canv $sels] break
    set rad [expr {hypot($ly0-$cy,$lx0-$cx)}]
    set sang [expr {atan2($ly0-$cy,$lx0-$cx)}]
    set eang [expr {atan2($ly1-$cy,$lx1-$cx)}]
    if {$sang < 0} {
        set sang [expr {$sang+2.0*$pi}]
    }
    while {$eang < $sang} {
        set eang [expr {$eang+2.0*$pi}]
    }
    set lang [expr {-atan2($ly1-$ly0,$lx1-$lx0)}]
    set ldst [expr {hypot($ly1-$ly0,$lx1-$lx0)}]

    set dx [expr {$cx-$lx0}]
    set dy [expr {$cy-$ly0}]
    set ptx [expr {$dx*cos($lang)-$dy*sin($lang)}]
    set pty [expr {$dx*sin($lang)+$dy*cos($lang)}]

    if {$pty < 0.0} {
        set eang [expr {$eang-2.0*$pi}]
    }
    set dang [expr {$eang-$sang}]

    foreach {x0 y0 x1 y1} [list \
        $ox0 $oy0 $ox0 $oy1 \
        $ox0 $oy1 $ox1 $oy1 \
        $ox1 $oy1 $ox1 $oy0 \
        $ox1 $oy0 $ox0 $oy0 \
        $ox0 $oy0 $ox1 $oy1 \
        $ox0 $oy1 $ox1 $oy0 \
        $lx0 $ly0 $lx1 $ly1 \
    ] {
        set path [list $x0 $y0 $x1 $y1]
        set path [bezutil_bezier_from_line $path]
        set path [bezutil_bezier_split_long_segments $path [expr {5.0*$degtorad*$rad}]]
        set nupath {}
        foreach {x y} $path {
            set dx [expr {$x-$lx0}]
            set dy [expr {$y-$ly0}]
            set tx [expr {$dx*cos($lang)-$dy*sin($lang)}]
            set ty [expr {$dx*sin($lang)+$dy*cos($lang)}]
            set nurad [expr {$rad-sign($dang)*$ty}]
            set nuang [expr {$sang+sign($dang)*$tx/$rad}]
            set x [expr {$nurad*cos($nuang)+$cx}]
            set y [expr {$nurad*sin($nuang)+$cy}]
            lappend nupath $x $y
        }
        set path [cadobjects_scale_coords $canv $nupath]
        $canv create line $path -smooth raw -fill "#7f7fff" -tags Preview
    }
}


proc plugin_wrap_execute {canv coords isconf} {
    $canv delete Preview
    foreach {cx cy lx0 ly0} $coords break
    if {[llength $coords] < 6} {
        set pang [expr {atan2($ly0-$cy,$lx0-$cx)-$pi/2.0}]
        set perpx [expr {$lx0+cos($pang)}]
        set perpy [expr {$ly0+sin($pang)}]
        lappend coords $perpx $perpy
    }
    foreach {x0 y0 x1 y1 x2 y2} $coords break
    cadobjects_object_wrap $canv [cadselect_list $canv] $x0 $y0 $x1 $y1 $x2 $y2
}






proc plugin_wraptan_preview {canv coords isconf} {
    constants pi degtorad

    if {[llength $coords] < 4} {
        return
    }

    $canv delete Preview
    set path [cadobjects_scale_coords $canv [lrange $coords 0 3]]
    $canv create line $path -smooth raw -fill "#7f7fff" -tags Preview

    if {[llength $coords] < 6} {
        return
    }

    set sels [$canv bbox Selected]
    if {[llength $sels] == 0} {
        return
    }
    foreach {ox0 oy0 ox1 oy1} [cadobjects_descale_coords $canv $sels] break

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
    set col [expr {$cpx1*($cpy2-$cpy3)+$cpx2*($cpy3-$cpy1)+$cpx3*($cpy1-$cpy2)}]
    if {abs($col) < 1e-6} {
        # Points are colinear.  Don't wrap.
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
    set rad [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    if {$rad > 180} {
        # Points are colinear.  Don't wrap.
        return
    }

    set sang [expr {atan2($cpy1-$cy,$cpx1-$cx)}]
    set eang [expr {atan2($cpy2-$cy,$cpx2-$cx)}]
    if {$sang < 0} {
        set sang [expr {$sang+2.0*$pi}]
    }
    while {$eang < $sang} {
        set eang [expr {$eang+2.0*$pi}]
    }
    set lang [expr {-atan2($cpy2-$cpy1,$cpx2-$cpx1)}]
    set ldst [expr {hypot($cpy2-$cpy1,$cpx2-$cpx1)}]

    set dx [expr {$cx-$cpx1}]
    set dy [expr {$cy-$cpy1}]
    set ptx [expr {$dx*cos($lang)-$dy*sin($lang)}]
    set pty [expr {$dx*sin($lang)+$dy*cos($lang)}]

    if {$pty < 0.0} {
        set eang [expr {$eang-2.0*$pi}]
    }
    set dang [expr {$eang-$sang}]

    foreach {x0 y0 x1 y1} [list \
        $ox0 $oy0 $ox0 $oy1 \
        $ox0 $oy1 $ox1 $oy1 \
        $ox1 $oy1 $ox1 $oy0 \
        $ox1 $oy0 $ox0 $oy0 \
        $ox0 $oy0 $ox1 $oy1 \
        $ox0 $oy1 $ox1 $oy0 \
        $cpx1 $cpy1 $cpx2 $cpy2 \
    ] {
        set path [list $x0 $y0 $x1 $y1]
        set path [bezutil_bezier_from_line $path]
        set path [bezutil_bezier_split_long_segments $path [expr {5.0*$degtorad*$rad}]]
        set nupath {}
        foreach {x y} $path {
            set dx [expr {$x-$cpx1}]
            set dy [expr {$y-$cpy1}]
            set tx [expr {$dx*cos($lang)-$dy*sin($lang)}]
            set ty [expr {$dx*sin($lang)+$dy*cos($lang)}]
            set nurad [expr {$rad-sign($dang)*$ty}]
            set nuang [expr {$sang+sign($dang)*$tx/$rad}]
            set x [expr {$nurad*cos($nuang)+$cx}]
            set y [expr {$nurad*sin($nuang)+$cy}]
            lappend nupath $x $y
        }
        set path [cadobjects_scale_coords $canv $nupath]
        $canv create line $path -smooth raw -fill "#7f7fff" -tags Preview
    }
}


proc plugin_wraptan_execute {canv coords isconf} {
    constants pi degtorad

    $canv delete Preview
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
    set col [expr {$cpx1*($cpy2-$cpy3)+$cpx2*($cpy3-$cpy1)+$cpx3*($cpy1-$cpy2)}]
    if {abs($col) < 1e-6} {
        # Points are colinear.  Don't wrap.
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
    set rad [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    if {$rad > 180} {
        # Points are colinear.  Don't wrap.
        return
    }
    cadobjects_object_wrap $canv [cadselect_list $canv] $cx $cy $cpx1 $cpy1 $cpx2 $cpy2
}






proc plugin_unwrap_preview {canv coords isconf} {
    constants pi degtorad radtodeg

    foreach {cx cy lx0 ly0} $coords break
    if {[llength $coords] < 4} {
        return
    }
    if {[llength $coords] < 6} {
        set pang [expr {atan2($ly0-$cy,$lx0-$cx)-$pi/2.0}]
        set perpx [expr {$lx0+cos($pang)}]
        set perpy [expr {$ly0+sin($pang)}]
        lappend coords $perpx $perpy
    }
    $canv delete Preview
    set sels [$canv bbox Selected]
    if {[llength $sels] == 0} {
        return
    }
    foreach {cx cy lx0 ly0 lx1 ly1} $coords break
    foreach {ox0 oy0 ox1 oy1} [cadobjects_descale_coords $canv $sels] break
    set rad [expr {hypot($ly0-$cy,$lx0-$cx)}]
    set sang [expr {atan2($ly0-$cy,$lx0-$cx)}]
    set eang [expr {atan2($ly1-$cy,$lx1-$cx)}]
    if {$sang < 0} {
        set sang [expr {$sang+2.0*$pi}]
    }
    while {$eang < $sang} {
        set eang [expr {$eang+2.0*$pi}]
    }
    set lang [expr {atan2($ly1-$ly0,$lx1-$lx0)}]
    set ldst [expr {hypot($ly1-$ly0,$lx1-$lx0)}]

    set dx [expr {$cx-$lx0}]
    set dy [expr {$cy-$ly0}]
    set ptx [expr {$dx*cos($lang)-$dy*sin($lang)}]
    set pty [expr {$dx*sin($lang)+$dy*cos($lang)}]

    if {$pty < 0.0} {
        set eang [expr {$eang-2.0*$pi}]
    }
    set dang [expr {$eang-$sang}]

    set linepath [list $lx0 $ly0 $lx1 $ly1]
    set linepath [cadobjects_scale_coords $canv $linepath]
    $canv create line $linepath -fill "#7f7fff" -tags Preview

    set x0 [expr {$cx-$rad}]
    set y0 [expr {$cy-$rad}]
    set x1 [expr {$cx+$rad}]
    set y1 [expr {$cy+$rad}]
    set start [expr {$sang*$radtodeg}]
    set extent [expr {$dang*$radtodeg}]
    set arccoords [list $x0 $y0 $x1 $y1]
    set arccoords [cadobjects_scale_coords $canv $arccoords]
    $canv create arc $arccoords -start $start -extent $extent -style arc -outline "#7f7fff" -tags Preview
}


proc plugin_unwrap_execute {canv coords isconf} {
    $canv delete Preview
    foreach {cx cy lx0 ly0} $coords break
    if {[llength $coords] < 6} {
        set pang [expr {atan2($ly0-$cy,$lx0-$cx)-$pi/2.0}]
        set perpx [expr {$lx0+cos($pang)}]
        set perpy [expr {$ly0+sin($pang)}]
        lappend coords $perpx $perpy
    }
    foreach {x0 y0 x1 y1 x2 y2} $coords break
    cadobjects_object_unwrap $canv [cadselect_list $canv] $x0 $y0 $x1 $y1 $x2 $y2
}






proc plugin_transforms_register {} {
    tool_register_ex NODEADD "&Nodes" "&Add Node" {
        {1    "Node Add Position"}
    } -icon "tool-nodeadd" -showctls
    tool_register_ex NODEDEL "&Nodes" "&Delete Node" {
        {1    "Node to Delete"}
    } -icon "tool-nodedel" -cursor "top_left_arrow" -snaps {} -showctls
    tool_register_ex SLICE "&Nodes" "&Slice" {
        {1    "Slice Position"}
    } -icon "tool-slice" -showctls
    tool_register_ex REORIENT "&Nodes" "&Change Loop's Start Node" {
        {1    "Node to Reorient Endpoints To."}
    } -icon "tool-reorient" -cursor "top_left_arrow" -snaps {} -showctls
    tool_register_ex CONNECT "&Nodes" "C&onnect" {
        {1    "Start Point"}
        {2    "End Point"}
    } -icon "tool-connect"
    tool_register_ex TRANSLATE "&Transforms" "&Translate" {
        {1    "Reference Point"}
        {2    "Move To"}
    } -icon "tool-translate"
    tool_register_ex ROTATE "&Transforms" "&Rotate" {
        {1    "Center of Rotation"}
        {2    "Reference Point"}
        {3    "Rotate To"}
    } -icon "tool-rotate"
    tool_register_ex SCALE "&Transforms" "&Scale" {
        {1    "Center of Scaling"}
        {2    "Reference Point"}
        {3    "Scale To"}
    } -icon "tool-scale"
    tool_register_ex FLIP "&Transforms" "&Flip" {
        {1    "Start of Line to Flip Across"}
        {2    "End of Line to Flip Across"}
    } -icon "tool-flip"
    tool_register_ex SHEAR "&Transforms" "S&hear" {
        {1    "Center of Shear"}
        {2    "Reference Point"}
        {3    "Shear To"}
    } -icon "tool-shear"
    tool_register_ex BEND "&Transforms" "&Bend" {
        {1    "First Endpoint"}
        {2    "Second Endpoint"}
        {3    "Control Point"}
    } -icon "tool-bend"
    tool_register_ex WRAP "&Transforms" "&Wrap around Center" {
        {1    "Center Point"}
        {2    "Reference Point"}
        {3    "Tangent Point"}
    } -icon "tool-wrap"
    tool_register_ex WRAPTAN "&Transforms" "Wrap by Ta&ngent" {
        {1    "Starting Point"}
        {2    "Tangent Line Point"}
        {3    "Ending Point"}
    } -icon "tool-wraptan"
    tool_register_ex UNWRAP "&Transforms" "&Un-wrap" {
        {1    "Center Point"}
        {2    "Reference Point"}
        {3    "Tangent Point"}
    } -icon "tool-unwrap"
}
plugin_transforms_register 


# vim: set ts=4 sw=4 nowrap expandtab: settings

