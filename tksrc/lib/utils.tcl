proc font_families {} {
    global utilsInfo
    if {[info exists utilsInfo(FONT_FAMILIES)]} {
        return $utilsInfo(FONT_FAMILIES)
    }
    set bannedfams {system ansi device systemfixed ansifixed oemfixed system application menu}
    foreach famname [font families] {
        if {[string is ascii -strict $famname]} {
            if {[string is alpha -strict [string index $famname 0]]} {
                set famsub $famname
                regsub -all -nocase { *[ -]Bold}   $famsub "" famsub
                regsub -all -nocase { *[ -]Italic} $famsub "" famsub
                regsub -all -nocase { *[ -]Ital}   $famsub "" famsub
                if {![info exists famtree($famsub)]} {
                    set famtree($famsub) $famname
                }
                if {[string length $famname] < [string length $famtree($famsub)]} {
                    set famtree($famsub) $famname
                }
            }
        }
    }
    set fams {}
    foreach {famsub famname} [array get famtree] {
        if {$famsub ni $bannedfams} {
            lappend fams $famname
        }
    }
    set fams [lsort $fams]
    set fams [linsert $fams 0 {*}[cncfont_list]]
    set utilsInfo(FONT_FAMILIES) $fams
    return $fams
}



proc swapvars {x y} {
    upvar $x a $y b
    lassign [list $a $b] b a
}


proc lremove {lst val} {
    set pos [lsearch -exact $lst $val]
    if {$pos >= 0} {
        set lst [lreplace $lst $pos $pos]
    }
    return $lst
}


proc util_number_validate {val {cb ""} {units ""}} {
    if {$units == 1} {
        set units "in"
    }
    if {[util_number_value $val $units] == ""} {
        return 0
    }
    if {$cb != ""} {
        if {[catch $cb err]} {
            global errorInfo
            puts stderr $errorInfo
        }
    }
    return 1
}


proc util_number_value {val {targunits ""}} {
    if {$targunits != ""} {
        if {$targunits == 1} {
            set targunits "in"
        }
        set units $targunits
        set val [string trim $val]
        if {[regexp -expanded -- "^(-)?(\[0-9\]+)' *(\[0-9\]+)\"\$" $val dummy sgn feet inches]} {
            set val [expr {$feet*12.0+$inches}]
            if {$sgn == "-"} {
                set val [expr {-$val}]
            }
            set units "in"
        } elseif {[regexp -expanded -- "^(-?\[0-9/. \]+)\'\$" $val dummy nuval]} {
            set val $nuval
            set units "ft"
        } elseif {[regexp -expanded -- "^(-?\[0-9/. \]+)\"\$" $val dummy nuval]} {
            set val $nuval
            set units "in"
        } elseif {[regexp -expanded -- "^(-?\[0-9/. \]+)(um|mm|cm|dm|m|in|ft|pt)\s*\$" $val dummy nuval nuunits]} {
            set val $nuval
            set units $nuunits
        } else {
            set units $targunits
        }
    }
    if {[regexp -expanded -- {^(-)?(([0-9]+) +)?([0-9]+)/([1-9][0-9]*)$} $val dummy sgn dummy whole denom divisor]} {
        if {[string first " " $val] == -1} {
            # Workaround for an apparent regexp bug.
            set denom "$whole$denom"
            set whole 0.0
        }
        if {$whole == ""} {
            set whole 0.0
        }
        set val [expr {$whole+(($denom+0.0)/($divisor+0.0))}]
        if {$sgn == "-"} {
            set val [expr {-$val}]
        }
    } elseif {![string is double -strict $val]} {
        if {[regexp -nocase -- {\\\[\]\$\{\}} $val]} {
            return ""
        }
        set val [string map {/ *1.0/} $val]
        if {[catch {expr $val} res]} {
            return ""
        }
        set val $res
    }
    if {$targunits != ""} {
        array set unitset [list \
            "um" [expr {(1.0/25.4)/1000.0}] \
            "mm" [expr {(1.0/25.4)}] \
            "cm" [expr {(1.0/25.4)*10.0}] \
            "dm" [expr {(1.0/25.4)*100.0}] \
            "m"  [expr {(1.0/25.4)*1000.0}] \
            "in" 1.0   \
            "ft" 12.0  \
            "pt" [expr {1.0/72.0}] \
        ]
        set val [expr {$val*$unitset($units)/$unitset($targunits)}]
    }
    return $val
}


