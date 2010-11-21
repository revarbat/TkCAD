proc layerwin_init {} {
    global layerwinInfo
}


proc layerwin_create {base win} {
    global layerwinInfo
    global tkcad_images_dir
    set layerwinInfo(WIN-$base) $win

    toplevel $base
    set lcanv [canvas $base.layers -width 200 -borderwidth 1 -relief solid -highlightthickness 0 -yscrollcommand "$base.vscroll set"]
    frame $lcanv.lfr -width 200 -borderwidth 0 -background white -highlightthickness 0
    $lcanv create window 0 0 -anchor nw -window $lcanv.lfr
    scrollbar $base.vscroll -orient vertical -command "$lcanv yview"
    set btns [frame $base.buttons -relief flat]

    set imgdir $tkcad_images_dir
    set newimg [image create photo -file [file join $imgdir "layer-new.gif"]]
    set delimg [image create photo -file [file join $imgdir "layer-delete.gif"]]
    set visimg [image create photo -file [file join $imgdir "layer-visible.gif"]]
    set camimg [image create photo -file [file join $imgdir "layer-cam.gif"]]
    set nocamimg [image create photo -file [file join $imgdir "layer-nocam.gif"]]
    set lockimg [image create photo -file [file join $imgdir "layer-locked.gif"]]
    set unlockimg [image create photo -file [file join $imgdir "layer-unlocked.gif"]]
    set invisimg [image create photo -width 16 -height 16]

    set layerwinInfo(VISICON-$base) $visimg
    set layerwinInfo(CAMICON-$base) $camimg
    set layerwinInfo(NOCAMICON-$base) $nocamimg
    set layerwinInfo(INVISICON-$base) $invisimg
    set layerwinInfo(LOCKICON-$base) $lockimg
    set layerwinInfo(UNLOCKICON-$base) $unlockimg

    button $btns.new -image $newimg -borderwidth 2 -command "layerwin_new $base"  -padx 0 -pady 0
    button $btns.del -image $delimg -borderwidth 2 -command "layerwin_delete $base" -padx 0 -pady 0
    pack $btns.new -side left -expand 0 -fill none -padx 5 -pady 5
    pack $btns.del -side left -expand 0 -fill none -padx 5 -pady 5

    pack $base.buttons -side bottom -expand 0 -fill x
    pack $base.vscroll -side right -expand 0 -fill y
    pack $base.layers -side left -expand 1 -fill both

    bind $lcanv <MouseWheel> "layerwin_scroll $base %D"
    bind $lcanv.lfr <MouseWheel> "layerwin_scroll $base %D"

    layerwin_refresh $base
    return $base
}



proc layerwin_scroll {base delta} {
    if {$delta != 0} {
        set delta [expr {$delta/-abs($delta)}]
    }
    if {$delta >= 0 || [lindex [$base.layers yview] 0] > 0.0} {
        $base.layers yview scroll $delta units
    }
}



