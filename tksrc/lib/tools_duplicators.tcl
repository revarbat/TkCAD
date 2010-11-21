proc plugin_radialcopy_editfields {canv} {
    set out {}
    lappend out {
        type POINT
        name CENTER
        datum 0
        title "Rotation Pt"
        default {0.0 0.0}
    }
    lappend out {
        type INT
        name SYMMETRY
        title "Symmetry"
        min 2
        max 99
        width 3
        default 6
    }
    lappend out {
        type EXEC
        name EXEC
        title "Radial Duplicate"
    }
    return $out
}


proc plugin_radialcopy_preview {canv coords isconf} {
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
        if {abs($drot) > 1e-6} {
            set sym [expr {int(360.0/abs($drot))}]
        } else {
            set sym 100
        }
    } else {
        set cx ""
        set cy ""
        if {[llength $coords] >= 2} {
            foreach {cx cy} $coords break
        }
        set sym [tool_getdatum $toolid "SYMMETRY"]
        if {$sym == ""} {
            return
        }
    }
    set drot [expr {2.0*$pi/$sym}]

    foreach {ox0 oy0 ox1 oy1} [$canv bbox Selected] break
    if {![info exists ox0]} {
        # Nothing selected.  Don't rotate.
        return
    }

    tool_setdatum $toolid "SYMMETRY" $sym
    $canv delete Preview

    for {set i 0} {$i < $sym} {incr i} {
        set rotr [expr {$drot*$i}]
        set sinv [expr {sin($rotr)}]
        set cosv [expr {cos($rotr)}]
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
}


proc plugin_radialcopy_execute {canv coords isconf} {
    constants pi
    $canv delete Preview
    set toolid [tool_current]
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
        if {abs($drot) > 1e-6} {
            set sym [expr {int(360.0/abs($drot))}]
        } else {
            set sym 100
        }
    } else {
        set cx ""
        set cy ""
        if {[llength $coords] >= 2} {
            foreach {cx cy} $coords break
        }
        set sym [tool_getdatum $toolid "SYMMETRY"]
        if {$sym == ""} {
            return
        }
    }
    set drot [expr {360.0/$sym}]
    set objids [cadselect_list $canv]
    set allobjs $objids
    for {set i 1} {$i < $sym} {incr i} {
        set ang [expr {$drot*$i}]
        foreach objid $objids {
            set info [cadobjects_object_serialize $canv $objid]
            set newobj [cadobjects_object_deserialize $canv -1 1 $info]
            lappend allobjs $newobj
            cadobjects_object_rotate $canv $newobj $ang $cx $cy
        }
    }

    cadobjects_reset
    cadselect_clear $canv
    foreach objid $allobjs {
        cadselect_add $canv $objid
    }
}





proc plugin_linearcopy_editfields {canv} {
    set out {}
    lappend out {
        type POINT
        name STARTPT
        datum 0
        title "Starting Pt"
        default {0.0 0.0}
    }
    lappend out {
        type POINT
        name ENDPT
        datum 1
        title "Ending Pt"
        default {0.0 0.0}
    }
    lappend out {
        type INT
        name COUNT
        title "Count"
        width 3
        min 1
        max 99
        default 4
    }
    lappend out {
        type FLOAT
        name SPACING
        title "Spacing"
        width 8
        min -1e9
        max 1e9
        increment 0.0625
        default 1.0
        islength 1
    }
    lappend out {
        type EXEC
        name EXEC
        title "Linear Duplicate"
    }
    return $out
}


