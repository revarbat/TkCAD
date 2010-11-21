#########################################################################
# Screw tap and hole commands
#########################################################################

proc mlcnc_screw_size {size} {
    if {[regexp {^#([0-9][0-9]*)$} $size dummy screwnum]} {
        return [expr {$screwnum*0.013+0.06}]
    }
    if {[string first "/" $size] != -1} {
        foreach {denominator divisor} [split $size "/"] break
        set denominator [expr {$denominator+0.0}]
        set divisor [expr {$divisor+0.0}]
        return [expr {$denominator/$divisor}]
    }
    if {[regexp {^M([1-9][.0-9]*)$} $size dummy mm]} {
        return [expr {$mm/25.4}]
    }
    if {[catch {
        set size [expr {0.0+$size}]
    }]} {
        return ""
    }
    return $size
}



global mlcnc_standard_nut_sizes
set mlcnc_standard_nut_sizes {
    "#2"    { 6/32in   0.065in}
    "#3"    { 6/32in   0.073in}
    "#4"    { 8/32in   0.089in}
    "#6"    {10/32in   0.112in}
    "#8"    {11/32in   0.120in}
    "#10"   {12/32in   0.122in}
    "#12"   {13/32in   0.171in}
    "1/4"   {14/32in   0.220in}
    "5/16"  {16/32in   0.270in}
    "3/8"   {18/32in   0.321in}
    "7/16"  {22/32in   0.364in}
    "1/2"   {24/32in   0.416in}
    "M3"    {  5.5mm   2.4mm  }
    "M4"    {  7.0mm   3.2mm  }
    "M5"    {  8.0mm   4.0mm  }
    "M6"    { 10.0mm   5.0mm  }
    "M8"    { 13.0mm   6.5mm  }
    "M10"   { 17.0mm   8.0mm  }
    "M12"   { 19.0mm  10.0mm  }
    "M16"   { 24.0mm  13.0mm  }
    "M20"   { 30.0mm  16.0mm  }
    "M24"   { 36.0mm  19.0mm  }
    "M30"   { 46.0mm  24.0mm  }
    "M36"   { 55.0mm  29.0mm  }
}



proc mlcnc_get_standard_nut_sizes {} {
    global mlcnc_standard_nut_sizes
    set out {}
    foreach {size dummy} $mlcnc_standard_nut_sizes {
        lappend out $size $size
    }
    return $out
}



proc mlcnc_get_standard_nut_width {size} {
    global mlcnc_standard_nut_sizes
    array set sizes $mlcnc_standard_nut_sizes
    if {![info exists sizes($size)]} {
        return ""
    }
    set val [lindex $sizes($size) 0]
    return [util_number_value $val "in"]
}



proc mlcnc_get_standard_nut_height {size} {
    global mlcnc_standard_nut_sizes
    array set sizes $mlcnc_standard_nut_sizes
    if {![info exists sizes($size)]} {
        return ""
    }
    set val [lindex $sizes($size) 1]
    return [util_number_value $val "in"]
}



proc mlcnc_screw_hole_size {size {fit "close"}} {
    if {$fit != "exact" && $fit != "close" && $fit != "loose"} {
        error "Fit must be either 'close' or 'loose'."
    }
    set screwdiam [mlcnc_screw_size $size]
    if {$screwdiam == ""} {
        error "Unknown screw size $size"
    }
    if {$screwdiam >= 7.0/16.0} {
        if {$fit == "loose"} {
            set slop [expr {1.0/32.0}]
        } elseif {$fit == "close"} {
            set slop [expr {1.0/64.0}]
        } else {
            set slop 0.0
        }
        set holediam [expr {$screwdiam+$slop}]
    } else {
        if {$fit == "loose"} {
            set slop 1.10
        } elseif {$fit == "close"} {
            set slop 1.04
        } else {
            set slop 1.00
        }
        set holediam [expr {$screwdiam*$slop}]
    }
    return $holediam
}





proc mlcnc_screw_pitch_list {} {
    set pitches {
         #0    80    80
         #1    64    72
         #2    56    64
         #3    48    56
         #4    40    48
         #5    40    44
         #6    32    40
         #8    32    36
        #10    24    32
        #12    24    28
        1/4    20    28
       5/16    18    24
        3/8    16    24
       7/16    14    20
        1/2    13    20
       9/16    12    18
        5/8    11    18
        3/4    10    16
        7/8     9    14
          1     8    12
         M1  0.25  0.25
       M1.2  0.25  0.25
       M1.4   0.3   0.3
       M1.6  0.35  0.35
       M1.8  0.35  0.35
         M2   0.4   0.4
       M2.5  0.45  0.45
         M3   0.5   0.5
       M3.5   0.6   0.6
         M4   0.7   0.7
         M5   0.8   0.8
         M6   1.0   1.0
         M7   1.0   1.0
         M8  1.25   1.0
        M10   1.5   1.0
        M12  1.75  1.25
        M14   2.0   1.5
        M16   2.0   1.5
        M18   2.5   1.5
        M20   2.5   1.5
        M22   2.5   1.5
        M24   3.0   2.0
        M27   3.0   2.0
        M30   3.5   2.0
        M33   3.5   2.0
        M36   4.0   3.0
        M39   4.0   3.0
        M42   4.5   3.0
        M45   4.5   3.0
        M48   5.0   3.0
        M52   5.0   4.0
        M56   5.5   4.0
        M60   5.5   4.0
        M64   6.0   4.0
    }
    return $pitches
}


proc mlcnc_screw_size_list {} {
    set out {}
    foreach {ssiz crs fin}  [mlcnc_screw_pitch_list] {
        lappend out $ssiz
    }
    return $out
}


proc mlcnc_screw_tap_size {size pitch} {
    set screwdiam [mlcnc_screw_size $size]
    if {$screwdiam == ""} {
        return ""
    }
    set pitches [mlcnc_screw_pitch_list]

    set pfound 0
    foreach {ssiz coarse fine} $pitches {
        set sdiam [mlcnc_screw_size $ssiz]
        if {abs($screwdiam-$sdiam) < 1e-6} {
            set pfound 1
            if {$pitch == "coarse"} {
                set pitch $coarse
            } else {
                set pitch $fine
            }
            break
        }
    }
    if {!$pfound} {
        return ""
    }
    if {[string match "M*" $size]} {
        set tapdiam [expr {$screwdiam-(1.082532*0.75*$pitch/25.4)}]
    } else {
        set tapdiam [expr {$screwdiam-(1.299*0.75/$pitch)}]
    }
    return $tapdiam
}


proc mlcnc_g_screw_tap {x y z size pitch} {
    set tapdiam [mlcnc_screw_tap_size $size $pitch]
    if {$tapdiam == ""} {
        error "Unknown screw size $size"
    }
    set taprad [expr {$tapdiam/2.0}]
    return [mlcnc_g_circle $x $y $z $taprad $taprad]
}



proc mlcnc_g_screw_hole {x y z size {fit "close"}} {
    set holediam [mlcnc_screw_hole_size $size $fit]
    set holerad [expr {$holediam/2.0}]
    return [mlcnc_g_circle $x $y $z $holerad $holerad]
}



proc mlcnc_g_screw_tap_ring {x y z radius count startang size pitch} {
    constants pi
    set ang [expr {$startang*$pi/180.0}]
    set stepang [expr {(2.0*$pi)/$count}]
    set out {}
    for {set i 0} {$i < $count} {incr i} {
        set hx [expr {$radius*cos($ang)+$x}]
        set hy [expr {$radius*sin($ang)+$y}]
        append out [mlcnc_g_screw_tap $hx $hy $z $size $pitch]
        set ang [expr {$ang+$stepang}]
    }
    return $out
}



proc mlcnc_g_screw_hole_ring {x y z radius count startang size {fit "close"}} {
    constants pi
    set ang [expr {$startang*$pi/180.0}]
    set stepang [expr {(2.0*$pi)/$count}]
    set out {}
    for {set i 0} {$i < $count} {incr i} {
        set hx [expr {$radius*cos($ang)+$x}]
        set hy [expr {$radius*sin($ang)+$y}]
        append out [mlcnc_g_screw_hole $hx $hy $z $size $fit]
        set ang [expr {$ang+$stepang}]
    }
    return $out
}



proc mlcnc_g_screw_slot {x1 y1 x2 y2 z size {fit "close"}} {
    set holediam [mlcnc_screw_hole_size $size $fit]
    set holerad [expr {$holediam/2.0}]

    constants pi
    set ang1 [expr {fmod((atan2($y2-$y1,$x2-$x1)/$pi*180.0)+90.0,360.0)}]
    set ang2 [expr {fmod($ang1+180.0,360.0)}]

    # Calculate arc step size that keeps us within margin of error of true arc.
    # maxerr = radius * (sqrt(1+(sin(ang)^2)) - 1)
    # ang = asin(sqrt((maxerr/radius + 1)^2 - 1))
    set maxerr [expr {$holerad*0.005}]
    set endstep [expr {asin(sqrt(pow(($maxerr/$holerad)+1,2.0)-1))*180.0/$pi}]

    # Evenly distribute arc steps, for aesthetic reasons
    set endstep [expr {180.0/ceil(180.0/$endstep)}]

    set path {}
    mlcnc_append_arc_points path $x1 $y1 $holerad $ang1 180.0 $endstep
    mlcnc_append_arc_points path $x2 $y2 $holerad $ang2 180.0 $endstep
    lappend path [lindex $path 0] [lindex $path 1]

    return [mlcnc_g_path $path $z "right"]
}



proc mlcnc_g_screw_slot_arc {cx cy radius startang extent z size {fit "close"}} {
    set holediam [mlcnc_screw_hole_size $size $fit]
    set holerad [expr {$holediam/2.0}]

    constants pi
    set sang [expr {$startang*$pi/180.0}]
    set endang [expr {$startang+$extent}]
    set eang [expr {$sang+($extent*$pi/180.0)}]
    set x1 [expr {$cx+$radius*cos($sang)}]
    set y1 [expr {$cy+$radius*sin($sang)}]
    set x2 [expr {$cx+$radius*cos($eang)}]
    set y2 [expr {$cy+$radius*sin($eang)}]
    set irad [expr {$radius-$holerad}]
    set orad [expr {$radius+$holerad}]
    if {$extent >= 0.0} {
        set ang1 [expr {fmod($startang-180.0,360.0)}]
        set ang2 [expr {fmod($endang,360.0)}]
    } else {
        set ang1 [expr {fmod($startang,360.0)}]
        set ang2 [expr {fmod($endang+180.0,360.0)}]
    }
    set nextent [expr {-1.0*$extent}]

    # Calculate arc step size that keeps us within margin of error of true arc.
    # maxerr = radius * (sqrt(1+(sin(ang)^2)) - 1)
    # ang = asin(sqrt((maxerr/radius + 1)^2 - 1))
    set maxerr [expr {$holerad*0.005}]
    set arcstep [expr {asin(sqrt(pow(($maxerr/$orad)+1,2.0)-1))*180.0/$pi}]
    set endstep [expr {asin(sqrt(pow(($maxerr/$holerad)+1,2.0)-1))*180.0/$pi}]

    # Evenly distribute arc steps, for aesthetic reasons
    set arcstep [expr {$extent/ceil($extent/$arcstep)}]
    set endstep [expr {180.0/ceil(180.0/$endstep)}]

    set path {}
    mlcnc_append_arc_points path $x1 $y1 $holerad $ang1 180.0 $endstep
    mlcnc_append_arc_points path $cx $cy $orad $startang $extent $arcstep
    mlcnc_append_arc_points path $x2 $y2 $holerad $ang2 180.0 $endstep
    mlcnc_append_arc_points path $cx $cy $irad $endang $nextent $arcstep

    return [mlcnc_g_path $path $z "right"]
}


# vim: set ts=4 sw=4 nowrap expandtab: settings


