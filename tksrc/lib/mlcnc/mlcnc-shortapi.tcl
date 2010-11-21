package require opt

proc ~ {args} {
    if {[string index $args end] != ")"} {
        error "usage: \[( expr)\]"
    }
    return [uplevel expr [string range $args 0 end-1]]
}

tcl::OptProc angledto {
    {xvar    {}   "The variable to set with the X axis offset."}
    {yvar    {}   "The variable to set with the Y axis offset."}
    {cx      0.0  "The X axis position of the reference point."}
    {cy      0.0  "The Y axis position of the reference point."}
    {rot     0.0  "The angle that the item is, relative to the reference point."}
    {-radius 0.0  "The distance from the reference point to the item."}
    {-diam   0.0  "Twice the distance from the center point to the item."}
    {cmd     {}   "The command to execute for each ring item."}
} {
    upvar $xvar v1
    upvar $yvar v2
    constants pi
    if {$radius == 0.0 && $diam == 0.0} {
        error "ringof: You must specify either -radius or -diameter"
    } elseif {$radius != 0.0 && $diam != 0.0} {
        error "ringof: You must specify only one of -radius or -diameter"
    } elseif {$diam != 0.0} {
        set radius [expr {$diam/2.0}]
    }
    set rot [expr {$rot*$pi/180.0}]
    set v1 [expr {$radius*cos($rot)+$cx}]
    set v2 [expr {$radius*sin($rot)+$cy}]
    set res [uplevel $cmd]
    return $res
}




tcl::OptProc ringof {
    {xvar    {}   "The variable to set with the X axis offset."}
    {yvar    {}   "The variable to set with the Y axis offset."}
    {cx      0.0  "The X axis position of the center of the ring."}
    {cy      0.0  "The Y axis position of the center of the ring."}
    {-radius 0.0  "The radius of the centerline of the ring."}
    {-diam   0.0  "The diameter of the centerline of the ring."}
    {-rot    0.0  "Offset from 0 degrees for the first ring item."}
    {-count  4    "Number of items in the ring."}
    {cmd     {}   "The command to execute for each ring item."}
} {
    upvar $xvar v1
    upvar $yvar v2
    constants pi
    if {$radius == 0.0 && $diam == 0.0} {
        error "ringof: You must specify either -radius or -diameter"
    } elseif {$radius != 0.0 && $diam != 0.0} {
        error "ringof: You must specify only one of -radius or -diameter"
    } elseif {$diam != 0.0} {
        set radius [expr {$diam/2.0}]
    }
    set rot [expr {$rot*$pi/180.0}]
    set dang [expr {2.0*$pi/$count}]
    set ang 0.0
    set eang [expr {2.0*$pi}]
    while {abs($ang-$eang) > 1e-10} {
        set v1 [expr {$radius*cos($ang+$rot)+$cx}]
        set v2 [expr {$radius*sin($ang+$rot)+$cy}]
        set res [uplevel $cmd]
        set ang [expr {$ang+$dang}]
    }
    return $res
}




proc mlg_start {} {
    return [mlcnc_g_start]
}


proc mlg_tool {toolnum} {
    return [mlcnc_g_set_tool $toolnum]
}


tcl::OptProc mlg_path {
    {path {} "The path to follow."}
} {
    return [mlcnc_g_follow_path $path]
}