proc plugin_linearcopy_preview {canv coords isconf} {
    foreach {ox0 oy0 ox1 oy1} [$canv bbox Selected] break
    if {![info exists ox0]} {
        # Nothing selected.
        return
    }

    set toolid [tool_current]
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set coords [cadobjects_scale_coords $canv $coords]

    if {!$isconf} {
        if {[llength $coords] < 4} {
            return
        }
        if {[llength $coords] < 6} {
            foreach {refx refy cpx1 cpy1} $coords break
            set dist [expr {hypot($cpy1-$refy,$cpx1-$refx)}]
            set ang [expr {atan2($cpy1-$refy,$cpx1-$refx)}]
            set cnt [tool_getdatum $toolid "COUNT"]
            if {$cnt == ""} {
                set cnt 4
            }
            set cpx2 [expr {($dist*1.0/$cnt)*cos($ang)+$refx}]
            set cpy2 [expr {($dist*1.0/$cnt)*sin($ang)+$refy}]
        } else {
            foreach {refx refy cpx1 cpy1 cpx2 cpy2} $coords break
            set dist [expr {hypot($cpy1-$refy,$cpx1-$refx)}]
            set ang [expr {atan2($cpy1-$refy,$cpx1-$refx)}]
        }
        set spc [expr {hypot($cpy2-$refy,$cpx2-$refx)}]
        if {abs($spc) < 1e-6} {
            set cnt 4
        } else {
            set cnt [expr {1+int($dist/$spc+1e-6)}]
        }
        if {$cnt == 0} {
            set cnt 1
        }

        set spc [expr {$dist/($cnt+0.0)}]
        set sspc [expr {$spc/($dpi*$scalefactor)}]

        tool_setdatum $toolid "SPACING" $sspc
        tool_setdatum $toolid "COUNT" $cnt
    } else {
        if {[llength $coords] >= 4} {
            foreach {refx refy cpx1 cpy1} $coords break
        }
        set ang [expr {atan2($cpy1-$refy,$cpx1-$refx)}]
        set spc [tool_getdatum $toolid "SPACING"]
        set cnt [tool_getdatum $toolid "COUNT"]

        if {$spc == ""} {
            set spc 1.0
        }
        if {$cnt == ""} {
            set cnt 4
        }
        set spc [expr {$spc*$dpi*$scalefactor}]
    }

    $canv delete Preview

    set xspc [expr {$spc*cos($ang)}]
    set yspc [expr {$spc*sin($ang)}]
    for {set i 1} {$i <= $cnt} {incr i} {
        set xpos [expr {$i*$xspc}]
        set ypos [expr {$i*$yspc}]
        foreach {x0 y0 x1 y1} [list \
            $ox0 $oy0 $ox0 $oy1 \
            $ox0 $oy0 $ox1 $oy0 \
            $ox0 $oy0 $ox1 $oy1 \
            $ox1 $oy0 $ox1 $oy1 \
            $ox0 $oy1 $ox1 $oy1 \
            $ox0 $oy1 $ox1 $oy0 \
        ] {
            set nx0 [expr {$x0+$xpos}]
            set ny0 [expr {$y0+$ypos}]
            set nx1 [expr {$x1+$xpos}]
            set ny1 [expr {$y1+$ypos}]
            set linecoords [list $nx0 $ny0 $nx1 $ny1]
            $canv create line $linecoords -fill blue -tags Preview
        }
    }
}


proc plugin_linearcopy_execute {canv coords isconf} {
    $canv delete Preview

    set toolid [tool_current]
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]

    if {!$isconf} {
        if {[llength $coords] < 4} {
            return
        }
        if {[llength $coords] < 6} {
            foreach {refx refy cpx1 cpy1} $coords break
            set dist [expr {hypot($cpy1-$refy,$cpx1-$refx)}]
            set ang [expr {atan2($cpy1-$refy,$cpx1-$refx)}]
            set cnt [tool_getdatum $toolid "COUNT"]
            if {$cnt == ""} {
                set cnt 4
            }
            set cpx2 [expr {($dist/(0.0+$cnt))*cos($ang)+$refx}]
            set cpy2 [expr {($dist/(0.0+$cnt))*sin($ang)+$refy}]
        } else {
            foreach {refx refy cpx1 cpy1 cpx2 cpy2} $coords break
            set dist [expr {hypot($cpy1-$refy,$cpx1-$refx)}]
            set ang [expr {atan2($cpy1-$refy,$cpx1-$refx)}]
        }
        set spc [expr {hypot($cpy2-$refy,$cpx2-$refx)}]
        if {abs($spc) < 1e-6} {
            set cnt 4
        } else {
            set cnt [expr {1+int($dist/$spc+1e-6)}]
        }
        if {$cnt == 0} {
            set cnt 1
        }

        set spc [expr {$dist/($cnt+0.0)}]
        set sspc [expr {$spc/($dpi*$scalefactor)}]

        tool_setdatum $toolid "SPACING" $sspc
        tool_setdatum $toolid "COUNT" $cnt
    } else {
        if {[llength $coords] >= 4} {
            foreach {refx refy cpx1 cpy1} $coords break
        }
        set dist [expr {hypot($cpy1-$refy,$cpx1-$refx)}]
        set ang [expr {atan2($cpy1-$refy,$cpx1-$refx)}]

        set spc [tool_getdatum $toolid "SPACING"]
        set cnt [tool_getdatum $toolid "COUNT"]

        if {$spc == ""} {
            set spc 1.0
        }
        if {$cnt == ""} {
            set cnt 4
        }
    }

    set xspc [expr {$spc*cos($ang)}]
    set yspc [expr {$spc*sin($ang)}]
    set objids [cadselect_list $canv]
    set allobjs $objids
    foreach objid $objids {
        set info [cadobjects_object_serialize $canv $objid]
        for {set i 1} {$i <= $cnt} {incr i} {
            set xpos [expr {$i*$xspc}]
            set ypos [expr {$i*$yspc}]
            set newobj [cadobjects_object_deserialize $canv -1 1 $info]
            cadobjects_object_translate $canv $newobj $xpos $ypos
            lappend allobjs $newobj
        }
    }

    cadobjects_reset
    cadselect_clear $canv
    foreach objid $allobjs {
        cadselect_add $canv $objid
    }
}






