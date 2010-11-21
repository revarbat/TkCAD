# Notes for future inset re-implementation:
#   For each segment, compute inset quad.
#   For sharp convex joints, add extra curve segments every few degrees.
#     Note this makes some quads have 0-length outside segments.
#   Extend inside segments on ajacent non-intersecting quads.
#   Shorten inside segments on ajacent intersecting quads.
#   Recursively shorten inside segments when quads intersect.

if {[catch {package require mlcnc_critcl} err]} {
    puts stderr "Could not load mlcnc_critcl extentions.  Falling back to TCL."
}


if {[info commands mlcnc_find_line_intersection] == {}} {
    proc mlcnc_find_line_intersection {x1 y1 x2 y2  x3 y3 x4 y4} {
        if {abs($x1-$x3) < 0.00001 && abs($y1-$y3) < 0.00001} {
            return [list $x1 $y1]
        }
        if {abs($x1-$x4) < 0.00001 && abs($y1-$y4) < 0.00001} {
            return [list $x1 $y1]
        }
        if {abs($x2-$x3) < 0.00001 && abs($y2-$y3) < 0.00001} {
            return [list $x2 $y2]
        }
        if {abs($x2-$x4) < 0.00001 && abs($y2-$y4) < 0.00001} {
            return [list $x2 $y2]
        }
        if {abs($x1-$x2) < 0.00001} {
            if {abs($x3-$x4) < 0.00001} {
                if {abs($x1-$x3) < 0.00001} {
                    set min [mlcnc_min $y1 $y2 $y3 $y4]
                    set max [mlcnc_max $y1 $y2 $y3 $y4]
                    return [list $x1 [expr {($min+$max)/2.0}]]
                }
                return ""
            }
            set m2 [expr {($y4-$y3)/($x4-$x3)}]
            set c2 [expr {$y3-$m2*$x3}]
            set ix $x1
            set iy [expr {$ix*$m2+$c2}]
            return [list $ix $iy]
        } elseif {abs($x3-$x4) < 0.00001} {
            set m1 [expr {($y2-$y1)/($x2-$x1)}]
            set c1 [expr {$y1-$m1*$x1}]
            set ix $x3
            set iy [expr {$ix*$m1+$c1}]
            return [list $ix $iy]
        }

        set m1 [expr {($y2-$y1)/($x2-$x1)}]
        set m2 [expr {($y4-$y3)/($x4-$x3)}]

        set c1 [expr {$y1-$m1*$x1}]
        set c2 [expr {$y3-$m2*$x3}]

        if {abs($m1-$m2) < 0.00000001} {
            if {abs($c1-$c2) < 0.00001} {
                set minx [mlcnc_min $x1 $x2 $x3 $x4]
                set maxx [mlcnc_max $x1 $x2 $x3 $x4]
                set miny [mlcnc_min $y1 $y2 $y3 $y4]
                set maxy [mlcnc_max $y1 $y2 $y3 $y4]
                set midx [expr {($minx+$maxx)/2.0}]
                set midy [expr {($miny+$maxy)/2.0}]
                return [list $midx $midy]
            }
            return ""
        }

        set ix [expr {($c2-$c1)/($m1-$m2)}]
        set iy [expr {$m1*$ix+$c1}]

        return [list $ix $iy]
    }
    puts stderr "Defined mlcnc_find_line_intersection in TCL!"
}


if {[info commands mlcnc_lines_intersect] == {}} {
    proc mlcnc_lines_intersect {x1 y1 x2 y2  x3 y3 x4 y4} {
        if {$x1>$x2} {
            if {($x3 > $x1 && $x4 > $x1) || ($x3 < $x2 && $x4 < $x2)} {
                return 0
            }
        } else {
            if {($x3 > $x2 && $x4 > $x2) || ($x3 < $x1 && $x4 < $x1)} {
                return 0
            }
        }
        if {$y1>$y2} {
            if {($y3 > $y1 && $y4 > $y1) || ($y3 < $y2 && $y4 < $y2)} {
                return 0
            }
        } else {
            if {($y3 > $y2 && $y4 > $y2) || ($y3 < $y1 && $y4 < $y1)} {
                return 0
            }
        }
        set intersect [mlcnc_find_line_intersection $x1 $y1 $x2 $y2  $x3 $y3 $x4 $y4]
        if {$intersect == ""} {
            return 0
        }
        set x [lindex $intersect 0]
        set y [lindex $intersect 1]
        if {$x1 > $x2} {
            set tmp $x1
            set x1 $x2
            set x2 $tmp
        }
        if {$y1 > $y2} {
            set tmp $y1
            set y1 $y2
            set y2 $tmp
        }
        if {$x3 > $x4} {
            set tmp $x3
            set x3 $x4
            set x4 $tmp
        }
        if {$y3 > $y4} {
            set tmp $y3
            set y3 $y4
            set y4 $tmp
        }
        if {$x - $x1 < -0.00001 || $x - $x2 > 0.00001} {
            return 0
        }
        if {$y - $y1 < -0.00001 || $y - $y2 > 0.00001} {
            return 0
        }
        if {$x - $x3 < -0.00001 || $x - $x4 > 0.00001} {
            return 0
        }
        if {$y - $y3 < -0.00001 || $y - $y4 > 0.00001} {
            return 0
        }
        return 1
    }
    puts stderr "Defined mlcnc_lines_intersect in TCL!"
}


if {[info commands mlcnc_line_dist_from_point] == {}} {
    proc mlcnc_line_dist_from_point {x1 y1 x2 y2 px py} {
        set dx [expr {$x2-$x1}]
        set dy [expr {$y2-$y1}]
        if {abs($dx) < 1e-6} {
            set pdist [expr {abs($px-$x1)}]
            set x $x1
            set y $py
        } elseif {abs($dy) < 1e-6} {
            set pdist [expr {abs($py-$y1)}]
            set x $px
            set y $y1
        } else {
            set m1 [expr {$dy/$dx}]
            set m2 [expr {-$dx/$dy}]
            set c1 [expr {$y1-$m1*$x1}]
            set c2 [expr {$py-$m2*$px}]
            set x [expr {($c2-$c1)/($m1-$m2)}]
            set y [expr {$m1*$x+$c1}]
            set pdist [expr {hypot($y-$py,$x-$px)}]
        }
        set d1 [expr {hypot($y1-$y,$x1-$x)}]
        set d2 [expr {hypot($y2-$y,$x2-$x)}]
        set dt [expr {hypot($y2-$y1,$x2-$x1)}]
        if {abs($d1+$d2-$dt) < 1e-6} {
            return $pdist
        } elseif {$d1 < $d2} {
            return [expr {hypot($py-$y1,$px-$x1)}]
        } else {
            return [expr {hypot($py-$y2,$px-$x2)}]
        }
    }
    puts stderr "Defined mlcnc_line_dist_from_point in TCL!"
}


