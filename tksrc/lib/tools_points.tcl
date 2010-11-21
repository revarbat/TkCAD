proc plugin_point_editfields {canv objid coords} {
    set out {}
    lappend out {
        type POINT
        name POINT
        datum 0
        title "Point"
    }
    return $out
}


proc plugin_point_drawobj {canv objid coords tags color fill width dash} {
    foreach {x y} [cadobjects_scale_coords $canv $coords] break
    set x1 [expr {$x-3}]
    set y1 [expr {$y-3}]
    set x2 [expr {$x+3}]
    set y2 [expr {$y+3}]
    $canv create line [list $x1 $y $x2 $y] -tags $tags -fill $color -width $width -dash $dash
    $canv create line [list $x $y1 $x $y2] -tags $tags -fill $color -width $width -dash $dash
    return 1 ;# I drew it myself.
}


proc plugin_point_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid POINT $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_point_recalculate {canv objid coords {flags ""}} {
    # Nothing to do.  The control points are all the data needed.
}


proc plugin_point_decompose {canv objid coords allowed} {
    foreach {x y} $coords break

    if {"POINTS" in $allowed} {
        set path [list $x $y $x $y]
        return [list POINTS $coords]
    }
    return {}
}


proc plugin_point_bbox {canv objid coords} {
    set coords [concat $coords $coords]
    return [geometry_pointlist_bbox $coords]
}






proc plugin_point_register {} {
    tool_register_ex POINT "&Miscellaneous" "P&oint" {
        {1    "Point Location"}
    } -icon "tool-point" -creator
}
plugin_point_register 

# vim: set ts=4 sw=4 nowrap expandtab: settings

