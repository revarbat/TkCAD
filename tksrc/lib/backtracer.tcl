#!/bin/sh
# the next line restarts using wish \
exec wish "$0" "$@"

#############################################################################
#
# G-code backtracer
# copyright 2006-2011 by Fuzzball Software
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Library General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
#############################################################################

package require opt
catch { package require tkpath }


proc gcode_gvars {win args} {
	foreach var $args {
		uplevel upvar #0 "g$win-$var" $var
	}
}


proc gcode_gvars_clear_all {win} {
	foreach var [info globals "g$win-*"] {
		uplevel #0 unset $var
	}
}


proc gcode_toolfile_open {base} {
	set filetypes {
		{{Text Files}	{.txt}	TEXT	}
		{{Any Files}	{*}	TEXT	}
	}
	set file [tk_getOpenFile -defaultextension .txt -filetypes $filetypes \
		  -title "Open toolfile" -parent $base]
	if {$file != ""} {
		gcode_tools_load $file
	}
}


proc gcode_print_3view {base} {
	set isocanv $base.pw.p1.isocanv
	set filetypes {
		{{Postscript Files}	{.ps}	TEXT	}
	}

	set file [tk_getSaveFile -defaultextension .ps -filetypes $filetypes \
		  -title "Save view 3D" -parent $base]
	if {$file != ""} {
		$isocanv postscript -file $file
	}
}


proc gcode_tools_load {toolfile} {
	catch {
		set f [open $toolfile "r"]
		while {![eof $f]} {
			set line [string trim [gets $f]]
			if {$line == ""} {
				continue
			}
			scan $line "%d %d %f %f %s" pocket fms tlo diam comment
			gcode_tool_define $pocket $diam $tlo
		}
	}
	catch {
		close $f
	}
}


proc gcode_tool_define {toolnum tooldiam toollen} {
	global gcodeInfo
	set gcodeInfo(TOOL-$toolnum-DIAM) $tooldiam
	set gcodeInfo(TOOL-$toolnum-LENGTH) $toollen
}


proc gcode_tool_diam {toolnum} {
	global gcodeInfo
	if {![info exists gcodeInfo(TOOL-$toolnum-DIAM)]} {
		error "Tool not defined."
	}
	return $gcodeInfo(TOOL-$toolnum-DIAM)
}


proc gcode_tool_length {toolnum} {
	global gcodeInfo
	if {![info exists gcodeInfo(TOOL-$toolnum-LENGTH)]} {
		error "Tool not defined."
	}
	return $gcodeInfo(TOOL-$toolnum-LENGTH)
}


proc gcode_parameter {parmnum linenum} {
	global gcodeInfo
	if {$parmnum < 1 || $parmnum > 5399} {
		error "Bad parameter number after # at line $linenum"
	}
	if {abs($parmnum-int($parmnum+0.5)) > 0.0001} {
		error "Bad parameter number #$parmnum at line $linenum"
	}
	set parmnum [expr {int($parmnum+0.5)}]
	if {![info exists gcodeInfo(PARMS-$parmnum)]} {
		if {$parmnum == 5220} {
			return 1.0
		} else {
			return 0.0
		}
	}
	return $gcodeInfo(PARMS-$parmnum)
}


proc gcode_parameter_set {parmnum value linenum} {
	global gcodeInfo
	if {$parmnum < 1 || $parmnum > 5399} {
		error "Bad parameter number #$parmnum at line $linenum"
	}
	if {abs($parmnum-int($parmnum+0.5)) > 0.0001} {
		error "Bad parameter number #$parmnum at line $linenum"
	}
	if {![info exists gcodeInfo(PARMJOURNAL)]} {
		set gcodeInfo(PARMJOURNAL) {}
	}
	lappend gcodeInfo(PARMJOURNAL) $parmnum $value
}


proc gcode_parameters_commit {} {
	global gcodeInfo
	if {![info exists gcodeInfo(PARMJOURNAL)]} {
		set gcodeInfo(PARMJOURNAL) {}
	}
	foreach {parmnum value} $gcodeInfo(PARMJOURNAL) {
		set gcodeInfo(PARMS-$parmnum) $value
	}
}


proc gcode_integer {strvar cmd linenum} {
	upvar $strvar str
	if {$str == ""} {
		puts stderr "Expected integer or expression after '$cmd' at line $linenum"
		set val 0.0
	} else {
		set val [gcode_number str $cmd $linenum]
	}
	set intval [expr {round($val)}]
	if {abs($val-$intval) < 0.00001} {
		return $intval
	}
	puts stderr "Expected integer after '$cmd' at line $linenum"
}


proc gcode_expr {strvar cmd linenum} {
	upvar $strvar str
	set pi 3.141592653589793236
	set preconv 1.0
	set postconv 1.0
	while {[string index $str 0] == "-"} {
		set postconv [expr {-1.0*$postconv}]
		set str [string range $str 1 end]
	}
	if {[string is alpha [string index $str 0]]} {
		set word {}
		while {[string is alpha [string index $str 0]]} {
			append word [string index $str 0]
			set str [string range $str 1 end]
		}
		set word [string tolower $word]
		switch -exact -- $word {
			"abs" -
			"exp" -
			"round" -
			"sqrt" {
				set op $word
			}
			"cos" -
			"sin" -
			"tan" {
				set op $word
				set preconv [expr {$pi/180.0}]
			}
			"acos" -
			"asin" {
				set op $word
				set postconv [expr {$postconv*180.0/$pi}]
			}
			"atan" {
				set op "atan2"
				set postconv [expr {$postconv*180.0/$pi}]
			}
			"ln" {
				set op "log"
			}
			"fix" {
				set op "floor"
			}
			"fup" {
				set op "ceil"
			}
			default {
				error "Unrecognized word '$word' in line $linenum"
			}
		}
		if {[string index $str 0] != "\["} {
			error "Expected \[ after '$word' in line $linenum"
		}
		set val1 [gcode_expr str $cmd $linenum]
		if {$word == "atan"} {
			if {[string index $str 0] != "/"} {
				error "Expected '/ between arguments of '$word' in line $linenum"
			}
			set str [string range $str 1 end]
			if {[string index $str 0] != "\["} {
				error "Expected \[ after / for '$word' in line $linenum"
			}
			set val2 [gcode_expr str $cmd $linenum]
			set result [expr "${op}($val2,$val1)"]
		} else {
			set val1 [expr {$val1*$preconv}]
			set result [expr "${op}($val1)"]
		}
	} else {
		# Not a unary operator
		set nch [string index $str 0]
		if {[string is digit $nch] || $nch == "." || $nch == "#" || $nch == "\["} {
			# It's a number or parameter or sub-expression.
			set result [gcode_number str $cmd $linenum]
		} else {
			error "Unexpected operator '$ch' in expression at line $linenum"
		}
	}
	set result [expr {$result*$postconv}]

	# Check for binary operators
	set ops {}
	lappend ops [list 1 "+" 0.0]
	lappend ops [list 1 "+" $result]
	while {[string index $str 0] != "\]"} {
		set op3 [string index $str 0]
		if {[string range $str 0 1] == "**"} {
			set str [string range $str 2 "end"]
			set op3 "**"
			set pri3 3
		} elseif {[string toupper [string range $str 0 2]] == "MOD"} {
			set str [string range $str 3 "end"]
			set op3 "%"
			set pri3 2
		} elseif {$op3 == "*" || $op3 == "/"} {
			set str [string trimleft [string range $str 1 "end"]]
			set pri3 2
		} elseif {$op3 == "+" || $op3 == "-"} {
			set str [string trimleft [string range $str 1 "end"]]
			set pri3 1
		} else {
			error "Unrecognized operator '$currop' in line $linenum"
		}
		foreach {pri1 op1 val1} [lindex $ops end-1] break
		foreach {pri2 op2 val2} [lindex $ops end] break
		set val3 [gcode_expr str $cmd $linenum]
		lappend ops [list $pri3 $op3 $val3]
		while {$pri2 >= $pri3 && [llength $ops] > 2} {
			if {$op2 == "**"} {
				set val1 [expr {pow($val1,$val2)}]
			} else {
				set val1 [expr "$val1$op2$val2"]
			}
			set ops [lreplace $ops "end-2" "end-1" [list $pri1 $op1 $val1]]
			foreach {pri1 op1 val1} [lindex $ops end-2] break
			foreach {pri2 op2 val2} [lindex $ops end-1] break
		}
	}
	while {[llength $ops] > 1} {
		foreach {pri1 op1 val1} [lindex $ops end-1] break
		foreach {pri2 op2 val2} [lindex $ops end] break
		if {$op2 == "**"} {
			set result [expr {pow($val1,$val2)}]
		} else {
			set result [expr "$val1$op2$val2"]
		}
		set ops [lreplace $ops "end-1" "end" [list $pri1 $op1 $result]]
	}
	return [lindex [lindex $ops 0] 2]
}