tcl::OptProc mlg_circle {
    {cx 0.0 "The X coordinate of the circle's center."}
    {cy 0.0 "The X coordinate of the circle's center."}
    {depth 0.0 "The depth to mill the cicle down to."}
    {-radius 0.0 "The radius of the outside of the circle."}
    {-diam 0.0 "The diameter of the outside of the circle."}
    {-iradius 0.0 "The radius of the inside of the circle."}
    {-idiam 0.0 "The diameter of the inside of the circle."}
    {-pocket "If given, clear out inside of circle."}
    {-finish -choice {outside inside both none} "Side of the circle that should have a finishing pass."}
} {
    if {$radius != 0.0 && $diam != 0.0} {
        error "mlg_circle: You must specify only one of -radius or -diameter"
    } elseif {$diam != 0.0} {
        set orad [expr {$diam/2.0}]
    } else {
        set orad $radius
    }
    if {!$pocket} {
        if {$iradius == 0.0 && $idiam == 0.0} {
            set tooldiam [mlcnc_tooldiam]
            set iradius [expr {$orad-$tooldiam/2.0}]
        }
    }
    if {$iradius != 0.0 && $idiam != 0.0} {
        error "mlg_circle: You must specify only one of -iradius or -idiameter"
    } elseif {$idiam != 0.0} {
        set irad [expr {$idiam/2.0}]
    } else {
        set irad $iradius
    }
    return [mlcnc_g_circle $cx $cy $depth $orad $irad $finish]
}


tcl::OptProc mlg_rect {
    {x1 0.0 "The X coord of the rect's upper left corner."}
    {y1 0.0 "The Y coord of the rect's upper left corner."}
    {x2 0.0 "The X coord of the rect's lower right corner."}
    {y2 0.0 "The Y coord of the rect's lower right corner."}
    {depth 0.0 "The depth to mill the rect down to."}
    {-pocket "If given, clear out inside of rectangle."}
    {-finish "If given, adds a finishing pass to the rect milling."}
    {-offset -choice {none inside outside} "Side of the rect that should be milled away."}
} {
    if {$pocket} {
        if {$offset == "outside"} {
            error "mlg_rect: Can't pocket the outside of a rect!"
        }
        return [mlcnc_g_rectangle $x1 $y1 $x2 $y2 $depth $finish]
    } else {
        set path [list $x1 $y1  $x1 $y2  $x2 $y2  $x2 $y1  $x1 $y1]
        if {$offset == "inside"} {
            set offset "right"
        } elseif {$offset == "outside"} {
            set offset "left"
        }
        return [mlcnc_g_path $path $depth $offset]
    }
}



tcl::OptProc mlg_path {
    {path  {}  "The path to mill."}
    {depth 0.0 "The depth to mill the rect down to."}
    {-close "If given, closes the path."}
    {-pocket "If given, clears out inside of the closed path."}
    {-finish "If given, adds a finishing pass to the path milling."}
    {-offset -choice {none inside outside} "Side of the rect that should be milled away."}
} {
    foreach {x0 y0} [lrange $path 0 1]  break
    foreach {xl yl} [lrange $path end-1 end] break
    set closeenough 1e-5
    set isclosed 0
    if {abs($x0-$xl) < $closeenough && abs($y0-$yl) < $closeenough} {
        set isclosed 1
    }
    if {$close && !$isclosed} {
        lappend path [lindex $path 0] [lindex $path 1]
        set isclosed 1
    }
    if {$pocket} {
        if {!$isclosed || $offset == "outside"} {
            error "mlg_path: Can only pocket out the inside of a closed path!"
        }
        return [mlcnc_g_polygon $path $depth $finish]
    }
}


tcl::OptProc mlg_screwhole {
    {cx 0.0 "The X coordinate of the circle's center."}
    {cy 0.0 "The X coordinate of the circle's center."}
    {depth 0.0 "The depth to mill the cicle down to."}
    {-size -string {#10} "The size of the screw to make a hole for."}
    {-tap "If given, make the hole smaller, so it can be tapped."}
    {-pitch 0.0 "The thread pitch to make a tap hole for."}
    {-fit -choice {loose close} "The fit of the hole for the screw."}
} {
    if {$tap} {
        if {$pitch == 0.0} {
            error "Must specify -pitch when using -tap!"
        }
        if {$fit == "close"} {
            error "Cannot specify -fit with -tap!"
        }
        return [mlcnc_g_screw_tap $cx $cy $depth $size $pitch]
    } else {
        if {$pitch != 0.0} {
            error "Can only specify -pitch when using -tap!"
        }
        return [mlcnc_g_screw_hole $cx $cy $depth $size $fit]
    }
}

# vim: set ts=4 sw=4 nowrap expandtab: settings

