############################################################
# Node selection routines
############################################################

proc cadselect_node_list {canv {objid ""}} {
    global selectnodeInfo
    if {$objid == ""} {
        foreach objid [cadselect_list $canv] {
            if {[info exists selectnodeInfo($canv-SELNODES-$objid)]} {
                set objlist($objid) $selectnodeInfo($canv-SELNODES-$objid)
            }
        }
        return [array get objlist]
    } else {
        if {[info exists selectnodeInfo($canv-SELNODES-$objid)]} {
            return $selectnodeInfo($canv-SELNODES-$objid)
        }
        return {}
    }
}


proc cadselect_node_ismember {canv objid nodenum} {
    global selectnodeInfo
    if {[info exists selectnodeInfo($canv-SELNODES-$objid)]} {
        if {$nodenum in $selectnodeInfo($canv-SELNODES-$objid)} {
            return 1
        }
    }
    return 0
}


proc cadselect_node_clear {canv} {
    global selectnodeInfo
    foreach {objid nodes} [cadselect_node_list $canv] {
        foreach nodenum $nodes {
            cadselect_node_remove $canv $objid $nodenum
        }
    }
    $canv dtag SelectedNode SelectedNode
}


proc cadselect_node_clearobj {canv objid} {
    global selectnodeInfo
    if {[info exists selectnodeInfo($canv-SELNODES-$objid)]} {
        set nodes $selectnodeInfo($canv-SELNODES-$objid)
        foreach nodenum $nodes {
            cadselect_node_remove $canv $objid $nodenum
        }
    }
}


proc cadselect_node_drawsel {canv objid nodenum} {
    $canv addtag SelectedNode withtag "Obj_$objid&&Node_$nodenum"
    foreach ntype {rectangle oval diamond endnode} {
        foreach cid [$canv find withtag "CP&&Obj_$objid&&Node_$nodenum&&NType_${ntype}"] {
            $canv itemconfigure $cid -image [cadobjects_get_node_image "${ntype}-sel"]
        }
    }
    foreach cid [$canv find withtag "CL&&Obj_$objid&&Node_$nodenum"] {
        if {[catch {$canv itemconfigure $cid -stroke red}]} {
            $canv itemconfigure $cid -fill red
        }
    }
}


proc cadselect_node_add {canv objid nodenum} {
    global selectnodeInfo
    set nodes {}
    if {[info exists selectnodeInfo($canv-SELNODES-$objid)]} {
        set nodes $selectnodeInfo($canv-SELNODES-$objid)
    }
    if {$nodenum ni $nodes} {
        lappend nodes $nodenum
    }
    set selectnodeInfo($canv-SELNODES-$objid) [lsort -integer $nodes]
    cadselect_node_drawsel $canv $objid $nodenum
}


proc cadselect_node_remove {canv objid nodenum} {
    global selectnodeInfo
    if {[info exists selectnodeInfo($canv-SELNODES-$objid)]} {
        set nodes $selectnodeInfo($canv-SELNODES-$objid)
        set pos [lsearch -exact $nodes $nodenum]
        if {$pos != -1} {
            set nodes [lreplace $nodes $pos $pos]
        }
        set selectnodeInfo($canv-SELNODES-$objid) [lsort -integer $nodes]
    }

    $canv dtag "Obj_$objid&&Node_$nodenum" SelectedNode
    foreach ntype {rectangle oval diamond endnode} {
        foreach cid [$canv find withtag "CP&&Obj_$objid&&Node_$nodenum&&NType_${ntype}"] {
            $canv itemconfigure $cid -image [cadobjects_get_node_image "${ntype}"]
        }
    }
    foreach cid [$canv find withtag "CL&&Obj_$objid&&Node_$nodenum"] {
        if {[catch {$canv itemconfigure $cid -stroke red}]} {
            $canv itemconfigure $cid -fill red
        }
    }
}


proc cadselect_node_toggle {canv objid nodenum} {
    global selectnodeInfo
    if {![cadselect_node_ismember $canv $objid $nodenum]} {
        cadselect_node_add $canv $objid $nodenum
    } else {
        cadselect_node_remove $canv $objid $nodenum
    }
}


