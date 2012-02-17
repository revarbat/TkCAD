proc mainwin_init {} {
    global mainwinInfo
    set mainwinInfo(WINNUM) 0
    set mainwinInfo(WINCOUNT) 0
    set mainwinInfo(WINDOWS) {}
}
mainwin_init


proc mainwin_create {} {
    global mainwinInfo

    set screenw [winfo screenwidth .]
    set screenh [winfo screenheight .]

    set winnum [incr mainwinInfo(WINNUM)]
    set win ".cadmain$winnum"
    incr mainwinInfo(WINCOUNT)

    set tooltitleh 18
    set titleh 22
    set menubarh 22

    set iwidth [expr {$screenw-16}]
    set iheight 88
    set belowinfo [expr {$iheight+23}]

    set twidth 42

    set lwidth 250
    set lheight 200
    set layerwinx [expr {$screenw-$lwidth}]

    set swidth 250
    set sheight 125
    set snapswiny [expr {$belowinfo+$lheight+$tooltitleh-1}]

    set ewidth 250
    set eheight 200
    set editwiny [expr {$snapswiny+$sheight+$tooltitleh-1}]

    set winx [expr {$twidth+2}]
    set winy [expr {$belowinfo+4}]
    set winw [expr {$screenw-$winx-$lwidth-1}]
    set winh [expr {$screenh-$winy-$titleh}]

    toplevel $win -menu $win.menubar
    lappend mainwinInfo(WINDOWS) $win

    set infowin ".info"
    if {![winfo exists $infowin]} {
        infopanewin_create $infowin
        wm geometry $infowin ${iwidth}x${iheight}+4+${menubarh}
        subwindows_register "" $infowin "Info" 1 "side"
    }

    set toolwin ".tools"
    if {![winfo exists $toolwin]} {
        toolwin_create $toolwin
        wm geometry $toolwin +0+${belowinfo}
        subwindows_register "" $toolwin "Tools" 1
    }

    layerwin_create $win.layers $win
    wm geometry $win.layers ${lwidth}x${lheight}+${layerwinx}+${belowinfo}
    subwindows_register $win $win.layers "Layers" 1 "grow"

    set snapwin ".snaps"
    if {![winfo exists $snapwin]} {
        snapswin_create $snapwin
        wm geometry $snapwin ${swidth}x${sheight}+${layerwinx}+${snapswiny}
        subwindows_register "" $snapwin "Snaps" 1 "grow"
    }

    set editwin ".edit"
    if {![winfo exists $editwin]} {
        editpanewin_create $editwin
        wm geometry $editwin ${ewidth}x${eheight}+${layerwinx}+${editwiny}
        subwindows_register "" $editwin "Tool Config" 1 "grow"
    }

    wm title $win "tkCAD"
    wm protocol $win WM_DELETE_WINDOW [list mainwin_close $win]
    wm geometry $win ${winw}x${winh}+${winx}+${winy}

    frame $win.rcorner -relief flat \
        -borderwidth 0 -highlightthickness 0 \
        -background white
    ruler_create $win.hruler $win.canv horizontal
    ruler_create $win.vruler $win.canv vertical
    if {[namespace exists ::tkp]} {
        set canvcmd ::tkp::canvas
    } else {
        set canvcmd canvas
    }
    $canvcmd $win.canv -width 700 -height 500 -relief flat \
        -borderwidth 0 -highlightthickness 0 \
        -takefocus 1 -confine 0 -closeenough 2.0 \
        -xscrollincrement 10 -yscrollincrement 10 \
        -scrollregion {-1000 -1000 1000 1000} \
        -xscrollcommand "mainwin_canvas_scroll_from_canv horizontal $win $win.canvscrh" \
        -yscrollcommand "mainwin_canvas_scroll_from_canv vertical   $win $win.canvscrv"
    set bt [bindtags $win.canv]
    set bt [linsert $bt 0 ToolMenu]
    bindtags $win.canv $bt
    scrollbar $win.canvscrv -orient vertical   -command [list $win.canv yview]
    scrollbar $win.canvscrh -orient horizontal -command [list $win.canv xview]
    entry $win.zooment -width 8 -font {helvetica 8} \
        -highlightthickness 0 -relief solid -borderwidth 1
    $win.zooment insert end "100%"
    set unitsystems {"Inches (Decimal)" "Inches (Fractions)" Feet Millimeters Centimeters Meters}
    tk_optionMenu $win.unitsys mainwinInfo(UNITSYS-$win) {*}$unitsystems
    $win.unitsys configure \
        -highlightthickness 0 \
        -borderwidth 0 \
        -takefocus 0 \
        -font {Helvetica 9} \
        -width 15 -pady 0 \
        -justify left
    set mainwinInfo(UNITSYS-$win) [lindex $unitsystems 1]
    trace add variable mainwinInfo(UNITSYS-$win) write "mainwin_setunits $win"

    grid columnconfigure $win 3 -weight 10
    grid rowconfigure $win 1 -weight 10

    grid $win.rcorner  $win.hruler  -             -              $win.canvscrv
    grid $win.vruler   $win.canv    -             -              ^
    grid $win.zooment  -            $win.unitsys  $win.canvscrh

    grid $win.rcorner $win.canv $win.zooment $win.unitsys -sticky nsew
    grid $win.hruler   -sticky ews
    grid $win.vruler   -sticky nes
    grid $win.canvscrv -sticky nws
    grid $win.canvscrh -sticky nwe

    bind $win.canv <MouseWheel>         "mainwin_canvas_scroll $win yview %D ; break"
    bind $win.canv <Shift-MouseWheel>   "mainwin_canvas_scroll $win xview %D ; break"
    bind $win.canv <Command-MouseWheel> "mainwin_canvas_zoom $win %D %x %y ; break"
    bind $win.canv <Command-Shift-MouseWheel> "break"
    bind $win.canv <Key-Delete>          "mainmenu_clear %W ; break"
    bind $win.canv <Key-BackSpace>       "mainmenu_clear %W ; break"

    bind $win <Activate>     "mainwin_activate $win"
    bind $win <Deactivate>   "mainwin_deactivate $win"

    set subwins [subwindows_list $win]
    lappend subwins $win.canv $toolwin
    foreach subwin $subwins {
        bind $subwin <Control-Option-Command-Key-l>        "mainwin_addline $win"

        if {$subwin == ".info" || $subwin == "$win.layers"} {
            continue
        }
        bind $subwin <Key-Left>   "mainwin_canvas_scroll $win xview 5 ; break"
        bind $subwin <Key-Right>  "mainwin_canvas_scroll $win xview -5 ; break"
        bind $subwin <Key-Up>     "mainwin_canvas_scroll $win yview 5 ; break"
        bind $subwin <Key-Down>   "mainwin_canvas_scroll $win yview -5 ; break"
        bind $subwin <Key-Escape> "cadobjects_reset ; break"
    }

    bind all <KeyPress-Meta_L>      "cadobjects_modkey_press COMMAND ; continue"
    bind all <KeyPress-Meta_R>      "cadobjects_modkey_press COMMAND ; continue"
    bind all <KeyPress-Control_L>   "cadobjects_modkey_press CONTROL ; continue"
    bind all <KeyPress-Control_R>   "cadobjects_modkey_press CONTROL ; continue"
    bind all <KeyPress-Shift_L>     "cadobjects_modkey_press SHIFT   ; continue"
    bind all <KeyPress-Shift_R>     "cadobjects_modkey_press SHIFT   ; continue"
    bind all <KeyPress-Alt_L>       "cadobjects_modkey_press MOD2    ; continue"
    bind all <KeyPress-Alt_R>       "cadobjects_modkey_press MOD2    ; continue"

    bind all <KeyRelease-Meta_L>    "cadobjects_modkey_release COMMAND ; continue"
    bind all <KeyRelease-Meta_R>    "cadobjects_modkey_release COMMAND ; continue"
    bind all <KeyRelease-Control_L> "cadobjects_modkey_release CONTROL ; continue"
    bind all <KeyRelease-Control_R> "cadobjects_modkey_release CONTROL ; continue"
    bind all <KeyRelease-Shift_L>   "cadobjects_modkey_release SHIFT   ; continue"
    bind all <KeyRelease-Shift_R>   "cadobjects_modkey_release SHIFT   ; continue"
    bind all <KeyRelease-Alt_L>     "cadobjects_modkey_release MOD2    ; continue"
    bind all <KeyRelease-Alt_R>     "cadobjects_modkey_release MOD2    ; continue"

    bind $win.zooment <Key-Escape>  "mainwin_canvas_zoom_reset $win ; break"
    bind $win.zooment <Key-Return>  "mainwin_canvas_set_zoom $win ; break"

    cadobjects_init $win.canv $win
    tool_canvas_init $win.canv $toolwin "cadobjects_reset"
    layerwin_refresh $win.layers

    cadobjects_clear_modified $win.canv
    mainmenu_create $win
    after 100 mainwin_create2 $win $snapwin
    return $win
}


