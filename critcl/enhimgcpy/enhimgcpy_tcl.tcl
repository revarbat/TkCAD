
package require opt

tcl::OptProc image_copy_to_size {
    {src     {}         "Source image."}
    {targ    {}         "Target image."}
    {xsize   100        "Maximum width of the resulting image."}
    {ysize   100        "Maximum height of the resulting image."}
    {-blur   0.0        "Blur radius."}
    {-rotate 0.0        "Degrees of rotation"}
    {-filter -choice {Mitchell Lanczos BlackmanSinc ""} "The filter to use to interpolate pixels for scaling and rotation."}
} {
    set ow [image width $src]
    set oh [image height $src]
    set pi 3.141592653589793236
    set rotrad [expr {$rotate*$pi/180.0}]
    set minx 0
    set maxx 0
    set miny 0
    set maxy 0
    foreach {x y} [list 0 0  $ow 0  0 $oh  $ow $oh] {
	set xs [expr {int($x*cos($rotrad)-$y*sin($rotrad))}]
	set ys [expr {int($x*sin($rotrad)+$y*cos($rotrad))}]
	if {$xs < $minx} {set minx $xs}
	if {$xs > $maxx} {set maxx $xs}
	if {$ys < $miny} {set miny $ys}
	if {$ys > $maxy} {set maxy $ys}
    }
    set nxsize [expr {$maxx-$minx}]
    set nysize [expr {$maxy-$miny}]
    set sx [expr {($xsize+0.0)/$nxsize}]
    set sy [expr {($ysize+0.0)/$nysize}]
    if {$sx > $sy} {
	set sx $sy
    } else {
	set sy $sx
    }
    set xsize [expr {int($nxsize*$sx)}]
    set ysize [expr {int($nysize*$sy)}]
    $targ configure -width $xsize -height $ysize
    set rotate [expr {-$rotate}]
    image_copy $src $targ -scale $sx $sy -blur $blur -filter $filter -shrink -rotate $rotate
}