proc layerwin_refresh {base {editlayer ""}} {
    global layerwinInfo

    set win $layerwinInfo(WIN-$base)
    set canv [mainwin_get_canvas $win]
    set visimg $layerwinInfo(VISICON-$base)
    set camimg $layerwinInfo(CAMICON-$base)
    set nocamimg $layerwinInfo(NOCAMICON-$base)
    set invisimg $layerwinInfo(INVISICON-$base)
    set lockimg $layerwinInfo(LOCKICON-$base)
    set unlockimg $layerwinInfo(UNLOCKICON-$base)

    set lcanv $base.layers
    set lfr $lcanv.lfr
    set font {Helvetica 12}

    set currlayerid [layer_get_current $canv]

    foreach child [winfo children $lfr] {
        destroy $child
    }

    grid columnconfigure $lfr  0 -minsize 5
    grid columnconfigure $lfr  2 -minsize 0
    grid columnconfigure $lfr  4 -minsize 0
    grid columnconfigure $lfr  5 -minsize 100 -weight 1
    grid columnconfigure $lfr  6 -minsize 2
    grid columnconfigure $lfr  8 -minsize 5
    grid columnconfigure $lfr 10 -minsize 5
    grid columnconfigure $lfr 12 -minsize 5
    grid rowconfigure $lfr 0 -minsize 5

    set row 1
    foreach layerid [layer_ids $canv] {
        set limg $unlockimg
        set vimg $invisimg
        set cimg $nocamimg
        set namebg "white"
        set namefg "black"
        if {[layer_locked $canv $layerid]} {
            set limg $lockimg
        }
        if {[layer_visible $canv $layerid]} {
            set vimg $visimg
        }
        if {[layer_cutbit $canv $layerid] > 0} {
            set cimg $camimg
        }
        if {$layerid == $currlayerid} {
            set namebg systemHighlight
            set namefg systemHighlightText
        }
        set layername [layer_name $canv $layerid]
        set layerobjs [layer_objects $canv $layerid]
        set layerobjs [cadobjects_grouped_objects $canv $layerobjs]
        set layercount [llength $layerobjs]
        set lcolor [layer_color $canv $layerid]
        set lcutbit [layer_cutbit $canv $layerid]
        set lcutdepth [layer_cutdepth $canv $layerid]

        set lock    [button $lfr.lock$layerid    -image $limg      -background white   -highlightbackground white -borderwidth 0 -highlightthickness 1 -padx 0 -pady 0 -command [list layerwin_toggle_lock    $base $layerid]]
        set visible [button $lfr.visible$layerid -image $vimg      -background white   -highlightbackground white -borderwidth 0 -highlightthickness 1 -padx 0 -pady 0 -command [list layerwin_toggle_visible $base $layerid]]
        set name    [label  $lfr.name$layerid    -text $layername  -background $namebg -highlightbackground white -borderwidth 0 -highlightthickness 1 -relief flat  -font $font -justify left -anchor w -foreground $namefg]
        set colrbtn [label  $lfr.color$layerid   -text ""          -background $lcolor -highlightbackground white -borderwidth 1 -highlightthickness 0 -relief solid -width 2 -padx 0 -pady 0]
        set cambtn  [button $lfr.cam$layerid     -image $cimg      -background white   -highlightbackground white -borderwidth 0 -highlightthickness 1 -padx 0 -pady 0 -command [list layerwin_edit_cam $base $layerid]]
        set count   [label  $lfr.count$layerid   -text $layercount -background white   -highlightbackground white -borderwidth 0 -highlightthickness 1 -relief flat  -font $font -justify right -anchor e]

        bind $colrbtn <ButtonPress-1> [list layerwin_color_config $lfr.color$layerid $canv $layerid]

        grid $lock    -row $row -column  1 -sticky w
        grid $visible -row $row -column  3 -sticky w
        grid $name    -row $row -column  5 -sticky ew
        grid $colrbtn -row $row -column  7 -sticky e
        grid $cambtn  -row $row -column  9 -sticky e
        grid $count   -row $row -column 11 -sticky e

        bind $name <ButtonPress-1> "layerwin_select_layer $base $layerid %X %Y ; break"
        bind $name <Double-1> "layerwin_rename_layer_init $base %W $layerid ; break"
        bind $name <Motion> "layerwin_drag_motion $base %W $layerid %X %Y; break"
        bind $name <ButtonRelease-1> "layerwin_drag_release $base %W $layerid %X %Y ; break"

        bind $lock    <MouseWheel> "$base.layers yview scroll \[expr {%D/-abs(%D)}\] units"
        bind $visible <MouseWheel> "$base.layers yview scroll \[expr {%D/-abs(%D)}\] units"
        bind $name    <MouseWheel> "$base.layers yview scroll \[expr {%D/-abs(%D)}\] units"
        bind $colrbtn <MouseWheel> "$base.layers yview scroll \[expr {%D/-abs(%D)}\] units"
        bind $cambtn  <MouseWheel> "$base.layers yview scroll \[expr {%D/-abs(%D)}\] units"
        bind $count   <MouseWheel> "$base.layers yview scroll \[expr {%D/-abs(%D)}\] units"

        if {$editlayer == $layerid} {
            after 10 layerwin_rename_layer_init $base $name $layerid
        }
        incr row
    }
    incr row
    grid rowconfigure $lfr $row -minsize 3

    after 10 layerwin_update_scrollregion $base
}


proc layerwin_update_scrollregion {base} {
    set lcanv $base.layers
    $lcanv configure -scrollregion [$lcanv bbox all]
}


