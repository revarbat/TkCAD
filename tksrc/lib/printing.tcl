proc print_init {} {
    global pageformat
    set pageformat [::maccarbonprint::pagesetup -dialog 0]
}
print_init


proc print_page_setup {parent} {
    global pageformat
    set res [::maccarbonprint::pagesetup -dialog 1 -parent $parent -pageformat $pageformat]
    if {$res != {}} {
        set pageformat $res
    }
}


proc print_canvas {parent canv} {
    global pageformat printObj
    ::maccarbonprint::pageformatconfigure $pageformat -resolution 300
    array set printconf [::maccarbonprint::pageformatconfigure $pageformat]
    foreach {px0 py0 px1 py1} $printconf(-adjustedpagerect) break
    set pageaspect [expr {(0.0+$px1-$px0)/(0.0+$py1-$py0)}]

    set numpages 1
    if {[info exists printObj]} {
        set res [::maccarbonprint::print -pageformat $pageformat -firstpage 1 -lastpage $numpages -parent $parent -printobject $printObj]
    } else {
        set res [::maccarbonprint::print -pageformat $pageformat -firstpage 1 -lastpage $numpages -parent $parent]
    }
    if {[llength $res] > 0} {
        set printObj [lindex $res 1]
        ::maccarbonprint::printcanvas $canv $printObj
        return 1
    }
    return 0
}


proc print_cadobjects {parent canv {all 0}} {
    global printInfo

    set file [wm title [winfo toplevel $canv]]
    set pwin [toplevel $parent.printwin]
    wm title $pwin "Print $file"
    wm group $pwin $parent
    wm resizable $pwin 0 0
    catch {wm attributes $pwin -maximizebox 0}
    catch {wm attributes $pwin -minimizebox 0}

    checkbutton $pwin.flipx -text "Flip X axis" -variable printInfo(flipx)
    checkbutton $pwin.flipy -text "Flip Y axis" -variable printInfo(flipy)
    checkbutton $pwin.invert -text "Invert Colors (White on Black)" -variable printInfo(invert)
    button $pwin.cancel -text Cancel -width 6 -command [list destroy $pwin]
    button $pwin.print -text Print -width 6 -default active -command [list print_cadobjects_2 $parent $canv $pwin $all]
    bind $pwin <Key-Escape> [list $pwin.cancel invoke]
    bind $pwin <Key-Return> [list $pwin.print invoke]
    pack $pwin.flipx -side top -anchor w -padx 10 -pady {10 5}
    pack $pwin.flipy -side top -anchor w -padx 10 -pady {5 5}
    pack $pwin.invert -side top -anchor w -padx 10 -pady {5 10}
    pack $pwin.print -side right -anchor e -padx 10 -pady {5 10}
    pack $pwin.cancel -side right -anchor e -padx 10 -pady {5 10}

    raise $pwin
    grab set $pwin
}


