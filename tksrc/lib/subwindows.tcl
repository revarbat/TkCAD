
proc subwindows_init {} {
    global subwindowsInfo
    set subwindowsInfo(WINTYPES) {}
}


proc subwindows_register {win subwin type defvis {style {}}} {
    global subwindowsInfo
    if {$type ni $subwindowsInfo(WINTYPES)} {
        lappend subwindowsInfo(WINTYPES) $type
        set subwindowsInfo(WINVIS-$type) $defvis
    }
    lappend subwindowsInfo(SUBWINS-$win) $subwin
    lappend subwindowsInfo(SUBWINTS-$type) $subwin
    set subwindowsInfo(SUBWINTYPE-$win-$subwin) $type
    set subwindowsInfo(SUBWIN-$win-$type) $subwin

    set style [string tolower $style]

    if {[info commands ::tk::unsupported::MacWindowStyle] != ""} {
        set class "floating"
        set attrs {}
        #lappend attrs "noActivates"
        lappend attrs "hideOnSuspend"
        lappend attrs "closeBox"
        lappend attrs "noShadow"
        if {[string first "side" $style] != -1} {
            lappend attrs "sideTitlebar"
        }
        if {[string first "zoom" $style] != -1} {
            lappend attrs "horizontalZoom"
            lappend attrs "verticalZoom"
        }
        if {[string first "grow" $style] != -1} {
            lappend attrs "resizable"
        }
        if {[catch {::tk::unsupported::MacWindowStyle style $subwin $class $attrs} err]} {
            puts stderr "$err"
        }
    }

    wm title $subwin $type
    if {$win != ""} {
        #wm transient $subwin $win
        wm group $subwin $win
    }
    wm protocol $subwin WM_DELETE_WINDOW [list subwindows_hide_type $type]

    if {[string first "grow" $style] != -1} {
        wm resizable $subwin 1 1
    } else {
        wm resizable $subwin 0 0
    }

    catch {wm attributes $subwin -toolwindow 1}
    if {[string first "zoom" $style] != -1} {
        catch {wm attributes $subwin -maximizebox 1}
        catch {wm attributes $subwin -minimizebox 1}
    } else {
        catch {wm attributes $subwin -maximizebox 0}
        catch {wm attributes $subwin -minimizebox 0}
    }
}


proc subwindows_menu_make_items {menw} {
    global subwindowsInfo
    while {[$menw type end] != "separator"} {
        $menw delete end
    }
    foreach type $subwindowsInfo(WINTYPES) {
        $menw add checkbutton -label $type \
            -variable subwindowsInfo(WINVIS-$type) \
            -command [list subwindows_toggle_type $type]
    }
}


proc subwindows_hide_type {type} {
    global subwindowsInfo
    set subwindowsInfo(WINVIS-$type) 0
    subwindows_toggle_type $type
}


proc subwindows_toggle_type {type} {
    global subwindowsInfo

    set wins $subwindowsInfo(SUBWINTS-$type)
    foreach win $wins {
        if {$subwindowsInfo(WINVIS-$type)} {
            wm deiconify $win
        } else {
            wm withdraw $win
        }
    }
    set wins ""
    lappend wins [mainwin_current]
    foreach win $wins {
        if {[info exists subwindowsInfo(SUBWIN-$win-$type)]} {
            if {$subwindowsInfo(WINVIS-$type)} {
                wm deiconify $subwindowsInfo(SUBWIN-$win-$type)
                raise $subwindowsInfo(SUBWIN-$win-$type)
            } else {
                wm withdraw  $subwindowsInfo(SUBWIN-$win-$type)
            }
        }
    }
}


proc subwindows_activate {win} {
    global subwindowsInfo
    foreach type $subwindowsInfo(WINTYPES) {
        if {$subwindowsInfo(WINVIS-$type)} {
            if {[info exists subwindowsInfo(SUBWIN-$win-$type)]} {
                after  5 wm deiconify $subwindowsInfo(SUBWIN-$win-$type)
                after 10 raise $subwindowsInfo(SUBWIN-$win-$type)
            }
        }
    }
}


proc subwindows_list {win} {
    global subwindowsInfo
    if {![info exists subwindowsInfo(SUBWINS-$win)]} {
        return {}
    }
    return $subwindowsInfo(SUBWINS-$win)
}


proc subwindows_deactivate {win} {
    global subwindowsInfo
    foreach subwin $subwindowsInfo(SUBWINS-$win) {
        wm withdraw $subwin
    }
}


subwindows_init


# vim: set ts=4 sw=4 nowrap expandtab: settings

