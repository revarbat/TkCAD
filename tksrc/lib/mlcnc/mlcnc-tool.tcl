
tcl::OptProc mlcnc_define_tool {
    {toolnum -integer "The number of the tool."}
    {diam    -string  "The diameter of the tip of the tool."}
    {-length    0.0   "The length of the tool, for tool length compensation."}
    {-cutlength 0.0   "The length of the cutting edge of the tool."}
    {-bevel     0.0   "The bevel angle of Conical bit."}
    {-flutes    4     "Number of teeth that the tool has."}
    {-type -choice {End Ball "Gear Cutter"} "Material that the tool is made out of."}
    {-material -choice {HSS Carbide} "Material that the tool is made out of."}
    {-coating -choice {None TiN TiCN TiAlN AlTiN Diamond Diamondlike} "Material that the tool is coated with."}
} {
    global mlcncToolInfo
    set origdiam $diam
    if {[string first "/" $diam] != -1} {
        foreach {denominator divisor} [split $diam "/"] break
        set denominator [expr {$denominator+0.0}]
        set divisor [expr {$divisor+0.0}]
        set diam [expr {$denominator/$divisor}]
    }
    if {$cutlength == 0.0} {
        set cutlength [expr {$diam*3.0}]
    }
    set name "$toolnum: $origdiam\" $material ${flutes}flt"
    if {$type != "End"} {
        append name " $type"
    }

    set mlcncToolInfo(TOOLNAME-$toolnum) $name
    set mlcncToolInfo(TOOLDIAM-$toolnum) $diam
    set mlcncToolInfo(TOOLLEN-$toolnum) $length
    set mlcncToolInfo(TOOLCUTLEN-$toolnum) $cutlength
    set mlcncToolInfo(TOOLTEETH-$toolnum) $flutes
    set mlcncToolInfo(TOOLTYPE-$toolnum) $type
    set mlcncToolInfo(TOOLANGLE-$toolnum) $bevel
    set mlcncToolInfo(TOOLMATERIAL-$toolnum) $material
    set mlcncToolInfo(TOOLCOATING-$toolnum) $coating
    if {![info exists mlcncToolInfo(CURRTOOL)]} {
        set mlcncToolInfo(CURRTOOL) $toolnum
    }
}


tcl::OptProc mlcnc_select_tool {
    {toolnum -integer "The number of the tool to select."}
} {
    global mlcncToolInfo
    if {![info exists mlcncToolInfo(TOOLDIAM-$toolnum)]} {
        error "That tool was not was defined.  Use mlcnc_define_tool to define it."
    }
    set mlcncToolInfo(CURRTOOL) $toolnum
}


proc mlcnc_get_tools {} {
    global mlcncToolInfo
    set out {}
    foreach key [array names mlcncToolInfo "TOOLNAME-*"] {
        set toolnum [string range $key 9 end]
        lappend out $toolnum
    }
    return $out
}


proc mlcnc_get_tool {} {
    global mlcncToolInfo
    if {![info exists mlcncToolInfo(CURRTOOL)]} {
        error "No tool was defined.  Use mlcnc_define_tool to define a tool."
    }
    return $mlcncToolInfo(CURRTOOL)
}


proc mlcnc_tool_get_name {toolnum} {
    global mlcncToolInfo
    return $mlcncToolInfo(TOOLNAME-$toolnum)
}


proc mlcnc_tooldiam {{toolnum ""}} {
    global mlcncToolInfo
    if {$toolnum == ""} {
        set toolnum [mlcnc_get_tool]
    }
    return $mlcncToolInfo(TOOLDIAM-$toolnum)
}


proc mlcnc_toolcutlen {{toolnum ""}} {
    global mlcncToolInfo
    if {$toolnum == ""} {
        set toolnum [mlcnc_get_tool]
    }
    return $mlcncToolInfo(TOOLCUTLEN-$toolnum)
}


proc mlcnc_toollen {{toolnum ""}} {
    global mlcncToolInfo
    if {$toolnum == ""} {
        set toolnum [mlcnc_get_tool]
    }
    return $mlcncToolInfo(TOOLLEN-$toolnum)
}


proc mlcnc_toolteeth {{toolnum ""}} {
    global mlcncToolInfo
    if {$toolnum == ""} {
        set toolnum [mlcnc_get_tool]
    }
    return $mlcncToolInfo(TOOLTEETH-$toolnum)
}


proc mlcnc_tooltype {{toolnum ""}} {
    global mlcncToolInfo
    if {$toolnum == ""} {
        set toolnum [mlcnc_get_tool]
    }
    return $mlcncToolInfo(TOOLTYPE-$toolnum)
}


proc mlcnc_toolmaterial {{toolnum ""}} {
    global mlcncToolInfo
    if {$toolnum == ""} {
        set toolnum [mlcnc_get_tool]
    }
    return $mlcncToolInfo(TOOLMATERIAL-$toolnum)
}



proc mlcnc_toolcoating {{toolnum ""}} {
    global mlcncToolInfo
    if {$toolnum == ""} {
        set toolnum [mlcnc_get_tool]
    }
    return $mlcncToolInfo(TOOLCOATING-$toolnum)
}



proc mlcnc_tool_selector_widget_repopulate {w} {
    global mlcncToolInfo
    catch {$w.menu delete 0 end}
    foreach toolnum [lsort -integer [mlcnc_get_tools]] {
        set name [mlcnc_tool_get_name $toolnum]
        set var mlcncToolInfo(WIDGETVAL-$w)
        if {![info exists $var]} {
            set $var $toolnum
            $w configure -text $name
        } elseif {[set $var] == $toolnum} {
            $w configure -text $name
        }
        $w.menu add radiobutton -label $name -value $toolnum \
            -variable $var -command [list $w configure -text $name]
    }
}



proc mlcnc_tool_selector_widget {w} {
    menubutton $w -text "" -menu $w.menu \
        -relief raised -indicatoron 1 -direction flush -takefocus 1
    menu $w.menu -tearoff false
    mlcnc_tool_selector_widget_repopulate $w
}



proc mlcnc_tool_selector_widget_getval {w} {
    global mlcncToolInfo
    return $mlcncToolInfo(WIDGETVAL-$w)
}



# vim: set ts=4 sw=4 nowrap expandtab: settings

