
proc progwin_create {win title caption} {
    global progwinInfo
    toplevel $win
    wm resizable $win 0 0
    wm title $win $title
    wm protocol $win WM_DELETE_WINDOW "string tolower 0"
    label $win.caption -text $caption
    set canv [canvas $win.progbar -borderwidth 1 -relief solid -width 200 -height 20 -scrollregion {0 0 200 20}]
    $canv create rectangle 0 0 0 20 -width 0 -fill blue4 -tags progbar
    pack $win.caption -side top -anchor w
    pack $win.progbar -side top
    raise $win
    grab set $win
    tkwait visibility $win
    update idletasks
    update
    set progwinInfo(LASTUP) [clock milliseconds]
    return $win
}


proc progwin_callback {win maxval currval} {
    global progwinInfo
    if {![winfo exists $win]} {
        return
    }
    set now [clock milliseconds]
    set dtime [expr {$now-$progwinInfo(LASTUP)}]
    if {$dtime > 125} {
        set progwinInfo(LASTUP) $now
        set width [expr {int(round(200.0*$currval/$maxval))}]
        $win.progbar coords progbar 0 0 $width 20
        update idletasks
        update
    }
}


proc progwin_destroy {win} {
    global progwinInfo
    if {[winfo exists $win]} {
        destroy $win
        catch {unset progwinInfo(LASTUP)}
        grab release $win
    }
}


# vim: set ts=4 sw=4 nowrap expandtab: settings