if {[info commands mlcnc_path_min_dist_from_point] == {}} {
    proc mlcnc_path_min_dist_from_point {path px py} {
        set mindist 1e37
        set ox [lindex $path 0]
        set oy [lindex $path 1]
        foreach {x y} [lrange $path 2 end] {
            set dist [mlcnc_line_dist_from_point $ox $oy $x $y $px $py]
            if {$dist < $mindist} {
                set mindist $dist
            }
            set ox $x
            set oy $y
        }
        return $mindist
    }
    puts stderr "Defined mlcnc_path_min_dist_from_point in TCL!"
}


if {[info commands mlcnc_closest_point_on_path] == {}} {
    proc mlcnc_closest_point_on_path {path px py} {
        set cx ""
        set cy ""
        set cdist 1e36
        foreach {x y} $path {
            set dx [expr {$px-$x}]
            set dy [expr {$py-$y}]
            set dist [expr {sqrt($dx*$dx+$dy*$dy)}]
            if {$dist < $cdist} {
                set cx $x
                set cy $y
                set cdist $dist
            }
        }
        return [list $cx $cy]
    }
    puts stderr "Defined mlcnc_closest_point_on_path in TCL!"
}


proc mlcnc_line_angle {x1 y1 x2 y2 x3 y3} {
    set ang1 [expr {atan2($y2-$y1,$x2-$x1)}]
    set ang2 [expr {atan2($y3-$y2,$x3-$x2)}]
    set dang [expr {$ang2-$ang1}]
    constants pi
    if {$dang > $pi} {
        set dang [expr {$dang-2.0*$pi}]
    } elseif {$dang < -$pi} {
        set dang [expr {$dang+2.0*$pi}]
    }
    return $dang
}


proc mlcnc_path_angle {path} {
    if {abs([lindex $path 0] - [lindex $path end-1]) < 0.00001  &&
        abs([lindex $path 1] - [lindex $path end]) < 0.00001
    } {
        # If closed, also count angle between last and first segments.
        lappend path [lindex $path 2] [lindex $path 3]
    }

    constants pi
    set revcnt 0
    set totang 0.0
    foreach {fx fy} [lrange $path 0 end-4] \
            {sx sy} [lrange $path 2 end-2] \
            {x y} [lrange $path 4 end] \
    {
        set ang [mlcnc_line_angle $fx $fy $sx $sy $x $y]
        if {abs($ang-$pi) < 1e-7} {
            incr revcnt
        } else {
            set totang [expr {$totang+$ang}]
        }
    }

    if {$totang > 0.0} {
        set revcnt [expr {-$revcnt}]
    }
    set totang [expr {$totang+$revcnt*$pi}]
    return $totang
}


proc mlcnc_path_inset_offset {path offset} {
    if {[mlcnc_path_angle $path] < 0.0} {
        return $offset
    } else {
        return [expr {-1.0*$offset}]
    }
}


if {[info commands mlcnc_path_remove_repeated_points] == {}} {
    proc mlcnc_path_remove_repeated_points {path} {
        set outpath [lrange $path 0 1]
        foreach {ox oy} [lrange $path 0 end-2] \
                {x y} [lrange $path 2 end] \
        {
            if {abs($ox-$x) >= 0.00001 || abs($oy-$y) >= 0.00001} {
                lappend outpath $x $y
            }
        }
        return $outpath
    }
    puts stderr "Defined mlcnc_path_remove_repeated_points in TCL!"
}


proc mlcnc_reorder_polygon_path_by_point {path px py} {
    set found 0
    set alist {}
    set blist {}
    if {abs([lindex $path 0]-[lindex $path end-1]) < 0.00001} {
        if {abs([lindex $path 1]-[lindex $path end]) < 0.00001} {
            set path [lrange $path 0 end-2]
        }
    }
    foreach {x y} $path {
        if {!$found} {
            if {abs($x-$px) < 0.00001 && abs($y-$py) < 0.00001} {
                set found 1
                lappend blist $x $y
            } else {
                lappend alist $x $y
            }
        } else {
            lappend blist $x $y
        }
    }
    set newpath [concat $blist $alist]
    if {abs([lindex $newpath 0]-[lindex $newpath end-1]) >= 0.00001 || abs([lindex $newpath 1]-[lindex $newpath end]) >= 0.00001} {
        lappend newpath [lindex $newpath 0] [lindex $newpath 1]
    }
    return $newpath
}


proc mlcnc_path_inset_angle_point {ax ay  bx by  cx cy offset} {
    constants pi
    set ang_ba [expr {atan2($ay-$by,$ax-$bx)}]
    set ang_bc [expr {atan2($cy-$by,$cx-$bx)}]
    if {$ang_bc < $ang_ba} {
        set ang_bc [expr {$ang_bc+2.0*$pi}]
    }
    set ang_abd [expr {($ang_bc-$ang_ba)/2.0}]
    set sin_abd [expr {sin($ang_abd)}]
    if {abs($sin_abd) < 1e-9} {
        set rad 1e20
    } elseif {$ang_abd >= $pi} {
        set rad [expr {$offset/-$sin_abd}]
    } else {
        set rad [expr {$offset/$sin_abd}]
    }
    set len_ba [expr {hypot($ay-$by,$ax-$bx)}]
    set len_bc [expr {hypot($cy-$by,$cx-$bx)}]
    set sidelen [expr {$len_ba<$len_bc?$len_ba:$len_bc}]
    if {$rad > $sidelen+abs($offset)} {
        #set rad [expr {$sidelen+abs($offset)}]
        # This point is obviously bad.
        #return ""
    }
    set nx [expr {$rad*cos($ang_abd+$ang_ba)+$bx}]
    set ny [expr {$rad*sin($ang_abd+$ang_ba)+$by}]
    #puts stderr [format "(%.5f,%.5f)(%.5f,%.5f)(%.5f,%.5f) > (%.5f,%.5f) %.5f" $ax $ay $bx $by $cx $cy $nx $ny $rad]
    return [list $nx $ny]
}