proc gcode_number {strvar cmd linenum} {
	upvar $strvar str
	if {$str == ""} {
		puts stderr "Expected number after '$cmd' at line $linenum"
		return 0.0
	}
	set nch [string index $str 0]
	if {$nch == "+" || $nch == "-" || [string is digit $nch] || $nch == "."} {
		set postmult 1.0
		while {$nch == "+" || $nch == "-"} {
			if {$nch == "-"} {
				set postmult [expr {0.0-$postmult}]
			}
			set str [string trimleft [string range $str 1 end]]
			set nch [string index $str 0]
		}
		set num {}
		set havedec 0
		while {$str != "" && ([string is digit -strict $nch] || $nch == ".")} {
			if {[string is digit -strict $nch]} {
				if {$num == "" || $num eq "0"} {
					set num $nch
				} else {
					append num $nch
				}
			} elseif {$nch == "."} {
				if {$havedec} {
					error "Malformed number after '$cmd' in line $linenum"
				}
				set havedec 1
				append num $nch
			}
			set str [string trimleft [string range $str 1 end]]
			set nch [string index $str 0]
		}
		if {$num == "" || $num == "."} {
			error "Malformed number after '$cmd' in line $linenum"
		}
		set val [expr {$postmult*$num}]
		return $val
	} elseif {$nch == "\["} {
		set str [string trimleft [string range $str 1 end]]
		if {[string index $str 0] == "\]"} {
			error "Expected expression inside \[\] in line $linenum"
		}
		set result [gcode_expr str $cmd $linenum]
		if {[string index $str 0] != "\]"} {
			error "Expected \] after expression in line $linenum"
		}
		set str [string trimleft [string range $str 1 end]]
		return $result
	} elseif {$nch == "#"} {
		set str [string trimleft [string range $str 1 end]]
		set parmnum [gcode_integer str "#" $linenum]
		return [gcode_parameter $parmnum $linenum]
	}
	puts stderr "Expected number after '$cmd' at line $linenum"
	return 0.0
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



proc vector_magnitude {vec} {
	foreach {x y z} $vect break
	set d [expr {sqrt($x*$x+$y*$y+$z*$z)}]
	return $d
}


proc vector_normalize {vect} {
	foreach {x y z} $vect break
	set d [expr {sqrt($x*$x+$y*$y+$z*$z)}]
	if {$d < 1e-8} {
		return {0.0 0.0 1.0}
	}
	set x [expr {$x/$d}]
	set y [expr {$y/$d}]
	set z [expr {$z/$d}]
	return [list $x $y $z]
}


proc matrix_mult {mat1 mat2} {
	set m [llength $mat1]
	set n [llength [lindex $mat1 0]]
	set o [llength $mat2]
	set p [llength [lindex $mat2 0]]
	if {$n != $o} {
		error "Cols in mat1 must = rows in mat2"
	}
	set mat3 {}
	for {set i 0} {$i < $m} {incr i} {
		set row {}
		for {set j 0} {$j < $p} {incr j} {
			set sum 0.0
			for {set r 0} {$r < $n} {incr r} {
				set v1 [lindex [lindex $mat1 $i] $r]
				set v2 [lindex [lindex $mat2 $r] $j]
				set sum [expr {$sum+$v1*$v2}]
			}
			lappend row $sum
		}
		lappend mat3 $row
	}
	return $mat3
}


proc matrix_3d_translate {dx dy dz} {
	set mat2 [list \
		[list 1.0 0.0 0.0 $dx] \
		[list 0.0 1.0 0.0 $dy] \
		[list 0.0 0.0 1.0 $dz] \
		[list 0.0 0.0 0.0 1.0] \
	]
	return $mat2
}


proc matrix_3d_rotate {vect ang} {
	set pi 3.141592653589793236
	set ang [expr {$ang*$pi/180.0}]

	foreach {x y z} [vector_normalize $vect] break
	set cosv [expr {cos($ang)}]
	set sinv [expr {sin($ang)}]
	set cos1m [expr {1.0-cos($ang)}]

	set mat2 [list \
		[list [expr {$cosv+$cos1m*$x*$x}]    [expr {$cos1m*$x*$y-$sinv*$z}] [expr {$cos1m*$x*$z+$sinv*$y}] 0.0] \
		[list [expr {$cos1m*$y*$x+$sinv*$z}] [expr {$cosv+$cos1m*$y*$y}]    [expr {$cos1m*$y*$z-$sinv*$x}] 0.0] \
		[list [expr {$cos1m*$z*$x-$sinv*$y}] [expr {$cos1m*$z*$y+$sinv*$x}] [expr {$cosv+$cos1m*$z*$z}]    0.0] \
		[list 0.0                            0.0                            0.0                            1.0] \
	]
	return $mat2
}


proc matrix_delta_axis_angle {mat1 mat2} {
	set pi 3.141592653589793236

	set vec0  [lrange [matrix_mult $mat1 {0.0 0.0 0.0 1.0}] 0 2]
	set vec1y [lrange [matrix_mult $mat1 {0.0 1.0 0.0 1.0}] 0 2]
	set vec1z [lrange [matrix_mult $mat1 {0.0 0.0 1.0 1.0}] 0 2]
	set vec2y [lrange [matrix_mult $mat2 {0.0 1.0 0.0 1.0}] 0 2]
	set vec2z [lrange [matrix_mult $mat2 {0.0 0.0 1.0 1.0}] 0 2]

	set vec1y [vector_subtract $vec1y $vec0]
	set vec1z [vector_subtract $vec1z $vec0]
	set vec2y [vector_subtract $vec2y $vec0]
	set vec2z [vector_subtract $vec2z $vec0]

	set vec1y [vector_normalize $vec1y]
	set vec1z [vector_normalize $vec1z]
	set vec2y [vector_normalize $vec2y]
	set vec2z [vector_normalize $vec2z]

	set axis [vector_normalize [vector_cross $vec1z $vec2z]]
	set dot  [vector_dot $vec1z $vec2z]
	if {$dot > 1.0} {
		set dot 1.0
	}
	set ang  [expr {acos($dot)*180.0/$pi}]

	set mat  [matrix_3d_rotate $axis [expr {-$ang}]]
	set yvec [lrange [matrix_mult $mat [concat $vec2y 1.0]] 0 2]
	set paxis [vector_normalize [vector_cross $yvec $vec1y]]
	set dot  [vector_dot $yvec $vec1y]
	if {$dot > 1.0} {
		set dot 1.0
	}
	set pang [expr {-acos($dot)*180.0/$pi}]

	return [list $axis $ang $paxis $pang]
}


proc gcode_rotation_matrix {x0 y0 z0 x1 y1 z1 ang} {
	set dx [expr {$x1-$x0}]
	set dy [expr {$y1-$y0}]
	set dz [expr {$z1-$z0}]
	set pi 3.141592653589793236
	set ang [expr {$ang*$pi/180.0}]
	set t [expr {1.0-cos($ang)}]
	set s [expr {sin($ang)}]
	set c [expr {cos($ang)}]
	set mat1 [list \
		[list 1.0 0.0 0.0 [expr {0.0-$x0}]] \
		[list 0.0 1.0 0.0 [expr {0.0-$y0}]] \
		[list 0.0 0.0 1.0 [expr {0.0-$z0}]] \
		[list 0.0 0.0 0.0 1.0] \
	]
	set mat2 [list \
		[list [expr {$t*$dx*$dx+$c}]     [expr {$t*$dy*$dx-$s*$dz}] [expr {$t*$dz*$dx+$s*$dy}] $x0] \
		[list [expr {$t*$dx*$dy+$s*$dz}] [expr {$t*$dy*$dy+$c}]     [expr {$t*$dz*$dy-$s*$dx}] $y0] \
		[list [expr {$t*$dx*$dz-$s*$dy}] [expr {$t*$dy*$dz+$s*$dx}] [expr {$t*$dz*$dz+$c}]     $z0] \
		[list 0.0 0.0 0.0 1.0] \
	]
	set mat [matrix_mult $mat2 $mat1]
	return $mat
}


proc gcode_shift_line {x1 y1 x2 y2 amount} {
	set pi 3.141592653589793236
	set cx [expr {($x1+$x2)/2.0}]
	set cy [expr {($y1+$y2)/2.0}]
	set dx [expr {$x1-$cx}]
	set dy [expr {$y1-$cy}]
	set oang [expr {atan2($dy,$dx)}]
	set pang [expr {atan2($dy,$dx)+($pi/2.0)}]
	set rad [expr {sqrt($dx*$dx+$dy*$dy)}]
	set ex [expr {$cx+$amount*cos($pang)}]
	set ey [expr {$cy+$amount*sin($pang)}]
	set px [expr {$ex+$rad*cos($oang)}]
	set py [expr {$ey+$rad*sin($oang)}]
	return [list $px $py]
}



proc format_elapsed_time {secs} {
    set days [expr {int($secs/86400)}]
	set secs [expr {int($secs-$days*86400)}]
	set out ""
	if {$days > 0} {
	    append out "${days}d "
	}
	append out [clock format $secs -format "%T" -gmt 1]
	return $out
}



proc gcode_toolpath_append {base var x y z a b c type linenum reallinenum} {
	gcode_gvars $base xoffset yoffset zoffset aoffset boffset coffset
	gcode_gvars $base prev_x prev_y prev_z prev_a prev_b prev_c
	gcode_gvars $base a_matrix vector_ax0 vector_ay0 vector_az0 vector_ax1 vector_ay1 vector_az1
	gcode_gvars $base b_matrix vector_bx0 vector_by0 vector_bz0 vector_bx1 vector_by1 vector_bz1
	gcode_gvars $base c_matrix vector_cx0 vector_cy0 vector_cz0 vector_cx1 vector_cy1 vector_cz1
	gcode_gvars $base lencomp lencomptool diamcomp diamcomptool tool_width
	gcode_gvars $base units feedrate build_time

	upvar $var coordlist

	set lastx $x
	set lasty $y
	set lastz $z
	set lasta $a
	set lastb $b
	set lastc $c
	set coordsysnum [gcode_parameter 5220 $linenum]
	if {$coordsysnum > 0} {
		set parmbase [expr {5221+20*int($coordsysnum-1)}]
		set lastx [expr {$lastx+[gcode_parameter      $parmbase  $linenum]}]
		set lasty [expr {$lasty+[gcode_parameter [incr parmbase] $linenum]}]
		set lastz [expr {$lastz+[gcode_parameter [incr parmbase] $linenum]}]
		set lasta [expr {$lasta+[gcode_parameter [incr parmbase] $linenum]}]
		set lastb [expr {$lastb+[gcode_parameter [incr parmbase] $linenum]}]
		set lastc [expr {$lastc+[gcode_parameter [incr parmbase] $linenum]}]
	}
	set lastx [expr {$lastx+$xoffset}]
	set lasty [expr {$lasty+$yoffset}]
	set lastz [expr {$lastz+$zoffset}]
	set lasta [expr {$lasta+$aoffset}]
	set lastb [expr {$lastb+$boffset}]
	set lastc [expr {$lastc+$coffset}]

	set lastx2 $lastx
	set lasty2 $lasty

	set dx [expr {$lastx-$prev_x}]
	set dy [expr {$lasty-$prev_y}]
	set dz [expr {$lastz-$prev_z}]
	set seglen [expr {sqrt(($dx*$dx)+($dy*$dy)+($dz*$dz))}]
	set rate $feedrate
	if {$type == "rapid"} {
	    set rate 2500.0
	}
	if {$units == "mm"} {
		set rate [expr {$rate/25.4}]
	}
    set build_time [expr {$build_time+($seglen/($rate/60.0))}]

	if {$lencomp == "plus"} {
		set tlo [gcode_tool_length $lencomptool]
		set lastz [expr {$lastz-$tlo}]
	}

	if {$diamcomp == "left"} {
		set diam [gcode_tool_diam $diamcomptool]
		foreach {lastx2 lasty2} [gcode_shift_line $prev_x $prev_y $lastx2 $lasty2 [expr {$diam/-2.0}]] break
	} elseif {$diamcomp == "right"} {
		set diam [gcode_tool_diam $diamcomptool]
		foreach {lastx2 lasty2} [gcode_shift_line $prev_x $prev_y $lastx2 $lasty2 [expr {$diam/2.0}]] break
	}

	set steps 1
	if {abs($lasta-$prev_a) > 5.0} {
		set est_steps [expr {int(abs(($lasta-$prev_a)/5.0))}]
		if {$est_steps > $steps} {
			set steps $est_steps
		}
	}
	if {abs($lastb-$prev_b) > 5.0} {
		set est_steps [expr {int(abs(($lastb-$prev_b)/5.0))}]
		if {$est_steps > $steps} {
			set steps $est_steps
		}
	}
	if {abs($lastc-$prev_c) > 5.0} {
		set est_steps [expr {int(abs(($lastc-$prev_c)/5.0))}]
		if {$est_steps > $steps} {
			set steps $est_steps
		}
	}
	set partval [expr {1.0/(0.0+$steps)}]

	for {set i 1} {$i <= $steps} {incr i} {
		set realx [expr {$prev_x+($lastx2-$prev_x)*$partval*$i}]
		set realy [expr {$prev_y+($lasty2-$prev_y)*$partval*$i}]
		set realz [expr {$prev_z+($lastz-$prev_z)*$partval*$i}]
		set reala [expr {$prev_a+($lasta-$prev_a)*$partval*$i}]
		set realb [expr {$prev_b+($lastb-$prev_b)*$partval*$i}]
		set realc [expr {$prev_c+($lastc-$prev_c)*$partval*$i}]

		if {![info exists a_matrix] || $reala != $prev_a} {
			set a_matrix [gcode_rotation_matrix $vector_ax0 $vector_ay0 $vector_az0 $vector_ax1 $vector_ay1 $vector_az1 $reala]
		}
		if {$reala != 0.0} {
			set mat [list $realx $realy $realz 1.0]
			set mat [matrix_mult $a_matrix $mat]
			foreach {realx realy realz dummy} $mat break
		}

		if {![info exists b_matrix] || $realb != $prev_b} {
			set b_matrix [gcode_rotation_matrix $vector_bx0 $vector_by0 $vector_bz0 $vector_bx1 $vector_by1 $vector_bz1 $realb]
		}
		if {$realb != 0.0} {
			set mat [list $realx $realy $realz 1.0]
			set mat [matrix_mult $b_matrix $mat]
			foreach {realx realy realz dummy} $mat break
		}

		if {![info exists c_matrix] || $realc != $prev_c} {
			set c_matrix [gcode_rotation_matrix $vector_cx0 $vector_cy0 $vector_cz0 $vector_cx1 $vector_cy1 $vector_cz1 $realc]
		}
		if {$realc != 0.0} {
			set mat [list $realx $realy $realz 1.0]
			set mat [matrix_mult $c_matrix $mat]
			foreach {realx realy realz dummy} $mat break
		}

		lappend coordlist [list $realx $realy $realz $type $tool_width $reallinenum]
	}
	set prev_x $lastx
	set prev_y $lasty
	set prev_z $lastz
	set prev_a $lasta
	set prev_b $lastb
	set prev_c $lastc
}


proc gcode_parse_to_toolpath {base channel {progresscb ""} {codelb ""}} {
	gcode_gvars $base xoffset yoffset zoffset aoffset boffset coffset tool_width prev_x prev_y prev_z prev_a prev_b prev_c lencomp lencomptool diamcomp diamcomptool
	gcode_gvars $base a_matrix vector_ax0 vector_ay0 vector_az0 vector_ax1 vector_ay1 vector_az1
	gcode_gvars $base b_matrix vector_bx0 vector_by0 vector_bz0 vector_bx1 vector_by1 vector_bz1
	gcode_gvars $base c_matrix vector_cx0 vector_cy0 vector_cz0 vector_cx1 vector_cy1 vector_cz1
	gcode_gvars $base units feedrate build_time

	set pi 3.141592653589793236
	set max_arc_err 0.0001 ;# inches error

	set coordlist {}
	set coordsysnum 0
	for {set i 0} {$i <= 9} {incr i} {
		set coordsystems($i) [list 0.0 0.0 0.0 0.0 0.0 0.0]
	}
	set toolnum 1
	set gmode -1
	set speed 0.0
	set feedrate 1.0
	set feedmode "normal"
	set absmode 1
	set absarccenters 0
	set units "in"
	set plane "xy"
	set lencomptool 0
	set lencomp "none"
	set diamcomptool 0
	set diamcomp "none"
	set linenum 0
	set reallinenum 0
	set canned_feed 0.0
	set canned_return_level "orig"
	set tool_width 0.0
	set build_time 0.0

	set prev_x 0.0
	set prev_y 0.0
	set prev_z 0.0
	set prev_a 0.0
	set prev_b 0.0
	set prev_c 0.0

	set curra 0.0
	set currb 0.0
	set currc 0.0
	set currx 0.0
	set curry 0.0
	set currz 0.0

	set xnum $currx
	set ynum $curry
	set znum $currz
	set anum $curra
	set bnum $currb
	set cnum $currc
	set lnum 0
	set pnum 0.0
	set rnum 0.0

	set xoffset 0.0
	set yoffset 0.0
	set zoffset 0.0
	set aoffset 0.0
	set boffset 0.0
	set coffset 0.0

	gcode_toolpath_append $base coordlist $currx $curry $currz $curra $currb $currc "rapid" $linenum $reallinenum
	while {![eof $channel]} {
		incr linenum
		incr reallinenum
		if {[catch {gets $channel} line]} {
			break
		}
		$codelb insert end [format "%05d:  %s" $reallinenum $line]
		if {$progresscb != ""} {
			set filepos [tell $channel]
			if {[catch {eval $progresscb $filepos}]} {
				global errorInfo
				puts stderr $errorInfo
			}
		}
		set origline $line
		set line [regsub -all {[ 	]} $line ""]
		if {$line == ""} {
			continue
		}

		set have_x 0
		set have_y 0
		set have_z 0
		set have_a 0
		set have_b 0
		set have_c 0
		set have_i 0
		set have_j 0
		set have_k 0
		set have_l 0
		set have_p 0
		set have_r 0
		set inum 0.0
		set jnum 0.0
		set knum 0.0
		set do_set_origin 0
		set do_go_home 0
		set do_set_offsets 0

		while {$line != ""} {
			set cmd [string toupper [string index $line 0]]
			set line [string trim [string range $line 1 end]]
			switch -exact -- $cmd {
				"#" {
					set parmnum [gcode_integer line $cmd $linenum]
					if {$parmnum < 1 || $parmnum > 5399} {
						error "Bad parameter number after # at line $linenum"
					}
					if {[string index $line 0] != "="} {
						error "Expected '=' after parameter number in line $linenum"
					}
					set line [string range $line 1 end]
					set val [gcode_number line $cmd $linenum]
					gcode_parameter_set $parmnum $val $linenum
				}
				"(" {
					if {![regexp -- {^([^)]*)\)(.*)$} $line dummy comment newstr]} {
						error "Unterminated comment in lin $linenum"
					}
					if {[regexp -nocase -- {\( ([0-9][0-9.]*) or [0-9/]* inches tool diam \)} $origline dummy diam]} {
						set tool_width $diam
					}
					regexp -nocase -- { *\( Rotary table is on ([+-][XY]) side\.? *\) *} $origline dummy rottableside
					regexp -nocase -- { *\( Gear cutter is on ([+-][XY]) side\.? *\) *} $origline dummy gearcutterside
					if {[regexp -nocase -- {\( outside diam. = *([0-9][0-9.]*) in  \)} $origline dummy outsidediam]} {
						if {[info exists gearcutterside]} {
							if {$gearcutterside == "+Y"} {
								set outsidediam [expr {-$outsidediam}]
							}
						}
						set vector_ay0 $outsidediam
					}
					if {[regexp -nocase -- {\( helical angle = *([0-9][0-9.]*) deg \)} $origline dummy helicalang]} {
						set xyang 0.0
						if {[info exists rottableside]} {
							switch -exact -- $rottableside {
								"-X" { set xyang 0.0 }
								"+X" { set xyang 180.0 }
								"-Y" { set xyang 90.0 }
								"+Y" { set xyang 270.0 }
							}
						}
						set xyang [expr {$xyang*$pi/180.0}]
						set tilt [expr {$helicalang*$pi/180.0}]
						set vector_ax1 [expr {cos($xyang)*cos($tilt)+$vector_ax0}]
						set vector_ay1 [expr {sin($xyang)*cos($tilt)+$vector_ay0}]
						set vector_az1 [expr {sin($tilt)+$vector_az0}]
					}
					set line $newstr
				}
				"A" {
					set anum [gcode_number line $cmd $linenum]
					set have_a 1
				}
				"B" {
					set bnum [gcode_number line $cmd $linenum]
					set have_b 1
				}
				"C" {
					set cnum [gcode_number line $cmd $linenum]
					set have_c 1
				}
				"D" {
					set diamcomptool [gcode_integer line $cmd $linenum]
				}
				"F" {
					set feedrate [gcode_number line $cmd $linenum]
				}
				"G" {
					set gnum [gcode_number line $cmd $linenum]
					set gnum [format "%.1f" $gnum]
					switch -exact -- $gnum {
						0.0 - 1.0 - 2.0 - 3.0 {
							# movement command
							set gmode $gnum
						}
						4.0 {
							# Dwell.  Ignore this.
						}
						10.0 {
							set do_set_origin 1
						}
						17.0 {
							set plane "xy"
						}
						18.0 {
							set plane "xz"
						}
						19.0 {
							set plane "yz"
						}
						20.0 {
							set units "in"
						}
						21.0 {
							set units "mm"
						}
						28.0 {
							# return to home
							set do_go_home 1
						}
						30.0 {
							# return to secondary home
							set do_go_home 2
						}
						38.2 {
							# Straight-probe
							error "This parser cannot handle Straight-probe G38.2 codes."
						}
						40.0 {
							set diamcomp "none"
						}
						41.0 {
							set diamcomp "left"
						}
						42.0 {
							set diamcomp "right"
						}
						43.0 {
							set lencomp "plus"
						}
						49.0 {
							set lencomp "none"
						}
						53.0 {
							set coordsysnum 0
						}
						54.0 - 55.0 - 56.0 - 57.0 -
						58.0 - 59.0 {
							set coordsysnum [expr {int($gnum-53)}]
							gcode_parameter_set 5220 $coordsysnum $linenum
						}
						59.1 {
							set coordsysnum 7
							gcode_parameter_set 5220 $coordsysnum $linenum
						}
						59.2 {
							set coordsysnum 8
							gcode_parameter_set 5220 $coordsysnum $linenum
						}
						59.3 {
							set coordsysnum 9
							gcode_parameter_set 5220 $coordsysnum $linenum
						}
						61.0 - 61.1 - 64.0 {
							# Tool path control mode.  Ignore this.
						}
						80.0 {
							# Stop canned cycle mode
							set gmode -1
						}
						81.0 - 82.0 - 83.0 -
						84.0 - 85.0 - 86.0 -
						87.0 - 88.0 - 89.0 {
							# Canned movements
							set gmode $gnum
						}
						90.0 {
							set absmode 1
						}
						90.1 {
							set absarccenters 1
						}
						91.0 {
							set absmode 0
						}
						91.1 {
							set absarccenters 0
						}
						92.0 {
							set do_set_offsets 1
						}
						92.1 {
							set xoffset 0.0
							set yoffset 0.0
							set zoffset 0.0
							set aoffset 0.0
							set boffset 0.0
							set coffset 0.0
							gcode_parameter_set 5211 0.0 $linenum
							gcode_parameter_set 5212 0.0 $linenum
							gcode_parameter_set 5213 0.0 $linenum
							gcode_parameter_set 5214 0.0 $linenum
							gcode_parameter_set 5215 0.0 $linenum
							gcode_parameter_set 5216 0.0 $linenum
						}
						92.2 {
							set xoffset 0.0
							set yoffset 0.0
							set zoffset 0.0
							set aoffset 0.0
							set boffset 0.0
							set coffset 0.0
						}
						92.3 {
							set xoffset [gcode_parameter 5211 $linenum]
							set yoffset [gcode_parameter 5212 $linenum]
							set zoffset [gcode_parameter 5213 $linenum]
							set aoffset [gcode_parameter 5214 $linenum]
							set boffset [gcode_parameter 5215 $linenum]
							set coffset [gcode_parameter 5216 $linenum]
						}
						93.0 {
							set feedmode "inverse"
						}
						94.0 {
							set feedmode "normal"
						}
						98.0 {
							set canned_return_level "orig"
						}
						99.0 {
							set canned_return_level "R-point"
						}
						default {
							puts stderr "Unhandled code 'G$gnum' at line $linenum"
						}
					}
				}
				"H" {
					set lencomptool [gcode_integer line $cmd $linenum]
				}
				"I" {
					set inum [gcode_number line $cmd $linenum]
					if {$units == "mm"} {
					    set inum [expr {$inum/25.4}]
					}
					set have_i 1
				}
				"J" {
					set jnum [gcode_number line $cmd $linenum]
					if {$units == "mm"} {
					    set jnum [expr {$jnum/25.4}]
					}
					set have_j 1
				}
				"K" {
					set knum [gcode_number line $cmd $linenum]
					if {$units == "mm"} {
					    set knum [expr {$knum/25.4}]
					}
					set have_k 1
				}
				"L" {
					set lnum [gcode_integer line $cmd $linenum]
					set have_l 1
				}
				"M" {
					set mcode [gcode_integer line $cmd $linenum]
					# Ignore M-codes.  Nothing there that afects path.
				}
				"N" {
					set linenum [gcode_integer line $cmd $linenum]
				}
				"P" {
					set pnum [gcode_number line $cmd $linenum]
					set have_p 1
				}
				"Q" {
					set canned_feed [gcode_number line $cmd $linenum]
				}
				"R" {
					set rnum [gcode_number line $cmd $linenum]
					if {$units == "mm"} {
					    set rnum [expr {$rnum/25.4}]
					}
					set have_r 1
				}
				"S" {
					set speed [gcode_number line $cmd $linenum]
				}
				"T" {
					set toolnum [gcode_integer line $cmd $linenum]
				}
				"X" {
					set xnum [gcode_number line $cmd $linenum]
					if {$units == "mm"} {
					    set xnum [expr {$xnum/25.4}]
					}
					set have_x 1
				}
				"Y" {
					set ynum [gcode_number line $cmd $linenum]
					if {$units == "mm"} {
					    set ynum [expr {$ynum/25.4}]
					}
					set have_y 1
				}
				"Z" {
					set znum [gcode_number line $cmd $linenum]
					if {$units == "mm"} {
					    set znum [expr {$znum/25.4}]
					}
					set have_z 1
				}
				default {
					puts stderr "Unhandled code '$cmd' at line $linenum"
				}
			}
		}
		if {$do_set_offsets} {
			set allgood 0
			if {$have_x} {
				set xoffset [expr {$xoffset+$currx-$xnum}]
				set currx $xnum
				gcode_parameter_set 5211 $xoffset $linenum
				set allgood 1
			}
			if {$have_y} {
				set yoffset [expr {$yoffset+$curry-$ynum}]
				set curry $ynum
				gcode_parameter_set 5212 $yoffset $linenum
				set allgood 1
			}
			if {$have_z} {
				set zoffset [expr {$zoffset+$currz-$znum}]
				set currz $znum
				gcode_parameter_set 5213 $zoffset $linenum
				set allgood 1
			}
			if {$have_a} {
				set aoffset [expr {$aoffset+$curra-$anum}]
				set curra $anum
				gcode_parameter_set 5214 $aoffset $linenum
				set allgood 1
			}
			if {$have_b} {
				set boffset [expr {$boffset+$currb-$bnum}]
				set currb $bnum
				gcode_parameter_set 5215 $boffset $linenum
				set allgood 1
			}
			if {$have_c} {
				set coffset [expr {$coffset+$currc-$cnum}]
				set currc $cnum
				gcode_parameter_set 5216 $coffset $linenum
				set allgood 1
			}
			if {!$allgood} {
				error "No axis words given for G92 offset code at line $linenum."
			}
		} elseif {$do_set_origin} {
			if {!$have_l || $lnum != 2.0} {
				error "Expected L2 after G10 at line $linenum"
			}
			if {!$have_p || $pnum < 1.0 || $pnum > 9.0 || $pnum != floor($pnum)} {
				error "Expected integer P value between 1 and 9 after G10 at line $linenum"
			}
			set parmbase [expr {5221+20*($pnum-1)}]
			if {$have_x} {
				gcode_parameter_set [expr {$parmbase+0}] $xnum $linenum
			}
			if {$have_y} {
				gcode_parameter_set [expr {$parmbase+1}] $ynum $linenum
			}
			if {$have_z} {
				gcode_parameter_set [expr {$parmbase+2}] $znum $linenum
			}
			if {$have_a} {
				gcode_parameter_set [expr {$parmbase+3}] $anum $linenum
			}
			if {$have_b} {
				gcode_parameter_set [expr {$parmbase+4}] $bnum $linenum
			}
			if {$have_c} {
				gcode_parameter_set [expr {$parmbase+5}] $cnum $linenum
			}
		} else {
			if {$do_go_home == 1} {
				gcode_toolpath_append $base coordlist $xnum $ynum $znum $anum $bnum $cnum "rapid" $linenum $reallinenum

				set xnum [gcode_parameter 5161 $linenum]
				set ynum [gcode_parameter 5162 $linenum]
				set znum [gcode_parameter 5163 $linenum]
				set anum [gcode_parameter 5164 $linenum]
				set bnum [gcode_parameter 5165 $linenum]
				set cnum [gcode_parameter 5166 $linenum]

				gcode_toolpath_append $base coordlist $xnum $ynum $znum $anum $bnum $cnum "rapid" $linenum $reallinenum

				set currx $xnum
				set curry $ynum
				set currz $znum
				set curra $anum
				set currb $bnum
				set currc $cnum
			} elseif {$do_go_home == 2} {
				gcode_toolpath_append $base coordlist $xnum $ynum $znum $anum $bnum $cnum "rapid" $linenum $reallinenum

				set xnum [gcode_parameter 5181 $linenum]
				set ynum [gcode_parameter 5182 $linenum]
				set znum [gcode_parameter 5183 $linenum]
				set anum [gcode_parameter 5184 $linenum]
				set bnum [gcode_parameter 5185 $linenum]
				set cnum [gcode_parameter 5186 $linenum]

				gcode_toolpath_append $base coordlist $xnum $ynum $znum $anum $bnum $cnum "rapid" $linenum $reallinenum

				set currx $xnum
				set curry $ynum
				set currz $znum
				set curra $anum
				set currb $bnum
				set currc $cnum
			} else {
				switch -exact -- $gmode {
					0.0 {
						# Rapid linear move
						if {!$absmode} {
							set xnum [expr {$currx+($have_x?$xnum:0.0)}]
							set ynum [expr {$curry+($have_y?$ynum:0.0)}]
							set znum [expr {$currz+($have_z?$znum:0.0)}]
							set anum [expr {$curra+($have_a?$anum:0.0)}]
							set bnum [expr {$currb+($have_b?$bnum:0.0)}]
							set cnum [expr {$currc+($have_c?$cnum:0.0)}]
						}
						gcode_toolpath_append $base coordlist $xnum $ynum $znum $anum $bnum $cnum "rapid" $linenum $reallinenum
						set currx $xnum
						set curry $ynum
						set currz $znum
						set curra $anum
						set currb $bnum
						set currc $cnum
					}
					1.0 {
						# Linear interpolation
						if {!$absmode} {
							set xnum [expr {$currx+($have_x?$xnum:0.0)}]
							set ynum [expr {$curry+($have_y?$ynum:0.0)}]
							set znum [expr {$currz+($have_z?$znum:0.0)}]
							set anum [expr {$curra+($have_a?$anum:0.0)}]
							set bnum [expr {$currb+($have_b?$bnum:0.0)}]
							set cnum [expr {$currc+($have_c?$cnum:0.0)}]
						}
						gcode_toolpath_append $base coordlist $xnum $ynum $znum $anum $bnum $cnum "linear" $linenum $reallinenum

						set currx $xnum
						set curry $ynum
						set currz $znum
						set curra $anum
						set currb $bnum
						set currc $cnum
					}
					2.0 - 3.0 {
						# Clockwise helical interpolation
						if {$gmode == "2.0"} {
							set htype "helicalcw"
						} else {
							set htype "helicalccw"
						}
						if {!$absmode} {
							set xnum [expr {$currx+($have_x?$xnum:0.0)}]
							set ynum [expr {$curry+($have_y?$ynum:0.0)}]
							set znum [expr {$currz+($have_z?$znum:0.0)}]
							set anum [expr {$curra+($have_a?$anum:0.0)}]
							set bnum [expr {$currb+($have_b?$bnum:0.0)}]
							set cnum [expr {$currc+($have_c?$cnum:0.0)}]
						}
						if {!$absarccenters} {
							set inum [expr {$currx+($have_i?$inum:0.0)}]
							set jnum [expr {$curry+($have_j?$jnum:0.0)}]
							set knum [expr {$currz+($have_k?$knum:0.0)}]
						} else {
							set inum [expr {$have_i?$inum:$currx}]
							set jnum [expr {$have_j?$jnum:$curry}]
							set knum [expr {$have_k?$knum:$currz}]
						}
						if {$plane == "xy"} {
							if {$have_r} {
								set radius $rnum
								set d [expr {hypot($ynum-$curry,$xnum-$currx)/2.0}]
								if {$d > $radius} {
									error "Radius of arc is too small for distance between points in line $linenum"
								}
								set ang [expr {atan2($ynum-$curry,$xnum-$currx)-($pi/2.0)}]
								set h [expr {sqrt($radius*$radius-$d*$d)}]
								set mx [expr {($xnum+$currx)/2.0}]
								set my [expr {($ynum+$curry)/2.0}]
								set cx [expr {$h*cos($ang)+$mx}]
								set cy [expr {$h*sin($ang)+$my}]
							} else {
								set cx $inum
								set cy $jnum
								set radius [expr hypot($cx-$currx,$cy-$curry)]
							}
							set startang [expr {atan2($curry-$cy,$currx-$cx)}]
							set endang [expr {atan2($ynum-$cy,$xnum-$cx)}]
							if {$gmode == "2.0"} {
								if {$endang>=$startang} {
									set startang [expr {$startang+(2.0*$pi)}]
								}
							} else {
								if {$endang<=$startang} {
									set endang [expr {$endang+(2.0*$pi)}]
								}
							}
							if {$radius < 0.05} {
								set arc_res [expr {15.0*$pi/180.0}]
							} else {
								set arc_res [expr {2.0*acos(($radius-$max_arc_err)/$radius)}]
							}
							set steps [expr {1.0+int(abs($endang-$startang)/$arc_res)}]
							set stepang [expr {($endang-$startang)/$steps}]
							set stepz [expr {($znum-$currz)/$steps}]
							set stepa [expr {($anum-$curra)/$steps}]
							set stepb [expr {($bnum-$currb)/$steps}]
							set stepc [expr {($cnum-$currc)/$steps}]
							set arcz $currz
							set arca $curra
							set arcb $currb
							set arcc $currc
							set ang $startang
							while {1} {
								set arcx [expr {$cx+$radius*cos($ang)}]
								set arcy [expr {$cy+$radius*sin($ang)}]
								gcode_toolpath_append $base coordlist $arcx $arcy $arcz $anum $bnum $cnum $htype $linenum $reallinenum

								if {abs($ang-$endang) < 0.00001} {
									break
								}
								set arcz [expr {$arcz+$stepz}]
								set arca [expr {$arca+$stepa}]
								set arcb [expr {$arca+$stepb}]
								set arcc [expr {$arca+$stepc}]
								set ang [expr {$ang+$stepang}]
							}
						} elseif {$plane == "yz"} {
							if {$have_r} {
								set radius $rnum
								set d [expr {hypot($znum-$currz,$ynum-$curry)/2.0}]
								if {$d > $radius} {
									error "Radius of arc is too small for distance between points in line $linenum"
								}
								set ang [expr {atan2($znum-$currz,$ynum-$curry)-($pi/2.0)}]
								set h [expr {sqrt($radius*$radius-$d*$d)}]
								set my [expr {($ynum+$curry)/2.0}]
								set mz [expr {($znum+$currz)/2.0}]
								set cy [expr {$h*cos($ang)+$my}]
								set cz [expr {$h*sin($ang)+$mz}]
							} else {
								set cy $jnum
								set cz $knum
								set radius [expr hypot($cy-$curry,$cz-$currz)]
							}
							set startang [expr {atan2($currz-$cz, $curry-$cy)}]
							set endang [expr {atan2($znum-$cz, $ynum-$cy)}]
							if {$gmode == "2.0"} {
								if {$endang>=$startang} {
									set startang [expr {$startang+(2.0*$pi)}]
								}
							} else {
								if {$endang<=$startang} {
									set endang [expr {$endang+(2.0*$pi)}]
								}
							}
							if {$radius < 0.05} {
								set arc_res [expr {15.0*$pi/180.0}]
							} else {
								set arc_res [expr {2.0*acos(($radius-$max_arc_err)/$radius)}]
							}
							set steps [expr {1.0+int(abs($endang-$startang)/$arc_res)}]
							set stepang [expr {($endang-$startang)/$steps}]
							set stepz [expr {($xnum-$currx)/$steps}]
							set stepa [expr {($anum-$curra)/$steps}]
							set stepb [expr {($bnum-$currb)/$steps}]
							set stepc [expr {($cnum-$currc)/$steps}]
							set arcx $currx
							set arca $curra
							set arcb $currb
							set arcc $currc
							set ang $startang
							while {1} {
								set arcy [expr {$cy+$radius*cos($ang)}]
								set arcz [expr {$cz+$radius*sin($ang)}]
								gcode_toolpath_append $base coordlist $arcx $arcy $arcz $anum $bnum $cnum $htype $linenum $reallinenum

								if {abs($ang-$endang) < 0.00001} {
									break
								}
								set arcx [expr {$arcx+$stepx}]
								set arca [expr {$arca+$stepa}]
								set arcb [expr {$arca+$stepb}]
								set arcc [expr {$arca+$stepc}]
								set ang [expr {$ang+$stepang}]
							}
						} else {
							# XZ plane
							if {$have_r} {
								set radius $rnum
								set d [expr {hypot($znum-$currz,$xnum-$currx)/2.0}]
								if {$d > $radius} {
									error "Radius of arc is too small for distance between points in line $linenum"
								}
								set ang [expr {atan2($znum-$currz,$xnum-$currx)-($pi/2.0)}]
								set h [expr {sqrt($radius*$radius-$d*$d)}]
								set mx [expr {($xnum+$currx)/2.0}]
								set mz [expr {($znum+$currz)/2.0}]
								set cx [expr {$h*cos($ang)+$mx}]
								set cz [expr {$h*sin($ang)+$mz}]
							} else {
								set cx $inum
								set cz $knum
								set radius [expr hypot($cx-$currx,$cz-$currz)]
							}
							set startang [expr {atan2($currz-$cz, $currx-$cx)}]
							set endang [expr {atan2($znum-$cz, $xnum-$cx)}]
							if {$gmode == "2.0"} {
								if {$endang>=$startang} {
									set startang [expr {$startang+(2.0*$pi)}]
								}
							} else {
								if {$endang<=$startang} {
									set endang [expr {$endang+(2.0*$pi)}]
								}
							}
							if {$radius < 0.05} {
								set arc_res [expr {15.0*$pi/180.0}]
							} else {
								set arc_res [expr {2.0*acos(($radius-$max_arc_err)/$radius)}]
							}
							set steps [expr {1.0+int(abs($endang-$startang)/$arc_res)}]
							set stepang [expr {($endang-$startang)/$steps}]
							set stepy [expr {($ynum-$curry)/$steps}]
							set stepa [expr {($anum-$curra)/$steps}]
							set stepb [expr {($bnum-$currb)/$steps}]
							set stepc [expr {($cnum-$currc)/$steps}]
							set arcy $curry
							set arca $curra
							set arcb $currb
							set arcc $currc
							set ang $startang
							while {1} {
								set arcx [expr {$cx+$radius*cos($ang)}]
								set arcz [expr {$cz+$radius*sin($ang)}]
								gcode_toolpath_append $base coordlist $arcx $arcy $arcz $anum $bnum $cnum $htype $linenum $reallinenum

								if {abs($ang-$endang) < 0.00001} {
									break
								}
								set arcy [expr {$arcy+$stepy}]
								set arca [expr {$arca+$stepa}]
								set arcb [expr {$arca+$stepb}]
								set arcc [expr {$arca+$stepc}]
								set ang [expr {$ang+$stepang}]
							}
						}

						set currx $xnum
						set curry $ynum
						set currz $znum
						set curra $anum
						set currb $bnum
						set currc $cnum
					}
					81.0 - 82.0 - 83.0 -
					84.0 - 85.0 - 86.0 -
					87.0 - 88.0 - 89.0 {
						# Various drilling or boring cycles.
						for {set i 0} {$i < $lnum} {incr i} {
							if {$plane == "xy"} {
								if {$absmode} {
									set currx $xnum
									set curry $ynum
									set retractz $rnum
									set botz $znum
								} else {
									set currx [expr {$currx+$xnum}]
									set curry [expr {$curry+$ynum}]
									set retractz [expr {$currz+$rnum}]
									set botz [expr {$currz+$znum}]
								}
								if {$realrz > $realz} {
									gcode_toolpath_append $base coordlist $currx $curry $retractz $curra $currb $currc "rapid" $linenum $reallinenum
								}
								gcode_toolpath_append $base coordlist $currx $curry $currz $curra $currb $currc "rapid" $linenum $reallinenum
								gcode_toolpath_append $base coordlist $currx $curry $botz $curra $currb $currc "drill" $linenum $reallinenum
								gcode_toolpath_append $base coordlist $currx $curry $currz $curra $currb $currc "rapid" $linenum $reallinenum
							} elseif {$plane == "xz"} {
								if {$absmode} {
									set currx $xnum
									set currz $znum
									set retracty $rnum
									set boty $ynum
								} else {
									set currx [expr {$currx+$xnum}]
									set currz [expr {$currz+$znum}]
									set retracty [expr {$curry+$rnum}]
									set boty [expr {$curry+$ynum}]
								}
								if {$realrz > $realz} {
									gcode_toolpath_append $base coordlist $currx $retracty $currz $curra $currb $currc "rapid" $linenum $reallinenum
								}
								gcode_toolpath_append $base coordlist $currx $curry $currz $curra $currb $currc "rapid" $linenum $reallinenum
								gcode_toolpath_append $base coordlist $currx $boty  $currz $curra $currb $currc "drill" $linenum $reallinenum
								gcode_toolpath_append $base coordlist $currx $curry $currz $curra $currb $currc "rapid" $linenum $reallinenum
							} else {
								if {$absmode} {
									set curry $ynum
									set currz $znum
									set retractx $rnum
									set botx $xnum
								} else {
									set curry [expr {$curry+$ynum}]
									set currz [expr {$currz+$znum}]
									set retractx [expr {$currx+$rnum}]
									set botx [expr {$currx+$xnum}]
								}
								if {$realrz > $realz} {
									gcode_toolpath_append $base coordlist $retractx $curry $currz $curra $currb $currc "rapid" $linenum $reallinenum
								}
								gcode_toolpath_append $base coordlist $currx $curry $currz $curra $currb $currc "rapid" $linenum $reallinenum
								gcode_toolpath_append $base coordlist $botx  $curry $currz $curra $currb $currc "drill" $linenum $reallinenum
								gcode_toolpath_append $base coordlist $currx $curry $currz $curra $currb $currc "rapid" $linenum $reallinenum
							}
						}
					}
				}
			}
		}
		gcode_parameters_commit
	}
	return $coordlist
}