proc print_cadobjects_2 {parent canv pwin {all 0}} {
    global printInfo
    set flipx $printInfo(flipx)
    set flipy $printInfo(flipy)
    set invert $printInfo(invert)
    destroy $pwin

    global pageformat printObj
    ::maccarbonprint::pageformatconfigure $pageformat -resolution 300
    array set printconf [::maccarbonprint::pageformatconfigure $pageformat]
    foreach {px0 py0 px1 py1} $printconf(-adjustedpagerect) break

    set tmpimgs {}
    set numpages 1
    if {[info exists printObj]} {
        set res [::maccarbonprint::print -pageformat $pageformat -firstpage 1 -lastpage $numpages -parent $parent -printobject $printObj]
    } else {
        set res [::maccarbonprint::print -pageformat $pageformat -firstpage 1 -lastpage $numpages -parent $parent]
    }
    if {[llength $res] > 0} {
        set printObj [lindex $res 1]
        ::maccarbonprint::opendoc $printObj 1 $numpages
        set win [::maccarbonprint::openpage $printObj]

        set objids {}
        set layers [layer_ids $canv]
        foreach layerid $layers {
            if {!$all && ![layer_visible $canv $layerid]} {
                continue
            }
            set layerobjs [layer_objects $canv $layerid]
            set layerobjs [cadobjects_grouped_objects $canv $layerobjs]
            set objids [concat $objids $layerobjs]
        }
        foreach {minx miny maxx maxy} [cadobjects_objects_bbox $canv $objids] break

        set pdx [expr {$px1-$px0}]
        set pdy [expr {$py1-$py0}]
        set pcx [expr {($px0+$px1)/2.0}]
        set pcy [expr {($py0+$py1)/2.0}]

        set dx [expr {$maxx-$minx}]
        set dy [expr {$maxy-$miny}]
        set hx [expr {-($minx+$maxx)/2.0}]
        set hy [expr {-($miny+$maxy)/2.0}]

        set sx [expr {$pdx/$dx}]
        set sy [expr {$pdy/$dy}]
        if {$sx > 300.0} {
            set sx 300.0
        }
        if {$sy > 300.0} {
            set sy 300.0
        }
        if {$sx > $sy} {
            set sx $sy
        } else {
            set sy $sx
        }

        if {$flipx} {
            set sx [expr {-$sx}]
        }
        if {$flipy} {
            set sy [expr {-$sy}]
        }
        set sy [expr {-$sy}]
        set mat [matrix_transform translate $hx $hy  scale $sx $sy  translate $pcx $pcy]

        if {$invert} {
            set ix0 [expr {$minx-1}]
            set iy0 [expr {$miny-1}]
            set ix1 [expr {$maxx+1}]
            set iy1 [expr {$maxy+1}]
            set coords [list $ix0 $iy0 $ix1 $iy1]
            set coords [matrix_transform_coords $mat $coords]
            set coords [geometry_pointlist_bbox $coords]
            $win create rectangle $coords -fill black -outline black
        }

        if {$flipx || $flipy} {
            set allowed {ELLIPSE ARC BEZIER LINES IMAGE}
        } else {
            set allowed {ELLIPSE ARC BEZIER LINES IMAGE TEXT}
        }

        # Draw the picture on the page.
        foreach layerid $layers {
            if {!$all && ![layer_visible $canv $layerid]} {
                continue
            }
            set layerobjs [layer_objects $canv $layerid]
            set layerobjs [cadobjects_grouped_objects $canv $layerobjs]
            foreach objid $layerobjs {
                set dash  [cadobjects_object_getdatum $canv $objid "LINEDASH"]
                set color [cadobjects_object_getdatum $canv $objid "LINECOLOR"]
                set fill  [cadobjects_object_getdatum $canv $objid "FILLCOLOR"]
                set width [cadobjects_object_stroke_width $canv $objid]

                if {$dash != ""} {
                    set dash [dashpat $dash]
                }
                if {$color == ""} {
                    set color "black"
                }
                if {[string toupper $color] == "NONE"} {
                    if {[string toupper $fill] == "NONE" || $fill == ""} {
                        continue
                    }
                    set color ""
                } elseif {$invert} {
                    foreach {h s v} [color_to_hsv $color] break
                    set color [color_from_hsv $h $s [expr {1.0-$v}]]
                }
                if {[string toupper $fill] == "NONE"} {
                    set fill ""
                } elseif {$invert} {
                    foreach {h s v} [color_to_hsv $fill] break
                    set fill [color_from_hsv $h $s [expr {1.0-$v}]]
                }
                set width [expr {$width*abs($sx)}]

                foreach {dectype data} [cadobjects_object_decompose $canv $objid $allowed] {
                    switch -exact -- $dectype {
                        ELLIPSE {
                            foreach {cx cy rad1 rad2} $data break
                            set x0 [expr {$cx-$rad1}] 
                            set y0 [expr {$cy-$rad2}] 
                            set x1 [expr {$cx+$rad1}] 
                            set y1 [expr {$cy+$rad2}] 
                            set coords [list $x0 $y0 $x1 $y1]
                            set coords [matrix_transform_coords $mat $coords]
                            set coords [geometry_pointlist_bbox $coords]
                            $win create oval $coords -outline $color -fill $fill -width $width -dash $dash
                        }
                        ARC {
                            foreach {cx cy rad start extent} $data break
                            set x0 [expr {$cx-$rad}] 
                            set y0 [expr {$cy-$rad}] 
                            set x1 [expr {$cx+$rad}] 
                            set y1 [expr {$cy+$rad}] 
                            set coords [list $x0 $y0 $x1 $y1]
                            set coords [matrix_transform_coords $mat $coords]
                            set coords [geometry_pointlist_bbox $coords]
                            if {$sy > 0} {
                                set start [expr {0.0-$start-$extent}]
                            }
                            $win create arc {*}$coords -style arc -start $start -extent $extent -outline $color -fill $fill -width $width -dash $dash
                        }
                        BEZIER {
                            if {[llength $data] >= 8} {
                                set coords [matrix_transform_coords $mat $data]
                                if {[geometry_path_is_closed $coords]} {
                                    $win create polygon $coords -smooth raw -splinesteps 40 -outline $color -fill $fill -width $width -dash $dash
                                } else {
                                    $win create line $coords -smooth raw -splinesteps 40 -capstyle round -joinstyle round -fill $color -width $width -dash $dash
                                }
                            }
                        }
                        LINES {
                            if {[llength $data] >= 4} {
                                set coords [matrix_transform_coords $mat $data]
                                if {[geometry_path_is_closed $coords]} {
                                    $win create polygon $coords -outline $color -fill $fill -width $width -dash $dash
                                } else {
                                    $win create line $coords -joinstyle round -capstyle round -fill $color -width $width -dash $dash
                                }
                            }
                        }
                        TEXT {
                            foreach {cx cy txt font just} $data break
                            foreach {cx cy} [matrix_transform_coords $mat [list $cx $cy]] break
                            switch -exact -- $just {
                                left { set anchor sw }
                                center { set anchor s }
                                right { set anchor se }
                                default { set anchor sw }
                            }
                            set fsiz [lindex $font 1]
                            set fsiz [expr {int((300.0/72.0)*$fsiz+0.5)}]
                            if {$fsiz < 1} {
                                set fsiz 1
                            }
                            set font [lreplace $font 1 1 $fsiz]
                            set descent [font metrics $font -descent]
                            set cy [expr {int($cy+$descent+0.5)}]
                            $win create text $cx $cy -text $txt -font $font \
                                -fill $color -anchor $anchor
                        }
                        IMAGE {
                            foreach {cx cy wid height rot img} $data break
                            set pscx [expr {abs($wid*$sx)/[image width $img]}]
                            set pscy [expr {abs($height*$sy)/[image height $img]}]
                            # TODO: fix positioning for rotation, flipping, etc.
                            set img2 [image create photo]
                            lappend tmpimgs $img2
                            set mirror ""
                            if {$flipx&&$flipy} {
                                set mirror "-mirror"
                            } elseif {$flipx} {
                                set mirror "-mirror x"
                            } elseif {$flipy} {
                                set mirror "-mirror y"
                            }
                            image_copy $img $img2 -rotate $rot -scale $pscx $pscy {*}$mirror -filter Lanczos -background white -smoothedge 2
                            set coords [matrix_transform_coords $mat [list $cx $cy]]
                            foreach {cx cy} $coords break
                            $win create image $cx $cy -image $img2 -anchor center
                        }
                    }
                }
            }
        }
        ::maccarbonprint::closepage $printObj
        ::maccarbonprint::closedoc $printObj
        foreach tmpimg $tmpimgs {
            image delete $tmpimg
        }
        return 1
    }
    return 0
}