proc color_to_hue {color} {
    lassign [winfo rgb . $color] r g b
    set max [expr {max($r,$g,$b)}]
    set min [expr {min($r,$g,$b)}]
    if {$r == $g && $r == $b} {
        set h 0.0
    } elseif {$r >= $g && $r >= $b} {
        if {$g >= $b} {
            set h [expr {60.0*(($g-$b+0.0)/($max-$min+0.0))+0.0}]
        } else {
            set h [expr {60.0*(($g-$b+0.0)/($max-$min+0.0))+360.0}]
        }
    } elseif {$g >= $r && $g >= $b} {
        set h [expr {60.0*(($b-$r+0.0)/($max-$min+0.0))+120.0}]
    } else {
        set h [expr {60.0*(($r-$g+0.0)/($max-$min+0.0))+240.0}]
    }
    set h [expr {fmod($h,360.0)}]
    return $h
}



proc color_to_hsl {color} {
    set h [color_to_hue $color]
    lassign [winfo rgb . $color] r g b
    set max [expr {max($r,$g,$b)}]
    set min [expr {min($r,$g,$b)}]
    set l [expr {0.5*($max+$min)/65535.0}]
    if {$r == $g && $r == $b} {
        set s 0.0
    } elseif {$l <= 0.5} {
        set s [expr {($max-$min)/(2.0*$l)}]
    } else {
        set s [expr {($max-$min)/(2.0-2.0*$l)}]
    }
    return [list $h $s $l]
}



proc color_to_hsv {color} {
    set h [color_to_hue $color]
    lassign [winfo rgb . $color] r g b
    set max [expr {max($r,$g,$b)}]
    set min [expr {min($r,$g,$b)}]
    set v [expr {$max/65535.0}]
    if {$r == $g && $r == $b} {
        set s 0.0
    } else {
        set s [expr {1.0-($min/($max+0.0))}]
    }
    return [list $h $s $v]
}


proc color_from_hsv {h s v} {
    set h60 [expr {$h/60.0}]
    set hi [expr {int($h60)%6}]
    set f [expr {$h60-int($h60)}]
    set p [expr {$v*(1.0-$s)}]
    set q [expr {$v*(1.0-$f*$s)}]
    set t [expr {$v*(1.0-(1.0-$f)*$s)}]
    switch -exact -- $hi {
        0 { set r $v ; set g $t ; set b $p }
        1 { set r $q ; set g $v ; set b $p }
        2 { set r $p ; set g $v ; set b $t }
        3 { set r $p ; set g $q ; set b $v }
        4 { set r $t ; set g $p ; set b $v }
        5 { set r $v ; set g $p ; set b $q }
    }
    set r [expr {int($r*65535)}]
    set g [expr {int($g*65535)}]
    set b [expr {int($b*65535)}]
    return [format "#%04x%04x%04x" $r $g $b]
}




proc dash_patterns {} {
    set pats {}
    lappend pats "CenterLine"
    lappend pats "Construction"
    lappend pats "HiddenLine"
    lappend pats "CutLine"
    lappend pats "Solid"
    return $pats
}


proc pathdash {pat} {
    set out {}
    foreach ch [split $pat ""] {
        switch -exact $ch {
            "_"  {lappend out 16 4}
            "-"  {lappend out 6 4}
            "."  {lappend out 3 4}
        }
    }
    return $out
}


