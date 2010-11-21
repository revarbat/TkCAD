proc mlcnc_g_excellon {filename z} {
    set f [open $filename "r"]
    set holesInfo {}
    set section "start"
    set conv 1.0
    set currdiam 0.0
    while {![eof $f]} {
        if {[catch {
            set line [gets $f]
        }]} {
            break
        }
        if {$line == "M71"} {
            set conv [expr {1.0/25.4}]
        } elseif {$line == "M72"} {
            set conv 1.0
        }
        if {[regexp {^ *T *([0-9][0-9]*) *C *([0-9][0-9]*\.[0-9][0-9]*).*$} $line dummy toolnum diam]} {
            set toolnum [string trimleft $toolnum "0"]
            set diam [expr {$diam+0.0}]
            set toolsInfo($toolnum) $diam
        } elseif {[regexp {^ *T *([0-9][0-9]*).*$} $line dummy toolnum]} {
            set toolnum [string trimleft $toolnum "0"]
            if {![info exists toolsInfo($toolnum)]} {
                error "Malformed excellon file.  May require extra drill tool file."
            }
            set currdiam $toolsInfo($toolnum)
        } elseif {[regexp {^ *X *([0-9][.0-9]*) *Y *([0-9][.0-9]*).*$} $line dummy x y]} {
            if {[string first "." $x] != -1} {
                set x [expr {$x*$conv}]
                set y [expr {$y*$conv}]
            } else {
                set x [expr {$x*$conv/10000.0}]
                set y [expr {$y*$conv/10000.0}]
            }
            lappend holesInfo $x $y $currdiam
        }
    }
    set out {}
    foreach {x y diam} $holesInfo {
        set rad [expr {$diam/2.0}]
        append out [mlcnc_g_circle $x $y $z $rad $rad]
    }
    return $out
}


# vim: set ts=4 sw=4 nowrap expandtab: settings

