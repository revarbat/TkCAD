##################################################################
# General Matrix math
##################################################################

proc matrix_mult {mat1 mat2} {
	set m [llength $mat1]
	set n [llength [lindex $mat1 0]]
	set o [llength $mat2]
	set p [llength [lindex $mat2 0]]
	if {$n != $o} {
		error "Cols in mat1 must == rows in mat2"
	}
	set mat3 {}
	for {set i 0} {$i < $m} {incr i} {
		set row {}
		for {set j 0} {$j < $p} {incr j} {
			set sum 0.0
			for {set r 0} {$r < $n} {incr r} {
				set sum [expr {$sum+[lindex $mat1 $i $r]*[lindex $mat2 $r $j]}]
			}
			lappend row $sum
		}
		lappend mat3 $row
	}
	return $mat3
}


proc matrix_transpose {mat} {
    set m [llength $mat]
    set n [llength [lindex $mat 0]]
    set out {}
    for {set i 0} {$i < $n} {incr i} {
        set row {}
        for {set j 0} {$j < $m} {incr j} {
            lappend row [lindex $mat $j $i]
        }
        lappend out $row
    }
    return $out
}


proc matrix_print {mat} {
    set m [llength $mat]
    set n [llength [lindex $mat 0]]
    for {set i 0} {$i < $m} {incr i} {
        set row {[}
        for {set j 0} {$j < $n} {incr j} {
            set val [lindex $mat $i $j]
            append row [format " %10.5f" $val]
        }
        append row { ]}
        puts stdout $row
    }
    return
}


##################################################################
# Matrix 2D math
##################################################################

proc matrix_identity {} {
	set mat [list \
		[list 1 0 0] \
		[list 0 1 0] \
		[list 0 0 1] \
	]
    return $mat
}


proc matrix_translate {dx dy} {
	set mat2 [list \
		[list 1 0 $dx] \
		[list 0 1 $dy] \
		[list 0 0 1] \
	]
	return $mat2
}


proc matrix_scale {sx sy {cx 0.0} {cy 0.0}} {
	set mat2 [list \
		[list $sx 0   [expr {$cx-$sx*$cx}]] \
		[list 0   $sy [expr {$cy-$sy*$cy}]] \
		[list 0   0   1] \
	]
	return $mat2
}


proc matrix_rotate {ang {cx 0.0} {cy 0.0}} {
    constants pi
	set ang [expr {$ang*$pi/180.0}]
	set mat2 [list \
		[list [expr {cos($ang)}] [expr {-sin($ang)}] $cx] \
		[list [expr {sin($ang)}] [expr {cos($ang)}]  $cy] \
		[list 0                  0                   1] \
	]
    set mat2 [matrix_mult $mat2 [matrix_translate [expr {-$cx}] [expr {-$cy}]]]
	return $mat2
}


proc matrix_reflect_by_angle {ang} {
    constants pi
	set ang [expr {2.0*$ang*$pi/180.0}]
	set mat2 [list \
		[list [expr {cos($ang)}] [expr {sin($ang)}]  0] \
		[list [expr {sin($ang)}] [expr {-cos($ang)}] 0] \
		[list 0                  0                   1] \
	]
	return $mat2
}


proc matrix_reflect_line {x0 y0 x1 y1} {
    set dx [expr {$x1-$x0}]
    set dy [expr {$y1-$y0}]
    foreach {dx dy} [vector_normalize [list $dx $dy]] break

	set mat [list \
		[list [expr {$dx*$dx-$dy*$dy}] [expr {2.0*$dx*$dy}]     $x0] \
		[list [expr {2.0*$dx*$dy}]     [expr {$dy*$dy-$dx*$dx}] $y0] \
		[list 0                        0                        1] \
	]
    set mat2 [matrix_translate [expr {-$x0}] [expr {-$y0}]]
	set mat [matrix_mult $mat $mat2]
    return $mat
}


proc matrix_skew_xy {skx sky {cx 0.0} {cy 0.0}} {
	set mat [list \
		[list 1    $skx  $cx] \
		[list $sky 1     $cy] \
		[list 0    0     1] \
	]
    set mat2 [matrix_translate [expr {-$cx}] [expr {-$cy}]]
	set mat [matrix_mult $mat $mat2]
	return $mat
}



