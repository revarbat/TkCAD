proc mainmenu_nowin_rebind {} {
    bind all <Command-Key-n>        "mainmenu_menu_invoke %W {File|New} ; break"
    bind all <Command-Key-o>        "mainmenu_menu_invoke %W {File|Open...} ; break"
    bind all <Command-Key-s>        "mainmenu_menu_invoke %W {File|Save} ; break"
    bind all <Shift-Command-Key-S>  "mainmenu_menu_invoke %W {File|Save As...} ; break"
    bind all <Command-Key-w>        "mainmenu_menu_invoke %W {File|Close} ; break"
    bind all <Command-Key-W>        "mainmenu_menu_invoke %W {File|Close} ; break"

    bind all <Command-Key-x>        "mainmenu_cut %W ; break"
    bind all <Command-Key-c>        "mainmenu_copy %W ; break"
    bind all <Command-Key-v>        "mainmenu_paste %W ; break"
    bind all <Command-Shift-Option-Control-Key-K> "console show; puts stderr \[winfo children .\]; break"
}


proc mainmenu_nowin_create {} {
    set win ""
    set mb [menu $win.menubar -tearoff 0]

    set filemenu [menu $mb.file -tearoff 0]
    set recentmenu [menu $filemenu.recent -tearoff 0 -postcommand "mainmenu_recentmenu_populate . $filemenu.recent"]
    $filemenu add command -label "New"   -underline 0 -accelerator "Command+N" -command "mainwin_create"
    $filemenu add command -label "Open..." -underline 0 -accelerator "Command+O" -command "mainwin_open ."
    $filemenu add cascade -label "Open Recent" -underline 5 -menu $recentmenu
    $filemenu add separator
    $filemenu add command -label "Close" -underline 0 -accelerator "Command+W" -state disabled
    $filemenu add command -label "Save"  -underline 0 -accelerator "Command+S" -state disabled
    $filemenu add command -label "Save As..." -underline 1 -accelerator "Shift+Command+S" -state disabled

    set editmenu [menu $mb.edit -tearoff 0]
    $editmenu add command -label "Cut"   -underline 1 -accelerator "Command+X" -command "mainmenu_cut \[focus\] 1"
    $editmenu add command -label "Copy"  -underline 0 -accelerator "Command+C" -command "mainmenu_copy \[focus\] 1"
    $editmenu add command -label "Paste" -underline 0 -accelerator "Command+V" -command "mainmenu_paste \[focus\] 1"
    $editmenu add separator
    $editmenu add command -label "Clear" -underline 1 -accelerator "Delete" -command "mainmenu_clear \[focus\] 1"

    $mb add cascade -label File -underline 0 -menu $filemenu
    $mb add cascade -label Edit -underline 0 -menu $editmenu

    mainmenu_recentmenu_populate . $recentmenu
    . configure -menu $mb
    mainmenu_nowin_rebind
}



proc mainmenu_recentmenu_populate {win recentmenu} {
    $recentmenu delete 0 end
    set count 0
    foreach filename [/prefs:get recent_files] {
        if {[file exists $filename] && [file isfile $filename] && [file readable $filename]} {
            $recentmenu add command -label [file tail $filename] -command "mainwin_open $win $filename"
        }
        incr count
    }
    set state disabled
    if {$count > 0} {
        $recentmenu add separator
        set state normal
    }
    $recentmenu add command -label "Clear Menu" -state $state -command "/prefs:set recent_files {}"
}



