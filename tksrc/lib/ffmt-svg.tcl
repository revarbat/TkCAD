proc ffmt_plugin_save_svg {win canv filename} {
    return [ffmt_plugin_writefile_svg $win $canv $filename 0]
}



proc ffmt_plugin_open_svg {win canv filename} {
    return [ffmt_plugin_readfile_svg $win $canv $filename]
}



proc ffmt_plugin_save_svglaser {win canv filename} {
    global ffmtSvgInfo
    set ffmtSvgInfo(RESULT) 0
    set ffmtSvgInfo(KERF) [/prefs:get laser_kerf]

    set win [toplevel .laserwin -padx 20 -pady 20]
    wm title $win "SVG for Laser Settings"
    set kerflbl [label $win.kerflbl -text "Kerf"]
    set kerfspin [spinbox $win.kerfspin -format "%0.4f" -from 0.0 -to 0.05 -increment 0.001 -width 8 -justify right -textvariable ffmtSvgInfo(KERF)]
    set kerfunit [label $win.kerfunit -text "inches"]
    set exportbtn [button $win.exportbtn -text "Export" -command "set ffmtSvgInfo(RESULT) 1; destroy $win" -default active]
    set cancelbtn [button $win.cancelbtn -text "Cancel" -command "set ffmtSvgInfo(RESULT) 0; destroy $win"]

    grid $kerflbl $kerfspin  $kerfunit -padx 5 -pady 5 -sticky nw
    grid x        $exportbtn $cancelbtn -padx 5 -pady 5 -sticky nw
    grid $kerfunit -padx 0

    grab $win
    tkwait window $win
    if {$ffmtSvgInfo(RESULT) == 0} {
        return
    }
    set kerf $ffmtSvgInfo(KERF)
    /prefs:set laser_kerf $kerf
    return [ffmt_plugin_writefile_svg $win $canv $filename [expr {$kerf/2.0}]]
}




proc ffmt_plugin_init_svg {} {
    fileformat_register READWRITE SVG "SVG Files" .svg
    fileformat_register WRITE SVGLASER "SVG For Laser" .SVG
}

ffmt_plugin_init_svg 




####################################################################
# Private functions follow below.
# These are NOT part of the FileFormat Plugin API.
####################################################################

proc svg_len {val} {
    set svg_dpi 90.0
    set out [format "%.12g" [expr {$val*$svg_dpi}]]
    if {[string first "e" $out] != -1} {
        set out [format "%.12f" [expr {$val*$svg_dpi}]]
        set out [string trimright $out "0"]
        if {[string index $out end] == "."} {
            set out [string range $out 0 end-1]
        }
    }
    return $out
}


proc svg_hpos {val} {
    return [svg_len $val]
}


proc svg_vpos {val} {
    global svg_top_pos
    return [svg_len [expr {$svg_top_pos-$val}]]
}


proc svg_coord {x y} {
    set out [svg_hpos $x]
    append out ","
    append out [svg_vpos $y]
    return $out
}


proc svg_get_float {str} {
    if {[scan $str " %f %n" num pos] < 2} {
        return [list "" $str]
    }
    set str [string range $str $pos end]
    return [list $num $str]
}


proc svg_decode_length {val} {
    set val [string trim $val]
    foreach {unitpat unitval} {
        "*in" 1.0
        "*cm" 2.54
        "*pc" 6.0
        "*ex" 6.5
        "*em" 7.5
        "*mm" 25.4
        "*%"  45.0
        "*pt" 72.0
        "*px" 90.0
    } {
        if {[string match $unitpat $val]} {
            set len [string length $unitpat]
            incr len -1
            set val [string trim [string range $val 0 end-$len]]
            if {![string is double -strict $val]} {
                return ""
            }
            set val [expr {$val/$unitval}]
            return $val
        }
    }
    if {[string is double -strict $val]} {
        return [expr {$val/90.0}]
    }
    return ""
}


proc svg_decode_dash {val} {
    set val [string trim $val]
    if {$val == ""} {
        return "solid"
    }
    set lens [split $val ","]
    if {[llength $lens] == 0} {
        return "solid"
    }
    if {[llength $lens] % 2 == 1} {
        set lens [concat $lens $lens]
    }
    set lens [concat $lens $lens $lens $lens]
    set dashes {}
    foreach {dash space} $lens {
        lappend dashes [svg_decode_length $dash]
    }
    set d0 [lindex $dashes 0]
    set d1 [lindex $dashes 1]
    set d2 [lindex $dashes 2]
    set d3 [lindex $dashes 2]
    if {$d0 <= 5 && $d1 <= 5 && $d2 <= 5} {
        return "construction"
    }
    if {$d0 <= 5 && $d1 <= 5 && $d2 > 5 && $d3 <= 5} {
        return "cutline"
    }
    if {$d0 <= 5 && $d1 > 5 && $d2 <= 5 && $d3 <= 5} {
        return "cutline"
    }
    if {$d0 > 5 && $d1 <= 5 && $d2 <= 5 && $d3 > 5} {
        return "cutline"
    }
    if {$d0 <= 5 && $d1 > 5 && $d2 <= 5 && $d3 > 5} {
        return "centerline"
    }
    if {$d0 > 5 && $d1 <= 5 && $d2 > 5 && $d3 <= 5} {
        return "centerline"
    }
    return "hidden"
}


proc svg_decode_color {val} {
    if {$val == ""} {
        return "#000"
    }
    if {$val == "none"} {
        return ""
    }
    if {$val == "currentColor"} {
        return "#000"
    }
    if {![catch {winfo rgb . $val} color]} {
        foreach {r g b} $color break
        return [format "#%04x%04x%04x" $r $g $b]
    }
    return "#000"
}


proc svg_decode_stroke {canv objid var} {
    upvar $var attr
    foreach {var name defval} {
        lcolor  stroke            ""
        lwidth  stroke-width      1.0
        ldash   stroke-dasharray  ""
        ldoff   stroke-dashoffset 0.0
        lcap    stroke-linecap    "butt"
        ljoin   stroke-linejoin   "miter"
        lmlim   stroke-miterlimit 4.0
        fcolor  fill              "none"
    } {
        set $var $defval
        catch {
            set $var $attr($name)
        }
    }
    set lcolor [svg_decode_color $lcolor]
    set lwidth [svg_decode_length $lwidth]
    set ldash  [svg_decode_dash $ldash]
    set fcolor [svg_decode_color $fcolor]

    # Presumably, these are new objects anyways.
    cutpaste_suspend_recording $canv
    cadobjects_object_setdatum $canv $objid "FILLCOLOR" $fcolor
    cadobjects_object_setdatum $canv $objid "LINECOLOR" $lcolor
    cadobjects_object_setdatum $canv $objid "LINEWIDTH" $lwidth
    cadobjects_object_setdatum $canv $objid "LINEDASH" $ldash
    cutpaste_resume_recording $canv
}


