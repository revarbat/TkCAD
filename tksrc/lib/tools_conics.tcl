proc plugin_conic2pt_editfields {canv objid coords} {
    set out {}
    lappend out {
        type POINT
        name START
        datum 0
        title "Start pt"
    }
    lappend out {
        type POINT
        name END
        datum 1
        title "End pt"
    }
    return $out
}


proc plugin_conic2pt_transformobj {canv objid coords mat} {
    foreach {cpx1 cpy1 cpx2 cpy2} $coords break
    set coords [list $cpx1 $cpy1 $cpx2 $cpy2 $cpx2 $cpy1]
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid CONIC3PT
    return 0 ;# Also allow default coordlist skewing
}


proc plugin_conic2pt_flipobj {canv objid coords x0 y0 x1 y1} {
    foreach {cpx1 cpy1 cpx2 cpy2} $coords break
    set coords [list $cpx1 $cpy1 $cpx2 $cpy2 $cpx2 $cpy1]
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid CONIC3PT
    return 0 ;# Also allow default coordlist skewing
}


proc plugin_conic2pt_shearobj {canv objid coords sx sy cx cy} {
    foreach {cpx1 cpy1 cpx2 cpy2} $coords break
    set coords [list $cpx1 $cpy1 $cpx2 $cpy2 $cpx2 $cpy1]
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid CONIC3PT
    return 0 ;# Also allow default coordlist skewing
}


proc plugin_conic2pt_rotateobj {canv objid coords rotang cx cy} {
    foreach {cpx1 cpy1 cpx2 cpy2} $coords break
    set coords [list $cpx1 $cpy1 $cpx2 $cpy2 $cpx2 $cpy1]
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid CONIC3PT
    return 0 ;# Also allow default coordlist rotation
}


proc plugin_conic2pt_drawobj {canv objid coords tags color fill width dash} {
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_conic2pt_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid CONIC2PT $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_conic2pt_recalculate {canv objid coords {flags ""}} {
    constants pi
    foreach {ox1 oy1 ox2 oy2} $coords break

    set rad1 [expr {abs($ox2-$ox1)}]
    set rad2 [expr {abs($oy2-$oy1)}]
    cadobjects_object_setdatum $canv $objid "RAD1" $rad1
    cadobjects_object_setdatum $canv $objid "RAD2" $rad2

    set cx $ox1
    set cy $oy2

    if {$rad1 < 1e-6 || $rad2 < 1e-6} {
        # This is actually not a conic.
        return
    }
    if {$ox1 > $ox2} {
        if {$oy1 < $oy2} {
            set start -90.0
            set extent -90.0
        } else {
            set start 90.0
            set extent 90.0
        }
    } else {
        if {$oy1 < $oy2} {
            set start -90.0
            set extent 90.0
        } else {
            set start 90.0
            set extent -90.0
        }
    }

    set x0 [expr {$cx-$rad1}]
    set y0 [expr {$cy-$rad2}]
    set x1 [expr {$cx+$rad1}]
    set y1 [expr {$cy+$rad2}]
    cadobjects_object_setdatum $canv $objid "START" $start
    cadobjects_object_setdatum $canv $objid "EXTENT" $extent
    cadobjects_object_setdatum $canv $objid "BOX" [list $x0 $y0 $x1 $y1]
    cadobjects_object_setdatum $canv $objid "CENTER" [list $cx $cy]
}


proc plugin_conic2pt_decompose {canv objid coords allowed} {
    foreach {cpx1 cpy1 cpx2 cpy2} $coords break
    plugin_conic2pt_recalculate $canv $objid $coords
    set rad1 [cadobjects_object_getdatum $canv $objid "RAD1"]
    set rad2 [cadobjects_object_getdatum $canv $objid "RAD2"]
    set start  [cadobjects_object_getdatum $canv $objid "START"]
    set extent [cadobjects_object_getdatum $canv $objid "EXTENT"]
    foreach {cx cy} [cadobjects_object_getdatum $canv $objid "CENTER"] break

    if {$rad1 < 1e-6 || $rad2 < 1e-6} {
        if {"LINES" in $allowed} {
            # This is actually not a conic.
            # Draw it as a straight line between the control points.
            return [list LINES $coords]
        }
    }

    set dx [expr {abs($cpx2-$cpx1)}]
    set dy [expr {abs($cpy2-$cpy1)}]

    if {"ARC" in $allowed && abs($dx-$dy) < 1e-5} {
        return [list ARC [list $cx $cy $rad1 $start $extent]]
    } elseif {"ROTARC" in $allowed} {
        return [list ROTARC [list $cx $cy $rad1 $rad2 $start $extent 0.0]]
    } elseif {"BEZIER" in $allowed} {
        set path {}
        bezutil_append_bezier_arc path $cx $cy $rad1 $rad2 $start $extent
        return [list BEZIER $path]
    } elseif {"LINES" in $allowed} {
        set path {}
        bezutil_append_line_arc path $cx $cy $rad1 $rad2 $start $extent
        return [list LINES $path]
    }
    return {}
}


proc plugin_conic2pt_pointsofinterest {canv objid coords nearx neary} {
    set poi {}
    set nodenum 0
    foreach {x y} $coords {
        lappend poi "controlpoints" $x $y "Control point" [incr nodenum]
        incr nodenum 3
    }
    # TODO: set closeenough and tolerance for the following call.
    # cadobjects_object_bezier_pois poi "contours" "On Conic" $coords $nearx $neary
    return $poi
}


proc plugin_conic2pt_length {canv objid coords} {
    constants pi
    set rad1 [cadobjects_object_getdatum $canv $objid "RAD1"]
    set rad2 [cadobjects_object_getdatum $canv $objid "RAD2"]
    set start  [cadobjects_object_getdatum $canv $objid "START"]
    set extent [cadobjects_object_getdatum $canv $objid "EXTENT"]
    foreach {cx cy} [cadobjects_object_getdatum $canv $objid "CENTER"] break

    # TODO: This calculation is a hack!
    # Calculating the perimeter of an ellipse is hard.  This calculation is an
    # approximation, with an error of about 0.4% when when the ellipse is nearly
    # flat.  Maybe we should get a closer approx by getting the bezier len.
    set ynot [expr {log(2.0)/log($pi/2.0)}]
    set perim [expr {4.0*pow(pow($rad1,$ynot)+pow($rad2,$ynot),1.0/$ynot)}]
    set len [expr {$perim*abs($extent)/360.0}]
    return $len
}


proc plugin_conic2pt_bbox {canv objid coords} {
    return [geometry_pointlist_bbox $coords]
}






proc plugin_conic3pt_editfields {canv objid coords} {
    set out {}
    lappend out {
        type POINT
        name START
        datum 0
        title "Start pt"
    }
    lappend out {
        type POINT
        name END
        datum 1
        title "End pt"
    }
    lappend out {
        type POINT
        name CTRLPT
        datum 2
        title "Control pt"
    }
    return $out
}


proc plugin_conic3pt_drawobj {canv objid coords tags color fill width dash} {
    return 0 ;# Also draw default decomposed shape.
}


proc plugin_conic3pt_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    foreach {cpx1 cpy1 cpx2 cpy2 cpx3 cpy3} $coords break
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid CONIC3PT $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
    cadobjects_object_draw_control_line $canv $objid $cpx1 $cpy1 $cpx3 $cpy3 1 $color {2 2 2 2}
    cadobjects_object_draw_control_line $canv $objid $cpx2 $cpy2 $cpx3 $cpy3 2 $color {2 2 2 2}
}


