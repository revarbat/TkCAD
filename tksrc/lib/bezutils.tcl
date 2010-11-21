proc bezutil_append_bezier_arc {var cx cy radiusx radiusy start extent} {
    upvar $var coords
    constants pi
    set arcsliceangle 15.0

    set cx [expr {$cx+0.0}]
    set cy [expr {$cy+0.0}]
    set start [expr {$start+0.0}]
    set extent [expr {$extent+0.0}]

    set extsign [expr {$extent/abs($extent)}]
    set arcslice [expr {$extent/ceil(abs($extent/$arcsliceangle))}]
    set arcrdn [expr {0.5*$arcslice*$pi/180.0}]

    # Formula for calculating the "magic number" bezier distance
    # for approximating an elliptical curve closely:
    #   x = (8 sin(ang)-4)/3
    #   magic = 4/3[( 1 - cosz)/sinz ]
    set bezmagic [expr {abs((4.0/3.0)*((1.0-cos($arcrdn))/sin($arcrdn)))}]

    set tmpcoords {}
    set done 0
    for {set i $start} {!$done} {set i [expr {$i+$arcslice}]} {
        set radians [expr {$i*$pi/180.0}]
        set tx [expr {cos($radians)}]
        set ty [expr {sin($radians)}]
        set tx1 [expr {cos($radians-1e-4)}]
        set ty1 [expr {sin($radians-1e-4)}]
        set tx2 [expr {cos($radians+1e-4)}]
        set ty2 [expr {sin($radians+1e-4)}]
        set curang [expr {atan2($ty2-$ty1,$tx2-$tx1)}]
        set prad $bezmagic
        if {$extent < 0.0} {
            set prad [expr {-$prad}]
        }
        if {$i == $start} {
            set coordlen [llength $coords]
            if {$coordlen > 0 && $coordlen % 6 == 2} {
                #lappend tmpcoords [lindex $coords end-1] [lindex $coords end]
                lappend tmpcoords $tx $ty
                lappend tmpcoords $tx $ty
            }
        } else {
            set cpx1 [expr {$tx-$prad*cos($curang)}]
            set cpy1 [expr {$ty-$prad*sin($curang)}]
            lappend tmpcoords $cpx1 $cpy1
        }
        lappend tmpcoords $tx $ty
        if {abs($i-($start+$extent)) < 1e-6} {
            set done 1
        } else {
            set cpx2 [expr {$tx+$prad*cos($curang)}]
            set cpy2 [expr {$ty+$prad*sin($curang)}]
            lappend tmpcoords $cpx2 $cpy2
        }
    }
    set mat [matrix_translate $cx $cy]
    set mat [matrix_mult $mat [matrix_scale $radiusx $radiusy]]
    foreach {x y} [matrix_transform_coords $mat $tmpcoords] {
        lappend coords $x $y
    }
    return
}


proc bezutil_append_line_arc {var cx cy radiusx radiusy start extent} {
    upvar $var coords
    constants pi
    set arcsliceangle 0.5

    set start [expr {$start+0.0}]
    set extent [expr {$extent+0.0}]

    set extsign [expr {sign($extent)}]
    if {$extent == 0.0} {
        set arcslice 0.0
    } else {
        set arcslice [expr {$extent/ceil(abs($extent/$arcsliceangle))}]
    }
    set done 0
    for {set i $start} {!$done} {set i [expr {$i+$arcslice}]} {
        set radians [expr {$i*$pi/180.0}]
        set tx [expr {$cx+$radiusx*cos($radians)}]
        set ty [expr {$cy+$radiusy*sin($radians)}]
        lappend coords $tx $ty
        if {abs($i-($start+$extent)) < 1e-6} {
            set done 1
        }
    }
    return
}


proc bezutil_segment_is_collinear {x0 y0 x1 y1 x2 y2 {tolerance 1e-4}} {
    set points [list $x0 $y0 $x1 $y1 $x2 $y2]
    return [geometry_points_are_collinear $points $tolerance]
}


proc bezutil_bezier_split_long_segments {path maxlen} {
    set nupath {}
    foreach {x0 y0} [lrange $path 0 1] break
    lappend nupath $x0 $y0
    foreach {x1 y1 x2 y2 x3 y3} [lrange $path 2 end] {
        if {hypot($y3-$y0,$x3-$x0) <= $maxlen} {
            lappend nupath $x1 $y1 $x2 $y2 $x3 $y3
        } else {
            set nusegs [bezutil_bezier_segment_split 0.5 $x0 $y0 $x1 $y1 $x2 $y2 $x3 $y3]
            set nusegs [bezutil_bezier_split_long_segments $nusegs $maxlen]
            foreach {x3 y3} [lrange $nusegs 2 end] {
                lappend nupath $x3 $y3
            }
        }
        set x0 $x3
        set y0 $y3
    }
    return $nupath
}


proc bezutil_bezier_segment_split {t x0 y0 x1 y1 x2 y2 x3 y3} {
    set u [expr {1.0-$t}]
    set mx01   [expr {$u*$x0    + $t*$x1   }]
    set my01   [expr {$u*$y0    + $t*$y1   }]
    set mx12   [expr {$u*$x1    + $t*$x2   }]
    set my12   [expr {$u*$y1    + $t*$y2   }]
    set mx23   [expr {$u*$x2    + $t*$x3   }]
    set my23   [expr {$u*$y2    + $t*$y3   }]
    set mx012  [expr {$u*$mx01  + $t*$mx12 }]
    set my012  [expr {$u*$my01  + $t*$my12 }]
    set mx123  [expr {$u*$mx12  + $t*$mx23 }]
    set my123  [expr {$u*$my12  + $t*$my23 }]
    set mx0123 [expr {$u*$mx012 + $t*$mx123}]
    set my0123 [expr {$u*$my012 + $t*$my123}]
    return [list $x0 $y0 $mx01 $my01 $mx012 $my012 $mx0123 $my0123 $mx123 $my123 $mx23 $my23 $x3 $y3]
}