proc matrix_skew_x {ang {cx 0.0} {cy 0.0}} {
    constants pi
	set ang [expr {$ang*$pi/180.0}]
	set mat [list \
		[list 1 [expr {tan($ang)}] $cx] \
		[list 0         1          $cy] \
		[list 0         0          1] \
	]
    set mat2 [matrix_translate [expr {-$cx}] [expr {-$cy}]]
	set mat [matrix_mult $mat $mat2]
	return $mat
}



proc matrix_skew_y {ang {cx 0.0} {cy 0.0}} {
    constants pi
	set ang [expr {$ang*$pi/180.0}]
	set mat [list \
		[list 1                   0   $cx] \
		[list [expr {tan($ang)}]  1   $cy] \
		[list 0                   0   1] \
	]
    set mat2 [matrix_translate [expr {-$cx}] [expr {-$cy}]]
	set mat [matrix_mult $mat $mat2]
	return $mat
}



proc matrix_transform {args} {
    set mat [matrix_identity]
    for {set i 0} {$i < [llength $args]} {} {
        set cmd [lindex $args $i]
        incr i
        switch -exact -- $cmd {
            translate {
                set xoff [lindex $args $i]
                incr i
                set yoff [lindex $args $i]
                incr i
                set mat2 [matrix_translate $xoff $yoff]
            }
            scale {
                set scx [lindex $args $i]
                incr i
                set scy $scx
                if {[string is double -strict [lindex $args $i]]} {
                    set scy [lindex $args $i]
                    incr i
                }
                set cx 0.0
                if {[string is double -strict [lindex $args $i]]} {
                    set cx [lindex $args $i]
                    incr i
                }
                set cy 0.0
                if {[string is double -strict [lindex $args $i]]} {
                    set cy [lindex $args $i]
                    incr i
                }
                set mat2 [matrix_scale $scx $scy $cx $cy]
            }
            rotate {
                set ang [lindex $args $i]
                incr i
                set cx 0.0
                if {[string is double -strict [lindex $args $i]]} {
                    set cx [lindex $args $i]
                    incr i
                }
                set cy 0.0
                if {[string is double -strict [lindex $args $i]]} {
                    set cy [lindex $args $i]
                    incr i
                }
                set mat2 [matrix_rotate $ang $cx $cy]
            }
            skewX {
                set ang [lindex $args $i]
                incr i
                set cx 0.0
                if {[string is double -strict [lindex $args $i]]} {
                    set cx [lindex $args $i]
                    incr i
                }
                set cy 0.0
                if {[string is double -strict [lindex $args $i]]} {
                    set cy [lindex $args $i]
                    incr i
                }
                set mat2 [matrix_skew_x $ang $cx $cy]
            }
            skewY {
                set ang [lindex $args $i]
                incr i
                set cx 0.0
                if {[string is double -strict [lindex $args $i]]} {
                    set cx [lindex $args $i]
                    incr i
                }
                set cy 0.0
                if {[string is double -strict [lindex $args $i]]} {
                    set cy [lindex $args $i]
                    incr i
                }
                set mat2 [matrix_skew_y $ang $cx $cy]
            }
            skewXY {
                set skx [lindex $args $i]
                incr i
                set sky 0.0
                if {[string is double -strict [lindex $args $i]]} {
                    set sky [lindex $args $i]
                    incr i
                }
                set cx 0.0
                if {[string is double -strict [lindex $args $i]]} {
                    set cx [lindex $args $i]
                    incr i
                }
                set cy 0.0
                if {[string is double -strict [lindex $args $i]]} {
                    set cy [lindex $args $i]
                    incr i
                }
                set mat2 [matrix_skew_xy $skx $sky $cx $cy]
            }
            default {
                error "Unknown transformation type: $cmd"
            }
        }
        set mat [matrix_mult $mat2 $mat]
    }
    return $mat
}



