proc geometry_path_is_closed {path} {
    foreach {x0 y0} [lrange $path 0 1] break
    foreach {xe ye} [lrange $path end-1 end] break
    return [expr {hypot($ye-$y0,$xe-$x0) <= 1e-4}]
}


proc geometry_points_are_collinear {points {tolerance 1e-6}} {
    foreach {x0 y0} [lrange $points 0 1] break
    set maxdist 0.0
    set ptx $x0
    set pty $y0
    # find most distant point from start point.
    foreach {x1 y1} [lrange $points 2 end] {
        set dist [expr {hypot($y1-$y0,$x1-$x0)}]
        if {$dist > $maxdist} {
            set ptx $x1
            set pty $y1
            set maxdist $dist
        }
    }
    set x1 $ptx
    set y1 $pty
    set dx [expr {0.0+$x1-$x0}]
    set dy [expr {0.0+$y1-$y0}]

    if {abs($dx) < 1e-6 && abs($dy) < 1e-6} {
        # All points are identical.  Technically collinear.
        return 1
    } elseif {abs($dx) > abs($dy)} {
        # Line is mostly Horizontal.  Lets try the normal line equation.
        # y = m*x + c
        set m [expr {$dy/$dx}]
        set c [expr {$y0-$m*$x0}]

        foreach {x2 y2} [lrange $points 2 end] {
            set predy [expr {$x2*$m+$c}]
            if {abs($predy-$y2) > $tolerance} {
                return 0
            }
        }
    } else {
        # Line is mostly vertical.  Lets try the flipside line equation.
        # x = m*y + c
        set m [expr {$dx/$dy}]
        set c [expr {$x0-$m*$y0}]

        foreach {x2 y2} [lrange $points 2 end] {
            set predx [expr {$y2*$m+$c}]
            if {abs($predx-$x2) > $tolerance} {
                return 0
            }
        }
    }
    return 1
}


proc geometry_points_are_in_box {x0 y0 x1 y1 points} {
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
    foreach {x2 y2} $points {
        if {$x2 < $x0 || $x2 > $x1 || $y2 < $y0 || $y2 > $y1} {
            return 0
        }
    }
    return 1
}


proc geometry_boxes_intersect {bbox1 bbox2} {
    set p1 [lrange $bbox1 0 1]
    set p2 [lrange $bbox1 2 3]
    set q1 [lrange $bbox2 0 1]
    set q2 [lrange $bbox2 2 3]
    return [::math::geometry::rectanglesOverlap $p1 $p2 $q1 $q2 0]
}


proc geometry_points_are_on_line_segment {x0 y0 x1 y1 points {tolerance 1e-6}} {
    if {![geometry_points_are_collinear [concat $x0 $y0 $x1 $y1 $points] $tolerance]} {
        return 0
    }
    if {![geometry_points_are_in_box $x0 $y0 $x1 $y1 $points]} {
        return 0
    }
    return 1
}


proc geometry_polyline_add_vertex {polyline point} {
    set pp1 [lrange $polyline 0 1]
    set out $pp1
    foreach {x y} [lrange $polyline 2 end] {
        set pp2 [list $x $y]
        if {[::math::geometry::calculateDistanceToLineSegment $point [concat $pp1 $pp2]] < 1e-6} {
            if {hypot($y-[lindex $point 1],$x-[lindex $point 0]) > 1e-6} {
                if {hypot([lindex $pp1 1]-[lindex $point 1],[lindex $pp1 0]-[lindex $point 0]) > 1e-6} {
                    lappend out {*}$point
                }
            }
        }
        lappend out $x $y
        set pp1 $pp2
    }
    return $out
}


proc geometry_find_polyline_line_segment_intersections {polyline line} {
    set lp1 [lrange $line 0 1]
    set lp2 [lrange $line 2 3]
    set out {}
    set seg 0
    set pp1 [lrange $polyline 0 1]
    foreach {x y} [lrange $polyline 2 end] {
        set pp2 [list $x $y]
        if {[::math::geometry::rectanglesOverlap $lp1 $lp2 $pp1 $pp2 0]} {
            set isect [::math::geometry::findLineSegmentIntersection $line [concat $pp1 $pp2]]
            if {$isect != "none"} {
                lappend out $seg $isect
            }
        }
        set pp1 $pp2
        incr seg
    }
    return $out
}