proc plugin_gridcopy_editfields {canv} {
    set out {}
    lappend out {
        type INT
        name XCOUNT
        title "X Count"
        width 3
        min 1
        max 99
        default 3
    }
    lappend out {
        type FLOAT
        name XSPACING
        title "X Spacing"
        width 8
        min -1e9
        max 1e9
        increment 1.0
        default 1.0
        islength 1
    }
    lappend out {
        type POINT
        name STARTPT
        datum 0
        title "Starting Pt"
        default {0.0 0.0}
    }
    lappend out {
        type INT
        name YCOUNT
        title "Y Count"
        width 3
        min 1
        max 99
        default 3
    }
    lappend out {
        type FLOAT
        name YSPACING
        title "Y Spacing"
        width 8
        min -1e9
        max 1e9
        increment 1.0
        default 1.0
        islength 1
    }
    lappend out {
        type EXEC
        name EXEC
        title "Grid Duplicate"
    }
    return $out
}


proc plugin_gridcopy_preview {canv coords isconf} {
    foreach {ox0 oy0 ox1 oy1} [$canv bbox Selected] break
    if {![info exists ox0]} {
        # Nothing selected.
        return
    }

    set toolid [tool_current]
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set coords [cadobjects_scale_coords $canv $coords]

    if {!$isconf} {
        if {[llength $coords] < 4} {
            return
        }
        if {[llength $coords] < 6} {
            foreach {refx refy cpx1 cpy1} $coords break
            set cpx2 $cpx1
            set cpy2 $cpy1
        } else {
            foreach {refx refy cpx1 cpy1 cpx2 cpy2} $coords break
        }
        set xspc [expr {abs($cpx1-$refx)}]
        set yspc [expr {abs($cpy1-$refy)}]
        if {abs($xspc) < 1e-6} {
            set xcnt 1
        } else {
            set xcnt [expr {1+int(abs($cpx2-$refx)/$xspc)}]
        }
        if {abs($yspc) < 1e-6} {
            set ycnt 1
        } else {
            set ycnt [expr {1+int(abs($cpy2-$refy)/$yspc)}]
        }

        if {$cpx2<$refx} {
            set xspc [expr {-$xspc}]
        }
        if {$cpy2<$refy} {
            set yspc [expr {-$yspc}]
        }
        if {$xcnt == 0} {
            set xcnt 1
        }
        if {$ycnt == 0} {
            set ycnt 1
        }

        set sxspc [expr {$xspc/($dpi*$scalefactor)}]
        set syspc [expr {$yspc/(-$dpi*$scalefactor)}]

        tool_setdatum $toolid "XSPACING" $sxspc
        tool_setdatum $toolid "YSPACING" $syspc
        tool_setdatum $toolid "XCOUNT" $xcnt
        tool_setdatum $toolid "YCOUNT" $ycnt
    } else {
        if {[llength $coords] >= 2} {
            foreach {refx refy} $coords break
        }
        set xspc [tool_getdatum $toolid "XSPACING"]
        set yspc [tool_getdatum $toolid "YSPACING"]
        set xcnt [tool_getdatum $toolid "XCOUNT"]
        set ycnt [tool_getdatum $toolid "YCOUNT"]

        set xspc [expr {$xspc*$dpi*$scalefactor}]
        set yspc [expr {-$yspc*$dpi*$scalefactor}]

        if {$xspc == ""} {
            set xspc 1.0
        }
        if {$yspc == ""} {
            set yspc 1.0
        }
        if {$xcnt == ""} {
            set xcnt 1
        }
        if {$ycnt == ""} {
            set ycnt 1
        }
    }

    $canv delete Preview

    for {set j 0} {$j < $ycnt} {incr j} {
        for {set i 0} {$i < $xcnt} {incr i} {
            set xpos [expr {$i*$xspc}]
            set ypos [expr {$j*$yspc}]
            foreach {x0 y0 x1 y1} [list \
                $ox0 $oy0 $ox0 $oy1 \
                $ox0 $oy0 $ox1 $oy0 \
                $ox0 $oy0 $ox1 $oy1 \
                $ox1 $oy0 $ox1 $oy1 \
                $ox0 $oy1 $ox1 $oy1 \
                $ox0 $oy1 $ox1 $oy0 \
            ] {
                set nx0 [expr {$x0+$xpos}]
                set ny0 [expr {$y0+$ypos}]
                set nx1 [expr {$x1+$xpos}]
                set ny1 [expr {$y1+$ypos}]
                set linecoords [list $nx0 $ny0 $nx1 $ny1]
                $canv create line $linecoords -fill blue -tags Preview
            }
        }
    }
}