proc mainmenu_create {win} {
    set mb [menu $win.menubar -tearoff 0]

    bind all <Command-Key-n>        "mainmenu_menu_invoke %W {File|New} ; break"
    bind all <Command-Key-o>        "mainmenu_menu_invoke %W {File|Open...} ; break"
    bind all <Command-Key-s>        "mainmenu_menu_invoke %W {File|Save} ; break"
    bind all <Shift-Command-Key-S>  "mainmenu_menu_invoke %W {File|Save As...} ; break"
    bind all <Shift-Command-Key-O>  "mainmenu_menu_invoke %W {File|Import...} ; break"
    bind all <Option-Shift-Command-Key-S>  "mainmenu_menu_invoke %W {File|Export...} ; break"
    bind all <Command-Key-w>        "mainmenu_menu_invoke %W {File|Close} ; break"
    bind all <Command-Key-W>        "mainmenu_menu_invoke %W {File|Close} ; break"

    bind all <Command-Key-z>        "mainmenu_menu_invoke %W {Edit|Undo} ; break"
    bind all <Shift-Command-Key-Z>  "mainmenu_menu_invoke %W {Edit|Redo} ; break"
    bind all <Command-Key-x>        "mainmenu_cut %W ; break"
    bind all <Command-Key-c>        "mainmenu_copy %W ; break"
    bind all <Command-Key-v>        "mainmenu_paste %W ; break"
    bind all <Key-Delete>           "mainmenu_clear %W ; break"
    bind all <Key-BackSpace>        "mainmenu_clear %W ; break"
    bind all <Command-Key-g>        "mainmenu_menu_invoke %W {Edit|Group} ; break"
    bind all <Shift-Command-Key-G>  "mainmenu_menu_invoke %W {Edit|Ungroup} ; break"
    bind all <Command-Key-a>        "mainmenu_menu_invoke %W {Edit|Select All} ; break"
    bind all <Command-Key-d>        "mainmenu_menu_invoke %W {Edit|Deselect All} ; break"
    bind all <Command-Key-l>        "mainmenu_menu_invoke %W {Edit|Convert to Lines} ; break"
    bind all <Command-Key-j>        "mainmenu_menu_invoke %W {Edit|Join Curves} ; break"
    bind all <Command-Key-b>        "mainmenu_menu_invoke %W {Edit|Convert to Curves} ; break"
    bind all <Option-Command-Key-b> "mainmenu_menu_invoke %W {Edit|Simplify Curves} ; break"
    bind all <Shift-Command-Key-B>  "mainmenu_menu_invoke %W {Edit|Smooth Curves} ; break"

    bind all <Command-Key-bracketleft>  "mainmenu_menu_invoke %W {Edit|Rotate 90 CW} ; break"
    bind all <Command-Key-bracketright> "mainmenu_menu_invoke %W {Edit|Rotate 90 CCW} ; break"
    bind all <Option-Command-Key-u>     "mainmenu_menu_invoke %W {Edit|Union of Polygons} ; break"
    bind all <Control-Option-Command-Key-d>     "mainmenu_menu_invoke %W {Edit|Difference of Polygons} ; break"
    bind all <Option-Command-Key-i>     "mainmenu_menu_invoke %W {Edit|Intersection of Polygons} ; break"

    bind all <Command-Key-r>        "mainmenu_menu_invoke %W {View|Redraw} ; break"
    bind all <Command-Key-0>        "mainmenu_menu_invoke %W {View|Actual Size} ; break"
    bind all <Command-Key-equal>    "mainmenu_menu_invoke %W {View|Zoom In} ; break"
    bind all <Command-Key-minus>    "mainmenu_menu_invoke %W {View|Zoom Out} ; break"

    bind all <Command-Key-m>         "mainmenu_menu_invoke %W {Window|Minimize} ; break"
    bind all <Command-Key-quoteleft> "mainmenu_menu_invoke %W {Window|Cycle Through Windows} ; break"


    set filemenu [menu $mb.file -tearoff 0]
    set recentmenu [menu $filemenu.recent -tearoff 0 -postcommand "mainmenu_recentmenu_populate \[mainwin_current\] $filemenu.recent"]
    $filemenu add command -label "New"   -underline 0 -accelerator "Command+N" -command "mainwin_create"
    $filemenu add command -label "Open..." -underline 0 -accelerator "Command+O" -command "mainwin_open \[mainwin_current\]"
    $filemenu add cascade -label "Open Recent" -underline 5 -menu $recentmenu
    $filemenu add separator
    $filemenu add command -label "Close" -underline 0 -accelerator "Command+W" -command "mainwin_close_window \[mainwin_current\]"
    $filemenu add command -label "Save"  -underline 0 -accelerator "Command+S" -command "mainwin_save \[mainwin_current\]"
    $filemenu add command -label "Save As..." -underline 1 -accelerator "Shift+Command+S" -command "mainwin_saveas \[mainwin_current\]"
    $filemenu add separator
    $filemenu add command -label "Import..." -underline 0 -accelerator "Shift+Command+O" -command "mainwin_import \[mainwin_current\]"
    $filemenu add command -label "Export..." -underline 0 -accelerator "Shift+Option+Command+S" -command "mainwin_export \[mainwin_current\]"
    $filemenu add separator
    $filemenu add command -label "Page Setup..." -underline 1 -accelerator "Shift+Command+P" -command "mainwin_page_setup \[mainwin_current\]"
    $filemenu add command -label "Print..." -underline 1 -accelerator "Command+P" -command "mainwin_print \[mainwin_current\]"

    mainmenu_recentmenu_populate [mainwin_current] $recentmenu

    set editmenu [menu $mb.edit -tearoff 0]
    set arrangemenu [menu $editmenu.arrange -tearoff 0]
    $arrangemenu add command -label "Raise to Top"    -underline 9 -command "mainwin_raise_selected \[mainwin_current\] top"
    $arrangemenu add command -label "Raise"           -underline 0 -command "mainwin_raise_selected \[mainwin_current\]"
    $arrangemenu add command -label "Lower"           -underline 0 -command "mainwin_lower_selected \[mainwin_current\]"
    $arrangemenu add command -label "Lower to Bottom" -underline 9 -command "mainwin_lower_selected \[mainwin_current\] bottom"

    $editmenu add command -label "Undo" -underline 0 -accelerator "Command+Z" -command "mainwin_undo \[mainwin_current\]"
    $editmenu add command -label "Redo" -underline 0 -accelerator "Shift+Command+Z" -command "mainwin_redo \[mainwin_current\]"
    $editmenu add separator
    $editmenu add command -label "Cut"   -underline 1 -accelerator "Command+X" -command "mainmenu_cut \[focus\] 1"
    $editmenu add command -label "Copy"  -underline 0 -accelerator "Command+C" -command "mainmenu_copy \[focus\] 1"
    $editmenu add command -label "Paste" -underline 0 -accelerator "Command+V" -command "mainmenu_paste \[focus\] 1"
    $editmenu add separator
    $editmenu add command -label "Select All" -underline 7 -accelerator "Command+A" -command "mainwin_select_all \[mainwin_current\]"
    $editmenu add command -label "Select All Similar" -underline 11 -command "mainwin_select_similar \[mainwin_current\]"
    $editmenu add command -label "Deselect All" -underline 0 -accelerator "Command+D" -command "mainwin_deselect_all \[mainwin_current\]"
    $editmenu add separator
    $editmenu add command -label "Clear" -underline 1 -accelerator "Delete" -command "mainmenu_clear \[focus\] 1"
    $editmenu add separator
    $editmenu add command -label "Group" -underline 0 -accelerator "Command+G" -command "mainwin_newgroup \[mainwin_current\]"
    $editmenu add command -label "Ungroup" -underline 1 -accelerator "Shift+Command+G" -command "mainwin_ungroup \[mainwin_current\]"
    $editmenu add cascade -label "Arrange" -underline 1 -menu $arrangemenu
    $editmenu add separator
    $editmenu add command -label "Rotate 90 CCW" -accelerator "Command+\[" -command "mainwin_rotate_selected_by \[mainwin_current\] -90"
    $editmenu add command -label "Rotate 90 CW" -accelerator "Command+\]" -command "mainwin_rotate_selected_by \[mainwin_current\] 90"
    $editmenu add command -label "Rotate 180" -command "mainwin_rotate_selected_by \[mainwin_current\] 180"
    $editmenu add separator
    $editmenu add command -label "Convert to Lines" -underline 11 -accelerator "Command+L" -command "mainwin_convert_to_lines \[mainwin_current\]"
    $editmenu add command -label "Convert to Curves" -underline 1 -accelerator "Command+B" -command "mainwin_convert_to_curves \[mainwin_current\]"
    $editmenu add command -label "Simplify Curves" -underline 0 -accelerator "Option+Command+B" -command "mainwin_simplify_curves \[mainwin_current\]"
    $editmenu add command -label "Smooth Curves" -underline 1 -accelerator "Shift+Command+B" -command "mainwin_smooth_curves \[mainwin_current\]"
    $editmenu add command -label "Join Curves" -underline 0 -accelerator "Command+J" -command "mainwin_join_curves \[mainwin_current\]"
    $editmenu add command -label "Vectorize Bitmap" -underline 0 -command "mainwin_vectorize_bitmaps \[mainwin_current\]"
    $editmenu add separator
    $editmenu add command -label "Union of Polygons" -underline 0 -accelerator "Option+Command+U" -command "mainwin_paths_union \[mainwin_current\]"
    $editmenu add command -label "Difference of Polygons" -underline 0 -accelerator "Control+Option+Command+D" -command "mainwin_paths_diff \[mainwin_current\]"
    $editmenu add command -label "Intersection of Polygons" -underline 0 -accelerator "Option+Command+I" -command "mainwin_paths_intersection \[mainwin_current\]"

    global mainmenuInfo
    set mainmenuInfo(view-show_origin) [/prefs:get show_origin]
    set mainmenuInfo(view-show_grid)   [/prefs:get show_grid]

    set viewmenu [menu $mb.view -tearoff 0]
    $viewmenu add command -label "Redraw" -underline 0 -accelerator "Command+R" -command "mainwin_redraw \[mainwin_current\]"
    $viewmenu add command -label "Actual Size" -underline 8 -accelerator "Command+0" -command "mainwin_canvas_zoom_actual \[mainwin_current\]"
    $viewmenu add command -label "Zoom to Fit" -underline 8 -command "mainwin_canvas_zoom_all \[mainwin_current\]"
    $viewmenu add command -label "Zoom In" -underline 5 -accelerator "Command+=" -command "mainwin_canvas_zoom \[mainwin_current\] 1"
    $viewmenu add command -label "Zoom Out" -underline 5 -accelerator "Command+-" -command "mainwin_canvas_zoom \[mainwin_current\] -1"
    $viewmenu add separator
    $viewmenu add checkbutton -label "Show Origin" -variable mainmenuInfo(view-show_origin) -command "/prefs:set show_origin \$mainmenuInfo(view-show_origin)"
    $viewmenu add checkbutton -label "Show Grid"   -variable mainmenuInfo(view-show_grid)   -command "/prefs:set show_grid   \$mainmenuInfo(view-show_grid)"
    $viewmenu add separator

    set cammenu [menu $mb.cam -tearoff 0]
    $cammenu add command -label "Configure Mill..." -underline 10 -command "mlgui_mill_create .mill"
    #$cammenu add command -label "Configure Stock..." -underline 10 -command "mlgui_stock_create .stock"
    #$cammenu add command -label "Configure Tools..." -underline 10 -command "mlgui_tool_create .tool"
    $cammenu add separator
    $cammenu add command -label "Speeds & Feeds Wizard" -underline 0 -command "feedwiz_create"
    $cammenu add separator
    $cammenu add command -label "Generate G-Code..." -underline 0 -command "mainwin_export_gcode \[mainwin_current\]"
    $cammenu add command -label "Backtrace G-Code..." -underline 0 -command "mainwin_backtrace_start \[mainwin_current\]"
    $cammenu add separator
    $cammenu add command -label "Make a Worm..." -underline 7 -command "mlcnc_g_worm_gui_create {}"
    $cammenu add command -label "Make a WormGear..." -underline 8 -command "mlcnc_g_worm_gear_gui_create {}"
    $cammenu add command -label "Make a Gear..." -underline 7 -command "mlcnc_g_gear_gui_create {}"

    set winmenu [menu $mb.window -tearoff 0 -postcommand "mainmenu_update_window_menu"]
    $winmenu add command -label "Minimize" -underline 0 -accelerator "Command+M" -command "wm iconify \[mainwin_current\]"
    $winmenu add command -label "Cycle Through Windows" -underline 0 -accelerator "Command+`" -command "mainwin_nextwin \[mainwin_current\]"
    $winmenu add separator
    mainmenu_update_window_menu $win

    $mb add cascade -label File -underline 0 -menu $filemenu
    $mb add cascade -label Edit -underline 0 -menu $editmenu
    $mb add cascade -label View -underline 0 -menu $viewmenu
    $mb add cascade -label CAM  -underline 0 -menu $cammenu
    $mb add cascade -label Window -underline 0 -menu $winmenu

    subwindows_menu_make_items $viewmenu
}

