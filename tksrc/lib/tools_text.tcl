proc plugin_text_initobj {canv objid coords} {
    cadobjects_object_setdatum $canv $objid "ROT" 0.0
    cadobjects_object_setdatum $canv $objid "TEXT" "Text"
    cadobjects_object_setdatum $canv $objid "FONT" "Times 12"
    cadobjects_object_setdatum $canv $objid "JUSTIFY" "left"
}


proc plugin_text_transformobj {canv objid coords mat} {
    set decomp [plugin_text_decompose $canv $objid $coords [list "BEZIER"]]
    foreach {dectyp coords} [lrange $decomp 0 1] break
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid BEZIER
    foreach {dectyp coords} [lrange $decomp 2 end] {
        set nuobj [cadobjects_object_create $canv BEZIER $coords]
        cadobjects_object_transform $canv $nuobj $mat
        cadselect_add $canv $nuobj
    }
    return 0 ;# Also allow default coordlist transform
}


proc plugin_text_rotateobj {canv objid coords rotang cx cy} {
    set rot [cadobjects_object_getdatum $canv $objid "ROT"]
    set rotang [expr {$rotang+$rot}]
    cadobjects_object_setdatum $canv $objid "ROT" $rotang
    return 0 ;# Also allow default coordlist transform
}


proc plugin_text_scaleobj {canv objid coords sx sy cx cy} {
    if {abs($sx-$sy) < 1e-6} {
        set font [cadobjects_object_getdatum $canv $objid "FONT"]
        set ffam [lindex $font 0]
        set fsiz [lindex $font 1]
        set fsiz [format "%.2f" [expr {$sx*$fsiz}]]
        set font [list $ffam $fsiz]
        cadobjects_object_setdatum $canv $objid "FONT" $font
    } else {
        set decomp [plugin_text_decompose $canv $objid $coords [list "BEZIER"]]
        foreach {dectyp coords} [lrange $decomp 0 1] break
        cadobjects_object_set_coords $canv $objid $coords
        cadobjects_object_settype $canv $objid BEZIER
        foreach {dectyp coords} [lrange $decomp 2 end] {
            set nuobj [cadobjects_object_create $canv BEZIER $coords]
            cadobjects_object_scale $canv $nuobj $sx $sy $cx $cy
            cadselect_add $canv $nuobj
        }
    }
    return 0 ;# Also allow default coordlist transform
}


proc plugin_text_shearobj {canv objid coords sx sy cx cy} {
    set decomp [plugin_text_decompose $canv $objid $coords [list "BEZIER"]]
    foreach {dectyp coords} [lrange $decomp 0 1] break
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid BEZIER
    foreach {dectyp coords} [lrange $decomp 2 end] {
        set nuobj [cadobjects_object_create $canv BEZIER $coords]
        cadobjects_object_shear $canv $nuobj $sx $sy $cx $cy
        cadselect_add $canv $nuobj
    }
    return 0 ;# Also allow default coordlist transform
}


proc plugin_text_flipobj {canv objid coords x0 y0 x1 y1} {
    set decomp [plugin_text_decompose $canv $objid $coords [list "BEZIER"]]
    foreach {dectyp coords} [lrange $decomp 0 1] break
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid BEZIER
    foreach {dectyp coords} [lrange $decomp 2 end] {
        set nuobj [cadobjects_object_create $canv BEZIER $coords]
        cadobjects_object_flip $canv $nuobj $x0 $y0 $x1 $y1
        cadselect_add $canv $nuobj
    }
    return 0 ;# Also allow default coordlist transform
}


proc plugin_text_editfields {canv objid coords} {
    set out {}
    lappend out {
        type STR
        name TEXT
        title "Text"
        width 30
        live 1
    }
    lappend out {
        type POINT
        name ANCHOR
        datum 0
        title "Anchor pt"
    }
    lappend out {
        type FLOAT
        name ROT
        title "Rot"
        width 8
        min -360.0
        max 360.0
        increment 1.0
        default 0.0
    }
    lappend out {
        type FONT
        name FONT
        title "Font"
    }
    lappend out {
        type OPTIONS
        name JUSTIFY
        title "Justify"
        width 8
        values {Left left Center center Right right}
        default left
    }
    return $out
}


