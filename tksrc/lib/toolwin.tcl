proc toolwin_init {} {
    global toolwinInfo
    set toolwinInfo(GROUPS) {}
}


proc toolwin_create {base} {
    global toolwinInfo
    set toolwinInfo(BNUM-$base) 0
    toplevel $base
    return $base
}


proc toolwin_repack {base} {
    set maxcols 1
    set col 0
    set row 0
    foreach child [winfo children $base] {
        if {[winfo class $child] != "Radiobutton"} {
            continue
        }
        grid forget $child
        grid $child -row $row -column $col -sticky nsew
        if {[incr col] >= $maxcols} {
            set col 0
            incr row
        }
    }
}


proc toolwin_tool_add {base hint groupname imgname varname value command} {
    global toolwinInfo
    global tkcad_images_dir

    set toolgid [tool_group_id $groupname]
    set toolids [tool_group_toolids $toolgid]
    set img [image create photo -file [file join $tkcad_images_dir "$imgname.gif"]]
    

    if {[info exists toolwinInfo(TOOLBTN-IMG-$value)]} {
        return
    }

    lappend toolwinInfo(GROUPTOOLS-$groupname) $value
    set toolwinInfo(TOOLBTN-GROUP-$value) $groupname
    set toolwinInfo(TOOLBTN-HINT-$value) $hint
    set toolwinInfo(TOOLBTN-VAR-$value) $varname
    set toolwinInfo(TOOLBTN-IMG-$value) $img
    set toolwinInfo(TOOLBTN-CMD-$value) $command

    set tkey ""
    if {[regexp -nocase -- {&([A-Z0-9_-])} $hint dummy tkey]} {
        set hint [string map {{&} {}} $hint]
        set tkey [string tolower $tkey]
    }

    if {![info exists toolwinInfo(GROUPBTN-$groupname)]} {
        if {[llength $toolids] <= 1} {
            # Make the tool group button
            set bnum [incr toolwinInfo(BNUM-$base)]
            set btn [radiobutton $base.b$bnum \
                        -indicatoron 0 -highlightthickness 0 \
                        -padx 0 -pady 0 \
                        -variable $varname -value $value \
                        -image $img -command $command]
            bind $btn <FocusIn> "after 10 focus \[mainwin_current\]"
            toolwin_repack $base
            catch { tooltip::tooltip $btn $hint }
            lappend toolwinInfo(GROUPS) $groupname
            set toolwinInfo(GROUPBTN-$groupname) $btn


        } else {
            # Make the expandable tool group button
            set bnum [incr toolwinInfo(BNUM-$base)]
            set btn [radiobutton $base.b$bnum \
                        -indicatoron 0 -highlightthickness 0 \
                        -padx 0 -pady 0 \
                        -variable $varname -value $value \
                        -image $img]
            bind $btn <ButtonPress-1> [list +toolwin_toolbtn_press $base $groupname %s]
            bind $btn <ButtonRelease-1> [list +toolwin_toolbtn_release $base $groupname %X %Y]
            bind $btn <FocusIn> "after 10 focus \[mainwin_current\]"
            toolwin_repack $base
            catch { tooltip::tooltip $btn $hint }
            lappend toolwinInfo(GROUPS) $groupname
            set toolwinInfo(GROUPBTN-$groupname) $btn
            toolwin_update_groupbtn $groupname $value
        }
    }
}


proc toolwin_menu_release {base menwin} {
    toolwin_canvas_rebind $base
    grab release $menwin
    destroy $menwin
}


proc toolwin_canvas_rebind {base} {
    foreach b [bind ToolMenu] {
        bind ToolMenu $b ""
    }
    foreach tgroup [tool_group_ids] {
        set gname [tool_group_name $tgroup]
        set tools [tool_group_toolids $tgroup]
        set tool [lindex $tools 0]

        set gkey ""
        if {[regexp -nocase -- {&([A-Z0-9_-])} $gname dummy gkey]} {
            set gkey [string tolower $gkey]
        }
        if {$gname == "Selector"} {
            set gkey "space"
            append name " ($gkey)"
            bind ToolMenu <Key-$gkey> "tool_set_current $tool"
        } elseif {$gkey != ""} {
            if {[llength $tools] > 1} {
                bind ToolMenu <Key-$gkey> [list toolwin_popup_menu $base $gname]
            } else {
                bind ToolMenu <Key-$gkey> "tool_set_current $tool"
            }
        }
    }
}


