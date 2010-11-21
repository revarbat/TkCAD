package require mlcnc_critcl
package require tkpath
package require math::constants

::math::constants::constants pi

set path {}
set wraps 4.0
set slice [expr {$pi*$wraps*2.0/25}]
set exprate [expr {45.0/($wraps*$pi*2.0)}]
for {set i 0} {$i < $wraps*2.0*$pi} {set i [expr {$i+$slice}]} {
    lappend path [expr {int(50.5+cos($i)*$i*$exprate)}] [expr {int(50.5+sin($i)*$i*$exprate)}]
}
lappend path [lindex $path 0] [lindex $path 1]
#set path [list 10.0 10.0  20.0 10.0  30.0 20.0  40.0 10.0   50.0 10.0  50.0 30.0  10.0 30.0]

set c [::tkp::canvas .c]
pack $c

set img [image create photo -height 100 -width 100]
set s [clock microseconds]
for {set x 0.0} {$x < 100.0} {set x [expr {$x+1.0}]} {
    for {set y 0.0} {$y < 100.0} {set y [expr {$y+1.0}]} {
	if {[mlcnc_path_circumscribes_point $path $x $y]} {
	    set dist [mlcnc_path_min_dist_from_point $path $x $y]
	    if {$dist>7.5} {
		set dist 7.5
	    }
	    set val [expr {15-int(2.0*$dist+0.5)}]
	    set color [format "#%01x%01x%01x" $val $val $val]
	} else {
	    set color blue
	}
	$img put $color -to [expr {int($x)}] [expr {int($y)}]
    }
}
set e [clock microseconds]
puts stderr "[expr {($e-$s)/10000}]us per iteration"
$c create image 0 0 -image $img -anchor nw
#set obj [$c create line $path]

if 0 {
set tline {5.0 10.0 55.0 20.0}
set res [mlcnc_path_find_line_segment_intersections $path {*}$tline]
puts stderr "res='$res'"
$c create pline $tline -stroke green
}