proc cadselect_node_toggle_current {canv} {
    global selectnodeInfo
    set cid [$canv find withtag current]
    foreach {objid nodenum} [cadobjects_objid_and_node_from_cid $canv $cid] break
    if {$objid != "" && $nodenum != ""} {
        cadselect_node_toggle $canv $objid $nodenum
    }
}



############################################################
# Object selection routines
############################################################


proc cadselect_list {canv} {
    global selectInfo
    if {![info exists selectInfo($canv-SELOBJS)]} {
        set selectInfo($canv-SELOBJS) {}
    }
    return $selectInfo($canv-SELOBJS)
}


proc cadselect_ismember {canv objid} {
    global selectInfo
    if {[info exists selectInfo($canv-SELOBJ-$objid)]} {
        if {$selectInfo($canv-SELOBJ-$objid)} {
            return 1
        }
    }
    return 0
}


proc cadselect_canv_itemconfigure {canv args} {
    return [$canv itemconfigure {*}$args]
}

proc cadselect_canv_addtag {canv args} {
    return [$canv addtag {*}$args]
}

proc cadselect_canv_find {canv args} {
    return [$canv find {*}$args]
}

proc cadselect_canv_type {canv args} {
    return [$canv type {*}$args]
}

proc cadselect_canv_raise {canv args} {
    return [$canv raise {*}$args]
}

proc cadselect_canv {canv op args} {
    return ["cadselect_canv_$op" $canv {*}$args]
}