proc svg_decode_transform {mat1 transform} {
    set transform [string tolower $transform]
    set transform [string trimleft $transform]
    while {$transform != ""} {
        switch -glob -- $transform {
            "matrix*" {
                scan $transform "matrix ( %n" pos
                set transform [string range $transform $pos end]
                foreach {a transform} [svg_get_float $transform] break
                set transform [string trimleft $transform " \n\t,"]
                foreach {b transform} [svg_get_float $transform] break
                set transform [string trimleft $transform " \n\t,"]
                foreach {c transform} [svg_get_float $transform] break
                set transform [string trimleft $transform " \n\t,"]
                foreach {d transform} [svg_get_float $transform] break
                set transform [string trimleft $transform " \n\t,"]
                foreach {e transform} [svg_get_float $transform] break
                set transform [string trimleft $transform " \n\t,"]
                foreach {f transform} [svg_get_float $transform] break
                set transform [string trimleft $transform " \n\t,"]
                if {$f == "" || [string index $transform 0] != ")"} {
                    # Aborting early due to bad expression
                    return $mat1
                }
                set transform [string range $transform 1 end]
                set transform [string trimleft $transform]
                set mat2 [list [list $a $c $e] [list $b $d $f] [list 0 0 1]]
                set mat1 [matrix_mult $mat1 $mat2]
            }
            "translate*" {
                scan $transform "translate ( %n" pos
                set transform [string range $transform $pos end]
                foreach {dx transform} [svg_get_float $transform] break
                set transform [string trimleft $transform " \n\t,"]
                foreach {dy transform} [svg_get_float $transform] break
                if {$dx == "" || [string index $transform 0] != ")"} {
                    # Aborting early due to bad expression
                    return $mat1
                }
                if {$dy == ""} {
                    set dy 0.0
                }
                set transform [string range $transform 1 end]
                set transform [string trimleft $transform]
                set mat2 [matrix_translate $dx $dy]
                set mat1 [matrix_mult $mat1 $mat2]
            }
            "rotate*" {
                scan $transform "rotate ( %n" pos
                set transform [string range $transform $pos end]
                set transform [string trimleft $transform " \n\t,"]

                foreach {ang transform} [svg_get_float $transform] break
                set transform [string trimleft $transform " \n\t,"]

                foreach {cx transform} [svg_get_float $transform] break
                set transform [string trimleft $transform " \n\t,"]

                foreach {cy transform} [svg_get_float $transform] break
                set transform [string trimleft $transform " \n\t,"]

                if {$ang == "" || [string index $transform 0] != ")"} {
                    # Aborting early due to bad expression
                    return $mat1
                }
                if {$cy == ""} {
                    set cx 0.0
                    set cy 0.0
                }
                set transform [string range $transform 1 end]
                set transform [string trimleft $transform]
                if {$cx != 0.0 || $cy != 0.0} {
                    set mat2 [matrix_translate $cx $cy]
                    set mat1 [matrix_mult $mat1 $mat2]
                }
                set mat2 [matrix_rotate $ang]
                set mat1 [matrix_mult $mat1 $mat2]
                if {$cx != 0.0 || $cy != 0.0} {
                    set mat2 [matrix_translate [expr {-$cx}] [expr {-$cy}]]
                    set mat1 [matrix_mult $mat1 $mat2]
                }
            }
            "scale*" {
                scan $transform "scale ( %n" pos
                set transform [string range $transform $pos end]
                foreach {sx transform} [svg_get_float $transform] break
                set transform [string trimleft $transform " \n\t,"]
                foreach {sy transform} [svg_get_float $transform] break
                if {$sx == "" || [string index $transform 0] != ")"} {
                    # Aborting early due to bad expression
                    return $mat1
                }
                if {$sy == ""} {
                    set sy $sx
                }
                set transform [string range $transform 1 end]
                set transform [string trimleft $transform]
                set mat2 [matrix_scale $sx $sy]
                set mat1 [matrix_mult $mat1 $mat2]
            }
            "skewx*" {
                scan $transform "skewx ( %n" pos
                set transform [string range $transform $pos end]
                foreach {ang transform} [svg_get_float $transform] break
                if {$ang == "" || [string index $transform 0] != ")"} {
                    # Aborting early due to bad expression
                    return $mat1
                }
                set transform [string range $transform 1 end]
                set transform [string trimleft $transform]
                set mat2 [matrix_skew_x $ang]
                set mat1 [matrix_mult $mat1 $mat2]
            }
            "skewy*" {
                scan $transform "skewy ( %n" pos
                set transform [string range $transform $pos end]
                foreach {ang transform} [svg_get_float $transform] break
                if {$ang == "" || [string index $transform 0] != ")"} {
                    # Aborting early due to bad expression
                    return $mat1
                }
                set transform [string range $transform 1 end]
                set transform [string trimleft $transform]
                set mat2 [matrix_skew_y $ang]
                set mat1 [matrix_mult $mat1 $mat2]
            }
            default {
                # Aborting early due to bad expression
                return $mat1
            }
        }
        set transform [string trimleft $transform]
    }
    return $mat1
}


proc svg_bbox_expand {bbox coords} {
    foreach {x0 y0} [lrange $coords 0 1] break
    if {$bbox == ""} {
        set minx $x0
        set maxx $x0
        set miny $y0
        set maxy $y0
    } else {
        lassign $bbox minx miny maxx maxy
        if {$x0 < $minx} {set minx $x0}
        if {$x0 > $maxx} {set maxx $x0}
        if {$y0 < $miny} {set miny $y0}
        if {$y0 > $maxy} {set maxy $y0}
    }
    foreach {x1 y1} [lrange $coords 2 end] {
        if {$x1 < $minx} {set minx $x1}
        if {$x1 > $maxx} {set maxx $x1}
        if {$y1 < $miny} {set miny $y1}
        if {$y1 > $maxy} {set maxy $y1}
    }
    return [list $minx $miny $maxx $maxy]
}