#################################################################################################
# Plotting routines
#################################################################################################

proc gcode_3d_color_segment {base segidx color {dogoto 1}} {
	gcode_gvars $base cammat minx maxx miny maxy minz maxz scaleval scalepcnt rendertime toolpath show_rapid_paths stereo
	set isocanv $base.pw.p1.isocanv

	set ysize [winfo reqwidth $isocanv]

	set transmat [list \
		[list 1.0 0.0 0.0 [expr {-($maxx+$minx)/2.0}]] \
		[list 0.0 1.0 0.0 [expr {-($maxy+$miny)/2.0}]] \
		[list 0.0 0.0 1.0 [expr {-($maxz+$minz)/2.0}]] \
		[list 0.0 0.0 0.0 1.0] \
	]
	set scalmat [list \
		[list [expr {$scaleval*($scalepcnt/100.0)}] 0.0 0.0 0.0] \
		[list 0.0 [expr {-$scaleval*($scalepcnt/100.0)}] 0.0 0.0] \
		[list 0.0 0.0 [expr {$scaleval*($scalepcnt/100.0)}] 0.0] \
		[list 0.0 0.0 0.0 1.0] \
	]
	set mat [matrix_mult $cammat $transmat]
	set mat [matrix_mult $scalmat $mat]
	set vvect0 [matrix_mult $mat {0.0 0.0 0.0 1.0}]
	set vvect1 [matrix_mult $mat {0.0 0.0 1.0 1.0}]
	set vvect [vector_subtract $vvect1 $vvect0]

	set topz $maxz
	if {$minz < 0.01} {
	    set topz 0.0
	}

	set pi 3.141592653589793236
	set showbitwidth 0
	if {abs(atan2(hypot([lindex $vvect 1],[lindex $vvect 0]),[lindex $vvect 2])*180.0/$pi) < 1.0} {
		set showbitwidth 1
	}

	foreach {x y z type tool_width srcline} [lindex $toolpath $segidx] break
	if {$color == ""} {
		set rcolor cyan
		set lcolor black
		set ccolor black
		if {$showbitwidth} {
			set dp [expr {abs(($z-$minz)/(($topz-$minz) == 0.0?1.0:($topz-$minz)))}]
			set ccolor [color_from_depth $dp]
			if {$dp < 0.25} {
				set ccolor #770
			}
		}
		set width 1
		set arrow "none"
		set rdash "2 2 2 2"
		set lstate "normal"
		set cstate [expr {$show_rapid_paths?"normal":"hidden"}]
		set rstate [expr {$show_rapid_paths?"normal":"hidden"}]
	} else {
		set lcolor $color
		set ccolor $color
		set rcolor $color
		if {$showbitwidth} {
			set width [expr {$scaleval*$scalepcnt/100.0*$tool_width}]
		} else {
			set width 5
		}
		set arrow "last"
		set rdash ""
		set lstate "normal"
		set cstate "normal"
		set rstate "normal"
	}
	if {$stereo == 1} {
		$isocanv itemconfig "StereoL&&Line_$srcline&&centerline"  -fill "#ff7f7f" -state $cstate -width $width -capstyle round -arrow $arrow
		$isocanv itemconfig "StereoL&&Line_$srcline&&!centerline" -fill "#ff7f7f" -state $lstate -width $width -capstyle round -arrow $arrow
		$isocanv itemconfig "StereoL&&RLine_$srcline" -fill "#ff7f7f" -state $rstate -width $width -dash $rdash -capstyle round -arrow $arrow

		$isocanv itemconfig "StereoR&&Line_$srcline&&centerline"  -fill "#00ffff" -state $cstate -width $width -capstyle round -arrow $arrow
		$isocanv itemconfig "StereoR&&Line_$srcline&&!centerline" -fill "#00ffff" -state $lstate -width $width -capstyle round -arrow $arrow
		$isocanv itemconfig "StereoR&&RLine_$srcline" -fill "#00ffff" -state $rstate -width $width -dash $rdash -capstyle round -arrow $arrow
	} else {
		$isocanv itemconfig "Line_$srcline&&centerline" -fill $ccolor -state $cstate -width $width -capstyle round -arrow $arrow
		$isocanv itemconfig "Line_$srcline&&!centerline" -fill $lcolor -state $lstate -width $width -capstyle round -arrow $arrow
		$isocanv itemconfig "RLine_$srcline" -fill $rcolor -state $rstate -width $width -dash $rdash -capstyle round -arrow $arrow
	}
	foreach {sx0 sy0 sx1 sy1} [$isocanv cget -scrollregion] break
	if {![info exists sx0] || !$dogoto || $color == ""} {
		return
	}

	set lobjs [$isocanv find withtag "RLine_$srcline||Line_$srcline"]
	if {$lobjs != {}} {
		set lobj [lindex $lobjs 0]
		set lcoords [$isocanv coords $lobjs]
		if {$lcoords == {}} {
			return
		}
		set isox [lindex $lcoords end-1]
		set isoy [lindex $lcoords end]

		foreach {xoff xpart} [$isocanv xview] break
		if {$xoff > 1e-6 || $xpart < 1.0-1e-6} {
			set cx0 [$isocanv canvasx 0]
			set cx1 [$isocanv canvasx [expr {[winfo width $isocanv]-2}]]
			set delt 10
			if {$isox < $cx0+$delt || $isox > $cx1-$delt} {
				set xoff [expr {(($isox-$sx0)/(0.0+$sx1-$sx0))-(($xpart-$xoff)/2.0)}]
				$isocanv xview moveto $xoff
			}
		}

		foreach {yoff ypart} [$isocanv yview] break
		if {$yoff > 1e-6 || $ypart < 1.0-1e-6} {
			set cy0 [$isocanv canvasy 0]
			set cy1 [$isocanv canvasy [expr {[winfo height $isocanv]-2}]]
			set delt 10
			if {$isoy < $cy0+$delt || $isoy > $cy1-$delt} {
				set yoff [expr {(($isoy-$sy0)/(0.0+$sy1-$sy0))-(($ypart-$yoff)/2.0)}]
				$isocanv yview moveto $yoff
			}
		}
	}
}