# Offsets path to the right by the given amount.  Negative offsets are left shifts.
proc mlcnc_path_offset {path offset} {
    set debug 0
    constants pi degtorad radtodeg

    if {$debug} {
        puts stderr "---------------------------------------------------------------------------"
        puts stderr "offset=$offset"
        puts -nonewline stderr "Orig  len=[llength $path]   {"
        puts -nonewline stderr [format "%.5f %.5f" [lindex $path 0] [lindex $path 1]]
        foreach {xval yval} [lrange $path 2 end] {
            puts -nonewline stderr [format "  %.5f %.5f" $xval $yval]
        }
        puts stderr "}\n"
    }

    if {[llength $path] < 4} {
        return ""
    }

    # Remove repeated points.
    set path [mlcnc_path_remove_repeated_points $path]
    if {[llength $path] < 4} {
        return ""
    }

    if {$debug} {
        puts -nonewline stderr "NoReps  len=[llength $path]  {"
        puts -nonewline stderr [format "%.5f %.5f" [lindex $path 0] [lindex $path 1]]
        foreach {xval yval} [lrange $path 2 end] {
            puts -nonewline stderr [format "  %.5f %.5f" $xval $yval]
        }
        puts stderr "}\n"
    }

    # Get original path angle for later path culling.
    set origx [lindex $path end-1]
    set origy [lindex $path end]
    set pathang [expr {[mlcnc_path_angle $path] >= 0.0}]
    if {$debug} {
        puts stderr [format "path angle = %.10f" [expr {[mlcnc_path_angle $path]*$radtodeg}]]
    }

    # Remember if path was closed.
    foreach {x0 y0} [lrange $path 0 1] break
    foreach {xe ye} [lrange $path end-1 end] break
    if {hypot($ye-$y0,$xe-$x0) < 1e-3} {
        set wasclosed 1
        # If it was really close to, but not quite closed, close it.
        if {hypot($ye-$y0,$xe-$x0) > 1e-6} {
            set mx [expr {($x0+$xe)/2.0}]
            set my [expr {($y0+$ye)/2.0}]
            set path [lreplace [lrange $path 0 end-2] 0 1 $mx $my]
            lappend path $mx $my
            set pathang [expr {[mlcnc_path_angle $path] >= 0.0}]
        }
        set was_inset [expr {$pathang?1:0 == ($offset<0.0)?1:0}]
        if {$debug} {
            puts stderr "pathang=$pathang"
            puts stderr "offset=$offset"
            puts stderr "was_inset=$was_inset"
        }
    } else {
        set wasclosed 0
    }

    # Uncross input path if it needs it.
    if {[llength $path] >= 4} {
        set paths [mlcnc_region_uncross $path]
    } else {
        set paths [list $path]
    }
    if {[llength $paths] != 1} {
        set outpaths {}
        if {$debug} {
            puts stderr "Split into [llength $paths] paths"
        }
        foreach path $paths {
            if {[llength $path] < 4} continue
            foreach subpath [mlcnc_path_offset $path $offset] {
                lappend outpaths $subpath
            }
        }
        return $outpaths
    }
    set path [lindex $paths 0]
    if {$debug} {
        puts -nonewline stderr "Uncrossed len=[llength $path] {"
        puts -nonewline stderr [format "%.5f %.5f" [lindex $path 0] [lindex $path 1]]
        foreach {xval yval} [lrange $path 2 end] {
            puts -nonewline stderr [format "  %.5f %.5f" $xval $yval]
        }
        puts stderr "}\n"
    }

    # Strip out sharply concave parts that are too small anyways. (Deburring)
    # Makes the angle insets slightly less pathological in shooting
    # inset angle points all the way across the canvas.
    set offsgn [expr {$offset>0.0?1:-1}]
    set vertexcount [expr {[llength $path]/2-1}]
    while {1} {
        # Don't bother if there's only a triangle left.
        if {$vertexcount < 4} break

        set finished 1
        set nupath [lrange $path 0 1]
        foreach {sx sy} [lrange $path 0 end-4] \
                {mpx mpy} [lrange $path 2 end-2] \
                {ex ey} [lrange $path 4 end] \
        {
            set ang1 [expr {atan2($mpy-$sy,$mpx-$sx)}]
            set ang2 [expr {atan2($ey-$mpy,$ex-$mpx)}]
            set dang [expr {$ang2-$ang1}]
            if {$dang > $pi} {
                set dang [expr {$dang-2.0*$pi}]
            } elseif {$dang < -$pi} {
                set dang [expr {$dang+2.0*$pi}]
            }
            if {$dang*$offsgn < -$pi*0.75 || abs(abs($dang)-$pi) < 1e-6} {
                set len1 [expr {hypot($sy-$mpy,$sx-$mpx)}]
                set len2 [expr {hypot($ey-$mpy,$ex-$mpx)}]
                if {$len1 > $len2} {
                    set len3 [::math::geometry::calculateDistanceToLineSegment [list $ex $ey] [list $sx $sy $mpx $mpy]]
                } else {
                    set len3 [::math::geometry::calculateDistanceToLineSegment [list $sx $sy] [list $ex $ey $mpx $mpy]]
                }
                if {$len3 < 2.0*abs($offset)} {
                    set finished 0
                    if {abs($len2-$len1) < 1e-9} {
                        set npx [expr {($sx+$ex)/2.0}]
                        set npy [expr {($sy+$ey)/2.0}]
                        set npt [list $npx $npy]
                    } elseif {$len1 > $len2} {
                        set npt [::math::geometry::findClosestPointOnLineSegment [list $ex $ey] [list $sx $sy $mpx $mpy]]
                    } else {
                        set npt [::math::geometry::findClosestPointOnLineSegment [list $sx $sy] [list $ex $ey $mpx $mpy]]
                    }
                    foreach {abx aby} $npt break
                    lappend nupath $abx $aby
                } else {
                    lappend nupath $mpx $mpy
                }
            } else {
                lappend nupath $mpx $mpy
            }
        }
        lappend nupath [lindex $path end-1] [lindex $path end]
        if {$path == $nupath} {
            break
        }
        set path $nupath
        if {$finished} {
            break
        }
    }
    if {$debug} {
        puts -nonewline stderr "Deburred1 len=[llength $path] {"
        puts -nonewline stderr [format "%.5f %.5f" [lindex $path 0] [lindex $path 1]]
        foreach {xval yval} [lrange $path 2 end] {
            puts -nonewline stderr [format "  %.5f %.5f" $xval $yval]
        }
        puts stderr "}\n"
    }

    # Deburr start/end of closed path if it makes a sharply concave corner.
    if {$wasclosed} {
        foreach {sx sy} [lrange $path end-3 end-1] break
        foreach {mpx mpy} [lrange $path 0 1] break
        foreach {ex ey} [lrange $path 2 3] break
        set ang1 [expr {atan2($mpy-$sy,$mpx-$sx)}]
        set ang2 [expr {atan2($ey-$mpy,$ex-$mpx)}]
        set dang [expr {$ang2-$ang1}]
        if {$dang > $pi} {
            set dang [expr {$dang-2.0*$pi}]
        } elseif {$dang < -$pi} {
            set dang [expr {$dang+2.0*$pi}]
        }
        if {$dang*$offsgn < -$pi*0.75} {
            set len1 [expr {hypot($sy-$mpy,$sx-$mpx)}]
            set len2 [expr {hypot($ey-$mpy,$ex-$mpx)}]
            if {$len1 > $len2} {
                set len3 [::math::geometry::calculateDistanceToLineSegment [list $ex $ey] [list $sx $sy $mpx $mpy]]
            } else {
                set len3 [::math::geometry::calculateDistanceToLineSegment [list $sx $sy] [list $ex $ey $mpx $mpy]]
            }
            if {$len3 < 2.0*abs($offset)} {
                if {abs($len2-$len1) < 1e-9} {
                    set npx [expr {($sx+$ex)/2.0}]
                    set npy [expr {($sy+$ey)/2.0}]
                    set npt [list $npx $npy]
                } elseif {$len1 > $len2} {
                    set npt [::math::geometry::findClosestPointOnLineSegment [list $ex $ey] [list $sx $sy $mpx $mpy]]
                } else {
                    set npt [::math::geometry::findClosestPointOnLineSegment [list $sx $sy] [list $ex $ey $mpx $mpy]]
                }
                foreach {abx aby} $npt break
                set path [lreplace [lrange $path 0 end-2] 0 1 $abx $aby]
                lappend path $abx $aby
            }
        }
    }
    if {$debug} {
        puts -nonewline stderr "Deburred2 len=[llength $path] {"
        puts -nonewline stderr [format "%.5f %.5f" [lindex $path 0] [lindex $path 1]]
        foreach {xval yval} [lrange $path 2 end] {
            puts -nonewline stderr [format "  %.5f %.5f" $xval $yval]
        }
        puts stderr "}\n"
    }

    set modpath $path

    # Inset each angle vertex
    set origangs {}
    set insetpath {}
    set curvstep 0.175  ;# 0.175 radians ~= 10 degrees steps.
    foreach {sx sy mx my} [lrange $modpath 0 3] break
    foreach {nx ny ex ey} [lrange $modpath end-3 end] break
    if {$wasclosed} {
        set ang1 [expr {atan2($ey-$ny,$ex-$nx)}]
        set ang2 [expr {atan2($my-$sy,$mx-$sx)}]
        set dang [expr {$ang2-$ang1}]
        while {$dang < -$pi} {
            set dang [expr {$dang+2.0*$pi}]
        }
        while {$dang > $pi} {
            set dang [expr {$dang-2.0*$pi}]
        }
        if {($dang > $curvstep+1e-6 && $offset > 0.0) || \
            ($dang < -$curvstep-1e-6 && $offset < 0.0)
        } {
            # Make arcs around convex angles.
            set sang [expr {$ang1-$pi/2.0}]
            set eang [expr {$ang2-$pi/2.0}]
            set ddang [expr {0.5*$dang/ceil(abs($dang)/$curvstep)}]
            set lmult [expr {sqrt(1.0+pow(sin($ddang),2.0))}]
            set first 1
            set sang [expr {$sang+$ddang}]
            while {1} {
                set ix [expr {$lmult*$offset*cos($sang)+$sx}]
                set iy [expr {$lmult*$offset*sin($sang)+$sy}]
                if {$first} {
                    set svx $ix
                    set svy $iy
                    set first 0
                } else {
                    lappend origangs [expr {$sang+$pi/2.0}]
                }
                lappend insetpath $ix $iy
                set sang [expr {$sang+$ddang}]
                if {abs($sang-$eang) < 0.01 || abs(abs($sang-$eang)-2.0*$pi) < 0.01} {
                    break
                }
                set sang [expr {$sang+$ddang}]
            }
        } else {
            # Calculate vertex inset
            set isect [mlcnc_path_inset_angle_point $nx $ny  $ex $ey  $mx $my $offset]
            foreach {svx svy} $isect break
            lappend insetpath $svx $svy
        }
    } else {
        set ang [expr {atan2($my-$sy,$mx-$sx)-$pi/2.0}]
        set ix [expr {$offset*cos($ang)+$sx}]
        set iy [expr {$offset*sin($ang)+$sy}]
        lappend insetpath $ix $iy
    }

    foreach {sx sy} [lrange $modpath 0 end-4] \
            {mpx mpy} [lrange $modpath 2 end-2] \
            {ex ey} [lrange $modpath 4 end] \
    {
        set ang1 [expr {atan2($mpy-$sy,$mpx-$sx)}]
        set ang2 [expr {atan2($ey-$mpy,$ex-$mpx)}]
        set dang [expr {$ang2-$ang1}]
        while {$dang < -$pi} {
            set dang [expr {$dang+2.0*$pi}]
        }
        while {$dang > $pi} {
            set dang [expr {$dang-2.0*$pi}]
        }
        if {($dang > $curvstep+1e-6 && $offset > 0.0) || \
            ($dang < -$curvstep-1e-6 && $offset < 0.0)
        } {
            # Make arcs around convex angles.
            set sang [expr {$ang1-$pi/2.0}]
            set eang [expr {$ang2-$pi/2.0}]
            set ddang [expr {0.5*$dang/ceil(abs($dang)/$curvstep)}]
            set lmult [expr {sqrt(1.0+pow(sin($ddang),2.0))}]
            set sang [expr {$sang+$ddang}]
            while {1} {
                set ix [expr {$lmult*$offset*cos($sang)+$mpx}]
                set iy [expr {$offset*sin($sang)+$mpy}]
                lappend insetpath $ix $iy
                lappend origangs [expr {$sang+$pi/2.0}]
                set sang [expr {$sang+$ddang}]
                if {abs($sang-$eang) < 0.01 || abs(abs($sang-$eang)-2.0*$pi) < 0.01} {
                    break
                }
                set sang [expr {$sang+$ddang}]
            }
            set abx $ix
            set aby $iy
        } else {
            # Calculate vertex inset
            set isect [mlcnc_path_inset_angle_point $sx $sy  $mpx $mpy  $ex $ey $offset]
            foreach {abx aby} $isect break
            lappend insetpath $abx $aby
            lappend origangs $ang1
        }
    }
    foreach {sx sy ex ey} [lrange $modpath end-3 end] break
    set ang [expr {atan2($ey-$sy,$ex-$sx)}]
    if {$wasclosed} {
        lappend insetpath $svx $svy
        lappend origangs $ang
    } else {
        set ang [expr {atan2($ey-$sy,$ex-$sx)}]
        set pang [expr {atan2($ey-$sy,$ex-$sx)-$pi/2.0}]
        set ix [expr {$offset*cos($pang)+$ex}]
        set iy [expr {$offset*sin($pang)+$ey}]
        lappend insetpath $ix $iy
        lappend origangs $ang
    }
    if {$debug} {
        puts -nonewline stderr "Inset len=[llength $insetpath] {"
        puts -nonewline stderr [format "%.5f %.5f" [lindex $insetpath 0] [lindex $insetpath 1]]
        foreach {xval yval} [lrange $insetpath 2 end] {
            puts -nonewline stderr [format "  %.5f %.5f" $xval $yval]
        }
        puts stderr "}\n"
    }

    # Mark segments which reverse their vector for culling.
    set badsides {}
    foreach {cx cy} [lrange $insetpath 0 end-2] \
            {dx dy} [lrange $insetpath 2 end] \
            oang $origangs \
    {
        set ang [expr {atan2($dy-$cy,$dx-$cx)}]
        set dang [expr {$ang-$oang}]
        if {$dang <= -$pi} {
            set dang [expr {$dang+2.0*$pi}]
        } elseif {$dang > $pi} {
            set dang [expr {$dang-2.0*$pi}]
        }
        set bad [expr {(abs($dang) > $pi/2.0)? 1 : 0}]
        if {$debug} {
            if {$bad} {
                puts stderr [format "Reversed! %.5f %.5f %.5f %.5f" $cx $cy $dx $dy]
            }
        }
        lappend badsides $bad
    }
    if {$debug} {
        puts stderr "badsides=$badsides"
    }

    # Split inset path into uncrossed subpaths, and process each one.
    set goodpaths {}
    set subpathnum 0
    foreach sub [mlcnc_markedpath_uncross $insetpath $badsides] {
        incr subpathnum
        lassign $sub subpath badsides

        if {$debug} {
            puts stderr "subpath badsides=$badsides"
            puts -nonewline stderr "Subpath len=[llength $subpath] {"
            puts -nonewline stderr [format "%.5f %.5f" [lindex $subpath 0] [lindex $subpath 1]]
            foreach {xval yval} [lrange $subpath 2 end] {
                puts -nonewline stderr [format "  %.5f %.5f" $xval $yval]
            }
            puts stderr "}\n"
        }

        # Find segments that are fully within offset distance of original path.
        # mark them for culling.
        set seg 0
        foreach {cx cy} [lrange $subpath 0 end-2] \
                {dx dy} [lrange $subpath 2 end] \
        {
            if {![lindex $badsides $seg]} {
                set mindist [mlcnc_path_min_dist_from_point $path $cx $cy]
                set mindist2 [mlcnc_path_min_dist_from_point $path $dx $dy]
                set goodcnt 0
                if {$mindist >= abs($offset)-1e-6} {
                    incr goodcnt
                }
                if {$mindist2 >= abs($offset)-1e-6} {
                    incr goodcnt
                }
                if {$goodcnt < 2} {
                    # Check along middle of long lines as well as their endpoints.
                    set dist [expr {hypot($dy-$cy,$dx-$cx)}]
                    set stepdist [expr {abs($offset)-$mindist+1e-3}]
                    set step [expr {$stepdist/$dist}]
                    for {set i $step} {$i < 1.0 && $stepdist > 1e-6} {set i [expr {$i+$step}]} {
                        set sx [expr {($dx-$cx)*$i+$cx}]
                        set sy [expr {($dy-$cy)*$i+$cy}]
                        set mindist [mlcnc_path_min_dist_from_point $path $sx $sy]
                        if {$mindist > abs($offset)-1e-6} {
                            incr goodcnt
                            if {$goodcnt >= 2} break
                        }
                        set stepdist [expr {abs($offset)-$mindist+1e-6}]
                        if {$stepdist < 1e-3} {
                            set stepdist 1e-3
                        }
                        set step [expr {$stepdist/$dist}]
                    }
                }
                if {$goodcnt < 2} {
                    if {$debug} {
                        puts stderr [format "Too close! %.5f %.5f %.5f %.5f" $cx $cy $dx $dy]
                    }
                    lset badsides $seg 1
                }
            }
            incr seg
        }

        # if too few good sides, skip this subpath
        set segs [lsearch -exact -all $badsides 0]
        set nsegs [llength $segs]
        if {$nsegs < 3 && $subpathnum != 1} {
            if {$debug} {
                puts stderr "Cull subpath: too few line segments\n"
            }
            continue
        }

        # Cull bad sides.
        while {1} {
            if {[llength $subpath] < 4} break
            if {[llength [lsearch -exact -all $badsides 0]] < 2} break
            set didcull 0
            set spangs {}
            foreach {cx cy} [lrange $subpath 0 end-2] \
                    {dx dy} [lrange $subpath 2 end] \
            {
                set ang [expr {atan2($dy-$cy,$dx-$cx)}]
                lappend spangs $ang
            }
            set seg -1
            while {1} {
                if {[llength [lsearch -exact -all $badsides 0]] < 2} break
                set seg [lsearch -exact -start [incr seg] $badsides 1]
                if {$seg < 0} break
                if {$seg == 0 || [lindex $badsides end]} {
                    foreach {sx sy} [lrange $subpath 0 1] break
                    foreach {ex ey} [lrange $subpath end-1 end] break
                    if {hypot($ey-$sy,$ex-$sx) < 1e-6} {
                        # If a closed subpath, rotate so we can start with a good segment.
                        if {$debug} {
                            puts -nonewline stderr "PreRotpath len=[llength $subpath] {"
                            puts -nonewline stderr [format "%.5f %.5f" [lindex $subpath 0] [lindex $subpath 1]]
                            foreach {xval yval} [lrange $subpath 2 end] {
                                puts -nonewline stderr [format "  %.5f %.5f" $xval $yval]
                            }
                            puts stderr "}"
                            puts stderr "pre-rot badsides =$badsides"
                        }
                        set sseg [lindex [lsearch -exact -all $badsides 0] end]
                        set badsides [concat [lrange $badsides $sseg end] [lrange $badsides 0 [expr {$sseg-1}]]]
                        set spangs [concat [lrange $spangs $sseg end] [lrange $spangs 0 [expr {$sseg-1}]]]
                        set subpath [concat [lrange $subpath [expr {$sseg*2}] end] [lrange $subpath 2 [expr {$sseg*2+1}]]]
                        set seg [lsearch -exact $badsides 1]
                        if {$debug} {
                            puts stderr "post-rot badsides=$badsides"
                            puts -nonewline stderr "Rotpath len=[llength $subpath] {"
                            puts -nonewline stderr [format "%.5f %.5f" [lindex $subpath 0] [lindex $subpath 1]]
                            foreach {xval yval} [lrange $subpath 2 end] {
                                puts -nonewline stderr [format "  %.5f %.5f" $xval $yval]
                            }
                            puts stderr "}\n"
                        }

                    } else {
                        # TODO:  Uhhh... do something.  First segment is considered bad, and the path is not closed..
                        if {$debug} {
                            puts stderr "Can't rot!  Not closed path!"
                        }
                    }
                }
                set seg2 [lsearch -exact -start $seg $badsides 0]
                if {$debug} {
                    puts stderr "post-rot-loop badsides=$badsides"
                    puts stderr "seg=$seg   seg2=$seg2"
                    puts -nonewline stderr "SP2 len=[llength $subpath] {"
                    puts -nonewline stderr [format "%.5f %.5f" [lindex $subpath 0] [lindex $subpath 1]]
                    foreach {xval yval} [lrange $subpath 2 end] {
                        puts -nonewline stderr [format "  %.5f %.5f" $xval $yval]
                    }
                    puts stderr "}\n"
                }

                set ay1 [set by1 ""]
                foreach {ax0 ay0 ax1 ay1} [lrange $subpath [expr {$seg*2-2}] [expr {$seg*2+1}]] break
                foreach {bx0 by0 bx1 by1} [lrange $subpath [expr {$seg2*2}] [expr {$seg2*2+3}]] break
                if {$ay1 == "" || $by1 == ""} {
                    if {$debug} {
                        puts stderr "before-escape badsides=$badsides"
                        puts stderr "Escape culler loop: Bad seg?"
                    }
                    break
                }
                set ix ""
                foreach {ix iy} [mlcnc_find_line_intersection $ax0 $ay0 $ax1 $ay1  $bx0 $by0 $bx1 $by1] break
                if {$ix == ""} {
                    error "Internal error: could not find intersection of good sides."
                }
                set badsides [concat [lrange $badsides 0 [expr {$seg-1}]] [lrange $badsides $seg2 end]]
                set spangs [concat [lrange $spangs 0 [expr {$seg-1}]] [lrange $spangs $seg2 end]]
                set subpath [concat [lrange $subpath 0 [expr {$seg*2-1}]] $ix $iy [lrange $subpath [expr {$seg2*2+2}] end]]
                set didcull 1

                if {$debug} {
                    puts stderr "after-clip badsides=$badsides"
                    puts -nonewline stderr "Culled len=[llength $subpath] {"
                    puts -nonewline stderr [format "%.5f %.5f" [lindex $subpath 0] [lindex $subpath 1]]
                    foreach {xval yval} [lrange $subpath 2 end] {
                        puts -nonewline stderr [format "  %.5f %.5f" $xval $yval]
                    }
                    puts stderr "}\n"
                }
            }

            if {$debug} {
                puts stderr "before re-mark badsides=$badsides"
                puts -nonewline stderr "BeforeReMark len=[llength $subpath] {"
                puts -nonewline stderr [format "%.5f %.5f" [lindex $subpath 0] [lindex $subpath 1]]
                foreach {xval yval} [lrange $subpath 2 end] {
                    puts -nonewline stderr [format "  %.5f %.5f" $xval $yval]
                }
                puts stderr "}\n"
            }

            # Mark segments which reverse their vector for culling.
            set mseg 0
            foreach {cx cy} [lrange $subpath 0 end-2] \
                    {dx dy} [lrange $subpath 2 end] \
                    oang $spangs \
            {
                set ang [expr {atan2($dy-$cy,$dx-$cx)}]
                set dang [expr {$ang-$oang}]
                if {$dang <= -$pi} {
                    set dang [expr {$dang+2.0*$pi}]
                } elseif {$dang > $pi} {
                    set dang [expr {$dang-2.0*$pi}]
                }
                set bad [expr {(abs($dang) > $pi/2.0)? 1 : 0}]
                if {$debug} {
                    if {$bad} {
                        puts stderr [format "Reversed! %.5f %.5f %.5f %.5f" $cx $cy $dx $dy]
                    }
                }
                if {$debug} {
                    puts stderr "mseg=$mseg   splen=[llength $subpath] spanglen=[llength $spangs]"
                }
                if {$bad} {
                    puts stderr "badsides=$badsides"
                    lset badsides $mseg 1
                }
                incr mseg
            }
            if {$debug} {
                puts stderr "badsides=$badsides"
                puts stderr "after re-mark badsides=$badsides"
                puts -nonewline stderr "AfterReMark len=[llength $subpath] {"
                puts -nonewline stderr [format "%.5f %.5f" [lindex $subpath 0] [lindex $subpath 1]]
                foreach {xval yval} [lrange $subpath 2 end] {
                    puts -nonewline stderr [format "  %.5f %.5f" $xval $yval]
                }
                puts stderr "}\n"
            }

            if {!$didcull} break
        }

        # If subpath has too few sides, skip it.
        if {[llength $subpath] < 4} continue

        # If subpath has too few good paths, skip it.
        if {$subpathnum != 1 && [llength [lsearch -exact -all $badsides 0]] < 2} continue

        # All culled now.  WE HAVE A WINNER!
        if {$subpathnum == 1 && !$wasclosed} {
            set subpath [mlcnc_path_remove_repeated_points $subpath]
        } else {
            foreach {px py} [mlcnc_closest_point_on_path $subpath $origx $origy] break
            set subpath [mlcnc_reorder_polygon_path_by_point $subpath $px $py]
            set subpath [mlcnc_path_remove_repeated_points $subpath]
        }
        if {$debug} {
            puts -nonewline stderr "Good len=[llength $subpath] {"
            puts -nonewline stderr [format "%.5f %.5f" [lindex $subpath 0] [lindex $subpath 1]]
            foreach {xval yval} [lrange $subpath 2 end] {
                puts -nonewline stderr [format "  %.5f %.5f" $xval $yval]
            }
            puts stderr "}\n"
        }
        lappend goodpaths $subpath
    }

    if {$debug} {
        puts stderr ""
        puts stderr ""
    }

    return $goodpaths
}