# This returns a close approximation of the length of the given
# cubic bezier curve segment.
proc bezutil_bezier_segment_length {x0 y0 x1 y1 x2 y2 x3 y3} {
    set inc [expr {1.0/20.0}]

    set xc [expr {3.0*($x1-$x0)}]
    set xb [expr {3.0*($x2-$x1)-$xc}]
    set xa [expr {$x3-$x0-$xc-$xb}]

    set yc [expr {3.0*($y1-$y0)}]
    set yb [expr {3.0*($y2-$y1)-$yc}]
    set ya [expr {$y3-$y0-$yc-$yb}]

    set len 0.0

    set t 0.0
    set ox [expr {(($xa*$t + $xb)*$t + $xc)*$t + $x0}]
    set oy [expr {(($ya*$t + $yb)*$t + $yc)*$t + $y0}]

    for {set t $inc} {$t <= 1.0} {set t [expr {$t+$inc}]} {
        set mx [expr {(($xa*$t + $xb)*$t + $xc)*$t + $x0}]
        set my [expr {(($ya*$t + $yb)*$t + $yc)*$t + $y0}]
        set len [expr {$len+hypot($my-$oy,$mx-$ox)}]
        set ox $mx
        set oy $my
    }

    return $len
}


# This returns a close approximation of the length of the given
# cubic bezier curve.
proc bezutil_bezier_length {coords} {
    set len 0.0
    foreach {x0 y0} [lrange $coords 0 1] break
    foreach {x1 y1 x2 y2 x3 y3} [lrange $coords 2 end] {
        set seglen [bezutil_bezier_segment_length $x0 $y0 $x1 $y1 $x2 $y2 $x3 $y3]
        set len [expr {$len+$seglen}]
        set x0 $x3
        set y0 $y3
    }
    return $len
}


proc bezutil_bezier_segment_point {t x0 y0 x1 y1 x2 y2 x3 y3} {
    set xc [expr {3.0*($x1-$x0)}]
    set xb [expr {3.0*($x2-$x1)-$xc}]
    set xa [expr {$x3-$x0-$xc-$xb}]

    set yc [expr {3.0*($y1-$y0)}]
    set yb [expr {3.0*($y2-$y1)-$yc}]
    set ya [expr {$y3-$y0-$yc-$yb}]

    set x [expr {(($xa*$t + $xb)*$t + $xc)*$t + $x0}]
    set y [expr {(($ya*$t + $yb)*$t + $yc)*$t + $y0}]

    return [list $x $y]
}


proc bezutil_bezier_segment_partial_pos {x0 y0 x1 y1 x2 y2 x3 y3 part {tolerance 1e-3}} {
    set inc [expr {1.0/20.0}]

    set xc [expr {3.0*($x1-$x0)}]
    set xb [expr {3.0*($x2-$x1)-$xc}]
    set xa [expr {$x3-$x0-$xc-$xb}]

    set yc [expr {3.0*($y1-$y0)}]
    set yb [expr {3.0*($y2-$y1)-$yc}]
    set ya [expr {$y3-$y0-$yc-$yb}]

    set len 0.0

    set t 0.0
    set ox [expr {(($xa*$t + $xb)*$t + $xc)*$t + $x0}]
    set oy [expr {(($ya*$t + $yb)*$t + $yc)*$t + $y0}]

    for {set t $inc} {$t <= 1.0} {set t [expr {$t+$inc}]} {
        set mx [expr {(($xa*$t + $xb)*$t + $xc)*$t + $x0}]
        set my [expr {(($ya*$t + $yb)*$t + $yc)*$t + $y0}]
        set seglen [expr {hypot($my-$oy,$mx-$ox)}]
        if {$len+$seglen >= $part} {
            if {$inc < $tolerance} {
                break
            }
            set t [expr {$t-$inc}]
            set inc [expr {$inc/2.0}]
            continue
        }
        set len [expr {$len+$seglen}]
        set ox $mx
        set oy $my
    }
    set ang [expr {atan2($my-$oy,$mx-$ox)}]

    return [list $ox $oy $ang]
}


# Finds the t value of the closest approach of the given cubic bezier segment
# to the given point (px, py).  Only points closer to (px, py) than the
# closeenough value will be considered.  This routine will iteratively try
# to close in on the exact t value of the closest point, until it is within
# the tolerance distance from exact.
proc bezutil_bezier_segment_mindist_pos {px py x0 y0 x1 y1 x2 y2 x3 y3 {closeenough 1e-2} {tolerance 1e-3} {func ""}} {
    if {[llength [info commands mlcnc_bezier_nearest_point_to_point]] > 0} {
        set dat [mlcnc_bezier_nearest_point_to_point [list $x0 $y0 $x1 $y1 $x2 $y2 $x3 $y3] $px $py]
        lassign $dat dist x y seg t
        if {$dist <= $closeenough} {
            return $t
        }
        return ""
    }

    set xc [expr {3.0*($x1-$x0)}]
    set xb [expr {3.0*($x2-$x1)-$xc}]
    set xa [expr {$x3-$x0-$xc-$xb}]

    set yc [expr {3.0*($y1-$y0)}]
    set yb [expr {3.0*($y2-$y1)-$yc}]
    set ya [expr {$y3-$y0-$yc-$yb}]

    set inc 0.05
    set stepmult 10.0
    set allminima 0.5
    while {1} {
        set minima {}
        set minimadists {}
        foreach min $allminima {
            set start [expr {$min-$inc*$stepmult}]
            if {$start < 0.0} {
                set start 0.0
            }
            set end [expr {$min+$inc*$stepmult}]
            if {$end > 1.0} {
                set end 1.0
            }
            set trend -1
            set prevdist 1e17
            set t $start
            while {1} {
                set mx [expr {(($xa*$t + $xb)*$t + $xc)*$t + $x0}]
                set my [expr {(($ya*$t + $yb)*$t + $yc)*$t + $y0}]
                if {$func == ""} {
                    set dist [expr {hypot($my-$py,$mx-$px)}]
                } else {
                    set dist [expr $func]
                }
                if {$dist > $prevdist} {
                    if {$trend == -1} {
                        lappend minima [expr {$t-$inc}]
                        lappend minimadists $dist
                    }
                    set trend 1
                } else {
                    set trend -1
                }
                if {abs($t-$end) < 1e-10} {
                    if {$dist < $prevdist} {
                        lappend minima $t
                        lappend minimadists $dist
                    }
                    break
                }
                set prevdist $dist
                set prevmx $mx
                set prevmy $my
                set t [expr {$t+$inc}]
            }
        }
        set allminima $minima
        set stepmult 2.0
        set inc   [expr {$inc/2.0}]
        if {hypot($my-$prevmy,$mx-$prevmx) < $tolerance} {
            break
        }
    }
    set closest {}
    set mindist $closeenough
    foreach min $minima dist $minimadists {
        if {$dist < $mindist} {
            set closest $min
            set mindist $dist
        }
    }
    return $closest
}