proc plugin_gridcopy_execute {canv coords isconf} {
    $canv delete Preview

    set toolid [tool_current]
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]

    if {!$isconf} {
        if {[llength $coords] < 4} {
            return
        }
        if {[llength $coords] < 6} {
            foreach {refx refy cpx1 cpy1} $coords break
            set cpx2 $cpx1
            set cpy2 $cpy1
        } else {
            foreach {refx refy cpx1 cpy1 cpx2 cpy2} $coords break
        }
        set xspc [expr {abs($cpx1-$refx)}]
        set yspc [expr {abs($cpy1-$refy)}]
        if {abs($xspc) < 1e-6} {
            set xcnt 1
        } else {
            set xcnt [expr {1+int(abs($cpx2-$refx)/$xspc)}]
        }
        if {abs($yspc) < 1e-6} {
            set ycnt 1
        } else {
            set ycnt [expr {1+int(abs($cpy2-$refy)/$yspc)}]
        }

        if {$cpx2<$refx} {
            set xspc [expr {-$xspc}]
        }
        if {$cpy2<$refy} {
            set yspc [expr {-$yspc}]
        }
        if {$xcnt == 0} {
            set xcnt 1
        }
        if {$ycnt == 0} {
            set ycnt 1
        }

        set sxspc [expr {$xspc/($dpi*$scalefactor)}]
        set syspc [expr {$yspc/(-$dpi*$scalefactor)}]

        tool_setdatum $toolid "XSPACING" $sxspc
        tool_setdatum $toolid "YSPACING" $syspc
        tool_setdatum $toolid "XCOUNT" $xcnt
        tool_setdatum $toolid "YCOUNT" $ycnt
    } else {
        if {[llength $coords] >= 2} {
            foreach {refx refy} $coords break
        }

        set xspc [tool_getdatum $toolid "XSPACING"]
        set yspc [tool_getdatum $toolid "YSPACING"]
        set xcnt [tool_getdatum $toolid "XCOUNT"]
        set ycnt [tool_getdatum $toolid "YCOUNT"]

        if {$xspc == ""} {
            set xspc 1.0
        }
        if {$yspc == ""} {
            set yspc 1.0
        }
        if {$xcnt == ""} {
            set xcnt 1
        }
        if {$ycnt == ""} {
            set ycnt 1
        }
    }

    set objids [cadselect_list $canv]
    set allobjs $objids
    foreach objid $objids {
        set info [cadobjects_object_serialize $canv $objid]
        for {set j 0} {$j < $ycnt} {incr j} {
            for {set i 0} {$i < $xcnt} {incr i} {
                if {$i == 0 && $j == 0} {
                    continue
                }
                set xpos [expr {$i*$xspc}]
                set ypos [expr {$j*$yspc}]
                set newobj [cadobjects_object_deserialize $canv -1 1 $info]
                cadobjects_object_translate $canv $newobj $xpos $ypos
                lappend allobjs $newobj
            }
        }
    }

    cadobjects_reset
    cadselect_clear $canv
    foreach objid $allobjs {
        cadselect_add $canv $objid
    }
}