proc mainwin_create2 {win snapwin} {
    mainmenu_update_window_menu $win
    snapswin_update $snapwin
    focus $win.canv
    return $win
}


proc mainwin_get_canvas {win} {
    return $win.canv
}


proc mainwin_current {} {
    set toplev .
    foreach tlev [lreverse [wm stackorder .]] {
        if {[regexp {^.cadmain[0-9]*$} $tlev]} {
            set toplev $tlev
            break
        }
    }
    while {1} {
        set menw [$toplev cget -menu]
        if {$menw != "" || $toplev == "."} {
            break
        }
        set tlev [winfo parent $toplev]
        set tlev [winfo toplevel $tlev]
        if {$tlev == "."} break
        set toplev $tlev
    }
    return $toplev
}


proc ::tk::mac::ReopenApplication { } {
    set win [mainwin_current]
    if {$win == "." || $win == ""} {
        mainwin_create
    }
}


proc ::tk::mac::PrintDocument {args} {
    set win [mainwin_current]
    if {$win == "." || $win == ""} {
        after 100 "::tk::mac::PrintDocument $args"
        return
    }
    foreach file $args {
        set ext [string tolower [file extension $file]]
        set ffids [fileformat_ids_from_extension $ext]
        set ffid -1
        foreach ffmtid $ffids {
            if {[fileformat_can_read $ffmtid]} {
                set ffid $ffmtid
            }
        }
        if {$ffid != -1} {
            cutpaste_canvas_init $win.canv
            set newwin [fileformat_openfile $win $file]
            mainwin_print $newwin
            mainwin_close_window $newwin
        } else {
            switch -exact -- $ext {
                .tap -
                .cnc -
                .gcode -
                .nc {
                    # No gcode backtrace printing support yet.
                }
            }
        }
    }
}


