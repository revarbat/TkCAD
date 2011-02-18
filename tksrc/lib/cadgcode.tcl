proc cadgcode_compare_pathset_insideness {pathset1 pathset2} {
    constants radtodeg
    set ps1path {}
    set ps2path {}
    foreach path $pathset1 {
        set ptype [lindex $path 0]
        switch -exact -- $ptype {
            ARC {
                foreach {type cx cy rad dir x0 y0 x1 y1} $path break
                set start [expr {atan2($y0-$cy,$x0-$cx)*$radtodeg}]
                set end [expr {atan2($y1-$cy,$x1-$cx)*$radtodeg}]
                set extent [expr {$end-$start}]
                if {$extent < 0 && $dir == "ccw"} {
                    set extent [expr {$extent+360.0}]
                } elseif {$extent > 0 && $dir == "cw"} {
                    set extent [expr {$extent-360.0}]
                }
                bezutil_append_line_arc ps1path $cx $cy $rad $rad $start $extent
            }
            CIRCLE {
                foreach {type cx cy rad x0 y0 x1 y1} $path break
                set start [expr {atan2($y0-$cy,$x0-$cx)*$radtodeg}]
                bezutil_append_line_arc ps1path $cx $cy $rad $rad $start 359.9999
            }
            LINES {
                foreach {type coords x0 y0 x1 y1} $path break
                foreach {x y} $coords {
                    lappend ps1path $x $y
                }
            }
        }
    }

    foreach path $pathset2 {
        set ptype [lindex $path 0]
        switch -exact -- $ptype {
            ARC {
                foreach {type cx cy rad dir x0 y0 x1 y1} $path break
                set start [expr {atan2($y0-$cy,$x0-$cx)*$radtodeg}]
                set end [expr {atan2($y1-$cy,$x1-$cx)*$radtodeg}]
                set extent [expr {$end-$start}]
                if {$extent < 0 && $dir == "ccw"} {
                    set extent [expr {$extent+360.0}]
                } elseif {$extent > 0 && $dir == "cw"} {
                    set extent [expr {$extent-360.0}]
                }
                bezutil_append_line_arc ps2path $cx $cy $rad $rad $start $extent
            }
            CIRCLE {
                foreach {type cx cy rad x0 y0 x1 y1} $path break
                set start [expr {atan2($y0-$cy,$x0-$cx)*$radtodeg}]
                bezutil_append_line_arc ps2path $cx $cy $rad $rad $start 359.9999
            }
            LINES {
                foreach {type coords x0 y0 x1 y1} $path break
                foreach {x y} $coords {
                    lappend ps2path $x $y
                }
            }
        }
    }

    foreach {ax0 ay0} [lrange $ps1path 0 1] break
    foreach {axe aye} [lrange $ps1path end-1 end] break
    foreach {bx0 by0} [lrange $ps2path 0 1] break
    foreach {bxe bye} [lrange $ps2path end-1 end] break

    if {hypot($aye-$ay0,$axe-$ax0) <= 1e-5} {
        if {[llength $ps1path] > 3} {
            if {[mlcnc_path_circumscribes_point $ps1path $bx0 $by0]} {
                return -1
            }
        }
    }
    if {hypot($bye-$by0,$bxe-$bx0) <= 1e-5} {
        if {[llength $ps2path] > 3} {
            if {[mlcnc_path_circumscribes_point $ps2path $ax0 $ay0]} {
                return 1
            }
        }
    }
    return 0
}