proc toolwin_toolbtn_press {base groupname state} {
    global toolwinInfo
    cadobjects_modkey_set $state
    set aftid [after 250 [list toolwin_popup_menu $base $groupname]]
    set toolwinInfo(AFTID) $aftid
}


proc toolwin_toolbtn_release {base groupname x y} {
    global toolwinInfo
    if {[info exists toolwinInfo(AFTID)]} {
        set aftid $toolwinInfo(AFTID)
        unset toolwinInfo(AFTID)
        after cancel $aftid
    } else {
        if {![info exists toolwinInfo(MENUPOPUP)]} {
            return
        }
        set menwin $toolwinInfo(MENUPOPUP)
        if {![winfo exists $menwin]} {
            return
        }
        set gbtn $toolwinInfo(GROUPBTN-$groupname)
        set btn [winfo containing $x $y]
        if {[string match "$menwin.*" $btn]} {
            $btn invoke
        } elseif {![string match "$base.*" $btn]} {
            toolwin_tool_window $base $groupname $x $y
            $gbtn select
        } else {
            $gbtn select
        }
        destroy $menwin
        catch {tooltip::hide}
    }
    confpane_populate
}


proc toolwin_toolbtn_motion {base groupname x y} {
    global toolwinInfo
    if {![info exists toolwinInfo(AFTID)]} {
        set menwin $toolwinInfo(MENUPOPUP)
        set btn [winfo containing $x $y]
        if {[string match "$menwin.*" $btn]} {
            $btn select
            catch {tooltip::show $btn [tooltip::tooltip $btn]}
        }
    }
}


# Create the popup menu tool window
proc toolwin_popup_menu {base groupname} {
    global toolwinInfo

    catch {unset toolwinInfo(AFTID)}

    set mainwin [mainwin_current]
    set toolids $toolwinInfo(GROUPTOOLS-$groupname)

    if {[llength [cadobjects_modkeys_down]] > 0} {
        return
    }

    set num 0
    if {[winfo exists $base.m$num]} {
        raise $base.m$num
        return
    }

    set menwin [toplevel $base.m$num]
    wm overrideredirect $menwin 1
    wm transient $menwin $mainwin

    grab set $menwin
    bind ToolMenu <Key-Escape> "toolwin_menu_release $base $menwin ; continue"
    set toolwinInfo(MENUPOPUP) $menwin
    set grpbtn $toolwinInfo(GROUPBTN-$groupname)
    set gwinx [expr {[winfo rootx $grpbtn]+[winfo width $grpbtn]}]
    set gwiny [winfo rooty $grpbtn]
    wm geometry $menwin +$gwinx+$gwiny

    set bnum 0
    foreach value $toolids  {
        set hint $toolwinInfo(TOOLBTN-HINT-$value)
        set varname $toolwinInfo(TOOLBTN-VAR-$value)
        set img $toolwinInfo(TOOLBTN-IMG-$value)
        set command $toolwinInfo(TOOLBTN-CMD-$value)

        set gkey ""
        if {[regexp -nocase -- {&([A-Z0-9_-])} $groupname dummy gkey]} {
            set gkey [string tolower $gkey]
        }

        set tkey ""
        if {[regexp -nocase -- {&([A-Z0-9_-])} $hint dummy tkey]} {
            set hint [string map {{&} {}} $hint]
            set tkey [string tolower $tkey]
        }

        set cmd "toolwin_update_groupbtn [list $groupname] [list $value]"
        append cmd " ; toolwin_menu_release $base $menwin"
        append cmd " ; $command"

        set btn [radiobutton $menwin.b$bnum \
                    -indicatoron 0 -highlightthickness 0 \
                    -padx 0 -pady 0 \
                    -compound top -text [string toupper "$gkey-$tkey"] \
                    -anchor se -font {Helvetica 9} \
                    -image $img -variable $varname -value $value \
                    -activebackground blue -command $cmd]
        bindtags $btn [list $btn ToolMenu Radiobutton all]
        if {$tkey != ""} {
            bind ToolMenu <Key-$tkey> "if {\[winfo exists $btn\]} {$btn invoke} else {toolwin_canvas_rebind $base; event generate ToolMenu <Key-$tkey>}; break"
        }
        catch { tooltip::tooltip $btn $hint }
        pack $btn -side left
        incr bnum
    }
    bind $menwin <FocusOut> "toolwin_menu_release $base $menwin"
    bind $menwin <ButtonPress-1> "toolwin_menu_release $base $menwin"
    bind $menwin <ButtonRelease-1> [list toolwin_toolbtn_release $base $groupname %X %Y]
    bind $menwin <Motion> [list toolwin_toolbtn_motion $base $groupname %X %Y]
    raise $menwin
}