proc mlcnc_path_inset {path inset} {
    set offset [mlcnc_path_inset_offset $path $inset]
    return [mlcnc_path_offset $path $offset]
}


proc mlcnc_find_last_path_point_near_path {path nearpath tolerance} {
    set x ""
    set y ""
    foreach {px py} $path {
        set dist [mlcnc_path_min_dist_from_point $nearpath $px $py]
        if {$dist < $tolerance+0.00001} {
            set x $px
            set y $py
        }
    }
    return [list $x $y]
}


proc mlcnc_append_arc_points {var cx cy radius startang extent stepang} {
    constants pi
    upvar $var out
    set sang [expr {$startang*$pi/180.0}]
    set eang [expr {$sang+$extent*$pi/180.0}]
    set step [expr {$stepang*$pi/180.0}]
    if {$extent < 0.0} {
        for {set ang $sang} {$ang > $eang} {set ang [expr {$ang-$step}]} {
            set x [expr {$cx+$radius*cos($ang)}]
            set y [expr {$cy+$radius*sin($ang)}]
            lappend out $x $y
        }
    } else {
        for {set ang $sang} {$ang < $eang} {set ang [expr {$ang+$step}]} {
            set x [expr {$cx+$radius*cos($ang)}]
            set y [expr {$cy+$radius*sin($ang)}]
            lappend out $x $y
        }
    }
    set x [expr {$cx+$radius*cos($eang)}]
    set y [expr {$cy+$radius*sin($eang)}]
    lappend out $x $y
    return $out
}