proc layerwin_color_config {colrbtn canv layerid} {
    set parent [winfo toplevel $canv]
    set title "Choose a new color"
    set oldcolor [layer_color $canv $layerid]
    set color [tk_chooseColor -initialcolor $oldcolor -parent $parent -title $title]
    if {$color == ""} {
        return
    }

    cutpaste_set_checkpoint $canv

    layer_set_color $canv $layerid $color
    $colrbtn configure -background $color
    cadobjects_redraw $canv
}


proc layerwin_toggle_lock {base layerid} {
    global layerwinInfo

    set win $layerwinInfo(WIN-$base)
    set canv [mainwin_get_canvas $win]
    set lockimg $layerwinInfo(LOCKICON-$base)
    set unlockimg $layerwinInfo(UNLOCKICON-$base)

    cutpaste_set_checkpoint $canv

    set lcanv $base.layers
    set lfr $lcanv.lfr

    if {[layer_locked $canv $layerid]} {
        $lfr.lock$layerid configure -image $unlockimg
        layer_set_locked $canv $layerid 0
    } else {
        $lfr.lock$layerid configure -image $lockimg
        layer_set_locked $canv $layerid 1
    }

    mainwin_redraw $win
}


proc layerwin_edit_cam {base layerid} {
    global layerwinInfo

    set win $layerwinInfo(WIN-$base)
    set canv [mainwin_get_canvas $win]

    set lcutbit [layer_cutbit $canv $layerid]
    set lcutdepth [layer_cutdepth $canv $layerid]

    set bits {"No Cut"}
    set origbitname [lindex $bits 0]
    foreach bitnum [lsort -integer [mlcnc_get_tools]] {
        if {$bitnum != 99} {
            set bitname [mlcnc_tool_get_name $bitnum]
            if {$lcutbit == $bitnum} {
                set origbitname $bitname
            }
            lappend bits $bitname
        }
    }

    set camwin [toplevel $base.camwin]
    wm title $camwin "CAM Settings"
    label $camwin.lbit -text "Cut Bit"
    ::ttk::combobox $camwin.bit -values $bits -state readonly
    $camwin.bit set $origbitname
    label $camwin.ldepth -text "Cut Depth"
    spinbox $camwin.depth -width 8 -format "%.4f" -from -1e6 -to 1e6 -increment 0.05
    $camwin.depth set [format "%.4f" $lcutdepth]
    button $camwin.ok -text Set -width 6 -command "layerwin_edit_cam_commit $base $camwin $layerid" -default active
    button $camwin.cancel -text Cancel -width 6 -command "destroy $camwin"
    bind $camwin <Key-Return> "$camwin.ok invoke"
    bind $camwin <Key-Escape> "$camwin.cancel invoke"
    focus $camwin.bit

    grid columnconfigure $camwin 0 -minsize 10
    grid columnconfigure $camwin 2 -minsize 10
    grid columnconfigure $camwin 4 -minsize 10
    grid rowconfigure $camwin 0 -minsize 10
    grid rowconfigure $camwin 2 -minsize 5
    grid rowconfigure $camwin 4 -minsize 5
    grid rowconfigure $camwin 6 -minsize 10
    grid x $camwin.lbit   x $camwin.bit    x -row 1
    grid x $camwin.ldepth x $camwin.depth  x -row 3
    grid x $camwin.ok     x $camwin.cancel x -row 5

    grid $camwin.lbit $camwin.ldepth -sticky e
    grid $camwin.bit $camwin.depth -sticky ew
    grid $camwin.ok $camwin.cancel -sticky e
}


proc layerwin_edit_cam_commit {base camwin layerid} {
    global layerwinInfo

    set win $layerwinInfo(WIN-$base)
    set canv [mainwin_get_canvas $win]
    set camimg $layerwinInfo(CAMICON-$base)
    set nocamimg $layerwinInfo(NOCAMICON-$base)
    set invisimg $layerwinInfo(INVISICON-$base)
    set cutbit [$camwin.bit get]
    set cutdepth [$camwin.depth get]

    destroy $camwin

    if {$cutbit == "No Cut"} {
        set cutbit 0
    } else {
        set cutbit [lindex [split $cutbit ":"] 0]
    }

    set cutdepth [util_number_value $cutdepth "in"]
    if {$cutdepth == ""} {
        return
    }

    cutpaste_set_checkpoint $canv

    set lcanv $base.layers
    set lfr $lcanv.lfr

    layer_set_cutbit $canv $layerid $cutbit
    layer_set_cutdepth $canv $layerid $cutdepth

    if {$cutbit > 0} {
        $lfr.cam$layerid configure -image $camimg
    } else {
        $lfr.cam$layerid configure -image $nocamimg
    }
    mainwin_redraw $win
}