proc ffmt_plugin_writeobj_svg {win canv f objid halfkerf objcountvar {linepfx ""}} {
    constants pi
    set type   [cadobjects_object_gettype $canv $objid]
    set coords [cadobjects_object_get_coords $canv $objid]
    upvar $objcountvar objnum

    if {$type == "GROUP"} {
        puts -nonewline $f $linepfx
        set children [cadobjects_object_getdatum $canv $objid "CHILDREN"]
        if {[llength $children] > 0} {
            xmlutil_write_block_open $f "g"
            foreach child $children {
                ffmt_plugin_writeobj_svg $win $canv $f $child $halfkerf objnum "  $linepfx"
            }
            puts -nonewline $f $linepfx
            xmlutil_write_block_close $f "g"
        }
    } else {
        puts -nonewline $f $linepfx
        if {$halfkerf} {
            set allowed {ELLIPSE CIRCLE RECTANGLE ROTRECT ARC ROTARC LINES POINTS TEXT ROTTEXT LASER}
            set cutside [cadobjects_object_getdatum $canv $objid "CUTSIDE"]
        } else {
            set allowed {ELLIPSE CIRCLE RECTANGLE ROTRECT ARC ROTARC QUADBEZ BEZIER LINES POINTS TEXT ROTTEXT}
        }
        set fcolor [cadobjects_object_getdatum $canv $objid "FILLCOLOR"]
        set lcolor [cadobjects_object_getdatum $canv $objid "LINECOLOR"]
        set lwidth [cadobjects_object_getdatum $canv $objid "LINEWIDTH"]
        set ldash  [cadobjects_object_getdatum $canv $objid "LINEDASH" ]
        if {$fcolor == ""} { set fcolor "none" }
        if {$lcolor == "none"} { set lcolor "" }
        if {$ldash == "none"}  { set ldash "" }
        foreach {dectype data} [cadobjects_object_decompose $canv $objid $allowed] {
            switch -exact -- $dectype {
                ELLIPSE {
                    foreach {cx cy rad1 rad2} $data break
                    if {$halfkerf} {
                        if {$cutside == "inside"} {
                            set rad1 [expr {$rad1-$halfkerf}]
                            set rad2 [expr {$rad2-$halfkerf}]
                        } elseif {$cutside == "outside"} {
                            set rad1 [expr {$rad1+$halfkerf}]
                            set rad2 [expr {$rad2+$halfkerf}]
                        }
                    }
                    xmlutil_write_element $f "ellipse" \
                        cx [svg_hpos $cx] \
                        cy [svg_vpos $cy] \
                        rx [svg_len $rad1] \
                        ry [svg_len $rad2] \
                        fill $fcolor stroke $lcolor stroke-width "${lwidth}in"
                }
                ELLIPSEROT {
                    foreach {cx cy rad1 rad2 rot} $data break
                    if {$halfkerf} {
                        if {$cutside == "inside"} {
                            set rad1 [expr {$rad1-$halfkerf}]
                            set rad2 [expr {$rad2-$halfkerf}]
                        } elseif {$cutside == "outside"} {
                            set rad1 [expr {$rad1+$halfkerf}]
                            set rad2 [expr {$rad2+$halfkerf}]
                        }
                    }
                    if {abs($rot) < 1e-6} {
                        xmlutil_write_element $f "ellipse" \
                            cx [svg_hpos $cx] \
                            cy [svg_vpos $cy] \
                            rx [svg_len $rad1] \
                            ry [svg_len $rad2] \
                            fill $fcolor stroke $lcolor stroke-width "${lwidth}in"
                    } else {
                        xmlutil_write_element $f "ellipse" \
                            transform "rotate($rot [svg_coord $cx $cy])" \
                            cx [svg_hpos $cx] \
                            cy [svg_vpos $cy] \
                            rx [svg_len $rad1] \
                            ry [svg_len $rad2] \
                            fill $fcolor stroke $lcolor stroke-width "${lwidth}in"
                    }
                }
                CIRCLE {
                    foreach {cx cy rad1} $data break
                    if {$halfkerf} {
                        if {$cutside == "inside"} {
                            set rad1 [expr {$rad1-$halfkerf}]
                        } elseif {$cutside == "outside"} {
                            set rad1 [expr {$rad1+$halfkerf}]
                        }
                    }
                    xmlutil_write_element $f "circle" \
                        cx [svg_hpos $cx] \
                        cy [svg_vpos $cy] \
                        r [svg_len $rad1] \
                        fill $fcolor stroke $lcolor stroke-width "${lwidth}in"
                }
                RECTANGLE {
                    foreach {x0 y0 x1 y1} $data break
                    set dx [expr {$x1-$x0}]
                    set dy [expr {$y0-$y1}]
                    if {$dx < 0.0} {
                        set dx [expr {-$dx}]
                        set x0 $x1
                    }
                    if {$dy < 0.0} {
                        set dy [expr {-$dy}]
                        set y0 $y1
                    }
                    if {$halfkerf} {
                        if {$cutside == "inside"} {
                            set dx [expr {$dx-$halfkerf}]
                            set dy [expr {$dy-$halfkerf}]
                        } elseif {$cutside == "outside"} {
                            set dx [expr {$dx+$halfkerf}]
                            set dy [expr {$dy+$halfkerf}]
                        }
                    }
                    xmlutil_write_element $f "rect" \
                        x [svg_hpos $x0] \
                        y [svg_vpos $y0] \
                        width [svg_len $dx] \
                        height [svg_len $dy] \
                        fill $fcolor stroke $lcolor stroke-width "${lwidth}in"
                }
                ROTRECT {
                    foreach {cx cy hdx hdy rot} $data break
                    set hdx [expr {abs($hdx)}]
                    set hdy [expr {abs($hdy)}]
                    if {$halfkerf} {
                        if {$cutside == "inside"} {
                            set hdx [expr {$hdx-$halfkerf}]
                            set hdy [expr {$hdy-$halfkerf}]
                        } elseif {$cutside == "outside"} {
                            set hdx [expr {$hdx+$halfkerf}]
                            set hdy [expr {$hdy+$halfkerf}]
                        }
                    }
                    set x0 [expr {$cx-$hdx}]
                    set y0 [expr {$cy-$hdy}]
                    set dx [expr {abs($hdx*2.0)}]
                    set dy [expr {abs($hdy*2.0)}]
                    xmlutil_write_element $f "rect" \
                        transform "rotate($rot) translate([svg_coord $cx $cy])" \
                        x [svg_hpos -$hdx] \
                        y [svg_vpos -$hdy] \
                        width [svg_len $dx] \
                        height [svg_len $dy] \
                        fill $fcolor stroke $lcolor stroke-width "${lwidth}in"
                }
                ARC {
                    foreach {cx cy rad1 start extent} $data break
                    if {$halfkerf} {
                        if {$cutside == "inside"} {
                            set rad1 [expr {$rad1-$halfkerf}]
                        } elseif {$cutside == "outside"} {
                            set rad1 [expr {$rad1+$halfkerf}]
                        }
                    }
                    set startang [expr {fmod($start,360.0)*$pi/180.0}]
                    set endang [expr {fmod($start+$extent,360.0)*$pi/180.0}]
                    set x0 [expr {$rad1*cos($startang)+$cx}]
                    set y0 [expr {$rad1*sin($startang)+$cy}]
                    set x [expr {$rad1*cos($endang)+$cx}]
                    set y [expr {$rad1*sin($endang)+$cy}]
                    set sweep 0
                    set long 0
                    if {abs($extent) > 180.0} {
                        set long 1
                    }
                    if {$extent < 0.0} {
                        set sweep 1
                    }
                    set path "M[svg_coord $x0 $y0] A[svg_len $rad1],[svg_len $rad1] 0.0 $long,$sweep [svg_coord $x $y]"
                    xmlutil_write_element $f "path" d $path \
                        fill $fcolor stroke $lcolor stroke-width "${lwidth}in"
                }
                ROTARC {
                    foreach {cx cy rad1 rad2 start extent rot} $data break
                    if {$halfkerf} {
                        if {$cutside == "inside"} {
                            set rad1 [expr {$rad1-$halfkerf}]
                            set rad2 [expr {$rad2-$halfkerf}]
                        } elseif {$cutside == "outside"} {
                            set rad1 [expr {$rad1+$halfkerf}]
                            set rad2 [expr {$rad2+$halfkerf}]
                        }
                    }
                    set startang [expr {fmod($start,360.0)*$pi/180.0}]
                    set endang [expr {fmod($start+$extent,360.0)*$pi/180.0}]
                    set x0 [expr {$rad1*cos($startang)+$cx}]
                    set y0 [expr {$rad1*sin($startang)+$cy}]
                    set x [expr {$rad1*cos($endang)+$cx}]
                    set y [expr {$rad1*sin($endang)+$cy}]
                    set rotr [expr {$rot*$pi/180.0}]
                    set sinv [expr {sin($rotr)}]
                    set cosv [expr {cos($rotr)}]
                    set spx [expr {$cosv*($x0-$cx)-$sinv*($y0-$cy)+$cx}]
                    set spy [expr {$sinv*($x0-$cx)+$cosv*($y0-$cy)+$cy}]
                    set epx [expr {$cosv*($x-$cx)-$sinv*($y-$cy)+$cx}]
                    set epy [expr {$sinv*($x-$cx)+$cosv*($y-$cy)+$cy}]
                    set sweep 0
                    set long 0
                    if {abs($extent) > 180.0} {
                        set long 1
                    }
                    if {$extent < 0.0} {
                        set sweep 1
                    }
                    set path "M[svg_coord $spx $spy] A[svg_len $rad1],[svg_len $rad2] $rot $long,$sweep [svg_coord $epx $epy]"
                    xmlutil_write_element $f "path" d $path \
                        fill $fcolor stroke $lcolor stroke-width "${lwidth}in"
                }
                QUADBEZ {
                    foreach {x0 y0} [lrange $data 0 1] break
                    set ox0 $x0
                    set oy0 $y0
                    set path "M[svg_coord $x0 $y0]"
                    foreach {x1 y1 x2 y2} [lrange $data 2 end] {
                        append path "\n$linepfx  Q[svg_coord $x1 $y1] [svg_coord $x2 $y2]"
                        set x0 $x2
                        set y0 $y2
                    }
                    set fillcolor "none"
                    if {[geometry_path_is_closed $data]} {
                        append path " Z"
                        set fillcolor $fcolor
                    }
                    xmlutil_write_element $f "path" d $path \
                        fill $fillcolor stroke $lcolor stroke-width "${lwidth}in"
                }
                BEZIER {
                    foreach {x0 y0} [lrange $data 0 1] break
                    set ox0 $x0
                    set oy0 $y0
                    set path "M[svg_coord $x0 $y0]"
                    foreach {x1 y1 x2 y2 x3 y3} [lrange $data 2 end] {
                        append path "\n$linepfx  C[svg_coord $x1 $y1] [svg_coord $x2 $y2] [svg_coord $x3 $y3]"
                        set x0 $x3
                        set y0 $y3
                    }
                    if {hypot($x3-$ox0,$y3-$oy0) < 1e-6} {
                        append path " Z"
                    }
                    set fillcolor "none"
                    if {[geometry_path_is_closed $data]} {
                        set fillcolor $fcolor
                    }
                    xmlutil_write_element $f "path" d $path \
                        fill $fillcolor stroke $lcolor stroke-width "${lwidth}in"
                }
                LINES {
                    set lineset [list $data]
                    if {$halfkerf} {
                        if {$cutside == "right"} {
                            set lineset [mlcnc_path_offset $data $halfkerf]
                        } elseif {$cutside == "left"} {
                            set lineset [mlcnc_path_offset $data -$halfkerf]
                        } elseif {$cutside == "inside"} {
                            set lineset [mlcnc_path_inset $data $halfkerf]
                        } elseif {$cutside == "outside"} {
                            set lineset [mlcnc_path_inset $data -$halfkerf]
                        }
                    }
                    foreach data $lineset {
                        foreach {x0 y0} [lrange $data 0 1] break
                        set ox0 $x0
                        set oy0 $y0
                        set path "M[svg_coord $x0 $y0]"
                        foreach {x1 y1} [lrange $data 2 end] {
                            append path "\n$linepfx  L[svg_coord $x1 $y1]"
                            set x0 $x1
                            set y0 $y1
                        }
                        if {hypot($x1-$ox0,$y1-$oy0) < 1e-6} {
                            append path " Z"
                        }
                        set fillcolor "none"
                        if {[geometry_path_is_closed $data]} {
                            set fillcolor $fcolor
                        }
                        xmlutil_write_element $f "path" d $path \
                            fill $fillcolor stroke $lcolor stroke-width "${lwidth}in"
                    }
                }
                POINTS {
                    foreach {x y} $data {
                        set x [svg_hpos $x]
                        set y [svg_vpos $y]
                        set px0 [expr {$x-2}]
                        set py0 [expr {$y-2}]
                        set px1 [expr {$x+2}]
                        set py1 [expr {$y+2}]
                        set path "M$px0,$y L$px1,$y M$x,$py0 L$x,$py1"
                        xmlutil_write_element $f "path" d $path \
                            fill $fcolor stroke $lcolor stroke-width "${lwidth}in"
                    }
                }
                TEXT {
                    foreach {cx cy txt font just} $data break
                    set ffam [lindex $font 0]
                    set fsiz [expr {int(0.5+[lindex $font 1]*90.0/72.0)}]
                    switch -exact -- $just {
                        center { set anchor middle }
                        right  { set anchor end }
                        default { set anchor start }
                    }
                    set lines [split $txt "\n"]
                    set lspace [font metrics $font -linespace]
                    set dy [expr {$lspace*([llength $lines]-1)/72.0}]
                    set cy [expr {$cy+$dy}]
                    xmlutil_write_block_open $f "text" \
                        x [svg_hpos $cx] \
                        y [svg_vpos $cy] \
                        fill $fcolor \
                        font-family $ffam \
                        font-size $fsiz \
                        text-anchor $anchor
                    puts -nonewline $f [xmlutil_escape_value [lindex $lines 0]]
                    foreach ln [lrange $lines 1 end] {
                        xmlutil_write_block_open $f "tspan" \
                            x [svg_hpos $cx] \
                            dy "[expr {$lspace*90.0/72.0}]px"
                        puts -nonewline $f [xmlutil_escape_value $ln]
                        xmlutil_write_block_close $f "tspan"
                    }
                    xmlutil_write_block_close $f "text"
                }
                ROTTEXT {
                    foreach {cx cy txt font just rot} $data break
                    set ffam [lindex $font 0]
                    set fsiz [expr {[lindex $font 1]*125.0/72.0}]
                    switch -exact -- $just {
                        center { set anchor middle }
                        right  { set anchor end }
                        default { set anchor start }
                    }
                    set lines [split $txt "\n"]
                    set lspace [font metrics $font -linespace]
                    set dy [expr {$lspace*([llength $lines]-1)/72.0}]
                    set cy [expr {$cy+$dy}]
                    set nrot [expr {-$rot}]
                    xmlutil_write_block_open $f "text" \
                        transform "rotate($nrot [svg_coord $cx $cy])" \
                        x [svg_hpos $cx] \
                        y [svg_vpos $cy] \
                        fill $fcolor \
                        font-family $ffam \
                        font-size $fsiz \
                        text-anchor $anchor
                    puts -nonewline $f [xmlutil_escape_value [lindex $lines 0]]
                    foreach ln [lrange $lines 1 end] {
                        xmlutil_write_block_open $f "tspan" \
                            x [svg_hpos $cx] \
                            dy "[expr {$lspace*90.0/72.0}]px"
                        puts -nonewline $f [xmlutil_escape_value $ln]
                        xmlutil_write_block_close $f "tspan"
                    }
                    xmlutil_write_block_close $f "text"
                }
            }
        }
    }
}


