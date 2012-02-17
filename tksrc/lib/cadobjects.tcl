
proc cadobjects_init {canv mainwin} {
    global cadobjectsInfo tkcad_images_dir

    set unitsys [/prefs:get ruler_units]
    if {$unitsys == ""} {
        set unitsys "Inches (Fractions)"
    }
    set cadobjectsInfo($canv-MAINWIN) $mainwin
    set cadobjectsInfo($canv-MODIFIED) 0
    set cadobjectsInfo($canv-MATERIAL) Aluminum
    set cadobjectsInfo($canv-UNITSYS) $unitsys
    set cadobjectsInfo($canv-OBJNUM) 0
    set cadobjectsInfo($canv-OBJECTS) {}

    foreach nodeimg {rectangle oval diamond endnode rectangle-sel oval-sel diamond-sel endnode-sel} {
        set cadobjectsInfo(IMG-$nodeimg) [image create photo -file [file join $tkcad_images_dir "node-${nodeimg}.gif"]]
    }

    cutpaste_canvas_init $canv
    layer_init $canv

    #$canv create rectangle -1000 -1000 1000 1000 -outline white -fill white -tags BG

    cadobjects_set_dpi $canv 110.0
    cadobjects_set_scale_factor $canv 1.0
    $canv xview moveto [expr {0.5-(125.0/2000.0)}]
    $canv yview moveto [expr {0.5-(([winfo screenheight $canv]-300.0)/2000.0)}]

    cadobjects_redraw_grid $canv

    bind $canv <Double-ButtonPress-1> "cadobjects_doubleclick $canv %x %y ; break"
    bind $canv <ButtonPress-1> "cadobjects_buttonpress $canv %x %y ; break"
    bind $canv <ButtonRelease-1> "cadobjects_buttonrelease $canv %x %y ; break"
    bind $canv <Motion> "cadobjects_motion $canv %x %y ; break"
}


proc cadobjects_mark_modified {canv} {
    global cadobjectsInfo
    set cadobjectsInfo($canv-MODIFIED) 1
    set win [cadobjects_mainwin $canv]
    catch {wm attributes $win -modified 1}
}


proc cadobjects_clear_modified {canv} {
    global cadobjectsInfo
    set cadobjectsInfo($canv-MODIFIED) 0
    set win [cadobjects_mainwin $canv]
    catch {wm attributes $win -modified 0}
}


proc cadobjects_is_modified {canv} {
    global cadobjectsInfo
    return $cadobjectsInfo($canv-MODIFIED)
}


proc cadobjects_get_material {canv} {
    global cadobjectsInfo
    return $cadobjectsInfo($canv-MATERIAL)
}


proc cadobjects_set_material {canv mat} {
    global cadobjectsInfo
    if {![catch {mlcnc_define_stock 1.0 1.0 1.0 -material $mat}]} {
        set cadobjectsInfo($canv-MATERIAL) $mat
    }
}



proc cadobjects_get_node_image {nodeimg} {
    global cadobjectsInfo
    return $cadobjectsInfo(IMG-$nodeimg)
}


proc cadobjects_set_dpi {canv dpi} {
    global cadobjectsInfo
    set dpi [expr {0.0+$dpi}]
    set cadobjectsInfo($canv-DPI) $dpi
}


proc cadobjects_get_dpi {canv} {
    global cadobjectsInfo
    return $cadobjectsInfo($canv-DPI)
}


proc cadobjects_set_scale_factor {canv scalefactor} {
    global cadobjectsInfo
    set scalefactor [expr {0.0+$scalefactor}]
    set cadobjectsInfo($canv-SCALEFACTOR) $scalefactor
}


proc cadobjects_set_scale_percent {canv scalepcnt} {
    cadobjects_set_scale_factor $canv [expr {$scalepcnt/100.0}]
}


proc cadobjects_get_scale_factor {canv} {
    global cadobjectsInfo
    return $cadobjectsInfo($canv-SCALEFACTOR)
}


proc cadobjects_get_closeenough {canv objid} {
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set scalemult [expr {$dpi*$scalefactor}]
    set linewidth [cadobjects_object_stroke_width $canv $objid]
    set closeenough [$canv cget -closeenough]
    set closeenough [expr {$closeenough/$scalemult+$linewidth/2.0}]
    return $closeenough
}


proc cadobjects_scale_coords {canv coords} {
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set outcoords {}
    foreach {x y} $coords {
       lappend outcoords [expr  {$dpi*$x*$scalefactor}]
       lappend outcoords [expr {-$dpi*$y*$scalefactor}]
    }
    return $outcoords
}


proc cadobjects_descale_coords {canv coords} {
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set outcoords {}
    foreach {x y} $coords {
       lappend outcoords [expr {$x/($dpi*$scalefactor)}]
       lappend outcoords [expr {$y/(-$dpi*$scalefactor)}]
    }
    return $outcoords
}


proc cadobjects_reset {} {
    global cadobjectsInfo

    set win [mainwin_current]
    set canv [mainwin_get_canvas $win]
    set currtool [tool_current]
    set tooltoken [tool_token $currtool]
    set cursor [tool_cursor $currtool]
    $canv configure -cursor $cursor

    if {[tool_showctls $currtool]} {
        set sellist [cadselect_list $canv]
        foreach objid $sellist {
            cadobjects_object_draw_controls $canv $objid red
        }
    } else {
        cadselect_node_clear $canv
        $canv delete "(CP||CL)"
    }
    $canv delete SnapGuide
    $canv delete Preview

    tool_set_state "INIT"
    if {[info exists cadobjectsInfo($canv-NEWOBJ)]} {
        set objid $cadobjectsInfo($canv-NEWOBJ)
        if {$objid != ""} {
            if {$cadobjectsInfo($canv-NEWHASLASTNODE)} {
                set objtype [cadobjects_object_gettype $canv $objid]
                set nodecount [tool_get_nodecount_from_token $objtype]

                set coords [cadobjects_object_get_coords $canv $objid]
                set coordcount [llength $coords]
                set pos [expr {$coordcount-(($nodecount-1)*2)-1}]
                set coords [lrange $coords 0 $pos]
                if {[llength $coords] >= $nodecount*2} {
                    cadobjects_object_set_coords $canv $objid $coords
                    cadobjects_object_recalculate $canv $objid {CONSTRUCT}
                    cadobjects_object_draw $canv $objid
                } else {
                    cadobjects_object_delete $canv $objid
                }
            }

            set cadobjectsInfo($canv-NEWOBJ) ""
            set cadobjectsInfo($canv-NEWHASLASTNODE) 0
        }
    }
    cadobjects_object_clear_construction_points $canv
    tool_clear_datums $currtool
    cadobjects_tool_clear_coords $canv
    confpane_populate
    cadobjects_update_actionstr
}


proc cadobjects_get_objids_near {canv canvx canvy nearness} {
    set x0 [expr {$canvx-$nearness}]
    set y0 [expr {$canvy-$nearness}]
    set x1 [expr {$canvx+$nearness}]
    set y1 [expr {$canvy+$nearness}]
    set cids [$canv find overlapping $x0 $y0 $x1 $y1]
    foreach cid $cids {
        set objid [cadobjects_objid_from_cid $canv $cid]
        if {$objid != ""} {
            set objarr($objid) 1
        }
    }
    return [array names objarr]
}