proc ::tk::mac::OpenDocument {args} {
    set win [mainwin_current]
    if {$win == "." || $win == ""} {
        after 100 "::tk::mac::OpenDocument $args"
        return
    }
    foreach file $args {
        set ext [string tolower [file extension $file]]
        set ffids [fileformat_ids_from_extension $ext]
        set ffid -1
        foreach ffmtid $ffids {
            if {[fileformat_can_read $ffmtid]} {
                set ffid $ffmtid
            }
        }
        if {$ffid != -1} {
            cutpaste_canvas_init $win.canv
            fileformat_openfile $win $file
        } else {
            switch -exact -- $ext {
                .tap -
                .cnc -
                .gcode -
                .nc {
                    cadgcode_backtrace_start $file
                }
            }
        }
    }
}


proc mainwin_open {win {filename ""}} {
    if {$win == ""} {
        set win "."
    }
    cutpaste_canvas_init $win.canv
    if {$filename != ""} {
        set win [fileformat_openfile $win $filename]
    } else {
        set win [fileformat_open $win]
    }
    if {$win == ""} {
        return
    }
    set canv $win.canv
    cadobjects_clear_modified $canv
    mainwin_update_layerwin $win
}


proc mainwin_import {win} {
    fileformat_open $win 1
}


proc mainwin_export {win} {
    fileformat_export $win $win.canv
}


proc mainwin_export_gcode {win} {
    cadgcode_generate $win.canv
}


