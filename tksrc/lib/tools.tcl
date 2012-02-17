proc tools_startup {} {
    global toolsInfo
    set toolsInfo(TOOLS) {}
    set toolsInfo(TOOLNUM) 0
    set toolsInfo(TGROUPS) {}
    set toolsInfo(TGROUPNUM) 0
    tool_register_ex "OBJSEL"  "Selector" "Select Objects" {} -icon "tool-objsel"  -cursor "arrow"
    tool_register_ex "NODESEL" "&Nodes"   "Select &Nodes"  {} -icon "tool-nodesel" -cursor "top_left_arrow" -showctls
}


proc tool_canvas_init {canv toolwin toolchangecb} {
    global toolsInfo
    tool_set_current 1
    tool_set_state "INIT"
    foreach tgroup [tool_group_ids] {
        set gname [tool_group_name $tgroup]
        foreach tool [tool_group_toolids $tgroup] {
            set name [tool_name $tool]
            set imgname [tool_image $tool]
            set toolgroup [tool_group $tool]
            set grpname [tool_group_name $toolgroup]

            set gkey ""
            if {[regexp -nocase -- {&([A-Z0-9_-])} $grpname dummy gkey]} {
                set gkey [string tolower $gkey]
            }
            set tkey ""
            if {[regexp -nocase -- {&([A-Z0-9_-])} $name dummy tkey]} {
                set tkey [string tolower $tkey]
            }
            if {$grpname == "Selector"} {
                set gkey "space"
                append name " ($gkey)"
                bind ToolMenu <Key-$gkey> "tool_set_current $tool"
            } elseif {$gkey != ""} {
                if {$tkey != ""} {
                    append name [string toupper " ($gkey-$tkey)"]
                    bind ToolMenu <Key-$gkey> [list toolwin_popup_menu $toolwin $grpname]
                } else {
                    append name [string toupper " ($gkey)"]
                    bind ToolMenu <Key-$gkey> "tool_set_current $tool"
                }
            }

            toolwin_tool_add $toolwin $name $grpname $imgname toolsInfo(CURRTOOL) $tool $toolchangecb
        }
    }
}


proc tool_group_ids {} {
    global toolsInfo
    return $toolsInfo(TGROUPS)
}


proc tool_group_toolids {toolgid} {
    global toolsInfo
    if {![info exists toolsInfo(TGROUPTOOLS-$toolgid)]} {
        return {}
    }
    return $toolsInfo(TGROUPTOOLS-$toolgid)
}


proc tool_group_id {toolgroup} {
    global toolsInfo
    if {![info exists toolsInfo(TGROUP-$toolgroup)]} {
        set toolgid [incr toolsInfo(TGROUPNUM)]
        set toolsInfo(TGROUP-$toolgroup) $toolgid
        set toolsInfo(TGROUPNAME-$toolgid) $toolgroup
        set toolsInfo(TGROUPTOOLS-$toolgid) {}
        lappend toolsInfo(TGROUPS) $toolgid
    }
    return $toolsInfo(TGROUP-$toolgroup)
}


proc tool_group_name {toolgid} {
    global toolsInfo
    return $toolsInfo(TGROUPNAME-$toolgid)
}


tcl::OptProc tool_register_ex {
    {token         {}          "The token to use for the tool."}
    {toolgroup     {}          "The control group to list the tool under, in the tools window."}
    {name          {}          "The human-friendly name to show in tooltips in the tools window."}
    {nodeinfo      {}          "List of what nodes/coords are needed by this tool."}
    {-impfields    {}          "List of extra DATUMS to save for objects of this type."}
    {-icon         {}          "The icon image to use in the tools window."}
    {-cursor       {crosshair} "The cursor to use for this tool in the main window."}
    {-snaps        {all}       "Snaps to allow when using this tool."}
    {-creator                  "This tool creates objects."}
    {-showctls                 "This tool should show control nodes when selected."}
} {
    tool_register $token $toolgroup $name $icon $cursor $nodeinfo $impfields $creator $snaps $showctls
}