proc dashpat {pat} {
    global tcl_platform
    set pat [string tolower $pat]
    set pat [string map {" " "" "-" ""} $pat]
    switch -exact -- $pat {
        center -
        centerline {
            if {$tcl_platform(platform) == "windows"} {
                return {-.}
            } else {
                return {._}
            }
        }
        construction {
            return {.}
        }
        hidden -
        hiddenline {
            return {-}
        }
        phantom -
        cutline -
        cutting -
        cuttingline {
            if {$tcl_platform(platform) == "windows"} {
                return {-..}
            } else {
                return {_..}
            }
        }
        default {
            return {}
        }
    }
}



proc line_coords_reverse {coords} {
    set out {}
    foreach {y x} [lreverse $coords] {
        lappend out $x $y
    }
    return $out
}



#
# defer -- Defers a command's execution for a few milliseconds, making sure
#            that it only gets executed once, even if it is re-defered many
#            times. ie: if you call the same defer many times, only the first
#            (or last) one will actually be executed at the end of the delay.
#            This is useful if you need to perform an expensive action, that
#            might need to be triggered many more times than you would want
#            it to actually run, but you do want it to run once at the end
#            of a short delay.
#
# defer ?-delay ms? ?-replace? ?-group name? cmd args ...
#   -delay MS      Sets the delay in milliseconds.  Default is 25.
#   -group NAME    Sets the group name.  Defaults is the cmd
#   -replace       If a cmd in the same group is already pending,
#                    replace that cmd with this new one, and its args.
#                    Note that the delay will be restarted.
#                    Default is to keep the old cmd.
#
proc defer {args} {
    global utilsInfo
    set delay 10
    set replace 0
    set group ""
    while {[llength $args]} {
        set args [lassign $args cmd]
        switch -glob $cmd {
            -- {
                break
            }
            -delay {
                set args [lassign $args delay]
            }
            -replace {
                set replace 1
            }
            -group {
                set args [lassign $args group]
            }
            default {
                set args [linsert $args 0 $cmd]
                break
            }
        }
    }
    if {$group == ""} {
        set group [lindex $args 0]
    }
    if {[info exists utilsInfo(DEFERPID-$group)]} {
        set afid $utilsInfo(DEFERPID-$group)
        if {$replace} {
            catch {after cancel $afid}
        } else {
            if {![catch {after info $afid}]} {
                return
            }
        }
    }
    set cmd "$args ; unset [list [list utilsInfo(DEFERPID-$group)]]"
    set afid [after $delay {*}$cmd]
    set utilsInfo(DEFERPID-$group) $afid
}



if {[info commands lreverse] == ""} {
    proc lreverse {l} {
        set out {}
        set i [llength $l]
        while {$i} {
            lappend out [lindex $l [incr i -1]]
        }
        return $out
    }
}



if {[info commands lassign] == ""} {
    proc lassign {listval args} {
        set vnum 0
        set vlist {}
        foreach var $args {
            set myvar "v[incr vnum]"
            upvar $var $myvar
            lappend vlist $myvar
        }
        foreach $vlist $listval break
        return [lrange $listval [llength $args] end]
    }
}



