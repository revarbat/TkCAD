proc cutpaste_init {} {
    global cutpasteInfo
    set cutpasteInfo(COPY) {}
}


proc cutpaste_canvas_init {canv} {
    global cutpasteInfo
    set cutpasteInfo(UNDO-$canv) {}
    set cutpasteInfo(REDO-$canv) {}
    set cutpasteInfo(CURR-$canv) {}
    set cutpasteInfo(SUSP-$canv) 0
}


proc cutpaste_cut {canv objids} {
    set objids [cadobjects_topmost_objects $canv $objids]
    cutpaste_copy $canv $objids
    foreach objid $objids {
        cadobjects_object_delete $canv $objid
    }
}


proc cutpaste_copy {canv objids} {
    global cutpasteInfo
    set buf {}
    set objids [cadobjects_topmost_objects $canv $objids]
    foreach objid $objids {
        lappend buf [cadobjects_object_serialize $canv $objid]
    }
    set cutpasteInfo(COPY) $buf
    return
}


proc cutpaste_paste {canv} {
    global cutpasteInfo
    cadselect_clear $canv
    foreach info $cutpasteInfo(COPY) {
        set newobj [cadobjects_object_deserialize $canv -1 1 $info]
        cadselect_add $canv $newobj
    }
    return
}


proc cutpaste_change_init {} {
    global cutpasteChangeInfo
    set cutpasteChangeInfo(MAXID) 0
}


proc cutpaste_change_create {data} {
    upvar #0 cutpasteChangeInfo change
    set chid [incr change(MAXID)]
    set change($chid) $data
    return $chid
}


proc cutpaste_change_delete {chid} {
    upvar #0 cutpasteChangeInfo change
    catch {unset change($chid)}
}



proc cutpaste_suspend_recording {canv} {
    global cutpasteInfo
    incr cutpasteInfo(SUSP-$canv)
}


proc cutpaste_resume_recording {canv} {
    global cutpasteInfo
    incr cutpasteInfo(SUSP-$canv) -1
}


proc cutpaste_recording_is_suspended {canv} {
    global cutpasteInfo
    return [expr {$cutpasteInfo(SUSP-$canv) > 0}]
}


proc cutpaste_remember_creation {canv objid} {
    global cutpasteInfo
    if {[cutpaste_recording_is_suspended $canv]} {
        return
    }
    cadobjects_mark_modified $canv
    lappend cutpasteInfo(CURR-$canv) "OBJCREATED" [cutpaste_change_create [cadobjects_object_serialize $canv $objid]]
}


proc cutpaste_remember_change {canv objid} {
    global cutpasteInfo
    if {[cutpaste_recording_is_suspended $canv]} {
        return
    }
    cadobjects_mark_modified $canv
    upvar #0 cutpasteInfo(CURR-$canv) currbuf
    global cutpasteChangeInfo
    set firstmatch 1
    set pos 0
    foreach {chtyp chid} $currbuf {
        if {$chtyp == "OBJCHANGED"} {
            set info $cutpasteChangeInfo($chid)
            catch {unset data}
            array set data $info
            set chobjid $data(objid)
            if {$objid == $chobjid} {
                if {!$firstmatch} {
                    # Remove redundant 2nd OBJCHANGED entry for this object.
                    set pos1 [expr {$pos*2}]
                    set pos2 [expr {$pos1+1}]
                    set currbuf [lreplace $currbuf $pos1 $pos2]
                    cutpaste_change_delete $chid
                    break
                }
                set firstmatch 0
            }
        }
        incr pos
    }
    lappend currbuf "OBJCHANGED" [cutpaste_change_create [cadobjects_object_serialize $canv $objid]]
}


proc cutpaste_remember_deletion {canv objid} {
    global cutpasteInfo
    if {[cutpaste_recording_is_suspended $canv]} {
        return
    }
    cadobjects_mark_modified $canv
    lappend cutpasteInfo(CURR-$canv) "OBJDESTROYED" [cutpaste_change_create [cadobjects_object_serialize $canv $objid]]
}




proc cutpaste_remember_datum_change {canv objid datum} {
    global cutpasteInfo
    if {[cutpaste_recording_is_suspended $canv]} {
        return
    }
    cadobjects_mark_modified $canv
    lappend cutpasteInfo(CURR-$canv) "DATUMCHANGED" [cutpaste_change_create [list objid $objid datum $datum value [cadobjects_object_getdatum $canv $objid $datum]]]
}



