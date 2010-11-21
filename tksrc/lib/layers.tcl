proc layer_init {canv} {
    global layersInfo
    set layersInfo($canv-LAYERNUM) 0
    set layersInfo($canv-LAYERS) {}
    set layersInfo($canv-LAYERCURR) -1
    layer_set_current $canv [layer_create $canv]
}


proc layer_create {canv {name ""}} {
    set res [layer_create_noundo $canv $name]
    cutpaste_remember_layer_creation $canv $res
    return $res
}


proc layer_create_noundo {canv {name ""} {layerid -1}} {
    global layersInfo
    if {$layerid == -1} {
        set layerid [incr layersInfo($canv-LAYERNUM)]
    }
    if {$name == ""} {
        set name "Layer $layerid"
    }
    set layersInfo($canv-LAYERCHILDREN-$layerid) {}
    set layersInfo($canv-LAYERNAME-$layerid) $name
    set layersInfo($canv-LAYERVISIBLE-$layerid) 1
    set layersInfo($canv-LAYERLOCK-$layerid) 0
    set layersInfo($canv-LAYERCOLOR-$layerid) black
    set layersInfo($canv-LAYERCUTBIT-$layerid) 0
    set layersInfo($canv-LAYERCUTDEPTH-$layerid) 0.0
    lappend layersInfo($canv-LAYERS) $layerid
    return $layerid
}


proc layer_delete {canv layerid} {
    return [layer_delete_noundo $canv $layerid 1]
}


proc layer_delete_noundo {canv layerid {enableundo 0}} {
    global layersInfo
    set layers $layersInfo($canv-LAYERS)

    foreach objid [layer_objects $canv $layerid] {
        cadobjects_object_delete $canv $objid
    }

    if {$enableundo} {
        cutpaste_remember_layer_deletion $canv $layerid
    }

    set pos [lsearch -exact $layers $layerid]
    if {[layer_get_current $canv] == $layerid} {
        set nlpos 0
        if {$pos == 0} {
            set nlpos 1
        }
        layer_set_current $canv [lindex $layers $nlpos]
    }

    unset layersInfo($canv-LAYERCHILDREN-$layerid)
    unset layersInfo($canv-LAYERNAME-$layerid)
    unset layersInfo($canv-LAYERVISIBLE-$layerid)
    unset layersInfo($canv-LAYERLOCK-$layerid)
    unset layersInfo($canv-LAYERCOLOR-$layerid)
    unset layersInfo($canv-LAYERCUTBIT-$layerid)
    unset layersInfo($canv-LAYERCUTDEPTH-$layerid)
    if {$pos >= 0} {
        set layers [lreplace $layers $pos $pos]
    }
    set layersInfo($canv-LAYERS) $layers
    if {[llength $layers] == 0} {
        set layersInfo($canv-LAYERNUM) 0
        set layersInfo($canv-LAYERCURR) -1
    }
}


proc layer_name_id {canv name} {
    foreach lid [layer_ids $canv] {
        set lname [layer_name $canv $lid]
        if {$name eq $lname} {
            return $lid
        }
    }
    return ""
}


proc layer_exists {canv layerid} {
    global layersInfo
    return [info exists layersInfo($canv-LAYERNAME-$layerid)]
}


proc layer_serialize {canv layerid} {
    set layers [layer_ids $canv]
    set out {}
    lappend out "layerid"  $layerid
    lappend out "pos"      [layer_pos $canv $layerid]
    lappend out "name"     [layer_name $canv $layerid]
    lappend out "visible"  [layer_visible $canv $layerid]
    lappend out "locked"   [layer_locked $canv $layerid]
    lappend out "color"    [layer_color $canv $layerid]
    lappend out "cutbit"   [layer_cutbit $canv $layerid]
    lappend out "cutdepth" [layer_cutdepth $canv $layerid]
    return $out
}


proc layer_deserialize {canv layerid forcenew info} {
    global layersInfo

    array set data $info
    if {$forcenew} {
        set layerid -1
    }
    foreach tag {layerid name visible locked color cutbit cutdepth pos} {
        if {![info exists data($tag)]} {
            error "Internal error: serialization contains no $tag."
        }
    }
    if {$layerid == -1} {
        set layerid [layer_create_noundo $canv $data(name)]
    } elseif {![layer_exists $canv $layerid]} {
        set layerid [layer_create_noundo $canv $data(name) $layerid]
    } else {
        set layersInfo($canv-LAYERNAME-$layerid) $data(name)
    }
    set layersInfo($canv-LAYERVISIBLE-$layerid) $data(visible)
    set layersInfo($canv-LAYERLOCK-$layerid) $data(locked)
    set layersInfo($canv-LAYERCOLOR-$layerid) $data(color)
    set layersInfo($canv-LAYERCUTBIT-$layerid) $data(cutbit)
    set layersInfo($canv-LAYERCUTDEPTH-$layerid) $data(cutdepth)
    layer_reorder $canv $layerid $data(pos)
    mainwin_redraw [winfo toplevel $canv]
    return $layerid
}