proc gcode_3d_playback_pause {base} {
	gcode_gvars $base playmode
	set playmode 0
}

proc gcode_3d_playback_toggle {base} {
	gcode_gvars $base playmode
	if {![info exists playmode]} {
		set playmode 1
	} elseif {$playmode} {
		set playmode 0
	} else {
		set playmode 1
	}
	if {$playmode} {
		gcode_3d_playback_handler $base
	}
}


proc gcode_3d_playback_handler {base} {
	gcode_gvars $base playmode
	if {!$playmode} {
		return
	}
	gcode_3d_hilite_next_line $base 10
	after 100 gcode_3d_playback_handler $base
}


proc gcode_3d_hilite_next_line {base lines {doupdate 1}} {
	gcode_gvars $base segment_number toolpath playmode
	set isocanv $base.pw.p1.isocanv
	foreach {x y z type tool_width srcline} [lindex $toolpath $segment_number] break
	set linenum $srcline
	set count [llength $toolpath]
	for {set j 0} {$j <= $lines} {incr j} {
		for {set i [expr {$segment_number+1}]} {$i <= $count} {incr i} {
			foreach {x y z type tool_width srcline} [lindex $toolpath $i] break
			if {$srcline != $linenum || $i == $count} {
				incr i -1
				if {$i >= $count-1} {
					set playmode 0
				}
				gcode_3d_color_segment $base $segment_number ""
				if {$doupdate || $j >= $lines} {
					set lbline [expr {$linenum-1}]
					$base.pw.p2.gcodelb selection clear 0 end
					$base.pw.p2.gcodelb selection set $lbline
					$base.pw.p2.gcodelb activate $lbline
					$base.pw.p2.gcodelb see $lbline
					gcode_3d_color_segment $base $i red
					update idletasks
				}
				set segment_number $i
				set linenum $srcline
				break
			}
		}
	}
	#$isocanv raise all
}