proc mainwin_backtrace_start {win} {
    cadgcode_backtrace_start
}


proc mainwin_page_setup {win} {
    print_page_setup $win
}


proc mainwin_print {win} {
    print_cadobjects $win $win.canv 0
}


proc mainwin_save {win} {
    fileformat_save $win $win.canv
    cadobjects_clear_modified $win.canv
}


proc mainwin_saveas {win} {
    fileformat_saveas $win $win.canv
    cadobjects_clear_modified $win.canv
}


proc mainwin_close_window {{win ""}} {
    if {$win == ""} {
        set win [mainwin_current]
    }
    set cmd [wm protocol $win WM_DELETE_WINDOW]
    if {$cmd != ""} {
        eval $cmd
    } else {
        if {[winfo exists $win]} {
            destroy $win
        }
    }
}


proc mainwin_close {win} {
    global mainwinInfo
    if {[cadobjects_is_modified $win.canv]} {
        set doc [fileformat_get_filename $win]
        if {$doc == ""} {
            set doc "Untitled"
        } else {
            set doc [file tail $doc]
        }
        raise $win
        set res [tk_messageBox -type yesnocancel -icon warning \
                    -default yes -parent $win -title "Confirm Close" \
                    -message "Do you want to save the changes you made in the document \"$doc\"?" \
                    -detail "Your changes will be lost if you don’t save them."]

        switch -exact -- $res {
            cancel { return 0 }
            yes { mainwin_save $win }
        }
    }

    destroy $win

    set wins $mainwinInfo(WINDOWS)
    set pos [lsearch -exact $wins $win]
    if {$pos >= 0} {
        set mainwinInfo(WINDOWS) [lreplace $wins $pos $pos]
    }

    return 1
}


proc mainwin_quit {} {
    global mainwinInfo
    foreach win $mainwinInfo(WINDOWS) {
        if {![mainwin_close $win]} {
            return
        }
    }
    tkcad_exit
}


proc mainwin_get_infopane {win} {
    return .info
}


proc mainwin_get_editpane {win} {
    return .edit
}


proc mainwin_update_mousepos {win realx realy unit} {
    ruler_update_mousepos $win.hruler $realx
    ruler_update_mousepos $win.vruler $realy
    infopane_update_mousepos .info $realx $realy $unit
}


proc mainwin_canvas_scroll_from_canv {orient win scrb first last} {
    $scrb set $first $last
    if {$orient == "horizontal"} {
        ruler_redraw $win.hruler
    } else {
        ruler_redraw $win.vruler
    }
    cadobjects_redraw_grid $win.canv
}


proc mainwin_canvas_scroll {win view dir} {
    set canv $win.canv
    set div 1
    $canv $view scroll [expr {-int($dir/$div)}] unit
    if {$view == "xview"} {
        ruler_redraw $win.hruler
    } else {
        ruler_redraw $win.vruler
    }
    cadobjects_redraw_grid $win.canv
}


proc mainwin_canvas_zoom_reset {win} {
    set sfact [cadobjects_get_scale_factor $win.canv]
    $win.zooment delete 0 end
    $win.zooment insert end [format "%.5g%%" [expr {$sfact*100.0}]]
    focus [tk_focusNext $win.zooment]
}


proc mainwin_canvas_set_zoom {win} {
    set zoomval [$win.zooment get]
    set zoomval [string trim $zoomval " %"]
    if {![string is double $zoomval]} {
        bell
    } elseif {$zoomval < 1.0} {
        bell
    } elseif {$zoomval > 5000.0} {
        bell
    } else {
        cadobjects_rescale_redraw $win.canv [expr {$zoomval/100.0}]
        ruler_redraw $win.hruler
        ruler_redraw $win.vruler
        cadobjects_redraw_grid $win.canv
    }
    mainwin_canvas_zoom_reset $win
    focus [tk_focusNext $win.zooment]
}


proc mainwin_windows {} {
    global mainwinInfo
    if {![info exists mainwinInfo(WINDOWS)]} {
        return ""
    }
    return $mainwinInfo(WINDOWS)
}


