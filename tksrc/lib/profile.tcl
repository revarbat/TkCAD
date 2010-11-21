namespace eval prof {
    variable st {}
    variable times
    variable called
    variable callcnt
    variable counts



    proc init {} {
        # The following command forces any clock procs to be instantiated
        # before we start instrumenting procedures.
        clock microseconds
        catch {
            # Clear tclprof.txt file.
            set f [open "tclprof.txt" "w"]
            puts $f ""
            close $f
        }
    }
    init



    proc enter {str op} {
        set n [uplevel namespace which -command [lindex $str 0]]
        if {$n == ""} {
            set n [lindex $str 0]
        }
        incr ::prof::counts($n)
        set l 0
        # Uncomment next line for fine-grained caller-line recording.
        #set l [dict get [info frame -2] line]
        lappend ::prof::st $n $l [clock microseconds]
        return
    }



    proc leave {str code result op} {
        set e [clock microseconds]
        lassign [lrange $::prof::st end-2 end] n l s
        if {[llength $::prof::st] > 3} {
            set c [lindex $::prof::st end-5]
        } else {
            set c {{TOP}}
        }
        set ::prof::st [lrange $::prof::st 0 end-3]
        if {$c != $n} {
            incr ::prof::times($n) [expr {$e-$s}]
            append c " " $l " " $n
            incr ::prof::called($c) [expr {$e-$s}]
            incr ::prof::callcnt($c)
        }
        return
    }



    proc reset {} {
        catch {
            set f [open "tclprof.txt" "a"]
            puts $f "Profile data reset at [clock format [clock seconds] -format %c]"
            puts $f ""
            close $f
        }
        set ::prof::st {}
        foreach key [array names ::prof::times] {
            unset ::prof::times($key)
        }
        foreach key [array names ::prof::called] {
            unset ::prof::called($key)
        }
        foreach key [array names ::prof::callcnt] {
            unset ::prof::callcnt($key)
        }
        foreach key [array names ::prof::counts] {
            unset ::prof::counts($key)
        }
        return
    }



    proc dump {} {
        variable times
        variable called
        variable callcnt
        variable counts

        if {[catch {
            set f [open "tclprof.txt" "a"]
            puts $f "Profile data dump at [clock format [clock seconds] -format %c]"

            set top {{TOP}}
            set counts($top) 1

            set tottime 0
            foreach key [array names called "$top *"] {
                incr tottime $called($key)
            }
            set timeunit "ms"
            set timediv 1000.0
            if {$tottime > 1e7} {
                set timeunit "s"
                set timediv [expr {$timediv*1000.0}]
            }

            set proflist {}
            foreach procname [array names times "*"] {
                lappend proflist [list $procname $times($procname)]
            }
            set proflist [lsort -decreasing -index 1 -integer $proflist]
            set proflist [linsert $proflist 0 [list $top $tottime]]

            set funcnum 0
            foreach profdata $proflist {
                lassign $profdata procname time
                set funcnums($procname) $funcnum
                incr funcnum
            }

            puts $f ""
            puts $f [format "%-6s %6s %8s %8s %12s %s (%s)" Index %Time Time($timeunit) Part($timeunit) Calls Name LineFrom]
            foreach profdata $proflist {
                lassign $profdata procname time
                if {$time > 0} {
                    puts $f "----------------------------------------------------------------------------"

                    set supproflist {}
                    foreach key [array names called "* $procname"] {
                        lassign [split $key " "] supfunc supfuncl subfunc
                        lappend supproflist [list $supfunc $supfuncl $called($key) $callcnt($key)]
                    }

                    set outtime 0
                    set subproflist {}
                    foreach key [array names called "$procname *"] {
                        lassign [split $key " "] supfunc supfuncl subfunc
                        if {$supfunc != $subfunc} {
                            incr outtime $called($key)
                        }
                        lappend subproflist [list $subfunc $supfuncl $called($key) $callcnt($key)]
                    }

                    foreach supprofdata [lsort -index 2 -integer $supproflist] {
                        lassign $supprofdata supfunc supfuncl suptime supcnt
                        if {$suptime > 0} {
                            if {![info exists funcnums($supfunc)]} {
                                set fnum ""
                            } else {
                                set fnum [format "\[%s\]" $funcnums($supfunc)]
                            }
                            if {$supfuncl > 0 && $supfunc != $top} {
                                set supfuncl [format "(L:%d)" $supfuncl]
                            } else {
                                set supfuncl ""
                            }
                            puts $f [format "%22s %8.3f %12d     %s %s %s" "" \
                                            [expr {$suptime/$timediv}] \
                                            $supcnt \
                                            [string trimleft $supfunc ":"] \
                                            $fnum $supfuncl \
                                            ]
                        }
                    }
                    if {![info exists funcnums($procname)]} {
                        set fnum ""
                    } else {
                        set fnum [format "\[%s\]" $funcnums($procname)]
                    }
                    puts $f [format "%-6s %5.1f%% %8.3f %8.3f %12d %s %s" \
                                    $fnum \
                                    [expr {$time*100.0/$tottime}] \
                                    [expr {$time/$timediv}] \
                                    [expr {($time-$outtime)/$timediv}] \
                                    $counts($procname) \
                                    [string trimleft $procname ":"] \
                                    $fnum \
                                    ]
                    foreach subprofdata [lsort -decreasing -index 2 -integer $subproflist] {
                        lassign $subprofdata subfunc supfuncl subtime subcnt
                        if {$subtime > 0} {
                            if {![info exists funcnums($subfunc)]} {
                                set fnum ""
                            } else {
                                set fnum [format "\[%s\]" $funcnums($subfunc)]
                            }
                            if {$supfuncl > 0 && $procname != $top} {
                                set supfuncl [format "(L:%d)" $supfuncl]
                            } else {
                                set supfuncl ""
                            }
                            puts $f [format "%22s %8.3f %12s     %s %s %s" "" \
                                            [expr {$subtime/$timediv}] \
                                            $subcnt/$counts($subfunc) \
                                            [string trimleft $subfunc ":"] \
                                            $fnum $supfuncl \
                                            ]
                        }
                    }
                }
            }
            puts $f "----------------------------------------------------------------------------"
            puts $f ""
            puts $f ""
            close $f
        } err]} {
            global errorInfo
            puts stderr $errorInfo
        }
    }



    proc instrument {{ns {::}}} {
        foreach func [info procs "${ns}::*"] {
            trace add execution $func enter ::prof::enter
            trace add execution $func leave ::prof::leave
        }
        foreach chns [namespace children $ns] {
            if {$chns ni {::tcl ::tk ::ttk ::prof ::msgcat}} {
                instrument $chns
            }
        }
    }



    proc start {} {
        foreach cmd {
            source vwait fcopy interp update exec
            tkwait tk_dialog tk_messageBox tk_chooseColor
            tk_chooseDirectory tk_getOpenFile tk_getSaveFile
        } {
            catch {
                trace add execution ::$cmd enter ::prof::enter
                trace add execution ::$cmd leave ::prof::leave
            }
        }
        instrument
    }

}


catch {
    bind all <Shift-Control-Option-Command-D> "after idle ::prof::dump ; break"
    bind all <Shift-Control-Option-Command-R> "after idle ::prof::reset ; break"
}


rename exit ::prof::_exit

proc exit {} {
    ::prof::dump
    ::prof::_exit
}



::prof::start



rename proc ::prof::_proc

::prof::_proc proc {procname procargs procbody} {
    set ns [uplevel namespace current]
    if {$ns == "::"} {
        set ns ""
    }
    if {[string range $procname 0 1] != "::"} {
        set procname "${ns}::${procname}"
    }
    set res [::prof::_proc $procname $procargs $procbody]
    if {![string match "::tcl::*" $procname]} {
        trace add execution $procname enter ::prof::enter
        trace add execution $procname leave ::prof::leave
    }
    return $res
}


# vim: set ts=4 sw=4 nowrap expandtab: settings