# Create the a detached tool window
proc toolwin_tool_window {base groupname x y} {
    global toolwinInfo

    toolwin_canvas_rebind $base
    set mainwin [mainwin_current]
    set toolids $toolwinInfo(GROUPTOOLS-$groupname)

    set num 0
    while {[winfo exists $base.w$num]} {
        incr num
    }

    set menwin [toplevel $base.w$num]
    set gname [string map {{&} {}} $groupname]
    wm group $menwin $mainwin
    wm resizable $menwin 0 0
    wm title $menwin $gname
    catch {wm attributes $menwin -toolwindow 1}
    catch {wm attributes $menwin -maximizebox 0}
    catch {wm attributes $menwin -minimizebox 0}
    catch {
        set class "floating"
        #set attrs {noActivates hideOnSuspend closeBox noShadow sideTitlebar}
        #set attrs {noActivates hideOnSuspend closeBox noShadow}
        set attrs {hideOnSuspend closeBox noShadow}
        ::tk::unsupported::MacWindowStyle style $menwin $class $attrs
    }

    set toolwinInfo(MENUPOPUP) $menwin
    wm geometry $menwin +$x+$y

    set bnum 0
    foreach value $toolids  {
        set hint $toolwinInfo(TOOLBTN-HINT-$value)
        set varname $toolwinInfo(TOOLBTN-VAR-$value)
        set img $toolwinInfo(TOOLBTN-IMG-$value)
        set command $toolwinInfo(TOOLBTN-CMD-$value)

        set tkey ""
        if {[regexp -nocase -- {&([A-Z0-9_-])} $hint dummy tkey]} {
            set hint [string map {{&} {}} $hint]
            set tkey [string tolower $tkey]
        }

        set cmd "toolwin_update_groupbtn [list $groupname] [list $value]"
        append cmd " ; $command"

        set btn [radiobutton $menwin.b$bnum \
                    -indicatoron 0 -highlightthickness 0 \
                    -padx 0 -pady 0 \
                    -image $img -variable $varname -value $value \
                    -activebackground blue -command $cmd]
        bindtags $btn [list $btn Radiobutton all]
        catch { tooltip::tooltip $btn $hint }
        pack $btn -side left
        incr bnum
    }
    raise $menwin
}


proc toolwin_update_groupbtn {groupname value} {
    global toolwinInfo

    set grpbtn $toolwinInfo(GROUPBTN-$groupname)
    set hint $toolwinInfo(TOOLBTN-HINT-$value)
    set varname $toolwinInfo(TOOLBTN-VAR-$value)
    set img $toolwinInfo(TOOLBTN-IMG-$value)

    set tkey ""
    if {[regexp -nocase -- {&([A-Z0-9_-])} $hint dummy tkey]} {
        set hint [string map {{&} {}} $hint]
        set tkey [string tolower $tkey]
    }

    set previmg [$grpbtn cget -image]
    if {$previmg != "" && $previmg != $img} {
        image delete $previmg
    }
    set nuimg [image create photo]
    $nuimg copy $img

    # Make a triangle in the corner,
    #  if there's multiple tools in this group
    set trisize 4
    set iconw [image width $nuimg]
    set iconh [image height $nuimg]
    for {set i 0} {$i < $trisize} {incr i} {
        set px [expr {$iconw-$i}]
        for {set j 0} {$j < $trisize-$i} {incr j} {
            set py [expr {$iconh-$j}]
            $nuimg put #000000 -to $px $py
        }
    }

    set gname [string map {{&} {}} $groupname]
    $grpbtn configure -image $nuimg -value $value
    catch { tooltip::tooltip $grpbtn "$gname:\n$hint" }
}



toolwin_init

# vim: set ts=4 sw=4 nowrap expandtab: settings