proc ffmt_plugin_writefile_svg {win canv filename halfkerf} {
    global svg_top_pos
    set objcount [llength [cadobjects_object_ids $canv]]
    progwin_create .svg-progwin "tkCAD Export" "Exporting SVG file..."
    set objnum 0

    set bbox [cadobjects_objects_bbox $canv]
    foreach {minx miny maxx maxy} $bbox break
    set viewBox ""
    set svg_top_pos $maxy
    set width [expr {abs($maxx-$minx)}]
    set height [expr {abs($maxy-$miny)}]

    append viewBox [svg_hpos $minx] " " [svg_vpos $maxy] " " [svg_len $width] " " [svg_len $height]

    set f [open $filename "w"]
    puts $f {<?xml version="1.0" encoding="UTF-8"?>}
    puts $f {<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">}
    xmlutil_write_block_open $f "svg" xmlns "http://www.w3.org/2000/svg" xml:space "preserve" width "${width}in" height "${height}in" viewBox $viewBox style "shape-rendering:geometricPrecision; text-rendering:geometricPrecision; image-rendering:optimizeQuality; fill-rule:evenodd; clip-rule:evenodd" xmlns:xlink "http://www.w3.org/1999/xlink"
    foreach layer [layer_ids $canv] {
        set layername [layer_name $canv $layer]
        puts -nonewline $f "  "
        xmlutil_write_block_open $f "g" id $layername stroke [layer_color $canv $layer]
        foreach objid [layer_objects $canv $layer] {
            incr objnum
            ffmt_plugin_writeobj_svg $win $canv $f $objid $halfkerf objnum "    "
            progwin_callback .svg-progwin $objcount $objnum
        }
        puts -nonewline $f "  "
        xmlutil_write_block_close $f "g"
    }
    xmlutil_write_block_close $f "svg"
    close $f
    progwin_destroy .svg-progwin
}


proc ffmt_plugin_readfile_svg {win canv filename {svgmat {}}} {
    constants pi radtodeg
    set currgroups {}
    set ipd [expr {1.0/90.0}]
    set transmat [matrix_scale $ipd -$ipd]
    set transforms_stack {}
    lappend transforms_stack $transmat
    set textx 0.0
    set texty 0.0
    set textdx 0.0
    set textdy "1.25em"
    set textffam "Times"
    set textfsiz 12
    set textanchor "start"
    set intext 0
    set allnewobjs {}
    set bbox ""

    set totalbytes [file size $filename]
    set f [open $filename "r"]

    progwin_create .svg-progwin "tkCAD Import" "Importing vectors..."
    set progcmd "progwin_callback .svg-progwin $totalbytes"

    while {1} {
        foreach {elem attributes} [xmlutil_read_element $f $progcmd] break
        set currbyte [tell $f]
        if {$elem == "EOF"} {
            # We're done here.
            break
        } elseif {$elem == "ERROR"} {
            # Ignore element.  Try next.
            continue
        } elseif {$elem == "TEXT"} {
            # All text between elems is whitespace to us, except for <text> values.
            if {$intext > 0} {
                set fsize [expr {int($textfsiz*72.0/90.0+0.5)}]
                set font [list $textffam $fsize]
                switch -exact -- $anch {
                    middle  {set just center}
                    end     {set just right}
                    default {set just left}
                }

                set nextx $textx
                set nexty $texty
                set tdx $textdx
                set tdy $textdy

                set mult 1.0
                if {[string range $tdx end-1 end] == "em"} {
                    set mult [font measure $font "0"]
                    set tdx [string range $tdx 0 end-2]
                    if {[string is double -strict $tdx]} {
                        set tdx [expr {$tdx*$mult}]
                    } else {
                        set tdx 0.0
                    }
                } elseif {[string range $tdx end-1 end] == "ex"} {
                    set mult [font measure $font "x"]
                    set tdx [string range $tdx 0 end-2]
                    if {[string is double -strict $tdx]} {
                        set tdx [expr {$tdx*$mult}]
                    } else {
                        set tdx 0.0
                    }
                } else {
                    set tdx [expr {90.0*[svg_decode_length $tdx]}]
                }
                set nextx [expr {$nextx+$tdx}]

                set mult 1.0
                if {[string range $tdy end-1 end] == "em"} {
                    set mult [font metrics $font -linespace]
                    set tdy [string range $tdy 0 end-2]
                    if {[string is double -strict $tdy]} {
                        set tdy [expr {$tdy*$mult}]
                    } else {
                        set tdy [font metrics $font -linespace]
                    }
                } elseif {[string range $tdy end-1 end] == "ex"} {
                    set mult [expr {[font metrics $font -linespace]/2.0}]
                    set tdy [string range $tdy 0 end-2]
                    if {[string is double -strict $tdy]} {
                        set tdy [expr {$tdy*$mult}]
                    } else {
                        set tdy [font metrics $font -linespace]
                    }
                } else {
                    set tdy [expr {90.0*[svg_decode_length $tdy]}]
                }
                set nexty [expr {$nexty+$tdy}]

                set path [list $textx $texty [expr {$textx+1.0}] $texty]

                set mat1 [lindex $transforms_stack end]
                set coords [matrix_transform_coords $mat1 $path]
                foreach {x y x1 y1} $coords break

                set rot [expr {atan2($y1-$y,$x1-$x)*$radtodeg}]
                set coords [lrange $coords 0 1]
                set txt [string trim $attributes]

                set bbox [svg_bbox_expand $bbox $coords]
                set newobj [cadobjects_object_create $canv TEXT $coords [list TEXT $txt ROT $rot FONT $font JUSTIFY $just]]
                lappend allnewobjs $newobj
                svg_decode_stroke $canv $newobj attr
                if {$currgroups != {}} {
                    set group [lindex $currgroups end]
                    cadobjects_object_group_addobj $canv $group $newobj
                }
                cadobjects_object_recalculate $canv $newobj
                set textx $nextx
                set texty $nexty
            }
            continue
        }
        
        catch {unset attr}
        array set attr $attributes
        switch -exact -- $elem {
            "<svg>" {
                foreach {var defval} {
                    formatversion      0.0
                    width              ""
                    height             ""
                    viewBox            ""
                } {
                    set $var $defval
                    catch {
                        set $var $attr($var)
                    }
                }
                set mat1 [lindex $transforms_stack end]
                if {$width != "" && $height != "" && $viewBox != ""} {
                    set width [svg_decode_length $width]
                    set height [svg_decode_length $height]
                    foreach {minx miny wid hgt} $viewBox break
                    set maxx [expr {$wid+$minx}]
                    set maxy [expr {$hgt+$miny}]
                    set scx [expr {$width /($wid/90.0)}]
                    set scy [expr {$height/($hgt/90.0)}]
                    set mat1 [svg_decode_transform $mat1 [format "translate(%.1f %.1f) scale(%.4f %.4f)" [expr {-$minx}] [expr {-$miny}] $scx $scy]]
                }
                if {[info exists attr(transform)]} {
                    set mat1 [svg_decode_transform $mat1 $attr(transform)]
                }
                lappend transforms_stack $mat1
            }
            "<g>" {
                set mat1 [lindex $transforms_stack end]
                if {[info exists attr(transform)]} {
                    set mat1 [svg_decode_transform $mat1 $attr(transform)]
                }
                lappend transforms_stack $mat1
                lappend currgroups [cadobjects_object_create $canv GROUP {} {}]
            }
            "</g>" {
                set group [lindex $currgroups end]
                set currgroups [lrange $currgroups 0 end-1]
                if {[llength $currgroups] > 0} {
                    set parent [lindex $currgroups end]
                    cadobjects_object_group_addobj $canv $parent $group
                }
                set transforms_stack [lrange $transforms_stack 0 end-1]
            }
            "<line/>" {
                set mat1 [lindex $transforms_stack end]
                if {[info exists attr(transform)]} {
                    set mat1 [svg_decode_transform $mat1 $attr(transform)]
                }
                foreach {var defval} {
                    x1      0.0
                    y1      0.0
                    x2      0.0
                    y2      0.0
                } {
                    set $var $defval
                    catch {
                        set $var $attr($var)
                    }
                }
                set path [list $x1 $y1 $x2 $y2]
                set coords [matrix_transform_coords $mat1 $path]
                set bbox [svg_bbox_expand $bbox $coords]
                set newobj [cadobjects_object_create $canv LINE $coords]
                lappend allnewobjs $newobj
                svg_decode_stroke $canv $newobj attr
                if {$currgroups != {}} {
                    set group [lindex $currgroups end]
                    cadobjects_object_group_addobj $canv $group $newobj
                }
                cadobjects_object_recalculate $canv $newobj
            }
            "<polyline/>" {
                set mat1 [lindex $transforms_stack end]
                if {[info exists attr(transform)]} {
                    set mat1 [svg_decode_transform $mat1 $attr(transform)]
                }
                foreach {var defval} {
                    points  {}
                } {
                    set $var $defval
                    catch {
                        set $var $attr($var)
                    }
                }
                set coords [matrix_transform_coords $mat1 $points]
                set bbox [svg_bbox_expand $bbox $coords]
                set newobj [cadobjects_object_create $canv LINE $coords]
                lappend allnewobjs $newobj
                svg_decode_stroke $canv $newobj attr
                if {$currgroups != {}} {
                    set group [lindex $currgroups end]
                    cadobjects_object_group_addobj $canv $group $newobj
                }
                cadobjects_object_recalculate $canv $newobj
            }
            "<polygon/>" {
                set mat1 [lindex $transforms_stack end]
                if {[info exists attr(transform)]} {
                    set mat1 [svg_decode_transform $mat1 $attr(transform)]
                }
                foreach {var defval} {
                    points  {}
                } {
                    set $var $defval
                    catch {
                        set $var $attr($var)
                    }
                }
                set coords [matrix_transform_coords $mat1 $points]
                set bbox [svg_bbox_expand $bbox $coords]
                set newobj [cadobjects_object_create $canv LINE $coords]
                lappend allnewobjs $newobj
                svg_decode_stroke $canv $newobj attr
                if {$currgroups != {}} {
                    set group [lindex $currgroups end]
                    cadobjects_object_group_addobj $canv $group $newobj
                }
                cadobjects_object_recalculate $canv $newobj
            }
            "<rect/>" {
                set mat1 [lindex $transforms_stack end]
                if {[info exists attr(transform)]} {
                    set mat1 [svg_decode_transform $mat1 $attr(transform)]
                }
                foreach {var defval} {
                    x      0.0
                    y      0.0
                    width  0.0
                    height 0.0
                    rx     0.0
                    ry     0.0
                } {
                    set $var $defval
                    catch {
                        set $var $attr($var)
                    }
                }
                if {$rx == 0.0 && $ry == 0.0} {
                    if {[lindex $mat1 0 1] == 0.0 && [lindex $mat1 1 0] == 0.0} {
                        # object is NOT rotated or skewed
                        set path [list \
                            $x $y \
                            [expr {$x+$width}] [expr {$y+$height}] \
                            ]
                        set coords [matrix_transform_coords $mat1 $path]
                        set bbox [svg_bbox_expand $bbox $coords]
                        set newobj [cadobjects_object_create $canv RECTANGLE $coords]
                        lappend allnewobjs $newobj
                        svg_decode_stroke $canv $newobj attr
                        cadobjects_object_recalculate $canv $newobj
                    } else {
                        # object is rotated or skewed
                        set path [list \
                            $x $y \
                            $x [expr {$y+$height}] \
                            [expr {$x+$width}] [expr {$y+$height}] \
                            [expr {$x+$width}] $y \
                            ]
                        set coords [matrix_transform_coords $mat1 $path]
                        set bbox [svg_bbox_expand $bbox $coords]
                        set newobj [cadobjects_object_create $canv LINE $coords]
                        lappend allnewobjs $newobj
                        svg_decode_stroke $canv $newobj attr
                        cadobjects_object_recalculate $canv $newobj
                    }
                } else {
                    # TODO: Construct a rounded rect from lines and arcs or bezier.
                }
                if {$currgroups != {}} {
                    set group [lindex $currgroups end]
                    cadobjects_object_group_addobj $canv $group $newobj
                }
            }
            "<circle/>" {
                set mat1 [lindex $transforms_stack end]
                if {[info exists attr(transform)]} {
                    set mat1 [svg_decode_transform $mat1 $attr(transform)]
                }
                foreach {var defval} {
                    cx    0.0
                    cy    0.0
                    r     0.0
                } {
                    set $var $defval
                    catch {
                        set $var $attr($var)
                    }
                }
                if {abs([lindex $mat1 0 1]) < 1e-6 && abs([lindex $mat1 1 0]) < 1e-6} {
                    # object is NOT rotated or skewed
                    if {abs([lindex $mat1 0 0]-[lindex $mat1 1 1]) < 1e-6} {
                        # object is also evenly scaled.
                        set path [list $cx $cy  [expr {$cx+$r}] $cy ]
                        set coords [matrix_transform_coords $mat1 $path]
                        set corners [list [expr {$cx-$r}] [expr {$cy-$r}] [expr {$cx+$r}] [expr {$cy+$r}]]
                        set corners [matrix_transform_coords $mat1 $corners]
                        set bbox [svg_bbox_expand $bbox $corners]
                        set newobj [cadobjects_object_create $canv CIRCLECTR $coords]
                    } else {
                        # object is not evenly scaled.
                        set path [list $cx $cy  [expr {$cx+$r}] [expr {$cy+$r}] ]
                        set coords [matrix_transform_coords $mat1 $path]
                        set corners [list [expr {$cx-$r}] [expr {$cy-$r}] [expr {$cx+$r}] [expr {$cy+$r}]]
                        set corners [matrix_transform_coords $mat1 $corners]
                        set bbox [svg_bbox_expand $bbox $corners]
                        set newobj [cadobjects_object_create $canv ELLIPSECTR $coords]
                    }
                    lappend allnewobjs $newobj
                    cadobjects_object_recalculate $canv $newobj
                } elseif {abs(hypot([lindex $mat1 0 0],[lindex $mat1 0 1])-hypot([lindex $mat1 1 0],[lindex $mat1 1 1])) < 1e-6} {
                    # object is rotated but not unevenly scaled or skewed
                    set path [list $cx $cy  [expr {$cx+$r}] $cy ]
                    set coords [matrix_transform_coords $mat1 $path]
                    set corners [list [expr {$cx-$r}] [expr {$cy-$r}] [expr {$cx+$r}] [expr {$cy+$r}]]
                    set corners [matrix_transform_coords $mat1 $corners]
                    set bbox [svg_bbox_expand $bbox $corners]
                    set newobj [cadobjects_object_create $canv CIRCLECTR $coords]
                    lappend allnewobjs $newobj
                } else {
                    # Okay, we have a more complex transformation matrix.
                    # Fall back to a more flexible ellipse.
                    set tmpcx2 [expr {$cx+$r}]
                    set tmpcy2 [expr {$cy+$r}]
                    set path [list $cx $cy  $tmpcx2 $cy  $tmpcx2 $tmpcy2]
                    set coords [matrix_transform_coords $mat1 $path]
                    set corners [list [expr {$cx-$r}] [expr {$cy-$r}] [expr {$cx+$r}] [expr {$cy+$r}]]
                    set corners [matrix_transform_coords $mat1 $corners]
                    set bbox [svg_bbox_expand $bbox $corners]
                    set newobj [cadobjects_object_create $canv ELLIPSECTRTAN $coords]
                    lappend allnewobjs $newobj
                }
                svg_decode_stroke $canv $newobj attr
                if {$currgroups != {}} {
                    set group [lindex $currgroups end]
                    cadobjects_object_group_addobj $canv $group $newobj
                }
                cadobjects_object_recalculate $canv $newobj
            }
            "<ellipse/>" {
                set mat1 [lindex $transforms_stack end]
                if {[info exists attr(transform)]} {
                    set mat1 [svg_decode_transform $mat1 $attr(transform)]
                }
                foreach {var defval} {
                    cx    0.0
                    cy    0.0
                    rx    0.0
                    ry    0.0
                } {
                    set $var $defval
                    catch {
                        set $var $attr($var)
                    }
                }
                if {abs([lindex $mat1 0 1]) < 1e-6 && abs([lindex $mat1 1 0]) < 1e-6} {
                    # object is NOT rotated or skewed
                    set path [list $cx $cy  [expr {$cx+$rx}] [expr {$cy+$ry}]]
                    set coords [matrix_transform_coords $mat1 $path]
                    set corners [list [expr {$cx-$rx}] [expr {$cy-$ry}] [expr {$cx+$rx}] [expr {$cy+$ry}] [expr {$cx-$rx}] [expr {$cy+$ry}] [expr {$cx+$rx}] [expr {$cy-$ry}]]
                    set corners [matrix_transform_coords $mat1 $corners]
                    set bbox [svg_bbox_expand $bbox $corners]
                    set newobj [cadobjects_object_create $canv ELLIPSECTR $coords]
                } else {
                    # Okay, we have a more complex transformation matrix.
                    # Fall back to a more flexible ellipse.
                    set tmpcx2 [expr {$cx+$rx}]
                    set tmpcy2 [expr {$cy+$ry}]
                    set path [list $cx $cy  $tmpcx2 $cy  $tmpcx2 $tmpcy2]
                    set coords [matrix_transform_coords $mat1 $path]
                    set corners [list [expr {$cx-$rx}] [expr {$cy-$ry}] [expr {$cx+$rx}] [expr {$cy+$ry}] [expr {$cx-$rx}] [expr {$cy+$ry}] [expr {$cx+$rx}] [expr {$cy-$ry}]]
                    set corners [matrix_transform_coords $mat1 $corners]
                    set bbox [svg_bbox_expand $bbox $corners]
                    set newobj [cadobjects_object_create $canv ELLIPSECTRTAN $coords]
                }
                lappend allnewobjs $newobj
                svg_decode_stroke $canv $newobj attr
                if {$currgroups != {}} {
                    set group [lindex $currgroups end]
                    cadobjects_object_group_addobj $canv $group $newobj
                }
                cadobjects_object_recalculate $canv $newobj
            }
            "<tspan>" -
            "<text>" {
                if {$elem == "<text>"} {
                    incr intext
                }
                set mat1 [lindex $transforms_stack end]
                if {[info exists attr(transform)]} {
                    set mat1 [svg_decode_transform $mat1 $attr(transform)]
                }
                lappend transforms_stack $mat1

                foreach {attname var defval} {
                    x            x     ""
                    y            y     ""
                    dx           dx    ""
                    dy           dy    ""
                    text-anchor  anch  ""
                    font-family  ffam  ""
                    font-size    fsiz  ""
                } {
                    set $var $defval
                    catch {
                        set $var $attr($attname)
                    }
                }
                if {$anch != ""} {
                    set textanchor $anch
                }
                if {$ffam != ""} {
                    set textffam $ffam
                }
                if {$fsiz != ""} {
                    set textfsiz $fsiz
                }
                if {$x != ""} {
                    set textx $x
                }
                if {$y != ""} {
                    set texty $y
                }
                if {$dx != ""} {
                    set textdx $dx
                }
                if {$dy != ""} {
                    set textdy $dy
                }
            }
            "</text>" {
                set transforms_stack [lrange $transforms_stack 0 end-1]
                incr intext -1
            }
            "</tspan>" {
                set transforms_stack [lrange $transforms_stack 0 end-1]
            }
            "<path/>" {
                set mat1 [lindex $transforms_stack end]
                if {[info exists attr(transform)]} {
                    set mat1 [svg_decode_transform $mat1 $attr(transform)]
                }
                foreach {var defval} {
                    d    ""
                } {
                    set $var $defval
                    catch {
                        set $var $attr($var)
                    }
                }
                set x0 0.0
                set y0 0.0
                set ox 0.0
                set oy 0.0
                set mode ""
                set coords {}
                set buildmode {}
                set buildcoords {}
                set d [regsub -all -- {([A-Za-z])} $d { \1 }]
                set d [regsub -all -- {[, \t\r\n][, \t\r\n]*} $d { }]
                set d [string trimleft $d]
                while {$d != ""} {
                    set ch [string index $d 0]
                    set isrel [string is lower $ch]
                    set d [string range $d 1 end]
                    progwin_callback .svg-progwin $totalbytes [expr {$currbyte-[string length $d]}]
                    switch -exact -- [string toupper $ch] {
                        "M" {
                            # Moveto
                            set buildcoords $coords
                            set buildmode $mode
                            set mode "BEZIER"
                            set coords {}
                            set isfirst 1
                            set px $ox
                            set py $oy
                            while {1} {
                                foreach {x d} [svg_get_float $d] break
                                foreach {y d} [svg_get_float $d] break
                                if {$x == "" || $y == ""} {
                                    break
                                }
                                if {$isrel} {
                                    set x [expr {$x+$px}]
                                    set y [expr {$y+$py}]
                                }
                                if {$isfirst} {
                                    lappend coords $x $y
                                    set isfirst 0
                                } else {
                                    lappend coords $px $py $x $y $x $y
                                }
                                set px $x
                                set py $y
                            }
                            if {[llength $coords] >= 2} {
                                foreach {x0 y0} [lrange $coords 0 1] break
                                foreach {ox oy} [lrange $coords end-1 end] break
                            }
                        }
                        "L" {
                            # Lineto
                            if {$mode != "BEZIER"} {
                                set buildcoords $coords
                                set buildmode $mode
                                set mode "BEZIER"
                                set coords [list $ox $oy $ox $oy]
                            }
                            set px $ox
                            set py $oy
                            while {1} {
                                foreach {x d} [svg_get_float $d] break
                                foreach {y d} [svg_get_float $d] break
                                if {$x == "" || $y == ""} {
                                    break
                                }
                                if {$isrel} {
                                    set x [expr {$x+$px}]
                                    set y [expr {$y+$py}]
                                }
                                lappend coords $px $py $x $y $x $y
                                set px $x
                                set py $y
                            }
                            if {[llength $coords] >= 4} {
                                foreach {ox oy} [lrange $coords end-1 end] break
                            }
                        }
                        "H" {
                            # Horizontal lineto
                            if {$mode != "BEZIER"} {
                                set buildcoords $coords
                                set buildmode $mode
                                set mode "BEZIER"
                                set coords [list $ox $oy $ox $oy]
                            }
                            set px $ox
                            set py $oy
                            while {1} {
                                foreach {x d} [svg_get_float $d] break
                                if {$x == ""} {
                                    break
                                }
                                if {$isrel} {
                                    set x [expr {$x+$px}]
                                }
                                lappend coords $px $py $x $oy $x $oy
                                set px $x
                            }
                            if {[llength $coords] >= 4} {
                                foreach {ox oy} [lrange $coords end-1 end] break
                            }
                        }
                        "V" {
                            # Verical lineto
                            if {$mode != "BEZIER"} {
                                set buildcoords $coords
                                set buildmode $mode
                                set mode "BEZIER"
                                set coords [list $ox $oy $ox $oy]
                            }
                            set px $ox
                            set py $oy
                            while {1} {
                                foreach {y d} [svg_get_float $d] break
                                if {$y == ""} {
                                    break
                                }
                                if {$isrel} {
                                    set y [expr {$y+$py}]
                                }
                                lappend coords $px $py $ox $y $ox $y
                                set py $y
                            }
                            if {[llength $coords] >= 4} {
                                foreach {ox oy} [lrange $coords end-1 end] break
                            }
                        }
                        "C" {
                            # Cubic Bezier
                            if {$mode != "BEZIER"} {
                                set buildcoords $coords
                                set buildmode $mode
                                set mode "BEZIER"
                                set coords [list $ox $oy]
                            }
                            set px $ox
                            set py $oy
                            while {1} {
                                foreach {x1 d} [svg_get_float $d] break
                                foreach {y1 d} [svg_get_float $d] break
                                foreach {x2 d} [svg_get_float $d] break
                                foreach {y2 d} [svg_get_float $d] break
                                foreach {x3 d} [svg_get_float $d] break
                                foreach {y3 d} [svg_get_float $d] break
                                if {$y3 == ""} {
                                    break
                                }
                                if {$isrel} {
                                    set x1 [expr {$x1+$px}]
                                    set y1 [expr {$y1+$py}]
                                    set x2 [expr {$x2+$px}]
                                    set y2 [expr {$y2+$py}]
                                    set x3 [expr {$x3+$px}]
                                    set y3 [expr {$y3+$py}]
                                }
                                lappend coords $x1 $y1 $x2 $y2 $x3 $y3
                                set px $x3
                                set py $y3
                            }
                            if {[llength $coords] >= 4} {
                                foreach {ox oy} [lrange $coords end-1 end] break
                            }
                        }
                        "S" {
                            # Cubic Bezier shorthand
                            if {$mode != "BEZIER"} {
                                set buildcoords $coords
                                set buildmode $mode
                                set mode "BEZIER"
                                set coords [list $ox $oy]
                            }
                            if {[llength $coords] >=4} {
                                foreach {cpx1 cpy1} [lrange $coords end-3 end-2] break
                            } else {
                                set cpx1 $ox
                                set cpy1 $oy
                            }
                            set px $ox
                            set py $oy
                            while {1} {
                                foreach {x2 d} [svg_get_float $d] break
                                foreach {y2 d} [svg_get_float $d] break
                                foreach {x3 d} [svg_get_float $d] break
                                foreach {y3 d} [svg_get_float $d] break
                                if {$y3 == ""} {
                                    break
                                }
                                if {$isrel} {
                                    set x2 [expr {$x2+$px}]
                                    set y2 [expr {$y2+$py}]
                                    set x3 [expr {$x3+$px}]
                                    set y3 [expr {$y3+$py}]
                                }
                                set x1 [expr {$px-($cpx1-$px)}]
                                set y1 [expr {$py-($cpy1-$py)}]
                                lappend coords $x1 $y1 $x2 $y2 $x3 $y3
                                set px $x3
                                set py $y3
                            }
                            if {[llength $coords] >= 4} {
                                foreach {ox oy} [lrange $coords end-1 end] break
                            }
                        }
                        "Z" {
                            # Closepath
                            if {$mode != "BEZIER"} {
                                set buildcoords $coords
                                set buildmode $mode
                                set mode "BEZIER"
                                set coords [list $ox $oy]
                            }
                            lappend coords $ox $oy $x0 $y0 $x0 $y0
                        }
                        "Q" {
                            # Quadratic Bezier
                            if {$mode != "QUADBEZ"} {
                                set buildcoords $coords
                                set buildmode $mode
                                set mode "QUADBEZ"
                                set coords [list $ox $oy]
                            }
                            set px $ox
                            set py $oy
                            while {1} {
                                foreach {x1 d} [svg_get_float $d] break
                                foreach {y1 d} [svg_get_float $d] break
                                foreach {x2 d} [svg_get_float $d] break
                                foreach {y2 d} [svg_get_float $d] break
                                if {$y2 == ""} {
                                    break
                                }
                                if {$isrel} {
                                    set x1 [expr {$x1+$px}]
                                    set y1 [expr {$y1+$py}]
                                    set x2 [expr {$x2+$px}]
                                    set y2 [expr {$y2+$py}]
                                }
                                lappend coords $x1 $y1 $x2 $y2
                                set px $x2
                                set py $y2
                            }
                            if {[llength $coords] >= 4} {
                                foreach {ox oy} [lrange $coords end-1 end] break
                            }
                        }
                        "T" {
                            # Quadratic Bezier shorthand
                            if {$mode != "QUADBEZ"} {
                                set buildcoords $coords
                                set buildmode $mode
                                set mode "QUADBEZ"
                                set coords [list $ox $oy]
                            }
                            if {[llength $coords] >=4} {
                                foreach {cpx1 cpy1} [lrange $coords end-3 end-2] break
                            } else {
                                set cpx1 $ox
                                set cpy1 $oy
                            }
                            set px $ox
                            set py $oy
                            while {1} {
                                foreach {x2 d} [svg_get_float $d] break
                                foreach {y2 d} [svg_get_float $d] break
                                if {$y2 == ""} {
                                    break
                                }
                                if {$isrel} {
                                    set x2 [expr {$x2+$px}]
                                    set y2 [expr {$y2+$py}]
                                }
                                set x1 [expr {$px-($cpx1-$px)}]
                                set y1 [expr {$py-($cpy1-$py)}]
                                lappend coords $x1 $y1 $x2 $y2
                                set px $x2
                                set py $y2
                            }
                            if {[llength $coords] >= 4} {
                                foreach {ox oy} [lrange $coords end-1 end] break
                            }
                        }
                        "A" {
                            # Elliptical arc
                            set buildcoords $coords
                            set buildmode $mode
                            set mode "ARC"
                            set coords [list $ox $oy]
                            set px $ox
                            set py $oy
                            while {1} {
                                foreach {rx    d} [svg_get_float $d] break
                                foreach {ry    d} [svg_get_float $d] break
                                foreach {rot   d} [svg_get_float $d] break
                                foreach {long  d} [svg_get_float $d] break
                                foreach {sweep d} [svg_get_float $d] break
                                foreach {x     d} [svg_get_float $d] break
                                foreach {y     d} [svg_get_float $d] break
                                if {$y == ""} {
                                    break
                                }
                                if {$isrel} {
                                    set x [expr {$x+$px}]
                                    set y [expr {$y+$py}]
                                }
                                lappend coords $rx $ry $rot $long $sweep $x $y
                                set px $x
                                set py $y
                            }
                            if {[llength $coords] >= 4} {
                                foreach {ox oy} [lrange $coords end-1 end] break
                            }
                        }
                    }
                    set d [string trimleft $d]
                    while {$buildmode != "" || ($d == "" && [llength $coords] >= 4)} {
                        if {[llength $buildcoords] >= 4} {
                            switch -exact -- $buildmode {
                                ARC {
                                    foreach {ox0 oy0 rx ry rot long sweep ox1 oy1} $buildcoords {
                                        set rotr [expr {$rot*$pi/180.0}]
                                        set mx [expr {($ox0-$ox1)/2.0}]
                                        set my [expr {($oy0-$oy1)/2.0}]
                                        set sinv [expr {sin(-$rotr)}]
                                        set cosv [expr {cos(-$rotr)}]
                                        set mrx [expr {$cosv*($mx)-$sinv*($my)}]
                                        set mry [expr {$sinv*($mx)+$cosv*($my)}]

                                        set rx2 [expr {$rx*$rx}]
                                        set ry2 [expr {$ry*$ry}]
                                        set mrx2 [expr {$mrx*$mrx}]
                                        set mry2 [expr {$mry*$mry}]
                                        set mf [expr {sqrt(abs(($rx2*$ry2-$rx2*$mry2-$ry2*$mrx2)/($rx2*$mry2+$ry2*$mrx2)))}]
                                        if {$long == $sweep} {
                                            set mf [expr {-$mf}]
                                        }
                                        set crx [expr {$mf*($rx*$mry/$ry)}]
                                        set cry [expr {$mf*(-$ry*$mrx/$rx)}]
                                        set sinv [expr {sin($rotr)}]
                                        set cosv [expr {cos($rotr)}]
                                        set cx [expr {$cosv*($crx)-$sinv*($cry)+($ox0+$ox1)/2.0}]
                                        set cy [expr {$sinv*($crx)+$cosv*($cry)+($oy0+$oy1)/2.0}]
                                        set arccoords {}
                                        lappend arccoords $cx $cy
                                        if {$sweep} {
                                            lappend arccoords $ox1 $oy1 $ox0 $oy0
                                        } else {
                                            lappend arccoords $ox0 $oy0 $ox1 $oy1
                                        }
                                        set arccoords [matrix_transform_coords $mat1 $arccoords]
                                        set corners [list [expr {$cx-$rx}] [expr {$cy-$ry}] [expr {$cx+$rx}] [expr {$cy+$ry}] [expr {$cx-$rx}] [expr {$cy+$ry}] [expr {$cx+$rx}] [expr {$cy-$ry}]]
                                        set corners [matrix_transform_coords $mat1 $corners]
                                        set bbox [svg_bbox_expand $bbox $corners]
                                        set newobj [cadobjects_object_create $canv ARCCTR $arccoords]
                                        lappend allnewobjs $newobj
                                        svg_decode_stroke $canv $newobj attr
                                        if {$currgroups != {}} {
                                            set group [lindex $currgroups end]
                                            cadobjects_object_group_addobj $canv $group $newobj
                                        }
                                        cadobjects_object_recalculate $canv $newobj
                                    }
                                }
                                QUADBEZ {
                                    set buildcoords [matrix_transform_coords $mat1 $buildcoords]
                                    set bbox [svg_bbox_expand $bbox $buildcoords]
                                    set newobj [cadobjects_object_create $canv BEZIERQUAD $buildcoords]
                                    lappend allnewobjs $newobj
                                    svg_decode_stroke $canv $newobj attr
                                    if {$currgroups != {}} {
                                        set group [lindex $currgroups end]
                                        cadobjects_object_group_addobj $canv $group $newobj
                                    }
                                    cadobjects_object_recalculate $canv $newobj
                                }
                                BEZIER {
                                    set buildcoords [matrix_transform_coords $mat1 $buildcoords]
                                    set bbox [svg_bbox_expand $bbox $buildcoords]
                                    set newobj [cadobjects_object_create $canv BEZIER $buildcoords]
                                    lappend allnewobjs $newobj
                                    svg_decode_stroke $canv $newobj attr
                                    if {$currgroups != {}} {
                                        set group [lindex $currgroups end]
                                        cadobjects_object_group_addobj $canv $group $newobj
                                    }
                                    cadobjects_object_recalculate $canv $newobj
                                }
                            }
                        }
                        if {$d == "" && [llength $coords] >= 4} {
                            set buildcoords $coords
                            set buildmode $mode
                            set coords {}
                            set mode ""
                        } else {
                            set buildcoords {}
                            set buildmode ""
                        }
                    }
                }
            }
            "</svg>" {
                set transforms_stack [lrange $transforms_stack 0 end-1]
            }
            default {
                # Ignore.
            }
        }
    }
    close $f

    #foreach {x0 y0 x1 y1} [cadobjects_descale_coords $canv $bbox] break
    foreach {x0 y0 x1 y1} $bbox break
    set dx [expr {$y1-$x0}]
    set dy [expr {$y1-$y0}]

    mainwin_redraw $win

    # Presumably, these are new objects anyways.
    cutpaste_suspend_recording $canv
    cadselect_clear $canv
    foreach objid $allnewobjs {
        if {$svgmat != {}} {
            cadobjects_object_transform $canv $objid $svgmat
        } else {
            cadobjects_object_translate $canv $objid $dx $dy
        }
        set objgroups [cadobjects_object_getdatum $canv $objid "GROUPS"]
        if {[llength $objgroups] == 0} {
            cadselect_add $canv $objid
        }
    }
    cutpaste_resume_recording $canv

    mainwin_canvas_zoom_all $win
    progwin_destroy .svg-progwin
    return $allnewobjs
}


# vim: set ts=4 sw=4 nowrap expandtab: settings

