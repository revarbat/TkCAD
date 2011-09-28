global dxf_color_table
set dxf_color_table {
    #000000 #ff0000 #ffff00 #00ff00 #00ffff #0000ff #ff00ff #ffffff
    #414141 #808080 #ff0000 #ffaaaa #bd0000 #bd7e7e #810000 #815656
    #680000 #684545 #4f0000 #4f3535 #ff3f00 #ffbfaa #bd2e00 #bd8d7e
    #811f00 #816056 #681900 #684e45 #4f1300 #4f3b35 #ff7f00 #ffd4aa
    #bd5e00 #bd9d7e #814000 #816b56 #683400 #685645 #4f2700 #4f4235
    #ffbf00 #ffeaaa #bd8d00 #bdad7e #816000 #817656 #684e00 #685f45
    #4f3b00 #4f4935 #ffff00 #ffffaa #bdbd00 #bdbd7e #818100 #818156
    #686800 #686845 #4f4f00 #4f4f35 #bfff00 #eaffaa #8dbd00 #adbd7e
    #608100 #768156 #4e6800 #5f6845 #3b4f00 #494f35 #7fff00 #d4ffaa
    #5ebd00 #9dbd7e #408100 #6b8156 #346800 #566845 #274f00 #424f35
    #3fff00 #bfffaa #2ebd00 #8dbd7e #1f8100 #608156 #196800 #4e6845
    #134f00 #3b4f35 #00ff00 #aaffaa #00bd00 #7ebd7e #008100 #568156
    #006800 #456845 #004f00 #354f35 #00ff3f #aaffbf #00bd2e #7ebd8d
    #00811f #568160 #006819 #45684e #004f13 #354f3b #00ff7f #aaffd4
    #00bd5e #7ebd9d #008140 #56816b #006834 #456856 #004f27 #354f42
    #00ffbf #aaffea #00bd8d #7ebdad #008160 #568176 #00684e #45685f
    #004f3b #354f49 #00ffff #aaffff #00bdbd #7ebdbd #008181 #568181
    #006868 #456868 #004f4f #354f4f #00bfff #aaeaff #008dbd #7eadbd
    #006081 #567681 #004e68 #455f68 #003b4f #35494f #007fff #aad4ff
    #005ebd #7e9dbd #004081 #566b81 #003468 #455668 #00274f #35424f
    #003fff #aabfff #002ebd #7e8dbd #001f81 #566081 #001968 #454e68
    #00134f #353b4f #0000ff #aaaaff #0000bd #7e7ebd #000081 #565681
    #000068 #454568 #00004f #35354f #3f00ff #bfaaff #2e00bd #8d7ebd
    #1f0081 #605681 #190068 #4e4568 #13004f #3b354f #7f00ff #d4aaff
    #5e00bd #9d7ebd #400081 #6b5681 #340068 #564568 #27004f #42354f
    #bf00ff #eeaaff #8d00bd #ad7ebd #600081 #765681 #4e0068 #5f4568
    #3b004f #49354f #ff00ff #ffaaff #bd00bd #bd7ebd #810081 #815681
    #680068 #684568 #4f004f #4f354f #ff00bf #ffaaea #bd008d #bd7ead
    #810060 #815676 #68004e #68455f #4f003b #4f3549 #ff007f #ffaad4
    #bd005e #bd7e9d #810040 #81566b #680034 #684556 #4f0027 #4f3542
    #ff003f #ffaabf #bd002e #bd7e8d #81001f #815660 #680019 #68454e
    #4f0013 #4f353b #333333 #505050 #696969 #828282 #bebebe #ffffff
}



proc ffmt_plugin_save_dxf {win canv filename} {
    return [ffmt_plugin_writefile_dxf $win $canv $filename]
}



proc ffmt_plugin_open_dxf {win canv filename} {
    return [ffmt_plugin_readfile_dxf $win $canv $filename]
}




proc ffmt_plugin_init_dxf {} {
    fileformat_register READWRITE DXF "AutoCAD DXF R12" .dxf
}

ffmt_plugin_init_dxf 




####################################################################
# Private functions follow below.
# These are NOT part of the FileFormat Plugin API.
####################################################################

proc dxf_write_string {f typenum val} {
    puts -nonewline $f [format "%3d\r\n" $typenum]
    puts -nonewline $f [format "%s\r\n" $val]
}


proc dxf_write_int {f typenum val} {
    puts -nonewline $f [format "%3d\r\n" $typenum]
    puts -nonewline $f [format "%6d\r\n" $val]
}



proc dxf_write_float {f typenum val} {
    puts -nonewline $f [format "%3d\r\n" $typenum]
    puts -nonewline $f [format "%.12g\r\n" $val]
}


proc dxf_write_length {f typenum val} {
    set units [/prefs:get ruler_units]
    switch -exact -- $units {
        "Millimeters"        -
        "Centimeters"        -
        "Meters"             { set val [expr {$val*25.4}] }
    }
    dxf_write_float $f $typenum $val
}


proc dxf_write_color {f typenum val} {
    if {$val == ""} {
        set val #000
    }
    global dxf_color_table
    foreach {r1 g1 b1} [winfo rgb . $val] break
    set dist 999999
    set closest 0
    set cnum 0
    foreach color $dxf_color_table {
        foreach {r2 g2 b2} [winfo rgb . $color] break
        set dr [expr {abs($r1-$r2)}]
        set dg [expr {abs($g1-$g2)}]
        set db [expr {abs($b1-$b2)}]
        set cdist [expr {sqrt($dr*$dr + $dg*$dg + $db+$db)}]
        if {$cdist < $dist} {
            set dist $cdist
            set closest $cnum
        }
        incr cnum
    }
    dxf_write_int $f $typenum $closest
}