proc matrix_transform_coords {mat1 coords} {
    set outcoords {}
    foreach {row1 row2 row3} $mat1 break
    foreach {a1 a2 a3} $row1 break
    foreach {b1 b2 b3} $row2 break
    foreach {x y} $coords {
        set nx [expr {$a1*$x+$a2*$y+$a3}]
        set ny [expr {$b1*$x+$b2*$y+$b3}]
        lappend outcoords $nx $ny
    }
    return $outcoords
}



##################################################################
# Matrix 3d math
##################################################################

proc matrix_3d_identity {} {
	set mat [list \
		[list 1 0 0 0] \
		[list 0 1 0 0] \
		[list 0 0 1 0] \
		[list 0 0 0 1] \
	]
    return $mat
}


proc matrix_3d_translate {dx dy dz} {
	set mat2 [list \
		[list 1 0 0 $dx] \
		[list 0 1 0 $dy] \
		[list 0 0 1 $dz] \
		[list 0 0 0 1  ] \
	]
	return $mat2
}


proc matrix_3d_scale {sx sy sz {cx 0.0} {cy 0.0} {cz 0.0}} {
	set mat2 [list \
		[list $sx 0   0   [expr {$cx-$sx*$cx}]] \
		[list 0   $sy 0   [expr {$cy-$sy*$cy}]] \
		[list 0   0   $sz [expr {$cz-$sz*$cz}]] \
		[list 0   0   0   1] \
	]
	return $mat2
}


proc matrix_3d_rotate {vect ang} {
    constants pi
	set ang [expr {$ang*$pi/180.0}]

    foreach {x y z} [vector_normalize $vect] break
    set cosv [expr {cos($ang)}]
    set sinv [expr {sin($ang)}]
    set cos1m [expr {1.0-cos($ang)}]

	set mat2 [list \
		[list [expr {$cosv+$cos1m*$x*$x}]    [expr {$cos1m*$x*$y-$sinv*$z}] [expr {$cos1m*$x*$z+$sinv*$y}] 0] \
		[list [expr {$cos1m*$y*$x+$sinv*$z}] [expr {$cosv+$cos1m*$y*$y}]    [expr {$cos1m*$y*$z-$sinv*$x}] 0] \
		[list [expr {$cos1m*$z*$x-$sinv*$y}] [expr {$cos1m*$z*$y+$sinv*$x}] [expr {$cosv+$cos1m*$z*$z}]    0] \
		[list 0                              0                              0                              1] \
	]
	return $mat2
}


proc matrix_3d_reflect_line {x0 y0 z0 x1 y1 z1} {
    set dx [expr {$x1-$x0}]
    set dy [expr {$y1-$y0}]
    set dz [expr {$z1-$z0}]
    foreach {dx dy dz} [vector_normalize [list $dx $dy $dz]] break

    set mat [matrix_3d_translate $x0 $y0 $z0]
	set mat2 [list \
		[list [expr {-$dz*$dz-$dy*$dy}] [expr {$dx*$dy}]          [expr {$dx*$dz}]           0] \
		[list [expr {$dy*$dx}]          [expr {-$dx*$dx-$dz*$dz}] [expr {$dy*$dz}]           0] \
		[list [expr {$dz*$dx}]          [expr {$dz*$dy}]          [expr {-$dy*$dy-$dz*$dz}]  0] \
		[list 0                         0                         0                          1] \
	]
	set mat [matrix_mult $mat $mat2]
    set mat2 [matrix_3d_translate [expr {-$x0}] [expr {-$y0}] [expr {-$z0}]]
	set mat [matrix_mult $mat $mat2]
    return $mat
}


# TODO: implement reflection across plane.
# Implementation ideas:
#   Given 3pts on plane.
#   vect1 = pt1 - pt0
#   vect2 = pt2 - pt0
#   norm = vect1 x vect2   (cross product)
#   norm = vector_normalize(norm)
#   (A, B, C) = norm
#   D = -(A(pt0_x) + B(pt0_y) + C(pt0_z))
# Matrix for reflection across plane Ax + By + Cz + D = 0 is at:
#   http://www.geom.uiuc.edu/docs/reference/CRC-formulas/node45.html


proc matrix_3d_shear_xy {shx shy} {
	set mat2 [list \
		[list 1    0    $shx 0] \
		[list 0    1    $shy 0] \
		[list 0    0    1    0] \
		[list 0    0    0    1] \
	]
	return $mat2
}