proc plugin_text_usereditobj {canv objid coords} {
    confpane_populate
    confpane_focus TEXT
}


proc plugin_text_convert_to_bezier {canv font txt} {
    set parent [winfo toplevel $canv]
    set fsiz [expr {[lindex $font 1]+0.0}]
    set font [lreplace $font 1 1 72]
    set path [GetFontCurves $parent $font $txt]
    set beziers {}
    set currbez {}
    set pathlen [llength $path]
    for {set i 0} {$i < $pathlen} {incr i} {
        set cmd [lindex $path $i]
        switch -exact -- $cmd {
            "M" {
                if {[llength $currbez] > 0} {
                    lappend beziers $currbez
                    set currbez {}
                }
                set p1x [lindex $path [incr i]]
                set p1y [lindex $path [incr i]]

                set p1x [expr {$p1x*$fsiz/72.0}]
                set p1y [expr {$p1y*$fsiz/72.0}]
                lappend currbez $p1x $p1y
            }
            "L" {
                set p1x [lindex $currbez end-1]
                set p1y [lindex $currbez end]
                set p2x [lindex $path [incr i]]
                set p2y [lindex $path [incr i]]

                set p2x [expr {$p2x*$fsiz/72.0}]
                set p2y [expr {$p2y*$fsiz/72.0}]
                lappend currbez $p1x $p1y $p2x $p2y $p2x $p2y
            }
            "C" {
                set p1x [lindex $path [incr i]]
                set p1y [lindex $path [incr i]]
                set p2x [lindex $path [incr i]]
                set p2y [lindex $path [incr i]]
                set p3x [lindex $path [incr i]]
                set p3y [lindex $path [incr i]]

                set p1x [expr {$p1x*$fsiz/72.0}]
                set p1y [expr {$p1y*$fsiz/72.0}]
                set p2x [expr {$p2x*$fsiz/72.0}]
                set p2y [expr {$p2y*$fsiz/72.0}]
                set p3x [expr {$p3x*$fsiz/72.0}]
                set p3y [expr {$p3y*$fsiz/72.0}]
                lappend currbez $p1x $p1y $p2x $p2y $p3x $p3y
            }
            "z" {
                if {[llength $currbez] > 0} {
                    lappend beziers $currbez
                    set currbez {}
                }
                set pathlen 0
            }
        }
    }
    return $beziers
}


proc plugin_text_drawobj {canv objid coords tags color fill width dash} {
    return 0 ;# Draw default decomposed shape.
}


proc plugin_text_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid TEXT $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_text_recalculate {canv objid coords {flags ""}} {
}