proc geometry_polyline_strip_duplicates {polyline} {
    set out {}
    foreach {x0 y0} [lrange $polyline1 0 1] break
    lappend out $x0 $y0
    foreach {x1 y1} [lrange $polyline1 2 end] {
        if {abs($y1-$y0) > 1e-6 || abs($x1-$x0) > 1e-6} {
            lappend out $x1 $y1
        }
        set x0 $x1
        set y0 $y1
    }
    return $out
}


proc geometry_find_polylines_intersections {polyline1 polyline2} {
    if {[catch {
        set isects [mlcnc_path_find_path_intersections $polyline1 $polyline2]
        set out {}
        foreach {s1 s2 x y} $isects {
            lappend out $x $y
        }
    } err]} {
        foreach {x0 y0} [lrange $polyline1 0 1] break
        foreach {x1 y1} [lrange $polyline1 2 end] {
            set points [geometry_find_polyline_line_segment_intersections $polyline2 [list $x0 $y0 $x1 $y1]]
            foreach {seg pt} $points {
                if {$pt != "coincident"} {
                    foreach {x y} $pt break
                    lappend out $x $y
                }
            }
            set x0 $x1
            set y0 $y1
        }
    }
    return $out
}


proc ::tcl::mathfunc::sign {val} {
    if {$val == 0} {
        return 0
    }
    expr {$val>0?1:-1}
}


proc ::tcl::mathfunc::frac {val} {
    if {$val < 0.0} {
        expr {$val-ceil($val)}
    } else {
        expr {$val-floor($val)}
    }
}


proc ::tcl::mathfunc::normang {val} {
    constants pi
    if {abs($val) > $pi} {
        set tpi [expr {$pi*2.0}]
        set val [expr {fmod($val,$tpi)}]
        if {$val > $pi} {
            set val [expr {$val-$tpi}]
        } elseif {$val < -$pi} {
            set val [expr {$val+$tpi}]
        }
    }
    return $val
}


proc geometry_closest_point_on_arc {cx cy rad start extent x y} {
    constants pi degtorad

    set start  [expr {normang($start *$degtorad)}]
    set extent [expr {$extent*$degtorad}]
    set eang   [expr {$start+$extent}]

    set ang [expr {atan2($y-$cy,$x-$cx)}]
    if {$ang < $start} {
        set ang [expr {$ang+$pi*2.0}]
    }
    if {$ang > $eang} {
        set dang1 [expr {normang($start-$ang)}]
        set dang2 [expr {normang($ang-$eang)}]
        if {abs($dang1) < abs($dang2)} {
            set ang $start
        } else {
            set ang $eang
        }
    }
    set px [expr {$cx+$rad*cos($ang)}]
    set py [expr {$cy+$rad*sin($ang)}]
    return [list $px $py]
}



proc geometry_join_polylines {polys} {
    set out {}
    set epsilon 1e-6
    while {[llength $polys] > 0} {
        set poly1 [lindex $polys 0]
        set polys [lrange $polys 1 end]
        foreach {x0 y0} [lrange $poly1 0 1] break
        foreach {xe ye} [lrange $poly1 end-1 end] break
        if {abs($xe-$x0) < $epsilon && abs($ye-$y0) < $epsilon} {
            lappend out $poly1
        } else {
            set found 0
            set j 0
            foreach poly2 $polys {
                foreach {bx0 by0} [lrange $poly2 0 1] break
                foreach {bxe bye} [lrange $poly2 end-1 end] break
                if {abs($x0-$bx0) < $epsilon && abs($y0-$by0) < $epsilon} {
                    set polys [lreplace $polys $j $j]
                    set poly2 [line_coords_reverse [lrange $poly2 2 end]]
                    lappend polys [concat $poly2 $poly1]
                    set found 1
                    break
                } elseif {abs($x0-$bxe) < $epsilon && abs($y0-$bye) < $epsilon} {
                    set polys [lreplace $polys $j $j]
                    set poly2 [lrange $poly2 0 end-2]
                    lappend polys [concat $poly2 $poly1]
                    set found 1
                    break
                } elseif {abs($xe-$bx0) < $epsilon && abs($y0-$by0) < $epsilon} {
                    set polys [lreplace $polys $j $j]
                    set poly2 [lrange $poly2 2 end]
                    lappend polys [concat $poly1 $poly2]
                    set found 1
                    break
                } elseif {abs($xe-$bxe) < $epsilon && abs($y0-$bye) < $epsilon} {
                    set polys [lreplace $polys $j $j]
                    set poly2 [line_coords_reverse [lrange $poly2 0 end-2]]
                    lappend polys [concat $poly1 $poly2]
                    set found 1
                    break
                }
                incr j
            }
            if {!$found} {
                lappend out $poly1
            }
        }
    }

    return $out
}



