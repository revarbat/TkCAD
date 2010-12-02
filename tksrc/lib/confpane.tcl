proc confpane_validate_combobox {combo} {
    set var [$combo cget -textvariable]
    set vcmd [$combo cget -validatecommand]
    set invcmd [$combo cget -invalidcommand]
    upvar #0 $var val
    regsub -all "%P" $vcmd [list $val] vcmd
    if {![eval $vcmd]} {
        eval $invcmd
    }
}


proc confpane_invalidcmd {canv name datum valgetcb def var} {
    bell
    set oldval [confpane_getdatum $canv $name $datum $valgetcb $def]
    after idle [list set $var $oldval]
}


proc confpane_invalidcmd_point {canv name datum valgetcb def cnum var} {
    bell
    set oldval [confpane_getdatum $canv $name $datum $valgetcb $def]
    set oldval [lindex $oldval $cnum]
    after idle [list set $var $oldval]
}


proc confpane_invalidcmd_fontsize {canv name datum valgetcb def var} {
    bell
    set oldval [confpane_getdatum $canv $name $datum $valgetcb $def]
    set oldval [lindex $oldval 1]
    after idle [list set $var $oldval]
}


proc confpane_validate_str {canv name datum valsetcb validatecb value} {
    global confpaneInfo
    if {$confpaneInfo(NOVALIDATE)} {
        return 1
    }
    if {$value == ""} {
        return 1
    }
    if {$validatecb != ""} {
        set res [eval $validatecb [list $value]]
        if {!$res} {
            return 0
        }
    }
    confpane_setdatum $canv $name $datum $valsetcb $value
    return 1
}


proc confpane_validate_int {canv name datum min max valsetcb validatecb value} {
    global confpaneInfo
    if {$confpaneInfo(NOVALIDATE)} {
        return 1
    }
    if {$value == ""} {
        return 1
    }
    if {![string is integer -strict $value]} {
        return 0
    }
    if {$value < $min || $value > $max} {
        return 0
    }
    if {$validatecb != ""} {
        if {![eval $validatecb $value]} {
            return 0
        }
    }
    confpane_setdatum $canv $name $datum $valsetcb $value
    return 1
}


proc confpane_validate_float {canv name datum min max valsetcb validatecb islength value} {
    global confpaneInfo
    if {$confpaneInfo(NOVALIDATE)} {
        return 1
    }
    if {$value == ""} {
        return 1
    }
    if {$islength} {
        lassign [cadobjects_unit_system $canv] usys isfract unitmult unit
        set value [util_number_value $value $unit]
        if {$value != ""} {
            set value [expr {$value/$unitmult}]
        }
    } else {
        set value [util_number_value $value]
    }
    if {$value == ""} {
        return 0
    }
    if {$value < $min || $value > $max} {
        return 0
    }
    if {$validatecb != ""} {
        if {![eval $validatecb $value]} {
            return 0
        }
    }
    confpane_setdatum $canv $name $datum $valsetcb $value
    return 1
}


proc confpane_validate_point {canv name datum valsetcb cnum value} {
    global confpaneInfo
    if {$confpaneInfo(NOVALIDATE)} {
        return 1
    }
    if {$value == ""} {
        return 1
    }
    lassign [cadobjects_unit_system $canv] usys isfract unitmult unit
    set value [util_number_value $value $unit]
    if {$value == ""} {
        return 0
    }
    set value [expr {$value/$unitmult}]
    confpane_set_point_val $canv $name $datum $valsetcb $cnum $value
    return 1
}


proc confpane_validate_fontsize {canv name datum valsetcb base value} {
    global confpaneInfo
    if {$confpaneInfo(NOVALIDATE)} {
        return 1
    }
    if {$value == ""} {
        return 1
    }
    if {![string is integer -strict $value]} {
        return 0
    }
    if {$value < 1} {
        return 0
    }
    confpane_setfontdatum $canv $name $datum $valsetcb $base
    return 1
}


proc confpane_clearcolor {canv name datum valsetcb colorbox} {
    $colorbox configure -background white -foreground black -text "None"
    confpane_setdatum $canv $name $datum $valsetcb none
}


proc confpane_editcolor {canv name datum valsetcb colorbox} {
    set parent [winfo toplevel $canv]
    set title "Choose a new color"
    set oldcolor [$colorbox cget -background]
    set color [tk_chooseColor -initialcolor $oldcolor -parent $parent -title $title]
    if {$color == ""} {
        return
    }
    $colorbox configure -background $color -foreground $color -text ""
    confpane_setdatum $canv $name $datum $valsetcb $color
}


proc confpane_incdatum {canv name datum min max valsetcb islength fmt sbox dir} {
    set increment [$sbox cget -increment]
    set val [$sbox get]
    if {$val == ""} {
        return
    }
    lassign [cadobjects_unit_system $canv] usys isfract unitmult unit
    if {$islength} {
        set val [util_number_value $val $unit]
    } else {
        set val [util_number_value $val]
    }
    if {$val == ""} {
        return
    }
    if {$dir == "up"} {
        if {$val + $increment >= $max - 1e-6} {
            return
        }
        set val [expr {$val+$increment}]
    } else {
        if {$val - $increment <= $min - 1e-6} {
            return
        }
        set val [expr {$val-$increment}]
    }
    set valeng [format $fmt $val]
    if {$islength} {
        set val [expr {$val/$unitmult}]
    }
    $sbox delete 0 end
    $sbox insert end $valeng
    confpane_setdatum $canv $name $datum $valsetcb $val
}