proc print_images {parent files} {
    global pageformat printObj
    ::maccarbonprint::pageformatconfigure $pageformat -resolution 300
    array set printconf [::maccarbonprint::pageformatconfigure $pageformat]
    foreach {px0 py0 px1 py1} $printconf(-adjustedpagerect) break
    set pageaspect [expr {(0.0+$px1-$px0)/(0.0+$py1-$py0)}]

    if {$printconf(-orientation) == "reverselandscape"} {
        set rotang -90.0
    } else {
        set rotang 90.0
    }
    set numpages [llength $files]
    if {[info exists printObj]} {
        set res [::maccarbonprint::print -pageformat $pageformat -firstpage 1 -lastpage $numpages -parent $parent -printobject $printObj]
    } else {
        set res [::maccarbonprint::print -pageformat $pageformat -firstpage 1 -lastpage $numpages -parent $parent]
    }
    if {[llength $res] > 0} {
        set printObj [lindex $res 1]
        ::maccarbonprint::opendoc $printObj 1 $numpages
        foreach file $files {
            # Calculate original image size and aspect ratio
            set img [image create photo -file $file]
            set imgw [image width $img]
            set imgh [image height $img]
            set imgaspect [expr {(0.0+$imgw)/(0.0+$imgh)}]

            # Make sure the photo's long axis matches the paper's long axis.
            set ang 0.0
            if {(($pageaspect < 1.0) && ($imgaspect > 1.0)) ||
                (($pageaspect > 1.0) && ($imgaspect < 1.0))
            } {
                # Needs rotating by 90 degrees.
                set ang $rotang
                set imgw [image height $img]
                set imgh [image width $img]
            }

            # Calculate the scaling factor needed to make the photo
            # fill the page.
            set scalex [expr {($px1-$px0)/$imgw}]
            set scaley [expr {($py1-$py0)/$imgh}]
            if {$scalex < $scaley} {
                set pscale $scaley
            } else {
                set pscale $scalex
            }

            # If we need to do some scaling or rotation, do them now.
            if {$ang != 0.0 || $pscale != 1.0} {
                set img2 [image create photo]
                image_copy $img $img2 -rotate $ang -scale $pscale -filter Lanczos
                image delete $img
                set img $img2
                set imgw [image width $img]
                set imgh [image height $img]
            }

            set win [::maccarbonprint::openpage $printObj]

            # Center the image on the page.
            set ix [expr {(($px1-$px0)/2.0)-($imgw/2.0)}]
            set iy [expr {(($py1-$py0)/2.0)-($imgh/2.0)}]

            # Draw the picture on the page.
            $win create image $ix $iy -anchor nw -image $img

            # Close down.
            ::maccarbonprint::closepage $printObj

            # free some memory
            image delete $img
        }
        ::maccarbonprint::closedoc $printObj
        return 1
    }
    return 0
}