proc mainmenu_update_window_menu {{win ""}} {
    if {$win == ""} {
        set win [mainwin_current]
    }
    set winmenu $win.menubar.window
    while {[$winmenu type end] != "separator"} {
        $winmenu delete end
    }
    set tln 1
    foreach tl [mainwin_windows] {
        if {$tln < 10} {
            $winmenu add command -label [wm title $tl] -accelerator "Command+$tln" -command "raise $tl"
            bind all <Command-Key-$tln> "raise $tl ; break"
        } else {
            $winmenu add command -label [wm title $tl] -command "raise $tl"
        }
        incr tln
    }
    subwindows_menu_make_items $win.menubar.view
}



proc mainmenu_menu_invoke {w menustr} {
    set toplev [mainwin_current]
    if {$toplev == ""} {
        set toplev "."
    }
    set menw [$toplev cget -menu]
    if {$menw==""} {
        set menw $toplev.menubar
    }
    set menus [split $menustr "|"]
    set lev 0
    set mcount [llength $menus]
    foreach mentxt $menus {
        incr lev
        set idx ""
        catch {set idx [$menw index $mentxt]}
        if {$idx == "" || $idx == "none"} {
            error "Menu item not found: $menustr (1)"
        }
        if {[$menw type $idx] == "cascade"} {
            set menw [$menw entrycget $idx -menu]
        } else {
            if {$lev != $mcount} {
                error "Menu item not found: $menustr (2)"
            }
            set cmd [$menw entrycget $idx -command]
            if {$cmd != "" && [string first "%" $cmd] >= 0} {
                eval [string map [list %W $w] $cmd]
            } else {
                $menw invoke $idx
            }
            return
        }
    }
    error "Menu item not found: $menustr (3)"
}


