
tcl::OptProc mlcnc_rpm {
    {-plunge "This flag specifies that we need a plunge speed."}
} {
    if {$plunge && ![mlcnc_mill_rpm_is_fixed]} {
        set sfm [mlcnc_stock_drillsfm]
    } else {
        set sfm [mlcnc_stock_millsfm]
    }
    set diam [mlcnc_tooldiam]
    set mat [mlcnc_toolmaterial]
    if {$mat == "Carbide"} {
        set sfm [expr {$sfm*2.0}]
    }
    set coat [mlcnc_toolcoating]
    switch -exact -- $coat {
        TiCN   { set sfm [expr {$sfm*1.4}] }
        TiAlCN { set sfm [expr {$sfm*1.7}] }
    }
    set speed [expr {$sfm*3.82/$diam}]
    if {[mlcnc_mill_speeds_are_discrete]} {
        set speedlist [mlcnc_mill_rpm_list]
        if {$speedlist != {}} {
            set speedlist [lsort -integer $speedlist]
            set gearnum 1
            set founddiff 99999999
            set foundspeed 0
            set foundgear 0
            foreach speedopt $speedlist {
                set diff [expr {abs($speedopt-$speed)}]
                if {$diff < $founddiff} {
                    set foundspeed $speedopt
                    set founddiff $diff
                    set foundgear $gearnum
                }
                incr gearnum
            }
            set speed $foundspeed
        }
    } else {
        set speedmin [mlcnc_mill_rpm_min]
        if {$speed < $speedmin} {
            set speed $speedmin
        }
        set speedmax [mlcnc_mill_rpm_max]
        if {$speedmax != 0} {
            if {$speed > $speedmax} {
                set speed $speedmax
            }
        }
        set foundgear 0
    }
    set speed [expr {int($speed)}]
    return $speed
}


tcl::OptProc mlcnc_gearnum {
    {-plunge "This flag specifies that we need a plunge speed."}
} {
    if {$plunge && ![mlcnc_mill_rpm_is_fixed]} {
        set sfm [mlcnc_stock_drillsfm]
    } else {
        set sfm [mlcnc_stock_millsfm]
    }
    set diam [mlcnc_tooldiam]
    set mat [mlcnc_toolmaterial]
    if {$mat == "Carbide"} {
        set sfm [expr {$sfm*2.0}]
    }
    set coat [mlcnc_toolcoating]
    switch -exact -- $coat {
        TiCN   { set sfm [expr {$sfm*1.4}] }
        TiAlCN { set sfm [expr {$sfm*1.7}] }
    }
    set speed [expr {$sfm*3.82/$diam}]
    if {[mlcnc_mill_speeds_are_discrete]} {
        set speedlist [mlcnc_mill_rpm_list]
        if {$speedlist != {}} {
            set speedlist [lsort -integer $speedlist]
            set gearnum 1
            set founddiff 99999999
            set foundspeed 0
            set foundgear 0
            foreach speedopt $speedlist {
                set diff [expr {abs($speedopt-$speed)}]
                if {$diff < $founddiff} {
                    set foundspeed $speedopt
                    set founddiff $diff
                    set foundgear $gearnum
                }
                incr gearnum
            }
            set speed $foundspeed
        }
    } else {
        set foundgear 0
    }
    return $foundgear
}


tcl::OptProc mlcnc_feed {
    {-plunge        "This flag specifies that we need a plunge feed speed."}
} {
    set rpm [mlcnc_rpm]
    set ipt [mlcnc_stock_feedipt]
    set diam [mlcnc_tooldiam]
    set teeth [mlcnc_toolteeth]
    if {$diam < 1.0} {
        set ipt [expr {$ipt*$diam}]
    }
    if {$plunge} {
        set ipt [expr {$ipt*0.2}]
    }
    set feed [expr {$ipt*$teeth*$rpm}]
    set maxfeed [mlcnc_mill_feed_max]
    if {$feed > $maxfeed} {
        set feed $maxfeed
    }
    set feed [format "%.2f" $feed]
    return $feed
}


tcl::OptProc mlcnc_cutdepth {
    {-plunge        "This flag specifies that we need a plunge feed speed."}
    {-cutwidth  0.0 "This specifies how wide a cut we want to make."}
} {
    set tooldiam [mlcnc_tooldiam]
    set depth [expr {$tooldiam/2.0}]
    if {$depth < 1e-4} { set depth 1e-4 }
    if {$plunge} {
        set depth [format "%.5f" $depth]
        return $depth
    }
    set feed [mlcnc_feed]
    if {$cutwidth == 0.0} {
        set cutwidth $tooldiam
    }
    if {$cutwidth < $tooldiam/2.0} {
        # For lesser cuts, allow more depth
        set depth [expr {(($tooldiam/2.0)/$cutwidth)*$depth}]
    }
    set maxhp [mlcnc_mill_hp]
    set unithp [mlcnc_stock_unithp]
    set maxdepth [expr {0.75*$maxhp/($cutwidth*$feed*$unithp)}]
    if {$depth > $maxdepth} {
        set depth $maxdepth
    }
    set cutlen [mlcnc_toolcutlen]
    if {$depth > $cutlen} {
        set depth $cutlen
    }
    if {$depth < 1e-4} { set depth 1e-4 }
    set depth [format "%.5f" $depth]
    return $depth
}



proc mlcnc_min {v1 args} {
    foreach v2 $args {
        if {$v2 < $v1} {
            set v1 $v2
        }
    }
    return $v1
}


proc mlcnc_max {v1 args} {
    foreach v2 $args {
        if {$v2 > $v1} {
            set v1 $v2
        }
    }
    return $v1
}


# vim: set ts=4 sw=4 nowrap expandtab: settings

