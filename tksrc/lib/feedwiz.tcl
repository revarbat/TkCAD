proc feedwiz_create {} {
    global feedwizInfo

    set base .feedwiz

    if {[winfo exists $base]} {
        raise $base
        return
    }

    toplevel $base -padx 20 -pady 20
    wm title $base "Speed and Feed Wizard"

    set feedwizInfo(STOCK_MATERIAL)        "Aluminum"
    set feedwizInfo(TOOL_MATERIAL)         "Carbide"
    set feedwizInfo(TOOL_DIAMETER)         "1/8\""
    set feedwizInfo(TOOL_FLUTES)           "4"
    set feedwizInfo(MILL_HORSEPOWER)       "0.20"
    set feedwizInfo(MILL_SPEEDS_DISCRETE)  1
    set feedwizInfo(MILL_SPEED_MIN)        1100
    set feedwizInfo(MILL_SPEED_MAX)        10500
    set feedwizInfo(MILL_SPEED_LIST)       {1100 1900 2900 4300 6500 10500}

    trace add variable feedwizInfo(STOCK_MATERIAL) write "feedwiz_trace_update $base"
    trace add variable feedwizInfo(TOOL_MATERIAL)  write "feedwiz_trace_update $base"

    set smats [mlcnc_stock_types]
    set smatl  [label $base.smatl -text "Material to Mill"]
    tk_optionMenu $base.smatmb feedwizInfo(STOCK_MATERIAL) {*}$smats
    set smatmb $base.smatmb
    $smatmb configure -width 20

    set tmatl  [label $base.tmatl -text "Tool Type"]
    tk_optionMenu $base.tmatmb feedwizInfo(TOOL_MATERIAL) "HSS" "Carbide"
    set tmatmb $base.tmatmb
    $tmatmb configure -width 20

    set tooldiams [list 1/32\" 1/16\" 1/8\" 3/16\" 1/4\" 5/16\" 3/8\" 7/16\" 1/2\" 9/16\" 5/8\" 11/16\" 3/4\" 13/16\" 7/8\" 15/16\" 1\"]
    set tdiaml  [label $base.tdiaml -text "Tool Diameter"]
    set tdiamcb [::ttk::combobox $base.tdiamcb \
                    -textvariable feedwizInfo(TOOL_DIAMETER) \
                    -justify left -values $tooldiams \
                    -validatecommand "util_number_validate %P {feedwiz_update $base} 1" \
                    -invalidcommand "bell" \
                    -validate focus -height 10 -width 8]
    bind $tdiamcb <Key-Return> "feedwiz_update $base"
    bind $tdiamcb <Key-KP_Enter> "feedwiz_update $base"
    bind $tdiamcb <<ComboboxSelected>> "feedwiz_update $base"

    set tfltl  [label $base.tfltl -text "Tool Flutes"]
    set tfltcb [::ttk::combobox $base.tfltcb \
                    -textvariable feedwizInfo(TOOL_FLUTES) \
                    -justify left -values {1 2 3 4 5 6 7 8} \
                    -validatecommand "feedwiz_integer_validate $base %P" \
                    -invalidcommand "bell" \
                    -validate all -height 8 -width 8]

    set mhpl  [label $base.mhpl -text "Mill HorsePower"]
    set mhpcb [::ttk::combobox $base.mhpcb \
                    -textvariable feedwizInfo(MILL_HORSEPOWER) \
                    -justify left -values {1/8 1/6 1/5 1/4 1/3 1/2 2/3 3/4 1 1.5 2.0 3.0} \
                    -validatecommand "util_number_validate %P {feedwiz_update $base}" \
                    -invalidcommand "bell" \
                    -validate focus -height 8 -width 8]
    bind $mhpcb <Key-Return> "feedwiz_update $base"
    bind $mhpcb <Key-KP_Enter> "feedwiz_update $base"
    bind $mhpcb <<ComboboxSelected>> "feedwiz_update $base"

    set mspdl  [label $base.mspdl -text "Mill Speeds"]
    set mspdcb [checkbutton $base.mspdcb \
                    -text "Discrete" \
                    -variable feedwizInfo(MILL_SPEEDS_DISCRETE) \
                    -command "feedwiz_showhide_speeds $base"]

    set mspdfr [frame $base.mspdfr -padx 20]

    set mspdcfr [frame $mspdfr.cfr]
    set mspdminl [label $mspdcfr.minl -text "Min"]
    set mspdmine [entry $mspdcfr.mine \
                    -textvariable feedwizInfo(MILL_SPEED_MIN) \
                    -width 8 -validate all \
                    -validatecommand "feedwiz_integer_validate $base %P" \
                    -invalidcommand "bell"]
    set mspdmaxl [label $mspdcfr.maxl -text "Max"]
    set mspdmaxe [entry $mspdcfr.maxe \
                    -textvariable feedwizInfo(MILL_SPEED_MAX) \
                    -width 8 -validate all \
                    -validatecommand "feedwiz_integer_validate $base %P" \
                    -invalidcommand "bell"]
    grid $mspdminl $mspdmine
    grid $mspdmaxl $mspdmaxe

    set mspddfr [frame $mspdfr.dfr]
    set mspddlb [listbox $mspddfr.dlb -width 6 -height 5 -listvariable feedwizInfo(MILL_SPEED_LIST) -yscrollcommand "$mspddfr.dsb set"]
    set mspddsb [scrollbar $mspddfr.dsb -orient vertical -command "$mspddlb yview"]
    grid $mspddlb $mspddsb
    grid $mspddlb -sticky nsew
    grid $mspddsb -sticky nse

    set ofr [labelframe $base.ofr -text "Speeds & Feeds" -padx 10]
    set ospdl [label $ofr.spd -text "RPM Speed: "]
    set opfrl [label $ofr.pfr -text "Plunge Rate: "]
    set ocfrl [label $ofr.cfr -text "Feed Rate: "]
    set odepl [label $ofr.dep -text "Cut Depth: "]
    grid $ospdl -sticky nw
    grid $opfrl -sticky nw
    grid $ocfrl -sticky nw
    grid $odepl -sticky nw

    grid columnconfigure $base 1 -weight 1
    grid $smatl   $smatmb   $ofr  -sticky w
    grid $tmatl   $tmatmb   ^     -sticky w
    grid $tdiaml  $tdiamcb  ^     -sticky w
    grid $tfltl   $tfltcb   ^     -sticky w
    grid $mhpl    $mhpcb    ^     -sticky w
    grid $mspdl   $mspdcb   ^     -sticky w
    grid $mspdfr  -         ^     -sticky w
    grid $smatmb -pady 5
    grid $tmatmb -pady 5
    grid $ofr -sticky nsew -padx {20 0}

    feedwiz_showhide_speeds $base
}


proc feedwiz_trace_update {base name1 name2 op} {
    feedwiz_update $base
}


proc feedwiz_integer_validate {base val} {
    set res 0
    set res [string is integer -strict $val]
    if {$res} {
        feedwiz_update $base
    }
    return $res
}


proc feedwiz_showhide_speeds {base} {
    global feedwizInfo
    set fr $base.mspdfr
    if {$feedwizInfo(MILL_SPEEDS_DISCRETE)} {
        # show discrete frame
        pack forget $fr.cfr
        pack $fr.dfr
    } else {
        # show minmax frame
        pack forget $fr.dfr
        pack $fr.cfr
    }
    feedwiz_update $base
}


proc feedwiz_update {base} {
    if {![winfo ismapped $base]} {
        after 10 feedwiz_update $base
        return
    }

    global feedwizInfo

    set smat  $feedwizInfo(STOCK_MATERIAL)
    set tmat  $feedwizInfo(TOOL_MATERIAL)
    set tdiam $feedwizInfo(TOOL_DIAMETER)
    set tflt  $feedwizInfo(TOOL_FLUTES)
    set mhp   $feedwizInfo(MILL_HORSEPOWER)
    set mspdd $feedwizInfo(MILL_SPEEDS_DISCRETE)
    set msmin $feedwizInfo(MILL_SPEED_MIN)
    set msmax $feedwizInfo(MILL_SPEED_MAX)
    set mspds $feedwizInfo(MILL_SPEED_LIST)

    set tdiam [util_number_value $tdiam "in"]
    set mhp [util_number_value $mhp]
    if {$tdiam == ""} {
        set tdiam 0.125
    }
    if {$mhp == ""} {
        set mhp 0.25
    }

    if {$mspdd} {
        mlcnc_define_mill \
            -discretespeeds 1 \
            -rpmlist $mspds \
            -fixedrpm 1 \
            -autotoolchanger 0 \
            -maxfeed 15.0 \
            -hp $mhp
    } else {
        mlcnc_define_mill \
            -discretespeeds 0 \
            -minrpm $msmin \
            -maxrpm $msmax \
            -fixedrpm 0 \
            -autotoolchanger 0 \
            -maxfeed 15.0 \
            -hp $mhp
    }
    mlcnc_define_stock 1.0 1.0 0.5 -material $smat
    mlcnc_define_tool 99 $tdiam -material $tmat -flutes $tflt
    mlcnc_select_tool 99

    set targrpm [mlcnc_rpm]
    set targpfr [mlcnc_feed -plunge]
    set targcfr [mlcnc_feed]
    set targdep [mlcnc_cutdepth -cutwidth $tdiam]

    set ofr $base.ofr
    $ofr.spd configure -text "RPM Speed:   $targrpm"
    $ofr.pfr configure -text "Plunge Rate: $targpfr IPM"
    $ofr.cfr configure -text "Feed Rate:   $targcfr IPM"
    $ofr.dep configure -text "Cut Depth:   $targdep\""
}


# vim: set ts=4 sw=4 nowrap expandtab: settings

