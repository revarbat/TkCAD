proc plugin_image_editfields {canv objid coords} {
    set out {}
    lappend out {
        type POINT
        name POINT
        datum 0
        title "Point"
    }
    lappend out {
        type FLOAT
        name ROT
        title "Angle"
        min -360.0
        max 360.0
        increment 5.0
        width 8
    }
    return $out
}



proc plugin_image_initobj {canv objid coords} {
    cadobjects_object_setdatum $canv $objid "ROT" 0.0
    cadobjects_object_setdatum $canv $objid "WIDTH" 0.0
    cadobjects_object_setdatum $canv $objid "HEIGHT" 0.0
    cadobjects_object_setdatum $canv $objid "BBOX" ""
}



proc plugin_image_transformobj {canv objid coords mat} {
    cadobjects_object_setdatum $canv $objid "MATRIX" $mat
    return 0 ;# Also allow default coordlist transforms
}



proc plugin_image_flipobj {canv objid coords x0 y0 x1 y1} {
    constants degtorad radtodeg
    set rot [cadobjects_object_getdatum $canv $objid "ROT"]
    set refang [expr {atan2($y1-$y0,$x1-$x0)*$radtodeg}]
    set rot [expr {fmod(2.0*$refang-$rot,360.0)}]
    cadobjects_object_setdatum $canv $objid "ROT" $rot
    return 0 ;# Also allow default coordlist transforms
}



proc plugin_image_shearobj {canv objid coords sx sy cx cy} {
    return 0 ;# Also allow default coordlist transforms
}



proc plugin_image_rotateobj {canv objid coords rotang cx cy} {
    set rot [cadobjects_object_getdatum $canv $objid "ROT"]
    set rot [expr {$rot+$rotang}]
    cadobjects_object_setdatum $canv $objid "ROT" $rot
    return 0 ;# Also allow default coordlist transforms
}



proc plugin_image_drawobj {canv objid coords tags color fill width dash} {
    return 0 ;# Let image be drawn from decomposition.
}



proc plugin_image_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid POINT $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}



proc plugin_image_recalculate {canv objid coords {flags ""}} {
    constants degtorad

    set rot [cadobjects_object_getdatum $canv $objid "ROT"]
    if {$rot == ""} {
        set rot 0.0
    }

    set img [cadobjects_object_getdatum $canv $objid "IMAGE"]
    if {$img == ""} {
        set imgdata [cadobjects_object_getdatum $canv $objid "IMGDATA"]
        if {$imgdata != ""} {
            if {[catch {
                set img [image create photo]
                $img put $imgdata
            } err]} {
                after 10 cadobjects_object_delete $canv $objid
                return
            }
        } else {
            set filetypes {
                {"Image Files" {.jpg .jpeg .JPG .JPEG .jfif .JFIF .gif .GIF .png .PNG .tiff .TIFF .pnm .PNM .pbm .PBM .pgm .PGM .ppm .PPM .tga .TGA .targa .TARGA .bmp .BMP .xbm .XBM .xpm .XPM}}
            }
            set filename [tk_getOpenFile \
                -title "Open Image File..." \
                -filetypes $filetypes \
                ]
            if {$filename == ""} {
                after idle cadobjects_object_delete $canv $objid
                return
            }
            if {[catch {image create photo -file $filename} img]} {
                after idle cadobjects_object_delete $canv $objid
                return
            }
            cadobjects_object_setdatum $canv $objid "IMGDATA" [$img data -format png]
        }
        cadobjects_object_setdatum $canv $objid "IMAGE" $img
    }

    set imgw [expr {[image width $img]/100.0}]
    set imgh [expr {[image height $img]/100.0}]
    if {[llength $coords] == 2} {
        foreach {x0 y0} $coords break
        set x1 [expr {$x0+$imgw}]
        set y1 [expr {$y0+$imgh}]
        cadobjects_object_set_coords $canv $objid [list $x0 $y0 $x1 $y1]
    } else {
        foreach {x0 y0 x1 y1} $coords break
    }

    set rad [expr {hypot($y1-$y0,$x1-$x0)}]
    set ang [expr {atan2($y1-$y0,$x1-$x0)}]
    set width  [expr {$rad*cos($ang-$rot*$degtorad)}]
    set height [expr {$rad*sin($ang-$rot*$degtorad)}]
    if {[cadobjects_modkey_isdown SHIFT]} {
        set sx [expr {double($width)/double($imgw)}]
        set sy [expr {double($height)/double($imgh)}]
        if {abs($sx) > abs($sy)} {
            set sy [expr {abs($sx)*(($sy>=0.0)?1.0:-1.0)}]
        } else {
            set sx [expr {abs($sy)*(($sx>=0.0)?1.0:-1.0)}]
        }
        set width [expr {$sx*$imgw}]
        set height [expr {$sy*$imgh}]
        set x1 [expr {$width*cos($rot*$degtorad)-$height*sin($rot*$degtorad)+$x0}]
        set y1 [expr {$width*sin($rot*$degtorad)+$height*cos($rot*$degtorad)+$y0}]
        cadobjects_object_set_coords $canv $objid [list $x0 $y0 $x1 $y1]
    }

    cadobjects_object_setdatum $canv $objid "WIDTH" $width
    cadobjects_object_setdatum $canv $objid "HEIGHT" $height

    set mat [matrix_rotate $rot $x0 $y0]
    set rcoords [list $x0 $y0  $x1 $y0  $x1 $y1  $x0 $y1]
    set rcoords [matrix_transform_coords $mat $rcoords]
    set bbox [geometry_pointlist_bbox $rcoords]
    cadobjects_object_setdatum $canv $objid "BBOX" $bbox
}