proc geometry_polygon_circumscribed_by_polygon {polygon1 polygon2} {
    set allinside 1
    # Technically we need the next line, but we'll assume it's already been done.
    #foreach {polygon1 polygon2} [mlcnc_path_insert_path_intersections $polygon1 $polygon2] break
    foreach {x0 y0} [lrange $polygon1 0 1] break
    foreach {x1 y1} [lrange $polygon1 2 end] {
        set mx [expr {($x0+$x1)/2.0}]
        set my [expr {($y0+$y1)/2.0}]
        if {[info commands mlcnc_path_circumscribes_point] != ""} {
            if {![mlcnc_path_circumscribes_point $polygon2 $mx $my]} {
                set allinside 0
                break
            }
        } elseif {![::math::geometry::pointInsidePolygon [list $mx $my] $polygon2]} {
            set allinside 0
            break
        }
        set polygon1 [concat [lrange $polygon1 2 end] [list $x1 $y1]]
        set x0 $x1
        set y0 $y1
    }
    return $allinside
}


proc geometry_polygons_union {polyset1 polyset2} {
    return [geometry_polygons_boolean_operation $polyset1 $polyset2 "union"]
}


proc geometry_polygons_diff {polyset1 polyset2} {
    return [geometry_polygons_boolean_operation $polyset1 $polyset2 "diff"]
}


proc geometry_polygons_intersection {polyset1 polyset2} {
    return [geometry_polygons_boolean_operation $polyset1 $polyset2 "intersect"]
}