proc mlcnc_close_path {var} {
    upvar $var out
    lappend out [lindex $out 0] [lindex $out 1]
}


proc mlcnc_reverse_path {path} {
    set out {}
    set count [llength $path]
    for {set i [expr {$count-2}]} {$i >= 0} {incr i -2} {
        lappend out [lindex $path $i] [lindex $path [expr {$i+1}]]
    }
    return $out
}


proc mlcnc_breakup_long_lines {path maxlen} {
    set out {}
    lappend out [lindex $path 0] [lindex $path 1]
    set count [llength $path]
    for {set i 0} {$i+3 < $count} {incr i 2} {
        foreach {ox oy x y} [lrange $path $i [expr {$i+3}]] break
        set dx [expr {$x-$ox}]
        set dy [expr {$y-$oy}]
        set dist [expr {sqrt($dx*$dx+$dy*$dy)}]
        if {$dist > $maxlen} {
            set ang [expr {atan2($dy,$dx)}]
            set dr [expr {$dist/ceil($dist/$maxlen)}]
            for {set r $dr} {$r <= $dist+0.00001} {set r [expr {$r+$dr}]} {
                set nx [expr {$ox+$r*cos($ang)}]
                set ny [expr {$oy+$r*sin($ang)}]
                lappend out $nx $ny
            }
        } else {
            lappend out $x $y
        }
    }
    return $out
}