# Finds the t value and segment number of the closest approach of the given
# cubic bezier to the given point (px, py).  Only points closer to (px, py)
# than the closeenough value will be considered.  This routine will
# iteratively try to close in on the exact t value of the closest point,
# until it is within the tolerance distance from exact.
proc bezutil_bezier_mindist_segpos {px py bezpath {closeenough 1e-2} {tolerance 1e-4} {func ""}} {
    if {[llength [info commands mlcnc_bezier_nearest_point_to_point]] > 0} {
        set dat [mlcnc_bezier_nearest_point_to_point $bezpath $px $py]
        lassign $dat dist x y seg t
        if {$dist <= $closeenough} {
            return [list $seg $t]
        }
        return ""
    }

    set seg 0
    foreach {x0 y0} [lrange $bezpath 0 1] break
    foreach {x1 y1  x2 y2  x3 y3} [lrange $bezpath 2 end] {
        set closest [bezutil_bezier_segment_mindist_pos $px $py $x0 $y0 $x1 $y1 $x2 $y2 $x3 $y3 $closeenough $tolerance $func]
        if {$closest != ""} {
            return [list $seg $closest]
        }
        set x0 $x3
        set y0 $y3
        incr seg
    }
    return ""
}


proc bezutil_bezier_segment_nearest_point {px py x0 y0 x1 y1 x2 y2 x3 y3 {closeenough 1e-2} {tolerance 1e-4}} {
    if {[llength [info commands mlcnc_bezier_nearest_point_to_point]] > 0} {
        set dat [mlcnc_bezier_nearest_point_to_point [list $x0 $y0 $x1 $y1 $x2 $y2 $x3 $y3] $px $py]
        lassign $dat dist x y seg t
        if {$dist <= $closeenough} {
            return [list $x $y]
        }
        return ""
    }

    set t [bezutil_bezier_segment_mindist_pos $px $py $x0 $y0 $x1 $y1 $x2 $y2 $x3 $y3 $closeenough $tolerance]
    if {$t == ""} {
        return
    }
    set pt [bezutil_bezier_segment_point $t $x0 $y0 $x1 $y1 $x2 $y2 $x3 $y3]
    return $pt
}


proc bezutil_bezier_nearest_point {px py coords {closeenough 1e-2} {tolerance 1e-4}} {
    set ret [bezutil_bezier_mindist_segpos $px $py $coords $closeenough $tolerance]
    if {$ret == ""} {
        return
    }
    foreach {seg t} $ret break
    set pos1 [expr {$seg*6}]
    set pos2 [expr {$pos1+7}]
    foreach {x0 y0 x1 y1 x2 y2 x3 y3} [lrange $coords $pos1 $pos2] break
    set pt [bezutil_bezier_segment_point $t $x0 $y0 $x1 $y1 $x2 $y2 $x3 $y3]
    return $pt
}


proc bezutil_bezier_bezier_intersections {sx sy bezpath1 bezpath2 {tolerance 1e-4}} {
    # TODO: Implement this.
}


# Splits the given cubic bezier segment at the point closest to the given
# point (px, py).  Only points closer to (px, py) than the closeenough value
# will be considered.  This routine will iteratively try to close in on the
# closest point, until it is within the tolerance distance from exact.
proc bezutil_bezier_segment_split_near {px py x0 y0 x1 y1 x2 y2 x3 y3 {closeenough 1e-2} {tolerance 1e-3}} {
    set closest [bezutil_bezier_segment_mindist_pos $px $py $x0 $y0 $x1 $y1 $x2 $y2 $x3 $y3 $closeenough $tolerance]
    if {$closest != {}} {
        return [bezutil_bezier_segment_split $closest $x0 $y0 $x1 $y1 $x2 $y2 $x3 $y3]
    }
    return [list $x0 $y0 $x1 $y1 $x2 $y2 $x3 $y3]
}


# Splits the given cubic bezier at the point closest to the given point
# (px, py).  Only points closer to (px, py) than the closeenough value will
# be considered.  This routine will iteratively try to close in on the
# closest point, until it is within the tolerance distance from exact.
proc bezutil_bezier_split_near {px py coords {closeenough 1e-2} {tolerance 1e-3}} {
    set outcoords {}
    foreach {x0 y0} [lrange $coords 0 1] break
    lappend outcoords $x0 $y0
    foreach {x1 y1 x2 y2 x3 y3} [lrange $coords 2 end] {
        if {abs($x3-$px)+abs($y3-$py) <= $tolerance} {
            lappend outcoords $x1 $y1 $x2 $y2 $x3 $y3
        } else {
            foreach {x y} [lrange [bezutil_bezier_segment_split_near $px $py $x0 $y0 $x1 $y1 $x2 $y2 $x3 $y3 $closeenough $tolerance] 2 end] {
                lappend outcoords $x $y
            }
        }
        set x0 $x3
        set y0 $y3
    }
    return $outcoords
}


# Breaks the given cubic bezier segment at the point closest to the given
# point (px, py).  Only points closer to (px, py) than the closeenough value
# will be considered.  This routine will iteratively try to close in on the
# closest point, until it is within the tolerance distance from exact.
# A list is returned, containing one or two beziers points lists.
proc bezutil_bezier_segment_break_near {px py x0 y0 x1 y1 x2 y2 x3 y3 {closeenough 1e-2} {tolerance 1e-3}} {
    set closest [bezutil_bezier_segment_mindist_pos $px $py $x0 $y0 $x1 $y1 $x2 $y2 $x3 $y3 $closeenough $tolerance]
    if {$closest != {}} {
        set points [bezutil_bezier_segment_split $closest $x0 $y0 $x1 $y1 $x2 $y2 $x3 $y3]
        foreach {x0 y0 x1 y1 x2 y2 x3 y3 x4 y4 x5 y5 x6 y6} $points break
        set bez1 [list $x0 $y0  $x1 $y1  $x2 $y2  $x3 $y3]
        set bez2 [list $x3 $y3  $x4 $y4  $x5 $y5  $x6 $y6]
        return [list $bez1 $bez2]
    }
    set bez1 [list $x0 $y0  $x1 $y1  $x2 $y2  $x3 $y3]
    return [list $bez1]
}