proc confpane_setfontdatum {canv name datum valsetcb base args} {
    global confpaneInfo

    set famvar confpaneInfo(FONTMB-$canv-$name)
    set sizvar confpaneInfo(SIZESP-$canv-$name)
    set boldvar confpaneInfo(BOLDCB-$canv-$name)
    set italvar confpaneInfo(ITALCB-$canv-$name)

    set objids [cadselect_list $canv]
    foreach objid $objids {
        set ffam [set $famvar]
        set fsiz [set $sizvar]
        set fbold [set $boldvar]
        set fital [set $italvar]

        set oldfont [cadobjects_object_getdatum $canv $objid $datum]
        if {$ffam == ""} {
            set ffam [lindex $oldfont 0]
        }
        if {$fsiz == ""} {
            set fsiz [lindex $oldfont 1]
        }
        if {$fbold == ""} {
            set fbold [expr {"bold" in $oldfont}]
        }
        if {$fital == ""} {
            set fital [expr {"italic" in $oldfont}]
        }

        set font [list $ffam $fsiz]
        if {$fbold} {
            lappend font "bold"
        }
        if {$fital} {
            lappend font "italic"
        }

        #set famcb $base.datafam
        #$famcb configure -font [lreplace $font 1 1 12]
        confpane_setdatum $canv $name $datum $valsetcb $font
    }
}


proc confpane_set_point_val {canv name datum valsetcb cnum value} {
    set toolid [tool_current]
    if {![tool_isselector $toolid] && ![tool_iscreator $toolid]} {
        set tooltoken [tool_token $toolid]
        if {$valsetcb != ""} {
            set cmd "$valsetcb $canv [list $name $cnum] [list $value]"
            eval $cmd
        } elseif {$datum != ""} {
            if {[string is integer $datum]} {
                # If datum is integer, get a coord point.
                set pos [expr {$datum*2+$cnum}]
                set coords [cadobjects_tool_get_coords $canv]
                while {[llength $coords] < $pos} {
                    lappend $coords 0.0 0.0
                }
                set coords [lreplace $coords $pos $pos $value]
                cadobjects_tool_set_coords $canv $coords
            } else {
                tool_setdatum $toolid $datum $value
            }
        }
        set coords [cadobjects_tool_get_coords $canv]
        cadobjects_toolcall "preview" $canv $tooltoken $coords 1
        #after idle confpane_populate
        return
    }
    cutpaste_set_checkpoint $canv
    set odatum $datum
    set objids [cadselect_list $canv]
    foreach objid $objids {
        set datum $odatum
        set coords [cadobjects_object_get_coords $canv $objid]

        if {$valsetcb != ""} {
            cutpaste_remember_change $canv $objid
            eval $valsetcb $canv $objid [list $coords] [list $name $cnum] [list $value]
        }

        if {$datum != ""} {
            set propagate 1
            if {$datum == "_end"} {
                set propagate 0
                set datum [expr {[llength $coords]/2-1}]
            } elseif {$datum == "_selnode"} {
                set datum [lindex [cadselect_node_list $canv $objid] 0]
                if {$datum != ""} {
                    incr datum -1
                    set propagate 0
                } else {
                    set datum [expr {[llength $coords]/2-1}]
                }
            } elseif {[string index $datum 0] == "#"} {
                set propagate 0
                set datum [string range $datum 1 end]
            }
            if {[string is integer $datum]} {
                # If datum is integer, set a coord point value.
                set coords [cadobjects_object_get_coords $canv $objid]
                set origcoords $coords
                set pos [expr {$datum*2+$cnum}]
                set origval [lindex $coords $pos]
                set delta [expr {$value-$origval}]
                while {$pos < [llength $coords]} {
                    set origval [lindex $coords $pos]
                    set nuval [expr {$origval+$delta}]
                    set coords [lreplace $coords $pos $pos $nuval]
                    incr pos 2
                    if {!$propagate} {
                        break
                    }
                }
                if {$coords != $origcoords} {
                    cutpaste_remember_change $canv $objid
                    cadobjects_object_set_coords $canv $objid $coords
                }
            } else {
                set origval [cadobjects_object_getdatum $canv $objid $datum]
                if {$value != $origval} {
                    cutpaste_remember_change $canv $objid
                    cadobjects_object_setdatum $canv $objid $datum $value
                }
            }
        }

        cadobjects_object_recalculate $canv $objid
        cadobjects_object_draw $canv $objid
        after idle confpane_populate
    }
}


proc confpane_get_persistent {canv datum def} {
    global confpaneInfo
    if {![info exists confpaneInfo(PERSISTVALS-$canv-$datum)]} {
        set confpaneInfo(PERSISTVALS-$canv-$datum) $def
        lappend confpaneInfo(PERSISTS-$canv) $datum
    }
    set datval $confpaneInfo(PERSISTVALS-$canv-$datum)
    return $datval
}