proc matrix_3d_shear_xz {shx shz} {
	set mat2 [list \
		[list 1    $shx 0    0] \
		[list 0    1    0    0] \
		[list 0    $shz 1    0] \
		[list 0    0    0    1] \
	]
	return $mat2
}


proc matrix_3d_shear_yz {shy shz} {
	set mat2 [list \
		[list 1    0    0    0] \
		[list $shy 1    0    0] \
		[list $shz 0    1    0] \
		[list 0    0    0    1] \
	]
	return $mat2
}


proc matrix_3d_coordsys_convert {origin xvect yvect zvect} {
    lappend xvect 0
    lappend yvect 0
    lappend zvect 0
    lappend origin 1
    return [matrix_transpose [list $xvect $yvect $zvect $origin]]
}


proc matrix_3d_transform_coords {mat1 coords} {
    set outcoords {}
    foreach {row1 row2 row3 row4} $mat1 break
    foreach {a1 a2 a3 a4} $row1 break
    foreach {b1 b2 b3 b4} $row2 break
    foreach {c1 c2 c3 c4} $row3 break
    foreach {x y z} $coords {
        set nx [expr {$a1*$x+$a2*$y+$a3*$z+$a4}]
        set ny [expr {$b1*$x+$b2*$y+$b3*$z+$b4}]
        set nz [expr {$c1*$x+$c2*$y+$c3*$z+$c4}]
        lappend outcoords $nx $ny $nz
    }
    return $outcoords
}




##################################################################
# Vector math
##################################################################

proc matrix_vector {mat} {
    set m [llength $mat]
    set out {}
    for {set i 0} {$i < $m-1} {incr i} {
        lappend out [lindex $mat $i $i]
    }
    return $out
}


proc vector_matrix {vect} {
    set m [llength $vect]
    incr m
    set out {}
    for {set i 0} {$i < $m} {incr i} {
        set row {}
        for {set j 0} {$j < $m} {incr j} {
            if {$i == $j} {
                if {$i == $m-1} {
                    lappend row 1
                } else {
                    lappend row [lindex $vect $i]
                }
            } else {
                lappend row 0
            }
        }
        lappend out $row
    }
    return $out
}


proc vector_magnitude {vect} {
    foreach {x y z} $vect break
    set sum 0.0
    foreach val $vect {
        set sum [expr {$sum+$val*$val}]
    }
    return [expr {sqrt($sum)}]
}


proc vector_normalize {vect} {
    foreach {x y z} $vect break
    set len [vector_magnitude $vect]
    set out {}
    foreach val $vect {
        lappend out [expr {$val/$len}]
    }
    return $out
}


proc vector_add {vect1 vect2} {
    set out {}
    foreach val1 $vect1 val2 $vect2 {
        lappend out [expr {$val1+$val2}]
    }
    return $out
}



proc vector_subtract {vect1 vect2} {
    set out {}
    foreach val1 $vect1 val2 $vect2 {
        lappend out [expr {$val1-$val2}]
    }
    return $out
}



proc vector_multiply {vect1 val} {
    set out {}
    foreach val2 $vect1 {
        lappend out [expr {$val*$val2}]
    }
    return $out
}


proc vector_dot {vect1 vect2} {
    set sum 0.0
    foreach val1 $vect1 val2 $vect2 {
        set sum [expr {$sum+$val1*$val2}]
    }
    return $sum
}


proc vector_cross {vect1 vect2} {
    foreach {x1 y1 z1} $vect1 break
    foreach {x2 y2 z2} $vect2 break
    set x [expr {$y1*$z2-$z1*$y2}]
    set y [expr {$z1*$x2-$x1*$z2}]
    set z [expr {$x1*$y2-$y1*$x2}]
    return [list $x $y $z]
}


proc vector_reflect {vect reflvect} {
    set numer [vector_dot $vect    $refvect]
    set denom [vector_dot $refvect $refvect]
    set mult [expr {2.0*$numer/$denom}]
    set vect2 [vector_multiply $refvect $mult]
    return [vector_subtract $vect $vect2]
}



# vim: set ts=4 sw=4 nowrap expandtab: settings