proc mainmenu_copy {w {frommenu 0}} {
    switch -exact -- [string tolower [winfo class $w]] {
        text -
        entry -
        spinbox {
            if {$frommenu} {
                event generate $w <<Copy>>
            }
            return
        }
        default {
            mainwin_copy [mainwin_current]
        }
    }
}


proc mainmenu_cut {w {frommenu 0}} {
    switch -exact -- [string tolower [winfo class $w]] {
        text -
        entry -
        spinbox {
            if {$frommenu} {
                event generate $w <<Cut>>
            }
            return
        }
        default {
            mainwin_cut [mainwin_current]
        }
    }
}


proc mainmenu_paste {w {frommenu 0}} {
    switch -exact -- [string tolower [winfo class $w]] {
        text -
        entry -
        spinbox {
            if {$frommenu} {
                event generate $w <<Paste>>
            }
            return
        }
        default {
            mainwin_paste [mainwin_current]
        }
    }
}


proc mainmenu_clear {w {frommenu 0}} {
    switch -exact -- [string tolower [winfo class $w]] {
        text -
        entry -
        spinbox -
        tcombobox {
            if {$frommenu} {
                event generate $w <<Clear>>
            }
            return
        }
        default {
            puts stderr [winfo class $w]
            mainwin_clear [mainwin_current]
        }
    }
}


# vim: set ts=4 sw=4 nowrap expandtab: settings