proc plugin_text_decompose {canv objid coords allowed} {
    foreach {cx cy} $coords break
    set scalefact [cadobjects_get_scale_factor $canv]
    set lwidth [cadobjects_object_stroke_width $canv $objid]
    set ldash [cadobjects_object_getdatum $canv $objid "LINEDASH"]
    set rot   [cadobjects_object_getdatum $canv $objid "ROT"]
    set txt   [cadobjects_object_getdatum $canv $objid "TEXT"]
    set just  [cadobjects_object_getdatum $canv $objid "JUSTIFY"]
    set font  [cadobjects_object_getdatum $canv $objid "FONT"]
    set ffam [lindex $font 0]
    set fsiz [lindex $font 1]
    set fheight [expr {$fsiz/72.0}]
    if {$ldash == ""} {
        set ldash "solid"
    }
    set iscncfont [cncfont_exists $ffam]
    set xwid [cncfont_measure $font $txt $lwidth]
    switch -exact -- $just {
        center { set xoff [expr {-$xwid/2.0}] }
        right { set xoff [expr {-$xwid}] }
        default { set xoff 0.0 }
    }
    set sc [expr {(100.0/72.0)/72.0}]

    if {"TEXT" in $allowed && abs($rot) < 1e-6 && $ldash == "solid" && !$iscncfont} {
        return [list TEXT [list $cx $cy $txt $font $just]]
    } elseif {"ROTTEXT" in $allowed && $ldash == "solid" && !$iscncfont} {
        return [list ROTTEXT [list $cx $cy $txt $font $just $rot]]
    } elseif {"BEZIER" in $allowed} {
        set out {}
        if {$iscncfont} {
            set mat [matrix_transform translate $xoff 0.0  rotate $rot  translate $cx $cy]
            set beziers [cncfont_render_beziers $ffam 0.0 0.0 $txt $fheight $lwidth]
        } else {
            set mat [matrix_transform translate $xoff 0.0  scale $sc -$sc  rotate $rot  translate $cx $cy]
            set beziers [plugin_text_convert_to_bezier $canv $font $txt]
        }
        foreach bez $beziers {
            set bez [matrix_transform_coords $mat $bez]
            lappend out BEZIER $bez
        }
        return $out
    } elseif {"LINES" in $allowed} {
        set out {}
        if {$iscncfont} {
            set mat [matrix_transform translate $xoff 0.0  rotate $rot  translate $cx $cy]
            set beziers [cncfont_render_beziers $ffam 0.0 0.0 $txt $fheight $lwidth]
        } else {
            set mat [matrix_transform translate $xoff 0.0  scale $sc -$sc  rotate $rot  translate $cx $cy]
            set beziers [plugin_text_convert_to_bezier $canv $font $txt]
        }
        foreach bez $beziers {
            set bez [matrix_transform_coords $mat $bez]
            set path {}
            bezutil_append_line_from_bezier path $bez
            lappend out LINES $path
        }
        return $out
    }
    return {}
}


proc plugin_text_bbox {canv objid coords} {
    foreach {cx cy} $coords break
    set lwidth [cadobjects_object_stroke_width $canv $objid]
    set rot  [cadobjects_object_getdatum $canv $objid "ROT"]
    set txt  [cadobjects_object_getdatum $canv $objid "TEXT"]
    set just [cadobjects_object_getdatum $canv $objid "JUSTIFY"]
    set font [cadobjects_object_getdatum $canv $objid "FONT"]
    set ffam [lindex $font 0]
    set fsiz [lindex $font 1]
    set fheight [expr {$fsiz/72.0}]

    set iscncfont [cncfont_exists $ffam]
    set xwid [cncfont_measure $font $txt $lwidth]
    switch -exact -- $just {
        center  { set xoff [expr {-$xwid/2.0}] }
        right   { set xoff [expr {-$xwid}] }
        default { set xoff 0.0 }
    }

    set x0 0
    set x1 [expr {$x0+$xwid}]
    set mat [matrix_transform translate $xoff 0.0  rotate $rot  translate $cx $cy]
    set coords [list $x0 0.0  $x0 $fheight  $x1 $fheight  $x1 0.0]
    set coords [matrix_transform_coords $mat $coords]
    set coords [::math::geometry::bbox $coords]
    return $coords
}







proc plugin_textarc_initobj {canv objid coords} {
    cadobjects_object_setdatum $canv $objid "TEXT" "Text"
    cadobjects_object_setdatum $canv $objid "FONT" "Times 12"
    cadobjects_object_setdatum $canv $objid "JUSTIFY" "left"
}


proc plugin_textarc_transformobj {canv objid coords mat} {
    set decomp [plugin_textarc_decompose $canv $objid $coords [list "BEZIER"]]
    foreach {dectyp coords} [lrange $decomp 0 1] break
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid BEZIER
    foreach {dectyp coords} [lrange $decomp 2 end] {
        set nuobj [cadobjects_object_create $canv BEZIER $coords]
        cadobjects_object_transform $canv $nuobj $mat
        cadselect_add $canv $nuobj
    }
    return 0 ;# Also allow default coordlist transform
}