proc cadobjects_find_intersections {canv objids rx ry} {
    constants radtodeg

    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set scalemult [expr {$dpi*$scalefactor}]
    set closeenough [$canv cget -closeenough]
    set tolerance 1e-5

    if {[llength $objids] < 2} {
        return ""
    }
    set lpos 1
    set allowed {TEXT ARC BEZIER LINES}
    if {[namespace exists ::tkp]} {
        lappend allowed ROTTEXT
    }
    foreach obj1 [lrange $objids 0 end-1] {
        set linewidth [cadobjects_object_stroke_width $canv $obj1]
        set closeenough [expr {(5+$closeenough)/$scalemult+$linewidth/2.0}]
        foreach {dectype1 data1} [cadobjects_object_decompose $canv $obj1 $allowed] {
            foreach obj2 [lrange $objids $lpos end] {
                foreach {dectype2 data2} [cadobjects_object_decompose $canv $obj2 $allowed] {
                    set p1 [lsearch -exact $allowed $dectype1]
                    set p2 [lsearch -exact $allowed $dectype2]
                    if {$p1 > $p2} {
                        set tmp $data1
                        set data1 $data2
                        set data2 $tmp
                        set tmp $dectype1
                        set dectype1 $dectype2
                        set dectype2 $tmp
                    }
                    switch -exact -- $dectype1 {
                        TEXT -
                        ROTTEXT {
                            # Do nothing.  We ignore text.
                        }
                        ARC {
                            foreach {a_cx a_cy a_rad a_start a_extent} $data1 break
                            if {$dectype2 == "ARC"} {
                                # ARC-ARC
                                foreach {b_cx b_cy b_rad b_start b_extent} $data2 break
                                set cpoints [geometry_find_circles_intersections $a_cx $a_cy $a_rad $b_cx $b_cy $b_rad]
                                if {$cpoints != {}} {
                                    set points {}
                                    foreach {ax ay} $cpoints {
                                        set a_ang [expr {atan2($ay-$a_cy,$ax-$a_cx)*$radtodeg}]
                                        set b_ang [expr {atan2($ay-$b_cy,$ax-$b_cx)*$radtodeg}]
                                        if {$a_ang < $a_start} {
                                            set a_ang [expr {$a_ang+360.0}]
                                        }
                                        if {$a_ang < $a_start + $a_extent} {
                                            if {$b_ang < $b_start} {
                                                set b_ang [expr {$b_ang+360.0}]
                                            }
                                            if {$b_ang < $b_start + $b_extent} {
                                                lappend points $ax $ay
                                            }
                                        }
                                    }
                                    if {$points != {}} {
                                        foreach {ax ay} [geometry_find_closest_point_in_list $rx $ry $points] {
                                            if {hypot($ay-$ry,$ax-$rx) < $closeenough} {
                                                return [list $ax $ay]
                                            }
                                        }
                                    }
                                }
                            } elseif {$dectype2 == "BEZIER"} {
                                # ARC-BEZIER
                                set ret [bezutil_bezier_mindist_segpos $rx $ry $data2 $closeenough 1e-5]
                                if {$ret != ""} {
                                    foreach {seg t} $ret break
                                    set pos1 [expr {$seg*6}]
                                    set pos2 [expr {$pos1+7}]
                                    set coords2 [lrange $data2 $pos1 $pos2]
                                    foreach {ax ay} [bezutil_bezier_segment_point $t {*}$coords2] break
                                    for {set lim 0} {$lim < 10} {incr lim} {
                                        set ang [expr {atan2($ay-$a_cy,$ax-$a_cx)}]
                                        set bx [expr {$a_cx+cos($ang)*$a_rad}]
                                        set by [expr {$a_cy+sin($ang)*$a_rad}]
                                        foreach {ax ay} [bezutil_bezier_segment_nearest_point $bx $by {*}$coords2 $closeenough 1e-5] break
                                        if {hypot($by-$ay,$bx-$ax) < 1e-4} {
                                            if {hypot($ay-$ry,$ax-$rx) < $closeenough} {
                                                return [list $ax $ay]
                                            }
                                        }
                                    }
                                }
                            } else {
                                # ARC-LINES
                                set cpoints [geometry_find_circle_polyline_intersections $a_cx $a_cy $a_rad $data2]
                                if {$cpoints != {}} {
                                    set points {}
                                    foreach {ax ay} $cpoints {
                                        set a_ang [expr {atan2($ay-$a_cy,$ax-$a_cx)*$radtodeg}]
                                        if {$a_ang < $a_start} {
                                            set a_ang [expr {$a_ang+360.0}]
                                        }
                                        if {$a_ang < $a_start + $a_extent} {
                                            lappend points $ax $ay
                                        }
                                    }
                                    if {$points != ""} {
                                        foreach {ax ay} [geometry_find_closest_point_in_list $rx $ry $points] {
                                            if {hypot($ay-$ry,$ax-$rx) < $closeenough} {
                                                return [list $ax $ay]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        BEZIER {
                            if {$dectype2 == "BEZIER"} {
                                # BEZIER-BEZIER
                                set ret1 [bezutil_bezier_mindist_segpos $rx $ry $data1 $closeenough 1e-5]
                                set close [expr {$closeenough*2.0}]
                                if {$ret1 != ""} {
                                    foreach {seg1 t1} $ret1 break
                                    set pos1 [expr {$seg1*6}]
                                    set pos2 [expr {$pos1+7}]
                                    set coords1 [lrange $data1 $pos1 $pos2]
                                    lassign $coords1 sx1 sy1
                                    lassign [lrange $coords1 end-1 end] ex1 ey1
                                    foreach {ax ay} [bezutil_bezier_segment_point $t1 {*}$coords1] break
                                    set ret2 [bezutil_bezier_mindist_segpos $ax $ay $data2 $close 1e-5]
                                    if {$ret2 != ""} {
                                        foreach {seg2 t2} $ret2 break
                                        set pos1 [expr {$seg2*6}]
                                        set pos2 [expr {$pos1+7}]
                                        set coords2 [lrange $data2 $pos1 $pos2]
                                        lassign $coords1 sx2 sy2
                                        lassign [lrange $coords1 end-1 end] ex2 ey2
                                        foreach {ax ay} [bezutil_bezier_segment_point $t2 {*}$coords2] break
                                        for {set lim 0} {$lim < 100} {incr lim} {
                                            set ret1 [bezutil_bezier_segment_nearest_point $ax $ay {*}$coords1 $close 1e-5]
                                            foreach {bx by} $ret1 break
                                            set d1 [expr {hypot($by-$sy1,$bx-$sx1)}]
                                            set d2 [expr {hypot($by-$ey1,$bx-$ex1)}]
                                            if {$d1 < 1e-9 || $d2 < 1e-9} {
                                                if {$d1 < 1e-9} {
                                                    if {$seg1 > 0} {
                                                        incr seg1 -1
                                                    }
                                                } else {
                                                    if {$seg1 < [llength $data1]/6-1} {
                                                        incr seg1
                                                    }
                                                }
                                                set pos1 [expr {$seg1*6}]
                                                set pos2 [expr {$pos1+7}]
                                                set coords1 [lrange $data1 $pos1 $pos2]
                                                lassign $coords1 sx1 sy1
                                                lassign [lrange $coords1 end-1 end] ex1 ey1
                                            }
                                            set ret2 [bezutil_bezier_segment_nearest_point $bx $by {*}$coords2 $close 1e-5]
                                            foreach {ax ay} $ret2 break
                                            set d1 [expr {hypot($ay-$sy2,$ax-$sx2)}]
                                            set d2 [expr {hypot($ay-$ey2,$ax-$ex2)}]
                                            if {$d1 < 1e-9 || $d2 < 1e-9} {
                                                if {$d1 < 1e-9} {
                                                    if {$seg2 > 0} {
                                                        incr seg2 -1
                                                    }
                                                } else {
                                                    if {$seg2 < [llength $data2]/6-1} {
                                                        incr seg2
                                                    }
                                                }
                                                set pos1 [expr {$seg2*6}]
                                                set pos2 [expr {$pos1+7}]
                                                set coords2 [lrange $data2 $pos1 $pos2]
                                                lassign $coords2 sx1 sy1
                                                lassign [lrange $coords2 end-1 end] ex1 ey1
                                            }
                                            if {hypot($by-$ay,$bx-$ax) < 1e-4} {
                                                if {hypot($ay-$ry,$ax-$rx) < $closeenough} {
                                                    return [list $ax $ay]
                                                }
                                            }
                                        }
                                    }
                                }
                            } else {
                                # BEZIER-LINES
                                set ret1 [bezutil_bezier_mindist_segpos $rx $ry $data1 $closeenough 1e-5]
                                if {$ret1 != ""} {
                                    foreach {seg1 t1} $ret1 break
                                    set pos1 [expr {$seg1*6}]
                                    set pos2 [expr {$pos1+7}]
                                    set coords1 [lrange $data1 $pos1 $pos2]
                                    foreach {ax ay} [bezutil_bezier_segment_point $t1 {*}$coords1] break

                                    set ret2 [::math::geometry::findClosestPointOnPolyline [list $ax $ay] $data2]
                                    foreach {ax ay} $ret2 break
                                    for {set lim 0} {$lim < 10} {incr lim} {
                                        set bxy [bezutil_bezier_segment_nearest_point $ax $ay {*}$coords1 $closeenough 1e-5]
                                        if {$bxy != ""} {
                                            foreach {bx by} $bxy break
                                            foreach {ax ay} [::math::geometry::findClosestPointOnPolyline [list $bx $by] $data2] break
                                            if {hypot($by-$ay,$bx-$ax) < 1e-4} {
                                                if {hypot($ay-$ry,$ax-$rx) < $closeenough} {
                                                    return [list $ax $ay]
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        LINES {
                            # LINES-LINES
                            set points [geometry_find_polylines_intersections $data1 $data2]
                            if {$points != ""} {
                                foreach {ax ay} [geometry_find_closest_point_in_list $rx $ry $points] {
                                    if {hypot($ay-$ry,$ax-$rx) < $closeenough} {
                                        return [list $ax $ay]
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        incr lpos
    }
    return {}
}


proc cadobjects_get_objids_along_line {canv canvx0 canvy0 canvx1 canvy1 nearness {stopatfirst 0}} {
    set dx [expr {$canvx1-$canvx0}]
    set dy [expr {$canvy1-$canvy0}]
    set dist [expr {hypot($dy,$dx)}]
    set steps [expr {0.0+ceil($dist/2.0)}]
    set dx [expr {$dx/$steps}]
    set dy [expr {$dy/$steps}]
    for {set i 0} {$i < $steps} {incr i} {
        set x [expr {$canvx0+$dx*$i}]
        set y [expr {$canvx0+$dx*$i}]
        set objids [cadobjects_get_objids_near $canv $x $y $nearness]
        foreach objid $objids {
            if {$stopatfirst} {
                return [list $objid [list $x $y]]
            }
            set objarr($objid) [list $x $y]
        }
    }
    return [array get objarr]
}


proc cadobjects_doubleclick {canv x y} {
    set cid [$canv find withtag current]
    set type "CANV"
    if {$cid != ""} {
        set tags [$canv gettags $cid]
        foreach tag $tags {
            switch -glob -- $tag {
                "CP" {
                    set type "CP"
                }
                "CL" {
                    set type "CL"
                }
                "AllDrawn" {
                    set type "OBJ"
                }
            }
        }
    }
    cadobjects_binding_doubleclick $canv $type $x $y
}


proc cadobjects_buttonpress {canv x y} {
    focus $canv
    set cid [$canv find withtag current]
    set type "CANV"
    if {$cid != ""} {
        set tags [$canv gettags $cid]
        foreach tag $tags {
            switch -glob -- $tag {
                "CP" {
                    set type "CP"
                }
                "CL" {
                    set type "CL"
                }
                "AllDrawn" {
                    set type "OBJ"
                }
            }
        }
    }
    cadobjects_binding_buttonpress $canv $type $x $y
}


proc cadobjects_buttonrelease {canv x y} {
    set cid [$canv find withtag current]
    set type ""
    if {$cid != ""} {
        set tags [$canv gettags $cid]
        foreach tag $tags {
            switch -glob -- $tag {
                "CP" {
                    set type "CP"
                }
                "CL" {
                    set type "CL"
                }
                "Obj_*" {
                    set type "Obj"
                }
            }
        }
    }
    cadobjects_binding_buttonrelease $canv $type $x $y
}


proc cadobjects_motion {canv x y} {
    cadobjects_binding_motion $canv $x $y
}


proc cadobjects_modkey_press {modkey} {
    global cadobjectsInfo
    set cadobjectsInfo(MODKEY-$modkey) 1
    set mods [cadobjects_modkeys_down]
    if {$modkey != "COMMAND"} {
        cadobjects_modkey_preview
    }
}


proc cadobjects_modkey_release {modkey} {
    global cadobjectsInfo
    set cadobjectsInfo(MODKEY-$modkey) 0
    set mods [cadobjects_modkeys_down]
    if {$modkey != "COMMAND"} {
        cadobjects_modkey_preview
    }
}


proc cadobjects_modkey_set {state} {
    global cadobjectsInfo
    set waschange 0
    foreach {mask modkey} {
         1 SHIFT
         4 CONTROL
         8 COMMAND
        16 MOD2
    } {
        set was [cadobjects_modkey_isdown $modkey]
        set isnow [expr {($state&$mask)?1:0}]
        if {$was != $isnow} {
            set cadobjectsInfo(MODKEY-$modkey) $isnow
            set waschange 1
        }
    }
    if {$waschange} {
        set mods [cadobjects_modkeys_down]
        cadobjects_modkey_preview
    }
}


proc cadobjects_modkey_preview {} {
    set win [mainwin_current]
    set canv [mainwin_get_canvas $win]
    set currtool [tool_current]
    set tooltoken [tool_token $currtool]
    set coords [cadobjects_tool_get_coords $canv]
    if {[tool_iscreator $currtool]} {
        global cadobjectsInfo
        if {![info exists cadobjectsInfo($canv-NEWOBJ)]} return
        set newobj $cadobjectsInfo($canv-NEWOBJ)
        if {![cadobjects_object_exists $canv $newobj]} {
            set newobj [set cadobjectsInfo($canv-NEWOBJ) ""]
        }
        if {$newobj != ""} {
            cadobjects_object_recalculate $canv $newobj {CONSTRUCT}
            cadobjects_object_draw $canv $newobj
            cadobjects_object_draw_controls $canv $newobj red
        }
    } else {
        cadobjects_toolcall "preview" $canv $tooltoken $coords 0
    }
}


proc cadobjects_modkey_isdown {modkey} {
    global cadobjectsInfo
    if {![info exists cadobjectsInfo(MODKEY-$modkey)]} {
        return 0
    }
    return $cadobjectsInfo(MODKEY-$modkey)
}


proc cadobjects_modkeys_down {} {
    set mods {}
    foreach modkey {COMMAND CONTROL SHIFT MOD2} {
        if {[cadobjects_modkey_isdown $modkey]} {
            lappend mods $modkey
        }
    }
    return $mods
}


proc cadobjects_rescale_redraw {canv scalefactor} {
    if {$scalefactor < 0.0} {
        error "Cannot rescale to a negative scale factor!"
    }
    constants radtodeg degtorad
    set dpi [cadobjects_get_dpi $canv]
    set osf [cadobjects_get_scale_factor $canv]
    set delta [expr {$scalefactor/$osf}]

    foreach {minorspacing majorspacing superspacing labelspacing divisor units formatfunc conversion} \
        [cadobjects_grid_info $canv] break
    set scalemult [expr {$dpi*$scalefactor/$conversion}]

    $canv delete "SnapGuide"
    $canv scale "(AllDrawn&&!PIMAGE)||CP||CL||Preview" 0 0 $delta $delta
    foreach obj [$canv find withtag AllDrawn] {
        if {[catch {
            set width [$canv itemcget $obj -strokewidth]
            if {$width == 0.5 && $delta > 1.0} {
                set tags [$canv itemcget $obj -tags]
                set pos [lsearch -glob $tags "Obj_*"]
                set wobj [string range [lindex $tags $pos] 4 end]
                set width [cadobjects_object_stroke_width $canv $wobj]
                set width [expr {$dpi*$width*$osf}]
            }
            set width [expr {$width*$delta}]
            if {$width<0.5} {
                set width 0.5
            }
            $canv itemconfigure $obj -strokewidth $width
        }]} {
            if {[$canv type $obj] != "pimage"} {
                catch {
                    set width [$canv itemcget $obj -width]
                    set width [expr {$width*$delta}]
                    $canv itemconfigure $obj -width $width
                }
            }
        }
    }
    foreach obj [$canv find withtag TEXT] {
        set tags [$canv itemcget $obj -tags]
        set pos [lsearch -glob $tags "Obj_*"]
        set objid [string range [lindex $tags $pos] 4 end]
        set font [cadobjects_object_getdatum $canv $objid "FONT"]
        set fsiz [lindex $font 1]
        set fsiz [expr {int($fsiz*$scalefactor*2.153+0.5)}]
        set state normal
        if {$fsiz < 1.0} {
            set fsiz 1
            set state hidden
        }
        set font [lreplace $font 1 1 $fsiz]
        $canv itemconfigure $obj -font $font -state $state
    }

    if {[namespace exists ::tkp]} {
        foreach obj [$canv find withtag PTEXT] {
            set fsiz [$canv itemcget $obj -fontsize]
            set fsiz [expr {$fsiz*$delta}]
            $canv itemconfigure $obj -fontsize $fsiz

            set mat [$canv itemcget $obj -matrix]
            set m1 [lindex $mat 0 0]
            set m2 [lindex $mat 0 1]
            set rotr [expr {atan2($m2,$m1)}]
            if {abs($rotr) > 1e-9} {
                foreach {cx cy} [$canv coords $obj] break
                set mat [::tkp::transform rotate $rotr $cx $cy]
                $canv itemconfigure $obj -matrix $mat
            }
        }
        foreach obj [$canv find withtag PIMAGE] {
            set tags [$canv itemcget $obj -tags]
            set pos [lsearch -glob $tags "Obj_*"]
            set objid [string range [lindex $tags $pos] 4 end]
            foreach {dectype data} [cadobjects_object_decompose $canv $objid "IMAGE"] {
                if {$dectype == "IMAGE"} {
                    foreach {cx cy width height rot img} $data break
                    set radrot [expr {-$rot*$degtorad}]
                    set cx [expr {$cx*$scalefactor*$dpi}]
                    set cy [expr {-$cy*$scalefactor*$dpi}]
                    set width [expr {$width*$scalefactor*$dpi}]
                    set height [expr {$height*$scalefactor*$dpi}]
                    set x0 [expr {$cx-$width/2.0}]
                    set y0 [expr {$cy-$height/2.0}]
                    set x1 [expr {$cx+$width/2.0}]
                    set y1 [expr {$cy+$height/2.0}]
                    set sx $width
                    set sy $height
                    set y1 [expr {$y0-$sy}]
                    if {abs($sx) < 1e-6} { set sx 1e-6 }
                    if {abs($sy) < 1e-6} { set sy 1e-6 }
                    set mat1 [::tkp::transform rotate $radrot 0.0 0.0]
                    set mat2 [::tkp::transform scale $sx $sy]
                    set mat3 [::tkp::transform translate $cx $cy]
                    set mat [::tkp::mmult $mat1 $mat2]
                    set mat [::tkp::mmult $mat3 $mat]
                    $canv itemconfigure $obj -matrix $mat
                    $canv coords $obj -0.5 -0.5
                }
            }
        }
    } else {
        foreach obj [$canv find withtag BEZIER] {
            if {[string toupper [$canv type $obj]] == "LINE"} {
                set dmax 0.0
                set coords [$canv coords $obj]
                foreach {x0 y0} [lrange $coords 0 1] break
                foreach {x1 y1} [lrange $coords 2 end] {
                    set dist [expr {hypot($y1-$y0,$x1-$x0)}]
                    if {$dist > $dmax} {
                        set dmax $dist
                    }
                    set x0 $x1
                    set y0 $y1
                }
                set steps [expr {int($dmax/5.0)}]
                if {$steps < 5} {
                    set steps 5
                }
                $canv itemconfigure $obj -splinesteps $steps
            }
        }
    }
    if {[namespace exists ::tkp]} {
        $canv itemconfigure "ConstLines" -strokewidth 0.75
    } else {
        $canv itemconfigure "ConstLines" -width 1
    }

    cadobjects_set_scale_factor $canv $scalefactor
    cadobjects_redraw_grid $canv
    cadobjects_object_redraw_construction_points $canv
    #cadselect_redraw_selections $canv
}



proc cadobjects_get_unitsystem {canv} {
    global cadobjectsInfo
    return $cadobjectsInfo($canv-UNITSYS)
}



proc cadobjects_set_unitsystem {canv units showfracts} {
    if {$showfracts == "YES"} {
        set showfracts 1
    } elseif {$showfracts == "NO"} {
        set showfracts 0
    } elseif {$showfracts == "1"} {
        set showfracts 1
    } else {
        set showfracts 0
    }
    switch -exact -- [string tolower $units] {
        "inches (decimal)" {
            set unitsys "Inches (Decimal)"
        }
        "inches (fractions)" {
            set unitsys "Inches (Fractions)"
        }
        \" -
        in -
        inches {
            if {$showfracts} {
                set unitsys "Inches (Fractions)"
            } else {
                set unitsys "Inches (Decimal)"
            }
        }
        \' -
        ft -
        feet {
            set unitsys "Feet"
        }
        mm -
        millimeters {
            set unitsys "Millimeters"
        }
        cm -
        centimeters {
            set unitsys "Centimeters"
        }
        m -
        meters {
            set unitsys "Meters"
        }
        default {
            set unitsys "Inches (Fractions)"
        }
    }
    global cadobjectsInfo
    set cadobjectsInfo($canv-UNITSYS) $unitsys
    mainwin_update_unitsys [cadobjects_mainwin $canv]
}



proc cadobjects_unit_system {canv} {
    set units [cadobjects_get_unitsystem $canv]
    set fract 0
    set abbrev "in"
    set mult 1.0
    switch -exact -- $units {
        "Inches (Decimal)"   { set abbrev "in"; set mult 1.0 ; set units "Inches" }
        "Inches (Fractions)" { set abbrev "in"; set mult 1.0 ; set units "Inches" ; set fract 1 }
        "Feet"               { set abbrev "ft"; set mult [expr {1.0/12.0}] }
        "Millimeters"        { set abbrev "mm"; set mult 25.4 }
        "Centimeters"        { set abbrev "cm"; set mult 2.54 }
        "Meters"             { set abbrev "m" ; set mult 0.0254 }
    }
    return [list $units $fract $mult $abbrev]
}


proc cadobjects_grid_info {canv} {
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]

    #set unittype "english_fractions"
    lassign [cadobjects_unit_system $canv] unittype isfract conversion abbrev

    if {$isfract} {
        set formatfunc ruler_format_fractions 
    } else {
        set formatfunc ruler_format_decimal 
    }
    set divisor 1.0
    if {$unittype == "Inches"} {
        if {$isfract} {
            # Proposed: 10ft, 1ft, 1in, 1/4in, 1/16in, 1/64in, 1/256in gridline sets.
            set significants {0.00390625 0.015625 0.0625 0.25 1.0 12.0 120.0 1200.0}
            set unit \"
        } else {
            # Proposed: 10ft, 1ft, 1in, 1/10in, 1/100in, 1/1000in gridline sets.
            set significants {0.001 0.01 0.1 1.0 12.0 120.0 1200.0}
            set unit \"
        }

    } elseif {$unittype == "Feet"} {
        # Proposed: 10ft, 1ft, 1in, 1/4in, 1/16in, 1/64in, 1/256in gridline sets.
        set significants {0.000325520833333 0.001302083333333 0.005208333333333 0.020833333333333 0.083333333333333 1.0 10.0 100.0}
        set formatfunc ruler_format_fractions 
        set unit \'

    } else {
        # Metric
        # Proposed: 10m, 1m, 1dm, 1cm, 1mm, 0.1mm gridline sets.
        set significants {0.0001 0.001 0.01 0.1 1.0 10.0 100.0 1000.0 10000.0 100000.0}
        set unit mm
        set formatfunc ruler_format_decimal 
        switch -exact -- $unittype {
            "Centimeters" { set unit "cm" }
            "Meters"      { set unit "m" }
        }
    }
    set scalemult [expr {$dpi*$scalefactor/$conversion}]

    set minorspacing 0
    set majorspacing 0
    set superspacing 0
    set labelspacing 0

    foreach val $significants {
        if {$minorspacing == 0 && $scalemult*$val >= 8.0} {
            set minorspacing $val
        }
        if {$labelspacing == 0 && $scalemult*$val >= 30.0} {
            set labelspacing $val
        }
        if {$majorspacing == 0 && $minorspacing != 0 && $val / $minorspacing > 2.99} {
            set majorspacing $val
        }
        if {$superspacing == 0 && $majorspacing != 0 && $val / $majorspacing > 1.99} {
            set superspacing $val
            break
        }
    }
    if {$labelspacing * $scalemult > 100.0} {
        set labelspacing [expr {$labelspacing/2.0}]
    }

    return [list $minorspacing $majorspacing $superspacing $labelspacing $divisor $unit $formatfunc $conversion]
}


proc cadobjects_object_create_noundo {canv type coords {data {}} {objid -1} {layerid -1}} {
    global cadobjectsInfo
    cutpaste_suspend_recording $canv
    if {$layerid == -1} {
        set layerid [layer_get_current $canv]
        if {$layerid == -1} {
            set layerid [layer_create $canv]
            layer_set_current $canv $layerid
        }
    }
    if {$objid == -1} {
        set objid [incr cadobjectsInfo($canv-OBJNUM)]
    }
    lappend cadobjectsInfo($canv-OBJECTS) $objid

    set cadobjectsInfo($canv-OBJLAYER-$objid) $layerid
    set cadobjectsInfo($canv-OBJTYPE-$objid) $type
    set cadobjectsInfo($canv-OBJCOORDS-$objid) $coords
    layer_object_add $canv $layerid $objid

    cadobjects_object_init $canv $objid
    foreach {datum def} {FILLCOLOR none LINECOLOR black LINEWIDTH 0.0050 LINEDASH solid CUTBIT inherit CUTDEPTH 0.0000} {
        set value [confpane_get_persistent $canv $datum $def]
        cadobjects_object_setdatum $canv $objid $datum $value
    }
    foreach {datum value} $data {
        cadobjects_object_setdatum $canv $objid $datum $value
        if {$datum == "GROUPS"} {
            if {[llength $value] > 0} {
                set gid [lindex $value end]
                set children [cadobjects_object_getdatum $canv $gid $datum]
                if {$objid ni $children} {
                    lappend children $objid
                    cadobjects_object_setdatum $canv $gid $datum $children
                }
            }
        }
    }
    cadobjects_object_recalculate $canv $objid

    cutpaste_resume_recording $canv
    mainwin_update_layerwin [cadobjects_mainwin $canv]
    cadobjects_object_validate_coords $canv $objid $coords
    return $objid
}


proc cadobjects_object_create {canv type coords {data {}}} {
    set objid [cadobjects_object_create_noundo $canv $type $coords $data]
    cutpaste_remember_creation $canv $objid
    return $objid
}


proc cadobjects_object_delete_noundo {canv objids} {
    global cadobjectsInfo

    cutpaste_suspend_recording $canv
    set objids [cadobjects_topmost_objects $canv $objids]

    set diddel 0
    foreach objid $objids {
        if {[cadobjects_object_exists $canv $objid]} {
            set diddel 1
            set objtype [cadobjects_object_gettype $canv $objid]
            if {$objtype == "GROUP"} {
                set children [cadobjects_object_getdatum $canv $objid "CHILDREN"]
                foreach child $children {
                    cadobjects_object_group_removeobj $canv $child
                    cadobjects_object_delete_noundo $canv $child
                }
            } else {
                set layerid $cadobjectsInfo($canv-OBJLAYER-$objid)
                layer_object_delete $canv $layerid $objid
                cadselect_remove $canv $objid
                unset cadobjectsInfo($canv-OBJTYPE-$objid)
                unset cadobjectsInfo($canv-OBJCOORDS-$objid)
                unset cadobjectsInfo($canv-OBJLAYER-$objid)
                foreach key [array names cadobjectInfo "$canv-OBJDATUM-$objid-*"] {
                    unset cadobjectsInfo($key)
                }
                set pos [lsearch -exact $cadobjectsInfo($canv-OBJECTS) $objid]
                set cadobjectsInfo($canv-OBJECTS) [lreplace $cadobjectsInfo($canv-OBJECTS) $pos $pos]
                $canv delete "Obj_$objid"
            }
        }
    }
    if {$diddel} {
        mainwin_update_layerwin [cadobjects_mainwin $canv]
    }
    cutpaste_resume_recording $canv
}


proc cadobjects_object_delete {canv objids} {
    set objids [cadobjects_topmost_objects $canv $objids]
    foreach objid $objids {
        if {[cadobjects_object_exists $canv $objid]} {
            cutpaste_remember_deletion $canv $objid
        }
    }
    return [cadobjects_object_delete_noundo $canv $objids]
}


proc cadobjects_object_delete_selected {canv} {
    global cadobjectsInfo
    set currtool [tool_current]
    set tooltoken [tool_token $currtool]
    if {$tooltoken == "NODESEL"} {
        set selnodes [cadselect_node_list $canv]
        if {[llength $selnodes] == 0} {
            foreach objid [cadselect_list $canv] {
                cadobjects_object_delete $canv $objid
            }
        } else {
            foreach {objid nodes} $selnodes {
                cadobjects_object_nodes_delete $canv $objid $nodes
            }
        }
    } else {
        if {[tool_iscreator $currtool]} {
            cadobjects_reset
        }
        foreach objid [cadselect_list $canv] {
            cadobjects_object_delete $canv $objid
        }
    }
    confpane_populate
}


proc cadobjects_object_ids {canv} {
    global cadobjectsInfo
    return $cadobjectsInfo($canv-OBJECTS)
}


proc cadobjects_object_exists {canv objid} {
    global cadobjectsInfo
    if {[info exists cadobjectsInfo($canv-OBJTYPE-$objid)]} {
        return 1
    }
    return 0
}


proc cadobjects_object_get_coords {canv objid} {
    global cadobjectsInfo
    return $cadobjectsInfo($canv-OBJCOORDS-$objid)
}


proc cadobjects_object_validate_coords {canv objid coords} {
    return ;# This check makes all sorts of problems

    set typ [cadobjects_object_gettype $canv $objid]
    if {$typ == "LINES"} {
        if {[llength $coords] % 2 != 0} {
            error "Badly formed coords for Line"
        }
    } elseif {$typ == "BEZIER"} {
        if {[llength $coords] % 2 != 0} {
            error "Badly formed coords for Bezier"
        }
        if {([llength $coords]/2) % 3 != 1} {
            error "Bad number of points for Bezier"
        }
    } elseif {$typ == "ARCCTR"} {
        if {[llength $coords] != 6} {
            error "Badly formed coords for ArcCtr"
        }
    }
}


proc cadobjects_object_set_coords {canv objid coords} {
    global cadobjectsInfo
    cutpaste_remember_change $canv $objid
    cadobjects_object_validate_coords $canv $objid $coords
    set cadobjectsInfo($canv-OBJCOORDS-$objid) $coords
    return
}


proc cadobjects_object_get_scaled_coords {canv objid} {
    set coords [cadobjects_object_get_coords $canv $objid]
    return [cadobjects_scale_coords $canv $coords]
}


proc cadobjects_object_coords_append {canv objid coords} {
    global cadobjectsInfo
    if {![cadobjects_object_exists $canv $objid]} {
        error "No such object '$objid'!"
    }
    cutpaste_remember_change $canv $objid
    foreach coord $coords {
        lappend cadobjectsInfo($canv-OBJCOORDS-$objid) $coord
    }
    cadobjects_object_recalculate $canv $objid {CONSTRUCT}
    cadobjects_object_draw $canv $objid
    return [llength $cadobjectsInfo($canv-OBJCOORDS-$objid)]
}


proc cadobjects_object_gettype {canv objid} {
    global cadobjectsInfo
    return $cadobjectsInfo($canv-OBJTYPE-$objid)
}


proc cadobjects_object_settype {canv objid type} {
    global cadobjectsInfo
    cutpaste_remember_change $canv $objid
    if {![cadobjects_object_exists $canv $objid]} {
        error "No such object '$objid'!"
    }
    set cadobjectsInfo($canv-OBJTYPE-$objid) $type
    return
}



proc cadobjects_object_getlayer {canv objid} {
    global cadobjectsInfo
    if {![cadobjects_object_exists $canv $objid]} {
        error "No such object '$objid'!"
    }
    set objtype [cadobjects_object_gettype $canv $objid]
    if {$objtype == "GROUP"} {
        set children [cadobjects_object_getdatum $canv $objid "CHILDREN"]
        if {[llength $children] > 0} {
            return [cadobjects_object_getlayer $canv [lindex $children 0]]
        }
    }
    if {[info exists cadobjectsInfo($canv-OBJLAYER-$objid)]} {
        return $cadobjectsInfo($canv-OBJLAYER-$objid)
    }
    return {}
}


proc cadobjects_object_setlayer {canv objid newlayer} {
    global cadobjectsInfo
    if {![cadobjects_object_exists $canv $objid]} {
        error "No such object '$objid'!"
    }
    cutpaste_remember_change $canv $objid
    if {[info exists cadobjectsInfo($canv-OBJLAYER-$objid)]} {
        set oldlayer $cadobjectsInfo($canv-OBJLAYER-$objid)
        if {$oldlayer != "" && $oldlayer >= 0} {
            layer_object_delete $canv $oldlayer $objid
        }
    }
    set cadobjectsInfo($canv-OBJLAYER-$objid) $newlayer
    layer_object_add $canv $newlayer $objid
    return {}
}

proc cadobjects_object_getdatum {canv objid datum} {
    global cadobjectsInfo
    if {![cadobjects_object_exists $canv $objid]} {
        error "No such object '$objid'!"
    }
    set value ""
    if {[info exists cadobjectsInfo($canv-OBJDATUM-$objid-$datum)]} {
        set value $cadobjectsInfo($canv-OBJDATUM-$objid-$datum)
    }
    return $value
}


proc cadobjects_object_setdatum_noundo {canv objid datum value} {
    global cadobjectsInfo
    if {![cadobjects_object_exists $canv $objid]} {
        error "No such object '$objid'!"
    }
    set cadobjectsInfo($canv-OBJDATUM-$objid-$datum) $value
    return
}


proc cadobjects_object_setdatum {canv objid datum value} {
    global cadobjectsInfo
    if {![cadobjects_object_exists $canv $objid]} {
        error "No such object '$objid'!"
    }
    cutpaste_remember_datum_change $canv $objid $datum
    set cadobjectsInfo($canv-OBJDATUM-$objid-$datum) $value
    return
}


proc cadobjects_object_serialize {canv objid} {
    set out {}
    set type [cadobjects_object_gettype $canv $objid]
    lappend out "objid"  $objid
    lappend out "type"   $type
    lappend out "layer"  [cadobjects_object_getlayer $canv $objid]
    lappend out "coords" [cadobjects_object_get_coords $canv $objid]
    set impfields [tool_get_important_fields $type]
    lappend impfields "FILLCOLOR" "LINECOLOR" "LINEWIDTH" "LINEDASH" "CUTDEPTH" "CUTBIT" "CUTSIDE"
    set impfields [lsort -unique -dictionary -nocase $impfields]
    foreach datum $impfields {
        set val [cadobjects_object_getdatum $canv $objid $datum]
        if {$val != ""} {
            lappend out "datum-$datum" $val
        }
    }
    if {$type == "GROUP"} {
        set children [cadobjects_object_getdatum $canv $objid "CHILDREN"]
        set val {}
        foreach child $children {
            lappend val [cadobjects_object_serialize $canv $child]
        }
        lappend out "children" $val
    }
    return $out
}


proc cadobjects_object_deserialize {canv objid forcenew info} {
    global cadobjectsInfo

    array set data $info
    if {$forcenew} {
        set objid -1
    }
    if {![info exists data(type)]} {
        error "Internal error: serialization contains no object type."
    }
    if {![info exists data(layer)]} {
        error "Internal error: serialization contains no object layer."
    }
    if {![info exists data(coords)]} {
        error "Internal error: serialization contains no object coords."
    }
    if {$objid == ""} {
        set objid $data(objid)
    }
    if {$objid == -1} {
        if {$forcenew} {
            set objid [cadobjects_object_create $canv $data(type) $data(coords) {}]
        } else {
            set objid [cadobjects_object_create_noundo $canv $data(type) $data(coords) {} -1 $data(layer)]
        }
    } elseif {![cadobjects_object_exists $canv $objid]} {
        set objid [cadobjects_object_create_noundo $canv $data(type) $data(coords) {} $objid $data(layer)]
    } else {
        set cadobjectsInfo($canv-OBJTYPE-$objid) $data(type)
        set cadobjectsInfo($canv-OBJCOORDS-$objid) $data(coords)
    }
    foreach datum [array names data "datum-*"] {
        set datname [string range $datum 6 end]
        if {$datname == "GROUPS"} continue
        if {$datname == "CHILDREN"} continue
        set cadobjectsInfo($canv-OBJDATUM-$objid-$datname) $data($datum)
    }
    if {$data(type) == "GROUP"} {
        if {![info exists data(children)]} {
            error "Internal error: serialization of group obj contains no children."
        }
        foreach childinfo $data(children) {
            set child [dict get $childinfo objid]
            set nuobj [cadobjects_object_deserialize $canv $child $forcenew $childinfo]
            cadobjects_object_group_addobj $canv $objid $nuobj
        }
    }
    cadobjects_object_recalculate $canv $objid
    cadobjects_object_draw $canv $objid
    return $objid
}


proc cadobjects_toolcall {cmd canv tooltoken args} {
    set tooltoken [string tolower $tooltoken]
    set cmdname "plugin_${tooltoken}_${cmd}"
    if {[info commands $cmdname] != {}} {
        set res [eval [list $cmdname $canv] $args]
        return [list OK $res]
    }
    return ""
}


proc cadobjects_objcall {cmd canv objid args} {
    set type [cadobjects_object_gettype $canv $objid]
    set type [string tolower $type]
    set cmdname "plugin_${type}_${cmd}"
    if {[info commands $cmdname] != {}} {
        set coords [cadobjects_object_get_coords $canv $objid]
        set res [eval [list $cmdname $canv $objid $coords] $args]
        return [list OK $res]
    }
    return ""
}


proc cadobjects_object_init {canv objid} {
    cadobjects_objcall "initobj" $canv $objid
}


proc cadobjects_object_recalculate {canv objid {flags ""}} {
    cadobjects_objcall "recalculate" $canv $objid $flags
}


# Finds point on object nearest the real coordinates x, y
proc cadobjects_object_nearest_point {canv objid x y} {
    set res [cadobjects_objcall "nearest_point" $canv $objid $x $y]
    if {$res == ""} {
        return {}
    }
    set pt [lindex $res 1]
    return $pt
}


# Returns the object if it is not grouped.  Otherwise returns the outermost group that contains this object.
proc cadobjects_object_get_root {canv objid} {
    while {1} {
        set groupid [cadobjects_object_getgroup $canv $objid]
        if {$groupid == ""} {
            return $objid
        }
        set objid $groupid
    }
}


proc cadobjects_object_getgroup {canv objid} {
    set objgroups [cadobjects_object_getdatum $canv $objid "GROUPS"]
    if {[llength $objgroups] == 0} {
        return {}
    }
    return [lindex $objgroups end]
}


proc cadobjects_object_group_removeobj {canv objid} {
    set group [cadobjects_object_getgroup $canv $objid]
    if {$group == ""} {
        return 0
    }
    set layer [cadobjects_object_getlayer $canv $objid]
    layer_object_add $canv $layer $objid

    set objgroups [cadobjects_object_getdatum $canv $objid "GROUPS"]
    set objgroups [lremove $objgroups $group]
    cadobjects_object_setdatum $canv $objid "GROUPS" $objgroups

    set children [cadobjects_object_getdatum $canv $group "CHILDREN"]
    set children [lremove $children $objid]
    cadobjects_object_setdatum $canv $group "CHILDREN" $children
    if {[llength $children] == 0} {
        cadobjects_object_delete $canv $group
    }

    return 1
}


proc cadobjects_object_group_addobj {canv groupid objid} {
    set objgroups [cadobjects_object_getdatum $canv $objid "GROUPS"]
    if {[llength $objgroups] > 0} {
        error "Object is already part of a group."
    }
    set grptype [cadobjects_object_gettype $canv $groupid]
    if {$grptype != "GROUP"} {
        error "Target group object must be of type GROUP."
    }

    set grplayer [cadobjects_object_getlayer $canv $groupid]
    cadobjects_object_setlayer $canv $objid $grplayer
    layer_object_delete $canv $grplayer $objid

    lappend objgroups $groupid
    cadobjects_object_setdatum $canv $objid "GROUPS" $objgroups

    set children [cadobjects_object_getdatum $canv $groupid "CHILDREN"]
    if {$objid ni $children} {
        lappend children $objid
    }
    cadobjects_object_setdatum $canv $groupid "CHILDREN" $children
    return $groupid
}


proc cadobjects_object_newgroup {canv {objids "SELECTED"}} {
    if {$objids == "SELECTED"} {
        set objids [cadselect_list $canv]
    }
    set objids [cadobjects_topmost_objects $canv $objids]

    set layer ""
    foreach objid $objids {
        set objtype [cadobjects_object_gettype $canv $objid]
        set children [cadobjects_object_getdatum $canv $objid "CHILDREN"]
        set objlayer [cadobjects_object_getlayer $canv $objid]
        if {$layer == ""} {
            set layer $objlayer
        } elseif {$objlayer != $layer} {
            error "All objects being grouped must be in the same layer."
        }
    }

    set groupid [cadobjects_object_create $canv GROUP {} [list CHILDREN {}]]
    if {$layer != ""} {
        cadobjects_object_setlayer $canv $groupid $layer
    }
    foreach objid $objids {
        cadobjects_object_group_addobj $canv $groupid $objid
    }
    return $groupid
}


proc cadobjects_object_ungroup {canv {objids "SELECTED"}} {
    if {$objids == "SELECTED"} {
        set objids [cadselect_list $canv]
    }
    set objids [cadobjects_topmost_objects $canv $objids]
    set groupids {}
    foreach objid $objids {
        set type [cadobjects_object_gettype $canv $objid]
        if {$type == "GROUP"} {
            lappend groupids $objid
        }
    }
    foreach gid $groupids {
        set children [cadobjects_object_getdatum $canv $gid "CHILDREN"]
        foreach child $children {
            cadobjects_object_group_removeobj $canv $child
        }
        cadobjects_object_delete $canv $gid
    }
    return
}




proc cadobjects_object_arrange {canv relpos {objids "SELECTED"}} {
    if {$objids == "SELECTED"} {
        set objids [cadselect_list $canv]
    }
    set objids [cadobjects_topmost_objects $canv $objids]

    set layer ""
    foreach objid $objids {
        set layerid [cadobjects_object_getlayer $canv $objid]
        layer_object_arrange $canv $layerid $objid $relpos
    }
    cadobjects_redraw $canv
}



# Breaks a linear object into two pieces, near the real coordinates x, y
proc cadobjects_object_slice {canv objid x y} {
    set layer [cadobjects_object_getlayer $canv $objid]
    set objcolor [cadobjects_object_getdatum $canv $objid "LINECOLOR"]
    set objfill  [cadobjects_object_getdatum $canv $objid "FILLCOLOR"]
    set linwidth [cadobjects_object_getdatum $canv $objid "LINEWIDTH"]
    set objdash  [cadobjects_object_getdatum $canv $objid "LINEDASH"]
    set cutdepth [cadobjects_object_getdatum $canv $objid "CUTDEPTH"]
    set cutbit   [cadobjects_object_getdatum $canv $objid "CUTBIT"]
    set cutside  [cadobjects_object_getdatum $canv $objid "CUTSIDE"]

    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set scalemult [expr {$dpi*$scalefactor}]
    set closeenough [$canv cget -closeenough]
    set tolerance [expr {1.0/$scalemult}]

    set res [cadobjects_objcall "sliceobj" $canv $objid $x $y]
    if {$res == ""} {
        foreach {dectype coords} [cadobjects_object_decompose $canv $objid {LINES BEZIER}] {
            set linewidth [cadobjects_object_stroke_width $canv $objid]
            set closeval [expr {$closeenough/$scalemult+$linewidth/2.0}]
            switch -exact -- $dectype {
                BEZIER {
                    set beziers [bezutil_bezier_break_near $x $y $coords $closeval $tolerance]
                    set objids {}
                    foreach bez $beziers {
                        if {[llength $bez] <= 0} continue
                        lappend objids [cadobjects_object_create $canv BEZIER $bez]
                    }
                }
                LINES {
                    set plines [bezutil_polyline_break_near $x $y $coords $closeval]
                    set objids {}
                    foreach pline $plines {
                        if {[llength $pline] <= 0} continue
                        lappend objids [cadobjects_object_create $canv LINE $pline]
                    }
                }
                default {
                    error "Internal error: dectype invalid in cadobjects_object_slice"
                }
            }
            cadobjects_object_delete $canv $objid
        }
    } else {
        set objids [lindex $res 1]
    }

    cadselect_clear $canv
    set firstobj 1
    foreach obj $objids {
        cadobjects_object_setdatum $canv $obj "LINECOLOR" $objcolor
        cadobjects_object_setdatum $canv $obj "FILLCOLOR" $objfill
        cadobjects_object_setdatum $canv $obj "LINEWIDTH" $linwidth
        cadobjects_object_setdatum $canv $obj "LINEDASH" $objdash
        cadobjects_object_setdatum $canv $obj "CUTDEPTH" $cutdepth
        cadobjects_object_setdatum $canv $obj "CUTBIT" $cutbit
        cadobjects_object_setdatum $canv $obj "CUTSIDE" $cutside
        cadobjects_object_setlayer $canv $obj $layer

        cadobjects_object_recalculate $canv $obj
        cadobjects_object_draw $canv $obj
        if {!$firstobj} {
            cadobjects_object_draw_controls $canv $obj
            cadselect_add $canv $obj
        }
        set firstobj 0
    }
    mainwin_update_layerwin [cadobjects_mainwin $canv]
    return $objids
}


proc cadobjects_objects_connect {canv obj1 x1 y1 obj2 x2 y2} {
    set objs1 [cadobjects_object_slice $canv $obj1 $x1 $y1]
    set objs2 [cadobjects_object_slice $canv $obj2 $x2 $y2]
    set con1 [cadobjects_object_create $canv LINE [list $x1 $y1 $x2 $y2]]
    set con2 [cadobjects_object_create $canv LINE [list $x2 $y2 $x1 $y1]]

    set o1 [lindex $objs1 0]
    set o2 [lindex $objs1 end]
    set o3 [lindex $objs2 0]
    set o4 [lindex $objs2 end]

    cadselect_clear $canv
    foreach obj [list $o1 $con1 $o3] {
        cadselect_add $canv $obj
    }
    plugin_line_join_selected $canv

    cadselect_clear $canv
    foreach obj [list $o2 $con2 $o4] {
        cadselect_add $canv $obj
    }
    plugin_line_join_selected $canv
    mainwin_update_layerwin [cadobjects_mainwin $canv]
    return $o1
}


proc cadobjects_object_offsetcopy {canv objid offset} {
    set layer [cadobjects_object_getlayer $canv $objid]
    set objcolor [cadobjects_object_getdatum $canv $objid "LINECOLOR"]
    set objfill  [cadobjects_object_getdatum $canv $objid "FILLCOLOR"]
    set linwidth [cadobjects_object_getdatum $canv $objid "LINEWIDTH"]
    set objdash  [cadobjects_object_getdatum $canv $objid "LINEDASH"]
    set cutdepth [cadobjects_object_getdatum $canv $objid "CUTDEPTH"]
    set cutbit   [cadobjects_object_getdatum $canv $objid "CUTBIT"]
    set cutside  [cadobjects_object_getdatum $canv $objid "CUTSIDE"]

    set res [cadobjects_objcall "offsetcopyobj" $canv $objid $offset]
    if {$res == ""} {
        set objids {}
        foreach {dectype coords} [cadobjects_object_decompose $canv $objid {LINES}] {
            if {$dectype != "LINES"} {
                error "Internal error: dectype not LINES in cadobjects_object_offsetcopy"
            }
            foreach pline [mlcnc_path_inset $coords $offset] {
                set nuobj [cadobjects_object_create $canv LINE $pline {}]
                lappend objids $nuobj
            }
        }
    } else {
        set objids [lindex $res 1]
    }

    cadselect_clear $canv
    foreach obj $objids {
        cadobjects_object_setdatum $canv $obj "LINECOLOR" $objcolor
        cadobjects_object_setdatum $canv $obj "FILLCOLOR" $objfill
        cadobjects_object_setdatum $canv $obj "LINEWIDTH" $linwidth
        cadobjects_object_setdatum $canv $obj "LINEDASH" $objdash
        cadobjects_object_setdatum $canv $obj "CUTDEPTH" $cutdepth
        cadobjects_object_setdatum $canv $obj "CUTBIT" $cutbit
        cadobjects_object_setdatum $canv $obj "CUTSIDE" $cutside
        cadobjects_object_setlayer $canv $obj $layer

        cadobjects_object_recalculate $canv $obj
        cadobjects_object_draw $canv $obj
        cadobjects_object_draw_controls $canv $obj
        cadselect_add $canv $obj
    }
    mainwin_update_layerwin [cadobjects_mainwin $canv]
    return $objids
}


# Adds a new node to the given object, near the real coordinates x, y
proc cadobjects_object_node_add {canv objid x y} {
    if {[cadobjects_objcall "addnode" $canv $objid $x $y] == ""} {
        bell
    }
    return
}


proc cadobjects_object_nodes_delete {canv objid nodes} {
    set done 0
    set type [cadobjects_object_gettype $canv $objid]
    set nodecount [tool_get_nodecount_from_token $type]
    set res [cadobjects_objcall "deletenodes" $canv $objid $nodes]
    if {$res != ""} {
        if {[lindex $res 1]} {
            set done 1
        }
    }
    if {!$done} {
        set coords [cadobjects_object_get_coords $canv $objid]
        foreach node [lsort -decreasing -integer $nodes] {
            set pos1 [expr {($node-1)*2}]
            set pos2 [expr {$pos1+1}]
            set coords [lreplace $coords $pos1 $pos2]
        }
        if {[llength $coords]/2 < $nodecount} {
            cadobjects_object_delete $canv $objid
        } else {
            cadobjects_object_set_coords $canv $objid $coords
            cadobjects_object_recalculate $canv $objid
            cadobjects_object_draw $canv $objid
            cadobjects_object_draw_controls $canv $objid
        }
    }
    return
}


proc cadobjects_object_node_reorient {canv objid node} {
    set done 0
    set type [cadobjects_object_gettype $canv $objid]
    set res [cadobjects_objcall "reorientnode" $canv $objid $node]
    if {$res != ""} {
        if {[lindex $res 1]} {
            set done 1
        }
    }
    if {!$done} {
        if {$type ni {LINE BEZIER BEZIERQUAD}} {
            bell
            return
        }

        set coords [cadobjects_object_get_coords $canv $objid]
        foreach {x0 y0} [lrange $coords 0 1] break
        foreach {xe ye} [lrange $coords end-1 end] break
        if {hypot($ye-$y0,$xe-$x0) > 1e-3} {
            bell
            return
        }

        set maxcoord [expr {[llength $coords]/2}]
        if {$node == 1 || $node == $maxcoord} {
            # already at endpoint.
            return
        }

        if {$type == "BEZIER"} {
            if {$node%3 != 1} {
                # Was a control point, not a node point.
                bell
                return
            }
        } elseif {$type == "QUADBEZIER"} {
            if {$node%2 != 1} {
                # Was a control point, not a node point.
                bell
                return
            }
        }
        set pos1 [expr {$node*2-2}]
        set pos2 [expr {$pos1-1}]
        set nucoords [concat [lrange $coords $pos1 end] [lrange $coords 2 $pos2]]
        lappend nucoords [lindex $nucoords 0] [lindex $nucoords 1]

        cadobjects_object_set_coords $canv $objid $nucoords
        if {$type == "BEZIER"} {
            cadobjects_object_setdatum $canv $objid "NODETYPES" ""
        }
        cadobjects_object_recalculate $canv $objid
        cadobjects_object_draw $canv $objid
        cadobjects_object_draw_controls $canv $objid
    }
    return
}


proc cadobjects_object_length {canv objid } {
    set res [cadobjects_objcall "length" $canv $objid $allowed]
    if {$res != ""} {
        return [lindex $res 1]
    }
    return 0
}


# ARC        cx cy rad1      start extent
# ROTARC     cx cy rad1 rad2 start extent rot
# CIRCLE     cx cy rad1
# ELLIPSE    cx cy rad1 rad2
# ELLIPSEROT cx cy rad1 rad2 rot
# RECTANGLE  x0 y0 x1 y1
# BEZIER     coords
# LINES      coords
# TEXT       cx cy txt font just
# ROTTEXT    cx cy txt font just rot
proc cadobjects_object_decompose {canv objid allowed} {
    set res [cadobjects_objcall "decompose" $canv $objid $allowed]
    if {$res != ""} {
        return [lindex $res 1]
    }
    return {}
}


proc cadobjects_grouped_objects {canv {objids "SELECTED"}} {
    if {$objids == "ALL"} {
        set objids [cadobjects_object_ids $canv]
    } elseif {$objids == "SELECTED"} {
        set objids [cadselect_list $canv]
    }
    set outobjs {}
    foreach objid $objids {
        set type [cadobjects_object_gettype $canv $objid]
        if {$type == "GROUP"} {
            set children [cadobjects_object_getdatum $canv $objid "CHILDREN"]
            foreach subobj [cadobjects_grouped_objects $canv $children] {
                lappend outobjs $subobj
            }
        } else {
            lappend outobjs $objid
        }
    }
    return $outobjs
}


proc cadobjects_topmost_objects {canv {objids "SELECTED"}} {
    if {$objids == "ALL"} {
        set objids [cadobjects_object_ids $canv]
    } elseif {$objids == "SELECTED"} {
        set objids [cadselect_list $canv]
    }
    set outobjs {}
    foreach objid $objids {
        if {[cadobjects_object_exists $canv $objid]} {
            set objid [cadobjects_object_get_root $canv $objid]
            if {$objid ni $outobjs} {
                lappend outobjs $objid
            }
        }
    }
    return $outobjs
}


proc cadobjects_objects_bbox {canv {objids "ALL"}} {
    set bbox ""
    if {$objids == "ALL"} {
        set objids [cadobjects_object_ids $canv]
    } elseif {$objids == "SELECTED"} {
        set objids [cadselect_list $canv]
    }
    foreach objid $objids {
        set type     [cadobjects_object_gettype $canv $objid]
        if {$type == "GROUP"} {
            set children [cadobjects_object_getdatum $canv $objid "CHILDREN"]
            set coords [cadobjects_objects_bbox $canv $children]
            if {$coords != {0 0 0 0}} {
                set coords [concat $bbox $coords]
                set bbox [geometry_pointlist_bbox $coords]
            }
        } else {
            set res [cadobjects_objcall "bbox" $canv $objid]
            if {$res != ""} {
                if {[lindex $res 1] != {0 0 0 0}} {
                    if {$bbox == ""} {
                        set bbox [lindex $res 1]
                    } else {
                        set coords [concat $bbox [lindex $res 1]]
                        set bbox [geometry_pointlist_bbox $coords]
                    }
                }
            } else {
                foreach {dectype data} [cadobjects_object_decompose $canv $objid [list "BEZIERS" "LINES"]] {
                    if {$bbox == ""} {
                        set bbox [geometry_pointlist_bbox $data]
                    } else {
                        set coords [concat $bbox $data]
                        set bbox [geometry_pointlist_bbox $coords]
                    }
                }
            }
        }
    }
    if {$bbox == ""} {
        set bbox [list 0 0 0 0]
    }
    return $bbox
}



proc cadobjects_object_align_left {canv objids xpos} {
    set objids [cadobjects_topmost_objects $canv $objids]
    foreach objid $objids {
        foreach {x0 y0 x1 y1} [cadobjects_objects_bbox $canv $objid] break
        set dx [expr {$xpos-$x0}]
        set dy 0.0
        cadobjects_object_translate $canv $objid $dx $dy
    }
}



proc cadobjects_object_align_hcenter {canv objids xpos} {
    set objids [cadobjects_topmost_objects $canv $objids]
    foreach objid $objids {
        foreach {x0 y0 x1 y1} [cadobjects_objects_bbox $canv $objid] break
        set dx [expr {$xpos-(($x1+$x0)/2.0)}]
        set dy 0.0
        cadobjects_object_translate $canv $objid $dx $dy
    }
}



proc cadobjects_object_align_right {canv objids xpos} {
    set objids [cadobjects_topmost_objects $canv $objids]
    foreach objid $objids {
        foreach {x0 y0 x1 y1} [cadobjects_objects_bbox $canv $objid] break
        set dx [expr {$xpos-$x1}]
        set dy 0.0
        cadobjects_object_translate $canv $objid $dx $dy
    }
}



proc cadobjects_object_align_top {canv objids ypos} {
    set objids [cadobjects_topmost_objects $canv $objids]
    foreach objid $objids {
        foreach {x0 y0 x1 y1} [cadobjects_objects_bbox $canv $objid] break
        set dx 0.0
        set dy [expr {$ypos-$y1}]
        cadobjects_object_translate $canv $objid $dx $dy
    }
}



proc cadobjects_object_align_vcenter {canv objids ypos} {
    set objids [cadobjects_topmost_objects $canv $objids]
    foreach objid $objids {
        foreach {x0 y0 x1 y1} [cadobjects_objects_bbox $canv $objid] break
        set dx 0.0
        set dy [expr {$ypos-(($y1+$y0)/2.0)}]
        cadobjects_object_translate $canv $objid $dx $dy
    }
}



proc cadobjects_object_align_bottom {canv objids ypos} {
    set objids [cadobjects_topmost_objects $canv $objids]
    foreach objid $objids {
        foreach {x0 y0 x1 y1} [cadobjects_objects_bbox $canv $objid] break
        set dx 0.0
        set dy [expr {$ypos-$y0}]
        cadobjects_object_translate $canv $objid $dx $dy
    }
}



proc cadobjects_object_edit {canv objid} {
    cadobjects_objcall "usereditobj" $canv $objid
}


proc cadobjects_object_transform {canv objid mat} {
    set done 0
    set res [cadobjects_objcall "transformobj" $canv $objid $mat]
    if {$res != ""} {
        if {[lindex $res 1]} {
            set done 1
        }
    }
    if {!$done} {
        set coords [cadobjects_object_get_coords $canv $objid]
        set coords [matrix_transform_coords $mat $coords]
        cadobjects_object_set_coords $canv $objid $coords
    }
    cadobjects_object_recalculate $canv $objid
    cadobjects_object_draw $canv $objid
}


proc cadobjects_object_flip {canv objids x0 y0 x1 y1} {
    set mat [matrix_reflect_line $x0 $y0 $x1 $y1]
    foreach objid $objids {
        set done 0
        set res [cadobjects_objcall "flipobj" $canv $objid $x0 $y0 $x1 $y1]
        if {$res != ""} {
            if {[lindex $res 1]} {
                set done 1
            }
        }
        if {!$done} {
            set coords [cadobjects_object_get_coords $canv $objid]
            set coords [matrix_transform_coords $mat $coords]
            cadobjects_object_set_coords $canv $objid $coords
        }
        cadobjects_object_recalculate $canv $objid
        cadobjects_object_draw $canv $objid
    }
}


proc cadobjects_object_bend {canv objids lx0 ly0 lx1 ly1 px py} {
    constants pi degtorad

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

    cadselect_clear $canv
    foreach objid $objids {
        set done 0
        set res [cadobjects_objcall "bendobj" $canv $objid $lx0 $ly0 $lx1 $ly1 $px $py]
        if {$res != ""} {
            if {[lindex $res 1]} {
                set done 1
            }
        }
        if {!$done} {
            foreach {dectype data} [cadobjects_object_decompose $canv $objid {BEZIER}] {
                if {$dectype != "BEZIER"} {
                    error "Internal error: dectype not BEZIER in cadobjects_object_bend."
                }
                set path [bezutil_bezier_split_long_segments $data [expr {2.0*$degtorad*$rad}]]
                set joints {}
                foreach {x1 y1 x2 y2 x3 y3} [lrange $path 4 end-4] {
                    if {abs($x1-$x2)+abs($y1-$y2) > 1e-5 && abs($x3-$x2)+abs($y3-$y2) > 1e-5} {
                        lappend joints [geometry_points_are_collinear [list $x1 $y1 $x2 $y2 $x3 $y3] 1e-4]
                    } else {
                        lappend joints 0
                    }
                }
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

                if {[llength $path] >= 14} {
                    set path $nupath
                    set nupath [lrange $path 0 3]
                    foreach {x1 y1 x2 y2 x3 y3} [lrange $path 4 end-4] isstraight $joints {
                        if {$isstraight} {
                            set rad1 [expr {hypot($y2-$y1,$x2-$x1)}]
                            set rad2 [expr {hypot($y3-$y2,$x3-$x2)}]
                            set ang1 [expr {atan2($y2-$y1,$x2-$x1)}]
                            set ang2 [expr {atan2($y3-$y2,$x3-$x2)}]
                            if {$ang1-$ang2 < -$pi} {
                                set ang1 [expr {$ang1+2.0*$pi}]
                            } elseif {$ang1-$ang2 > $pi} {
                                set ang2 [expr {$ang2+2.0*$pi}]
                            }
                            set nuang [expr {($ang1+$ang2)/2.0}]
                            set x1 [expr {$x2-$rad1*cos($nuang)}]
                            set y1 [expr {$y2-$rad1*sin($nuang)}]
                            set x3 [expr {$x2+$rad2*cos($nuang)}]
                            set y3 [expr {$y2+$rad2*sin($nuang)}]
                        }
                        lappend nupath $x1 $y1 $x2 $y2 $x3 $y3
                    }
                    lappend nupath [lindex $path end-3]
                    lappend nupath [lindex $path end-2]
                    lappend nupath [lindex $path end-1]
                    lappend nupath [lindex $path end]
                }

                set nupath [bezutil_bezier_simplify $nupath 1e-4]
                set newobj [cadobjects_object_create $canv BEZIER $nupath {}]
                cadobjects_object_recalculate $canv $newobj
                cadobjects_object_draw $canv $newobj
                cadselect_add $canv $newobj
            }
            cadobjects_object_delete $canv $objid
        }
    }
}


proc cadobjects_object_wrap {canv objids cx cy lx0 ly0 lx1 ly1} {
    constants pi degtorad

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

    cadselect_clear $canv
    foreach objid $objids {
        set done 0
        set res [cadobjects_objcall "wrapobj" $canv $objid $lx0 $ly0 $lx1 $ly1 $cx $cy]
        if {$res != ""} {
            if {[lindex $res 1]} {
                set done 1
            }
        }
        if {!$done} {
            foreach {dectype data} [cadobjects_object_decompose $canv $objid {BEZIER}] {
                if {$dectype != "BEZIER"} {
                    error "Internal error: dectype not BEZIER in cadobjects_object_wrap."
                }
                set path [bezutil_bezier_split_long_segments $data [expr {2.0*$degtorad*$rad}]]
                set joints {}
                foreach {x1 y1 x2 y2 x3 y3} [lrange $path 4 end-4] {
                    if {abs($x1-$x2)+abs($y1-$y2) > 1e-5 && abs($x3-$x2)+abs($y3-$y2) > 1e-5} {
                        lappend joints [geometry_points_are_collinear [list $x1 $y1 $x2 $y2 $x3 $y3] 1e-4]
                    } else {
                        lappend joints 0
                    }
                }
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

                if {[llength $path] >= 14} {
                    set path $nupath
                    set nupath [lrange $path 0 3]
                    foreach {x1 y1 x2 y2 x3 y3} [lrange $path 4 end-4] isstraight $joints {
                        if {$isstraight} {
                            set rad1 [expr {hypot($y2-$y1,$x2-$x1)}]
                            set rad2 [expr {hypot($y3-$y2,$x3-$x2)}]
                            set ang1 [expr {atan2($y2-$y1,$x2-$x1)}]
                            set ang2 [expr {atan2($y3-$y2,$x3-$x2)}]
                            if {$ang1-$ang2 < -$pi} {
                                set ang1 [expr {$ang1+2.0*$pi}]
                            } elseif {$ang1-$ang2 > $pi} {
                                set ang2 [expr {$ang2+2.0*$pi}]
                            }
                            set nuang [expr {($ang1+$ang2)/2.0}]
                            set x1 [expr {$x2-$rad1*cos($nuang)}]
                            set y1 [expr {$y2-$rad1*sin($nuang)}]
                            set x3 [expr {$x2+$rad2*cos($nuang)}]
                            set y3 [expr {$y2+$rad2*sin($nuang)}]
                        }
                        lappend nupath $x1 $y1 $x2 $y2 $x3 $y3
                    }
                    lappend nupath [lindex $path end-3]
                    lappend nupath [lindex $path end-2]
                    lappend nupath [lindex $path end-1]
                    lappend nupath [lindex $path end]
                }

                set nupath [bezutil_bezier_simplify $nupath 1e-4]
                set newobj [cadobjects_object_create $canv BEZIER $nupath {}]
                cadobjects_object_recalculate $canv $newobj
                cadobjects_object_draw $canv $newobj
                cadselect_add $canv $newobj
            }
            cadobjects_object_delete $canv $objid
        }
    }
}


proc cadobjects_object_unwrap {canv objids cx cy lx0 ly0 lx1 ly1} {
    constants pi degtorad

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

    cadselect_clear $canv
    foreach objid $objids {
        set done 0
        set res [cadobjects_objcall "unwrapobj" $canv $objid $lx0 $ly0 $lx1 $ly1 $cx $cy]
        if {$res != ""} {
            if {[lindex $res 1]} {
                set done 1
            }
        }
        if {!$done} {
            foreach {dectype data} [cadobjects_object_decompose $canv $objid {BEZIER}] {
                if {$dectype != "BEZIER"} {
                    error "Internal error: dectype not BEZIER in cadobjects_object_wrap."
                }
                set path [bezutil_bezier_split_long_segments $data [expr {2.0*$degtorad*$rad}]]
                set joints {}
                foreach {x1 y1 x2 y2 x3 y3} [lrange $path 4 end-4] {
                    if {abs($x1-$x2)+abs($y1-$y2) > 1e-5 && abs($x3-$x2)+abs($y3-$y2) > 1e-5} {
                        lappend joints [geometry_points_are_collinear [list $x1 $y1 $x2 $y2 $x3 $y3] 1e-4]
                    } else {
                        lappend joints 0
                    }
                }
                set nupath {}
                foreach {x y} $path {
                    set dy [expr {hypot($y-$cy,$x-$cx)-$rad}]
                    set dx [expr {$sang-(atan2($y-$cy,$x-$cx))*$rad}]
                    set x [expr {$dx*cos($lang)-$dy*sin($lang)+$lx0}]
                    set y [expr {$dx*sin($lang)+$dy*cos($lang)+$ly0}]
                    lappend nupath $x $y
                }

                if {[llength $path] >= 14} {
                    set path $nupath
                    set nupath [lrange $path 0 3]
                    foreach {x1 y1 x2 y2 x3 y3} [lrange $path 4 end-4] isstraight $joints {
                        if {$isstraight} {
                            set rad1 [expr {hypot($y2-$y1,$x2-$x1)}]
                            set rad2 [expr {hypot($y3-$y2,$x3-$x2)}]
                            set ang1 [expr {atan2($y2-$y1,$x2-$x1)}]
                            set ang2 [expr {atan2($y3-$y2,$x3-$x2)}]
                            if {$ang1-$ang2 < -$pi} {
                                set ang1 [expr {$ang1+2.0*$pi}]
                            } elseif {$ang1-$ang2 > $pi} {
                                set ang2 [expr {$ang2+2.0*$pi}]
                            }
                            set nuang [expr {($ang1+$ang2)/2.0}]
                            set x1 [expr {$x2-$rad1*cos($nuang)}]
                            set y1 [expr {$y2-$rad1*sin($nuang)}]
                            set x3 [expr {$x2+$rad2*cos($nuang)}]
                            set y3 [expr {$y2+$rad2*sin($nuang)}]
                        }
                        lappend nupath $x1 $y1 $x2 $y2 $x3 $y3
                    }
                    lappend nupath [lindex $path end-3]
                    lappend nupath [lindex $path end-2]
                    lappend nupath [lindex $path end-1]
                    lappend nupath [lindex $path end]
                }

                set nupath [bezutil_bezier_simplify $nupath 1e-4]
                set newobj [cadobjects_object_create $canv BEZIER $nupath {}]
                cadobjects_object_recalculate $canv $newobj
                cadobjects_object_draw $canv $newobj
                cadselect_add $canv $newobj
            }
            cadobjects_object_delete $canv $objid
        }
    }
}


proc cadobjects_object_translate {canv objid dx dy} {
    set type [cadobjects_object_gettype $canv $objid]
    if {$type == "GROUP"} {
        set children [cadobjects_object_getdatum $canv $objid "CHILDREN"]
        foreach child $children {
            cadobjects_object_translate $canv $child $dx $dy
        }
        return
    }

    set done 0
    set res [cadobjects_objcall "translateobj" $canv $objid $dx $dy]
    if {$res != ""} {
        if {[lindex $res 1]} {
            set done 1
        }
    }
    if {!$done} {
        set newcoords {}
        set coords [cadobjects_object_get_coords $canv $objid]
        foreach {coordx coordy} $coords {
            set nx [expr {$coordx+$dx}]
            set ny [expr {$coordy+$dy}]
            lappend newcoords $nx $ny
        }
        set coords $newcoords
        cadobjects_object_set_coords $canv $objid $coords
    }
    cadobjects_object_recalculate $canv $objid
    cadobjects_object_draw $canv $objid
}


proc cadobjects_object_scale {canv objid sx sy {cx ""} {cy ""}} {
    set type     [cadobjects_object_gettype $canv $objid]
    if {$type == "GROUP"} {
        set children [cadobjects_object_getdatum $canv $objid "CHILDREN"]
        foreach child $children {
            cadobjects_object_scale $canv $child $sx $sy $cx $cy
        }
        return
    }

    if {$cx == "" || $cy == ""} {
        set y1 ""
        foreach {x0 y0 x1 y1} [cadobjects_descale_coords $canv [$canv bbox "Obj_$objid"]] break
        if {$y1 != ""} {
            set cx [expr {($x0+$x1)/2.0}]
            set cy [expr {($y0+$y1)/2.0}]
        } else {
            set cx 0.0
            set cy 0.0
        }
    }

    set done 0
    set res [cadobjects_objcall "scaleobj" $canv $objid $sx $sy $cx $cy]
    if {$res != ""} {
        if {[lindex $res 1]} {
            set done 1
        }
    }
    if {!$done} {
        set newcoords {}
        set coords [cadobjects_object_get_coords $canv $objid]
        foreach {coordx coordy} $coords {
            set nx [expr {($coordx-$cx)*$sx+$cx}]
            set ny [expr {($coordy-$cy)*$sy+$cy}]
            lappend newcoords $nx $ny
        }
        set coords $newcoords
        cadobjects_object_set_coords $canv $objid $coords
    }
    cadobjects_object_recalculate $canv $objid
    cadobjects_object_draw $canv $objid
}


proc cadobjects_object_shear {canv objid sx sy {cx ""} {cy ""}} {
    if {$cx == "" || $cy == ""} {
        set y1 ""
        foreach {x0 y0 x1 y1} [cadobjects_descale_coords $canv [$canv bbox "Obj_$objid"]] break
        if {$y1 != ""} {
            set cx [expr {($x0+$x1)/2.0}]
            set cy [expr {($y0+$y1)/2.0}]
        } else {
            set cx 0.0
            set cy 0.0
        }
    }

    set done 0
    set res [cadobjects_objcall "shearobj" $canv $objid $sx $sy $cx $cy]
    if {$res != ""} {
        if {[lindex $res 1]} {
            set done 1
        }
    }
    if {!$done} {
        set coords [cadobjects_object_get_coords $canv $objid]
        set mat [matrix_skew_xy $sx $sy $cx $cy]
        set coords [matrix_transform_coords $mat $coords]
        cadobjects_object_set_coords $canv $objid $coords
    }
    cadobjects_object_recalculate $canv $objid
    cadobjects_object_draw $canv $objid
}


proc cadobjects_object_rotate {canv objid drot {cx ""} {cy ""}} {
    if {$cx == "" || $cy == ""} {
        foreach {x0 y0 x1 y1} [cadobjects_descale_coords $canv [$canv bbox "Obj_$objid"]] break
        set cx [expr {($x0+$x1)/2.0}]
        set cy [expr {($y0+$y1)/2.0}]
    }

    set done 0
    set res [cadobjects_objcall "rotateobj" $canv $objid $drot $cx $cy]
    if {$res != ""} {
        if {[lindex $res 1]} {
            set done 1
        }
    }
    if {!$done} {
        constants pi
        set rotr [expr {$drot*$pi/180.0}]
        set sinv [expr {sin($rotr)}]
        set cosv [expr {cos($rotr)}]
        set newcoords {}
        set coords [cadobjects_object_get_coords $canv $objid]
        foreach {coordx coordy} $coords {
            set nx [expr {$cosv*($coordx-$cx)-$sinv*($coordy-$cy)+$cx}]
            set ny [expr {$sinv*($coordx-$cx)+$cosv*($coordy-$cy)+$cy}]
            lappend newcoords $nx $ny
        }
        set coords $newcoords
        cadobjects_object_set_coords $canv $objid $coords
    }
    cadobjects_object_recalculate $canv $objid
    cadobjects_object_draw $canv $objid
}


proc cadobjects_object_stroke_width {canv objid} {
    set width [cadobjects_object_getdatum $canv $objid "LINEWIDTH"]
    if {$width == ""} {
        set width 0.005
    } elseif {[string tolower $width] == "thin"} {
        set width 0.0001
    }
    return $width
}


proc cadobjects_object_draw {canv objid {color ""}} {
    global cadobjectsInfo

    set dpi [cadobjects_get_dpi $canv]

    set scalefactor [cadobjects_get_scale_factor $canv]
    set type     [cadobjects_object_gettype $canv $objid]
    set layerid  [cadobjects_object_getlayer $canv $objid]
    set groups   [cadobjects_object_getdatum $canv $objid "GROUPS"]
    set objcolor [cadobjects_object_getdatum $canv $objid "LINECOLOR"]
    set objfill  [cadobjects_object_getdatum $canv $objid "FILLCOLOR"]
    set objdash  [cadobjects_object_getdatum $canv $objid "LINEDASH"]
    set coords   [cadobjects_object_get_coords $canv $objid]

    set nodenum 0

    if {$type == "GROUP"} {
        set coords {}
        set children [cadobjects_object_getdatum $canv $objid "CHILDREN"]
        foreach child $children {
            cadobjects_object_draw $canv $child $color
        }
        return
    }

    set tags [list "AllDrawn" "Layer_$layerid" "Obj_$objid"]
    foreach group $groups {
        lappend tags "Group_$group"
    }

    if {$color == "" || $color == "none"} {
        set layerid [cadobjects_object_getlayer $canv $objid]
        set color [layer_color $canv $layerid]
        if {$objcolor != "" && $objcolor != "none"} {
            set color $objcolor
        }
    }

    set fill $objfill
    if {$objfill == "" || $objfill == "none"} {
        set fill ""
    }

    set width [cadobjects_object_stroke_width $canv $objid]
    set width [expr {$dpi*$width*$scalefactor}]
    if {$width < 0.5} {
        set width 0.5
    }

    set dash {}
    if {$objdash != ""} {
        set dash [dashpat $objdash]
    }

    $canv delete "Obj_$objid"

    set done 0
    set res [cadobjects_objcall "drawobj" $canv $objid $tags $color $fill $width $dash]
    if {$res != ""} {
        if {[lindex $res 1]} {
            set done 1
        }
    }
    if {!$done} {
        cadobjects_object_drawobj_from_decomposition $canv $objid $tags $color $fill $width $dash
        $canv raise "Obj_$objid&&!FILLED"
    }

    cadselect_drawsel $canv $objid
    $canv lower BG
}


proc cadobjects_object_draw_controls {canv objid {color ""}} {
    global cadobjectsInfo

    if {$objid == "all"} {
        foreach layerid [layer_ids $canv] {
            foreach objid [layer_objects $canv $layerid] {
                set groups [cadobjects_object_getdatum $canv $objid "GROUPS"]
                if {$groups == {}} {
                    cadobjects_object_draw_controls $canv $objid $color
                }
            }
        }
        return
    }

    set type   [cadobjects_object_gettype $canv $objid]
    set groups [cadobjects_object_getdatum $canv $objid "GROUPS"]

    set tags [list Obj_$objid]
    foreach group $groups {
        lappend tags "Group_$group"
    }

    if {$color == ""} {
        set color "blue"
    }
    set fillcolor white

    $canv delete "Obj_$objid&&(CP||CL)"

    cadobjects_objcall "drawctls" $canv $objid $color $fillcolor

    switch -exact -- $type {
        GROUP {
            set coords {}
            set children [cadobjects_object_getdatum $canv $objid "CHILDREN"]
            foreach child $children {
                cadobjects_object_draw_controls $canv $child $color
            }
        }
    }
    $canv raise "CL&&Obj_$objid"
    $canv raise "CP&&Obj_$objid&&NType_oval"
    $canv raise "CP&&Obj_$objid&&(NType_diamond||NType_rectangle||NType_endnode)"
    $canv raise SnapGuide
    $canv lower BG
}


proc cadobjects_object_drawobj_from_decomposition {canv objid tags color fill width dash} {
    constants degtorad
    set allowed {ELLIPSE CIRCLE RECTANGLE ARC BEZIER LINES TEXT}
    global tcl_version tcl_patchLevel
    if {($tcl_version >= 8.6 && $tcl_patchLevel != "8.6a0") || [namespace exists ::tkp]} {
        lappend allowed ROTTEXT
    }
    if {[namespace exists ::tkp]} {
        lappend allowed IMAGE
    }
    lappend tags "Actual"
    if {$color == "" || $color == "none"} {
        set layerid [cadobjects_object_getlayer $canv $objid]
        set color [layer_color $canv $layerid]
        if {$color == "" || $color == "none"} {
            set color black
        }
    }
    foreach {dectype data} [cadobjects_object_decompose $canv $objid $allowed] {
        switch -exact -- $dectype {
            ELLIPSE {
                foreach {cx cy rad1 rad2} $data break
                set nutags $tags
                if {$fill != ""} {
                    lappend nutags FILLED
                }
                if {[namespace exists ::tkp]} {
                    set pdash [pathdash $dash]
                    set xyrr [cadobjects_scale_coords $canv [list $cx $cy $rad1 0.0 $rad2 0.0]]
                    foreach {cx cy rad1 dummy rad2 dummy} $xyrr break
                    $canv create ellipse [list $cx $cy] -rx $rad1 -ry $rad2 -tags $nutags -stroke $color -fill $fill -strokewidth $width -strokedasharray $pdash
                } else {
                    set x0 [expr {$cx-$rad1}] 
                    set y0 [expr {$cy-$rad2}] 
                    set x1 [expr {$cx+$rad1}] 
                    set y1 [expr {$cy+$rad2}] 
                    set box [list $x0 $y0 $x1 $y1]
                    set box [cadobjects_scale_coords $canv $box]
                    $canv create oval $box -tags $nutags -outline $color -fill $fill -width $width -dash $dash
                }
            }
            CIRCLE {
                foreach {cx cy rad1} $data break
                set nutags $tags
                if {$fill != ""} {
                    lappend nutags FILLED
                }
                if {[namespace exists ::tkp]} {
                    set pdash [pathdash $dash]
                    set xyr [cadobjects_scale_coords $canv [list $cx $cy $rad1 0.0]]
                    foreach {cx cy rad1 dummy} $xyr break
                    $canv create circle [list $cx $cy] -r $rad1 -tags $nutags -stroke $color -fill $fill -strokewidth $width -strokedasharray $pdash
                } else {
                    set x0 [expr {$cx-$rad1}] 
                    set y0 [expr {$cy-$rad1}] 
                    set x1 [expr {$cx+$rad1}] 
                    set y1 [expr {$cy+$rad1}] 
                    set box [list $x0 $y0 $x1 $y1]
                    set box [cadobjects_scale_coords $canv $box]
                    $canv create oval $box -tags $nutags -outline $color -fill $fill -width $width -dash $dash
                }
            }
            RECTANGLE {
                set box [cadobjects_scale_coords $canv $data]
                set nutags $tags
                if {$fill != ""} {
                    lappend nutags FILLED
                }
                if {[namespace exists ::tkp]} {
                    foreach {x0 y0 x1 y1} $box break
                    set pdash [pathdash $dash]
                    $canv create polyline [list $x0 $y0  $x1 $y0  $x1 $y1  $x0 $y1  $x0 $y0] -tags $nutags -fill $fill -stroke $color -strokewidth $width -strokedasharray $pdash
                } else {
                    $canv create rectangle $box -tags $nutags -outline $color -fill $fill -width $width -dash $dash
                }
            }
            ARC {
                foreach {cx cy rad1 start extent} $data break
                if {[namespace exists ::tkp]} {
                    set pdash [pathdash $dash]
                    if {abs($extent) >= 359.999999} {
                        set xyr [cadobjects_scale_coords $canv [list $cx $cy $rad1 0.0]]
                        foreach {cx cy rad1 dummy} $xyr break
                        $canv create circle [list $cx $cy] -r $rad1 -tags $tags -stroke $color -fill "" -strokewidth $width -strokedasharray $pdash
                    } else {
                        set x0 [expr {$rad1*cos($start*$degtorad)+$cx}]
                        set y0 [expr {$rad1*sin($start*$degtorad)+$cy}]
                        set x1 [expr {$rad1*cos(($start+$extent)*$degtorad)+$cx}]
                        set y1 [expr {$rad1*sin(($start+$extent)*$degtorad)+$cy}]
                        set acoords [cadobjects_scale_coords $canv [list $x0 $y0 $x1 $y1 $rad1 0.0]]
                        foreach {x0 y0 x1 y1 rad1 dummy} $acoords break
                        set la [expr {abs($extent)>=180.0?1:0}]
                        set sw [expr {$extent<0?1:0}]
                        set d [list "M" $x0 $y0 "A" $rad1 $rad1 0.0 $la $sw $x1 $y1]
                        $canv create path $d -fill "" -fillrule evenodd -stroke $color -strokewidth $width -strokelinecap round -strokelinejoin round -strokedasharray $pdash -tags $tags
                    }
                } else {
                    set x0 [expr {$cx-$rad1}] 
                    set y0 [expr {$cy-$rad1}] 
                    set x1 [expr {$cx+$rad1}] 
                    set y1 [expr {$cy+$rad1}] 
                    set box [list $x0 $y0 $x1 $y1]
                    set box [cadobjects_scale_coords $canv $box]
                    $canv create arc $box -style arc -start $start -extent $extent -tags $tags -outline $color -width $width -dash $dash
                }
            }
            BEZIER {
                if {[llength $data] >= 8} {
                    set beztags $tags
                    lappend beztags BEZIER
                    set path [cadobjects_scale_coords $canv $data]
                    set pathfill ""
                    if {[geometry_path_is_closed $path]} {
                        set pathfill $fill
                        if {$fill != ""} {
                            lappend beztags FILLED
                        }
                    }
                    if {[namespace exists ::tkp]} {
                        set pdash [pathdash $dash]
                        set d {}
                        foreach {x0 y0} [lrange $path 0 1] break
                        lappend d M $x0 $y0
                        foreach {x1 y1 x2 y2 x3 y3} [lrange $path 2 end] {
                            lappend d C $x1 $y1 $x2 $y2 $x3 $y3
                        }
                        $canv create path $d -fill $pathfill -fillrule evenodd -stroke $color -strokewidth $width -strokelinecap round -strokelinejoin round -strokedasharray $pdash -tags $beztags
                    } else {
                        if {$pathfill == ""} {
                            $canv create line $path -smooth raw -splinesteps 40 -capstyle round -joinstyle round -tags $beztags -fill $color -width $width -dash $dash
                        } else {
                            $canv create polygon $path -smooth raw -splinesteps 40 -joinstyle round -tags $beztags -fill $pathfill -outline $color -width $width -dash $dash
                        }
                    }
                }
            }
            LINES {
                if {[llength $data] >= 4} {
                    set path [cadobjects_scale_coords $canv $data]
                    set pathfill ""
                    set nutags $tags
                    if {[geometry_path_is_closed $path]} {
                        set pathfill $fill
                        if {$pathfill != "" && $pathfill != "none"} {
                            lappend nutags FILLED
                        }
                    }
                    if {[namespace exists ::tkp]} {
                        set pdash [pathdash $dash]
                        if {$pathfill == ""} {
                            $canv create polyline $path -strokelinejoin round -strokelinecap round -tags $nutags -stroke $color -strokewidth $width -strokedasharray $pdash
                        } else {
                            set d {}
                            foreach {x0 y0} [lrange $path 0 1] break
                            lappend d M $x0 $y0
                            foreach {x1 y1} [lrange $path 2 end] {
                                lappend d L $x1 $y1
                            }
                            $canv create path $d -fill $pathfill -fillrule evenodd -stroke $color -strokewidth $width -strokelinecap round -strokelinejoin round -strokedasharray $pdash -tags $nutags
                        }
                    } else {
                        if {$pathfill == ""} {
                            $canv create line $path -joinstyle round -capstyle round -tags $nutags -fill $color -width $width -dash $dash
                        } else {
                            $canv create polygon $path -joinstyle round -tags $nutags -fill $pathfill -outline $color -width $width -dash $dash
                        }
                    }
                }
            }
            IMAGE {
                foreach {cx cy wid height rot img} $data break
                foreach {cx cy wid height} [cadobjects_scale_coords $canv [list $cx $cy $wid $height]] break
                set radrot [expr {-$rot*$degtorad}]
                set x0 [expr {$cx-$wid/2.0}]
                set y0 [expr {$cy-$height/2.0}]
                set x1 [expr {$cx+$wid/2.0}]
                set y1 [expr {$cy+$height/2.0}]
                set height [expr {-$height}]
                set sx $wid
                set sy $height
                set y1 [expr {$y0-$sy}]
                if {abs($sx) < 1e-6} { set sx 1e-6 }
                if {abs($sy) < 1e-6} { set sy 1e-6 }
                set mat1 [::tkp::transform rotate $radrot 0.0 0.0]
                set mat2 [::tkp::transform scale $sx $sy]
                set mat3 [::tkp::transform translate $cx $cy]
                set mat [::tkp::mmult $mat1 $mat2]
                set mat [::tkp::mmult $mat3 $mat]
                set obj [$canv create pimage -0.5 -0.5 \
                            -matrix $mat -tags [concat $tags PIMAGE] \
                            -width 1.0 -height 1.0 \
                            -image $img]
                $canv lower $obj AllDrawn
                set pts [list $x0 $y0  $x1 $y0  $x1 $y1  $x0 $y1  $x0 $y0]
                set mat [matrix_transform rotate [expr {-$rot}] $cx $cy]
                set pts [matrix_transform_coords $mat $pts]
                $canv create polyline $pts -tags $tags -fill "" -stroke $color -strokewidth 0.5
            }
            TEXT {
                foreach {cx cy txt font just} $data break
                foreach {cx cy} [cadobjects_scale_coords $canv [list $cx $cy]] break
                switch -exact -- $just {
                    left { set anchor sw }
                    center { set anchor s }
                    right { set anchor se }
                    default { set anchor sw }
                }
                set fsiz [lindex $font 1]
                set scalefact [cadobjects_get_scale_factor $canv]
                set fsiz [expr {int($fsiz*$scalefact*2.153+0.5)}]
                set state normal
                if {$fsiz < 1.0} {
                    set fsiz 1
                    set state hidden
                }
                set font [lreplace $font 1 1 $fsiz]
                set descent [font metrics $font -descent]
                set cy [expr {int($cy+$descent+0.5)}]
                $canv create text $cx $cy -text $txt -font $font \
                    -tags [concat $tags TEXT] -fill $color -anchor $anchor -state $state
            }
            ROTTEXT {
                foreach {cx cy txt font just rot} $data break
                foreach {cx cy} [cadobjects_scale_coords $canv [list $cx $cy]] break
                lset font 1 [expr {int(0.5+[lindex $font 1])}]
                array set fontinfo [font actual $font]
                set ffam $fontinfo(-family)
                set fsiz $fontinfo(-size)
                set scalefact [cadobjects_get_scale_factor $canv]
                if {[namespace exists ::tkp]} {
                    set fsiz [expr {$fsiz*$scalefact*2.153}]
                    set tjust "start"
                    switch -exact -- $just {
                        center { set tjust "middle" }
                        right  { set tjust "end" }
                    }
                    set radrot [expr {-$rot*$degtorad}]
                    set mat [::tkp::transform rotate $radrot $cx $cy]
                    $canv create ptext $cx $cy -text $txt \
                        -fontfamily $ffam -fontsize $fsiz \
                        -matrix $mat -tags [concat $tags PTEXT] \
                        -fill $color -textanchor $tjust
                } else {
                    set fsiz [expr {int($fsiz*$scalefact*2.153+0.5)}]
                    set state normal
                    if {$fsiz < 1.0} {
                        set fsiz 1
                        set state hidden
                    }
                    switch -exact -- $just {
                        left { set anchor sw }
                        center { set anchor s }
                        right { set anchor se }
                        default { set anchor sw }
                    }
                    set font [lreplace $font 1 1 $fsiz]
                    set descent [font metrics $font -descent]
                    set cx [expr {int($cx+$descent*sin($rot*$degtorad)+0.5)}]
                    set cy [expr {int($cy+$descent*cos($rot*$degtorad)+0.5)}]
                    $canv create text $cx $cy -text $txt -font $font -angle $rot \
                        -tags [concat $tags TEXT] -fill $color -anchor $anchor -state $state
                }
            }
        }
    }
}


proc cadobjects_object_cutbit {canv objid} {
    set cutbit [cadobjects_object_getdatum $canv $objid "CUTBIT"]
    if {$cutbit == "" || $cutbit == "inherit"} {
        set layerid [cadobjects_object_getlayer $canv $objid]
        set layerbit [layer_cutbit $canv $layerid]
        set cutbit $layerbit
    }
    return $cutbit
}


proc cadobjects_redraw_grid {canv {color ""}} {
    set xsize 36.0
    set ysize 36.0

    #set gridcolor "#8fefef"
    set supercolor [color_from_hsv 195.0 0.5 1.0]
    set unitcolor  [color_from_hsv 180.0 0.5 1.0]
    if {$color != ""} {
        set unitcolor $color
    }

    lassign [color_to_hsv $unitcolor] hue sat val
    set gridcolor [color_from_hsv $hue [expr {0.4*$sat}] $val]

    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set lwidth 0.5

    foreach {minorspacing majorspacing superspacing labelspacing divisor units formatfunc conversion} \
        [cadobjects_grid_info $canv] break

    set scalemult [expr {$dpi*$scalefactor/$conversion}]

    set srx0 [$canv canvasx 0]
    set sry0 [$canv canvasy 0]
    set srx1 [$canv canvasx [winfo width $canv]]
    set sry1 [$canv canvasy [winfo height $canv]]

    set sfx [expr {$xsize*$dpi*$scalefactor}]
    set sfy [expr {$ysize*$dpi*$scalefactor}]
    set rgn [list -$sfx -$sfy $sfx $sfy]
    if {$rgn != [$canv cget -scrollregion]} {
        $canv configure -scrollregion [list -$sfx -$sfy $sfx $sfy]
    }

    set xstart [expr {$srx0/$scalemult}]
    set xend   [expr {$srx1/$scalemult}]

    set ystart [expr {$sry1/-$scalemult}]
    set yend   [expr {$sry0/-$scalemult}]

    $canv coords BG [list $srx0 $sry0 $srx1 $sry1]

    $canv delete Grid
    $canv delete GridOrigin
    if {[/prefs:get show_origin]} {
        $canv create line 0 0 0 -$dpi -fill green -tags GridOrigin -arrow last -width $lwidth
        $canv create line 0 0 $dpi 0 -fill red -tags GridOrigin -arrow last -width $lwidth
    }

    if {[/prefs:get show_grid]} {
        set gx [expr {floor($xstart/$minorspacing+1e-6)*$minorspacing}]
        for {} {$gx <= $xend} {set gx [expr {$gx+$minorspacing}]} {
            if {abs($gx/$superspacing-floor($gx/$superspacing+1e-6)) < 1e-3} {
                set color $supercolor
                set tags "Grid GridUnitLine"
            } elseif {abs($gx/$majorspacing-floor($gx/$majorspacing+1e-6)) < 1e-3} {
                set color $unitcolor
                set tags "Grid GridUnitLine"
            } else {
                set color $gridcolor
                set tags "Grid GridLine"
            }
            set gcx [expr {$gx*$scalemult}]
            $canv create line $gcx $sry0 $gcx $sry1 -tags $tags -fill $color -width $lwidth
        }

        set gy [expr {floor($ystart/$minorspacing+1e-6)*$minorspacing}]
        for {} {$gy <= $yend} {set gy [expr {$gy+$minorspacing}]} {
            if {abs($gy/$superspacing-floor($gy/$superspacing+1e-6)) < 1e-3} {
                set color $supercolor
                set tags "Grid GridUnitLine"
            } elseif {abs($gy/$majorspacing-floor($gy/$majorspacing+1e-6)) < 1e-3} {
                set color $unitcolor
                set tags "Grid GridUnitLine"
            } else {
                set color $gridcolor
                set tags "Grid GridLine"
            }
            set gcy [expr {$gy*-$scalemult}]
            $canv create line $srx0 $gcy $srx1 $gcy -tags $tags -fill $color -width $lwidth
        }
    }

    $canv lower GridUnitLine
    $canv lower GridLine
    $canv lower BG

    catch {$canv raise GridOrigin GridUnitLine}
}


proc cadobjects_redraw {canv {color ""}} {
    $canv delete "AllDrawn||CP||CL"
    cadobjects_redraw_grid $canv
    foreach layerid [layer_ids $canv] {
        if {[layer_visible $canv $layerid]} {
            foreach objid [layer_objects $canv $layerid] {
                set groups [cadobjects_object_getdatum $canv $objid "GROUPS"]
                if {$groups == {}} {
                    cadobjects_object_draw $canv $objid $color
                } else {
                    set children [cadobjects_object_getdatum $canv $objid "CHILDREN"]
                    foreach child $children {
                        cadobjects_object_draw_controls $canv $child $color
                    }
                }
            }
        }
    }
    cadobjects_object_redraw_construction_points $canv
}


proc cadobjects_filter_cids_for_control_points {canv cids} {
    set out {}
    foreach cid $cids {
        set tags [$canv gettags $cid]
        foreach tag $tags {
            if {$tag == "CP"} {
                lappend out $cid
            }
        }
    }
    return $out
}


proc cadobjects_objid_and_node_from_cid {canv cid} {
    set objid ""
    set nodenum ""
    set tags [$canv gettags $cid]
    foreach tag $tags {
        switch -glob -- $tag {
            Obj_* {
                set objid [string range $tag 4 end]
            }
            Node_* {
                set nodenum [string range $tag 5 end]
            }
        }
    }
    return [list $objid $nodenum]
}



proc cadobjects_objid_from_cid {canv cid} {
    set objid ""
    set nodenum ""
    set tags [$canv gettags $cid]
    foreach tag $tags {
        switch -glob -- $tag {
            Obj_* {
                set objid [string range $tag 4 end]
            }
            Node_* {
                set nodenum [string range $tag 5 end]
            }
        }
    }
    return $objid
}



proc cadobjects_tool_set_coord {canv num x y} {
    global cadobjectsInfo
    set cadobjectsInfo($canv-NEWNODE-$num) [list $x $y]
    set toolid [tool_current]
    tool_setdatum $toolid $num [list $x $y]
    return
}



proc cadobjects_tool_set_coords {canv coords} {
    global cadobjectsInfo
    set i 1
    foreach {nx ny} $coords {
        cadobjects_tool_set_coord $canv $i $nx $ny
        incr i
    }
    return
}



proc cadobjects_tool_get_coords {canv} {
    global cadobjectsInfo

    set currtool [tool_current]
    set nodeinfo [tool_nodeinfo $currtool]
    set nodecount [llength $nodeinfo]
    set endnode [lindex [lindex $nodeinfo end] 0]
    if {$endnode == "..."} {
        incr nodecount -1
    }

    set coords {}
    for {set i 1} {$i <= $nodecount} {incr i} {
        set nx ""
        catch {
            foreach {nx ny} $cadobjectsInfo($canv-NEWNODE-$i) break
        }
        if {$nx != ""} {
            lappend coords $nx $ny
        }
    }
    return $coords
}



proc cadobjects_tool_clear_coords {canv} {
    global cadobjectsInfo

    set currtool [tool_current]
    set nodeinfo [tool_nodeinfo $currtool]
    set nodecount [llength $nodeinfo]
    set endnode [lindex [lindex $nodeinfo end] 0]
    if {$endnode == "..."} {
        incr nodecount -1
    }

    for {set i 1} {$i <= $nodecount} {incr i} {
        set cadobjectsInfo($canv-NEWNODE-$i) ""
    }
    return
}



proc cadobjects_update_actionstr {} {
    set toolstate [tool_get_state]
    if {$toolstate == "INIT"} {
        set toolstate 1
    }
    if {[string is integer $toolstate]} {
        set currtool [tool_current]
        set nodeinfo [tool_nodeinfo $currtool]
        set actstr [lindex [lindex $nodeinfo [expr {$toolstate-1}]] 1]
        infopane_update_actionstr .info $actstr
    }
}



proc cadobjects_get_prev_point {canv} {
    global cadobjectsInfo
    if {![info exists cadobjectsInfo($canv-PREVPOINT)]} {
        set cadobjectsInfo($canv-PREVPOINT) ""
    }
    return $cadobjectsInfo($canv-PREVPOINT)
}



proc cadobjects_gather_points {canv x y advance} {
    global cadobjectsInfo
    set currtool [tool_current]
    set tooltoken [tool_token $currtool]
    set nodeinfo [tool_nodeinfo $currtool]
    set nodecount [llength $nodeinfo]
    set toolstate [tool_get_state]
    if {$toolstate == "INIT"} {
        set cadobjectsInfo($canv-NEWHASLASTNODE) 0
        set nodenum [lindex [lindex $nodeinfo 0] 0]
        cadobjects_tool_set_coord $canv $nodenum $x $y
        set cadobjectsInfo($canv-NEWOBJ) ""
        set toolstate 1
    } elseif {[string is integer $toolstate]} {
        set nodenum [lindex [lindex $nodeinfo [expr {$toolstate-1}]] 0]
        cadobjects_tool_set_coord $canv $nodenum $x $y
    }
    set endnode [lindex [lindex $nodeinfo end] 0]
    if {$endnode == "..."} {
        incr nodecount -1
    }
    if {[tool_iscreator $currtool]} {
        if {$toolstate == $nodecount} {
            set newobj $cadobjectsInfo($canv-NEWOBJ)
            if {$newobj == ""} {
                set coords [cadobjects_tool_get_coords $canv]
                cadobjects_tool_clear_coords $canv
                set newobj [cadobjects_object_create $canv $tooltoken $coords {}]
                set cadobjectsInfo($canv-NEWOBJ) $newobj
                set cadobjectsInfo($canv-NEWHASLASTNODE) 1
                cadobjects_object_recalculate $canv $newobj {CONSTRUCT}
                cadobjects_object_draw $canv $newobj
                # TODO: The edit maybe should be at any stage after creation
                #        instead of the first stage.
                cadobjects_object_edit $canv $newobj
            } else {
                if {!$cadobjectsInfo($canv-NEWHASLASTNODE)} {
                    set coords [cadobjects_tool_get_coords $canv]
                    cadobjects_tool_clear_coords $canv
                    cadobjects_object_coords_append $canv $newobj [lrange $coords 2 end]
                    set cadobjectsInfo($canv-NEWHASLASTNODE) 1
                } else {
                    set fullcoords [cadobjects_object_get_coords $canv $newobj]
                    set coordcount [expr {[llength $fullcoords]/2}]
                    set repnode [lindex [lindex $nodeinfo [expr {$toolstate-1}]] 0]
                    set repnode [expr {$coordcount-$nodecount+$repnode}]
                    set pos1 [expr {($repnode-1)*2}]
                    set pos2 [expr {$pos1+1}]
                    set fullcoords [lreplace $fullcoords $pos1 $pos2 $x $y]
                    # We do NOT need to track every drag change to the
                    #   object during its creation.
                    cutpaste_suspend_recording $canv
                    cadobjects_object_set_coords $canv $newobj $fullcoords
                    cadobjects_object_recalculate $canv $newobj {CONSTRUCT}
                    cadobjects_object_draw $canv $newobj
                    cutpaste_resume_recording $canv
                }
            }
            if {$advance} {
                if {$endnode == "..."} {
                    set toolstate 2
                    cadobjects_tool_set_coord $canv 1 $x $y
                    set cadobjectsInfo($canv-PREVPOINT) [list $x $y]
                } else {
                    set toolstate "INIT"
                    set cadobjectsInfo($canv-PREVPOINT) ""
                }
                set cadobjectsInfo($canv-NEWHASLASTNODE) 0
            }

            cadobjects_object_clear_construction_points $canv
            cadselect_clear $canv
            cadselect_add $canv $newobj
            cadobjects_object_draw_controls $canv $newobj red
            confpane_populate
        } else {
            set cadobjectsInfo($canv-NEWHASLASTNODE) 0
            cadobjects_object_draw_construction_point $canv $x $y
            if {$advance} {
                set cadobjectsInfo($canv-PREVPOINT) [list $x $y]
                incr toolstate
            }
        }
    } else {
        # Not an object creator.
        set coords [cadobjects_tool_get_coords $canv]
        if {$advance} {
            if {$toolstate == $nodecount} {
                cadobjects_tool_clear_coords $canv
                if {$endnode == "..."} {
                    set toolstate 2
                    cadobjects_tool_set_coord $canv 1 $x $y
                    set cadobjectsInfo($canv-PREVPOINT) [list $x $y]
                } else {
                    set toolstate "INIT"
                    set cadobjectsInfo($canv-PREVPOINT) ""
                }
                cadobjects_toolcall "execute" $canv $tooltoken $coords 0
                cadobjects_object_clear_construction_points $canv
            } else {
                cadobjects_object_draw_construction_point $canv $x $y
                cadobjects_toolcall "wasclicked" $canv $tooltoken $coords
                set cadobjectsInfo($canv-NEWHASLASTNODE) 0
                incr toolstate
            }
        } else {
            cadobjects_toolcall "preview" $canv $tooltoken $coords 0
        }
    }
    tool_set_state $toolstate
}


proc cadobjects_snap {canv canvx canvy realx realy} {
    global cadobjectsInfo

    set currtool  [tool_current]
    set toolsnaps [tool_snaps $currtool]
    if {![snap_is_enabled all] || $toolsnaps == {}} {
        $canv delete SnapGuide
        return [list $realx $realy]
    }

    foreach {minorspacing majorspacing superspacing labelspacing divisor units formatfunc conversion} \
        [cadobjects_grid_info $canv] break

    set closeenough 10

    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set closeenoughreal [expr {$closeenough/($dpi*$scalefactor)}]

    set newobj -1
    if {[info exists cadobjectsInfo($canv-NEWOBJ)]} {
        set newobj $cadobjectsInfo($canv-NEWOBJ)
    }
    set clickobj -1
    if {[info exists cadobjectsInfo($canv-CLICK_OBJ)]} {
        if {$cadobjectsInfo($canv-CLICK_OBJ) != ""} {
            set clickobj $cadobjectsInfo($canv-CLICK_OBJ)
        }
    }
    set clicknode -1
    if {[info exists cadobjectsInfo($canv-CLICK_NODE)]} {
        if {$cadobjectsInfo($canv-CLICK_NODE) != ""} {
            set clicknode $cadobjectsInfo($canv-CLICK_NODE)
        }
    }

    ##################################################################
    # Find nearby objects with which to figure out points of interest
    ##################################################################
    set nearx0 [expr {$canvx-$closeenough}]
    set neary0 [expr {$canvy-$closeenough}]
    set nearx1 [expr {$canvx+$closeenough}]
    set neary1 [expr {$canvy+$closeenough}]
    set nearby [$canv find overlapping $nearx0 $neary0 $nearx1 $neary1]
    foreach cid $nearby {
        set objid [cadobjects_objid_from_cid $canv $cid]
        if {$objid != "" && $objid != $newobj} {
            set nearobjarr($objid) 1
        }
    }
    set nearobjs [array names nearobjarr]

    ##############################################
    # Add intersections as points of interest.
    ##############################################
    set poi {}
    if {[snap_is_enabled intersect]} {
        set ncount [llength $nearobjs]
        if {$ncount >= 2 && $ncount < 10} {
            set isects [cadobjects_find_intersections $canv $nearobjs $realx $realy]
            foreach {poix poiy} $isects {
                lappend poi $poix $poiy "Intersection"
            }
        }
    }

    ##############################################
    # Add object specific points of interest.
    ##############################################
    foreach objid $nearobjs {
        set type [cadobjects_object_gettype $canv $objid]
        set coords [cadobjects_object_get_coords $canv $objid]
        set nodecount [tool_get_nodecount_from_token $type]
        set res [cadobjects_objcall "pointsofinterest" $canv $objid $realx $realy]
        if {$res != ""} {
            set objpois [lindex $res 1]
            foreach {poicat poix poiy poidesc poinode} $objpois {
                if {![snap_exists $poicat]} {
                    snap_add $poicat $poidesc 1
                }
                if {[snap_is_enabled $poicat]} {
                    if {$objid == $newobj} {
                        # Don't allow snapping to a new object
                    } elseif {$objid == $clickobj} {
                        # Don't snap to the object itself
                    } else {
                        lappend poi $poix $poiy $poidesc
                    }
                }
            }
        } else {
            set poinode 0
            foreach {poix poiy} $coords {
                incr poinode
                if {[snap_is_enabled controlpoints]} {
                    if {$objid == $newobj} {
                        # Don't allow snapping to last segment of object.
                        if {$poinode != -1 && $poinode <= [llength $coords]/2 - $nodecount} {
                            lappend poi $poix $poiy "Control point"
                        }
                    } elseif {$objid == $clickobj} {
                        if {$clicknode != -1} {
                            if {$clicknode != $poinode} {
                                lappend poi $poix $poiy "Control point"
                            }
                        }
                    } else {
                        lappend poi $poix $poiy "Control point"
                    }
                }
            }
        }
    }

    if {[snap_is_enabled grid]} {
        # Add the nearest grid intersection as a POI, in case it's closest.
        set poix [expr {floor(($realx*$conversion/$minorspacing)+0.5)*$minorspacing/$conversion}]
        set poiy [expr {floor(($realy*$conversion/$minorspacing)+0.5)*$minorspacing/$conversion}]
        lappend poi $poix $poiy "Grid"
    }

    ##############################
    # Find nearest candidate
    ##############################
    set close_poix 1e15
    set close_poiy 1e15
    set close_poidesc ""
    set close_dist 1e15
    set foundpoi 0
    foreach {poix poiy poidesc} $poi {
        set dist [expr {hypot($poiy-$realy,$poix-$realx)}]
        if {$dist < $closeenoughreal} {
            if {$dist < $close_dist} {
                set foundpoi 1
                set close_dist $dist
                set close_poix $poix
                set close_poiy $poiy
                set close_poidesc $poidesc
            }
        }
    }
    $canv delete SnapGuide
    if {$foundpoi} {
        # We found a close point of interest!
        set realx $close_poix
        set realy $close_poiy

        # Don't show snaps if we're in a selection mode,
        # and are not modifying anything
        set currtool  [tool_current]
        set tooltoken [tool_token $currtool]
        set toolstate [tool_get_state]
        if {$tooltoken == "NODESEL"} {
            if {$toolstate != "NODES_MOUSEDOWN"} {
                return [list $realx $realy]
            }
            if {![info exists cadobjectsInfo($canv-CLICK_HASMOVED)]} {
                return [list $realx $realy]
            }
            if {!$cadobjectsInfo($canv-CLICK_HASMOVED)} {
                return [list $realx $realy]
            }
        } elseif {$tooltoken == "OBJSEL"} {
            if {$toolstate != "OBJECTS_MOUSEDOWN"} {
                return [list $realx $realy]
            }
            if {![info exists cadobjectsInfo($canv-CLICK_HASMOVED)]} {
                return [list $realx $realy]
            }
            if {!$cadobjectsInfo($canv-CLICK_HASMOVED)} {
                return [list $realx $realy]
            }
        }

        # Otherwise, show the snap marker on the canvas
        foreach {cx cy} [cadobjects_scale_coords $canv [list $realx $realy]] break
        set x0 [expr {$cx-3}]
        set y0 [expr {$cy-3}]
        set x1 [expr {$cx+3}]
        set y1 [expr {$cy+3}]
        set x3 [expr {$cx+5}]
        set y3 [expr {$cy-5}]
        $canv create line $x0 $y0 $x1 $y1 -fill blue -tags SnapGuide
        $canv create line $x1 $y0 $x0 $y1 -fill blue -tags SnapGuide
        $canv create text $x3 $y3 -text $close_poidesc -fill blue -tags SnapGuide -anchor sw -font {Helvetica 9 bold}
        $canv raise SnapGuide
    }

    return [list $realx $realy]
}


proc cadobjects_binding_doubleclick {canv type x y} {
    global cadobjectsInfo
    cutpaste_set_checkpoint $canv
    set currtool [tool_current]
    set tooltoken [tool_token $currtool]
    set nx [$canv canvasx $x]
    set ny [$canv canvasy $y]
    foreach {realx realy} [cadobjects_descale_coords $canv [list $nx $ny]] break
    set noderealx $realx
    set noderealy $realy
    switch -exact -- $tooltoken {
        NODESEL -
        OBJSEL {
            if {$type == "OBJ"} {
                set cid [$canv find withtag current]
                set objid [cadobjects_objid_from_cid $canv $cid]
                cadobjects_object_edit $canv $objid
            }
        }
    }
}


proc cadobjects_binding_buttonpress {canv type x y} {
    global cadobjectsInfo
    cutpaste_set_checkpoint $canv
    set currtool [tool_current]
    set tooltoken [tool_token $currtool]
    set nx [$canv canvasx $x]
    set ny [$canv canvasy $y]
    foreach {realx realy} [cadobjects_descale_coords $canv [list $nx $ny]] break
    set noderealx $realx
    set noderealy $realy
    switch -exact -- $tooltoken {
        NODESEL {
            if {$type == "CP"} {
                tool_set_state "NODES_MOUSEDOWN"
                set cid [$canv find withtag current]
                foreach {objid nodenum} [cadobjects_objid_and_node_from_cid $canv $cid] break
                set coords [cadobjects_object_get_coords $canv $objid]
                set pos1 [expr {2*($nodenum-1)}]
                set pos2 [expr {$pos1+1}]
                foreach {noderealx noderealy} [lrange $coords $pos1 $pos2] break
                if {![cadselect_node_ismember $canv $objid $nodenum]} {
                    if {![cadobjects_modkey_isdown SHIFT]} {
                        cadselect_clear $canv $objid
                        cadselect_node_clear $canv
                    }
                }
                if {![cadselect_ismember $canv $objid]} {
                    cadobjects_object_draw_controls $canv $objid red
                    cadselect_add $canv $objid
                }
                if {![cadobjects_modkey_isdown SHIFT]} {
                    cadselect_node_add $canv $objid $nodenum
                } else {
                    cadselect_node_toggle $canv $objid $nodenum
                }
                set cadobjectsInfo($canv-CLICK_OBJ)  $objid
                set cadobjectsInfo($canv-CLICK_NODE) $nodenum

                cadobjects_objcall "clickctl" $canv $objid $nodenum
                confpane_populate
            } elseif {$type == "OBJ"} {
                tool_set_state "OBJECTS_MOUSEDOWN"
                set cid [$canv find withtag current]
                set objid [cadobjects_objid_from_cid $canv $cid]
                if {![cadselect_ismember $canv $objid]} {
                    if {![cadobjects_modkey_isdown SHIFT]} {
                        cadselect_clear $canv $objid
                        cadselect_node_clear $canv
                    }
                }
                if {![cadobjects_modkey_isdown SHIFT]} {
                    cadselect_add $canv $objid
                } else {
                    cadselect_toggle $canv $objid
                }
                if {[cadselect_ismember $canv $objid]} {
                    cadobjects_object_draw_controls $canv $objid red
                }
                set cadobjectsInfo($canv-CLICK_OBJ)  $objid
                set cadobjectsInfo($canv-CLICK_NODE)  ""
                cadobjects_objcall "clickobj" $canv $objid $realx $realy
                confpane_populate
            } else {
                tool_set_state "SELNODE_RECT_MOUSEDOWN"
                if {![cadobjects_modkey_isdown SHIFT]} {
                    #cadselect_clear $canv
                    cadselect_node_clear $canv
                }
                set cadobjectsInfo($canv-CLICK_OBJ)  ""
                set cadobjectsInfo($canv-CLICK_NODE)  ""
            }
        }
        OBJSEL {
            if {$type == "OBJ"} {
                tool_set_state "OBJECTS_MOUSEDOWN"
                set cid [$canv find withtag current]
                set objid [cadobjects_objid_from_cid $canv $cid]
                if {![cadselect_ismember $canv $objid]} {
                    if {![cadobjects_modkey_isdown SHIFT]} {
                        cadselect_clear $canv $objid
                    }
                }
                if {![cadobjects_modkey_isdown SHIFT]} {
                    cadselect_add $canv $objid
                } else {
                    cadselect_toggle $canv $objid
                }
                set cadobjectsInfo($canv-CLICK_OBJ)  $objid
                set cadobjectsInfo($canv-CLICK_NODE) ""
                cadobjects_objcall "clickobj" $canv $objid $realx $realy
                confpane_populate
            } else {
                tool_set_state "SELOBJ_RECT_MOUSEDOWN"
                if {![cadobjects_modkey_isdown SHIFT]} {
                    cadselect_clear $canv
                }
                set cadobjectsInfo($canv-CLICK_OBJ)  ""
                set cadobjectsInfo($canv-CLICK_NODE)  ""
            }
        }
        default {
            foreach {realx realy} [cadobjects_snap $canv $nx $ny $realx $realy] break
            cadobjects_gather_points $canv $realx $realy 1
        }
    }
    set cadobjectsInfo($canv-CLICK_CIDTYPE) $type
    set cadobjectsInfo($canv-CLICK_HASMOVED) 0
    set cadobjectsInfo($canv-CLICK_COORDS) [list $x $y]
    set cadobjectsInfo($canv-CLICK_REALCOORDS) [list $noderealx $noderealy]
    set cadobjectsInfo($canv-DRAG_COORDS) [list $x $y]
    set cadobjectsInfo($canv-DRAG_REALCOORDS) [list $noderealx $noderealy]
    confpane_populate
    cadobjects_update_actionstr
}


proc cadobjects_binding_buttonrelease {canv type x y} {
    global cadobjectsInfo
    set currtool [tool_current]
    set tooltoken [tool_token $currtool]
    set toolstate [tool_get_state]

    switch -exact -- $tooltoken {
        NODESEL {
            cadobjects_binding_motion $canv $x $y
            tool_set_state "INIT"
            set cursor [tool_cursor $currtool]
            $canv configure -cursor $cursor
        }
        OBJSEL {
            cadobjects_binding_motion $canv $x $y
            tool_set_state "INIT"
            set cursor [tool_cursor $currtool]
            $canv configure -cursor $cursor
        }
    }

    if {$cadobjectsInfo($canv-CLICK_HASMOVED)} {
        set nx [$canv canvasx $x]
        set ny [$canv canvasy $y]
        foreach {newx newy} [cadobjects_descale_coords $canv [list $nx $ny]] break
        foreach {rx ry} $cadobjectsInfo($canv-CLICK_REALCOORDS) break

        if {$toolstate == "SELNODE_RECT_MOUSEDOWN"} {
            $canv delete SelRect
            set coords [list $rx $ry $newx $newy]
            foreach {x0 y0 x1 y1} [cadobjects_scale_coords $canv $coords] break
            if {$x0 > $x1} {
                set tmp $x0
                set x0 $x1
                set x1 $tmp
            }
            if {$y0 > $y1} {
                set tmp $y0
                set y0 $y1
                set y1 $tmp
            }
            set cids [$canv find overlapping $x0 $y0 $x1 $y1]
            foreach cid $cids {
                set objid [cadobjects_objid_from_cid $canv $cid]
                if {$objid != ""} {
                    if {![cadselect_ismember $canv $objid]} {
                        cadselect_add $canv $objid
                    }
                }
            }
            set cids [$canv find overlapping $x0 $y0 $x1 $y1]
            set cids [cadobjects_filter_cids_for_control_points $canv $cids]
            foreach cid $cids {
                foreach {objid nodenum} [cadobjects_objid_and_node_from_cid $canv $cid] break
                if {$objid != "" && $nodenum != ""} {
                    if {![cadselect_ismember $canv $objid]} {
                        cadselect_add $canv $objid
                    }
                    if {![cadselect_node_ismember $canv $objid $nodenum]} {
                        cadselect_node_add $canv $objid $nodenum
                    }
                }
            }
            confpane_populate
        } elseif {$toolstate == "SELOBJ_RECT_MOUSEDOWN"} {
            $canv delete SelRect
            set coords [list $rx $ry $newx $newy]
            foreach {x0 y0 x1 y1} [cadobjects_scale_coords $canv $coords] break
            if {$x0 > $x1} {
                set tmp $x0
                set x0 $x1
                set x1 $tmp
            }
            if {$y0 > $y1} {
                set tmp $y0
                set y0 $y1
                set y1 $tmp
            }
            set cids [$canv find overlapping $x0 $y0 $x1 $y1]
            foreach cid $cids {
                set objid [cadobjects_objid_from_cid $canv $cid]
                if {$objid != ""} {
                    if {![cadselect_ismember $canv $objid]} {
                        cadselect_add $canv $objid
                    }
                }
            }
            confpane_populate
        }
    } else {
        if {$toolstate == "SELNODE_RECT_MOUSEDOWN" || $toolstate == "SELOBJ_RECT_MOUSEDOWN"} {
            if {![cadobjects_modkey_isdown SHIFT]} {
                cadselect_clear $canv
            }
        }
    }
    set cadobjectsInfo($canv-CLICK_OBJ)  ""
    set cadobjectsInfo($canv-CLICK_NODE)  ""
    cadobjects_update_actionstr
}


proc cadobjects_binding_motion {canv x y} {
    global cadobjectsInfo

    if {![info exists cadobjectsInfo($canv-CLICK_COORDS)]} {
        # Initialize, if there's not been motion in this canvas before.
        set cadobjectsInfo($canv-CLICK_COORDS) [list $x $y]
        set cadobjectsInfo($canv-CLICK_HASMOVED) 0
        set nx [$canv canvasx $x]
        set ny [$canv canvasy $y]
        foreach {newx newy} [cadobjects_descale_coords $canv [list $nx $ny]] break
        set cadobjectsInfo($canv-CLICK_REALCOORDS) [list $newx $newy]
        set cadobjectsInfo($canv-DRAG_COORDS) [list $x $y]
        set cadobjectsInfo($canv-DRAG_REALCOORDS) [list $newx $newy]
    }

    set currtool [tool_current]
    set toolstate [tool_get_state]

    foreach {ox oy} $cadobjectsInfo($canv-CLICK_COORDS) break
    if {!$cadobjectsInfo($canv-CLICK_HASMOVED)} {
        if {hypot($y-$oy,$x-$ox) >= 3.0} {
            set cadobjectsInfo($canv-CLICK_HASMOVED) 1
        }
    }
    foreach {crx cry} $cadobjectsInfo($canv-CLICK_REALCOORDS) break
    foreach {drx dry} $cadobjectsInfo($canv-DRAG_REALCOORDS) break

    if {$cadobjectsInfo($canv-CLICK_HASMOVED)} {
        set nx [$canv canvasx $x]
        set ny [$canv canvasy $y]
        foreach {newx newy} [cadobjects_descale_coords $canv [list $nx $ny]] break
        if {$toolstate != "SELNODE_RECT_MOUSEDOWN" && $toolstate != "SELOBJ_RECT_MOUSEDOWN"} {
            foreach {newx newy} [cadobjects_snap $canv $nx $ny $newx $newy] break
        }
        set dx [expr {$newx-$drx}]
        set dy [expr {$newy-$dry}]
    } else {
        set dx 0.0
        set dy 0.0
        set newx $crx
        set newy $cry
    }

    if {$toolstate == "NODES_MOUSEDOWN"} {
        if {$cadobjectsInfo($canv-CLICK_HASMOVED)} {
            $canv configure -cursor crosshair

            if {0&&[cadobjects_modkey_isdown SHIFT]} {
                # Snap to horizontal or vertical move on SHIFT key pressed.
                # Disabled due to bad side effects.
                if {abs($newx-$crx) > abs($newy-$cry)} {
                    set newy $cry
                } else {
                    set newx $crx
                }
                set dx [expr {$newx-$drx}]
                set dy [expr {$newy-$dry}]
            }

            set allnodes [cadselect_node_list $canv]
            foreach {objid nodes} $allnodes {
                set done 0
                set type [cadobjects_object_gettype $canv $objid]
                set coords [cadobjects_object_get_coords $canv $objid]
                set res [cadobjects_objcall "dragctls" $canv $objid $nodes $dx $dy]
                if {$res != ""} {
                    if {[lindex $res 1]} {
                        set done 1
                    }
                }
                if {!$done} {
                    set absmove [expr {[llength $nodes]<2&&[llength $allnodes]==2}]
                    foreach node $nodes {
                        if {$node > 0 && $node <= [llength $coords] / 2} {
                            set pos1 [expr {($node-1)*2}]
                            set pos2 [expr {$pos1+1}]
                            if {$absmove} {
                                set nx $newx
                                set ny $newy
                            } else {
                                set nx [expr {[lindex $coords $pos1]+$dx}]
                                set ny [expr {[lindex $coords $pos2]+$dy}]
                            }
                            set coords [lreplace $coords $pos1 $pos2 $nx $ny]
                        }
                    }
                    cadobjects_object_set_coords $canv $objid $coords
                }
                cadobjects_object_recalculate $canv $objid
                cadobjects_object_draw $canv $objid red
                cadobjects_object_draw_controls $canv $objid red
                cadselect_add $canv $objid
                foreach node $nodes {
                    cadselect_node_add $canv $objid $node
                }
            }

            set cadobjectsInfo($canv-DRAG_COORDS) [list $x $y]
            set cadobjectsInfo($canv-DRAG_REALCOORDS) [list $newx $newy]
            confpane_populate
        }
    } elseif {$toolstate == "OBJECTS_MOUSEDOWN"} {
        if {$cadobjectsInfo($canv-CLICK_HASMOVED)} {
            $canv configure -cursor crosshair
            if {[cadobjects_modkey_isdown SHIFT]} {
                if {abs($newx-$crx) > abs($newy-$cry)} {
                    set newy $cry
                } else {
                    set newx $crx
                }
                set dx [expr {$newx-$drx}]
                set dy [expr {$newy-$dry}]
            }

            foreach objid [cadselect_list $canv] {
                cadobjects_object_translate $canv $objid $dx $dy
                cadselect_add $canv $objid
            }
            set cadobjectsInfo($canv-DRAG_COORDS) [list $x $y]
            set cadobjectsInfo($canv-DRAG_REALCOORDS) [list $newx $newy]
            confpane_populate
        }
    } elseif {$toolstate == "SELNODE_RECT_MOUSEDOWN"} {
        if {$cadobjectsInfo($canv-CLICK_HASMOVED)} {
            $canv delete SelRect
            set coords [list $crx $cry $newx $newy]
            set coords [cadobjects_scale_coords $canv $coords]
            set dashoff [expr {([clock clicks -milliseconds]/100)%6}]
            $canv create rectangle $coords -fill "" -outline black -dash [dashpat construction] -tags SelRect -dashoffset $dashoff
            cadobjects_animate_selection_rectangle $canv
        }
    } elseif {$toolstate == "SELOBJ_RECT_MOUSEDOWN"} {
        if {$cadobjectsInfo($canv-CLICK_HASMOVED)} {
            $canv delete SelRect
            set coords [list $crx $cry $newx $newy]
            set coords [cadobjects_scale_coords $canv $coords]
            set dashoff [expr {([clock clicks -milliseconds]/100)%6}]
            $canv create rectangle $coords -fill "" -outline black -dash [dashpat construction] -tags SelRect -dashoffset $dashoff
            cadobjects_animate_selection_rectangle $canv
        }
    } else {
        if {$cadobjectsInfo($canv-CLICK_HASMOVED)} {
            set tooltoken [tool_token $currtool]
            set nodeinfo [tool_nodeinfo $currtool]
            set nodecount [expr {[llength $nodeinfo]}]
            set endnode [lindex [lindex $nodeinfo end] 0]
            if {$endnode == "..."} {
                incr nodecount -1
            }
            if {$toolstate == $nodecount} {
                cadobjects_gather_points $canv $newx $newy 0
            }
            set cadobjectsInfo($canv-DRAG_COORDS) [list $x $y]
            set cadobjectsInfo($canv-DRAG_REALCOORDS) [list $newx $newy]
            confpane_populate
        }
    }

    set mainwin [cadobjects_mainwin $canv]
    lassign [cadobjects_unit_system $canv] usys isfract unitmult unit
    set newx [expr {$newx*$unitmult}]
    set newy [expr {$newy*$unitmult}]
    mainwin_update_mousepos $mainwin $newx $newy $unit
    cadobjects_update_actionstr
}


proc cadobjects_mainwin {canv} {
    global cadobjectsInfo
    return $cadobjectsInfo($canv-MAINWIN)
}


proc cadobjects_animate_selection_rectangle {canv {isrepeat 0}} {
    global cadobjectsInfo
    set cid [$canv find withtag SelRect]
    if {$cid != ""} {
        set dashoff [expr {([clock clicks -milliseconds]/100)%6}]
        $canv itemconfigure $cid -dashoffset $dashoff
        if {![info exists cadobjectsInfo($canv-SELRECT_PID)] || $isrepeat} {
            set pid [after 100 cadobjects_animate_selection_rectangle $canv 1]
            set cadobjectsInfo($canv-SELRECT_PID) $pid
        }
    } else {
        unset cadobjectsInfo($canv-SELRECT_PID)
    }
}


proc cadobjects_object_clear_construction_points {canv} {
    global cadobjectsInfo
    if {[info exists cadobjectsInfo($canv-CONSTRPTS)]} {
        unset cadobjectsInfo($canv-CONSTRPTS)
    }
    $canv delete "ConstructionPt"
}


proc cadobjects_object_redraw_construction_points {canv} {
    global cadobjectsInfo
    $canv delete "ConstructionPt"
    if {[info exists cadobjectsInfo($canv-CONSTRPTS)]} {
        foreach {x y} $cadobjectsInfo($canv-CONSTRPTS) {
            foreach {x y} [cadobjects_scale_coords $canv [list $x $y]] break
            set cpcoords [list [expr {$x-2}] [expr {$y-2}] [expr {$x+2}] [expr {$y+2}]]
            $canv create oval $cpcoords -tags [concat "ConstructionPt"] -fill red -outline red
        }
    }
}


proc cadobjects_object_draw_construction_point {canv x y} {
    global cadobjectsInfo
    lappend cadobjectsInfo($canv-CONSTRPTS) $x $y
    cadobjects_object_redraw_construction_points $canv
}


proc cadobjects_object_draw_controlpoint {canv objid type x y cpnum cptype outlinecolor fillcolor {tags ""}} {
    set img [cadobjects_get_node_image $cptype]
    lappend tags "CP" "Obj_$objid" "Node_$cpnum" "NType_$cptype"
    $canv create image $x $y -tags $tags -image $img
}


proc cadobjects_object_draw_control_line {canv objid x0 y0 x1 y1 cpnum color {dash ""} {tags ""}} {
    if {$color == "" || $color == "none"} {
        set layerid [cadobjects_object_getlayer $canv $objid]
        set color [layer_color $canv $layerid]
        if {$color == "" || $color == "none"} {
            set color black
        }
    }
    set type [cadobjects_object_gettype $canv $objid]
    lappend tags "CL" "Obj_$objid" "Node_$cpnum" "ConstLines"
    if {[namespace exists ::tkp]} {
        $canv create pline [list $x0 $y0 $x1 $y1] -tags $tags -stroke $color -strokedasharray [pathdash $dash]
    } else {
        $canv create line [list $x0 $y0 $x1 $y1] -tags $tags -fill $color -dash $dash
    }
}


proc cadobjects_object_draw_circle {canv cx cy radius tags color {dash ""} {width 0.001}} {
    cadobjects_object_draw_oval $canv $cx $cy $radius $radius $tags $color $dash $width
}


proc cadobjects_object_draw_oval {canv cx cy rad1 rad2 tags color {dash ""} {width 0.001}} {
    if {$color == "" || $color == "none"} {
        set layerid [cadobjects_object_getlayer $canv $objid]
        set color [layer_color $canv $layerid]
        if {$color == "" || $color == "none"} {
            set color black
        }
    }
    lappend tags "ConstLines"
    set rad2 $rad1
    #set width 1.0
    if {[namespace exists ::tkp]} {
        $canv create ellipse [list $cx $cy] -rx $rad1 -ry $rad2 -tags $tags -stroke $color -fill "" -strokewidth $width -strokedasharray [pathdash $dash]
    } else {
        set x0 [expr {$cx-$rad1}]
        set y0 [expr {$cy-$rad2}]
        set x1 [expr {$cx+$rad1}]
        set y1 [expr {$cy+$rad2}]
        set box [list $x0 $y0 $x1 $y1]
        $canv create oval $box -tags $tags -outline $color -fill "" -width $width -dash $dash
    }
}


proc cadobjects_object_draw_center_cross {canv cx cy radius tags color {width 0.001}} {
    cadobjects_object_draw_oval_cross $canv $cx $cy $radius $radius $tags $color $width
}


proc cadobjects_object_draw_oval_cross {canv cx cy rad1 rad2 tags color {width 0.001}} {
    if {$color == "" || $color == "none"} {
        set layerid [cadobjects_object_getlayer $canv $objid]
        set color [layer_color $canv $layerid]
        if {$color == "" || $color == "none"} {
            set color black
        }
    }
    lappend tags "ConstLines"
    set width 1.0
    set x0 [expr {$cx-$rad1}]
    set y0 [expr {$cy-$rad2}]
    set x1 [expr {$cx+$rad1}]
    set y1 [expr {$cy+$rad2}]
    # Draw lines from center to keep dash pattern aligned.
    if {[namespace exists ::tkp]} {
        $canv create pline [list $cx $cy $x0 $cy] -tags $tags -stroke $color -strokewidth $width -strokedasharray [pathdash [dashpat centerline]]
        $canv create pline [list $cx $cy $x1 $cy] -tags $tags -stroke $color -strokewidth $width -strokedasharray [pathdash [dashpat centerline]]
        $canv create pline [list $cx $cy $cx $y0] -tags $tags -stroke $color -strokewidth $width -strokedasharray [pathdash [dashpat centerline]]
        $canv create pline [list $cx $cy $cx $y1] -tags $tags -stroke $color -strokewidth $width -strokedasharray [pathdash [dashpat centerline]]
    } else {
        $canv create line [list $cx $cy $x0 $cy] -tags $tags -fill $color -width $width -dash [dashpat centerline]
        $canv create line [list $cx $cy $x1 $cy] -tags $tags -fill $color -width $width -dash [dashpat centerline]
        $canv create line [list $cx $cy $cx $y0] -tags $tags -fill $color -width $width -dash [dashpat centerline]
        $canv create line [list $cx $cy $cx $y1] -tags $tags -fill $color -width $width -dash [dashpat centerline]
    }
}


proc cadobjects_object_draw_centerline {canv x0 y0 x1 y1 tags color} {
    if {$color == "" || $color == "none"} {
        set layerid [cadobjects_object_getlayer $canv $objid]
        set color [layer_color $canv $layerid]
        if {$color == "" || $color == "none"} {
            set color black
        }
    }
    lappend tags "ConstLines"
    set width 1.0
    if {[namespace exists ::tkp]} {
        $canv create pline [list $x0 $y0 $x1 $y1] -tags $tags -stroke $color -strokewidth $width -strokedasharray [pathdash [dashpat centerline]]
    } else {
        $canv create line [list $x0 $y0 $x1 $y1] -tags $tags -fill $color -width $width -dash [dashpat centerline]
    }
}


proc cadobjects_object_draw_center_arc {canv cx cy radius start extent tags color} {
    if {$color == "" || $color == "none"} {
        set layerid [cadobjects_object_getlayer $canv $objid]
        set color [layer_color $canv $layerid]
        if {$color == "" || $color == "none"} {
            set color black
        }
    }
    lappend tags "ConstLines"
    set width 1.0
    # Draw lines from center to keep dash pattern aligned.
    if {[namespace exists ::tkp]} {
        constants pi degtorad
        set x0 [expr {$radius*cos($start*$degtorad)+$cx}]
        set y0 [expr {-$radius*sin($start*$degtorad)+$cy}]
        set x1 [expr {$radius*cos(($start+$extent)*$degtorad)+$cx}]
        set y1 [expr {-$radius*sin(($start+$extent)*$degtorad)+$cy}]
        set la [expr {abs($extent)>=180.0?1:0}]
        set sw [expr {$extent<0?1:0}]
        set d [list "M" $x0 $y0 "A" $radius $radius 0.0 $la $sw $x1 $y1]
        $canv create path $d -tags $tags -stroke $color -strokewidth $width -strokedasharray [pathdash [dashpat centerline]] -fill ""
    } else {
        set x0 [expr {$cx-$radius}]
        set y0 [expr {$cy-$radius}]
        set x1 [expr {$cx+$radius}]
        set y1 [expr {$cy+$radius}]
        $canv create arc [list $x0 $y0 $x1 $y1] -tags $tags -style arc -outline $color -start $start -extent $extent -width $width -dash [dashpat centerline]
    }
}


proc cadobjects_object_polyline_pois {poivar poitype poilbl coords x y} {
    upvar $poivar var
    foreach {px py} [::math::geometry::findClosestPointOnPolyline [list $x $y] $coords] break
    lappend var $poitype $px $py $poilbl -1
}

proc cadobjects_object_bezier_pois {poivar poitype poilbl coords x y {closeenough 1e-2} {tolerance 1e-4}} {
    upvar $poivar var
    set pt [bezutil_bezier_nearest_point $x $y $coords $closeenough $tolerance]
    if {$pt != ""} {
        foreach {px py} $pt break
        lappend var $poitype $px $py $poilbl -1
    }
}

proc cadobjects_object_arc_pois {canv poivar poitype poilbl cx cy radius start extent x y} {
    upvar $poivar poi
    constants degtorad
    foreach {px py} [geometry_closest_point_on_arc $cx $cy $radius $start $extent $x $y] break
    set dist [expr {hypot($py-$y,$px-$x)}]
    lappend poi $poitype $px $py $poilbl -1

    set prevpt [cadobjects_get_prev_point $canv]
    if {$prevpt != ""} {
        foreach {ox oy} $prevpt break
        cadobjects_calculate_tangent_pois poi $cx $cy $radius $ox $oy [expr {$degtorad*$start}] [expr {$degtorad*$extent}]
    }
}


proc cadobjects_object_draw_control_arc {canv objid cx cy radius start extent cpnum color {dash ""}} {
    set type [cadobjects_object_gettype $canv $objid]
    set x0 [expr {$cx-$radius}]
    set y0 [expr {$cy-$radius}]
    set x1 [expr {$cx+$radius}]
    set y1 [expr {$cy+$radius}]
    $canv create arc [list $x0 $y0 $x1 $y1] -style arc -start $start -extent $extent -tags [list "CL" "Node_$cpnum" "Obj_$objid"] -outline $color -fill "" -dash $dash
}



proc cadobjects_calculate_tangent_pois {var cx cy radius ox oy {startang 0.0} {extent 6.284}} {
    upvar $var poi
    constants pi degtorad

    set dist [expr {hypot($oy-$cy,$ox-$cx)}]
    if {$dist < $radius} {
        return
    }
    set oang [expr {atan2($oy-$cy,$ox-$cx)}]
    set thirdside [expr {sqrt($dist*$dist-$radius*$radius)}]
    set dang [expr {atan2($thirdside,$radius)}]

    set ta1 [expr {$oang+$dang}]
    set tx1 [expr {$cx+$radius*cos($ta1)}]
    set ty1 [expr {$cy+$radius*sin($ta1)}]

    set ta2 [expr {$oang-$dang}]
    set tx2 [expr {$cx+$radius*cos($ta2)}]
    set ty2 [expr {$cy+$radius*sin($ta2)}]

    if {$extent > 2.0*$pi} {
        lappend poi "tangents"  $tx1  $ty1  "Tangent"       -1
        lappend poi "tangents"  $tx2  $ty2  "Tangent"       -1
    } else {
        # Normalize start and end angles for later comparison.
        if {$extent < 0} {
            set startang [expr {$startang+$endang}]
            set extent [expr {-$extent}]
        }
        while {$startang >= 2.0*$pi} {
            set startang [expr {$startang-2.0*$pi}]
        }
        while {$startang < 0.0} {
            set startang [expr {$startang+2.0*$pi}]
        }
        while {$ta1 >= 2.0*$pi} {
            set ta1 [expr {$ta1-2.0*$pi}]
        }
        while {$ta1 < $startang} {
            set ta1 [expr {$ta1+2.0*$pi}]
        }
        while {$ta2 >= 2.0*$pi} {
            set ta2 [expr {$ta2-2.0*$pi}]
        }
        while {$ta2 < $startang} {
            set ta2 [expr {$ta2+2.0*$pi}]
        }

        # compensate for rounding errors.
        set startang [expr {$startang-1e-8}]
        set extent [expr {$extent+1e-8}]

        if {$ta1 >= $startang && $ta1 <= $startang+$extent} {
            lappend poi "tangents"  $tx1  $ty1  "Tangent"       -1
        }
        if {$ta2 >= $startang && $ta2 <= $startang+$extent} {
            lappend poi "tangents"  $tx2  $ty2  "Tangent"       -1
        }
    }
}


# vim: set ts=4 sw=4 nowrap expandtab: settings