proc gcode_3d_hilite_prev_line {base lines {doupdate 1}} {
	gcode_gvars $base segment_number toolpath
	set isocanv $base.pw.p1.isocanv
	foreach {x y z type tool_width srcline} [lindex $toolpath $segment_number] break
	set linenum $srcline
	set count [llength $toolpath]
	for {set j 0} {$j < $lines+1} {incr j} {
		for {set i [expr {$segment_number-1}]} {$i >= 0} {incr i -1} {
			foreach {x y z type tool_width srcline} [lindex $toolpath $i] break
			if {$srcline != $linenum} {
				incr i
				gcode_3d_color_segment $base $segment_number ""
				if {$doupdate || $j >= $lines} {
					set lbline [expr {$linenum-1}]
					$base.pw.p2.gcodelb selection clear 0 end
					$base.pw.p2.gcodelb selection set $lbline
					$base.pw.p2.gcodelb activate $lbline
					$base.pw.p2.gcodelb see $lbline
					gcode_3d_color_segment $base $i red
					update idletasks
				}
				set segment_number $i
				set linenum $srcline
				break
			}
		}
	}
	#$isocanv raise all
}


proc gcode_select_line {base {line ""}} {
	gcode_gvars $base segment_number toolpath
	if {$line == ""} {
		set lbline [$base.pw.p2.gcodelb curselection]
	} else {
		set lbline [expr {$line-1}]
	}
	set segnum 0
	gcode_3d_color_segment $base $segment_number ""
	foreach seg $toolpath {
		foreach {x y z type tool_width srcline} $seg break
		if {$srcline > $lbline} {
			break
		}
		incr segnum
	}
	if {$segnum >= [llength $toolpath]} {
		set segnum [expr {[llength $toolpath]-1}]
	}
	set segment_number $segnum
	set linenum $srcline
	set lbline [expr {$segnum-1}]
	$base.pw.p2.gcodelb selection clear 0 end
	$base.pw.p2.gcodelb selection set $lbline
	$base.pw.p2.gcodelb activate $lbline
	$base.pw.p2.gcodelb see $lbline
	gcode_3d_color_segment $base $segnum red
}



proc color_from_depth {depthpart} {
	if {$depthpart > 1.0} {
	    set depthpart 1.0
	} elseif {$depthpart < 0.0} {
	    set depthpart 0.0
	}
	set h [expr {(1.0-$depthpart)*240.0}]
	set s 0.5
	set v [expr {0.10+0.80*$depthpart}]
	set h60 [expr {$h/60.0}]
	set hi [expr {int($h60)%6}]
	set f [expr {$h60-int($h60)}]
	set p [expr {$v*(1.0-$s)}]
	set q [expr {$v*(1.0-$f*$s)}]
	set t [expr {$v*(1.0-(1.0-$f)*$s)}]
	switch -exact -- $hi {
		0 { set r $v ; set g $t ; set b $p }
		1 { set r $q ; set g $v ; set b $p }
		2 { set r $p ; set g $v ; set b $t }
		3 { set r $p ; set g $q ; set b $v }
		4 { set r $t ; set g $p ; set b $v }
		5 { set r $v ; set g $p ; set b $q }
	}
	set r [expr {int($r*255)}]
	set g [expr {int($g*255)}]
	set b [expr {int($b*255)}]
	return [format "#%02x%02x%02x" $r $g $b]
}



proc gcode_3d_plot {base {ispreview 0}} {
	gcode_gvars $base cammat minx maxx miny maxy minz maxz scaleval scalepcnt rendertime toolpath segment_number show_rapid_paths stereo
	set isocanv $base.pw.p1.isocanv
	set scallbl $base.pw.p1.scallbl
	set sterlbl $base.pw.p1.sterlbl
	set pi 3.141592653589793236
	set zlevels 256


	set ysize [winfo reqwidth $isocanv]

	set aspect [expr {($maxy-$miny)/($maxx-$minx)}]
	set canv_aspect [expr {[winfo reqheight $isocanv]/[winfo reqwidth $isocanv]}]
	if {$aspect < $canv_aspect} {
		set scaleval [expr {([winfo reqwidth $isocanv]-40.0)/($maxx-$minx)}]
	} else {
		set scaleval [expr {([winfo reqheight $isocanv]-40.0)/($maxy-$miny)}]
	}
	set scaleval 100.0
	set topz $maxz
	if {$minz < 0.01} {
	    set topz 0.0
	}

	set transmat [list \
		[list 1.0 0.0 0.0 [expr {-($maxx+$minx)/2.0}]] \
		[list 0.0 1.0 0.0 [expr {-($maxy+$miny)/2.0}]] \
		[list 0.0 0.0 1.0 [expr {-($maxz+$minz)/2.0}]] \
		[list 0.0 0.0 0.0 1.0] \
	]
	set scalmat [list \
		[list [expr {$scaleval*($scalepcnt/100.0)}]  0.0 0.0 0.0] \
		[list 0.0 [expr {-$scaleval*($scalepcnt/100.0)}] 0.0 0.0] \
		[list 0.0 0.0 [expr {$scaleval*($scalepcnt/100.0)}]  0.0] \
		[list 0.0 0.0 0.0 1.0] \
	]
	set mat [matrix_mult $cammat $transmat]
	set mat [matrix_mult $scalmat $mat]

	set vvect0 [matrix_mult $mat {0.0 0.0 0.0 1.0}]
	set vvect1 [matrix_mult $mat {0.0 0.0 1.0 1.0}]
	set vvect [vector_subtract $vvect1 $vvect0]

	set vertang [expr {1.0*$pi/180.0}]
	set showbitwidth 0
	if {abs(atan2(hypot([lindex $vvect 1],[lindex $vvect 0]),[lindex $vvect 2])*180.0/$pi) < 1.0} {
		set showbitwidth 1
	}

	if {[namespace exists ::tkp]} {
		foreach child [$isocanv children 0] {
			$isocanv delete $child
		}
	} else {
		$isocanv delete all
	}
	$scallbl configure -text [format "%d%%" [expr {int($scalepcnt)}]]
	if {$stereo} {
		set smat1 $mat
		set smat2 $mat

		set srot [expr {2.0*$pi/180.0}]
		set srotmat1 [list \
			[list [expr {cos($srot)}] 0.0 [expr {sin($srot)}] 0.0] \
			[list 0.0 1.0 0.0 0.0] \
			[list [expr {-sin($srot)}] 0.0 [expr {cos($srot)}] 0.0] \
			[list 0.0 0.0 0.0 1.0] \
		]
		set srotmat2 [list \
			[list [expr {cos(-$srot)}] 0.0 [expr {sin(-$srot)}] 0.0] \
			[list 0.0 1.0 0.0 0.0] \
			[list [expr {-sin(-$srot)}] 0.0 [expr {cos(-$srot)}] 0.0] \
			[list 0.0 0.0 0.0 1.0] \
		]

		set smat1 [matrix_mult $srotmat1 $smat1]
		set smat2 [matrix_mult $srotmat2 $smat2]

		if {$stereo == 1} {
			$sterlbl configure -text "Red-Blue"
			set mats [list \
				$smat1 "#00ffff" 0 "StereoR" \
				$smat2 "#ff7f7f" 0 "StereoL" \
			]
			set showbitwidth 0
		} elseif {$stereo == 2} {
			$sterlbl configure -text "Convergent"
			set mats [list \
				$smat1 ""  150 "" \
				$smat2 "" -150 "" \
			]
		} elseif {$stereo == 3} {
			$sterlbl configure -text "Divergent"
			set mats [list \
				$smat1 "" -150 "" \
				$smat2 ""  150 "" \
			]
		}
	} else {
		$sterlbl configure -text "Normal"
		set mats [list $mat "" 0 ""]
	}

	foreach {mat colover st_off stereotags} $mats {
		set a1 [lindex [lindex $mat 0] 0]
		set a2 [lindex [lindex $mat 0] 1]
		set a3 [lindex [lindex $mat 0] 2]
		set a4 [lindex [lindex $mat 0] 3]
		set a4 0.0
		set a4 [expr {$a4+$ysize/2.0+$st_off}]
		set b1 [lindex [lindex $mat 1] 0]
		set b2 [lindex [lindex $mat 1] 1]
		set b3 [lindex [lindex $mat 1] 2]
		set b4 [expr {[lindex [lindex $mat 1] 3]+$ysize/2.0}]

		set isopath {}
		set backx [expr {$ysize-4}]
		set backy [expr {$ysize-4}]
		if {$ispreview && $rendertime > 0.25/($showbitwidth*2+1)} {
			set boxdata {}
			lappend boxdata $minx $miny $minz  $maxx $miny $minz  red
			lappend boxdata $maxx $miny $minz  $maxx $maxy $minz  black
			lappend boxdata $maxx $maxy $minz  $minx $maxy $minz  black
			lappend boxdata $minx $maxy $minz  $minx $miny $minz  green3

			lappend boxdata $minx $miny $minz  $minx $miny $maxz  blue
			lappend boxdata $maxx $miny $minz  $maxx $miny $maxz  black
			lappend boxdata $maxx $maxy $minz  $maxx $maxy $maxz  black
			lappend boxdata $minx $maxy $minz  $minx $maxy $maxz  black

			lappend boxdata $minx $miny $maxz  $maxx $miny $maxz  black
			lappend boxdata $maxx $miny $maxz  $maxx $maxy $maxz  black
			lappend boxdata $maxx $maxy $maxz  $minx $maxy $maxz  black
			lappend boxdata $minx $maxy $maxz  $minx $miny $maxz  black

			lappend boxdata $minx $miny $minz  $maxx $maxy $minz  grey
			lappend boxdata $maxx $miny $minz  $minx $maxy $minz  grey
			lappend boxdata $minx $miny $maxz  $maxx $maxy $maxz  cyan
			lappend boxdata $maxx $miny $maxz  $minx $maxy $maxz  cyan

			set linewidth 1.0
			foreach {x0 y0 z0 x1 y1 z1 color} $boxdata {
				set isox0 [expr {$a1*$x0+$a2*$y0+$a3*$z0+$a4}]
				set isoy0 [expr {$b1*$x0+$b2*$y0+$b3*$z0+$b4}]
				set isox1 [expr {$a1*$x1+$a2*$y1+$a3*$z1+$a4}]
				set isoy1 [expr {$b1*$x1+$b2*$y1+$b3*$z1+$b4}]
				if {[namespace exists ::tkp]} {
					$isocanv create pline [list $isox0 $isoy0 $isox1 $isoy1] -stroke $color -strokewidth $linewidth -strokedasharray "2 2 2 2"
				} else {
					$isocanv create line $isox0 $isoy0 $isox1 $isoy1 -fill $color -width $linewidth -dash "2 2 2 2"
				}
			}
		} else {
			set ox 0.0
			set oy 0.0
			set oz 0.0
			set otype "rapid"
			set osrcline 0
			set prevzq ""
			foreach pointdata $toolpath {
				foreach {x y z type tool_width srcline} $pointdata break
				if {$type != $otype || $srcline != $osrcline} {
					set pathlinetag "pathline"
					if {$otype == "rapid"} {
						set color cyan
						set dash "2 2 2 2"
						set tagpfx "RLine_"
						set lstate [expr {$show_rapid_paths?"normal":"hidden"}]
					} else {
						set color black
						set dash {}
						set tagpfx "Line_"
						set lstate "normal"
					}
					if {$colover != ""} {
						set color $colover
					}
					if {$showbitwidth} {
						set zquant [expr {int((0.0+$zlevels)*($z-$minz)/(($maxz-$minz) == 0.0?1.0:($maxz-$minz)))}]
						if {$prevzq == ""} {
							set prevzq $zquant
						}
						if {$tool_width > 0.0} {
							if {[llength $isopath] >= 4 && $otype != "rapid"} {
								set dp [expr {abs(($oz-$minz)/(($topz-$minz) == 0.0?1.0:($topz-$minz)))}]
								set color2 [color_from_depth $dp]
								if {$dp < 0.25} {
									set color #770
								}
								if {$colover != ""} {
									set color $colover
									set color2 $colover
								}
								if {[llength $isopath] >= 4} {
									if {[namespace exists ::tkp]} {
										$isocanv create polyline $isopath -stroke $color2 -strokewidth [expr {$scaleval*$scalepcnt/100.0*$tool_width}] -strokelinecap round -strokelinejoin round -tags "zq$prevzq bitwidth $otype $stereotags"
									} else {
										$isocanv create line $isopath -fill $color2 -width [expr {$scaleval*$scalepcnt/100.0*$tool_width}] -capstyle round -joinstyle round -tags "zq$prevzq bitwidth $otype $stereotags"
									}
								}
								set lstate [expr {$show_rapid_paths?"normal":"hidden"}]
								lappend pathlinetag "centerline"
								set prevzq $zquant
							}
						}
					}
					if {[llength $isopath] >= 4} {
						if {[namespace exists ::tkp]} {
							$isocanv create polyline $isopath -stroke $color -strokedasharray $dash -state $lstate -tags "zq$prevzq bitwidth $otype $stereotags"
						} else {
							$isocanv create line $isopath -fill $color -dash $dash -state $lstate -tags "$tagpfx$osrcline $pathlinetag $otype $stereotags"
						}
					}
					set isopath {}
					set isox [expr {$a1*$ox+$a2*$oy+$a3*$oz+$a4}]
					set isoy [expr {$b1*$ox+$b2*$oy+$b3*$oz+$b4}]
					lappend isopath $isox $isoy
				}
				set isox [expr {$a1*$x+$a2*$y+$a3*$z+$a4}]
				set isoy [expr {$b1*$x+$b2*$y+$b3*$z+$b4}]
				lappend isopath $isox $isoy
				set ox $x
				set oy $y
				set oz $z
				set otype $type
				set osrcline $srcline
			}
			set pathlinetag "pathline"
			if {$otype == "rapid"} {
				set color cyan
				set dash "2 2 2 2"
				set lstate [expr {$show_rapid_paths?"normal":"hidden"}]
			} else {
				set color black
				set dash {}
				set lstate "normal"
			}
			if {$colover != ""} {
				set color $colover
			}
			if {$showbitwidth} {
				set zquant [expr {int((0.0+$zlevels)*($z-$minz)/((0.0-$minz) == 0.0?1.0:(0.0-$minz)))}]
				if {$prevzq == ""} {
					set prevzq $zquant
				}
				if {$tool_width > 0.0} {
					if {[llength $isopath] >= 4 && $otype != "rapid"} {
						set dp [expr {abs(($oz-$minz)/(($topz-$minz) == 0.0?1.0:($topz-$minz)))}]
						set color2 [color_from_depth $dp]
						if {$dp < 0.25} {
							set color #fff
						}
						if {$colover != ""} {
							set color $colover
							set color2 $colover
						}
						if {[llength $isopath] >= 4} {
							if {[namespace exists ::tkp]} {
								$isocanv create polyline $isopath -stroke $color2 -strokewidth [expr {$scaleval*$scalepcnt/100.0*$tool_width}] -strokelinecap round -strokelinejoin round -tags "zq$prevzq bitwidth $otype $stereotags"
							} else {
								$isocanv create line $isopath -fill $color2 -width [expr {$scaleval*$scalepcnt/100.0*$tool_width}] -capstyle round -joinstyle round -tags "zq$prevzq bitwidth $otype $stereotags"
							}
						}
						set lstate [expr {$show_rapid_paths?"normal":"hidden"}]
						lappend pathlinetag "centerline"
						set prevzq $zquant
					}
				}
			}
			if {[llength $isopath] >= 4} {
				if {[namespace exists ::tkp]} {
					$isocanv create polyline $isopath -stroke $color -strokedasharray $dash -state $lstate -tags "$tagpfx$osrcline $pathlinetag $otype $stereotags"
				} else {
					$isocanv create line $isopath -fill $color -dash $dash -state $lstate -tags "$tagpfx$osrcline $pathlinetag $otype $stereotags"
				}
			}

			set midx [expr {($minx+$maxx)/2.0}]
			set midy [expr {($miny+$maxy)/2.0}]
			set midz [expr {($minz+$maxz)/2.0}]

			set axisdata {}
			#lappend axisdata $midx $midy $midz  $maxx $midy $midz  red
			#lappend axisdata $midx $midy $midz  $midx $maxy $midz  green3
			#lappend axisdata $midx $midy $midz  $midx $midy $maxz  blue
			lappend axisdata 0.0   0.0   0.0    1.0   0.0   0.0    red
			lappend axisdata 0.0   0.0   0.0    0.0   1.0   0.0    green3
			lappend axisdata 0.0   0.0   0.0    0.0   0.0   1.0    blue

			set linewidth 2.0
			foreach {x0 y0 z0 x1 y1 z1 color} $axisdata {
				if {$colover != ""} {
					set color $colover
				}
				set isox0 [expr {$a1*$x0+$a2*$y0+$a3*$z0+$a4}]
				set isoy0 [expr {$b1*$x0+$b2*$y0+$b3*$z0+$b4}]
				set isox1 [expr {$a1*$x1+$a2*$y1+$a3*$z1+$a4}]
				set isoy1 [expr {$b1*$x1+$b2*$y1+$b3*$z1+$b4}]
				if {hypot($isox1-$isox0,$isoy1-$isoy0) > 12.0} {
					if {[namespace exists ::tkp]} {
						$isocanv create pline [list $isox0 $isoy0 $isox1 $isoy1] -stroke $color -strokewidth $linewidth -tags axis
					} else {
						$isocanv create line $isox0 $isoy0 $isox1 $isoy1 -fill $color -arrow last -width $linewidth -tags axis
					}
				} else {
					if {[namespace exists ::tkp]} {
						$isocanv create pline [list $isox0 $isoy0 $isox1 $isoy1] -stroke $color -strokewidth $linewidth -tags axis
					} else {
						$isocanv create line $isox0 $isoy0 $isox1 $isoy1 -fill $color -width $linewidth -tags axis
					}
				}
			}
		}
	}
	for {set zq $zlevels} {$zq >= 0} {incr zq -1} {
		$isocanv raise "zq$zq"
	}
	$isocanv raise pathline
	$isocanv raise centerline
	$isocanv raise axis
	#$isocanv raise all
	set bbox [$isocanv bbox all]
	if {$bbox != {}} {
		foreach {x0 y0 x1 y1} $bbox break
		set canvw [winfo width $isocanv]
		set canvh [winfo height $isocanv]
		if {$x1-$x0 < $canvw} {
			set off [expr {($x1-$x0-$canvw)/2.0}]
			set x0 [expr {$x0+$off}]
			set x1 [expr {$x1-$off}]
		}
		if {$y1-$y0 < $canvh} {
			set off [expr {($y1-$y0-$canvh)/2.0}]
			set y0 [expr {$y0+$off}]
			set y1 [expr {$y1-$off}]
		}
		$isocanv configure -scrollregion [list $x0 $y0 $x1 $y1]
	}
	gcode_3d_color_segment $base $segment_number red 0
}