proc mainwin_nextwin {win} {
    set wins {}
    foreach tl [wm stackorder .] {
        if {[regexp {^.cadmain[0-9]*$} $tl]} {
            lappend wins $tl
        }
    }
    if {[llength $wins] < 2} {
        return
    }
    set win [lindex $wins end]
    lower $win [lindex $wins 0]
    set nuwin [lindex $wins end-1]
    raise $nuwin
    focus $nuwin
}


proc mainwin_activate {win} {
    subwindows_activate $win
    confpane_populate
    snapswin_update .snaps
    focus -force $win.canv
}


proc mainwin_deactivate {win} {
    return ;# Disable this, as it's hiding subwindows at inappropriate times.
    after 10 mainwin_deactivate2 $win
}


proc mainwin_deactivate2 {win} {
    if {[mainwin_current] == $win} {
        return
    }
    subwindows_deactivate $win
}


proc mainwin_canvas_zoom {win dir {x ""} {y ""}} {
    set canv $win.canv
    set zooms {0.01 0.015 0.02 0.03 0.04 0.05 0.075 0.10 0.125 0.1667 0.25 0.33 0.5 0.67 1.0 1.33 1.67 2.0 3.0 4.0 6.0 8.0 10.0 12.0 14.0 16.0 25.0 33.0 50.0}
    set sfact [cadobjects_get_scale_factor $canv]
    if {$y == ""} {
        set x [expr {[winfo reqwidth $canv]/2.0}]
        set y [expr {[winfo reqheight $canv]/2.0}]
    }
    set cx [$canv canvasx $x]
    set cy [$canv canvasy $y]
    foreach {x0 y0 x1 y1} [$canv cget -scrollregion] break
    set pcx [expr {($cx-$x0)/($x1-$x0)}]
    set pcy [expr {($cy-$y0)/($y1-$y0)}]

    if {$dir > 0} {
        foreach sc $zooms {
            if {$sc > $sfact} {
                set sfact $sc
                break
            }
        }
    } else {
        set nsfact $sfact
        foreach sc $zooms {
            if {$sc < $sfact} {
                set nsfact $sc
            }
        }
        set sfact $nsfact
    }
    cadobjects_rescale_redraw $canv $sfact
    $win.zooment delete 0 end
    $win.zooment insert end [format "%.5g%%" [expr {$sfact*100.0}]]

    foreach {x2 y2 x3 y3} [$canv cget -scrollregion] break
    set ofx [expr {$x/($x3-$x2)}]
    set ofy [expr {$y/($y3-$y2)}]
    $canv xview moveto [expr {$pcx-$ofx}]
    $canv yview moveto [expr {$pcy-$ofy}]
    ruler_redraw $win.hruler
    ruler_redraw $win.vruler
    cadobjects_redraw_grid $win.canv
}


proc mainwin_canvas_zoom_actual {win} {
    set canv $win.canv
    set reqx [winfo width $canv]
    set reqy [winfo height $canv]
    if {$reqx < 2} {
        set reqx [winfo reqwidth $canv]
        set reqy [winfo reqheight $canv]
    }
    if {$reqx < 2} {
        set reqx [$canv cget -width]
        set reqy [$canv cget -height]
    }
    set zoom 1.0
    cadobjects_rescale_redraw $canv $zoom
    mainwin_canvas_zoom_reset $win

    foreach {x0 y0 x1 y1} [$canv bbox AllDrawn] break
    if {[info exists x0]} {
        set cx [expr {($x0+$x1)/2.0}]
        set cy [expr {($y0+$y1)/2.0}]
    } else {
        set cx [expr {$reqx*0.3}]
        set cy [expr {-$reqy*0.3}]
    }

    foreach {sx0 sy0 sx1 sy1} [$canv cget -scrollregion] break
    set xoff [expr {($cx-$reqx/2.0-$sx0)/($sx1-$sx0)}]
    set yoff [expr {($cy-$reqy/2.0-$sy0)/($sy1-$sy0)}]
    $canv xview moveto $xoff
    $canv yview moveto $yoff
}