proc mlcnc_path_length {path} {
    set len 0.0
    set ox [lindex $path 0]
    set oy [lindex $path 1]
    foreach {x y} [lrange $path 2 end] {
        set dx [expr {$x-$ox}]
        set dy [expr {$y-$oy}]
        set len [expr {$len+sqrt($dx*$dx+$dy*$dy)}]
        set ox $x
        set oy $y
    }
    return $len
}


proc mlcnc_perpendicular_line {x1 y1 x2 y2} {
    constants pi
    set cx [expr {($x1+$x2)/2.0}]
    set cy [expr {($y1+$y2)/2.0}]
    set dx [expr {$x1-$cx}]
    set dy [expr {$y1-$cy}]
    set ang [expr {atan2($dy,$dx)+($pi/2.0)}]
    set rad [expr {sqrt($dx*$dx+$dy*$dy)}]
    set px1 [expr {$cx+$rad*cos($ang)}]
    set py1 [expr {$cy+$rad*sin($ang)}]
    set px2 [expr {$cx-$rad*cos($ang)}]
    set py2 [expr {$cy-$rad*sin($ang)}]
    return [list $px1 $py1 $px2 $py2]
}


proc mlcnc_find_arc_from_points {x1 y1 x2 y2 x3 y3} {
    constants pi
    foreach {px1 py1 px2 py2} [mlcnc_perpendicular_line $x1 $y1 $x2 $y2] break
    foreach {px3 py3 px4 py4} [mlcnc_perpendicular_line $x2 $y2 $x3 $y3] break
    foreach {cx cy} [mlcnc_find_line_intersection $px1 $py1 $px2 $py2  $px3 $py3 $px4 $py4] break
    if {![info exists cx]} {
        return ""
    }
    set dx [expr {$x1-$cx}]
    set dy [expr {$y1-$cy}]
    set startang [expr {atan2($dy,$dx)}]
    set endang [expr {atan2($y3-$cy,$x3-$cx)}]
    set radius [expr {sqrt($dx*$dx+$dy*$dy)}]
    return [list $cx $cy $radius $startang $endang]
}