proc confpane_getdatum {canv name datum valgetcb {def ""}} {
    global confpaneInfo
    set toolid [tool_current]
    if {![info exists confpaneInfo(PERSISTS-$canv)]} {
        set confpaneInfo(PERSISTS-$canv) ""
    }
    set persists $confpaneInfo(PERSISTS-$canv)
    if {![tool_isselector $toolid] && ![tool_iscreator $toolid] && $datum ni $persists} {
        if {$valgetcb != ""} {
            set coords [cadobjects_tool_get_coords $canv]
            set cmd "$valgetcb $canv [list $coords] [list $name]"
            set datval [eval $cmd]
        } elseif {$datum != ""} {
            if {[string is integer $datum]} {
                # If datum is integer, get a coord point.
                set pos [expr {$datum*2}]
                set coords [cadobjects_tool_get_coords $canv]
                set datval [lrange $coords $pos [incr pos]]
            } else {
                set datval [tool_getdatum $toolid $datum]
            }
            if {$datval == ""} {
                set datval $def
            }
        } else {
            set datval $def
        }
        if {$datum != "" && [tool_getdatum $toolid $datum] == ""} {
            tool_setdatum $toolid $datum $datval
        }
        return $datval
    }
    set datvals {}
    set objids [cadselect_list $canv]
    foreach objid $objids {
        set coords [cadobjects_object_get_coords $canv $objid]
        set valgetcb {}
        set res [cadobjects_objcall "editfields" $canv $objid]
        if {$res != ""} {
            set fields [lindex $res 1]
            foreach field $fields {
                if {[dict get $field name] == $name} {
                    catch {set valgetcb [dict get $field valgetcb]}
                }
            }
        }
        if {$valgetcb != ""} {
            set cmd "$valgetcb $canv $objid [list $coords] [list $name]"
            set datval [eval $cmd]
        } elseif {$datum != ""} {
            set datumname $datum
            if {$datum == "_end"} {
                set datumname [expr {[llength $coords]/2-1}]
            } elseif {$datum == "_selnode"} {
                set datumname [lindex [cadselect_node_list $canv $objid] 0]
                if {$datumname != ""} {
                    incr datumname -1
                } else {
                    set datumname [expr {[llength $coords]/2-1}]
                }
            } elseif {[string index $datumname 0] == "#"} {
                set datumname [string range $datumname 1 end]
            }
            if {$datumname == ""} {
                set datval ""
            } elseif {[string is integer $datumname]} {
                # If datum is integer, get a coord point.
                set pos [expr {$datumname*2}]
                set coords [cadobjects_object_get_coords $canv $objid]
                set datval [lrange $coords $pos [incr pos]]
            } else {
                # Get extended datum.
                set datval [cadobjects_object_getdatum $canv $objid $datum]
            }
            if {$datval == ""} {
                set datval $def
            }
        } else {
            set datval $def
        }
        if {$datum != "" && [tool_getdatum $toolid $datum] == ""} {
            tool_setdatum $toolid $datum $datval
        }
        set valfound 0
        foreach datvalsval $datvals {
            if {[string is double -strict $datval] && [string is double -strict $datvalsval]} {
                if {abs($datval-$datvalsval) < 1e-6} {
                    set valfound 1
                }
            } elseif {$datval == $datvalsval} {
                set valfound 1
            }
        }
        if {!$valfound} {
            lappend datvals $datval
        }
    }
    if {[llength $datvals] == 0 && [llength $objids] == 0} {
        set datval [confpane_get_persistent $canv $datum $def]
    } elseif {[llength $datvals] == 1} {
        set datval [lindex $datvals 0]
    } else {
        set datval ""
    }
    return $datval
}


proc confpane_setdatum {canv name datum valsetcb value} {
    global confpaneInfo
    set toolid [tool_current]
    set confpaneInfo(PERSISTVALS-$canv-$datum) $value
    set persists $confpaneInfo(PERSISTS-$canv)
    if {![tool_isselector $toolid] && ![tool_iscreator $toolid] && $datum ni $persists} {
        set tooltoken [tool_token $toolid]
        if {$valsetcb != ""} {
            set cmd "$valsetcb $canv [list $name] [list $value]"
            eval $cmd
        } elseif {$datum != ""} {
            tool_setdatum $toolid $datum $value
        }
        set coords [cadobjects_tool_get_coords $canv]
        cadobjects_toolcall "preview" $canv $tooltoken $coords 1
        #after idle confpane_populate
        return
    }
    cutpaste_set_checkpoint $canv
    set objids [cadselect_list $canv]
    foreach objid $objids {
        set origval [cadobjects_object_getdatum $canv $objid $datum]
        if {$value != $origval} {
            cutpaste_remember_change $canv $objid

            set valsetcb {}
            set res [cadobjects_objcall "editfields" $canv $objid]
            if {$res != ""} {
                set fields [lindex $res 1]
                foreach field $fields {
                    if {[dict get $field name] == $name} {
                        catch {set valsetcb [dict get $field valsetcb]}
                    }
                }
            }
            if {$valsetcb != ""} {
                set coords [cadobjects_object_get_coords $canv $objid]
                eval $valsetcb $canv $objid [list $coords] [list $name] [list $value]
            }

            if {$datum != ""} {
                cadobjects_object_setdatum $canv $objid $datum $value
            }

            cadobjects_object_recalculate $canv $objid
            cadobjects_object_draw $canv $objid
            after idle confpane_populate
        }
    }
}



proc confpane_invoke_exec {canv doinvoke dummy} {
    if {$doinvoke} {
        global confpaneInfo
        if {[info exists confpaneInfo(EXECBTN-$canv)]} {
            set btn $confpaneInfo(EXECBTN-$canv)
            after 10 $btn invoke
        }
    }
    focus $canv
}


proc confpane_execute {canv name} {
    cutpaste_set_checkpoint $canv
    set toolid [tool_current]
    set tooltoken [tool_token $toolid]
    set coords [cadobjects_tool_get_coords $canv]
    cadobjects_toolcall "execute" $canv $tooltoken $coords 1
}


proc confpane_fontmenu_populate {w cmd var} {
    if {[$w index end] == "none"} {
        foreach fam [font_families] {
            $w add radiobutton -label $fam -font [list $fam 12] -value $fam -variable $var -command $cmd
        }
    }
    $w add command -label "====================="
    $w delete last
}


proc confpane_focus {fieldname} {
    global confpaneInfo
    set confpaneInfo(FOCUSFIELD) $fieldname
}


proc confpane_populate {} {
    global confpaneInfo
    if {![info exists confpaneInfo(POPAFTPID)]} {
        set confpaneInfo(POPAFTPID) [after 50 confpane_populate_really]
        catch {unset confpaneInfo(FOCUSFIELD)}
    }
}