proc plugin_image_decompose {canv objid coords allowed} {
    foreach {x0 y0 x1 y1} $coords break
    set width  [cadobjects_object_getdatum $canv $objid "WIDTH"]
    set height [cadobjects_object_getdatum $canv $objid "HEIGHT"]
    set rot    [cadobjects_object_getdatum $canv $objid "ROT"]
    set img    [cadobjects_object_getdatum $canv $objid "IMAGE"]
    set cx [expr {($x0+$x1)/2.0}]
    set cy [expr {($y0+$y1)/2.0}]

    if {"IMAGE" in $allowed} {
        return [list IMAGE [list $cx $cy $width $height $rot $img]]
    }
    return {}
}



proc plugin_image_bbox {canv objid coords} {
    set bbox [cadobjects_object_getdatum $canv $objid "BBOX"]
    return $bbox
}



proc plugin_image_vectorize_selected {win canv} {
    set sellist [cadselect_list $canv]
    if {[llength $sellist] < 1} {
        bell
        return
    }

    #set base [toplevel .autotrace -padx 15 -pady 15]
    #wm title $base "Trace Bitmap"

    foreach objid $sellist {
        set objtype [cadobjects_object_gettype $canv $objid]
        if {$objtype != "IMAGE"} continue

        set coords [cadobjects_object_get_coords $canv $objid]
        foreach {x0 y0 x1 y1} $coords break

        set img    [cadobjects_object_getdatum $canv $objid "IMAGE"]
        set width  [cadobjects_object_getdatum $canv $objid "WIDTH"]
        set height [cadobjects_object_getdatum $canv $objid "HEIGHT"]
        set rot    [cadobjects_object_getdatum $canv $objid "ROT"]

        set use_potrace 1
        if {$use_potrace} {
            set mult 9.0
        } else {
            set mult 90.0
        }
        set pow [expr {[image width $img]/$mult}]
        set poh [expr {[image height $img]/$mult}]
        set sx [expr {$width*$mult/[image width $img]}]
        set sy [expr {-$height*$mult/[image height $img]}]
        set tx [expr {$x0}]
        set ty [expr {$y0}]

        set mat [matrix_transform scale $sx $sy 0.0 0.0 rotate $rot 0.0 0.0 translate $tx $ty]

        set tmpifile "/tmp/tkcadtrace[pid].png"
        set tmpofile "/tmp/tkcadtrace[pid].svg"
        $img write $tmpifile -format PPM -background #ffffff
        global root_dir
        if {$use_potrace} {
            set potracebin [file normalize [file join $root_dir .. .. bin potrace]]
            if {![file exists $potracebin]} {
                set potracebin [file normalize [file join / usr local bin potrace]]
            }
            exec $potracebin -s -k 0.7 --group -W $pow -H $poh $tmpifile > $tmpofile
        } else {
            set atracebin [file normalize [file join $root_dir .. .. bin autotrace]]
            if {![file exists $atracebin]} {
                set atracebin [file normalize [file join / usr local bin autotrace]]
            }
            exec $atracebin --background-color=FFFFFF --color-count=2 --dpi=90 --preserve-width --centerline --despeckle-level=8 --input-format=ppm --output-file=$tmpofile --output-format=svg $tmpifile
        }
        ffmt_plugin_readfile_svg $win $canv $tmpofile $mat
        file delete $tmpifile
        file delete $tmpofile
    }
}






proc plugin_image_register {} {
    tool_register_ex IMAGE "&Miscellaneous" "Bitmap &Image" {
        {1    "Upper-Left Corner"}
    } -icon "tool-image" -creator -impfields {ROT IMGDATA}
}
plugin_image_register 

# vim: set ts=4 sw=4 nowrap expandtab: settings