proc mainwin_canvas_zoom_all {win} {
    set canv $win.canv
    if {![winfo exists $canv]} {
        return
    }

    set reqx [winfo width $canv]
    set reqy [winfo height $canv]
    if {$reqx < 2} {
        set reqx [winfo reqwidth $canv]
        set reqy [winfo reqheight $canv]
    }
    if {$reqx < 2} {
        set reqx [$canv cget -width]
        set reqy [$canv cget -height]
    }

    set dpi [cadobjects_get_dpi $canv]
    foreach {x0 y0 x1 y1} [cadobjects_objects_bbox $canv ALL] break
    set zoomx [expr {0.90*$reqx/$dpi/abs($x1-$x0)}]
    set zoomy [expr {0.90*$reqy/$dpi/abs($y1-$y0)}]
    if {$zoomx < $zoomy} {
        set zoom $zoomx
    } else {
        set zoom $zoomy
    }
    set zoom [expr {floor($zoom*100.0)/100.0}]
    cadobjects_rescale_redraw $canv $zoom
    mainwin_canvas_zoom_reset $win
    set nuscale [cadobjects_get_scale_factor $canv]

    set cx [expr {($x0+$x1)*0.5*$nuscale*$dpi}]
    set cy [expr {($y0+$y1)*0.5*$nuscale*-$dpi}]

    foreach {sx0 sy0 sx1 sy1} [$canv cget -scrollregion] break
    #set dsx [expr {$sx1-$sx0}]
    #set dsy [expr {$sy1-$sy0}]
    #set xpart [expr {$reqx/(0.0+$sx1-$sx0)}]
    #set ypart [expr {$reqy/(0.0+$sy1-$sy0)}]
    #set xoff [expr {(($cx-$sx0)/(0.0+$sx1-$sx0))-($xpart/2.0)}]
    #set yoff [expr {(($cy-$sy0)/(0.0+$sy1-$sy0))-($ypart/2.0)}]

    set xoff [expr {($cx-$reqx/2.0-$sx0)/($sx1-$sx0)}]
    set yoff [expr {($cy-$reqy/2.0-$sy0)/($sy1-$sy0)}]
    $canv xview moveto $xoff
    $canv yview moveto $yoff
}


proc mainwin_copy {win} {
    set objids [cadselect_list $win.canv]
    cutpaste_copy $win.canv $objids
    confpane_populate
}


proc mainwin_cut {win} {
    set objids [cadselect_list $win.canv]
    cutpaste_cut $win.canv $objids
    confpane_populate
}


proc mainwin_paste {win} {
    cutpaste_paste $win.canv
    confpane_populate
}


proc mainwin_clear {win} {
    cutpaste_set_checkpoint $win.canv
    cadobjects_object_delete_selected $win.canv
    confpane_populate
}


proc mainwin_undo {win} {
    cutpaste_undo $win.canv
    confpane_populate
}


proc mainwin_redo {win} {
    cutpaste_redo $win.canv
    confpane_populate
}


proc mainwin_select_similar {win} {
    cadselect_select_similar $win.canv
    confpane_populate
}


proc mainwin_select_all {win} {
    cadselect_select_all $win.canv
    confpane_populate
}


proc mainwin_deselect_all {win} {
    cadselect_clear $win.canv
    confpane_populate
}


proc mainwin_newgroup {win} {
    cadobjects_object_newgroup $win.canv
    confpane_populate
}


proc mainwin_ungroup {win} {
    cadobjects_object_ungroup $win.canv
    confpane_populate
}


proc mainwin_update_layerwin {win} {
    defer layerwin_refresh $win.layers
}


proc mainwin_redraw {{wins ""}} {
    if {$wins == ""} {
        set wins [mainwin_windows]
    }
    foreach win $wins {
        cadobjects_redraw $win.canv
        ruler_redraw $win.hruler
        ruler_redraw $win.vruler
        cadobjects_redraw_grid $win.canv
        layerwin_refresh $win.layers
    }
    confpane_populate
    snapswin_update .snaps
}


proc mainwin_rotate_selected_by {win degrees} {
    cutpaste_set_checkpoint $win.canv
    plugin_rotate_selected_by $win.canv $degrees
    confpane_populate
}