proc plugin_conic3pt_recalculate {canv objid coords {flags ""}} {
    # TODO: This is a HACK.  Replace with proper arc calculation code.
    # Currently this is somewhere within about 0.2% positional error
    set scalar1 0.447707
    set scalar2 [expr {1.0-$scalar1}]
    foreach {x1 y1 x2 y2 x3 y3} $coords break
    set ix1 [expr {$scalar2*$x3+$scalar1*$x1}]
    set iy1 [expr {$scalar2*$y3+$scalar1*$y1}]
    set ix2 [expr {$scalar2*$x3+$scalar1*$x2}]
    set iy2 [expr {$scalar2*$y3+$scalar1*$y2}]
    set path [list $x1 $y1  $ix1 $iy1  $ix2 $iy2  $x2 $y2]
    set len [bezutil_bezier_length $path]
    cadobjects_object_setdatum $canv $objid "BEZPATH" $path
    cadobjects_object_setdatum $canv $objid "PATHLEN" $len
}


proc plugin_conic3pt_decompose {canv objid coords allowed} {
    set bezpath [cadobjects_object_getdatum $canv $objid "BEZPATH"]
    # TODO: Implement ROTARC for this.
    if {"BEZIER" in $allowed} {
        return [list BEZIER $bezpath]
    } elseif {"LINES" in $allowed} {
        set linepath {}
        bezutil_append_line_from_bezier linepath $bezpath
        return [list LINES $linepath]
    }
    return {}
}


proc plugin_conic3pt_pointsofinterest {canv objid coords nearx neary} {
    set dpi [cadobjects_get_dpi $canv]
    set scalefactor [cadobjects_get_scale_factor $canv]
    set scalemult [expr {$dpi*$scalefactor}]
    set linewidth [cadobjects_object_stroke_width $canv $objid]
    set closeenough [$canv cget -closeenough]
    set closeenough [expr {(5+$closeenough)/$scalemult+$linewidth/2.0}]
    set tolerance 1e-4

    set poi {}
    set bezpath [cadobjects_object_getdatum $canv $objid "BEZPATH"]
    set nodenum 0
    foreach {x y} $coords {
        lappend poi "controlpoints" $x $y "Control point" [incr nodenum]
        incr nodenum 3
    }
    cadobjects_object_bezier_pois poi "contours" "On Conic" $bezpath $nearx $neary $closeenough $tolerance
    return $poi
}


proc plugin_conic3pt_length {canv objid coords} {
    set len [cadobjects_object_getdatum $canv $objid "PATHLEN"]
    return $len
}


proc plugin_conic3pt_bbox {canv objid coords} {
    return [geometry_pointlist_bbox $coords]
}






proc plugin_conics_register {} {
    tool_register_ex CONIC2PT "&Arcs" "Conic Section by &2 Points" {
        {1    "Starting Point"}
        {2    "Ending Point"}
    } -icon "tool-conic2pt" -creator -impfields {ROT}
    tool_register_ex CONIC3PT "&Arcs" "Conic Section by &3 Points" {
        {1    "Starting Point"}
        {2    "Ending Point"}
        {3    "Slope Control Point"}
    } -icon "tool-conic3pt" -creator
}
plugin_conics_register 


# vim: set ts=4 sw=4 nowrap expandtab: settings