if {[info commands dict] == ""} {
    proc dict {cmd args} {
        switch -exact -- $cmd {
            append {
                set dictvar [lindex $args 0]
                set key [lindex $args 1]
                set strs [lrange $args 2 end]
                uplevel $dictvar dict
                catch {unset data}
                array set data $dict
                foreach str $strs {
                    append data($key) $str
                }
                set dict [array get data]
            }
            create {
                return $args
            }
            exists {
                set dict [lindex $args 0]
                set keys [lrange $args 1 end]
                foreach key $keys {
                    catch {unset data}
                    array set data $dict
                    if {![info exists data($key)]} {
                        return 0
                    }
                    set dict $data($key)
                }
                return 1
            }
            filter {
                set dict [lindex $args 0]
                set ftyp [lindex $args 1]
                set args [lrange $args 2 end]
                set nudict {}
                switch -exact -- $ftyp {
                    key {
                        set pat [lindex $args 0]
                        foreach {key val} $dict {
                            if {[string match $pat $key]} {
                                lappend nudict $key $val
                            }
                        }
                    }
                    value {
                        set pat [lindex $args 0]
                        foreach {key val} $dict {
                            if {[string match $pat $val]} {
                                lappend nudict $key $val
                            }
                        }
                    }
                    script {
                        set vars [lindex $args 0]
                        set script [lindex $args 1]
                        set keyvar [lindex $vars 0]
                        set valvar [lindex $vars 1]
                        foreach [list $keyvar $valvar] [dict get $dict] {
                            set code [catch {eval $script} res]
                            if {$code == 3} {
                                # break
                                break
                            } elseif {$code == 4} {
                                # continue
                                set code 0
                                set res 0
                            } elseif {$code == 2} {
                                # return
                                set code 0
                            } elseif {$code == 1} {
                                # error
                                set code 0
                                set res 0
                            }
                            if {$res} {
                                lappend nudict [set $keyvar] [set $valvar]
                            }
                        }
                    }
                }
                return $nudict
            }
            for {
                set vars [lindex $args 0]
                set dict [lindex $args 1]
                set body [lindex $args 2]
                foreach {keyvar valvar} $vars break
                upvar $keyvar key
                upvar $valvar val
                foreach {key val} [array get $dict] {
                    set res [uplevel $body]
                }
                return $res
            }
            get {
                set dict [lindex $args 0]
                set keys [lrange $args 1 end]
                foreach key $keys {
                    catch {unset data}
                    array set data $dict
                    set dict $data($key)
                }
                return $dict
            }
            incr {
                set dictvar [lindex $args 0]
                set key [lindex $args 1]
                set ival [lindex $args 2]
                upvar $dictvar dict
                catch {unset data}
                array set data $dict
                if {$ival == ""} {
                    set ival 1
                }
                set res [incr data($key) $ival]
                set dict [array get data]
                return $res
            }
            info {
                # TODO: implement this
                error "Not implemented"
            }
            keys {
                set dict [lindex $args 0]
                set pat [lindex $args 1]
                catch {unset data}
                array set data $dict
                if {$pat != ""} {
                    return [array names data $pat]
                }
                return [array names data]
            }
            lappend {
                set dictvar [lindex $args 0]
                set key [lindex $args 1]
                set items [lrange $args 2 end]
                upvar $dictvar dict
                catch {unset data}
                array set data $dict
                foreach item $items {
                    lappend data($key) $item
                }
                set dict [array get data]
            }
            merge {
                catch {unset data}
                foreach dict $args {
                    array set data $dict
                }
                return [array get data]
            }
            remove {
                set dict [lindex $args 0]
                set keys [lrange $args 1 end]
                catch {unset data}
                array set data $dict
                foreach item $items {
                    catch {unset data($key)}
                }
                set dict [array get data]
                return $dict
            }
            replace {
                # TODO: implement this
                error "Not implemented"
            }
            set {
                # TODO: implement this
                error "Not implemented"
            }
            size {
                set dict [lindex $args 0]
                return [expr {[llength $dict]/2}]
            }
            unset {
                # TODO: implement this
                error "Not implemented"
            }
            update {
                # TODO: implement this
                error "Not implemented"
            }
            values {
                set dict [lindex $args 0]
                set pat [lindex $args 1]
                set vals {}
                catch {unset data}
                array set data $dict
                foreach {key val} [array get data] {
                    if {$pat == "" || [string match $pat $val]} {
                        lappend vals $val
                    }
                }
                return $vals
            }
            with {
                # TODO: implement this
                error "Not implemented"
            }
        }
    }
}



# vim: set ts=4 sw=4 nowrap expandtab: settings