proc cadselect_drawsel {canv objid} {
    if {[cadselect_ismember $canv $objid]} {
        set layerid [cadobjects_object_getlayer $canv $objid]
        if {[layer_locked $canv $layerid]} {
            cadselect_remove $canv $objid
            return
        }
        set currtool [tool_current]
        set tooltoken [tool_token $currtool]

        if {[tool_showctls $currtool]} {
            cadobjects_object_draw_controls $canv $objid
        }

        set nodes [cadselect_node_list $canv $objid]
        cadselect_canv $canv addtag Selected withtag "Obj_$objid"
        foreach cid [cadselect_canv $canv find withtag "Obj_$objid&&AllDrawn"] {
            if {[catch {cadselect_canv $canv itemconfigure $cid -outline #ff00ff}]} {
                if {[cadselect_canv $canv type $cid] == "ptext" || [catch {cadselect_canv $canv itemconfigure $cid -stroke #ff00ff}]} {
                    if {[cadselect_canv $canv type $cid] != "pimage"} {
                        cadselect_canv $canv itemconfigure $cid -fill #ff00ff
                    }
                }
            }
        }
        foreach ntype {rectangle oval diamond endnode} {
            cadselect_canv $canv itemconfigure "Selected&&NType_${ntype}&&CP" -image [cadobjects_get_node_image "${ntype}"]
        }
        if {[namespace exists ::tkp]} {
            catch {cadselect_canv $canv itemconfigure "Selected&&CL" -stroke red}
        } else {
            catch {cadselect_canv $canv itemconfigure "Selected&&CL" -fill red}
        }
        foreach node $nodes {
            cadselect_node_drawsel $canv $objid $node
        }
        cadselect_canv $canv raise "Obj_$objid&&CL"
        cadselect_canv $canv raise "Obj_$objid&&NType_oval&&CP"
        cadselect_canv $canv raise "Obj_$objid&&(NType_diamond||NType_rectangle||NType_endnode)&&CP"
        cadselect_canv $canv raise SnapGuide
    }
}


proc cadselect_add {canv objid {dogroups 1}} {
    global selectInfo
    set layerid [cadobjects_object_getlayer $canv $objid]
    if {[layer_locked $canv $layerid]} {
        return
    }
    if {$dogroups} {
        set objgroups [cadobjects_object_getdatum $canv $objid "GROUPS"]
        if {[llength $objgroups] > 0} {
            set objid [lindex $objgroups end]
            cadselect_add $canv $objid $dogroups
            return
        }
    }
    set objtype [cadobjects_object_gettype $canv $objid]
    if {$objtype == "GROUP"} {
        set children [cadobjects_object_getdatum $canv $objid "CHILDREN"]
        foreach child $children {
            cadselect_add $canv $child 0
        }
        return
    }
    if {![cadselect_ismember $canv $objid]} {
        if {![info exists selectInfo($canv-SELOBJS)]} {
            set selectInfo($canv-SELOBJS) {}
        }
        set selectInfo($canv-SELOBJ-$objid) 1
        set objids $selectInfo($canv-SELOBJS)
        lappend objids $objid
        set selectInfo($canv-SELOBJS) [lsort -integer $objids]
    }
    cadselect_drawsel $canv $objid
    cadselect_update_heightwidth $canv $objid
}


proc cadselect_remove {canv objid {dogroups 1}} {
    global selectInfo
    if {$dogroups} {
        set objgroups [cadobjects_object_getdatum $canv $objid "GROUPS"]
        if {[llength $objgroups] > 0} {
            set objid [lindex $objgroups end]
            cadselect_remove $canv $objid $dogroups
            return
        }
    }
    set objtype [cadobjects_object_gettype $canv $objid]
    if {$objtype == "GROUP"} {
        set children [cadobjects_object_getdatum $canv $objid "CHILDREN"]
        foreach child $children {
            cadselect_remove $canv $child 0
        }
        return
    }
    if {[cadselect_ismember $canv $objid]} {
        cadselect_node_clearobj $canv $objid
        unset selectInfo($canv-SELOBJ-$objid)
        set objids $selectInfo($canv-SELOBJS)
        set pos [lsearch -exact $objids $objid]
        set objids [lreplace $objids $pos $pos]
        set selectInfo($canv-SELOBJS) $objids
    }
    $canv dtag "Obj_$objid" Selected
    $canv delete "Obj_$objid&&(CP||CL)"

    set objcolor [cadobjects_object_getdatum $canv $objid "LINECOLOR"]
    if {$objcolor == "" || $objcolor == "none"} {
        set layerid [cadobjects_object_getlayer $canv $objid]
        set objcolor [layer_color $canv $layerid]
    }
    foreach cid [$canv find withtag "AllDrawn&&Obj_$objid"] {
        if {[catch {$canv itemconfigure $cid -outline $objcolor}]} {
            if {[$canv type $cid] == "ptext" || [catch {$canv itemconfigure $cid -stroke $objcolor}]} {
                if {[$canv type $cid] != "pimage"} {
                    $canv itemconfigure $cid -fill $objcolor
                }
            }
        }
    }
    cadselect_update_heightwidth $canv
}


proc cadselect_clear {canv {except ""}} {
    foreach objid [cadselect_list $canv] {
        if {$objid != $except} {
            cadselect_remove $canv $objid
        }
    }
    $canv dtag Selected Selected
    cadselect_update_heightwidth $canv
}


proc cadselect_toggle {canv objid} {
    if {![cadselect_ismember $canv $objid]} {
        cadselect_add $canv $objid
    } else {
        cadselect_remove $canv $objid
    }
}


proc cadselect_toggle_current {canv} {
    set objid ""
    set cid [$canv find withtag current]
    if {$cid == ""} {
        return
    }
    set objid [cadobjects_objid_from_cid $canv $cid]
    if {$objid != ""} {
        cadselect_toggle $canv $objid
    }
}


proc cadselect_update_heightwidth {canv {objid ""}} {
    global selectInfo
    if {![info exists selectInfo(POPAFTPID)]} {
        set selectInfo(POPAFTPID) [after 100 cadselect_update_heightwidth_really $canv $objid]
    }
}


proc cadselect_update_heightwidth_really {canv {objid ""}} {
    global selectInfo
    unset selectInfo(POPAFTPID)
    if {$objid == ""} {
        foreach {x0 y0 x1 y1} [cadobjects_objects_bbox $canv $objid] break
        if {![info exists selectInfo($canv-minx)]} {
            set selectInfo($canv-minx) $x0
            set selectInfo($canv-miny) $y0
            set selectInfo($canv-maxx) $x1
            set selectInfo($canv-maxy) $y1
        } else {
            if {$x0 < $selectInfo($canv-minx)} { set selectInfo($canv-minx) $x0 }
            if {$y0 < $selectInfo($canv-miny)} { set selectInfo($canv-miny) $y0 }
            if {$x1 > $selectInfo($canv-maxx)} { set selectInfo($canv-maxx) $x1 }
            if {$y1 > $selectInfo($canv-maxy)} { set selectInfo($canv-maxy) $y1 }
        }
    } else {
        set bbox [cadselect_bbox $canv]
        if {$bbox != ""} {
            foreach {minx miny maxx maxy} $bbox break
            set selectInfo($canv-minx) $minx
            set selectInfo($canv-miny) $miny
            set selectInfo($canv-maxx) $maxx
            set selectInfo($canv-maxy) $maxy
        } else {
            unset selectInfo($canv-minx)
            unset selectInfo($canv-miny)
            unset selectInfo($canv-maxx)
            unset selectInfo($canv-maxy)
        }
    }
    if {![info exists selectInfo($canv-minx)]} {
        infopane_clear_widthheight .info
    } else {
        set wid [expr {$selectInfo($canv-maxx)-$selectInfo($canv-minx)}]
        set hgt [expr {$selectInfo($canv-maxy)-$selectInfo($canv-miny)}]
        foreach {minorspacing majorspacing superspacing labelspacing divisor units formatfunc conversion} \
            [cadobjects_grid_info $canv] break
        infopane_update_widthheight .info $wid $hgt $units
    }
}


proc cadselect_bbox {canv} {
    set minx ""
    set miny ""
    set maxx ""
    set maxy ""
    foreach objid [cadselect_list $canv] {
        foreach {x0 y0 x1 y1} [cadobjects_objects_bbox $canv $objid] break
        if {$minx == ""} {
            set minx $x0
            set miny $y0
            set maxx $x1
            set maxy $y1
        } else {
            if {$x0 < $minx} { set minx $x0 }
            if {$y0 < $miny} { set miny $y0 }
            if {$x1 > $maxx} { set maxx $x1 }
            if {$y1 > $maxy} { set maxy $y1 }
        }
    }
    if {$minx == ""} {
        return ""
    }
    return [list $minx $miny $maxx $maxy]
}


proc cadselect_redraw_selections {canv} {
    foreach objid [cadselect_list $canv] {
        cadselect_drawsel $canv $objid
    }
    foreach {objid nodes} [cadselect_node_list $canv] {
        foreach nodenum $nodes {
            cadselect_node_drawsel $canv $objid $nodenum
        }
    }
}


proc cadselect_deselect_nonvisible {canv} {
    set currtool [tool_current]
    set tooltoken [tool_token $currtool]

    foreach layerid [layer_ids $canv] {
        if {![layer_visible $canv $layerid]} {
            foreach objid [layer_objects $canv $layerid] {
                cadselect_remove $canv $objid
            }
        }
    }
}


proc cadselect_select_all {canv} {
    set currtool [tool_current]
    set tooltoken [tool_token $currtool]

    foreach layerid [layer_ids $canv] {
        if {[layer_visible $canv $layerid] && ![layer_locked $canv $layerid]} {
            foreach objid [layer_objects $canv $layerid] {
                cadselect_add $canv $objid
                if {$tooltoken == "NODESEL"} {
                    set coords [cadobjects_object_get_coords $canv $objid]
                    set nodes [expr {[llength $coords]/2}]
                    for {set i 1} {$i <= $nodes} {incr i} {
                        cadselect_node_add $canv $objid $i
                    }
                }
            }
        }
    }
}



proc cadselect_select_similar {canv} {
    set currtool [tool_current]
    set tooltoken [tool_token $currtool]

    set objtypes {}
    foreach objid [cadselect_list $canv] {
        set objtype [cadobjects_object_gettype $canv $objid]
        if {$objtype ni $objtypes} {
            lappend objtypes $objtype
        }
    }
    foreach layerid [layer_ids $canv] {
        if {[layer_visible $canv $layerid] && ![layer_locked $canv $layerid]} {
            foreach objid [layer_objects $canv $layerid] {
                set objtype [cadobjects_object_gettype $canv $objid]
                if {$objtype in $objtypes} {
                    cadselect_add $canv $objid
                }
            }
        }
    }
}



# vim: set ts=4 sw=4 nowrap expandtab: settings