proc dxf_read_entry {f} {
    if {[eof $f]} {
        return [list -1 {}]
    }
    set line [gets $f]
    scan $line "%d" num
    if {![info exists num]} {
        return [list -1 {}]
    }
    set val [string trim [gets $f]]
    return [list $num $val]
}


proc dxf_seek_section {f sectname} {
    while {![eof $f]} {
        foreach {typenum val} [dxf_read_entry $f] break
        if {$typenum == 0 && $val == "SECTION"} {
            foreach {typenum val} [dxf_read_entry $f] break
            if {$typenum == 2 && $val == $sectname} {
                return 1
            }
        }
    }
    return 0
}


proc dxf_value {varname typenum def} {
    upvar $varname data
    if {![info exists data($typenum)]} {
        return $def
    }
    return $data($typenum)
}


proc ffmt_plugin_writeobj_dxf {win canv f objid objcountvar} {
    constants pi
    set type    [cadobjects_object_gettype $canv $objid]
    set layerid [cadobjects_object_getlayer $canv $objid]
    set coords  [cadobjects_object_get_coords $canv $objid]
    set layername [layer_name $canv $layerid]
    upvar $objcountvar objnum

    if {$type == "GROUP"} {
        set children [cadobjects_object_getdatum $canv $objid "CHILDREN"]
        foreach child $children {
            incr objnum
            ffmt_plugin_writeobj_dxf $win $canv $f $child objnum
        }
    } else {
        #set acceptabletypes {TEXT ROTTEXT ELLIPSE ELLIPSEROT CIRCLE RECTANGLE ROTRECT ARC ROTARC QUADBEZ BEZIER LINES POINTS}
        set acceptabletypes {CIRCLE RECTANGLE ROTRECT ARC LINES POINTS}
        foreach {dectype data} [cadobjects_object_decompose $canv $objid $acceptabletypes] {
            switch -exact -- $dectype {
                TEXT {
                    foreach {cx cy txt font just} $data break
                    set fheight [expr {[lindex $font 1]/72.0}]
                    dxf_write_string $f 0 "TEXT"
                    dxf_write_string $f 100 "AcDbEntity"
                    dxf_write_string $f 8 $layername
                    dxf_write_int $f 62 256
                    dxf_write_string $f 100 "AcDbText"
                    dxf_write_float $f 210 0.0
                    dxf_write_float $f 220 0.0
                    dxf_write_float $f 230 1.0
                    dxf_write_length $f 10 $cx
                    dxf_write_length $f 20 $cy
                    dxf_write_length $f 30 0.0
                    dxf_write_length $f 40 $fheight
                    dxf_write_string $f 1 $txt
                    dxf_write_string $f 7 STANDARD
                    switch -exact -- $just {
                        "left"   {
                            dxf_write_int $f 72 0
                        }
                        "center" {
                            dxf_write_int $f 72 1
                            dxf_write_length $f 11 $cx
                            dxf_write_length $f 21 $cy
                            dxf_write_length $f 31 0.0
                        }
                        "right"  {
                            dxf_write_int $f 72 2
                            dxf_write_length $f 11 $cx
                            dxf_write_length $f 21 $cy
                            dxf_write_length $f 31 0.0
                        }
                    }
                }
                ROTTEXT {
                    foreach {cx cy txt font just rot} $data break
                    set fheight [expr {[lindex $font 1]/72.0}]
                    dxf_write_string $f 0 "TEXT"
                    dxf_write_string $f 100 "AcDbEntity"
                    dxf_write_string $f 8 $layername
                    dxf_write_int $f 62 256
                    dxf_write_string $f 100 "AcDbText"
                    dxf_write_float $f 210 0.0
                    dxf_write_float $f 220 0.0
                    dxf_write_float $f 230 1.0
                    dxf_write_length $f 10 $cx
                    dxf_write_length $f 20 $cy
                    dxf_write_length $f 30 0.0
                    dxf_write_length $f 40 $fheight
                    dxf_write_string $f 1 $txt
                    dxf_write_float $f 50 $rot
                    dxf_write_string $f 7 STANDARD
                    switch -exact -- $just {
                        "left"   {
                            dxf_write_int $f 72 0
                        }
                        "center" {
                            dxf_write_int $f 72 1
                            dxf_write_length $f 11 $cx
                            dxf_write_length $f 21 $cy
                            dxf_write_length $f 31 0.0
                        }
                        "right"  {
                            dxf_write_int $f 72 2
                            dxf_write_length $f 11 $cx
                            dxf_write_length $f 21 $cy
                            dxf_write_length $f 31 0.0
                        }
                    }
                }
                ELLIPSE {
                    foreach {cx cy rad1 rad2} $data break
                    dxf_write_string $f 0 "ELLIPSE"
                    dxf_write_string $f 100 "AcDbEntity"
                    dxf_write_string $f 8 $layername
                    dxf_write_int $f 62 256
                    dxf_write_string $f 100 "AcDbEllipse"
                    dxf_write_float $f 210 0.0
                    dxf_write_float $f 220 0.0
                    dxf_write_float $f 230 1.0
                    dxf_write_length $f 10 $cx
                    dxf_write_length $f 20 $cy
                    dxf_write_length $f 30 0.0
                    dxf_write_length $f 11 [expr {$cx+$rad1}]
                    dxf_write_length $f 21 $cy
                    dxf_write_length $f 31 0.0
                    dxf_write_float $f 40 [expr {$rad2/$rad1}]
                    dxf_write_float $f 41 0.0
                    dxf_write_float $f 42 [expr {2.0*$pi}]
                }
                ELLIPSEROT {
                    foreach {cx cy rad1 rad2 rot} $data break
                    set rotr [expr {$rot*$pi/180.0}]
                    dxf_write_string $f 0 "ELLIPSE"
                    dxf_write_string $f 100 "AcDbEntity"
                    dxf_write_string $f 8 $layername
                    dxf_write_int $f 62 256
                    dxf_write_string $f 100 "AcDbEllipse"
                    dxf_write_float $f 210 0.0
                    dxf_write_float $f 220 0.0
                    dxf_write_float $f 230 1.0
                    dxf_write_length $f 10 $cx
                    dxf_write_length $f 20 $cy
                    dxf_write_length $f 30 0.0
                    dxf_write_length $f 11 [expr {$cx+cos($rotr)*$rad1}]
                    dxf_write_length $f 21 [expr {$cy+sin($rotr)*$rad2}]
                    dxf_write_length $f 31 0.0
                    dxf_write_float $f 40 [expr {$rad2/$rad1}]
                    dxf_write_float $f 41 0.0
                    dxf_write_float $f 42 [expr {2.0*$pi}]
                }
                CIRCLE {
                    foreach {cx cy rad1} $data break
                    dxf_write_string $f 0 "CIRCLE"
                    dxf_write_string $f 100 "AcDbEntity"
                    dxf_write_string $f 8 $layername
                    dxf_write_int $f 62 256
                    dxf_write_string $f 100 "AcDbCircle"
                    dxf_write_float $f 210 0.0
                    dxf_write_float $f 220 0.0
                    dxf_write_float $f 230 1.0
                    dxf_write_length $f 10 $cx
                    dxf_write_length $f 20 $cy
                    dxf_write_length $f 30 0.0
                    dxf_write_length $f 40 $rad1
                }
                RECTANGLE {
                    foreach {x0 y0 x1 y1} $data break
                    foreach {px0 py0 px1 py1} [list \
                        $x0 $y0 $x0 $y1 \
                        $x0 $y1 $x1 $y1 \
                        $x1 $y1 $x1 $y0 \
                        $x1 $y0 $x0 $y0 \
                    ] {
                        dxf_write_string $f 0 "LINE"
                        dxf_write_string $f 100 "AcDbEntity"
                        dxf_write_string $f 8 $layername
                        dxf_write_int $f 62 256
                        dxf_write_string $f 100 "AcDbLine"
                        dxf_write_float $f 210 0.0
                        dxf_write_float $f 220 0.0
                        dxf_write_float $f 230 1.0
                        dxf_write_length $f 10 $px0
                        dxf_write_length $f 20 $py0
                        dxf_write_length $f 30 0.0
                        dxf_write_length $f 11 $px1
                        dxf_write_length $f 21 $py1
                        dxf_write_length $f 31 0.0
                    }
                }
                ROTRECT {
                    foreach {cx cy hdx hdy rot} $data break
                    set rotr [expr {$rot*$pi/180.0}]
                    set cosv [expr {cos($rotr)*$hdx}]
                    set sinv [expr {sin($rotr)*$hdy}]
                    set x0 [expr {$cx+$cosv}]
                    set y0 [expr {$cy+$sinv}]
                    set x1 [expr {$cx+$cosv}]
                    set y1 [expr {$cy-$sinv}]
                    set x2 [expr {$cx-$cosv}]
                    set y2 [expr {$cy-$sinv}]
                    set x3 [expr {$cx-$cosv}]
                    set y3 [expr {$cy+$sinv}]
                    foreach {px0 py0 px1 py1} [list \
                        $x0 $y0 $x1 $y1 \
                        $x1 $y1 $x2 $y2 \
                        $x2 $y2 $x3 $y3 \
                        $x3 $y3 $x0 $y0 \
                    ] {
                        dxf_write_string $f 0 "LINE"
                        dxf_write_string $f 100 "AcDbEntity"
                        dxf_write_string $f 8 $layername
                        dxf_write_int $f 62 256
                        dxf_write_string $f 100 "AcDbLine"
                        dxf_write_float $f 210 0.0
                        dxf_write_float $f 220 0.0
                        dxf_write_float $f 230 1.0
                        dxf_write_length $f 10 $px0
                        dxf_write_length $f 20 $py0
                        dxf_write_length $f 30 0.0
                        dxf_write_length $f 11 $px1
                        dxf_write_length $f 21 $py1
                        dxf_write_length $f 31 0.0
                    }
                }
                ARC {
                    foreach {cx cy rad1 start extent} $data break
                    if {$extent < 0.0} {
                        set start [expr {$start+$extent}]
                        set extent [expr {abs($extent)}]
                    }
                    dxf_write_string $f 0 "ARC"
                    dxf_write_string $f 100 "AcDbEntity"
                    dxf_write_string $f 8 $layername
                    dxf_write_int $f 62 256
                    dxf_write_string $f 100 "AcDbCircle"
                    dxf_write_float $f 210 0.0
                    dxf_write_float $f 220 0.0
                    dxf_write_float $f 230 1.0
                    dxf_write_length $f 10 $cx
                    dxf_write_length $f 20 $cy
                    dxf_write_length $f 30 0.0
                    dxf_write_length $f 40 $rad1
                    dxf_write_string $f 100 "AcDbArc"
                    dxf_write_float $f 50 $start
                    dxf_write_float $f 51 [expr {$start+$extent}]
                }
                ROTARC {
                    foreach {cx cy rad1 rad2 start extent rot} $data break
                    set rotr [expr {$rot*$pi/180.0}]
                    if {$extent < 0.0} {
                        set start [expr {$start+$extent}]
                        set extent [expr {abs($extent)}]
                    }
                    if {abs($rad1-$rad2) < 1e-6} {
                        dxf_write_string $f 0 "ARC"
                        dxf_write_string $f 100 "AcDbEntity"
                        dxf_write_string $f 8 $layername
                        dxf_write_int $f 62 256
                        dxf_write_string $f 100 "AcDbCircle"
                        dxf_write_float $f 210 0.0
                        dxf_write_float $f 220 0.0
                        dxf_write_float $f 230 1.0
                        dxf_write_length $f 10 $cx
                        dxf_write_length $f 20 $cy
                        dxf_write_length $f 30 0.0
                        dxf_write_length $f 40 $rad1
                        dxf_write_string $f 100 "AcDbArc"
                        dxf_write_float $f 50 [expr {fmod($start+$rot,360.0)}]
                        dxf_write_float $f 51 [expr {fmod($start+$extent+$rot,360.0)}]
                    } else {
                        dxf_write_string $f 0 "ELLIPSE"
                        dxf_write_string $f 100 "AcDbEntity"
                        dxf_write_string $f 8 $layername
                        dxf_write_int $f 62 256
                        dxf_write_string $f 100 "AcDbEllipse"
                        dxf_write_float $f 210 0.0
                        dxf_write_float $f 220 0.0
                        dxf_write_float $f 230 1.0
                        dxf_write_length $f 10 $cx
                        dxf_write_length $f 20 $cy
                        dxf_write_length $f 30 0.0
                        dxf_write_length $f 11 [expr {$cx+cos($rotr)*$rad1}]
                        dxf_write_length $f 21 [expr {$cy+sin($rotr)*$rad2}]
                        dxf_write_length $f 31 0.0
                        dxf_write_float $f 40 [expr {$rad2/$rad1}]
                        dxf_write_float $f 41 $start
                        dxf_write_float $f 42 [expr {$start+$extent}]
                    }
                }
                QUADBEZ {
                    set cps [expr {[llength $data]/2}]
                    dxf_write_string $f 0 "SPLINE"
                    dxf_write_int $f 5 43
                    dxf_write_string $f 100 "AcDbEntity"
                    dxf_write_string $f 8 $layername
                    dxf_write_int $f 62 256
                    dxf_write_string $f 100 "AcDbSpline"
                    dxf_write_float $f 210 0.0
                    dxf_write_float $f 220 0.0
                    dxf_write_float $f 230 1.0
                    dxf_write_int $f 70 8
                    dxf_write_int $f 71 3
                    dxf_write_int $f 72 [expr {$cps+4}]
                    dxf_write_int $f 73 $cps
                    dxf_write_int $f 74 0
                    dxf_write_float $f 42 0.0000001
                    dxf_write_float $f 43 0.0000001
                    dxf_write_float $f 44 0.0000000001

                    dxf_write_float $f 40 0.0
                    for {set i 0} {$i <= ($cps-1)/3} {incr i 3} {
                        dxf_write_float $f 40 $i
                        dxf_write_float $f 40 $i
                        dxf_write_float $f 40 $i
                    }
                    dxf_write_float $f 40 [expr {($cps-1)/3}]

                    foreach {x0 y0} [lrange $data 0 1] break
                    dxf_write_length $f 10 $x0
                    dxf_write_length $f 20 $y0
                    dxf_write_length $f 30 0.0
                    foreach {cpx cpy x3 y3} [lrange $data 2 end] {
                        set x1 [expr {($x0+$cpx)/2.0}]
                        set y1 [expr {($y0+$cpy)/2.0}]
                        set x2 [expr {($x3+$cpx)/2.0}]
                        set y2 [expr {($y3+$cpy)/2.0}]
                        dxf_write_length $f 10 $x1
                        dxf_write_length $f 20 $y1
                        dxf_write_length $f 30 0.0
                        dxf_write_length $f 10 $x2
                        dxf_write_length $f 20 $y2
                        dxf_write_length $f 30 0.0
                        dxf_write_length $f 10 $x3
                        dxf_write_length $f 20 $y3
                        dxf_write_length $f 30 0.0
                        set x0 $x2
                        set y0 $y2
                    }
                }
                BEZIER {
                    set cps [expr {[llength $data]/2}]
                    dxf_write_string $f 0 "SPLINE"
                    dxf_write_string $f 100 "AcDbEntity"
                    dxf_write_string $f 8 $layername
                    dxf_write_int $f 62 256
                    dxf_write_string $f 100 "AcDbSpline"
                    dxf_write_float $f 210 0.0
                    dxf_write_float $f 220 0.0
                    dxf_write_float $f 230 1.0
                    dxf_write_int $f 70 8
                    dxf_write_int $f 71 3
                    dxf_write_int $f 72 [expr {$cps+4}]
                    dxf_write_int $f 73 $cps
                    dxf_write_int $f 74 0
                    dxf_write_float $f 42 0.0000001
                    dxf_write_float $f 43 0.0000001
                    dxf_write_float $f 44 0.0000000001

                    dxf_write_float $f 40 0.0
                    for {set i 0} {$i <= ($cps-1)/3} {incr i 3} {
                        dxf_write_float $f 40 $i
                        dxf_write_float $f 40 $i
                        dxf_write_float $f 40 $i
                    }
                    dxf_write_float $f 40 [expr {($cps-1)/3}]

                    foreach {x0 y0} [lrange $data 0 1] break
                    dxf_write_length $f 10 $x0
                    dxf_write_length $f 20 $y0
                    dxf_write_length $f 30 0.0
                    foreach {x1 y1 x2 y2 x3 y3} [lrange $data 2 end] {
                        dxf_write_length $f 10 $x1
                        dxf_write_length $f 20 $y1
                        dxf_write_length $f 30 0.0
                        dxf_write_length $f 10 $x2
                        dxf_write_length $f 20 $y2
                        dxf_write_length $f 30 0.0
                        dxf_write_length $f 10 $x3
                        dxf_write_length $f 20 $y3
                        dxf_write_length $f 30 0.0
                    }
                }
                LINES {
                    if {[llength $data]/2 > 2} {
                        dxf_write_string $f 0 "LWPOLYLINE"
                        dxf_write_string $f 100 "AcDbEntity"
                        dxf_write_string $f 8 $layername
                        dxf_write_string $f 100 "AcDbPolyline"
                        dxf_write_int $f 90 [expr {[llength $data]/2}]
                        dxf_write_int $f 70 0
                        dxf_write_int $f 43 1
                        foreach {x y} $data {
                            dxf_write_length $f 10 $x
                            dxf_write_length $f 20 $y
                        }
                    } else {
                        foreach {x0 y0} [lrange $data 0 1] break
                        foreach {x1 y1} [lrange $data 2 end] {
                            dxf_write_string $f 0 "LINE"
                            dxf_write_string $f 100 "AcDbEntity"
                            dxf_write_string $f 8 $layername
                            dxf_write_int $f 62 256
                            dxf_write_string $f 100 "AcDbLine"
                            dxf_write_float $f 210 0.0
                            dxf_write_float $f 220 0.0
                            dxf_write_float $f 230 1.0
                            dxf_write_length $f 10 $x0
                            dxf_write_length $f 20 $y0
                            dxf_write_length $f 30 0.0
                            dxf_write_length $f 11 $x1
                            dxf_write_length $f 21 $y1
                            dxf_write_length $f 31 0.0
                            set x0 $x1
                            set y0 $y1
                        }
                    }
                }
                POINTS {
                    foreach {x y} $data {
                        dxf_write_string $f 0 "POINT"
                        dxf_write_string $f 100 "AcDbEntity"
                        dxf_write_string $f 8 $layername
                        dxf_write_int $f 62 256
                        dxf_write_string $f 100 "AcDbPoint"
                        dxf_write_length $f 10 $x
                        dxf_write_length $f 20 $y
                        dxf_write_length $f 30 0.0
                        dxf_write_float $f 210 0.0
                        dxf_write_float $f 220 0.0
                        dxf_write_float $f 230 1.0
                    }
                }
            }
        }
    }
}