proc gcode_advance_stereomode {base} {
	gcode_gvars $base stereo
	set nustereo [expr {($stereo+1)%4}]
	gcode_set_stereomode $base $nustereo
}


proc gcode_set_stereomode {base nustereo} {
	gcode_gvars $base stereo scales scalepcnt oldstereo

	set stereo $nustereo

	if {$oldstereo < 2} {
		if {$stereo >= 2} {
			set scale_targ [expr {$scalepcnt/2.0}]
		} else {
			set scale_targ $scalepcnt
		}
	} else {
		if {$stereo < 2} {
			set scale_targ [expr {$scalepcnt*2.0}]
		} else {
			set scale_targ $scalepcnt
		}
	}

	set nuscalepcnt ""
	set closest 1e6
	foreach sc $scales {
		if {abs($sc-$scale_targ) < abs($closest-$scale_targ)} {
			set nuscalepcnt $sc
			set closest $sc
		}
	}
	gcode_3d_scale_to $base $nuscalepcnt
	gcode_3d_plot $base
	set oldstereo $stereo
	update idletasks
}


proc gcode_toggle_rapids {base} {
	gcode_gvars $base show_rapid_paths
	set show_rapid_paths [expr {!$show_rapid_paths}]
	set isocanv $base.pw.p1.isocanv
	$isocanv itemconfigure rapid -state [expr {$show_rapid_paths?"normal":"hidden"}]
	$isocanv itemconfigure centerline -state [expr {$show_rapid_paths?"normal":"hidden"}]
}


proc gcode_3d_rot_start {base x y} {
	gcode_gvars $base xrot_base yrot_base rot_dragging
	set xrot_base $x
	set yrot_base $y
	set rot_dragging 1

	set isocanv $base.pw.p1.isocanv
	set cid [$isocanv find withtag current]
	if {$cid == ""} return
	foreach tag [$isocanv gettags $cid] {
		if {[string match "*Line_*" $tag]} {
			set line [lindex [split $tag "_"] 1]
			gcode_select_line $base $line
		}
	}
}


proc gcode_3d_rot_drag {base x y} {
	gcode_gvars $base xrot_base yrot_base rot_dragging
	if {!$rot_dragging} {
		return
	}
	set pi 3.141592653589793236
	set isocanv $base.pw.p1.isocanv
	set ysize [winfo reqheight $isocanv]
	set dx [expr {$x-$xrot_base}]
	set dy [expr {$y-$yrot_base}]
	set xrot_base $x
	set yrot_base $y
	set xrot_by [expr {$dy*360.0/$ysize}]
	set yrot_by [expr {$dx*360.0/$ysize}]
	gcode_3d_rotate_by $base $xrot_by $yrot_by 0.0
	gcode_3d_plot $base 1
}


proc gcode_3d_rot_end {base x y} {
	gcode_gvars $base rot_dragging
	set rot_dragging 0
	gcode_3d_plot $base
}


proc gcode_3d_scroll_horiz {base val} {
	if {$val < 0} {
		$base.pw.p1.isocanv xview scroll 1 units
	} else {
		$base.pw.p1.isocanv xview scroll -1 units
	}
}


proc gcode_3d_scroll_vert {base val} {
	if {$val < 0} {
		$base.pw.p1.isocanv yview scroll 1 units
	} else {
		$base.pw.p1.isocanv yview scroll -1 units
	}
}


proc gcode_3d_view_top {base} {
	gcode_3d_rotate_to $base 0.0 0.0 0.0
}


proc gcode_3d_view_front {base} {
	gcode_3d_rotate_to $base -90.0 0.0 0.0
}


proc gcode_3d_view_side {base} {
	gcode_3d_rotate_to $base -90.0 0.0 -90.0
}


proc gcode_3d_view_iso {base} {
	gcode_3d_rotate_to $base -45.0 0.0 -30.0
}


proc gcode_3d_view_iso2 {base} {
	gcode_3d_rotate_to $base -45.0 0.0 30.0
}


proc gcode_3d_view_iso3 {base} {
	gcode_3d_rotate_to $base -45.0 0.0 150.0
}


proc gcode_3d_view_iso4 {base} {
	gcode_3d_rotate_to $base -45.0 0.0 240.0
}


proc gcode_3d_view_iso5 {base} {
	gcode_3d_rotate_to $base -30.0 0.0 0.0
}


proc gcode_3d_view_iso6 {base} {
	gcode_3d_rotate_to $base -75.0 0.0 0.0
}


proc gcode_3d_view_scale_reset {base} {
	gcode_gvars $base stereo
	if {$stereo >= 2} {
		gcode_3d_scale_to $base 50
	} else {
		gcode_3d_scale_to $base 100
	}
}


proc gcode_3d_rotate_by {base xrot_t yrot_t zrot_t} {
	gcode_gvars $base anim_pid targ_cammat cammat

	set pi 3.141592653589793236

	set xrmat [matrix_3d_rotate {1.0 0.0 0.0} $xrot_t]
	set yrmat [matrix_3d_rotate {0.0 1.0 0.0} $yrot_t]
	set zrmat [matrix_3d_rotate {0.0 0.0 1.0} $zrot_t]

	set mat $cammat
	set mat [matrix_mult $xrmat $mat]
	set mat [matrix_mult $yrmat $mat]
	set mat [matrix_mult $zrmat $mat]
	set targ_cammat $mat
	set cammat $mat

	if {[info exists anim_pid]} {
		after cancel $anim_pid
		unset anim_pid
	}
	gcode_3d_playback_pause $base
	gcode_3d_plot $base
	update idletasks
}


proc gcode_3d_rotate_to {base xrot_t yrot_t zrot_t} {
	set pi 3.141592653589793236
	gcode_gvars $base time_targ anim_pid targ_cammat cammat

	set xrmat [matrix_3d_rotate {1.0 0.0 0.0} $xrot_t]
	set yrmat [matrix_3d_rotate {0.0 1.0 0.0} $yrot_t]
	set zrmat [matrix_3d_rotate {0.0 0.0 1.0} $zrot_t]

	set mat $zrmat
	set mat [matrix_mult $yrmat $mat]
	set mat [matrix_mult $xrmat $mat]
	set targ_cammat $mat

	set time_targ [expr {[clock clicks -milliseconds]+500}]
	if {[info exists anim_pid]} {
		after cancel $anim_pid
	}
	set anim_pid [after idle gcode_3d_rotate_anim $base]
	gcode_3d_playback_pause $base
}


proc gcode_3d_scale_to {base scale_t} {
	gcode_gvars $base scale_targ time_targ anim_pid
	set pi 3.141592653589793236
	set scale_targ $scale_t
	set time_targ [expr {[clock clicks -milliseconds]+500}]
	if {[info exists anim_pid]} {
		after cancel $anim_pid
	}
	set anim_pid [after idle gcode_3d_rotate_anim $base]
	gcode_3d_playback_pause $base
}


