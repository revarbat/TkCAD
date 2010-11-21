proc snapswin_init {} {
    global snapswinInfo
    set snapswinInfo(SNAPTYPES) {
        grid            "&Grid"              1
        controlpoints   "Control &Points"    1
        midpoints       "&Midpoints"         1
        quadrants       "&Quadrants"         1
        intersect       "In&tersections"     0
        contours        "&Lines and Arcs"    0
        centerlines     "&Centerlines"       0
        tangents        "&Tangents"          0
    }
}


proc snapswin_create {base} {
    global snapswinInfo
    set snapswinInfo(BNUM-$base) 0
    toplevel $base -padx 5 -pady 8

    grid columnconfigure $base 0 -minsize 10
    grid columnconfigure $base 2 -minsize 10
    grid columnconfigure $base 4 -weight 1

    set snapswinInfo(CURRROW-$base) 1
    set snapswinInfo(CURRCOL-$base) 1

    after 1000 [list snapswin_update $base]
    return $base
}


proc snapswin_update {base} {
    set foc [focus]
    if {$foc == ""} {
        after 1000 [list snapswin_update $base]
        return
    }
    global snapswinInfo
    set allcb $base.all
    set win [mainwin_current]
    if {$win == "" || $win == "."} {
        after 1000 [list snapswin_update $base]
        return
    }
    set canv [mainwin_get_canvas $win]
    if {![winfo exists $allcb]} {
        set snapswinInfo(SNAP-all) 1
        checkbutton $allcb -text "All Snaps" -underline 0 -font TkSmallCaptionFont -borderwidth 0 -highlightthickness 1 -pady 0 -state normal -variable snapswinInfo(SNAP-all) -command "snapswin_update $base"
        grid $allcb -column 0 -row 0 -sticky w -columnspan 2
    }
    if {[bind $canv <Option-Key-a>] == ""} {
        bind $canv <Option-Key-a> "$allcb invoke"
    }
    set col $snapswinInfo(CURRCOL-$base)
    set row $snapswinInfo(CURRROW-$base)
    foreach {snaptype snapname defval} [snap_types] {
        set accel ""
        set cbx $base.cbx-$snaptype
        set upos [string first "&" $snapname]
        if {$upos >= 0} {
            set snapname [string replace $snapname $upos $upos]
            set accel [string tolower [string index $snapname $upos]]
        }
        if {![winfo exists $cbx]} {
            set snapswinInfo(SNAP-$snaptype) $defval
            set cbx [checkbutton $base.cbx-$snaptype -text $snapname -underline $upos -font TkSmallCaptionFont -borderwidth 0 -highlightthickness 1 -pady 0 -variable snapswinInfo(SNAP-$snaptype)]
            grid $cbx -column $col -row $row -sticky w
            if {[incr col 2] >= 4} {
                set col 1
                incr row
            }
        }
        if {$accel != ""} {
            if {[bind $canv <Option-Key-$accel>] == ""} {
                bind $canv <Option-Key-$accel> "$cbx invoke"
            }
        }
        if {$snapswinInfo(SNAP-all)} {
            $cbx configure -state normal
        } else {
            $cbx configure -state disabled
        }
    }
    set snapswinInfo(CURRCOL-$base) $col
    set snapswinInfo(CURRROW-$base) $row
}


proc snap_types {} {
    global snapswinInfo
    return $snapswinInfo(SNAPTYPES)
}


proc snap_exists {snaptype} {
    global snapswinInfo
    return [info exists snapswinInfo(SNAP-$snaptype)]
}


proc snap_add {snaptype snapname defval} {
    global snapswinInfo
    lappend snapswinInfo(SNAPTYPES) $snaptype $snapname $defval
    set snapswinInfo(SNAP-$snaptype) $defval
}


proc snap_is_enabled {snaptype} {
    global snapswinInfo
    if {![info exists snapswinInfo(SNAP-$snaptype)]} {
        return 0
    }
    return $snapswinInfo(SNAP-$snaptype)
}



snapswin_init


# vim: set ts=4 sw=4 nowrap expandtab: settings