proc cadgcode_generate {canv} {
    global cadgcodeInfo

    constants degtorad
    set filetypes {
        {"NC Files" .nc}
        {"CNC Files" .cnc}
        {"Tap Files" .tap}
    }
    set mainwin [cadobjects_mainwin $canv]
    set winsys ""
    catch {set winsys [tk windowingsystem]}

    set have_cuts 0
    set objcount 0
    foreach layerid [layer_ids $canv] {
        if {![layer_visible $canv $layerid]} {
            continue
        }
        set layerbit [layer_cutbit $canv $layerid]
        set lobjs [layer_objects $canv $layerid]
        set lobjs [cadobjects_grouped_objects $canv $lobjs]
        foreach objid $lobjs {
            set cutbit [cadobjects_object_getdatum $canv $objid "CUTBIT"]
            if {$cutbit == "" || $cutbit == "inherit"} {
                set cutbit $layerbit
            }
            if {$cutbit > 0} {
                set have_cuts 1
                incr objcount
            }
        }
    }
    if {!$have_cuts} {
        tk_messageBox -icon warning -parent $mainwin -type ok -message "No cuts to write out."
        return
    }

    set filename [fileformat_get_filename $mainwin]
    if {[info exists cadgcodeInfo(NCFILE-$canv)]} {
        set filename $cadgcodeInfo(NCFILE-$canv)
    }
    set defext ".nc"
    set initdir [file dirname $filename]
    set initfile [file rootname [file tail $filename]]
    if {$initfile == ""} {
        set initfile "Untitled"
    }
    append initfile $defext

    # TODO: Make dialog to get the following options:
    #    Milling type: Climb/Conventional/As Drawn/Don't Care.
    #    G-Code units type: inches/mm.
    #    Stock material.
    #    Stock Thickness.  Safe Z.  Stock top.
    #    Enable Optimization.
    #    Enable Flood cooling.
    #    Re-zero/Offset X-Y for part.

    set cadgcodeInfo(STOCK_MATERIAL) [cadobjects_get_material $canv]
    set cadgcodeInfo(MILL_UNITS) "Inches"
    set cadgcodeInfo(SAFEZ) 1.0

    set base [toplevel .gcgen -padx 20 -pady 20]
    wm title $base "G-Code Generation"

    set smats [mlcnc_stock_types]
    set smatl  [label $base.smatl -text "Material to Mill"]
    tk_optionMenu $base.smatmb cadgcodeInfo(STOCK_MATERIAL) {*}$smats
    set smatmb $base.smatmb
    $smatmb configure -width 20

    set munitl  [label $base.munitl -text "Units"]
    tk_optionMenu $base.munitmb cadgcodeInfo(MILL_UNITS) Inches Millimeters
    set munitmb $base.munitmb
    $munitmb configure -width 20

    set safezl [label $base.safezl -text "Safe Z"]
    set safeze [entry $base.safeze \
                    -textvariable cadgcodeInfo(SAFEZ) \
                    -width 8 -validate focus \
                    -validatecommand "util_number_validate %P {} 1" \
                    -invalidcommand "bell"]

    set cadgcodeInfo(DLOGRES) 0
    set btns [frame $base.btns]
    button $btns.gen -text Generate -default active -command "set cadgcodeInfo(DLOGRES) 1 ; destroy $base"
    button $btns.cancel -text Cancel -command "destroy $base"
    pack $btns.cancel -side right
    pack $btns.gen -side right -padx 10

    grid columnconfigure $base 1 -minsize 5
    grid columnconfigure $base 2 -weight 1
    grid $smatl   x $smatmb   -sticky w
    #grid $munitl  x $munitmb  -sticky w
    grid $safezl  x $safeze   -sticky w
    grid $btns    - -         -sticky ew -pady {20 0}

    bind $base <Key-Escape> "$btns.cancel invoke ; break"
    bind $base <Key-Return> "$btns.gen invoke ; break"

    grab set $base
    tkwait window $base
    grab release $base

    if {!$cadgcodeInfo(DLOGRES)} {
        return
    }
    cadobjects_set_material $canv $cadgcodeInfo(STOCK_MATERIAL)
    set safez $cadgcodeInfo(SAFEZ)

    if {$winsys == "aqua"} {
        set filename [tk_getSaveFile \
            -title "Save NC File As..." \
            -message "Save NC File As..." \
            -parent $mainwin \
            -initialdir $initdir \
            -initialfile $initfile \
            -filetypes $filetypes \
            -defaultextension $defext \
            ]
    } else {
        set filename [tk_getSaveFile \
            -title "Save NC File As..." \
            -parent $mainwin \
            -initialdir $initdir \
            -initialfile $initfile \
            -filetypes $filetypes \
            -defaultextension $defext \
            ]
    }
    if {$filename == ""} {
        return
    }
    if {[file extension $filename] != $defext} {
        append filename $defext
    }

    progwin_create .nc-progwin "tkCAD G-Code" "Generating G-Code file..."
    set cadgcodeInfo(NCFILE-$canv) $filename
    set f [open $filename "w"]

    puts $f [mlcnc_g_start]
    if {$cadgcodeInfo(MILL_UNITS) == "Inches"} {
        puts $f "G20"
    } else {
        puts $f "G21"
    }

    set objnum 0
    set prevbit ""
    set allowed {ARC LINES CIRCLE GCODE}

    # Visible Layers are generated in order.
    #   Within layers, cuts are sorted by the different bits used, lowest to highest bit number.
    #     Within a set of cuts using the same bit, most positive depths are generated first.
    foreach layerid [layer_ids $canv] {
        if {![layer_visible $canv $layerid]} {
            continue
        }
        catch {unset bitobjs}
        set layerbit [layer_cutbit $canv $layerid]
        set layerdepth [layer_cutdepth $canv $layerid]
        set lobjs [layer_objects $canv $layerid]
        set lobjs [cadobjects_grouped_objects $canv $lobjs]
        foreach objid $lobjs {
            set cutbit [cadobjects_object_getdatum $canv $objid "CUTBIT"]
            set cutdepth [cadobjects_object_getdatum $canv $objid "CUTDEPTH"]
            if {$cutbit == "" || $cutbit == "inherit"} {
                set cutbit $layerbit
            }
            if {$cutdepth == "" || $cutdepth == 0.0} {
                set cutdepth $layerdepth
            }
            if {$cutbit > 0 && $cutdepth < 0.0} {
                lappend bitobjs($cutbit) $objid
            }
        }
        set firstobj 1
        foreach cutbit [lsort -integer [array names bitobjs]] {
            catch {unset paths}
            catch {unset pathstarts}
            catch {unset pathends}
            catch {unset depthpaths}
            set pathnum 0
            set depths {}
            foreach objid $bitobjs($cutbit) {

                # Decompose objects into arcs and lines, and  remember
                # them by endpoints for later optimization.
                set cutdepth [cadobjects_object_getdatum $canv $objid "CUTDEPTH"]
                if {$cutdepth == "" || $cutdepth == 0.0} {
                    set cutdepth $layerdepth
                }
                set cutdepth [format "%.4f" $cutdepth]
                foreach {dectype data} [cadobjects_object_decompose $canv $objid $allowed] {
                    progwin_callback .nc-progwin $objcount $objnum
                    switch -exact -- $dectype {
                        ARC {
                            foreach {cx cy rad start extent} $data break
                            set x0 [expr {$rad*cos($start*$degtorad)+$cx}]
                            set y0 [expr {$rad*sin($start*$degtorad)+$cy}]
                            set x1 [expr {$rad*cos(($start+$extent)*$degtorad)+$cx}]
                            set y1 [expr {$rad*sin(($start+$extent)*$degtorad)+$cy}]
                            set dir cw
                            if {$extent > 0.0} {
                                set dir "ccw"
                            }
                            set paths($pathnum) [list ARC $cx $cy $rad $dir $x0 $y0 $x1 $y1]
                        }
                        CIRCLE {
                            foreach {cx cy rad} $data break
                            set x0 [expr {$cx+$rad}]
                            set y0 $cy
                            set x1 $x0
                            set y1 $y0
                            set paths($pathnum) [list CIRCLE $cx $cy $rad $x0 $y0 $x1 $y1]
                        }
                        LINES {
                            set coords $data
                            lassign [lrange $coords 0 1] x0 y0
                            lassign [lrange $coords end-1 end] x1 y1
                            set paths($pathnum) [list LINES $coords $x0 $y0 $x1 $y1]
                        }
                    }
                    set spt [format "%.4f,%.4f,%.4f" $x0 $y0 $cutdepth]
                    set ept [format "%.4f,%.4f,%.4f" $x1 $y1 $cutdepth]
                    lappend pathstarts($spt) $pathnum
                    lappend pathends($ept) $pathnum
                    if {$cutdepth ni $depths} {
                        lappend depths $cutdepth
                    }
                    lappend depthpaths($cutdepth) $pathnum
                    incr pathnum
                    incr objnum
                }
            }

            if {$cutbit != $prevbit} {
                if {$firstobj} {
                    puts $f [format "G0 Z%.4f" $safez]
                    set firstobj 0
                }
                puts $f [mlcnc_g_set_tool $cutbit]
                set prevbit $cutbit
            }
            set rapiddepth [mlcnc_rapid_z]
            set maxcut [mlcnc_cutdepth]

            foreach cutdepth [lsort -decreasing $depths] {

                # Optimize paths by joining connected paths into pathsets.
                set dpaths $depthpaths($cutdepth)
                catch {unset usedpaths}
                set pathsets {}
                while {1} {
                    set spath -1
                    foreach pnum $dpaths {
                        if {![info exists usedpaths($pnum)]} {
                            set spath $pnum
                            break
                        }
                    }
                    if {$spath < 0} break
                    set currpathset [list $paths($spath)]

                    # Find path parts before current path part.
                    set bpath $spath
                    while {1} {
                        # Mark path as handled.
                        set usedpaths($bpath) 1
                        set pos [lsearch -exact $dpaths $bpath]
                        if {$pos >= 0} {
                            set dpaths [lreplace $dpaths $pos $pos]
                        }
                        set opath $bpath

                        # Get endpoint info for current path segment.
                        switch -exact -- [lindex $paths($bpath) 0] {
                            ARC {
                                foreach {type cx cy rad dir x0 y0 x1 y1} $paths($bpath) break
                            }
                            CIRCLE {
                                foreach {type cx cy rad x0 y0 x1 y1} $paths($bpath) break
                            }
                            LINES {
                                foreach {type coords x0 y0 x1 y1} $paths($bpath) break
                            }
                        }
                        set spt [format "%.4f,%.4f,%.4f" $x0 $y0 $cutdepth]

                        # Check if another unused segment's start point matches.
                        set bpath -1
                        if {[info exists pathstarts($spt)]} {
                            foreach pnum $pathstarts($spt) {
                                if {![info exists usedpaths($pnum)]} {
                                    # Join the first unused matching path segment to the start of the pathset.
                                    # We need to reverse it.
                                    switch -exact -- [lindex $paths($pnum) 0] {
                                        ARC {
                                            foreach {btype bcx bcy brad bdir bx0 by0 bx1 by1} $paths($pnum) break
                                            set revdir [expr {$bdir=="cw"?"ccw":"cw"}]
                                            set revpath [list $btype $bcx $bcy $brad $revdir $bx1 $by1 $bx0 $by0]
                                        }
                                        CIRCLE {
                                            foreach {btype bcx bcy brad bx0 by0 bx1 by1} $paths($pnum) break
                                            set revpath [list $btype $bcx $bcy $brad $bx1 $by1 $bx0 $by0]
                                        }
                                        LINES {
                                            foreach {btype bcoords bx0 by0 bx1 by1} $paths($pnum) break
                                            set revcoords [line_coords_reverse $bcoords]
                                            set revpath [list $btype $revcoords $bx1 $by1 $bx0 $by0]
                                        }
                                    }
                                    set paths($pnum) $revpath
                                    set bpath $pnum
                                    set currpathset [linsert $currpathset 0 $revpath]
                                    break
                                }
                            }
                        }
                        if {$bpath >= 0} continue

                        set bpath -1
                        # Check if another unused segment's end point matches.
                        if {[info exists pathends($spt)]} {
                            foreach pnum $pathends($spt) {
                                if {![info exists usedpaths($pnum)]} {
                                    # Join the first unused matching path segment to the start of the pathset.
                                    set bpath $pnum
                                    set currpathset [linsert $currpathset 0 $paths($pnum)]
                                    break
                                }
                            }
                        }
                        if {$bpath < 0} break
                    }

                    # Find path parts after current path part.
                    set bpath $spath
                    while {1} {
                        # Mark path segment as handled.
                        set usedpaths($bpath) 1
                        set pos [lsearch -exact $dpaths $bpath]
                        if {$pos >= 0} {
                            set dpaths [lreplace $dpaths $pos $pos]
                        }
                        set opath $bpath

                        # Get endpoint info for current path segment.
                        switch -exact -- [lindex $paths($bpath) 0] {
                            ARC {
                                foreach {type cx cy rad dir x0 y0 x1 y1} $paths($bpath) break
                            }
                            CIRCLE {
                                foreach {type cx cy rad x0 y0 x1 y1} $paths($bpath) break
                            }
                            LINES {
                                foreach {type coords x0 y0 x1 y1} $paths($bpath) break
                            }
                        }
                        set spt [format "%.4f,%.4f,%.4f" $x1 $y1 $cutdepth]

                        # Check if another unused segment's start point matches.
                        set bpath -1
                        if {[info exists pathstarts($spt)]} {
                            foreach pnum $pathstarts($spt) {
                                if {![info exists usedpaths($pnum)]} {
                                    # Join the first unused matching path segment to the start of the pathset.
                                    set bpath $pnum
                                    lappend currpathset $paths($pnum)
                                    break
                                }
                            }
                        }
                        if {$bpath >= 0} continue

                        # Check if another unused segment's end point matches.
                        set bpath -1
                        if {[info exists pathends($spt)]} {
                            foreach pnum $pathends($spt) {
                                if {![info exists usedpaths($pnum)]} {
                                    # Join the first unused matching path segment to the start of the pathset.
                                    # We need to reverse it.
                                    switch -exact -- [lindex $paths($pnum) 0] {
                                        ARC {
                                            foreach {btype bcx bcy brad bdir bx0 by0 bx1 by1} $paths($pnum) break
                                            set revdir [expr {$bdir=="cw"?"ccw":"cw"}]
                                            set revpath [list $btype $bcx $bcy $brad $revdir $bx1 $by1 $bx0 $by0]
                                        }
                                        CIRCLE {
                                            foreach {btype bcx bcy brad bx0 by0 bx1 by1} $paths($pnum) break
                                            set revpath [list $btype $bcx $bcy $brad $bx1 $by1 $bx0 $by0]
                                        }
                                        LINES {
                                            foreach {btype bcoords bx0 by0 bx1 by1} $paths($pnum) break
                                            set revcoords [line_coords_reverse $bcoords]
                                            set revpath [list $btype $revcoords $bx1 $by1 $bx0 $by0]
                                        }
                                    }
                                    set paths($pnum) $revpath
                                    set bpath $pnum
                                    lappend currpathset $revpath
                                    break
                                }
                            }
                        }
                        if {$bpath < 0} break
                    }

                    lappend pathsets $currpathset
                }

                # Do greedy distance-to-next-pathset ordering optimization.
                set pathsetcnt [llength $pathsets]
                for {set i 0} {$i < $pathsetcnt} {incr i} {
                    set pathset1 [lindex $pathsets $i]
                    set path1 [lindex $pathset1 end]
                    lassign [lrange $path1 end-3 end] ax0 ay0 ax1 ay1
                    set mind 9e99
                    set minj ""
                    set rev 0
                    for {set j [expr {$i+1}]} {$j < $pathsetcnt} {incr j} {
                        set pathset2 [lindex $pathsets $j]

                        set path2 [lindex $pathset2 0]
                        lassign [lrange $path2 end-3 end] bx0 by0 bx1 by1
                        set d [expr {hypot($ay1-$by0,$ax1-$bx0)}]
                        if {$minj == "" || $d < $mind} {
                            set mind $d
                            set minj $j
                            set rev 0
                        }

                        set path3 [lindex $pathset2 end]
                        lassign [lrange $path3 end-3 end] cx0 cy0 cx1 cy1
                        set d [expr {hypot($ay1-$cy1,$ax1-$cx1)}]
                        if {$minj == "" || $d < $mind} {
                            set mind $d
                            set minj $j
                            set rev 1
                        }
                    }
                    if {$minj != ""} {
                        set pathset [lindex $pathsets $minj]
                        if {$rev} {
                            set nupathset {}
                            for {set k [expr {[llength $pathset]-1}]} {$k >= 0} {incr k -1} {
                                set path [lindex $pathset $k]
                                switch -exact -- [lindex $path 0] {
                                    ARC {
                                        foreach {type cx cy rad dir x0 y0 x1 y1} $path break
                                        set revdir [expr {$dir=="cw"?"ccw":"cw"}]
                                        set path [list $type $cx $cy $rad $revdir $x1 $y1 $x0 $y0]
                                    }
                                    CIRCLE {
                                        foreach {type cx cy rad x0 y0 x1 y1} $path break
                                        set path [list $type $cx $cy $rad $x1 $y1 $x0 $y0]
                                    }
                                    LINES {
                                        foreach {type coords x0 y0 x1 y1} $path break
                                        set revcoords [line_coords_reverse $coords]
                                        set path [list $type $revcoords $x1 $y1 $x0 $y0]
                                    }
                                }
                                lappend nupathset $path
                            }
                            set pathset $nupathset
                        }
                        set pathsets [lreplace $pathsets $minj $minj]
                        set pathsets [linsert $pathsets [expr {$i+1}] $pathset]
                    }
                }

                # Sort paths by insideness.  At least for closed line paths.
                set pathsets [lsort -decreasing -command cadgcode_compare_pathset_insideness $pathsets]

                # All path parts have been connected.  Lets output results now.
                set passes [expr {ceil(abs($cutdepth)/$maxcut)}]
                set drop [expr {abs($cutdepth/$passes)}]
                set cutwidth [mlcnc_tooldiam $cutbit]
                set lastx 9e99
                set lasty 9e99
                set lastz 9e99
                foreach pathset $pathsets {
                    set firstpath [lindex $pathset 0]
                    set lastpath [lindex $pathset end]
                    lassign [lrange $firstpath end-3 end] ax0 ay0 ax1 ay1
                    lassign [lrange $lastpath end-3 end] bx0 by0 bx1 by1
                    set isfirst 1
                    for {set z -$drop} {$z >= $cutdepth} {set z [expr {$z-$drop}]} {
                        if {hypot($lasty-$ay0,$lastx-$ax0) > $cutwidth / 1.8 || $lastz < $z} {
                            puts $f [format "G0 Z%.4f" $rapiddepth]
                            puts $f [mlcnc_g_goto $ax0 $ay0]
                        } else {
                            puts $f [format "G1 X%.4f Y%.4f" $ax0 $ay0]
                        }
                        puts $f [format "G1 Z%.4f F#1000" $z]
                        foreach path $pathset {
                            switch -exact -- [lindex $path 0] {
                                ARC {
                                    foreach {type cx cy rad dir x0 y0 x1 y1} $path break
                                    set ioff [expr {$cx-$x0}]
                                    set joff [expr {$cy-$y0}]
                                    if {$dir == "cw"} {
                                        puts $f [format "G2 X%.4f Y%.4f I%.7f J%.7f F#1001" $x1 $y1 $ioff $joff]
                                    } else {
                                        puts $f [format "G3 X%.4f Y%.4f I%.7f J%.7f F#1001" $x1 $y1 $ioff $joff]
                                    }
                                }
                                CIRCLE {
                                    foreach {type cx cy rad x0 y0 x1 y1} $path break
                                    set ioff [expr {$cx-$x0}]
                                    set joff [expr {$cy-$y0}]
                                    puts $f [format "G2 X%.4f Y%.4f I%.7f J%.7f F#1001" $x1 $y1 $ioff $joff]
                                }
                                LINES {
                                    foreach {type coords x0 y0 x1 y1} $path break
                                    puts $f "F#1001"
                                    foreach {x y} [lrange $coords 2 end] {
                                        puts $f [format "G1 X%.4f Y%.4f" $x $y]
                                    }
                                }
                            }
                        }
                        set lastx $x1
                        set lasty $y1
                        set lastz $z
                    }
                    #puts $f [format "G0 Z%.4f" $rapiddepth]
                }
            }
        }
    }
    puts $f [format ""]
    puts $f [format "G0 Z%.4f" $safez]
    puts $f [format "M9           ( Stop coolant. )"]
    puts $f [format "M5           ( Stop spindle. )"]
    puts $f [format "M30          ( Stop program. )"]

    close $f
    progwin_destroy .nc-progwin

    set res [tk_messageBox -type yesno -default no -parent $mainwin -icon question -title "Backtrace G-Code?" -message "Would you like to view a backtrace of the generated G-Code file?"]
    if {$res == yes} {
        cadgcode_backtrace_start $filename
    }
}


proc cadgcode_backtrace_start {{filename ""}} {
    global root_dir
    set interp [interp create]
    $interp eval { package require Tk }
    foreach var [info globals tcl*] {
        upvar #0 $var val
        if {[llength [array names val]] > 0} {
            $interp eval "global [list $var] ; array set [list $var] [list [array get val]]"
        } else {
            $interp eval "global [list $var] ; set [list $var] [list $val]"
        }
    }
    if {$filename != ""} {
        $interp eval "global argc ; set argc 1"
        $interp eval "global argv ; set argv [list [list $filename]]"
    } else {
        $interp eval "global argc ; set argc 0"
        $interp eval "global argv ; set argv {}"
    }
    $interp eval "rename exit _real_exit"
    $interp alias exit cadgcode_backtrace_exit $interp
    $interp eval "source [list [file join $root_dir lib backtracer.tcl]]"
}


proc cadgcode_backtrace_exit {interp {val 0}} {
    interp delete $interp
}



# vim: set ts=4 sw=4 nowrap expandtab: settings