proc cutpaste_remember_layer_creation {canv layerid} {
    global cutpasteInfo
    if {[cutpaste_recording_is_suspended $canv]} {
        return
    }
    cadobjects_mark_modified $canv
    lappend cutpasteInfo(CURR-$canv) "LAYERCREATED" [cutpaste_change_create [layer_serialize $canv $layerid]]
}


proc cutpaste_remember_layer_change {canv layerid} {
    global cutpasteInfo
    if {[cutpaste_recording_is_suspended $canv]} {
        return
    }
    cadobjects_mark_modified $canv
    lappend cutpasteInfo(CURR-$canv) "LAYERCHANGED" [cutpaste_change_create [layer_serialize $canv $layerid]]
}


proc cutpaste_remember_layer_deletion {canv layerid} {
    global cutpasteInfo
    if {[cutpaste_recording_is_suspended $canv]} {
        return
    }
    cadobjects_mark_modified $canv
    lappend cutpasteInfo(CURR-$canv) "LAYERDESTROYED" [cutpaste_change_create [layer_serialize $canv $layerid]]
}




proc cutpaste_set_checkpoint {canv} {
    global cutpasteInfo
    if {$cutpasteInfo(CURR-$canv) != {}} {
        lappend cutpasteInfo(UNDO-$canv) $cutpasteInfo(CURR-$canv)

        # Limit undo buffer size to 100 steps.
        while {[llength $cutpasteInfo(UNDO-$canv)] > 100} {
            set tmpund [lindex $cutpasteInfo(UNDO-$canv) 0]
            foreach {chtyp chid} $tmpund {
                cutpaste_change_delete $chid
            }
            set cutpasteInfo(UNDO-$canv) [lrange $cutpasteInfo(UNDO-$canv) 1 end]
        }

        set cutpasteInfo(CURR-$canv) {}

        # Purge redo buffer.
        foreach tmpred $cutpasteInfo(REDO-$canv) {
            foreach {chtyp chid} $tmpred {
                cutpaste_change_delete $chid
            }
        }
        set cutpasteInfo(REDO-$canv) {}
    }
}




proc cutpaste_undo {canv} {
    global cutpasteInfo
    set undobuf $cutpasteInfo(UNDO-$canv)
    set redobuf $cutpasteInfo(REDO-$canv)
    set currbuf $cutpasteInfo(CURR-$canv)

    if {$currbuf == {}} {
        set cutpasteInfo(CURR-$canv) [lindex $undobuf end]
        set cutpasteInfo(UNDO-$canv) [lrange $undobuf 0 end-1]
        set undobuf $cutpasteInfo(UNDO-$canv)
        set currbuf $cutpasteInfo(CURR-$canv)
    }

    if {$currbuf == {}} {
        bell
        return
    }

    cutpaste_suspend_recording $canv

    global cutpasteChangeInfo
    set redoent {}
    set delchanges {}
    while {[llength $currbuf] >= 2} {
        foreach {changetype chid} [lrange $currbuf end-1 end] break
        set info $cutpasteChangeInfo($chid)
        catch {unset data}
        array set data $info
        switch -exact -- $changetype {
            "OBJCREATED" {
                set objid $data(objid)
                lappend redoent $changetype [cutpaste_change_create [cadobjects_object_serialize $canv $objid]]
                cadobjects_object_delete_noundo $canv $objid
            }
            "OBJCHANGED" {
                set objid $data(objid)
                lappend redoent $changetype [cutpaste_change_create [cadobjects_object_serialize $canv $objid]]
                cadobjects_object_deserialize $canv $objid 0 $info
            }
            "OBJDESTROYED" {
                set objid $data(objid)
                set objid [cadobjects_object_deserialize $canv $objid 0 $info]
                set data(objid) $objid
                lappend redoent $changetype [cutpaste_change_create [array get data]]
            }
            "DATUMCHANGED" {
                set objid $data(objid)
                set datum $data(datum)
                set value $data(value)
                lappend redoent $changetype [cutpaste_change_create [list objid $objid datum $datum value [cadobjects_object_getdatum $canv $objid $datum]]]
                cadobjects_object_setdatum_noundo $canv $objid $datum $value
            }
            "LAYERCREATED" {
                set layerid $data(layerid)
                lappend redoent $changetype [cutpaste_change_create [layer_serialize $canv $layerid]]
                layer_delete_noundo $canv $layerid
                mainwin_redraw [winfo toplevel $canv]
            }
            "LAYERCHANGED" {
                set layerid $data(layerid)
                lappend redoent $changetype [cutpaste_change_create [layer_serialize $canv $layerid]]
                layer_deserialize $canv $layerid 0 $info
            }
            "LAYERDESTROYED" {
                set layerid $data(layerid)
                set layerid [layer_deserialize $canv $layerid 0 $info]
                set data(layerid) $layerid
                lappend redoent $changetype [cutpaste_change_create [array get data]]
            }
        }
        set currbuf [lrange $currbuf 0 end-2]
        lappend delchanges $chid
    }
    foreach chid $delchanges {
        cutpaste_change_delete $chid
    }
    set rentcnt [llength $redoent]
    incr rentcnt -2
    set redoentout {}
    for {set i $rentcnt} {$i >= 0} {incr i -2} {
        foreach {changetype chid} [lrange $redoent $i [expr {$i+1}]] break
        lappend redoentout $changetype $chid
    }

    lappend cutpasteInfo(REDO-$canv) $redoentout
    set cutpasteInfo(CURR-$canv) [lindex $undobuf end]
    set cutpasteInfo(UNDO-$canv) [lrange $undobuf 0 end-1]

    cutpaste_resume_recording $canv
}


