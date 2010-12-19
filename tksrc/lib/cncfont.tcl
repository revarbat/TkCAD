proc cncfont_list {} {
    global cncfontInfo
    set fonts {}
    foreach fnum $cncfontInfo(FONTS) {
	lappend fonts $cncfontInfo(FN-$fnum)
    }
    return [lsort $fonts]
}


proc cncfont_exists {fontname} {
    global cncfontInfo
    if {![info exists cncfontInfo(F-$fontname)]} {
        return 0
    }
    return 1
}


proc cncfont_new {fontname fontattrs} {
    global cncfontInfo
    if {![cncfont_exists $fontname]} {
	set fnum [incr cncfontInfo(MAXFONT)]
	set cncfontInfo(F-$fontname) $fnum
	set cncfontInfo(FN-$fnum) $fontname
	lappend cncfontInfo(FONTS) $fnum
    }
    set fnum $cncfontInfo(F-$fontname)
    set cncfontInfo(A-$fnum) $fontattrs
    return $fnum
}


proc cncfont_getglyph {fontname char} {
    global cncfontInfo
    if {![cncfont_exists $fontname]} {
        error "No such CNC Font"
    }
    set fnum $cncfontInfo(F-$fontname)
    if {![info exists cncfontInfo(G-$fnum-$char]} {
        return ""
    }
    set ginfo $cncfontInfo(G-$fnum-$char)
    return [list width [lindex $ginfo 0] beziers [lindex $ginfo 1]]
}


proc cncfont_setglyph {fontname char width beziers} {
    global cncfontInfo
    if {![cncfont_exists $fontname]} {
        error "No such CNC Font"
    }
    set fnum $cncfontInfo(F-$fontname)
    set cncfontInfo(G-$fnum-$char) [list $width $beziers]
}


proc cncfont_getglyphs {fontname} {
    global cncfontInfo
    if {![cncfont_exists $fontname]} {
        error "No such CNC Font"
    }
    set fnum $cncfontInfo(F-$fontname)
    set out {}
    foreach key [array names cncfontInfo "G-$fnum-*"] {
	set fnumlen [string length $fnum]
	incr fnumlen 3
	set char [string range $key $fnumlen end]
	lappend out $char
    }
    return [lsort $out]
}


proc cncfont_load {filename} {
    global cncfontInfo

    set fontname ""
    set fontattrs ""
    set sect ""
    set glyphs {}
    set kerning {}

    set f [open $filename "r"]
    fconfigure $f -encoding utf-8

    while {![eof $f]} {
	set line [string trim [gets $f]]
	if {$line == "" || [string match -nocase "#*" $line]} {
	    continue
	} elseif {[string match -nocase "ENDSECTION*" $line]} {
	    set sect ""
	} elseif {$sect == ""} {
	    if {[string match -nocase "NAME:*" $line]} {
		set fontname [string trim [string range $line 5 end]]
	    }
	    if {[string match -nocase "ATTRS:*" $line]} {
		set fontattrs [string trim [string range $line 6 end]]
	    }
	    if {[string match -nocase "SECTION:*" $line]} {
		set sect [string toupper [string trim [string range $line 8 end]]]
	    }
	} elseif {$sect == "GLYPHS"} {
	    lassign $line letter width bezpaths
	    lappend glyphs $letter $width $bezpaths
	} elseif {$sect == "KERNING"} {
	    lassign $line letter1 letter2 offset
	    lappend kerning $letter1 $letter2 $offset
	}
    }

    catch {close $f}

    if {[llength $glyphs] == 0} {
	error "Bad CNCFont file.  No glyphs found."
    }
    if {$fontname == ""} {
	error "Bad CNCFont file.  Unable to find NAME."
    }
    if {$sect != ""} {
	error "Bad CNCFont file.  Unterminated SECTION: $sect"
    }

    set fnum [cncfont_new $fontname $fontattrs]
    foreach {letter width bezpaths} $glyphs {
	set cncfontInfo(G-$fnum-$letter) [list $width $bezpaths]
    }
    foreach {letter1 letter2 offset} $kerning {
	set cncfontInfo(K-$fnum-$letter1$letter2) $offset
    }
}


proc cncfont_save {fontname filename} {
    global cncfontInfo
    if {![cncfont_exists $fontname]} {
        error "No such CNC Font"
    }
    set fnum $cncfontInfo(F-$fontname)
    set attrs $cncfontInfo(A-$fnum)

    set f [open $filename "w"]
    fconfigure $f -encoding utf-8

    puts $f "NAME: $fontname"
    puts $f "ATTRS: $fontattrs"
    puts $f ""
    puts $f "SECTION: GLYPHS"
    foreach key [lsort [array names cncfontInfo "G-$fnum-*"]] {
	set fnumlen [string length $fnum]
	incr fnumlen 3
	set letter [string range $key $fnumlen end]
	set glyphinfo $cncfontInfo($key)
	lassign $glyphinfo width bezpaths
	puts $f [format "%-5s  %.5f  %.s" [list $letter] $width [list $bezpaths]]
    }
    puts $f "ENDSECTION"
    puts $f ""
    puts $f "SECTION: KERNING"
    foreach key [lsort [array names cncfontInfo "K-$fnum-*"]] {
	set fnumlen [string length $fnum]
	incr fnumlen 3
	set letters [string range $key $fnumlen end]
	set letter1 [string index $letters 0]
	set letter2 [string index $letters 1]
	set offset $cncfontInfo($key)
	puts $f [format "%-5s %-5s %-.3f" [list $letter1] [list $letter2] $offset]
    }
    puts $f "ENDSECTION"

    catch {close $f}
}


proc cncfont_autokern {fontname} {
    if {![cncfont_exists $fontname]} {
        error "No such CNC Font"
    }
    set kerningsteps 50
    set letters [cncfont_getglyphs $fontname]
    foreach glyph $letters {
	for {set i 0} {$i <= $kerningsteps} {incr i} {
	    set ginfo [cncfont_getglyph $fontname $glyph]
	    lassign $ginfo width bezpaths
	    set y [expr {$i*1.0/$kerningsteps}]
	    set minl $width
	    set minr $width
	    foreach bez $bezpaths {
		foreach {dist xpos ypos seg} [mlcnc_bezier_nearest_point_to_point $bez 0.0 $y] break
		if {$dist < $minl} {
		    set minl $dist
		}
		foreach {dist xpos ypos seg} [mlcnc_bezier_nearest_point_to_point $bez $width $y] break
		if {$dist < $minr} {
		    set minr $dist
		}
	    }
	    set clearance(L-$glyph-$i) $minl
	    set clearance(R-$glyph-$i) $minr
	}
    }

    foreach glyph1 $letters {
	if {$glyph1 == " "} {
	    continue
	}
	set ginfo [cncfont_getglyph $fontname $glyph]
	set width [lindex $ginfo 0]
	foreach glyph2 $letters {
	    if {$glyph2 == " "} {
		continue
	    }
	    set mindist $width
	    for {set i 0} {$i <= $kerningsteps} {incr i} {
		set y [expr {$i*1.0/$kerningsteps}]
		set clear1 $clearance(R-$glyph1-$i)
		set clear2 $clearance(L-$glyph2-$i)
		set dist [expr {$clear1+$clear2}]
		if {$dist < $mindist} {
		    set mindist $dist
		}
	    }
	    if {abs($mindist) >= 0.001} {
		set cncfontInfo(K-$fnum-$glyph1$glyph2) [expr {-$mindist}]
	    }
	}
    }
}


# Font is standard font style:  ie: {{Millbit Standard} 12}
proc cncfont_measure {font msg thick {spacing 1.0}} {
    global cncfontInfo
    lassign $font fontname size

    if {![cncfont_exists $fontname]} {
	set size [expr {int($size+0.5)}]
	lset font 1 $size
	set xwid [font measure $font $msg]
        set sc [expr {(100.0/72.0)/72.0}]
	return [expr {$xwid*$sc}]
    }
    set size [expr {$size/72.0}]
    set fnum $cncfontInfo(F-$fontname)

    set xpos 0.0
    set ypos 0.0
    set xoff $xpos
    set yoff $ypos
    set prevch ""
    set maxx 0.0
    set maxy 0.0
    foreach ch [split $msg ""] {
	if {[info exists cncfontInfo(G-$fnum-$ch)]} {
	    lassign $cncfontInfo(G-$fnum-$ch) width bezset
	    set kernoff 0.0
	    if {$prevch != ""} {
		if {[info exists cncfontInfo(K-$fnum-$prevch$ch)]} {
		    set kernoff $cncfontInfo(K-$fnum-$prevch$ch)
		}
	    }
	    set xoff [expr {$xoff+$kernoff*$size}]
	    set xoff [expr {$xoff+0.5*$thick}]
	    set xoff [expr {$xoff+$width*$size}]
	    set xoff [expr {$xoff+0.5*$thick}]
	    set xoff [expr {$xoff+0.15*$size*$spacing}]
	    if {$xoff > $maxx} {
	        set maxx $xoff
	    }
	}
	set prevch $ch
	if {$ch == "\n"} {
	    set xoff $xpos
	    if {$yoff > $maxy} {
	        set maxy $yoff
	    }
	    set yoff [expr {$yoff-($thick+$size*1.5)}]
	    set prevch ""
	}
    }
    return $maxx
}


proc cncfont_render_beziers {fontname xpos ypos msg size thick {spacing 1.0}} {
    global cncfontInfo

    if {![cncfont_exists $fontname]} {
	error "No such CNCFont."
    }
    set fnum $cncfontInfo(F-$fontname)

    set xoff $xpos
    set yoff $ypos
    set prevch ""
    set outbezs {}
    foreach ch [split $msg ""] {
	if {[info exists cncfontInfo(G-$fnum-$ch)]} {
	    lassign $cncfontInfo(G-$fnum-$ch) width bezset
	    set kernoff 0.0
	    if {$prevch != ""} {
		if {[info exists cncfontInfo(K-$fnum-$prevch$ch)]} {
		    set kernoff $cncfontInfo(K-$fnum-$prevch$ch)
		}
	    }
	    set xoff [expr {$xoff+$kernoff*$size}]
	    set xoff [expr {$xoff+0.5*$thick}]
	    foreach bez $bezset {
		set nubez {}
		foreach {x y} $bez {
		    lappend nubez [expr {$x*$size+$xoff}] [expr {$y*$size+$yoff}]
		}
		lappend outbezs $nubez
	    }
	    set xoff [expr {$xoff+$width*$size}]
	    set xoff [expr {$xoff+0.5*$thick}]
	    set xoff [expr {$xoff+0.15*$size*$spacing}]
	}
	set prevch $ch
	if {$ch == "\n"} {
	    set xoff $xpos
	    set yoff [expr {$yoff-($thick+$size*1.5)}]
	    set prevch ""
	}
    }
    return $outbezs
}


proc cncfont_draw {canv fontname xpos ypos msg size thick} {
    set dpi 110.0
    set strokewidth [expr {int($thick*$dpi+0.5)}]
    set bezpaths [cncfont_render_beziers $fontname $xpos $ypos $msg $size $thick]
    foreach bez $bezpaths {
	set nubez {}
	foreach {x y} $bez {
	    lappend nubez [expr {$x*$dpi}] [expr {-$y*$dpi}]
	}
	set bez $nubez
	if {[namespace exists ::tkp]} {
	    set bez [linsert $bez 0 "M"]
	    set bez [linsert $bez 3 "C"]
	    $canv create path $bez \
		-fill "" -fillrule evenodd \
		-stroke black -strokelinecap round -strokelinejoin round \
		-strokewidth $strokewidth
	} else {
	    $canv create line $bez \
		-smooth raw -capstyle round -joinstyle round \
		-splinesteps 5 \
		-fill black -width $strokewidth
	}
    }
}


if {[info commands main] == {}} {
    package require tkpath

    if {[namespace exists ::tkp]} {
	global ::tkp::antialias
	set ::tkp::antialias 1
	global ::tkp::depixelize
	set ::tkp::depixelize 0
	tkp::canvas .c -width 1000 -height 250
    } else {
	set ::tk::mac::CGAntialiasLimit 0
	set ::tk::mac::useCGDrawing 1
	set ::tk::mac::useThemedToplevel 1
	set ::tk::mac::useThemedFrame 1
	canvas .c -width 1000 -height 250
    }

    global argv
    pack .c -expand 1 -fill both
    cncfont_load [lindex $argv 0]

    set msg  "The Quick Brown Fox Jumps Over the Lazy Dog.\n"
    append msg  "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG.\n"
    append msg  "The quick brown fox jumps over the lazy dog.\n"
    append msg  "WATCH To Vote Fj Lwellyn? bcdegpq rj TOY ZOZ Train\n"
    append msg  [lindex $argv 1]

    set fontname [lindex [cncfont_list] 0]
    cncfont_draw .c $fontname 0.25 -0.5 $msg 0.1875 [expr {1.0/32.0}]
}