proc ffmt_plugin_writefile_dxf {win canv filename} {
    global tkcad_version
    set objcount [llength [cadobjects_object_ids $canv]]
    progwin_create .dxf-progwin "tkCAD Export" "Exporting DXF R12 file..."
    set layers [layer_ids $canv]

    set objnum 0
    foreach {x0 y0 x1 y1} [cadobjects_descale_coords $canv [$canv bbox AllDrawn]] break

    set f [open $filename "w"]
    fconfigure $f -translation binary

    dxf_write_string $f 999 "Created by tkCAD v$tkcad_version"
    dxf_write_string $f 0 "SECTION"
    dxf_write_string $f 2 "HEADER"
    dxf_write_string $f 9 "\$ACADVER"
    dxf_write_string $f 1 "AC1009"
    dxf_write_string $f 9 "\$INSBASE"
    dxf_write_length $f 10 0.0
    dxf_write_length $f 20 0.0
    dxf_write_length $f 30 0.0
    dxf_write_string $f 9 "\$EXTMIN"
    dxf_write_length $f 10 $x0
    dxf_write_length $f 20 $y1
    dxf_write_length $f 30 0.0
    dxf_write_string $f 9 "\$EXTMAX"
    dxf_write_length $f 10 $x1
    dxf_write_length $f 20 $y0
    dxf_write_length $f 30 0.0
    dxf_write_string $f 0 "ENDSEC"

    dxf_write_string $f 0 "SECTION"
    dxf_write_string $f 2 "TABLES"
    dxf_write_string $f 0 "TABLE"
    dxf_write_string $f 2 "LTYPE"
    dxf_write_int $f 70 1
    dxf_write_string $f 0 "LTYPE"
    dxf_write_string $f 2 "CONTINUOUS"
    dxf_write_int $f 70 64
    dxf_write_string $f 3 "Solid Line"
    dxf_write_int $f 72 65
    dxf_write_int $f 73 0
    dxf_write_float $f 40 0.0
    dxf_write_string $f 0 "ENDTAB"

    dxf_write_string $f 0 "TABLE"
    dxf_write_string $f 2 "LAYER"
    dxf_write_int $f 70 [llength $layers]
    foreach layerid $layers {
        set layername [layer_name $canv $layerid]
        set layercolor [layer_color $canv $layerid]
        dxf_write_string $f 0 "LAYER"
        dxf_write_string $f 2 $layername
        dxf_write_int $f 70 64
        dxf_write_color $f 62 $layercolor
        dxf_write_string $f 6 "CONTINUOUS"
    }
    dxf_write_string $f 0 "ENDTAB"

    dxf_write_string $f 0 "TABLE"
    dxf_write_string $f 2 "STYLE"
    dxf_write_int $f 70 0
    dxf_write_string $f 0 "ENDTAB"
    dxf_write_string $f 0 "ENDSEC"

    dxf_write_string $f 0 "SECTION"
    dxf_write_string $f 2 "BLOCKS"
    dxf_write_string $f 0 "ENDSEC"

    dxf_write_string $f 0 "SECTION"
    dxf_write_string $f 2 "ENTITIES"
    foreach layer $layers {
        foreach objid [layer_objects $canv $layer] {
            incr objnum
            ffmt_plugin_writeobj_dxf $win $canv $f $objid objnum
            progwin_callback .dxf-progwin $objcount $objnum
        }
    }
    dxf_write_string $f 0 "ENDSEC"
    dxf_write_string $f 0 "EOF"

    close $f
    progwin_destroy .dxf-progwin
}