# Returns >0 if px,py is to the LEFT of the given vector line.
# Returns <0 if px,py is to the RIGHT of the given vector line.
# Returns ==0 if px,py is ON the given vector line.
proc mlcnc_line_side {lx0 lyx lx1 ly1 px py} {
    return [expr {(lx1 - lx0)*(py - ly0) - (px - lx0)*(ly1 - ly0)}]
}


# Takes a possibly self-crossing polygon, and reduces it to one or more
# simple polygons.  Returns a list of simple polygon paths.
proc mlcnc_region_uncross {path} {
    set isects [mlcnc_path_find_self_intersections $path]
    if {[llength $isects] == 0} {
        return [list $path]
    }
    foreach {s1 s2 x y} [lrange $isects 0 3] break
    set subpath1 [concat $x $y [lrange $path [expr {$s1*2+2}] [expr {$s2*2+1}]]]
    set subpath2 [concat [lrange $path 0 [expr {$s1*2+1}]] $x $y [lrange $path [expr {$s2*2+2}] end]]

    foreach {x0 y0} [lrange $subpath2 0 1] break
    foreach {xe ye} [lrange $subpath2 end-1 end] break
    if {abs($xe-$x0) < 1e-9 && abs($ye-$y0) < 1e-9} {
        set subpath2 [lrange $subpath2 0 end-2]
    }

    set subpaths {}
    foreach subpath [mlcnc_region_uncross $subpath1] {
        lappend subpaths $subpath
    }
    foreach subpath [mlcnc_region_uncross $subpath2] {
        lappend subpaths $subpath
    }
    return $subpaths
}