proc plugin_textarc_shearobj {canv objid coords sx sy cx cy} {
    set decomp [plugin_textarc_decompose $canv $objid $coords [list "BEZIER"]]
    foreach {dectyp coords} [lrange $decomp 0 1] break
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid BEZIER
    foreach {dectyp coords} [lrange $decomp 2 end] {
        set nuobj [cadobjects_object_create $canv BEZIER $coords]
        cadobjects_object_shear $canv $nuobj $sx $sy $cx $cy
        cadselect_add $canv $nuobj
    }
    return 0 ;# Also allow default coordlist transform
}


proc plugin_textarc_flipobj {canv objid coords x0 y0 x1 y1} {
    set decomp [plugin_textarc_decompose $canv $objid $coords [list "BEZIER"]]
    foreach {dectyp coords} [lrange $decomp 0 1] break
    cadobjects_object_set_coords $canv $objid $coords
    cadobjects_object_settype $canv $objid BEZIER
    foreach {dectyp coords} [lrange $decomp 2 end] {
        set nuobj [cadobjects_object_create $canv BEZIER $coords]
        cadobjects_object_flip $canv $nuobj $x0 $y0 $x1 $y1
        cadselect_add $canv $nuobj
    }
    return 0 ;# Also allow default coordlist transform
}


proc plugin_textarc_editfields {canv objid coords} {
    set out {}
    lappend out {
        type STR
        name TEXT
        title "Text"
        width 30
        live 1
    }
    lappend out {
        type POINT
        name CENTER
        datum 0
        title "Center pt"
    }
    lappend out {
        type POINT
        name ANCHOR
        datum 1
        title "Anchor pt"
    }
    lappend out {
        type FLOAT
        name RADIUS
        datum ""
        title "Radius"
        width 8
        min 0.0
        max 1e9
        increment 0.1250
        valgetcb "plugin_textarc_getfield"
        valsetcb "plugin_textarc_setfield"
        default 1.0
    }
    lappend out {
        type FLOAT
        name STARTANG
        datum ""
        title "Start Angle"
        width 8
        min -360.0
        max 360.0
        increment 1.0
        valgetcb "plugin_textarc_getfield"
        valsetcb "plugin_textarc_setfield"
        default 0.0
    }
    lappend out {
        type FLOAT
        name CHARSPACING
        title "Spacing %"
        width 8
        fmt "%.3f"
        min 0.0
        max 9999.0
        increment 1.0
        default 100.0
    }
    lappend out {
        type FONT
        name FONT
        title "Font"
    }
    lappend out {
        type OPTIONS
        name JUSTIFY
        title "Justify"
        width 8
        values {Left left Center center Right right}
        default left
    }
    lappend out {
        type BOOLEAN
        name INVERT
        title "Invert Letters"
        default 0
    }
    return $out
}