proc layerwin_toggle_visible {base layerid} {
    global layerwinInfo

    set win $layerwinInfo(WIN-$base)
    set canv [mainwin_get_canvas $win]
    set visimg $layerwinInfo(VISICON-$base)
    set invisimg $layerwinInfo(INVISICON-$base)

    cutpaste_set_checkpoint $canv

    set lcanv $base.layers
    set lfr $lcanv.lfr

    if {[layer_visible $canv $layerid]} {
        $lfr.visible$layerid configure -image $invisimg
        layer_set_visible $canv $layerid 0
        cadselect_deselect_nonvisible $canv
    } else {
        $lfr.visible$layerid configure -image $visimg
        layer_set_visible $canv $layerid 1
    }

    mainwin_redraw $win
}


proc layerwin_select_layer {base layerid X Y} {
    global layerwinInfo

    set layerwinInfo(CLICK-$base) [list $X $Y]

    set win $layerwinInfo(WIN-$base)
    set canv [mainwin_get_canvas $win]

    cutpaste_set_checkpoint $canv

    set lcanv $base.layers
    set lfr $lcanv.lfr

    set namebg #7f7fff
    set namefg black
    set namebg systemHighlight
    set namefg systemHighlightText

    set oldlayerid [layer_get_current $canv]
    $lfr.name$oldlayerid configure -background white -foreground black
    $lfr.name$layerid configure -background $namebg -foreground $namefg
    layer_set_current $canv $layerid
}


proc layerwin_rename_layer_init {base wname layerid} {
    global layerwinInfo
    set win $layerwinInfo(WIN-$base)
    set canv [mainwin_get_canvas $win]

    set ginfo [grid info $wname]
    grid forget $wname

    set ent [winfo parent $wname]
    set ent [entry $ent.edit -width 5 -borderwidth 0 -highlightthickness 1]
    grid $ent {*}$ginfo

    $ent insert end [layer_name $canv $layerid]
    after 10 "focus $ent; $ent selection range 0 end"

    bind $ent <Key-Return> "layerwin_rename_layer_commit $base %W $layerid"
    bind $ent <Key-Escape> "layerwin_rename_layer_cancel $base %W"
}


proc layerwin_rename_layer_commit {base ent layerid} {
    global layerwinInfo
    set win $layerwinInfo(WIN-$base)
    set canv [mainwin_get_canvas $win]

    cutpaste_set_checkpoint $canv

    layer_set_name $canv $layerid [$ent get]
    destroy $ent
    layerwin_refresh $base
    focus $canv
}


proc layerwin_rename_layer_cancel {base ent} {
    global layerwinInfo
    set win $layerwinInfo(WIN-$base)
    set canv [mainwin_get_canvas $win]

    destroy $ent
    layerwin_refresh $base
    focus $canv
}