proc dxf_incr {var val} {
    upvar $var v
    set v [expr {$v+$val}]
    return $v
}


proc dxf_mult {var val} {
    upvar $var v
    set v [expr {$v*$val}]
    return $v
}


proc dxf_transform_coords {tuplet coords mat} {
    if {$tuplet == 3} {
        return [matrix_3d_transform_coords $mat [list $x $y $z]]
    } else {
        set outcoords {}
        foreach {x y} $coords {
            foreach {tx ty tz} [matrix_3d_transform_coords $mat [list $x $y 0.0]] break
            lappend outcoords $tx $ty
        }
        return $outcoords
    }
}


proc dxf_create_entity {canv entity data currgroup mat} {
    global dxf_block_info
    global dxf_block_transmat
    global dxf_polyflags dxf_polyvcount dxf_polyvlist dxf_inpolyline
    constants pi
    set newobjs {}

    array set entityvals $data

    set extrudex [dxf_value entityvals 210 0.0]
    set extrudey [dxf_value entityvals 220 0.0]
    set extrudez [dxf_value entityvals 230 1.0]
    set normv [list $extrudex $extrudey $extrudez]

    if {$extrudez != 1.0} {
        if {abs($extrudex) < 1.0/64.0 && abs($extrudey) < 1.0/64.0} {
            set arbxv [vector_cross [list 0.0 1.0 0.0] $normv]
        } else {
            set arbxv [vector_cross [list 0.0 0.0 1.0] $normv]
        }
        set arbxv [vector_normalize $arbxv]
        set arbyv [vector_cross $normv $arbxv]
        set arbzv $normv
        set mat2 [matrix_3d_coordsys_convert [list 0.0 0.0 0.0] $arbxv $arbyv $arbzv]
        set mat [matrix_mult $mat $mat2]
    }

    set layername [dxf_value entityvals 8 ""]
    set layerid [layer_get_current $canv]
    if {$layername == ""} {
        if {$layerid < 0} {
            set layerid [layer_create $canv]
            layer_set_current $canv $layerid
        }
        set layername [layer_name $canv $layerid]
    } else {
        if {$layerid < 0 || $layername != [layer_name $canv $layerid]} {
            set layerid [layer_name_id $canv $layername]
            if {$layerid == ""} {
                set layerid [layer_create $canv $layername]
            }
            set layername [layer_name $canv $layerid]
            layer_set_current $canv $layerid
        }
    }

    switch -exact -- $entity {
        "" {
            # do nothing.
        }
        INSERT {
            set blockname [dxf_value entityvals 2 ""]
            set ox [dxf_value entityvals 10 0.0]
            set oy [dxf_value entityvals 20 0.0]
            set oz [dxf_value entityvals 30 0.0]
            set sx [dxf_value entityvals 41 1.0]
            set sy [dxf_value entityvals 42 1.0]
            set sz [dxf_value entityvals 43 1.0]
            set rot [dxf_value entityvals 50 0.0]

            if {$ox != 0.0 || $oy != 0.0 || $oz != 0.0} {
                set mat [matrix_mult $mat [matrix_3d_translate $ox $oy $oz]]
            }
            if {$rot != 0.0} {
                set mat [matrix_mult $mat [matrix_3d_rotate $normv $rot]]
            }
            if {$sx != 1.0 || $sy != 1.0 || $sz != 1.0} {
                set mat [matrix_mult $mat [matrix_3d_scale $sx $sy $sz]]
            }
            set mat [matrix_mult $mat $dxf_block_transmat($blockname)]

            set newgroup [cadobjects_object_create $canv GROUP {} {}]
            cadobjects_object_setlayer $canv $newgroup $layerid
            foreach entityinfo $dxf_block_info($blockname) {
                foreach {subent subentdata} $entityinfo break
                dxf_create_entity $canv $subent $subentdata $newgroup $mat
            }
            lappend newobjs $newgroup
        }
        ARC {
            set cx    [dxf_value entityvals 10 0.0]
            set cy    [dxf_value entityvals 20 0.0]
            set rad   [dxf_value entityvals 40 0.0]
            set start [dxf_value entityvals 50 0.0]
            set end   [dxf_value entityvals 51 0.0]

            set ckmat [matrix_3d_transform_coords $mat {0.0 0.0 1.0}]
            if {[lindex $ckmat 2] < 0.0} {
                set tmp $start
                set start $end
                set end $tmp
            }

            set cpx1 [expr {$cx+cos($start*$pi/180.0)*$rad}]
            set cpy1 [expr {$cy+sin($start*$pi/180.0)*$rad}]
            set cpx2 [expr {$cx+cos($end*$pi/180.0)*$rad}]
            set cpy2 [expr {$cy+sin($end*$pi/180.0)*$rad}]

            set coords [list $cx $cy $cpx1 $cpy1 $cpx2 $cpy2]
            set coords [dxf_transform_coords 2 $coords $mat]
            set newobj [cadobjects_object_create $canv ARCCTR $coords]
            cadobjects_object_setlayer $canv $newobj $layerid
            cadobjects_object_recalculate $canv $newobj
            lappend newobjs $newobj
        }
        CIRCLE {
            set cx  [dxf_value entityvals 10 0.0]
            set cy  [dxf_value entityvals 20 0.0]
            set rad [dxf_value entityvals 40 0.0]
            set cpx1 [expr {$cx+$rad}]
            set cpy1 $cy
            set coords [list $cx $cy $cpx1 $cpy1]
            set coords [dxf_transform_coords 2 $coords $mat]
            set newobj [cadobjects_object_create $canv CIRCLECTR $coords]
            cadobjects_object_setlayer $canv $newobj $layerid
            cadobjects_object_recalculate $canv $newobj
            lappend newobjs $newobj
        }
        ELLIPSE {
            set cx    [dxf_value entityvals 10 0.0]
            set cy    [dxf_value entityvals 20 0.0]
            set majx  [dxf_value entityvals 11 0.0]
            set majy  [dxf_value entityvals 21 0.0]
            set ratio [dxf_value entityvals 40 0.0]
            set start [dxf_value entityvals 41 0.0]
            set end   [dxf_value entityvals 42 0.0]

            set rotr  [expr {atan2($majy,$majx)}]
            set rot   [expr {$rotr*180.0/$pi}]
            set rad1  [expr {hypot($majy,$majx)}]
            set rad2  [expr {$rad1*$ratio}]
            set cpx1  [expr {$cx+$rad1}]
            set cpy1  [expr {$cy+$rad2}]
            set sinv [expr {sin($rotr)}]
            set cosv [expr {cos($rotr)}]
            set nx [expr {$cosv*($cpx1-$cx)-$sinv*($cpy1-$cy)+$cx}]
            set ny [expr {$sinv*($cpx1-$cx)+$cosv*($cpy1-$cy)+$cy}]
            if {abs(($end-$start)-2.0*$pi) < 1e-8} {
                set coords [list $cx $cy $nx $ny]
                set coords [dxf_transform_coords 2 $coords $mat]
                set newobj [cadobjects_object_create $canv ELLIPSECTR $coords [list ROT [expr {$rot}]]]
                cadobjects_object_setlayer $canv $newobj $layerid
                cadobjects_object_recalculate $canv $newobj
                lappend newobjs $newobj
            } else {
                # TODO: implement partial elliptical arc
            }
        }
        LINE -
        3DLINE {
            set x0 [dxf_value entityvals 10 0.0]
            set y0 [dxf_value entityvals 20 0.0]
            set x1 [dxf_value entityvals 11 0.0]
            set y1 [dxf_value entityvals 21 0.0]
            set coords [list $x0 $y0 $x1 $y1]
            set coords [dxf_transform_coords 2 $coords $mat]
            set newobj [cadobjects_object_create $canv LINE $coords]
            cadobjects_object_setlayer $canv $newobj $layerid
            cadobjects_object_recalculate $canv $newobj
            lappend newobjs $newobj
        }
        LWPOLYLINE {
            set vcount [dxf_value entityvals 90 0.0]
            set flags  [dxf_value entityvals 70 0.0]
            set vlistx [dxf_value entityvals 10 0.0]
            set vlisty [dxf_value entityvals 20 0.0]
            set coords {}
            for {set i 0} {$i < $vcount} {incr i} {
                set x [lindex $vlistx $i]
                set y [lindex $vlisty $i]
                if {$x == ""} {
                    set x 0.0
                }
                if {$y == ""} {
                    set y 0.0
                }
                lappend coords $x $y
            }
            set coords [dxf_transform_coords 2 $coords $mat]
            set newobj [cadobjects_object_create $canv LINE $coords]
            cadobjects_object_setlayer $canv $newobj $layerid
            cadobjects_object_recalculate $canv $newobj
            lappend newobjs $newobj
        }
        POINT {
            set x0 [dxf_value entityvals 10 0.0]
            set y0 [dxf_value entityvals 20 0.0]
            set coords [list $x0 $y0]
            set coords [dxf_transform_coords 2 $coords $mat]
            set newobj [cadobjects_object_create $canv POINT $coords]
            cadobjects_object_setlayer $canv $newobj $layerid
            cadobjects_object_recalculate $canv $newobj
            lappend newobjs $newobj
        }
        POLYLINE {
            set dxf_polyflags  [dxf_value entityvals 90 0.0]
            set dxf_polyvcount 0
            set dxf_polyvlist {}
            set dxf_inpolyline 1
        }
        VERTEX {
            if {$dxf_inpolyline} {
                set x [dxf_value entityvals 10 0.0]
                set y [dxf_value entityvals 20 0.0]
                set z [dxf_value entityvals 30 0.0]
                if {$x == ""} {
                    set x 0.0
                }
                if {$y == ""} {
                    set y 0.0
                }
                if {$z == ""} {
                    set z 0.0
                }
                lappend dxf_polyvlist [list $x $y $z]
                incr dxf_polyvcount
            }
        }
        SEQEND {
            if {$dxf_inpolyline} {
                set dxf_inpolyline 0
                set coords {}
                for {set i 0} {$i < $dxf_polyvcount} {incr i} {
                    foreach {x y z} [lindex $dxf_polyvlist $i] break
                    lappend coords $x $y
                }
                set coords [dxf_transform_coords 2 $coords $mat]
                set newobj [cadobjects_object_create $canv LINE $coords]
                cadobjects_object_setlayer $canv $newobj $layerid
                cadobjects_object_recalculate $canv $newobj
                lappend newobjs $newobj
            }
        }
        SPLINE {
            set vcount [dxf_value entityvals 73 0]
            set flags  [dxf_value entityvals 70 0]
            set vlistx [dxf_value entityvals 10 {}]
            set vlisty [dxf_value entityvals 20 {}]
            set vlistz [dxf_value entityvals 30 {}]
            set coords {}
            for {set i 0} {$i < $vcount} {incr i} {
                set x [lindex $vlistx $i]
                set y [lindex $vlisty $i]
                set z [lindex $vlistz $i]
                if {$x == ""} {
                    set x 0.0
                }
                if {$y == ""} {
                    set y 0.0
                }
                if {$z == ""} {
                    set z 0.0
                }
                lappend coords $x $y
            }
            set coords [dxf_transform_coords 2 $coords $mat]
            set newobj [cadobjects_object_create $canv BEZIER $coords]
            cadobjects_object_setlayer $canv $newobj $layerid
            cadobjects_object_recalculate $canv $newobj
            lappend newobjs $newobj
        }
        TEXT {
            set cx  [dxf_value entityvals 10 0.0]
            set cy  [dxf_value entityvals 20 0.0]
            set th  [dxf_value entityvals 40 0.0]
            set rot [dxf_value entityvals 50 0.0]
            set txt [dxf_value entityvals 1 ""]
            set coords [list $cx $cy]
            set coords [dxf_transform_coords 2 $coords $mat]
            set newobj [cadobjects_object_create $canv TEXT $coords [list ROT [expr {$rot}] TEXT $txt FONT [list Times $th]]]
            cadobjects_object_setlayer $canv $newobj $layerid
            cadobjects_object_recalculate $canv $newobj
            lappend newobjs $newobj
            # TODO: support STYLES for text.
        }
    }
    foreach newobj $newobjs {
        if {$currgroup != ""} {
            cadobjects_object_group_addobj $canv $currgroup $newobj
        }
    }
}