proc cutpaste_redo {canv} {
    global cutpasteInfo

    set currbuf $cutpasteInfo(CURR-$canv)
    if {$currbuf != {}} {
        lappend cutpasteInfo(UNDO-$canv) $currbuf
    }

    set redobuf $cutpasteInfo(REDO-$canv)
    set cutpasteInfo(CURR-$canv) [lindex $redobuf end]
    set cutpasteInfo(REDO-$canv) [lrange $redobuf 0 end-1]

    set undobuf $cutpasteInfo(UNDO-$canv)
    set currbuf $cutpasteInfo(CURR-$canv)

    if {$currbuf == {}} {
        bell
        return
    }

    cutpaste_suspend_recording $canv

    global cutpasteChangeInfo
    set undoent {}
    set delchanges {}
    foreach {changetype chid} $currbuf {
        set info $cutpasteChangeInfo($chid)
        catch {unset data}
        array set data $info
        switch -exact -- $changetype {
            "OBJCREATED" {
                set objid $data(objid)
                cadobjects_object_deserialize $canv $objid 0 $info
                lappend undoent $changetype [cutpaste_change_create $info]
            }
            "OBJCHANGED" {
                set objid $data(objid)
                lappend undoent $changetype [cutpaste_change_create [cadobjects_object_serialize $canv $objid]]
                cadobjects_object_deserialize $canv $objid 0 $info
            }
            "OBJDESTROYED" {
                set objid $data(objid)
                lappend undoent $changetype [cutpaste_change_create [cadobjects_object_serialize $canv $objid]]
                cadobjects_object_delete_noundo $canv $objid
            }
            "DATUMCHANGED" {
                set objid $data(objid)
                set datum $data(datum)
                set value $data(value)
                lappend undoent $changetype [cutpaste_change_create [list objid $objid datum $datum value [cadobjects_object_getdatum $canv $objid $datum]]]
                cadobjects_object_setdatum_noundo $canv $objid $datum $value
            }
            "LAYERCREATED" {
                set layerid $data(layerid)
                layer_deserialize $canv $layerid 0 $info
                lappend undoent $changetype [cutpaste_change_create $info]
            }
            "LAYERCHANGED" {
                set layerid $data(layerid)
                lappend undoent $changetype [cutpaste_change_create [layer_serialize $canv $layerid]]
                layer_deserialize $canv $layerid 0 $info
            }
            "LAYERDESTROYED" {
                set layerid $data(layerid)
                lappend undoent $changetype [cutpaste_change_create [layer_serialize $canv $layerid]]
                layer_delete_noundo $canv $layerid
                mainwin_redraw [winfo toplevel $canv]
            }
        }
        lappend delchanges $chid
    }
    foreach chid $delchanges {
        cutpaste_change_delete $chid
    }
    set cutpasteInfo(CURR-$canv) $undoent

    cutpaste_resume_recording $canv
}



cutpaste_init


# vim: set ts=4 sw=4 nowrap expandtab: settings