proc print_sized_images {parent width height files} {
    global pageformat printObj
    set resolution 300
    ::maccarbonprint::pageformatconfigure $pageformat -resolution $resolution
    set targw [expr {1.0*$width*$resolution}]
    set targh [expr {1.0*$height*$resolution}]

    array set printconf [::maccarbonprint::pageformatconfigure $pageformat]
    foreach {pgx0 pgy0 pgx1 pgy1} $printconf(-adjustedpagerect) break
    foreach {ppx0 ppy0 ppx1 ppy1} $printconf(-adjustedpaperrect) break

    set mlft [expr {abs($ppx0-$pgx0)}]
    set mrgt [expr {abs($ppx1-$pgx1)}]
    set mtop [expr {abs($ppy0-$pgy0)}]
    set mbot [expr {abs($ppy1-$pgy1)}]

    set maxxmarg [expr {($mlft>$mrgt)?$mlft:$mrgt}]
    set maxymarg [expr {($mtop>$mbot)?$mtop:$mbot}]

    set px0 [expr {$ppx0+$maxxmarg}]
    set px1 [expr {$ppx1-$maxxmarg}]
    set py0 [expr {$ppy0+$maxymarg}]
    set py1 [expr {$ppy1-$maxymarg}]

    set pxoff [expr {$px0-$pgx0}]
    set pyoff [expr {$py0-$pgy0}]

    set pwidth [expr {(0.0+$px1-$px0)}]
    set pheight [expr {(0.0+$py1-$py0)}]

    # Estimate prints per page
    set cols_norm [expr {int(1.0*$pwidth/$targw)}]
    set rows_norm [expr {int(1.0*$pheight/$targh)}]
    set cols_rot  [expr {int(1.0*$pwidth/$targh)}]
    set rows_rot  [expr {int(1.0*$pheight/$targw)}]
    set pics_norm [expr {$rows_norm*$cols_norm}]
    set pics_rot  [expr {$rows_rot*$cols_rot}]

    set rows $rows_norm
    set cols $cols_norm
    if {$pics_rot > $pics_norm} {
        set rows $rows_rot
        set cols $cols_rot

        set tmp $targh
        set targh $targw
        set targw $tmp
    } elseif {$pics_rot == $pics_norm} {
        set colwidth [expr {1.0*$pwidth/$cols_norm}]
        set rowwidth [expr {1.0*$pheight/$rows_norm}]
        set colgut_norm [expr {$colwidth-$targw}]
        set rowgut_norm [expr {$rowwidth-$targh}]
        set colwidth [expr {1.0*$pwidth/$cols_rot}]
        set rowwidth [expr {1.0*$pheight/$rows_rot}]
        set colgut_rot [expr {$colwidth-$targh}]
        set rowgut_rot [expr {$rowwidth-$targw}]
        if {abs($colgut_norm-$rowgut_norm) > abs($colgut_rot-$rowgut_rot)} {
            set rows $rows_rot
            set cols $cols_rot

            set tmp $targh
            set targh $targw
            set targw $tmp
        }
    }

    set colwidth [expr {1.0*$pwidth/$cols}]
    set rowwidth [expr {1.0*$pheight/$rows}]

    if {$printconf(-orientation) == "reverselandscape"} {
        set rotang -90.0
    } else {
        set rotang 90.0
    }
    set numpages [llength $files]
    if {[info exists printObj]} {
        set res [::maccarbonprint::print -pageformat $pageformat -firstpage 1 -lastpage $numpages -parent $parent -printobject $printObj]
    } else {
        set res [::maccarbonprint::print -pageformat $pageformat -firstpage 1 -lastpage $numpages -parent $parent]
    }
    if {[llength $res] > 0} {
        set printObj [lindex $res 1]
        ::maccarbonprint::opendoc $printObj 1 $numpages

        foreach file $files {
            # Load file and calculate original size.
            set img [image create photo -file $file]
            set imgw [image width $img]
            set imgh [image height $img]

            # Determine if we should rotate the image
            set dorot 0
            set iasp [expr {(0.0+$imgw)/(0.0+$imgh)}]
            set tasp [expr {(0.0+$targw)/(0.0+$targh)}]
            if {($iasp>1.0) != ($tasp>1.0)} {
                # rotate to match target asec ratio
                set dorot 1
            }

            # Initialize values as if we're not rotating.
            set ang 0.0

            # Fix values for if we are rotating.
            if {$dorot} {
                set ang $rotang

                set tmp $imgw
                set imgw $imgh
                set imgh $tmp
            }

            # Calculate the scaling factor needed to make the photo
            #  the right size.
            set scalex [expr {$targw/$imgw}]
            set scaley [expr {$targh/$imgh}]
            if {$scalex < $scaley} {
                set pscale $scaley
            } else {
                set pscale $scalex
            }

            # If we need to do some scaling or rotation, do them now.
            if {$ang != 0.0 || $pscale != 1.0} {
                set img2 [image create photo]
                image_copy $img $img2 -rotate $ang -scale $pscale -filter Lanczos
                image delete $img

                set imgw [image width $img2]
                set imgh [image height $img2]

                set tx0 [expr {int(($imgw-$targw)/2.0)}]
                set ty0 [expr {int(($imgh-$targh)/2.0)}]
                set tx1 [expr {int($tx0+$targw+0.5)}]
                set ty1 [expr {int($ty0+$targh+0.5)}]

                set img [image create photo]
                $img copy $img2 -from $tx0 $ty0 $tx1 $ty1
                image delete $img2

                set imgw [image width $img]
                set imgh [image height $img]
            }

            set win [::maccarbonprint::openpage $printObj]

            # Draw images on page
            for {set j 0} {$j < $rows} {incr j} {
                for {set i 0} {$i < $cols} {incr i} {
                    set ix [expr {int($pxoff+(($i+0.5)*$colwidth)-($imgw/2.0)+0.5)}]
                    set iy [expr {int($pyoff+(($j+0.5)*$rowwidth)-($imgh/2.0)+0.5)}]
                    $win create image $ix $iy -anchor nw -image $img
                }
            }


            # Close down.
            ::maccarbonprint::closepage $printObj

            # free some memory
            image delete $img
        }
        ::maccarbonprint::closedoc $printObj
        return 1
    }
    return 0
}


# vim: set ts=8 sw=4 nowrap expandtab: settings