proc tool_register {token toolgroup name icon cursor nodeinfo impfields {creator 1} {snaps "all"} {showctls 0} {accel ""}} {
    global toolsInfo
    set toolid [incr toolsInfo(TOOLNUM)]
    set toolgid [tool_group_id $toolgroup]
    lappend toolsInfo(TOOLS) $toolid
    set toolsInfo(TOOLTOKEN-$toolid) $token
    set toolsInfo(TOOLISCREATOR-$toolid) $creator
    set toolsInfo(TOOLGROUP-$toolid) $toolgid
    lappend toolsInfo(TGROUPTOOLS-$toolgid) $toolid
    set toolsInfo(TOOLNAME-$toolid) $name
    set toolsInfo(TOOLIMAGE-$toolid) $icon
    set toolsInfo(TOOLCURSOR-$toolid) $cursor
    set toolsInfo(TOOLSNAPS-$toolid) $snaps
    set toolsInfo(TOOLSHOWCTLS-$toolid) $showctls
    set toolsInfo(TOOLKEYBIND-$toolid) $accel
    set toolsInfo(TOOLNODEINFO-$toolid) $nodeinfo
    set nodecount [llength $nodeinfo]
    if {[lindex [lindex $nodeinfo end] 0] == "..."} {
        incr nodecount -1
    }
    set toolsInfo(OBJNODECOUNT-$token) $nodecount
    lappend impfields FILLCOLOR LINECOLOR LINEWIDTH LINEDASH CUTBIT CUTDEPTH CUTSIDE
    set toolsInfo(OBJIMPFIELDS-$token) $impfields
}


proc tool_get_nodecount_from_token {token} {
    global toolsInfo
    return $toolsInfo(OBJNODECOUNT-$token)
}


proc tool_get_important_fields {token} {
    global toolsInfo
    if {[info exists toolsInfo(OBJIMPFIELDS-$token)]} {
        return $toolsInfo(OBJIMPFIELDS-$token)
    }
    return {}
}



proc tool_ids {} {
    global toolsInfo
    return $toolsInfo(TOOLS)
}


proc tool_token {toolid} {
    global toolsInfo
    return $toolsInfo(TOOLTOKEN-$toolid)
}


proc tool_isselector {toolid} {
    set tgid [tool_group $toolid]
    set tgname [tool_group_name $tgid]
    if {$tgname == "Selector"} {
        return 1
    }
    if {$tgname == "&Nodes"} {
        return 1
    }
    return 0
}


proc tool_iscreator {toolid} {
    global toolsInfo
    return $toolsInfo(TOOLISCREATOR-$toolid)
}


proc tool_group {toolid} {
    global toolsInfo
    return $toolsInfo(TOOLGROUP-$toolid)
}


proc tool_name {toolid} {
    global toolsInfo
    return $toolsInfo(TOOLNAME-$toolid)
}


proc tool_image {toolid} {
    global toolsInfo
    return $toolsInfo(TOOLIMAGE-$toolid)
}


proc tool_cursor {toolid} {
    global toolsInfo
    return $toolsInfo(TOOLCURSOR-$toolid)
}


proc tool_snaps {toolid} {
    global toolsInfo
    return $toolsInfo(TOOLSNAPS-$toolid)
}


proc tool_showctls {toolid} {
    global toolsInfo
    return $toolsInfo(TOOLSHOWCTLS-$toolid)
}


proc tool_nodeinfo {toolid} {
    global toolsInfo
    return $toolsInfo(TOOLNODEINFO-$toolid)
}


proc tool_setdatum {toolid datum value} {
    global toolsInfo
    set toolsInfo(TOOLDATUM-$toolid-$datum) $value
}



proc tool_getdatum {toolid datum} {
    global toolsInfo
    if {[info exists toolsInfo(TOOLDATUM-$toolid-$datum)]} {
        return $toolsInfo(TOOLDATUM-$toolid-$datum)
    }
    return ""
}


proc tool_clear_datums {toolid} {
    global toolsInfo
    foreach key [array names toolsInfo "TOOLDATUM-$toolid-*"] {
        unset toolsInfo($key)
    }
    return
}




proc tool_current {} {
    global toolsInfo
    return $toolsInfo(CURRTOOL)
}


proc tool_set_current {val} {
    global toolsInfo
    set toolsInfo(CURRTOOL) $val
    return
}


proc tool_get_state {} {
    global toolsInfo
    return $toolsInfo(TOOLSTATE)
}


proc tool_set_state {state} {
    global toolsInfo
    set toolsInfo(TOOLSTATE) $state
}


tools_startup

# vim: set ts=4 sw=4 nowrap expandtab: settings