# Breaks the given cubic bezier at the point closest to the given point
# (px, py).  Only points closer to (px, py) than the closeenough value will
# be considered.  This routine will iteratively try to close in on the
# closest point, until it is within the tolerance distance from exact.
# A list is returned, containing the one or two beziers points lists.
proc bezutil_bezier_break_near {px py coords {closeenough 1e-2} {tolerance 1e-3}} {
    set outbezs {}
    set outcoords {}
    foreach {x0 y0} [lrange $coords 0 1] break
    lappend outcoords $x0 $y0
    foreach {x1 y1 x2 y2 x3 y3} [lrange $coords 2 end] {
        if {abs($x3-$px)+abs($y3-$py) <= $tolerance} {
            lappend outcoords $x1 $y1 $x2 $y2 $x3 $y3
            lappend outbezs $outcoords
            set outcoords [list $x3 $y3]
        } else {
            set bezs [bezutil_bezier_segment_break_near $px $py $x0 $y0 $x1 $y1 $x2 $y2 $x3 $y3 $closeenough $tolerance]
            foreach {x0 y0 x1 y1 x2 y2 x3 y3} [lindex $bezs 0] break
            if {abs($x3-$x0)+abs($y3-$y0)+abs($x2-$x0)+abs($y2-$y0)+abs($x1-$x0)+abs($y1-$y0) > $tolerance} {
                lappend outcoords $x1 $y1  $x2 $y2  $x3 $y3
            }
            if {[llength $bezs] > 1} {
                set bez1 [lindex $bezs 1]
                foreach {x0 y0 x1 y1 x2 y2 x3 y3} $bez1 break
                if {abs($x3-$x0)+abs($y3-$y0)+abs($x2-$x0)+abs($y2-$y0)+abs($x1-$x0)+abs($y1-$y0) > $tolerance} {
                    if {[llength $outcoords] > 2} {
                        lappend outbezs $outcoords
                    }
                    set outcoords $bez1
                } else {
                    if {[llength $outcoords] > 2} {
                        set outcoords [lrange $outcoords 0 end-2]
                        lappend outcoords $x3 $y3
                        lappend outbezs $outcoords
                    }
                    set outcoords [list $x3 $y3]
                }
            }
        }
        set x0 $x3
        set y0 $y3
    }
    if {[llength $outcoords] > 2} {
        lappend outbezs $outcoords
    }
    return $outbezs
}


# Straightens out nearly straight control point triplets to smooth out curves.
proc bezutil_bezier_smooth {coords {tolerance 1e-2}} {
    constants pi
    set tolerance [expr {$tolerance*2.0}]
    set outcoords {}
    foreach {x0 y0 x1 y1 x2 y2 x3 y3} [lrange $coords 0 7] break
    lappend outcoords $x0 $y0
    foreach {x4 y4 x5 y5 x6 y6} [lrange $coords 8 end] {
        if {[bezutil_segment_is_collinear $x2 $y2 $x3 $y3 $x4 $y4 $tolerance]} {
            set dx1 [expr {$x3-$x2}]
            set dy1 [expr {$y3-$y2}]
            set dx2 [expr {$x4-$x3}]
            set dy2 [expr {$y4-$y3}]
            set ang1 [expr {atan2($dy1,$dx1)}]
            set ang2 [expr {atan2($dy2,$dx2)}]
            set dang [expr {$ang2-$ang1}]
            if {$dang > $pi} {
                set dang [expr {$dang-$pi*2.0}]
            } elseif {$dang < -$pi} {
                set dang [expr {$dang+$pi*2.0}]
            }
            if {abs($dang) < $pi/4} {
                # If angle was less than 45 degrees, straighten it out.
                set mx1 [expr {($x2+$x3)/2.0}]
                set my1 [expr {($y2+$y3)/2.0}]
                set mx2 [expr {($x3+$x4)/2.0}]
                set my2 [expr {($y3+$y4)/2.0}]

                set d1 [expr {hypot($dy1,$dx1)}]
                set d2 [expr {hypot($dy2,$dx2)}]
                if {$d1+$d2 > 1e-9} {
                    set dx [expr {$mx2-$mx1}]
                    set dy [expr {$my2-$my1}]

                    set x3 [expr {$mx1+$dx*($d1/($d1+$d2))}]
                    set y3 [expr {$my1+$dy*($d1/($d1+$d2))}]
                    set x2 [expr {$x3+2.0*($mx1-$x3)}]
                    set y2 [expr {$y3+2.0*($my1-$y3)}]
                    set x4 [expr {$x3+2.0*($mx2-$x3)}]
                    set y4 [expr {$y3+2.0*($my2-$y3)}]
                }
            }
        }
        lappend outcoords $x1 $y1  $x2 $y2  $x3 $y3
        foreach {x0 y0 x1 y1 x2 y2 x3 y3} [list $x3 $y3  $x4 $y4  $x5 $y5  $x6 $y6] break
    }
    lappend outcoords $x1 $y1  $x2 $y2  $x3 $y3

    return $outcoords
}