proc plugin_offsetcopy_editfields {canv} {
    global plugin_offsetcopyInfo
    set defoff 0.125
    if {[info exists plugin_offsetcopyInfo(LASTOFFSET)]} {
        set defoff $plugin_offsetcopyInfo(LASTOFFSET)
    }
    set out {}
    lappend out [list \
        type FLOAT \
        name OFFSETBY \
        title "Inset/offset By" \
        min -999.0 \
        max 999.0 \
        increment 0.0625 \
        width 8 \
        valgetcb "plugin_offsetcopy_getfield" \
        invoke 1 \
        default $defoff \
        islength 1
    ]
    lappend out {
        type EXEC
        name EXEC
        title "Inset/Offset"
    }
    return $out
}


proc plugin_offsetcopy_getfield {canv coords name} {
    global plugin_offsetcopyInfo
    set defoff 0.125
    if {[info exists plugin_offsetcopyInfo(LASTOFFSET)]} {
        set defoff $plugin_offsetcopyInfo(LASTOFFSET)
    }
    if {$name == "OFFSETBY"} {
        if {[llength $coords] < 4} {
            return $defoff
        }
        foreach {x0 y0 x1 y1} $coords break
        set offset [expr {hypot($y1-$y0,$x1-$x0)}]
        if {$x1-$x0 < 0.0} {
            set offset [expr {-$offset}]
        }
        if {$offset == 0.0} {
            return $defoff
        }
        return $offset
    }
}


proc plugin_offsetcopy_execute {canv coords isconf} {
    global plugin_offsetcopyInfo
    $canv delete Preview
    if {!$isconf} {
        if {[llength $coords] < 4} {
            return
        }
        foreach {x0 y0 x1 y1} $coords break
        set offset [expr {hypot($y1-$y0,$x1-$x0)}]
        if {$x1-$x0 < 0.0} {
            set offset [expr {-$offset}]
        }
    } else {
        if {[llength $coords] >= 2} {
            foreach {x0 y0} $coords break
        }
        set toolid [tool_current]
        set offset [tool_getdatum $toolid "OFFSETBY"]
        if {$offset == ""} {
            return
        }
    }
    set objids [cadselect_list $canv]
    set newobjects {}
    foreach objid $objids {
        set nuobjs [cadobjects_object_offsetcopy $canv $objid $offset]
        foreach nu $nuobjs {
            lappend newobjects $nu
        }
    }
    set plugin_offsetcopyInfo(LASTOFFSET) $offset
    cadobjects_reset
    cadselect_clear $canv
    foreach obj $newobjects {
        cadobjects_object_recalculate $canv $obj
        cadobjects_object_draw $canv $obj
        cadselect_add $canv $obj
    }
}







proc plugin_duplicators_register {} {
    tool_register_ex OFFSETCOPY "D&uplicators" "&Inset/Offset" {
        {1    "Reference Point"}
        {2    "Offset by"}
    } -icon "tool-offsetcopy"
    tool_register_ex RADIALCOPY "D&uplicators" "&Radial Duplicate" {
        {1    "Center of Rotation"}
        {2    "Reference Point"}
        {3    "First Copy Rotation"}
    } -icon "tool-radialcopy"
    tool_register_ex LINEARCOPY "D&uplicators" "&Linear Duplicate" {
        {1    "Start Point"}
        {2    "Ending Point"}
        {3    "Spacing Point"}
    } -icon "tool-linearcopy"
    tool_register_ex GRIDCOPY "D&uplicators" "&Grid Duplicate" {
        {1    "Reference Point"}
        {2    "Spacing Point"}
        {3    "Opposite Corner"}
    } -icon "tool-gridcopy"
}
plugin_duplicators_register 


# vim: set ts=4 sw=4 nowrap expandtab: settings