proc ffmt_plugin_readfile_dxf {win canv filename} {
    global dxf_block_info
    global dxf_block_transmat
    global dxf_inpolyline

    catch {unset dxf_block_info}
    catch {unset dxf_block_transmat}
    global dxf_block_info
    global dxf_block_transmat

    set dxf_inpolyline 0

    set fileformat 0.0
    set blockname ""
    set unitscale 1.0
    set ismm [tk_messageBox -type yesno -default no -icon question -message "If this file in millimeters?"]
    if {$ismm == "yes"} {
        set unitscale [expr {1.0/25.4}]
        cadobjects_set_unitsystem $canv "mm" 0
    } else {
        cadobjects_set_unitsystem $canv "inches" 1
    }
    set mat [matrix_3d_scale $unitscale $unitscale $unitscale]


    set f [open $filename "r"]
    seek $f 0 end
    set totalbytes [tell $f]
    seek $f 0 start

    progwin_create .dxf-progwin "tkCAD Import" "Importing DXF file..."

    if {[dxf_seek_section $f "BLOCKS"]} {
        set inblocks 1
    } else {
        seek $f 0 start
        dxf_seek_section $f "ENTITIES"
        set inblocks 0
    }
    set mode ""
    catch {unset entityvals}
    while {1} {
        foreach {typenum val} [dxf_read_entry $f] break
        progwin_callback .dxf-progwin $totalbytes [tell $f]

        if {$typenum < 0} {
            # Error.
            # We're done here.
            break
        }
        if {$typenum == 0} {
            set newobjs {}
            if {$inblocks} {
                switch -exact -- $mode {
                    "" {
                        # do nothing.
                    }
                    BLOCK {
                        set dx [dxf_value entityvals 10 0.0]
                        set dy [dxf_value entityvals 20 0.0]
                        set dz [dxf_value entityvals 30 0.0]
                        set blockname [dxf_value entityvals 2 0.0]
                        set dxf_block_transmat($blockname) [matrix_3d_translate $dx $dy $dz]
                    }
                    ENDBLK {
                        # Do nothing.
                    }
                    default {
                        lappend dxf_block_info($blockname) [list $mode [array get entityvals]]
                    }
                }
            } elseif {$mode != ""} {
                dxf_create_entity $canv $mode [array get entityvals] "" $mat
            }
            catch {unset entityvals}
            if {$val == "ENDSEC"} {
                if {$inblocks} {
                    # Done with BLOCKS section.  Skip to ENTITIES section.
                    set inblocks 0
                    dxf_seek_section $f "ENTITIES"
                } else {
                    # Done with ENTITIES section.  Quit.
                    break
                }
                set mode ""
            } elseif {$val == "EOF"} {
                break
            } else {
                set mode $val
            }
        } else {
            if {[info exists entityvals($typenum)]} {
                lappend entityvals($typenum) $val
            } else {
                set entityvals($typenum) $val
            }
        }
        # TODO: Add line color/width/style support.
    }
    close $f
    progwin_destroy .dxf-progwin

    #cutpaste_canvas_init $canv
    #mainwin_redraw $win
    #mainwin_canvas_zoom_all $win
    #cutpaste_canvas_init $canv
    foreach objid [cadobjects_object_ids $canv] {
        cadselect_add $canv $objid
    }
}


# vim: set ts=4 sw=4 nowrap expandtab: settings