# Strategy:
#    insert polygon crossing points.
#    For both polygon sets, find midpoints that are outside, inside, and on
#      the edge of the polygons in the other polygon set.
#    For midpoints that are on the path, offset a tiny bit to one side and
#      see if it is inside both polys or not.  These segments will be called
#      shared, as the inside is on the same side.
#    Union     = polyset1 outside segs + polyset2 outside segs + on-path shared segs
#    Diff      = polyset1 outside segs + polyset2 inside segs  + on-path unshared segs
#    Intersect = polyset1 inside segs  + polyset2 inside segs  + on-path shared segs
proc geometry_polygons_boolean_operation {polyset1 polyset2 oper} {
    set polyset(0) {}
    set polyset(1) {}
    set nupolyset1 {}
    foreach polygon1 $polyset1 {
        set nupolyset2 {}
        foreach polygon2 $polyset2 {
            foreach {polygon1 polygon2} [mlcnc_path_insert_path_intersections $polygon1 $polygon2] break
            set polygon1 [mlcnc_path_remove_repeated_points $polygon1]
            set polygon2 [mlcnc_path_remove_repeated_points $polygon2]
            lappend nupolyset2 $polygon2
        }
        set polyset2 $nupolyset2
        lappend nupolyset1 $polygon1
    }
    set polyset1 $nupolyset1

    set polyset(0) $polyset1
    set polyset(1) $polyset2

    unset nupolyset1
    unset nupolyset2
    unset polyset1
    unset polyset2

    # relations:
    #    I  INSIDE    segment is inside other polygon.
    #    O  OUTSIDE   segment is outside other polygon.
    #    S  SHARED    segment is on other polygon's edge, and the insides of the polygons are on the same side.
    #    U  UNSHARED  segment is on other polygon's edge, and the insides of the polygons are on opposite sides.
    switch -exact -- $oper {
        union {
            set pwant(0) {O S}
            set pwant(1) {O}
        }
        diff {
            set pwant(0) {O U}
            set pwant(1) {I}
        }
        intersect {
            set pwant(0) {I S}
            set pwant(1) {I}
        }
    }

    # Remember which segments of each polyset are inside, outside, or on the edge of the polygons in the other polyset.
    set pset 0
    for {set pset 0} {$pset <= 1} {incr pset} {
        set poly 0
        set otherset [expr {1-$pset}]
        foreach polygon1 $polyset($pset) {
            set seg 0
            foreach {x0 y0} [lrange $polygon1 0 1] break
            foreach {xe ye} [lrange $polygon1 end-1 end] break
            set aclosed [expr {hypot($ye-$y0,$xe-$x0) <= 1e-4}]
            set pclosed($pset-$poly) $aclosed
            foreach {x1 y1} [lrange $polygon1 2 end] {
                set mx [expr {($x0+$x1)/2.0}]
                set my [expr {($y0+$y1)/2.0}]
                set isinside 0
                set isedge 0
                set isshared 0
                set isunshared 0
                foreach polygon2 $polyset($otherset) {
                    #TODO: Implement pure-TCL algorithm.
                    foreach {bx0 by0} [lrange $polygon2 0 1] break
                    foreach {bx1 by1} [lrange $polygon2 end-1 end] break
                    if {hypot($by1-$by0,$bx1-$bx0) <= 1e-4} {
                        # Only check closed paths.  We are always Outside of open lines.
                        if {[mlcnc_path_min_dist_from_point $polygon2 $mx $my] < 1e-4} {
                            set isedge 1
                            if {$aclosed} {
                                # If other polygon is closed, check if edge is shared.  Otherwise, force unshared.
                                set mxe [expr {$mx+2e-4}]
                                set mye $my
                                if {[mlcnc_path_min_dist_from_point $polygon2 $mxe $mye] < 1e-4} {
                                    set mxe $mx
                                    set mye [expr {$my+2e-4}]
                                }
                                set circ1 [mlcnc_path_circumscribes_point $polygon1 $mxe $mye]
                                set circ2 [mlcnc_path_circumscribes_point $polygon2 $mxe $mye]
                                if {($circ1 && $circ2) || (!$circ1 && !$circ2)} {
                                    set isshared 1
                                }
                            } else {
                                set isunshared 1
                            }
                        } elseif {[mlcnc_path_circumscribes_point $polygon2 $mx $my]} {
                            set isinside [expr {!$isinside}]
                        }
                    }
                }
                if {$isedge} {
                    if {$isinside} {
                        set isshared [expr {!$isshared}]
                    }
                    if {$isshared && !$isunshared} {
                        set psegrel($pset-$poly-$seg) "S"
                    } else {
                        set psegrel($pset-$poly-$seg) "U"
                    }
                } elseif {$isinside} {
                    set psegrel($pset-$poly-$seg) "I"
                } else {
                    set psegrel($pset-$poly-$seg) "O"
                }
                set xy [format "%.6f,%.6f" $x0 $y0]
                lappend ppts($pset-$xy) $poly $seg
                set didpseg($pset-$poly-$seg) 0
                set x0 $x1
                set y0 $y1
                incr seg
            }
            incr poly
        }
    }

    set respolys {}
    set pset 0
    set poly 0
    set seg 0
    set dir 1
    while {1} {
        # Follow polygons until we hit an undesirable or used segment, then switch polys.
        set pos1 [expr {$seg*2}]
        set pos2 [expr {$pos1+1}]
        set currpoly [lrange [lindex $polyset($pset) $poly] $pos1 $pos2]
        while {1} {
            if {$didpseg($pset-$poly-$seg)} {
                break
            }
            if {$psegrel($pset-$poly-$seg) ni $pwant($pset)} {
                set didpseg($pset-$poly-$seg) 1
                break
            }
            set polygon1 [lindex $polyset($pset) $poly]

            set didpseg($pset-$poly-$seg) 1
            set pos1 [expr {$seg*2}]
            set pos2 [expr {$pos1+3}]
            if {$dir > 0} {
                foreach {x0 y0 x1 y1} [lrange $polygon1 $pos1 $pos2] break
            } else {
                foreach {x1 y1 x0 y0} [lrange $polygon1 $pos1 $pos2] break
            }
            lappend currpoly $x1 $y1

            set plen [expr {[llength $polygon1]/2-1}]
            incr seg $dir
            if {$seg < 0 || $seg >= $plen} {
                if {$pclosed($pset-$poly)} {
                    set seg [expr {($seg+$plen)%$plen}]
                } else {
                    break
                }
            }

            if {$psegrel($pset-$poly-$seg) ni $pwant($pset) || $didpseg($pset-$poly-$seg)} {
                set xy [format "%.6f,%.6f" $x1 $y1]
                set found 0
                for {set i 0} {$i < 1} {incr i} {
                    set pset [expr {1-$pset}]
                    if {[info exists ppts($pset-$xy)]} {
                        foreach {poly seg} $ppts($pset-$xy) {
                            set dir 1
                            if {!$didpseg($pset-$poly-$seg) && $psegrel($pset-$poly-$seg) in $pwant($pset)} {
                                set found 1
                            } else {
                                set dir -1
                                set plen [expr {[llength [lindex $polyset($pset) $poly]]/2-1}]
                                incr seg $dir
                                if {$seg < 0 || $seg >= $plen} {
                                    if {$pclosed($pset-$poly)} {
                                        set seg [expr {($seg+$plen)%$plen}]
                                    } else {
                                        continue
                                    }
                                }
                                if {!$didpseg($pset-$poly-$seg) && $psegrel($pset-$poly-$seg) in $pwant($pset)} {
                                    set found 1
                                }
                            }
                            if {$found} break
                        }
                    }
                    if {$found} break
                }
                if {!$found} break
            }
        }

        if {[llength $currpoly] > 4} {
            lappend respolys $currpoly
        }
        set currpoly {}

        set found 0
        set dir 1
        for {set pset 0} {$pset <= 1} {incr pset} {
            set pslen [llength $polyset($pset)]
            for {set poly 0} {$poly < $pslen} {incr poly} {
                set plen [expr {[llength [lindex $polyset($pset) $poly]]/2-1}]
                for {set seg 0} {$seg < $plen} {incr seg} {
                    if {!$didpseg($pset-$poly-$seg) && $psegrel($pset-$poly-$seg) in $pwant($pset)} {
                        set found 1
                        break
                    }
                }
                if {$found} break
            }
            if {$found} break
        }
        if {!$found} break
    }

    return [geometry_join_polylines $respolys]
}