# TODO: Incomplete
proc bezutil_bezier_approximate_segments {x0 y0  x1 y1   x2 y2  x3 y3  x4 y4   x5 y5  x6 y6  {tolerance 1e-3}} {
    if {[bezutil_segment_is_collinear $x0 $y0 $x3 $y3 $x6 $y6 $tolerance]} {
        if {[bezutil_segment_is_collinear $x2 $y2 $x3 $y3 $x4 $y4 $tolerance]} {
            # Two segments form a line.
            set dx [expr {$x6-$x0}]
            set dy [expr {$y6-$y0}]
            set x1 [expr {$x0+$dx*0.333}]
            set y1 [expr {$y0+$dy*0.333}]
            set x5 [expr {$x6-$dx*0.333}]
            set y5 [expr {$y6-$dy*0.333}]
            return [list $x0 $y0 $x1 $y1 $x5 $y5 $x6 $y6]
        }
    }
    foreach {tx1 ty1} [bezutil_bezier_segment_point 0.01 $x0 $y0  $x1 $y1  $x2 $y2  $x3 $y3] break
    foreach {tx5 ty5} [bezutil_bezier_segment_point 0.99 $x3 $y3  $x4 $y4  $x5 $y5  $x6 $y6] break
    set ang1 [expr {atan2($ty1-$x0,$tx1-$x0)}]
    set ang5 [expr {atan2($ty5-$x6,$tx5-$x6)}]
    set dist1 [expr {hypot($y6-$y0,$x6-$y0}/3.0]
    set dist5 $dist1
}



# Merges ajacent bezier curves that could be represented closely by one curve
proc bezutil_bezier_simplify {coords {tolerance 1e-3}} {
    constants pi
    set outcoords {}
    foreach {x0 y0 x1 y1 x2 y2 x3 y3} [lrange $coords 0 7] break
    lappend outcoords $x0 $y0
    foreach {x4 y4 x5 y5 x6 y6} [lrange $coords 8 end] {
        if {hypot($x3-$x6,$y3-$y6) < $tolerance*2 && hypot($x4-$x3,$y4-$y3) < $tolerance && hypot($x5-$x6,$y5-$y6) < $tolerance} {
            # If second bezier is too tiny, pretend it's not there.
            set x3 $x6
            set y3 $y6
            continue
        } elseif {hypot($x3-$x6,$y3-$y6) < $tolerance*8 && hypot($x4-$x3,$y4-$y3) < $tolerance*4 && hypot($x5-$x6,$y5-$y6) < $tolerance*4} {
            # if second bezier is just really small, clean it up into a straight line.
            set dx [expr {$x6-$x3}]
            set dy [expr {$y6-$y3}]
            set x4 [expr {$x3+$dx*0.333}]
            set y4 [expr {$y3+$dy*0.333}]
            set x5 [expr {$x6-$dx*0.333}]
            set y5 [expr {$y6-$dy*0.333}]
        } elseif {hypot($x4-$x3,$y4-$y3) < $tolerance && hypot($x5-$x6,$y5-$y6) < $tolerance} {
            # if second bezier's control lines are really short, clean it up into a straight line.
            set dx [expr {$x6-$x3}]
            set dy [expr {$y6-$y3}]
            set x4 [expr {$x3+$dx*0.333}]
            set y4 [expr {$y3+$dy*0.333}]
            set x5 [expr {$x6-$dx*0.333}]
            set y5 [expr {$y6-$dy*0.333}]
        }

        if {[bezutil_segment_is_collinear $x2 $y2 $x3 $y3 $x4 $y4 $tolerance]} {
            # If the two control points on either side of the node are linear, it's a candidate.
            set dx1 [expr {$x3-$x2}]
            set dy1 [expr {$y3-$y2}]
            set dx2 [expr {$x4-$x2}]
            set dy2 [expr {$y4-$y2}]
            set dist1 [expr {hypot($dy1,$dx1)}]
            set dist2 [expr {hypot($dy2,$dx2)}]
            set ang1 [expr {atan2($dy1,$dx1)}]
            set ang2 [expr {atan2($y4-$y3,$x4-$x3)}]
            set dang [expr {$ang2-$ang1}]
            if {$dang > $pi} {
                set dang [expr {$dang-$pi*2.0}]
            } elseif {$dang < -$pi} {
                set dang [expr {$dang+$pi*2.0}]
            }
            if {$dist1 > 1e-5 && $dist2 > 1e-5 && $dist2 > $dist1} {
                if {abs($dang) < $pi/4} {
                    # The angle at this joint is small enough to be a candidate.
                    set t [expr {$dist1/$dist2}]
                    set u [expr {1.0-$t}]

                    set dx [expr {$x1-$x0}]
                    set dy [expr {$y1-$y0}]
                    set mx1 [expr {$x0+$dx/$t}]
                    set my1 [expr {$y0+$dy/$t}]

                    set dx [expr {$x2-$x1}]
                    set dy [expr {$y2-$y1}]
                    set mx2 [expr {$x1+$dx/$t}]
                    set my2 [expr {$y1+$dy/$t}]

                    set dx [expr {$x5-$x6}]
                    set dy [expr {$y5-$y6}]
                    set mx3 [expr {$x6+$dx/$u}]
                    set my3 [expr {$y6+$dy/$u}]

                    set mx2b [expr {$u*$mx1+$t*$mx3}]
                    set my2b [expr {$u*$my1+$t*$my3}]

                    # Do midpoint predictions agree close enough?
                    if {hypot($my2-$my2b,$mx2-$mx2b) <= $tolerance*2} {
                        foreach {x1 y1 x2 y2 x3 y3} [list $mx1 $my1  $mx3 $my3  $x6 $y6] break
                        continue
                    } else {
                        puts stderr "Midpoints not close enough."
                    }
                } else {
                    puts stderr "Angle too wide."
                }
            } else {
                puts stderr "Bad CP distances."
            }
        } else {
            puts stderr "CPs not co-linear."
        }
        lappend outcoords $x1 $y1  $x2 $y2  $x3 $y3
        foreach {x0 y0 x1 y1 x2 y2 x3 y3} [list $x3 $y3  $x4 $y4  $x5 $y5  $x6 $y6] break
    }
    lappend outcoords $x1 $y1  $x2 $y2  $x3 $y3

    return $outcoords
}


proc bezutil_bezier_split {coords {tolerance 1e-2}} {
    set outcoords {}
    foreach {x0 y0} [lrange $coords 0 1] break
    lappend outcoords $x0 $y0
    foreach {x1 y1 x2 y2 x3 y3} [lrange $coords 2 end] {
        if {[bezutil_segment_is_collinear $x0 $y0 $x1 $y1 $x2 $y2 $tolerance] &&
            [bezutil_segment_is_collinear $x1 $y1 $x2 $y2 $x3 $y3 $tolerance]
        } {
            # Co-linear.  Don't bother splitting this segment.
            lappend outcoords $x1 $y1 $x2 $y2 $x3 $y3
        } else {
            set mx01 [expr {($x0+$x1)/2.0}]
            set my01 [expr {($y0+$y1)/2.0}]
            set mx12 [expr {($x1+$x2)/2.0}]
            set my12 [expr {($y1+$y2)/2.0}]
            set mx23 [expr {($x2+$x3)/2.0}]
            set my23 [expr {($y2+$y3)/2.0}]
            set mx012 [expr {($mx01+$mx12)/2.0}]
            set my012 [expr {($my01+$my12)/2.0}]
            set mx123 [expr {($mx12+$mx23)/2.0}]
            set my123 [expr {($my12+$my23)/2.0}]
            set mx0123 [expr {($mx012+$mx123)/2.0}]
            set my0123 [expr {($my012+$my123)/2.0}]
            set bezsplit1 [bezutil_bezier_split [list $x0 $y0 $mx01 $my01 $mx012 $my012 $mx0123 $my0123] $tolerance]
            set bezsplit2 [bezutil_bezier_split [list $mx0123 $my0123 $mx123 $my123 $mx23 $my23 $x3 $y3] $tolerance]
            foreach {x y} [lrange $bezsplit1 2 end] {
                lappend outcoords $x $y
            }
            foreach {x y} [lrange $bezsplit2 2 end] {
                lappend outcoords $x $y
            }
        }
        set x0 $x3
        set y0 $y3
    }
    return $outcoords
}


proc bezutil_append_line_from_bezier {var bezcoords} {
    upvar $var coords
    set bezpath [bezutil_bezier_split $bezcoords 5e-4]
    foreach {x0 y0} [lrange $bezpath 0 1] break
    lappend coords $x0 $y0
    foreach {x1 y1  x2 y2  x3 y3} [lrange $bezpath 2 end] {
        lappend coords $x3 $y3
    }
    return
}


proc bezutil_append_line_from_quadbezier {var bezcoords} {
    upvar $var coords
    set qbezpath [bezutil_quadbezier_split $bezcoords 5e-4]
    foreach {x0 y0} [lrange $qbezpath 0 1] break
    lappend coords $x0 $y0
    foreach {x1 y1  x2 y2} [lrange $qbezpath 2 end] {
        lappend coords $x2 $y2
    }
    return
}


proc bezutil_bezier_from_line {linecoords} {
    set out {}
    set onethird [expr {1.0/3.0}]
    set twothirds [expr {2.0/3.0}]
    foreach {x0 y0} [lrange $linecoords 0 1] break
    lappend out $x0 $y0
    foreach {x3 y3} [lrange $linecoords 2 end] {
        set dx [expr {$x3-$x0}]
        set dy [expr {$y3-$y0}]
        set x1 [expr {$x0+$dx*$onethird}]
        set y1 [expr {$y0+$dy*$onethird}]
        set x2 [expr {$x0+$dx*$twothirds}]
        set y2 [expr {$y0+$dy*$twothirds}]
        lappend out $x1 $y1 $x2 $y2 $x3 $y3
        set x0 $x3
        set y0 $y3
    }

    return $out
}



##################################################################
# Quadratic Bezier functions
##################################################################

proc bezutil_quadbezier_split {coords {tolerance 1e-2}} {
    set outcoords {}
    foreach {x0 y0} [lrange $coords 0 1] break
    lappend outcoords $x0 $y0
    foreach {x1 y1 x2 y2} [lrange $coords 2 end] {
        if {[bezutil_segment_is_collinear $x0 $y0 $x1 $y1 $x2 $y2 $tolerance]} {
            # Co-linear.  Don't bother splitting this segment.
            lappend outcoords $x1 $y1 $x2 $y2
        } else {
            set mx01 [expr {($x0+$x1)/2.0}]
            set my01 [expr {($y0+$y1)/2.0}]
            set mx12 [expr {($x1+$x2)/2.0}]
            set my12 [expr {($y1+$y2)/2.0}]
            set mx012 [expr {($mx01+$mx12)/2.0}]
            set my012 [expr {($my01+$my12)/2.0}]
            set bezsplit1 [bezutil_bezier_split [list $x0 $y0 $mx01 $my01 $mx012 $my012] $tolerance]
            set bezsplit2 [bezutil_bezier_split [list $mx012 $my012 $mx12 $my12 $x2 $y2] $tolerance]
            foreach {x y} [lrange $bezsplit1 2 end] {
                lappend outcoords $x $y
            }
            foreach {x y} [lrange $bezsplit2 2 end] {
                lappend outcoords $x $y
            }
        }
        set x0 $x2
        set y0 $y2
    }
    return $outcoords
}


# Merges ajacent quadratic bezier curves that could be represented
# closely by one curve
proc bezutil_quadbezier_simplify {coords {tolerance 1e-2}} {
    constants pi
    set outcoords {}
    foreach {x0 y0 x1 y1 x2 y2} [lrange $coords 0 5] break
    lappend outcoords $x0 $y0
    foreach {x3 y3 x4 y4} [lrange $coords 6 end] {
        if {(abs($x3-$x2) < 1e-9 && abs($y3-$y2) < 1e-9) ||
            (abs($x4-$x3) < 1e-9 && abs($y4-$y3) < 1e-9)
        } {
            if {abs($x2-$x4) < 1e-9 && abs($y2-$y4) < 1e-9} {
                continue
            } else {
                set x3 [expr {($x4+$x2)/2.0}]
                set y3 [expr {($y4+$y2)/2.0}]
            }
        }
        if {[bezutil_segment_is_collinear $x1 $y1 $x2 $y2 $x3 $y3 $tolerance]} {
            set dx1 [expr {$x2-$x1}]
            set dy1 [expr {$y2-$y1}]
            set dx2 [expr {$x3-$x1}]
            set dy2 [expr {$y3-$y1}]
            set dist1 [expr {hypot($dy1,$dx1)}]
            set dist2 [expr {hypot($dy2,$dx2)}]
            set ang1 [expr {atan2($dy1,$dx1)}]
            set ang2 [expr {atan2($y3-$y2,$x3-$x2)}]
            set dang [expr {abs($ang2-$ang1)}]
            if {$dang > $pi} {
                set dang [expr {abs($dang-$pi*2.0)}]
            }
            if {$dist2 > 1e-6 && $dist2 > $dist1 && $dang < $pi/4} {
                set t [expr {$dist1/$dist2}]

                set dx [expr {$x1-$x0}]
                set dy [expr {$y1-$y0}]
                set mx1 [expr {$x0+$dx/$t}]
                set my1 [expr {$y0+$dy/$t}]

                set dx [expr {$x3-$x4}]
                set dy [expr {$y3-$y4}]
                set mx1b [expr {$x4+$dx/(1.0-$t)}]
                set my1b [expr {$y4+$dy/(1.0-$t)}]

                # Do midpoint predictions agree close enough?
                if {hypot($my1-$my1b,$mx1-$mx1b) <= $tolerance} {
                    foreach {x1 y1 x2 y2} [list $mx1 $my1  $x4 $y4] break
                    continue
                }
            }
        }
        lappend outcoords $x1 $y1  $x2 $y2
        foreach {x0 y0 x1 y1 x2 y2} [list $x2 $y2  $x3 $y3  $x4 $y4] break
    }
    lappend outcoords $x1 $y1  $x2 $y2

    return $outcoords
}


proc bezutil_quadbezier_segment_split {t x0 y0 x1 y1 x2 y2} {
    set u [expr {1.0-$t}]
    set mx01   [expr {$u*$x0    + $t*$x1   }]
    set my01   [expr {$u*$y0    + $t*$y1   }]
    set mx12   [expr {$u*$x1    + $t*$x2   }]
    set my12   [expr {$u*$y1    + $t*$y2   }]
    set mx012  [expr {$u*$mx01  + $t*$mx12 }]
    set my012  [expr {$u*$my01  + $t*$my12 }]
    return [list $x0 $y0 $mx01 $my01 $mx012 $my012 $mx12 $my12 $x2 $y2]
}


# This returns a close approximation of the length of the given
# quadratic bezier curve segment.
proc bezutil_quadbezier_segment_length {x0 y0 x1 y1 x2 y2} {
    set inc [expr {1.0/20.0}]
    set len 0.0

    set t 0.0
    set u [expr {1.0-$t}]
    set ox [expr {$x2*$t*$t + $x1*2.0*$t*$u + $x0*$u*$u}]
    set oy [expr {$y2*$t*$t + $y1*2.0*$t*$u + $y0*$u*$u}]

    for {set t $inc} {$t <= 1.0} {set t [expr {$t+$inc}]} {
        set u [expr {1.0-$t}]
        set mx [expr {$x2*$t*$t + $x1*2.0*$t*$u + $x0*$u*$u}]
        set my [expr {$y2*$t*$t + $y1*2.0*$t*$u + $y0*$u*$u}]
        set len [expr {$len+hypot($my-$oy,$mx-$ox)}]
        set ox $mx
        set oy $my
    }

    return $len
}


# This returns a close approximation of the length of the given
# quadratic bezier curve.
proc bezutil_quadbezier_length {coords} {
    set len 0.0
    foreach {x0 y0} [lrange $coords 0 1] break
    foreach {x1 y1 x2 y2} [lrange $coords 2 end] {
        set seglen [bezutil_quadbezier_segment_length $x0 $y0 $x1 $y1 $x2 $y2]
        set len [expr {$len+$seglen}]
        set x0 $x2
        set y0 $y2
    }
    return $len
}


proc bezutil_quadbezier_segment_point {t x0 y0 x1 y1 x2 y2} {
    set u [expr {1.0-$t}]
    set mx [expr {$x2*$t*$t + $x1*2.0*$t*$u + $x0*$u*$u}]
    set my [expr {$y2*$t*$t + $y1*2.0*$t*$u + $y0*$u*$u}]
    return [list $mx $my]
}


# Returns the t value of closest point on the given bezier segment
# to the given point (px, py).  Only points closer to (px, py) than the
# closeenough value will be considered.  This routine will iteratively
# try to close in on the exact t value of the closest point, until it is
# within the tolerance distance from exact.
proc bezutil_quadbezier_mindist_pos {px py x0 y0 x1 y1 x2 y2 {closeenough 1e-2} {tolerance 1e-3}} {
    set inc 0.05
    set stepmult 10.0
    set allminima 0.5
    while {1} {
        set minima {}
        set minimadists {}
        foreach min $allminima {
            set start [expr {$min-$inc*$stepmult}]
            if {$start < 0.0} {
                set start 0.0
            }
            set end [expr {$min+$inc*$stepmult}]
            if {$end > 1.0} {
                set end 1.0
            }
            set trend -1
            set prevdist 1e17
            set t $start
            while {1} {
                set u [expr {1.0-$t}]
                set mx [expr {$x2*$t*$t + $x1*2.0*$t*$u + $x0*$u*$u}]
                set my [expr {$y2*$t*$t + $y1*2.0*$t*$u + $y0*$u*$u}]
                set dist [expr {hypot($my-$py,$mx-$px)}]
                if {$dist > $prevdist} {
                    if {$trend == -1} {
                        lappend minima [expr {$t-$inc}]
                        lappend minimadists $dist
                    }
                    set trend 1
                } else {
                    set trend -1
                }
                if {abs($t-$end) < 1e-10} {
                    if {$dist < $prevdist} {
                        lappend minima $t
                        lappend minimadists $dist
                    }
                    break
                }
                set prevdist $dist
                set prevmx $mx
                set prevmy $my
                set t [expr {$t+$inc}]
            }
        }
        set allminima $minima
        set stepmult 2.0
        set inc   [expr {$inc/2.0}]
        if {hypot($my-$prevmy,$mx-$prevmx) < $tolerance} {
            break
        }
    }
    set closest {}
    set mindist $closeenough
    foreach min $minima dist $minimadists {
        if {$dist < $mindist} {
            set closest $min
            set mindist $dist
        }
    }
    return $closest
}


proc bezutil_quadbezier_nearest_point {px py coords {closeenough 1e-2} {tolerance 1e-3}} {
    set ret [bezutil_quadbezier_mindist_segpos $px $py $bezpath $closeenough $tolerance]
    if {$ret == ""} {
        return
    }
    foreach {seg t} $ret break
    set pos1 [expr {$seg*6}]
    set pos2 [expr {$pos1+7}]
    foreach {x0 y0 x1 y1 x2 y2} [lrange $coords $pos1 $pos2] break
    set pt [bezutil_quadbezier_segment_point $t $x0 $y0 $x1 $y1 $x2 $y2]
    return $pt
}


# Splits the given quadratic bezier segment at the point closest to the given
# point (px, py).  Only points closer to (px, py) than the closeenough value
# will be considered.  This routine will iteratively try to close in on the
# closest point, until it is within the tolerance distance from exact.
proc bezutil_quadbezier_segment_split_near {px py x0 y0 x1 y1 x2 y2 {closeenough 1e-2} {tolerance 1e-3}} {
    set closest [bezutil_quadbezier_mindist_pos $px $py $x0 $y0 $x1 $y1 $x2 $y2 $closeenough $tolerance]
    if {$closest != {}} {
        return [bezutil_quadbezier_segment_split $closest $x0 $y0 $x1 $y1 $x2 $y2]
    }
    return [list $x0 $y0 $x1 $y1 $x2 $y2]
}


# Splits the given quadratic bezier at the point closest to the given point
# (px, py).  Only points closer to (px, py) than the closeenough value will
# be considered.  This routine will iteratively try to close in on the
# closest point, until it is within the tolerance distance from exact.
proc bezutil_quadbezier_split_near {px py coords {closeenough 1e-2} {tolerance 1e-3}} {
    set outcoords {}
    foreach {x0 y0} [lrange $coords 0 1] break
    lappend outcoords $x0 $y0
    foreach {x1 y1 x2 y2} [lrange $coords 2 end] {
        foreach {x y} [lrange [bezutil_quadbezier_segment_split_near $px $py $x0 $y0 $x1 $y1 $x2 $y2 $closeenough $tolerance] 2 end] {
            lappend outcoords $x $y
        }
        set x0 $x2
        set y0 $y2
    }
    return $outcoords
}



# Breaks the given quadratic bezier segment at the point closest to the given
# point (px, py).  Only points closer to (px, py) than the closeenough value
# will be considered.  This routine will iteratively try to close in on the
# closest point, until it is within the tolerance distance from exact.
# A list is returned, containing one or two quadbeziers points lists.
proc bezutil_quadbezier_segment_break_near {px py x0 y0 x1 y1 x2 y2 {closeenough 1e-2} {tolerance 1e-3}} {
    set closest [bezutil_quadbezier_mindist_pos $px $py $x0 $y0 $x1 $y1 $x2 $y2 $closeenough $tolerance]
    if {$closest != {}} {
        set points [bezutil_quadbezier_segment_split $closest $x0 $y0 $x1 $y1 $x2 $y2]
        foreach {x0 y0 x1 y1 x2 y2 x3 y3 x4 y4} $points break
        set qbez1 [list $x0 $y0  $x1 $y1  $x2 $y2]
        set qbez2 [list $x2 $y2  $x3 $y3  $x4 $y4]
        return [list $qbez1 $qbez2]
    }
    set qbez1 [list $x0 $y0  $x1 $y1  $x2 $y2]
    return [list $qbez1]
}


# Breaks the given cubic bezier at the point closest to the given point
# (px, py).  Only points closer to (px, py) than the closeenough value will
# be considered.  This routine will iteratively try to close in on the
# closest point, until it is within the tolerance distance from exact.
# A list is returned, containing the one or two beziers points lists.
proc bezutil_quadbezier_break_near {px py coords {closeenough 1e-2} {tolerance 1e-3}} {
    set outbezs {}
    set outcoords {}
    foreach {x0 y0} [lrange $coords 0 1] break
    lappend outcoords $x0 $y0
    foreach {x1 y1 x2 y2} [lrange $coords 2 end] {
        if {abs($x2-$px)+abs($y2-$py) <= $tolerance} {
            lappend outcoords $x1 $y1 $x2 $y2
            lappend outbezs $outcoords
            set outcoords [list $x2 $y2]
        } else {
            set bezs [bezutil_quadbezier_segment_break_near $px $py $x0 $y0 $x1 $y1 $x2 $y2 $closeenough $tolerance]
            foreach {x0 y0 x1 y1 x2 y2} [lindex $bezs 0] break
            if {abs($x2-$x0)+abs($y2-$y0)+abs($x1-$x0)+abs($y1-$y0) > $tolerance} {
                lappend outcoords $x1 $y1  $x2 $y2
            }
            if {[llength $bezs] > 1} {
                set qbez1 [lindex $bezs 1]
                foreach {x0 y0 x1 y1 x2 y2} $qbez1 break
                if {abs($x2-$x0)+abs($y2-$y0)+abs($x1-$x0)+abs($y1-$y0) > $tolerance} {
                    if {[llength $outcoords] > 2} {
                        lappend outbezs $outcoords
                    }
                    set outcoords $qbez1
                } else {
                    if {[llength $outcoords] > 2} {
                        set outcoords [lrange $outcoords 0 end-2]
                        lappend outcoords $x2 $y2
                        lappend outbezs $outcoords
                    }
                    set outcoords [list $x2 $y2]
                }
            }
        }
        set x0 $x2
        set y0 $y2
    }
    if {[llength $outcoords] > 2} {
        lappend outbezs $outcoords
    }
    return $outbezs
}


# Breaks the given polyline at the point closest to the given point
# (px, py).  Only points closer to (px, py) than the closeenough value will
# be considered.  A list is returned, containing the one or two polyline
# points lists.
proc bezutil_polyline_break_near {px py coords {closeenough 1e-2}} {
    set pt [list $px $py]
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
    if {$min_d > $closeenough} {
        return [list $coords]
    }
    set nupt [::math::geometry::findClosestPointOnLineSegment $pt $min_ln]
    set coords1 [lrange $coords 0 [expr {$min_seg*2+1}]]
    set coords2 [lrange $coords [expr {$min_seg*2+2}] end]
    if {abs([lindex $coords1 end-1]-$px) + abs([lindex $coords1 end]-$py) > 1e-4} {
        lappend coords1 {*}$nupt
    }
    if {abs([lindex $coords2 0]-$px) + abs([lindex $coords2 1]-$py) > 1e-4} {
        set coords2 [concat $nupt $coords2]
    }
    if {[llength $coords1] <= 2} {
        set out [list $coords2]
    } elseif {[llength $coords2] <= 2} {
        set out [list $coords1]
    } else {
        set out [list $coords1 $coords2]
    }
    return $out
}


# vim: set ts=4 sw=4 nowrap expandtab: settings