proc mainwin_join_curves {win} {
    cutpaste_set_checkpoint $win.canv
    plugin_line_join_selected $win.canv
    confpane_populate
}


proc mainwin_paths_union {win} {
    cutpaste_set_checkpoint $win.canv
    plugin_line_union_selected $win.canv
    confpane_populate
}


proc mainwin_paths_diff {win} {
    cutpaste_set_checkpoint $win.canv
    plugin_line_diff_selected $win.canv
    confpane_populate
}


proc mainwin_paths_intersection {win} {
    cutpaste_set_checkpoint $win.canv
    plugin_line_intersect_selected $win.canv
    confpane_populate
}


proc mainwin_convert_to_lines {win} {
    cutpaste_set_checkpoint $win.canv
    plugin_line_lineize_selected $win.canv
    confpane_populate
}


proc mainwin_convert_to_curves {win} {
    cutpaste_set_checkpoint $win.canv
    plugin_line_bezierize_selected $win.canv
    confpane_populate
}


proc mainwin_vectorize_bitmaps {win} {
    cutpaste_set_checkpoint $win.canv
    plugin_image_vectorize_selected $win $win.canv
    confpane_populate
}


proc mainwin_simplify_curves {win} {
    cutpaste_set_checkpoint $win.canv
    plugin_line_simplify_selected $win.canv
    confpane_populate
}


proc mainwin_smooth_curves {win} {
    cutpaste_set_checkpoint $win.canv
    plugin_line_smooth_selected $win.canv
    confpane_populate
}


proc mainwin_addline {win} {
    set canv $win.canv
    toplevel .mnal
    wm title .mnal "Line Coords"
    entry .mnal.ent
    button .mnal.add -text Add -command "mainwin_addline_commit $win"
    pack .mnal.ent -expand 1 -fill x
    pack .mnal.add
    focus .mnal.ent
    bind .mnal.ent <Key-Return> ".mnal.add invoke"
    bind .mnal.ent <Key-Escape> "destroy .mnal"
}


proc mainwin_addline_commit {win} {
    set canv $win.canv
    set vals [.mnal.ent get]
    destroy .mnal

    cadselect_clear $canv

    set vals [string map {"\n" ""} $vals]
    set vals [regsub -all {=} $vals "\n"]
    foreach val [split $vals "\n"] {
        set val [regsub -all {[^0-9. -]} $val " "]
        set val [regsub -all " - " $val " "]
        set val [regsub -all {   *} $val " "]
        set val [string trim $val]
        if {[llength $val] % 2 == 1} {
            set val [lrange $val 0 end-1]
        }
        if {[llength $val] == 0} continue
        puts stdout "val='$val'"

        set nuobj [cadobjects_object_create $canv LINE $val {}]
        cadobjects_object_recalculate $canv $nuobj
        cadobjects_object_draw $canv $nuobj
        cadobjects_object_draw_controls $canv $nuobj red
        cadselect_add $canv $nuobj
    }
    focus $canv
}


proc mainwin_raise_selected {win {pos "-1"}} {
    set canv $win.canv
    cadobjects_object_arrange $canv $pos SELECTED
}


proc mainwin_lower_selected {win {pos "1"}} {
    set canv $win.canv
    cadobjects_object_arrange $canv $pos SELECTED
}


proc mainwin_update_unitsys {win} {
    global mainwinInfo
    set unitsys [cadobjects_get_unitsystem $win.canv]
    trace remove variable mainwinInfo(UNITSYS-$win) write "mainwin_setunits $win"
    set mainwinInfo(UNITSYS-$win) $unitsys
    trace add variable mainwinInfo(UNITSYS-$win) write "mainwin_setunits $win"
}


proc mainwin_setunits {win args} {
    global mainwinInfo
    set unitsys $mainwinInfo(UNITSYS-$win)
    cadobjects_set_unitsystem $win.canv $unitsys 0
    ruler_redraw $win.hruler
    ruler_redraw $win.vruler
    cadobjects_redraw_grid $win.canv
}



# vim: set ts=4 sw=4 nowrap expandtab: settings