proc geometry_find_closest_point_in_list {px py points} {
    set mindist 1e99
    set closest {}
    foreach {x y} $points {
        set d [expr {hypot($y-$py,$x-$px)}]
        if {$d < $mindist} {
            set mindist $d
            set closest [list $x $y]
        }
    }
    return $closest
}


proc geometry_find_circles_intersections {a_cx a_cy a_rad b_cx b_cy b_rad} {
    set a $a_rad
    set b [expr {hypot($b_cy-$a_cy,$b_cx-$a_cx)}]
    set c $b_rad
    if {$b > $a+$c || $b < 1e-6} {
        return {}
    }
    if {$a * $b < 1e-6} {
        return {}
    }
    set bang [expr {atan2($b_cy-$a_cy,$b_cx-$a_cx)}]
    set h [expr {($a*$a+$b*$b-$c*$c)/(2.0*$a*$b)}]
    if {$h < -1.0 || $h > 1.0} {
        return {}
    }
    set dang [expr {acos($h)}]
    set x0 [expr {$a_cx+cos($bang+$dang)*$a_rad}]
    set y0 [expr {$a_cy+sin($bang+$dang)*$a_rad}]
    if  {$b == $a+$c} {
        return [list $x0 $y0]
    }
    set x1 [expr {$a_cx+cos($bang-$dang)*$a_rad}]
    set y1 [expr {$a_cy+sin($bang-$dang)*$a_rad}]
    return [list $x0 $y0 $x1 $y1]
}


proc geometry_find_circle_polyline_intersections {cx cy rad polyline} {
    set out {}
    foreach {x0 y0} [lrange $polyline 0 1] break
    foreach {x1 y1} [lrange $polyline 2 end] {
        set points [geometry_find_circle_lineseg_intersections $cx $cy $rad $x0 $y0 $x1 $y1]
        foreach {x y} $points {
            lappend out $x $y
        }
        set x0 $x1
        set y0 $y1
    }
    return $out
}