proc gcode_3d_rotate_anim {base} {
	gcode_gvars $base scalepcnt scales scale_targ anim_pid rendertime time_targ
	gcode_gvars $base time_targ anim_pid targ_cammat cammat

	set now [clock clicks -milliseconds]
	set pi 3.141592653589793236

	set delayms 10
	if {$now>$time_targ} {
		set dtime 0.0
	} else {
		set dtime [expr {($time_targ-$now)/1000.0}]
	}
	set rtime [expr {$rendertime+$delayms/1000.0}]
	if {$rendertime > $dtime || $dtime <= 0.001} {
		set t 1.0
	} else {
		set t [expr {sqrt($rendertime/$dtime)}]
	}
	set u [expr {1.0-$t}]

	set done 0
	if {$t == 1.0} {
		set done 1
		set closest 1e6
		foreach sc $scales {
			if {abs($sc-$scale_targ) < abs($closest-$scale_targ)} {
				set scalepcnt $sc
				set closest $sc
			}
		}
	} else {
		set scalepcnt [expr {$scalepcnt*$u+$scale_targ*$t}]
	}

	if {$t == 1.0} {
		set cammat $targ_cammat
	} else {
		foreach {rvect rang ovect oang} [matrix_delta_axis_angle $targ_cammat $cammat] break
		set rang [expr {-$rang*$t}]
		set oang [expr {-$oang*$t}]
		set rmat [matrix_3d_rotate $rvect $rang]
		set omat [matrix_3d_rotate $ovect $oang]
		set cammat [matrix_mult $omat $cammat]
		set cammat [matrix_mult $rmat $cammat]
	}

	gcode_3d_plot $base
	update

	if {!$done} {
		set anim_pid [after $delayms gcode_3d_rotate_anim $base]
	} else {
		if {[info exists anim_pid]} {
			unset anim_pid
		}
	}
}


proc gcode_3d_scaling_change {base val x y} {
	gcode_gvars $base scalepcnt scales scaleval scalepid scale_targ
	set isocanv $base.pw.p1.isocanv
	set scalenum [lsearch -exact $scales $scalepcnt]
	if {$val < 0} {
		if {$scalenum > 1} {
			incr scalenum -1
		}
	} else {
		if {$scalenum < [llength $scales]-1} {
			incr scalenum 1
		}
	}
	set scalepcnt [lindex $scales $scalenum]
	set scale_targ [lindex $scales $scalenum]

	foreach {ix0 ix1} [$isocanv xview] break
	foreach {iy0 iy1} [$isocanv yview] break
	gcode_3d_plot $base 1
	foreach {ix2 ix3} [$isocanv xview] break
	foreach {iy2 iy3} [$isocanv yview] break

	set fullx [winfo reqwidth $isocanv]
	set fully [winfo reqwidth $isocanv]
	set px [expr {$x/double($fullx)}]
	set py [expr {$y/double($fullx)}]
	set dx0 [expr {$ix1-$ix0}]
	set dy0 [expr {$iy1-$iy0}]
	set dx1 [expr {$ix3-$ix2}]
	set dy1 [expr {$iy3-$iy2}]
	set vcx [expr {$ix0+$dx0*$px}]
	set vcy [expr {$iy0+$dy0*$py}]
	set nx [expr {$vcx-$dx1*$px}]
	set ny [expr {$vcy-$dy1*$py}]
	$isocanv xview moveto $nx
	$isocanv yview moveto $ny

	if {[info exists scalepid]} {
		after cancel $scalepid
	}
	set scalepid [after 500 gcode_3d_scaling_change_plot $base]
}


proc gcode_3d_scaling_change_plot {base} {
	gcode_3d_plot $base
	gcode_gvars $base scalepid
	catch {unset scalepid}
}


proc gcode_file_parse {base file {progresscb ""} {codelb ""}} {
	set stime [clock clicks -milliseconds]

	gcode_gvars $base filename minx maxx miny maxy minz maxz toolpath

	set filename $file

	set f [open $file "r"]
	if {$progresscb != ""} {
		seek $f 0 end
		set endfilepos [tell $f]
		seek $f 0 start
		lappend progresscb $endfilepos
	}
	set toolpath [gcode_parse_to_toolpath $base $f $progresscb $codelb]
	catch {close $channel}

	set stime [clock clicks -milliseconds]

	set minx ""
	set miny ""
	set minz ""
	set maxx ""
	set maxy ""
	set maxz ""
	foreach pointdata $toolpath {
		foreach {x y z type tool_width} $pointdata break
		if {$minx == "" || $minx > $x} {
			set minx $x
		}
		if {$miny == "" || $miny > $y} {
			set miny $y
		}
		if {$minz == "" || $minz > $z} {
			set minz $z
		}
		if {$maxx == "" || $maxx < $x} {
			set maxx $x
		}
		if {$maxy == "" || $maxy < $y} {
			set maxy $y
		}
		if {$maxz == "" || $maxz < $z} {
			set maxz $z
		}
	}
	if {$minx == ""} {
		error "No toolpath data found!"
	}

	if {abs($maxx-$minx) < 0.00001} {
		if {$maxy == $miny} {
			set maxx 1.0
		} else {
			set minx [expr {$minx-($maxy-$miny)/10.0}]
			set maxx [expr {$maxx+($maxy-$miny)/10.0}]
		}
	}
	if {abs($maxy-$miny) < 0.00001} {
		set miny [expr {$miny-($maxx-$minx)/10.0}]
		set maxy [expr {$maxy+($maxx-$minx)/10.0}]
	}

}