proc layer_ids {canv} {
    global layersInfo
    if {![info exists layersInfo($canv-LAYERS)]} {
        return {}
    }
    return $layersInfo($canv-LAYERS)
}


proc layer_get_current {canv} {
    global layersInfo
    if {[info exists layersInfo($canv-LAYERCURR)]} {
        set layerid $layersInfo($canv-LAYERCURR)
        if {[llength $layersInfo($canv-LAYERS)] == 0} {
            return -1
        }
    } else {
        return -1
    }
    if {$layerid == -1} {
        set layerid [layer_create $canv]
        set layersInfo($canv-LAYERCURR) $layerid
    }
    return $layerid
}


proc layer_pos {canv layerid} {
    set layers [layer_ids $canv]
    set pos [lsearch -exact $layers $layerid]
    return $pos
}


proc layer_reorder {canv layerid newpos} {
    global layersInfo
    set layers $layersInfo($canv-LAYERS)
    set oldpos [lsearch -exact $layers $layerid]
    set layers [lreplace $layers $oldpos $oldpos]
    set layers [linsert $layers $newpos $layerid]
    set layersInfo($canv-LAYERS) $layers
}


proc layer_set_current {canv layerid} {
    global layersInfo
    set layersInfo($canv-LAYERCURR) $layerid
}


proc layer_name {canv layerid} {
    global layersInfo
    return $layersInfo($canv-LAYERNAME-$layerid)
}


proc layer_set_name {canv layerid val} {
    global layersInfo
    cutpaste_remember_layer_change $canv $layerid
    set layersInfo($canv-LAYERNAME-$layerid) $val
}


proc layer_visible {canv layerid} {
    global layersInfo
    return $layersInfo($canv-LAYERVISIBLE-$layerid)
}


proc layer_set_visible {canv layerid val} {
    global layersInfo
    set layersInfo($canv-LAYERVISIBLE-$layerid) $val
}


proc layer_locked {canv layerid} {
    global layersInfo
    return $layersInfo($canv-LAYERLOCK-$layerid)
}


proc layer_set_locked {canv layerid val} {
    global layersInfo
    set layersInfo($canv-LAYERLOCK-$layerid) $val
}


proc layer_color {canv layerid} {
    global layersInfo
    return $layersInfo($canv-LAYERCOLOR-$layerid)
}


proc layer_set_color {canv layerid val} {
    global layersInfo
    cutpaste_remember_layer_change $canv $layerid
    set layersInfo($canv-LAYERCOLOR-$layerid) $val
}


proc layer_cutbit {canv layerid} {
    global layersInfo
    return $layersInfo($canv-LAYERCUTBIT-$layerid)
}


proc layer_set_cutbit {canv layerid val} {
    global layersInfo
    cutpaste_remember_layer_change $canv $layerid
    set layersInfo($canv-LAYERCUTBIT-$layerid) $val
}


proc layer_cutdepth {canv layerid} {
    global layersInfo
    return $layersInfo($canv-LAYERCUTDEPTH-$layerid)
}


proc layer_set_cutdepth {canv layerid val} {
    global layersInfo
    cutpaste_remember_layer_change $canv $layerid
    set layersInfo($canv-LAYERCUTDEPTH-$layerid) $val
}


proc layer_objects {canv layerid} {
    global layersInfo
    return $layersInfo($canv-LAYERCHILDREN-$layerid)
}


proc layer_object_add {canv layerid objid} {
    global layersInfo
    lappend layersInfo($canv-LAYERCHILDREN-$layerid) $objid
    return
}


proc layer_object_delete {canv layerid objid} {
    global layersInfo
    set objs $layersInfo($canv-LAYERCHILDREN-$layerid)
    set pos [lsearch -exact $objs $objid]
    if {$pos >= 0} {
        set objs [lreplace $objs $pos $pos]
    }
    set layersInfo($canv-LAYERCHILDREN-$layerid) $objs
}



proc layer_object_arrange {canv layerid objid relpos} {
    set objs [layer_objects $canv $layerid]
    set origpos [lsearch -exact $objs $objid]
    set objs [lreplace $objs $origpos $origpos]
    set nupos $origpos
    if {$relpos == "bottom"} {
        set nupos end
    } elseif {$relpos == "top"} {
        set nupos 0
    } else {
        incr nupos $relpos
    }
    set objs [linsert $objs $nupos $objid]
    set layersInfo($canv-LAYERCHILDREN-$layerid) $objs
}


# vim: set ts=4 sw=4 nowrap expandtab: settings