proc geometry_find_circle_lineseg_intersections {cx cy rad x0 y0 x1 y1} {
    set out {}
    if {abs($x1-$x0) < 1e-6} {
        # Line is vertical.
        if {abs($cx-$x0) > $rad} {
            # No intersections
            return $out
        } elseif {abs($cx-$x0) == $rad} {
            if {[geometry_points_are_in_box $x0 $y0 $x1 $y1 [list $x0 $cy]]} {
                lappend out $x0 $cy
            }
            return $out
        }
        set c $rad
        set a [expr {$x0-$cx}]
        set b [expr {sqrt($c*$c-$a*$a)}]
        set ny0 [expr {$cy+$b}]
        set ny1 [expr {$cy-$b}]
        if {[geometry_points_are_in_box $x0 $y0 $x1 $y1 [list $x0 $ny0]]} {
            lappend out $x0 $ny0
        }
        if {[geometry_points_are_in_box $x0 $y0 $x1 $y1 [list $x0 $ny1]]} {
            lappend out $x0 $ny1
        }
        return $out
    }

    # Line is not vertical.
    set lm [expr {($y1-$y0)/($x1-$x0)}]
    set lc [expr {$y0-$lm*$x0}]

    set dx [expr {$x1-$x0}]
    set dy [expr {$y1-$y0}]
    set dr [expr {sqrt($dx*$dx+$dy*$dy)}]

    set lx0 [expr {$x0-$cx}]
    set ly0 [expr {$y0-$cy}]
    set lx1 [expr {$x1-$cx}]
    set ly1 [expr {$y1-$cy}]

    set d [expr {$lx0*$ly1-$lx1*$ly0}]
    set sgn [expr {$dy<0?-1:1}]

    set h [expr {$rad*$rad * $dr*$dr - $d*$d}]
    if {$h < 0.0} {
        # No intersections
        return {}
    }
    set nx0 [expr {$cx+($d*$dy+$sgn*$dx*sqrt($h))/($dr*$dr)}]
    set ny0 [expr {$cy+(-$d*$dx+abs($dy)*sqrt($h))/($dr*$dr)}]
    set nx1 [expr {$cx+($d*$dy-$sgn*$dx*sqrt($h))/($dr*$dr)}]
    set ny1 [expr {$cy+(-$d*$dx-abs($dy)*sqrt($h))/($dr*$dr)}]

    if {[geometry_points_are_in_box $x0 $y0 $x1 $y1 [list $nx0 $ny0]]} {
        lappend out $nx0 $ny0
    }
    if {$h > 0.0 && [geometry_points_are_in_box $x0 $y0 $x1 $y1 [list $nx1 $ny1]]} {
        lappend out $nx1 $ny1
    }
    return $out
}


proc geometry_pointlist_bbox {points} {
    set minx 1e9
    set maxx -1e9
    set miny 1e9
    set maxy -1e9

    foreach {x y} $points {
        if {$x < $minx} {set minx $x}
        if {$x > $maxx} {set maxx $x}
        if {$y < $miny} {set miny $y}
        if {$y > $maxy} {set maxy $y}
    }
    return [list $minx $miny $maxx $maxy]
}


# Offset line segment.  Left offset is positive.
proc geometry_line_offset {x0 y0 x1 y1 offset} {
    constants pi
    set ang [expr {atan2($y1-$y0,$x1-$x0)}]
    set pang [expr {$ang+$pi/2.0}]
    set nx0 [expr {$x0+$offset*cos($pang)}]
    set ny0 [expr {$y0+$offset*sin($pang)}]
    set nx1 [expr {$x1+$offset*cos($pang)}]
    set ny1 [expr {$y1+$offset*sin($pang)}]
    return [list $nx0 $ny0 $nx1 $ny1]
}


proc geometry_line_rot_point {x0 y0 x1 y1 radius offang} {
    constants degtorad
    set ang [expr {atan2($y1-$y0,$x1-$x0)}]
    set x2 [expr {$radius*cos($ang+$offang*$degtorad)+$x0}]
    set y2 [expr {$radius*sin($ang+$offang*$degtorad)+$y0}]
    return [list $x2 $y2]
}


# vim: set ts=4 sw=4 nowrap expandtab: settings