proc plugin_textarc_getfield {canv objid coords field} {
    constants pi
    foreach {cx cy cpx1 cpy1} $coords break
    switch -exact -- $field {
        STARTANG {
            set a [expr {atan2($cpy1-$cy,$cpx1-$cx)*180.0/$pi}]
            return $a
        }
        RADIUS {
            set d [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
            return $d
        }
    }
}


proc plugin_textarc_setfield {canv objid coords field val} {
    constants pi
    foreach {cx cy cpx1 cpy1} $coords break
    set hy1 [expr {hypot($cpy1-$cy,$cpx1-$cx)}]

    switch -exact -- $field {
        STARTANG {
            set cpx1 [expr {$hy1*cos($val*$pi/180.0)+$cx}]
            set cpy1 [expr {$hy1*sin($val*$pi/180.0)+$cy}]
            set coords [list $cx $cy $cpx1 $cpy1]
            cadobjects_object_set_coords $canv $objid $coords
        }
        RADIUS {
            if {abs($hy1) < 1e-9} {
                set d 0.0
            } else {
                set d [expr {$val/$hy1}]
            }
            set cpx1 [expr {($cpx1-$cx)*$d+$cx}]
            set cpy1 [expr {($cpy1-$cy)*$d+$cy}]
            set coords [list $cx $cy $cpx1 $cpy1]
            cadobjects_object_set_coords $canv $objid $coords
        }
    }
}


proc plugin_textarc_usereditobj {canv objid coords} {
    confpane_populate
    confpane_focus TEXT
}


proc plugin_textarc_drawobj {canv objid coords tags color fill width dash} {
    set coords [cadobjects_scale_coords $canv $coords]
    foreach {cx cy cpx1 cpy1} $coords break
    set radius [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set crrad [expr {$radius/4.0}]
    cadobjects_object_draw_center_cross $canv $cx $cy $crrad $tags $color $width
    return 0 ;# Draw default decomposed shape.
}


proc plugin_textarc_drawctls {canv objid coords color fillcolor} {
    set coords [cadobjects_scale_coords $canv $coords]
    set cpnum 1
    foreach {cpx cpy} $coords {
        cadobjects_object_draw_controlpoint $canv $objid TEXT $cpx $cpy $cpnum "rectangle" $color $fillcolor
        incr cpnum
    }
}


proc plugin_textarc_recalculate {canv objid coords {flags ""}} {
}


proc plugin_textarc_dragctls {canv objid coords nodes dx dy} {
    if {"1" in $nodes} {
        set nodes {1 2}
    }
    foreach node $nodes {
        set pos1 [expr {($node-1)*2}]
        set pos2 [expr {$pos1+1}]
        lset coords $pos1 [expr {[lindex $coords $pos1]+$dx}]
        lset coords $pos2 [expr {[lindex $coords $pos2]+$dy}]
    }
    cadobjects_object_set_coords $canv $objid $coords
    return 1 ;# We moved everything.  Tell caller we need nothing else moved.
}


proc plugin_textarc_decompose {canv objid coords allowed} {
    constants radtodeg pi
    foreach {cx cy cpx1 cpy1} $coords break
    set scalefact [cadobjects_get_scale_factor $canv]
    set lwidth [cadobjects_object_stroke_width $canv $objid]
    set txt  [cadobjects_object_getdatum $canv $objid "TEXT"]
    set just [cadobjects_object_getdatum $canv $objid "JUSTIFY"]
    set inv  [cadobjects_object_getdatum $canv $objid "INVERT"]
    set font [cadobjects_object_getdatum $canv $objid "FONT"]
    set chspc [cadobjects_object_getdatum $canv $objid "CHARSPACING"]
    set sang [expr {atan2($cpy1-$cy,$cpx1-$cx)}]
    set rad [expr {hypot($cpy1-$cy,$cpx1-$cx)}]
    set ffam [lindex $font 0]
    set fsiz [lindex $font 1]
    if {$chspc == ""} {
        set chspc 100.0
    }
    if {$inv == ""} {
        set inv 0
    }

    set iscncfont [cncfont_exists $ffam]
    set sc [expr {(100.0/72.0)/72.0}]
    set fheight [expr {$fsiz/72.0}]

    set zwid [expr {[cncfont_measure $font "0" $lwidth]}]
    set xwid [expr {[string length $txt]*($chspc-100.0)*$zwid/100.0}]
    set pch ""
    foreach ch [split $txt {}] {
        set pwid [cncfont_measure $font "$pch$ch" $lwidth]
        set cwid [cncfont_measure $font $pch $lwidth]
        set xwid [expr {$xwid+$pwid-$cwid}]
    }
    set irad $rad
    if {$inv} {
        set irad [expr {abs($irad-$fheight)}]
    }
    if {$irad < $xwid/(2.0*$pi)} {
        set irad [expr {$xwid/(2.0*$pi)}]
        if {$inv} {
            set rad [expr {abs($irad+$fheight)}]
        }
        set cpx1 [expr {$cx+$rad*cos($sang)}]
        set cpy1 [expr {$cy+$rad*sin($sang)}]
    }

    switch -exact -- $just {
        center { set xoff [expr {-$xwid/2.0}] }
        right { set xoff [expr {-$xwid}] }
        default { set xoff 0.0 }
    }
    if {$inv} {
        set xoff [expr {-$xoff}]
    }

    if {"TEXTARC" in $allowed} {
        return [list TEXTARC [list $cx $cy $cpx1 $cpx2 $txt $font $just]]
    }

    set out {}
    set prefix ""
    set pch ""
    set offset $xoff
    foreach ch [split $txt {}] {
        set offset [expr {$offset+($inv?-1:1)*($chspc-100.0)*$zwid/200.0}]
        set pwid [cncfont_measure $font "$pch$ch" $lwidth]
        set cwid [cncfont_measure $font $pch $lwidth]
        set chwid [expr {$pwid-$cwid}]
        if {$inv} {
            set chwid [expr {-$chwid}]
        }
        set chwid2 [expr {$chwid/2.0}]
        set chang [expr {$chwid/$irad}]
        set ang [expr {$sang-$offset/$irad-$chang/2.0}]
        set qx [expr {$cx+$rad*cos($ang)}]
        set qy [expr {$cy+$rad*sin($ang)}]
        set px [expr {$qx+$chwid2*cos($ang+0.5*$pi)}]
        set py [expr {$qy+$chwid2*sin($ang+0.5*$pi)}]
        set angdeg [expr {$ang*$radtodeg}]
        if {$inv} {
            set textang [expr {$angdeg+90.0}]
        } else {
            set textang [expr {$angdeg-90.0}]
        }
        set offset [expr {$offset+$chwid+($inv?-1:1)*($chspc-100.0)*$zwid/200.0}]
        if {"ROTTEXT" in $allowed && !$iscncfont} {
            lappend out ROTTEXT [list $px $py $ch $font left $textang]
        } elseif {"BEZIER" in $allowed} {
            if {$iscncfont} {
                set mat [matrix_transform translate 0.0 0.0  rotate $textang  translate $px $py]
                set beziers [cncfont_render_beziers $ffam 0.0 0.0 $ch $fheight $lwidth]
            } else {
                set mat [matrix_transform translate $chwid2 0.0  scale $sc -$sc  rotate $textang  translate $px $py]
                set beziers [plugin_text_convert_to_bezier $canv $font $ch]
            }
            foreach bez $beziers {
                set bez [matrix_transform_coords $mat $bez]
                lappend out BEZIER $bez
            }
        } elseif {"LINES" in $allowed} {
            if {$iscncfont} {
                set mat [matrix_transform translate $chwid2 0.0  rotate $textang  translate $px $py]
                set beziers [cncfont_render_beziers $ffam 0.0 0.0 $ch $fsiz $lwidth]
            } else {
                set mat [matrix_transform translate $chwid2 0.0  scale $sc -$sc  rotate $textang  translate $px $py]
                set beziers [plugin_text_convert_to_bezier $canv $font $ch]
            }
            foreach bez $beziers {
                set bez [matrix_transform_coords $mat $bez]
                set path {}
                bezutil_append_line_from_bezier path $bez
                lappend out LINES $path
            }
        }
        append prefix $ch
    }
    return $out
}







proc plugin_text_register {} {
    tool_register_ex TEXT "Te&xt" "Te&xt" {
        {1    "Base"}
    } -icon "tool-text" -cursor "ibeam" -creator -impfields {ROT FONT TEXT JUSTIFY}
    tool_register_ex TEXTARC "Te&xt" "Text &Arc" {
        {1    "Center pt"}
        {2    "Start pt"}
    } -icon "tool-textarc" -creator -impfields {FONT TEXT JUSTIFY INVERT CHARSPACING}
}
plugin_text_register 


# vim: set ts=4 sw=4 nowrap expandtab: settings