# Takes a possibly self-crossing polygon, and reduces it to one or more
# simple polygons.  Returns a list of simple polygon paths.
proc mlcnc_markedpath_uncross {path badsides} {
    set isects [mlcnc_path_find_self_intersections $path]
    if {[llength $isects] == 0} {
        return [list [list $path $badsides]]
    }
    foreach {s1 s2 x y} [lrange $isects 0 3] break

    set isbad1 [lindex $badsides $s1]
    set isbad2 [lindex $badsides $s2]
    set badsides1 [lrange $badsides $s1 $s2]
    set badsides2 [concat [lrange $badsides 0 $s1] [lrange $badsides $s2 end]]
    set subpath1 [concat $x $y [lrange $path [expr {$s1*2+2}] [expr {$s2*2+1}]] $x $y]
    set subpath2 [concat [lrange $path 0 [expr {$s1*2+1}]] $x $y [lrange $path [expr {$s2*2+2}] end]]

    set subpaths {}
    foreach subpath [mlcnc_markedpath_uncross $subpath2 $badsides2] {
        lappend subpaths $subpath
    }
    foreach subpath [mlcnc_markedpath_uncross $subpath1 $badsides1] {
        lappend subpaths $subpath
    }
    return $subpaths
}


proc mlcnc_region_insert_intersections {path1 path2} {
    set isects1 {}
    set isects2 {}
    foreach {s1 s2 x y} [mlcnc_path_find_path_intersections $path1 $path2] {
        lappend isects1 [list $s1 $x $y]
        lappend isects2 [list $s2 $x $y]
    }

    # Insert intersection points into path1
    set isects1 [lsort -integer -decreasing -index 0 $isects1]
    foreach isect $isects1 {
        foreach {seg x y} $isect break
        set path1 [linsert $path1 [expr {$seg*2}] $x $y]
    }

    # Insert intersection points into path2
    set isects2 [lsort -integer -decreasing -index 0 $isects2]
    foreach isect $isects2 {
        foreach {seg x y} $isect break
        set path2 [linsert $path2 [expr {$seg*2}] $x $y]
    }

    return [list $path1 $path2]
}


# Produces a union of two simple polygon paths.
# Returns a list of one or two simple polygon paths.
proc mlcnc_region_union {path1 path2} {
    lassign [mlcnc_region_insert_intersections $path1 $path2] path1 path2

    set isegs {}
    set isects [mlcnc_path_find_path_intersections $path1 $path2]
    if {[llength $isects] == 0} {
        return [list $path1 $path2]
    }

    foreach {s1 s2 x y} $isects {
        lappend isegs $s1
        lappend isegs2 $s2
        set iseg1($s2) $s1
        set iseg2($s1) $s2
        set isegx($s1) $x
        set isegy($s1) $y
    }

    # TODO: Finish this union code
    set outpath1 {}
    set outpath2 {}
    set seg 0
    foreach {ax0 ay0} [lrange $path1 0 1] break
    foreach {ax1 ay1} [lrange $path1 2 end] {
        set mx [expr {($ax0+$ax1)/2.0}]
        set my [expr {($ay0+$ay1)/2.0}]
        set is_in [mlcnc_path_circumscribes_point $path2 $mx $my]
        if {$seg ni $isegs} {
            if {!$is_in} {
                lappend outpath1 $ax0 $ay0
                lappend outpath1 $ax1 $ay1
            } else {
                lappend outpath2 $ax0 $ay0
                lappend outpath2 $ax1 $ay1
            }
        }

        set seg2 $iseg2($seg)
        foreach {bx0 by0 bx1 by1} [lrange $path1 [expr {$seg2*2}] [expr {$seg2*2+3}]] break
        incr seg
        set x0 $x1
        set y0 $y1
    }
}


proc mlcnc_region_normalize {inpaths expaths} {
    # Iterate included paths and
    #    Join any two included paths that intersect via Union.
    #    Remove those that are comletely circumscribed by another included path. 
    # Iterate excluded paths and
    #    Join any two excluded paths that intersect via Union.
    #    Remove those that are completely outside included paths.
    #    Remove those that are comletely circumscribed by another excluded path. 
    # Iterate included paths and
    #    Remove those that are completely circumscribed by an excluded paths.
    #    Subtract excluded paths.
    return [list $inpaths $expaths]
}


# vim: set ts=4 sw=4 nowrap expandtab: settings