proc layerwin_drag_motion {base wname layerid X Y} {
    global layerwinInfo

    if {![info exists layerwinInfo(CLICK-$base)]} {
        return
    }
    lassign $layerwinInfo(CLICK-$base) oX oY
    if {hypot($Y-$oY,$X-$oX) >= 5} {
        set layerwinInfo(DRAG-$base) 1
    }
    if {![info exists layerwinInfo(DRAG-$base)]} {
        return
    }
    if {[info exists layerwinInfo(DRAGPID-$base)]} {
        after cancel $layerwinInfo(DRAGPID-$base)
        unset layerwinInfo(DRAGPID-$base)
    }

    set parent $base.layers
    set rX [winfo rootx $parent]
    set rY [winfo rooty $parent]
    set rw [winfo width $parent]
    set rh [winfo height $parent]
    if {$X < $rX || $Y < $rY || $X > $rX+$rw || $Y > $rY+$rh} {
        # out of bounds.
        # maybe hide indicator
        return
    }

    set vscroll $base.vscroll
    lassign [$vscroll get] vstop vsbot
    if {$Y < $rY+10 && $vstop > 0.0} {
        $parent yview scroll -1 units
        set pid [after 100 [list layerwin_drag_motion $base $wname $layerid $X $Y]]
        set layerwinInfo(DRAGPID-$base) $pid
    } elseif {$Y > $rY+$rh-10 && $vsbot < 1.0} {
        $parent yview scroll 1 units
        set pid [after 100 [list layerwin_drag_motion $base $wname $layerid $X $Y]]
        set layerwinInfo(DRAGPID-$base) $pid
    }

    set win $layerwinInfo(WIN-$base)
    set canv [mainwin_get_canvas $win]

    set poswin [winfo containing -displayof $base $X $Y]
    if {[regexp -nocase {[a-z]([0-9][0-9]*)$} $poswin dummy targlid]} {
        set origpos [layer_pos $canv $layerid]
        set targpos [layer_pos $canv $targlid]
        set par [winfo parent $poswin]
        set refw $par.lock$targlid
        set pary [winfo rooty $par]
        set refy [winfo y $refw]
        set refh [winfo height $refw]
        set liney $refy
        if {$Y-$pary > $refy+$refh/2} {
            incr targpos
            incr liney $refh
        }
        catch {destroy $par.line}
        frame $par.line -height 1 -relief flat -borderwidth 0 -background red -width 200
        place $par.line -x 10 -y $liney
        raise $par.line
        if {$targpos > $origpos} {
            incr targpos -1
        }
        set layerwinInfo(DRAGPOS-$base) $targpos
    }
}


proc layerwin_drag_release {base wname layerid X Y} {
    global layerwinInfo

    layerwin_drag_motion $base $wname $layerid $X $Y

    if {![info exists layerwinInfo(CLICK-$base)]} {
        return
    }
    lassign $layerwinInfo(CLICK-$base) oX oY
    unset layerwinInfo(CLICK-$base)

    set par [winfo parent $wname]
    catch { destroy $par.line }

    if {![info exists layerwinInfo(DRAG-$base)]} {
        return
    }
    unset layerwinInfo(DRAG-$base)

    if {![info exists layerwinInfo(DRAGPOS-$base)]} {
        return
    }
    set pos $layerwinInfo(DRAGPOS-$base)
    unset layerwinInfo(DRAGPOS-$base)

    set parent $base.layers
    set rX [winfo rootx $parent]
    set rY [winfo rooty $parent]
    set rw [winfo width $parent]
    set rh [winfo height $parent]
    if {$X < $rX || $Y < $rY || $X > $rX+$rw || $Y > $rY+$rh} {
        # out of bounds.
        return
    }

    set win $layerwinInfo(WIN-$base)
    set canv [mainwin_get_canvas $win]

    cutpaste_set_checkpoint $canv
    cutpaste_remember_layer_change $canv $layerid
    layer_reorder $canv $layerid $pos
    layerwin_refresh $base
}


proc layerwin_new {base} {
    global layerwinInfo

    set win $layerwinInfo(WIN-$base)
    set canv [mainwin_get_canvas $win]

    cutpaste_set_checkpoint $canv

    set layerid [layer_create $canv]
    layer_set_current $canv $layerid
    layerwin_refresh $base $layerid
}


proc layerwin_delete {base} {
    global layerwinInfo

    set win $layerwinInfo(WIN-$base)
    set canv [mainwin_get_canvas $win]
    set parent [winfo toplevel $canv]

    if {[llength [layer_ids $canv]] == 1} {
        bell
        return
    }

    cutpaste_set_checkpoint $canv

    set layerid [layer_get_current $canv]
    set layername [layer_name $canv $layerid]

    set res "yes"
    if {[llength [layer_objects $canv $layerid]] > 0} {
        set res [tk_messageBox -type yesno \
            -default no -icon warning -parent $parent \
            -message "Are you sure you want to delete the layer '$layername' and all of the objects in it?"]
    }

    if {$res == "yes"} {
        layer_delete $canv $layerid
        layerwin_refresh $base
    }
}


layerwin_init


# vim: set ts=4 sw=4 nowrap expandtab: settings