proc confpane_populate_really {} {
    global confpaneInfo
    catch {unset confpaneInfo(POPAFTPID)}

    set win [mainwin_current]
    set canv [mainwin_get_canvas $win]
    if {![winfo exists $canv]} {
        return
    }
    set confpaneInfo(NOVALIDATE) 1

    set mainwin [cadobjects_mainwin $canv]
    set infowin [mainwin_get_infopane $mainwin]
    set icnf [infopanewin_get_conf_pane $infowin]
    set editwin [mainwin_get_editpane $mainwin]
    set scnf [editpanewin_get_conf_pane $editwin]
    set ccnf [editpanewin_get_cam_pane $editwin]
    lassign [cadobjects_unit_system $canv] usys isfract unitmult unit

    set fields {}
    set commonfields {}
    set objids [cadselect_list $canv]
    set toolid [tool_current]

    lappend commonfields {
        pane STROKE
        type COLOR
        name LINECOLOR
        title "Stroke Color"
        default black
        persist 1
    }
    lappend commonfields {
        pane STROKE
        type COLOR
        name FILLCOLOR
        title "Fill Color"
        default none
        persist 1
    }
    lappend commonfields {
        pane STROKE
        type FLOAT
        name LINEWIDTH
        title "Stroke Width"
        fmt "%.4f"
        width 8
        min 0.0
        max 10.0
        increment 0.001
        default 0.0050
        persist 1
        islength 1
    }
    lappend commonfields {
        pane STROKE
        type OPTIONS
        name LINEDASH
        title "Stroke Style"
        width 8
        values {" ━━━━━" solid " · · · · · · · ·" construction " - - - - - -" hidden " — · — · —" centerline " — · · — · ·" cutline}
        default solid
        persist 1
    }
    set bits {"No Cut" 0 "Layer Bit" inherit}
    foreach bitnum [lsort -integer [mlcnc_get_tools]] {
        if {$bitnum != 99} {
            set bitname [mlcnc_tool_get_name $bitnum]
            lappend bits $bitname $bitnum
        }
    }
    lappend commonfields [list \
        pane CAM \
        type OPTIONS \
        name CUTBIT \
        title "Cut Bit" \
        width 16 \
        values $bits \
        default inherit \
        persist 1 \
    ]
    lappend commonfields {
        pane CAM
        type FLOAT
        name CUTDEPTH
        title "Cut Depth"
        fmt "%.4f"
        width 8
        min -100.0
        max 100.0
        increment 0.005
        default 0.0000
        persist 1
        islength 1
    }

    set cant_be_different {type datum title values}
    if {[tool_isselector $toolid] || [tool_iscreator $toolid]} {
        set istoolconf 0

        foreach objid $objids {
            set fields {}
            set res [cadobjects_objcall "editfields" $canv $objid]
            if {$res != ""} {
                set fields [lindex $res 1]
            }
            set coords [cadobjects_object_get_coords $canv $objid]
            for {set i 0} {$i < [llength $fields]} {incr i} {
                set field [lindex $fields $i]
                if {[dict get $field type] == "POINTS"} {
                    set nodes [cadselect_node_list $canv $objid]
                    if {[llength $nodes] == 0} {
                        for {set j 1} {$j <= [llength $coords]/2 && $j <= 9} {incr j} {
                            lappend nodes $j
                        }
                    }
                    set nodes [lrange $nodes 0 9]
                    set nuflds {}
                    foreach node $nodes {
                        set nufld {}
                        foreach {key val} $field {
                            if {$key == "type"} {
                                set val POINT
                            }
                            set num $node
                            if {$key == "datum"} {
                                incr num -1
                            }
                            lappend nufld $key [format $val $num]
                        }
                        lappend nuflds $nufld
                    }
                    set fields [lreplace $fields $i $i]
                    foreach nufld $nuflds {
                        set fields [linsert $fields $i $nufld]
                        incr i
                    }
                }
            }
            foreach field $fields {
                catch {unset data}
                set data(type) ""
                set data(name) ""
                set data(persist) 0
                set data(datum) "---"
                array set data $field
                set name $data(name)
                if {$data(datum) == "---"} {
                    set data(datum) $name
                }
                if {![info exists fieldcnt($name)]} {
                    set fieldcnt($name) 0
                }
                set matches 1
                set coordslen [expr {[llength $coords]/2}]
                if {![catch {dict get $field mincoords} mincoords]} {
                    if {$coordslen < $mincoords} {
                        set matches 0
                        continue
                    }
                }
                if {![catch {dict get $field maxcoords} maxcoords]} {
                    if {$coordslen > $maxcoords} {
                        set matches 0
                        continue
                    }
                }
                if {[info exists fielddat($name-type)]} {
                    foreach fldpart $cant_be_different {
                        if {[info exists data($fldpart)]} {
                            if {![info exists fielddat($name-$fldpart)]} {
                                set matches 0
                                break
                            } elseif {$fielddat($name-$fldpart) != $data($fldpart)} {
                                if {$fldpart != "values"} {
                                    set matches 0
                                    break
                                }
                                set nuvals {}
                                foreach {fldvlbl fldval} $fielddat($name-$fldpart) {
                                    if {$fldval in $data($fldpart)} {
                                        lappend nuvals $fldvlbl $fldval
                                    }
                                }
                                set fielddat($name-$fldpart) $nuvals
                                set data($fldpart) $nuvals
                                if {[llength $nuvals] == 0} {
                                    set matches 0
                                    break
                                }
                            }
                        } elseif {[info exists fielddat($name-$fldpart)]} {
                            set matches 0
                            break
                        }
                    }
                }
                if {$matches || $data(persist)} {
                    foreach fldpart $cant_be_different {
                        if {[info exists data($fldpart)]} {
                            set fielddat($name-$fldpart) $data($fldpart)
                        }
                    }
                    incr fieldcnt($name)
                }
            }
        }
        set numobjs [llength $objids]
        foreach field $fields {
            catch {unset data}
            set data(type) ""
            set data(name) ""
            set data(persist) 0
            set data(datum) "---"
            array set data $field
            if {$data(datum) == "---"} {
                set data(datum) $data(name)
            }
            set name $data(name)
            if {[info exists fielddat($name-values)]} {
                set data(values) $fielddat($name-values)
            }
            set field [array get data]
            if {$fieldcnt($name) == $numobjs} {
                lappend commonfields $field
            } elseif {$data(persist)} {
                lappend commonfields $field
            }
        }

    } else {
        set istoolconf 1
        set toolid [tool_current]
        set tooltoken [tool_token $toolid]
        set res [cadobjects_toolcall "editfields" $canv $tooltoken]
        if {$res != ""} {
            foreach item [lindex $res 1] {
                lappend commonfields $item
            }
        }
    }

    set focfield ""
    if {[info exists confpaneInfo(FOCUSFIELD)]} {
        set focfield $confpaneInfo(FOCUSFIELD)
    }

    foreach {cnf panefilt} [list $icnf "INFO" $scnf "STROKE" $ccnf "CAM"] {
        set make_widgets 0
        upvar #0 confpaneInfo(PREVFIELDS-$panefilt) prevfields
        if {![info exists prevfields]} {
            set prevfields ""
        }
        if {$commonfields != $prevfields} {
            foreach child [winfo children $cnf] {
                destroy $child
            }
            set make_widgets 1
            set prevfields $commonfields
        }

        set cnt 0
        set colh 0
        set colnum 0
        set rownum 0
        foreach field $commonfields {
            catch {unset data}
            set data(pane) "INFO"
            set data(type) ""
            set data(name) ""
            set data(datum) "---"
            set data(title) ""
            set data(font) ""
            set data(width) 0
            set data(fmt) ""
            set data(min) 0
            set data(max) 100
            set data(values) {}
            set data(increment) 1.0
            set data(valgetcb) ""
            set data(valsetcb) ""
            set data(validatecb) ""
            set data(command) ""
            set data(mincoords) ""
            set data(maxcoords) ""
            set data(invoke) 0
            set data(islength) 0
            set data(default) ""
            set data(persist) 0
            set data(live) 0
            array set data $field

            if {$data(datum) == "---"} {
                set data(datum) $data(name)
            }
            set name $data(name)
            if {$data(pane) != $panefilt} {
                continue
            }

            set datval [confpane_getdatum $canv $name $data(datum) $data(valgetcb) $data(default)]

            set fr $cnf.fr$cnt
            if {$make_widgets} {
                set fr [frame $fr]
                set rowscnt 1
            }

            switch -exact -- $data(type) {
                BUTTON -
                EXEC {
                    if {$make_widgets} {
                        set cmd $data(command)
                        if {$data(type) == "EXEC"} {
                            set cmd "confpane_execute"
                        }
                        set btn [button $fr.cmd -text $data(title) \
                                -width $data(width) \
                                -font TkSmallCaptionFont \
                                -command  "$cmd $canv [list $data(name)]"]
                        pack $btn -side top -expand 0 -padx {100 0}
                        bind $btn <Key-Escape>   "focus $canv"

                        set confpaneInfo(EXECBTN-$canv) $btn
                        set reqh [winfo reqheight $btn]
                    }
                    if {$name == $focfield} {
                        focus $fr.cmd
                    }
                }
                BOOLEAN -
                BOOL {
                    set cbvar confpaneInfo(BOOL-$canv-$name)
                    set $cbvar $datval

                    if {$make_widgets} {
                        set cb [checkbutton $fr.data -text $data(title) \
                                -variable $cbvar -tristatevalue "" \
                                -font TkSmallCaptionFont \
                                -command  "confpane_setdatum $canv [list $data(name)] [list $data(datum)] [list $data(valsetcb)] \[set [list $cbvar]\]"]
                        pack $cb -side left -expand 0
                        bind $cb <Key-Escape>   "focus $canv"

                        set reqh [winfo reqheight $cb]
                    }
                    if {$name == $focfield} {
                        focus $fr.data
                    }
                }
                LABEL {
                    set datvar confpaneInfo(STR-$canv-$name)
                    set $datvar $datval

                    if {$make_widgets} {
                        set titlelbl [label $fr.title -font TkSmallCaptionFont -text "$data(title):"]
                        set datlbl [label $fr.data -font TkSmallCaptionFont -textvariable $datvar]
                        grid columnconfigure $fr 0 -minsize 75
                        grid $titlelbl -column 0 -row 0 -sticky e
                        grid $datlbl -column 1 -row 0 -sticky w

                        set reqh [winfo reqheight $datlbl]
                    }
                }
                STRING -
                STR {
                    set entvar confpaneInfo(STR-$canv-$name)
                    set $entvar $datval

                    if {$make_widgets} {
                        set titlelbl [label $fr.title -font TkSmallCaptionFont -text $data(title)]
                        set validateon focusout
                        if {$data(live)} {
                            set validateon all
                        }
                        set ent [entry $fr.data -width $data(width) \
                                      -textvariable $entvar -validate $validateon \
                                      -font TkSmallCaptionFont \
                                      -validatecommand [list confpane_validate_str $canv $data(name) $data(datum) $data(valsetcb) $data(validatecb) %P] \
                                      -invalidcommand [list confpane_invalidcmd $canv $data(name) $data(datum) $data(valgetcb) $data(default) $entvar]]
                        grid columnconfigure $fr 0 -minsize 75
                        grid $titlelbl -column 0 -row 0 -sticky e
                        grid $ent -column 1 -row 0 -sticky w

                        bind $ent <Key-Escape>   "focus $canv"
                        bind $ent <Key-Return>   "confpane_invoke_exec $canv $data(invoke) A"
                        bind $ent <Key-KP_Enter> "confpane_invoke_exec $canv $data(invoke) B"

                        set reqh [winfo reqheight $ent]
                    }
                    if {$name == $focfield} {
                        $fr.data selection range 0 end
                        focus $fr.data
                    }
                }
                INTEGER -
                INT {
                    set spinvar confpaneInfo(INT-$canv-$name)
                    if {$datval != ""} {
                        set $spinvar [expr {int($datval)}]
                    } else {
                        set $spinvar ""
                    }

                    if {$make_widgets} {
                        set titlelbl [label $fr.title -font TkSmallCaptionFont -text $data(title)]
                        set spin [spinbox $fr.data -increment $data(increment) \
                                      -width $data(width) -format "%.0f" -validate focusout \
                                      -font TkSmallCaptionFont \
                                      -textvariable $spinvar \
                                      -validatecommand [list confpane_validate_int $canv $data(name) $data(datum) $data(min) $data(max) $data(valsetcb) $data(validatecb) %P] \
                                      -invalidcommand [list confpane_invalidcmd $canv $data(name) $data(datum) $data(valgetcb) $data(default) $spinvar] \
                                      -command [list confpane_incdatum $canv $data(name) $data(datum) $data(min) $data(max) $data(valsetcb) 0 "%d" $fr.data %d]]

                        bind $spin <Key-Escape>   "focus $canv"
                        bind $spin <Key-Return>   "confpane_invoke_exec $canv $data(invoke) C"
                        bind $spin <Key-KP_Enter> "confpane_invoke_exec $canv $data(invoke) D"

                        grid columnconfigure $fr 0 -minsize 75
                        grid $titlelbl -column 0 -row 0 -sticky e
                        grid $spin -column 1 -row 0 -sticky w

                        set reqh [winfo reqheight $spin]
                    }
                    if {$name == $focfield} {
                        $fr.data selection range 0 end
                        focus $fr.data
                    }
                }
                DOUBLE -
                FLOAT {
                    set spinvar confpaneInfo(FLOAT-$canv-$name)
                    set fmt "%.4f"
                    if {$data(fmt) != ""} {
                        set fmt $data(fmt)
                    }
                    if {$datval != ""} {
                        if {$data(islength)} {
                            catch {
                                set datval [expr {$datval*$unitmult}]
                            }
                            append fmt " $unit"
                            incr data(width) 4
                        }
                        if {[catch {
                            set $spinvar [format $fmt $datval]
                        }]} {
                            set $spinvar $datval
                        }
                    } else {
                        set $spinvar $datval
                    }

                    if {$make_widgets} {
                        set titlelbl [label $fr.title -font TkSmallCaptionFont -text $data(title)]
                        set escfmt [string map {% %%} $fmt]
                        set spin [spinbox $fr.data -increment $data(increment) \
                                      -width $data(width) \
                                      -font TkSmallCaptionFont \
                                      -textvariable $spinvar -validate focusout \
                                      -validatecommand [list confpane_validate_float $canv $data(name) $data(datum) $data(min) $data(max) $data(valsetcb) $data(validatecb) $data(islength) %P] \
                                      -invalidcommand [list confpane_invalidcmd $canv $data(name) $data(datum) $data(valgetcb) $data(default) $spinvar] \
                                      -command [list confpane_incdatum $canv $data(name) $data(datum) $data(min) $data(max) $data(valsetcb) $data(islength) $escfmt $fr.data %d]]

                        bind $spin <Key-Escape>   "focus $canv"
                        bind $spin <Key-Return>   "confpane_invoke_exec $canv $data(invoke) E"
                        bind $spin <Key-KP_Enter> "confpane_invoke_exec $canv $data(invoke) F"

                        grid columnconfigure $fr 0 -minsize 75
                        grid $titlelbl -column 0 -row 0 -sticky e
                        grid $spin -column 1 -row 0 -sticky w

                        set reqh [winfo reqheight $spin]
                    }
                    if {$name == $focfield} {
                        $fr.data selection range 0 end
                        focus $fr.data
                    }
                }
                COLOR {
                    if {$make_widgets} {
                        set titlelbl [label $fr.title -font TkSmallCaptionFont -text $data(title)]
                        set colorbox [label $fr.colorbox -font TkSmallCaptionFont -text "" -width 12 -height 1 -relief solid -borderwidth 1 -highlightthickness 1 -takefocus 1]
                        set clrbtn [button $fr.clrbtn -font TkSmallCaptionFont -text "Clr" -height 1 -command [list confpane_clearcolor $canv $data(name) $data(datum) $data(valsetcb) $colorbox]]
                        bind $colorbox <ButtonPress-1> [list confpane_editcolor $canv $data(name) $data(datum) $data(valsetcb) $colorbox]
                        bind $colorbox <Key-Return> [list confpane_editcolor $canv $data(name) $data(datum) $data(valsetcb) $colorbox]

                        grid columnconfigure $fr 0 -minsize 75
                        grid $titlelbl -column 0 -row 0 -sticky e
                        grid $colorbox -column 1 -row 0 -sticky w -padx 3 -pady 4
                        grid $clrbtn   -column 2 -row 0 -sticky w
                        
                        set reqh [winfo reqheight $colorbox]
                    }
                    if {$name == $focfield} {
                        focus $fr.clrbtn
                    }
                    if {$datval == ""} {
                        $fr.colorbox configure -background #dfdfdf -foreground black -text "Multiple"
                    } elseif {$datval == "none"} {
                        $fr.colorbox configure -background #ffffff -foreground black -text "None"
                    } else {
                        $fr.colorbox configure -background $datval -foreground $datval -text ""
                    }
                }
                POINT {
                    set ptvar1 confpaneInfo(POINTX-$canv-$name)
                    set ptvar2 confpaneInfo(POINTY-$canv-$name)
                    set fmt "%.4f"
                    if {$datval != ""} {
                        append fmt " $unit"
                        catch {
                            set $ptvar1 [lindex $datval 0]
                            set datval1 [expr {[lindex $datval 0]*$unitmult}]
                            set $ptvar1 [format $fmt $datval1]
                        }
                        catch {
                            set $ptvar2 [lindex $datval 1]
                            set datval2 [expr {[lindex $datval 1]*$unitmult}]
                            set $ptvar2 [format $fmt $datval2]
                        }
                        set datval [list $datval1 $datval2]
                    } else {
                        set $ptvar1 $datval
                        set $ptvar2 $datval
                    }

                    if {$make_widgets} {
                        set titletxt $data(title)
                        append titletxt " X:"
                        set titlelbl [label $fr.title -font TkSmallCaptionFont -text $titletxt]

                        set xspin [entry $fr.datax -width 12 \
                                    -textvariable $ptvar1 \
                                    -font TkSmallCaptionFont \
                                    -validate focusout \
                                    -invalidcommand [list confpane_invalidcmd_point $canv $data(name) $data(datum) $data(valgetcb) $data(default) 0 $ptvar2] \
                                    -validatecommand [list confpane_validate_point $canv $data(name) $data(datum) $data(valsetcb) 0 %P]]

                        bind $xspin <Key-Escape>   "focus $canv"
                        bind $xspin <Key-Return>   "focus $canv"
                        bind $xspin <Key-KP_Enter> "focus $canv"

                        set ylbl [label $fr.ylbl -font TkSmallCaptionFont -text "Y:"]

                        set yspin [entry $fr.datay -width 12 \
                                    -textvariable $ptvar2 \
                                    -font TkSmallCaptionFont \
                                    -validate focusout \
                                    -invalidcommand [list confpane_invalidcmd_point $canv $data(name) $data(datum) $data(valgetcb) $data(default) 1 $ptvar2] \
                                    -validatecommand [list confpane_validate_point $canv $data(name) $data(datum) $data(valsetcb) 1 %P]]

                        bind $yspin <Key-Escape>   "focus $canv"
                        bind $yspin <Key-Return>   "focus $canv"
                        bind $yspin <Key-KP_Enter> "focus $canv"

                        grid columnconfigure $fr 0 -minsize 75
                        grid $titlelbl -column 0 -row 0 -sticky e
                        grid $xspin -column 1 -row 0 -sticky w
                        grid $ylbl -column 2 -row 0 -sticky w
                        grid $yspin -column 3 -row 0 -sticky w

                        set reqh [winfo reqheight $xspin]
                    }
                    if {$name == $focfield} {
                        $fr.datax selection range 0 end
                        focus $fr.datax
                    }
                }
                COMBOBOX -
                COMBO {
                    set cmbvar confpaneInfo(COMBO-$canv-$name)
                    set $cmbvar $datval

                    if {$make_widgets} {
                        set titlelbl [label $fr.title -font TkSmallCaptionFont -text $data(title)]
                        set cmb [ttk::combobox $fr.data -textvariable $cmbvar \
                                    -font TkSmallCaptionFont \
                                    -justify left -height 10 -values $data(values) \
                                    -validatecommand [list confpane_validate_str $canv $data(name) $data(datum) $data(valsetcb) $data(validatecb) %P] \
                                    -invalidcommand [list confpane_invalidcmd $canv $data(name) $data(datum) $data(valgetcb) $data(default) $cmbvar] \
                                    -validate focusout -width $data(width)]

                        grid columnconfigure $fr 0 -minsize 75
                        grid $titlelbl -column 0 -row 0 -sticky e
                        grid $cmb      -column 1 -row 0 -sticky w

                        bind $cmb <<ComboboxSelected>> "confpane_validate_combobox $cmb"
                        bind $cmb <Key-Escape>   "focus $canv"
                        bind $cmb <Key-Return>   "confpane_validate_combobox $cmb ; confpane_invoke_exec $canv $data(invoke) G"
                        bind $cmb <Key-KP_Enter> "confpane_validate_combobox $cmb ; confpane_invoke_exec $canv $data(invoke) H"

                        set reqh [winfo reqheight $cmb]
                    }
                    if {$name == $focfield} {
                        $fr.data selection range 0 end
                        focus $fr.data
                    }
                }
                OPTIONS {
                    set mbvar confpaneInfo(OPTMB-$canv-$name)
                    set lblvar confpaneInfo(OPTLBL-$canv-$name)
                    set $mbvar $datval

                    if {$datval == ""} {
                        set $lblvar "-Multiple-"
                    } else {
                        set $lblvar " "
                        foreach {labl val} $data(values) {
                            if {$datval == $val} {
                                set $lblvar $labl
                            }
                        }
                    }

                    if {$make_widgets} {
                        set font TkSmallCaptionFont
                        if {$data(font) != ""} {
                            set font $data(font)
                        }
                        set titlelbl [label $fr.title -font TkSmallCaptionFont -text $data(title)]
                        set mb [menubutton $fr.data -textvariable $lblvar -justify left \
                                    -width $data(width) -font $font -borderwidth 0 \
                                    -anchor w -menu $fr.data.menu -direction flush]
                        set mnu [menu $mb.menu -tearoff 0]

                        grid columnconfigure $fr 0 -minsize 75
                        grid $titlelbl -column 0 -row 0 -sticky e
                        grid $mb -column 1 -row 0 -sticky w

                        foreach {labl val} $data(values) {
                            $mnu add radiobutton -label $labl -value $val -variable $mbvar -command "set $lblvar [list $labl] ; confpane_setdatum $canv [list $data(name)] [list $data(datum)] [list $data(valsetcb)] [list $val]" -font TkSmallCaptionFont
                        }
                        set reqh [winfo reqheight $mb]
                    }
                    if {$name == $focfield} {
                        focus $fr.data
                    }
                }
                FONT {
                    set fmt "%.0f"

                    set famvar confpaneInfo(FONTMB-$canv-$name)
                    set sizvar confpaneInfo(SIZESP-$canv-$name)
                    set boldvar confpaneInfo(BOLDCB-$canv-$name)
                    set italvar confpaneInfo(ITALCB-$canv-$name)

                    if {$datval == ""} {
                        set ffam ""
                        set fsiz ""
                        set $famvar "-Multiple-"
                        set $sizvar ""
                        set $boldvar ""
                        set $italvar ""
                    } else {
                        set ffam [lindex $datval 0]
                        set fsiz [lindex $datval 1]
                        set $famvar $ffam
                        set $sizvar [format $fmt $fsiz]
                        set $boldvar [expr {"bold" in $datval}]
                        set $italvar [expr {"italic" in $datval}]
                    }

                    if {$make_widgets} {
                        set titlelbl [label $fr.title -font TkSmallCaptionFont -text $data(title)]
                        set fammb  [menubutton $fr.datafam -textvariable $famvar -font TkSmallCaptionFont -justify left -direction flush -menu $fr.datafam.mn -width 30]
                        set cmd [list confpane_setfontdatum $canv $data(name) $data(datum) $data(valsetcb) $fr]
                        set fammn  [menu $fr.datafam.mn -tearoff 0 -postcommand [list confpane_fontmenu_populate $fr.datafam.mn $cmd $famvar]]

                        set sizlbl [label $fr.sizlbl -font TkSmallCaptionFont -text "Size (pts)"]
                        set afr [frame $fr.afr]
                        set sizcmb [ttk::combobox $afr.datasiz -textvariable $sizvar \
                                    -justify right -values {6 7 8 9 10 11 12 14 16 18 20 24 28 36 48 72 108 144 216 288} \
                                    -font TkSmallCaptionFont \
                                    -validatecommand [list confpane_validate_fontsize $canv $data(name) $data(datum) $data(valsetcb) $fr %P] \
                                    -invalidcommand [list confpane_invalidcmd_fontsize $canv $data(name) $data(datum) $data(valgetcb) $data(default) $sizvar] \
                                    -validate focusout -height 10 -width 5]

                        set boldcb [checkbutton $afr.databold -tristatevalue "" \
                                    -text Bold -variable $boldvar \
                                    -font TkSmallCaptionFont \
                                    -command [list confpane_setfontdatum $canv $data(name) $data(datum) $data(valsetcb) $fr]]

                        set italcb [checkbutton $afr.dataital -tristatevalue "" \
                                    -text Italic -variable $italvar \
                                    -font TkSmallCaptionFont \
                                    -command [list confpane_setfontdatum $canv $data(name) $data(datum) $data(valsetcb) $fr]]

                        bind $fammb <Key-Escape>   "focus $canv"
                        bind $sizcmb <<ComboboxSelected>> "confpane_validate_combobox $sizcmb"
                        bind $sizcmb <Key-Escape>   "focus $canv"
                        bind $sizcmb <Key-Return>   "confpane_validate_combobox $sizcmb ; confpane_invoke_exec $canv $data(invoke) I"
                        bind $sizcmb <Key-KP_Enter> "confpane_validate_combobox $sizcmb ; confpane_invoke_exec $canv $data(invoke) J"
                        bind $italcb <Key-Escape>   "focus $canv"
                        bind $boldcb <Key-Escape>   "focus $canv"

                        pack $sizcmb -side left
                        pack $boldcb -side left
                        pack $italcb -side left

                        grid columnconfigure $fr 0 -minsize 75
                        grid $titlelbl -column 0 -row 0 -sticky e
                        grid $fammb    -column 1 -row 0 -sticky w
                        grid $sizlbl   -column 0 -row 1 -sticky e
                        grid $afr      -column 1 -row 1 -sticky w

                        set  reqh [winfo reqheight $fammb]
                        incr reqh [winfo reqheight $sizcmb]
                        set rowscnt 2
                    }
                    if {$name == $focfield} {
                        focus $fr.datafam
                    }
                }
                default {
                    error "Unknown infowin confpane option type."
                }
            }
            if {$make_widgets} {
                if {$colh + $reqh > [winfo reqheight $cnf]} {
                    if {$colh + $reqh > [winfo height $cnf]} {
                        incr colnum
                        set rownum 0
                        set colh 0
                    }
                }
                if {$rownum == 0} {
                    if {$colnum > 0 || $panefilt == "INFO"} {
                        set divfr [frame $cnf.div$cnt -width 2 -relief sunken -borderwidth 1]
                        grid $divfr -column $colnum -row 0 -rowspan 3 -sticky ns -padx 10 -pady {5 0}
                        incr colnum
                    }
                }
                grid $fr -column $colnum -row $rownum -rowspan $rowscnt -sticky nw -padx {0 10} -pady {0 0}
                incr rownum $rowscnt
                incr colh $reqh
            }
            incr cnt
        }
    }

    set confpaneInfo(NOVALIDATE) 0
}



# vim: set ts=4 sw=4 nowrap expandtab: settings