proc gcode_3view_win_create {needsprefs} {
	global gcodeInfo

	if {![info exists gcodeInfo(WINCOUNT)]} {
		set gcodeInfo(WINCOUNT) 0
		set gcodeInfo(WINNUM) 0
	}
	incr gcodeInfo(WINCOUNT)
	set winnum [incr gcodeInfo(WINNUM)]

	set base ".viewwin$winnum"

	gcode_gvars $base cammat minx maxx miny maxy minz maxz xsize ysize scalepcnt scaleval scales rendertime rot_dragging show_rapid_paths stereo oldstereo

	set scales [list 3 4 5 6 8 10 12 15 20 25 33 40 50 67 75 85 100 125 150 200 250 300 400 500 600 700 800 1000 1200 1400 1600]

	set xsize 640
	set ysize 640
	set rendertime 1.0

	gcode_gvars $base vector_ax0 vector_ay0 vector_az0 vector_ax1 vector_ay1 vector_az1
	set vector_ax0 0.0
	set vector_ay0 0.0
	set vector_az0 0.0
	set vector_ax1 1.0
	set vector_ay1 0.0
	set vector_az1 0.0

	gcode_gvars $base vector_bx0 vector_by0 vector_bz0 vector_bx1 vector_by1 vector_bz1
	set vector_bx0 0.0
	set vector_by0 0.0
	set vector_bz0 0.0
	set vector_bx1 0.0
	set vector_by1 1.0
	set vector_bz1 0.0

	gcode_gvars $base vector_cx0 vector_cy0 vector_cz0 vector_cx1 vector_cy1 vector_cz1
	set vector_cx0 0.0
	set vector_cy0 0.0
	set vector_cz0 0.0
	set vector_cx1 0.0
	set vector_cy1 0.0
	set vector_cz1 1.0

	toplevel $base -menu $base.menu
	wm protocol $base WM_DELETE_WINDOW "exit"
	wm title $base "G-Code Backtracer"

	set menubar [menu $base.menu -tearoff 0]
	set applemenu [menu $menubar.apple -tearoff 0]
	set filemenu  [menu $menubar.file -tearoff 0]
	set viewmenu  [menu $menubar.view -tearoff 0]
	set setmenu  [menu $menubar.settings -tearoff 0]
	$menubar add cascade -label "File" -menu $filemenu
	$menubar add cascade -label "View" -menu $viewmenu
	$menubar add cascade -label "Settings" -menu $setmenu
	$filemenu add command -label "Open" -underline 0 -accelerator "Command+O" -command [list gcode_filemenu_open $base]
	$filemenu add command -label "Close" -underline 0 -accelerator "Command+W" -command [list gcode_filemenu_close $base]
	$filemenu add command -label "Load Toolfile" -underline 0 -accelerator "Command+T" -command [list gcode_toolfile_open $base]
	$filemenu add command -label "Print" -underline 0 -accelerator "Command+P" -command [list gcode_print_3view $base]
	$setmenu add command -label "Modify A-Axis Offsets..." -underline 7 -accelerator "Command+Shift+A" -command [list gcode_axis_offsets_dlog $base "a"]
	$setmenu add command -label "Modify B-Axis Offsets..." -underline 7 -accelerator "Command+Shift+B" -command [list gcode_axis_offsets_dlog $base "b"]
	$setmenu add command -label "Modify C-Axis Offsets..." -underline 7 -accelerator "Command+Shift+C" -command [list gcode_axis_offsets_dlog $base "c"]
	set stereovar "g$base-stereo"
	$viewmenu add radiobutton -label "Normal"            -underline 0 -value 0 -variable $stereovar -command [list gcode_set_stereomode $base 0]
	$viewmenu add radiobutton -label "Red-Blue Stereo"   -underline 0 -value 1 -variable $stereovar -command [list gcode_set_stereomode $base 1]
	$viewmenu add radiobutton -label "Convergent Stereo" -underline 0 -value 2 -variable $stereovar -command [list gcode_set_stereomode $base 2]
	$viewmenu add radiobutton -label "Divergent Stereo"  -underline 0 -value 3 -variable $stereovar -command [list gcode_set_stereomode $base 3]
	if {$needsprefs} {
		$filemenu add command -label "Preferences..." -command gcode_prefs_dlog
	}

	set fixedfont TkFixedFont
	if {[lsearch -exact [font names] $fixedfont] == -1} {
		set fixedfont {Courier 10}
	}
	set panes [::ttk::panedwindow $base.pw -orient horizontal]
	$panes add [set fr1 [frame $panes.p1]] -weight 2
	$panes add [set fr2 [frame $panes.p2]] -weight 1

	set canvcmd canvas
	if {[namespace exists ::tkp]} {
		set canvcmd ::tkp::canvas
	}
	set isocanv [$canvcmd $fr1.isocanv -width $ysize -height $ysize -highlightthickness 0 -borderwidth 1 -relief sunken -xscrollcommand "$fr1.isocanv delete Help; $fr1.isohscr set" -yscrollcommand "$fr1.isocanv delete Help; $fr1.isovscr set"]
	set scallbl [label $fr1.scallbl -text "100%" -width 6 -justify left -font TkSmallCaptionFont]
	set sterlbl [label $fr1.sterlbl -text "Normal" -width 10 -justify left -font TkSmallCaptionFont]
	set isohscr [scrollbar $fr1.isohscr -orient horizontal -command [list $isocanv xview]]
	set isovscr [scrollbar $fr1.isovscr -orient vertical -command [list $isocanv yview]]

	set esttime [label $fr2.esttime -text "Est. Time:" -justify left -font TkSmallCaptionFont]
	set gcodelb [listbox $fr2.gcodelb -width 35 -selectmode single -font $fixedfont -xscrollcommand [list $fr2.gcodehs set] -yscrollcommand [list $fr2.gcodevs set]]
	set gcodehs [scrollbar $fr2.gcodehs -orient horizontal -command [list $gcodelb xview]]
	set gcodevs [scrollbar $fr2.gcodevs -orient vertical -command [list $gcodelb yview]]


	grid columnconfigure $fr1 2 -weight 1
	grid rowconfigure $fr1 0 -weight 1
	grid $isocanv -        -       $isovscr
	grid $scallbl $sterlbl $isohscr x       
	grid $isocanv -sticky nsew
	grid $isovscr -sticky nsw
	grid $scallbl $sterlbl -sticky w
	grid $isohscr -sticky new

	grid columnconfigure $fr2 0 -weight 1
	grid rowconfigure $fr2 1 -weight 1
	grid $esttime x
	grid $gcodelb $gcodevs
	grid $gcodehs x        
	grid $esttime -sticky nw
	grid $gcodelb -sticky nsew
	grid $gcodevs -sticky nsw
	grid $gcodehs -sticky new

	pack $panes -fill both -expand 1

	set pi 3.141592653589793236
	set scalepcnt 100
	set stereo 0
	set oldstereo 0

	set cammat [list \
		[list 1.0 0.0 0.0 0.0]  \
		[list 0.0 1.0 0.0 0.0]  \
		[list 0.0 0.0 1.0 0.0]  \
		[list 0.0 0.0 0.0 1.0]  \
	]

	set mvx [expr {$ysize/2.0}]
	set rot_dragging 0
	set show_rapid_paths 1

	bind $gcodelb <ButtonRelease-1>    [list after 10 gcode_select_line $base]
	bind $gcodelb <Key-Up>             "gcode_3d_playback_pause $base ; gcode_3d_hilite_prev_line $base 1 ; break"
	bind $gcodelb <Key-Down>           "gcode_3d_playback_pause $base ; gcode_3d_hilite_next_line $base 1 ; break"
	bind $gcodelb <Key-Prior>          "gcode_3d_playback_pause $base ; gcode_3d_hilite_prev_line $base 25 0 ; break"
	bind $gcodelb <Key-Next>           "gcode_3d_playback_pause $base ; gcode_3d_hilite_next_line $base 25 0 ; break"
	bind $gcodelb <Key-Home>           "gcode_3d_playback_pause $base ; gcode_select_line $base 0 ; break"
	bind $gcodelb <Key-End>            "gcode_3d_playback_pause $base ; gcode_select_line $base 99999999 ; break"

	bind $isocanv <ButtonPress-1>      [list gcode_3d_rot_start $base %x %y]
	bind $isocanv <Motion>             [list gcode_3d_rot_drag $base %x %y]
	bind $isocanv <ButtonRelease-1>    [list gcode_3d_rot_end $base %x %y]
	if {[catch {
		bind $isocanv <Command-Shift-MouseWheel> break
		bind $isocanv <Command-MouseWheel> [list gcode_3d_scaling_change $base %D %x %y]
	} err]} {
		bind $isocanv <Control-Shift-MouseWheel> break
		bind $isocanv <Control-MouseWheel> [list gcode_3d_scaling_change $base %D %x %y]
	}
	bind $isocanv <Shift-MouseWheel>   [list gcode_3d_scroll_horiz $base %D]
	bind $isocanv <MouseWheel>         [list gcode_3d_scroll_vert $base %D]
	bind $isocanv <Double-1>           "gcode_3d_view_iso $base ; gcode_3d_view_scale_reset $base"

	bind $base <Key-1>  [list gcode_3d_view_top $base]
	bind $base <Key-2>  [list gcode_3d_view_front $base]
	bind $base <Key-3>  [list gcode_3d_view_side $base]
	bind $base <Key-4>  [list gcode_3d_view_iso $base]
	bind $base <Key-5>  [list gcode_3d_view_iso2 $base]
	bind $base <Key-6>  [list gcode_3d_view_iso3 $base]
	bind $base <Key-7>  [list gcode_3d_view_iso4 $base]
	bind $base <Key-8>  [list gcode_3d_view_iso5 $base]
	bind $base <Key-9>  [list gcode_3d_view_iso6 $base]
	bind $base <Key-0>  [list gcode_3d_view_scale_reset $base]

	bind $base <Key-w>  [list gcode_3d_rotate_by $base -5.0  0.0  0.0]
	bind $base <Key-s>  [list gcode_3d_rotate_by $base  5.0  0.0  0.0]
	bind $base <Key-a>  [list gcode_3d_rotate_by $base  0.0 -5.0  0.0]
	bind $base <Key-d>  [list gcode_3d_rotate_by $base  0.0  5.0  0.0]
	bind $base <Key-q>  [list gcode_3d_rotate_by $base  0.0  0.0  5.0]
	bind $base <Key-e>  [list gcode_3d_rotate_by $base  0.0  0.0 -5.0]
	bind $base <Key-r>  [list gcode_toggle_rapids $base]
	bind $base <Key-m>  [list gcode_advance_stereomode $base]
	bind $sterlbl <ButtonPress-1> [list gcode_advance_stereomode $base]
	bind $sterlbl <Enter> [list $sterlbl configure -background #aaa]
	bind $sterlbl <Leave> [list $sterlbl configure -background [$sterlbl cget -background]]

	bind $base <Key-h>  [list show_help $isocanv]
	bind $base <Key-?>  [list show_help $isocanv]

	bind $base <Key-equal> [list gcode_3d_scaling_change $base  1 $mvx $mvx]
	bind $base <Key-minus> [list gcode_3d_scaling_change $base -1 $mvx $mvx]

	if {[catch {
		bind $base <Command-Key-equal> [list gcode_3d_scaling_change $base  1 $mvx $mvx]
		bind $base <Command-Key-minus> [list gcode_3d_scaling_change $base -1 $mvx $mvx]
		bind $base <Command-Key-Up>    [list gcode_3d_scaling_change $base  1 $mvx $mvx]
		bind $base <Command-Key-Down>  [list gcode_3d_scaling_change $base -1 $mvx $mvx]
		bind $base <Command-o>         [list $filemenu invoke "Open"]
		bind $base <Command-w>         [list $filemenu invoke "Close"]
		bind $base <Command-t>         [list $filemenu invoke "Toolfile"]
		bind $base <Command-p>         [list $filemenu invoke "Print"]
		bind $base <Shift-Command-A>   [list $setmenu  invoke "Modify A-Axis Offsets..."]
		bind $base <Shift-Command-B>   [list $setmenu  invoke "Modify B-Axis Offsets..."]
		bind $base <Shift-Command-C>   [list $setmenu  invoke "Modify C-Axis Offsets..."]
		bind $base <Command-q>         exit
	} err]} {
		bind $base <Control-Key-equal> [list gcode_3d_scaling_change $base  1 $mvx $mvx]
		bind $base <Control-Key-minus> [list gcode_3d_scaling_change $base -1 $mvx $mvx]
		bind $base <Control-Key-Up>    [list gcode_3d_scaling_change $base  1 $mvx $mvx]
		bind $base <Control-Key-Down>  [list gcode_3d_scaling_change $base -1 $mvx $mvx]
		bind $base <Control-o>         [list $filemenu invoke "Open"]
		bind $base <Control-w>         [list $filemenu invoke "Close"]
		bind $base <Control-t>         [list $filemenu invoke "Toolfile"]
		bind $base <Control-p>         [list $filemenu invoke "Print"]
		bind $base <Shift-Control-A>   [list $setmenu  invoke "Modify A-Axis Offsets..."]
		bind $base <Shift-Control-B>   [list $setmenu  invoke "Modify B-Axis Offsets..."]
		bind $base <Shift-Control-C>   [list $setmenu  invoke "Modify C-Axis Offsets..."]
		bind $base <Alt-F4>            exit
	}
	bind $base <Key-comma>   "gcode_3d_playback_pause $base ; gcode_3d_hilite_prev_line $base 1"
	bind $base <Key-period>  "gcode_3d_playback_pause $base ; gcode_3d_hilite_next_line $base 1"
	bind $base <Key-less>    "gcode_3d_playback_pause $base ; gcode_3d_hilite_prev_line $base 10"
	bind $base <Key-greater> "gcode_3d_playback_pause $base ; gcode_3d_hilite_next_line $base 10"
	bind $base <Key-p>       "gcode_3d_playback_toggle $base"
	bind $base <Key-space>   "gcode_3d_playback_toggle $base"

	focus $gcodelb

	return $base
}


proc progress_create {win title caption} {
	toplevel $win
	wm resizable $win 0 0
	wm title $win $title
	label $win.caption -text $caption
	set canv [canvas $win.progbar -borderwidth 1 -relief solid -width 200 -height 20 -scrollregion {0 0 200 20}]
	$canv create rectangle 0 0 0 20 -width 0 -fill blue4 -tags progbar
	pack $win.caption -side top -anchor w
	pack $win.progbar -side top
	update idletasks
	raise $win
	return $win
}


proc progress_callback {win maxval currval} {
	global lastprogupdate
	if {![info exists lastprogupdate]} {
		set lastprogupdate 0
	}
	set now [clock clicks -milliseconds]
	if {$now>$lastprogupdate+250} {
		set width [expr {int(round(200.0*$currval/$maxval))}]
		$win.progbar coords progbar 0 0 $width 20
		set lastprogupdate $now
		update
	}
}


proc progress_destroy {win} {
	if {[winfo exists $win]} {
		destroy $win
	}
}


proc gcode_load_and_show {file basewin} {
	gcode_gvars $basewin toolpath rendertime segment_number minx maxx miny maxy minz maxz build_time
	set segment_number 0

	set toolpath {}

	set progwin [progress_create .progress "Backtracer progress" "Parsing..."]
	gcode_file_parse $basewin $file "progress_callback $progwin" $basewin.pw.p2.gcodelb
	progress_destroy $progwin

	gcode_3d_view_top $basewin
	gcode_3d_view_scale_reset $basewin

	set stime [clock clicks -milliseconds]
	if {[catch {
		gcode_3d_plot $basewin
	} err]} {
		global errorInfo
		puts stderr $errorInfo
	}
	set rendertime [expr {([clock clicks -milliseconds]-$stime)/1000.0}]

	gcode_3d_color_segment $basewin 0 #f77

	$basewin.pw.p2.esttime configure -text "Est. Time: [format_elapsed_time $build_time]"
	set isocanv $basewin.pw.p1.isocanv
	show_help $isocanv
	after 1000 show_help $isocanv

	update
}


proc gcode_filemenu_close {base} {
	global gcodeInfo
	destroy $base
	gcode_gvars_clear_all $base
	set wincount [incr gcodeInfo(WINCOUNT) -1]
	if {$wincount <= 0} {
		exit
	}
}


proc gcode_filemenu_open {base} {
	global tcl_platform
	set filetypes {
		{{NC Files}       {.nc}    TEXT}
		{{Any Files}      {*}      TEXT}
	}
	if {$tcl_platform(os) == "Darwin"} {
		set file [tk_getOpenFile -defaultextension .nc -filetypes $filetypes \
			-message "Select an NC file to open." -title "Open file" \
			-parent $base]
	} else {
		set file [tk_getOpenFile -defaultextension .nc -filetypes $filetypes \
			-title "Open file" -parent $base]
	}
	if {$file != ""} {
		global gcodeInfo
		set base [gcode_3view_win_create $gcodeInfo(NEEDS_PREFS)]
		gcode_load_and_show $file $base
	}
}


proc gcode_axis_offsets_commit {mainwin base rotaxis} {
	gcode_gvars $mainwin filename
	for {set i 0} {$i <= 1} {incr i} {
		foreach ax {x y z} {
			set v "vector_$rotaxis$ax$i"
			gcode_gvars $mainwin $v
			upvar 0 $v "vector_$ax$i"
		}
	}
	set pi 3.141592653589793236

	set afr $base.afr
	set xoff [$afr.xoff get]
	set yoff [$afr.yoff get]
	set zoff [$afr.zoff get]
	set xyang [$afr.xyang get]
	set tilt [$afr.tilt get]
	if {![string is double $xoff]} {
		tk_messageBox -type ok -icon error -message "X offset isn't a valid number." -parent $base
		return
	}
	if {![string is double $yoff]} {
		tk_messageBox -type ok -icon error -message "Y offset isn't a valid number." -parent $base
		return
	}
	if {![string is double $zoff]} {
		tk_messageBox -type ok -icon error -message "Z offset isn't a valid number." -parent $base
		return
	}
	if {![string is double $xyang]} {
		tk_messageBox -type ok -icon error -message "Orientation angle isn't a valid number." -parent $base
		return
	}
	if {![string is double $tilt]} {
		tk_messageBox -type ok -icon error -message "Tilt angle isn't a valid number." -parent $base
		return
	}

	set xyang [expr {$xyang*$pi/180.0}]
	set tilt [expr {$tilt*$pi/180.0}]

	set vector_x0 $xoff
	set vector_y0 $yoff
	set vector_z0 $zoff

	set vector_x1 [expr {cos($xyang)*cos($tilt)+$vector_x0}]
	set vector_y1 [expr {sin($xyang)*cos($tilt)+$vector_y0}]
	set vector_z1 [expr {sin($tilt)+$vector_z0}]

	if {[info exists filename]} {
		if {[file readable $filename]} {
			gcode_load_and_show $filename $mainwin
		}
	}
	destroy $base
}


proc gcode_axis_offsets_dlog {mainwin axis} {
	if {[catch {gcode_axis_offsets_dlog2 $mainwin $axis} err]} {
		global errorInfo
		puts stderr $errorInfo
	}
}


proc gcode_axis_offsets_dlog2 {mainwin rotaxis} {
	set base ".prefs"

	for {set i 0} {$i <= 1} {incr i} {
		foreach ax {x y z} {
			set v "vector_$rotaxis$ax$i"
			gcode_gvars $mainwin $v
			upvar 0 $v "vector_$ax$i"
		}
	}
	set pi 3.141592653589793236

	toplevel $base
	set axcap [string toupper $rotaxis]
	wm title $base "$axcap-Axis Settings"
	set afr [labelframe $base.afr -text "$axcap-Axis"]

	label $afr.xoffl -text "X offset"
	entry $afr.xoff  -width 20
	label $afr.yoffl -text "Y offset"
	entry $afr.yoff  -width 20
	label $afr.zoffl -text "Z offset"
	entry $afr.zoff  -width 20
	label $afr.xyangl -text "Orientation angle"
	entry $afr.xyang  -width 20
	label $afr.tiltl -text "Tilt angle"
	entry $afr.tilt  -width 20

	grid columnconfigure $afr 0 -minsize 10
	grid columnconfigure $afr 2 -minsize 5
	grid columnconfigure $afr 3 -weight 1
	grid columnconfigure $afr 4 -minsize 10
	grid rowconfigure $afr 0 -minsize 10
	grid rowconfigure $afr 2 -minsize 10
	grid rowconfigure $afr 4 -minsize 10
	grid rowconfigure $afr 6 -minsize 10
	grid rowconfigure $afr 8 -minsize 10
	grid rowconfigure $afr 10 -minsize 10 -weight 1
	grid x $afr.xoffl  x $afr.xoff  x -row 1 -sticky ew
	grid x $afr.yoffl  x $afr.yoff  x -row 3 -sticky ew
	grid x $afr.zoffl  x $afr.zoff  x -row 5 -sticky ew
	grid x $afr.xyangl x $afr.xyang x -row 7 -sticky ew
	grid x $afr.tiltl  x $afr.tilt  x -row 9 -sticky ew

	$afr.xoff insert end [format "%.4f" $vector_x0]
	$afr.yoff insert end [format "%.4f" $vector_y0]
	$afr.zoff insert end [format "%.4f" $vector_z0]
	set xyang [expr {atan2($vector_y1-$vector_y0,$vector_x1-$vector_x0)*180.0/$pi}]
	if {$xyang < 0.0} {
		set xyang [expr {$xyang+360.0}]
	}
	set xyang [format "%.2f" $xyang]
	$afr.xyang insert end $xyang
	set tilt [expr {asin($vector_z1-$vector_z0)*180.0/$pi}]
	set tilt [format "%.2f" $tilt]
	$afr.tilt insert end $tilt

	button $base.cancel -text "Cancel" -width 6 -command "destroy $base"
	button $base.done -text "Done" -width 6 -command "gcode_axis_offsets_commit $mainwin $base $rotaxis"

	pack $afr -fill both -expand 1 -padx 10 -pady 10 -side top
	pack $base.cancel -padx 10 -pady 10 -side left
	pack $base.done -padx 10 -pady 10 -side left
	tkwait window $base
}



proc gcode_prefs_dlog {} {
	# Nothing to do, yet.
}

proc show_help {canv} {
	set data {
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
Ow==
}
	set img [image create photo helpkeys -data $data]
	set x [$canv canvasx 0]
	set y [$canv canvasy 0]
	$canv delete Help
	set obj [$canv create image $x $y -image $img -anchor nw -tags Help]
	$canv bind $obj <1> "$canv delete Help"
}


proc main {argc argv} {
	catch {set ::tk::mac::useCGDrawing 1}
	catch {set ::tk::mac::CGAntialiasLimit 0}
	global tcl_platform gcodeInfo
	set gcodeInfo(NEEDS_PREFS) 0
	if {$gcodeInfo(NEEDS_PREFS)} {
		catch {
			if {[tk windowingsystem] == "aqua"} {
				set gcodeInfo(NEEDS_PREFS) 0
				namespace eval ::tk::mac {
					proc ShowPreferences {} {
						gcode_prefs_dlog
					}
				}
			}
		}
	}
	gcode_tools_load "toolfile.txt"

	wm withdraw .
	if {$argc == 1} {
		set file [lindex $argv 0]
		set basewin [gcode_3view_win_create $gcodeInfo(NEEDS_PREFS)]
		gcode_load_and_show $file $basewin
	} else {
		gcode_filemenu_open .
	}
}

main $argc $argv

# vim: set ts=4 sw=4 nowrap noexpandtab: settings
