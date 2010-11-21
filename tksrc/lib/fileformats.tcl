proc fileformat_init {} {
    global fileformatInfo
    set fileformatInfo(FFMTNUM) 0
    set fileformatInfo(FFMTS) {}
}

fileformat_init 


proc fileformat_register {modes token name extension} {
    global fileformatInfo
    set canread 0
    set canwrite 0
    if {[string first "READ" [string toupper $modes]] != -1} {
        set canread 1
    }
    if {[string first "WRITE" [string toupper $modes]] != -1} {
        set canwrite 1
    }
    set ffid [incr fileformatInfo(FFMTNUM)]
    set fileformatInfo(FFMT-$ffid-NAME) $name
    set fileformatInfo(FFMT-$ffid-TOKEN) $token
    set fileformatInfo(FFMT-$ffid-EXTENSION) $extension
    set fileformatInfo(FFMT-$ffid-CANREAD) $canread
    set fileformatInfo(FFMT-$ffid-CANWRITE) $canwrite
    set fileformatInfo(FFMT_ID-$token) $ffid
    lappend fileformatInfo(FFMT_EXT-$extension) $ffid
    lappend fileformatInfo(FFMTS) $ffid
}


proc fileformat_list {} {
    global fileformatInfo
    return $fileformatInfo(FFMTS)
}


proc fileformat_name {ffid} {
    global fileformatInfo
    return $fileformatInfo(FFMT-$ffid-NAME)
}


proc fileformat_token {ffid} {
    global fileformatInfo
    return $fileformatInfo(FFMT-$ffid-TOKEN)
}


proc fileformat_extension {ffid} {
    global fileformatInfo
    return $fileformatInfo(FFMT-$ffid-EXTENSION)
}


proc fileformat_can_read {ffid} {
    global fileformatInfo
    return $fileformatInfo(FFMT-$ffid-CANREAD)
}


proc fileformat_can_write {ffid} {
    global fileformatInfo
    return $fileformatInfo(FFMT-$ffid-CANWRITE)
}


proc fileformat_id_from_token {token} {
    global fileformatInfo
    if {![info exists fileformatInfo(FFMT_ID-$token)]} {
        return -1
    }
    return $fileformatInfo(FFMT_ID-$token)
}


proc fileformat_ids_from_extension {ext} {
    global fileformatInfo
    if {![info exists fileformatInfo(FFMT_EXT-$ext)]} {
        return {}
    }
    return $fileformatInfo(FFMT_EXT-$ext)
}


proc fileformat_get_read_filetypes {} {
    set exts {}
    foreach ffid [fileformat_list] {
        set name [fileformat_name $ffid]
        set ext  [fileformat_extension $ffid]
        if {[fileformat_can_read $ffid]} {
            lappend exts $ext
        }
    }
    return [list [list "Vector Graphics Files" $exts]]
}


proc fileformat_get_written_filetypes {} {
    set out {}
    foreach ffid [fileformat_list] {
        set name [fileformat_name $ffid]
        set ext  [fileformat_extension $ffid]
        if {[fileformat_can_write $ffid]} {
            lappend out [list $name $ext]
        }
    }
    return $out
}


proc fileformat_set_filename {win filename} {
    global fileformatInfo
    set fileformatInfo(FILENAME-$win) $filename
    wm title $win [file tail $filename]
}


proc fileformat_get_filename {win} {
    global fileformatInfo
    if {![info exists fileformatInfo(FILENAME-$win)]} {
        set fileformatInfo(FILENAME-$win) ""
    }
    return $fileformatInfo(FILENAME-$win)
}


proc fileformat_remember_file {filename} {
    set recent [/prefs:get recent_files]
    set pos [lsearch -exact $recent $filename]
    if {$pos >= 0} {
        set recent [lreplace $recent $pos $pos]
    }
    set recent [linsert $recent 0 $filename]
    set recent [lrange $recent 0 14]
    /prefs:set recent_files $recent
}


proc fileformat_save {win canv} {
    set filename [fileformat_get_filename $win]
    if {$filename == ""} {
        return [fileformat_saveas $win $canv]
    }

    set defffid [fileformat_id_from_token NATIVE]
    set nativeext [fileformat_extension $defffid]

    set ext [file extension $filename]
    set ffids [fileformat_ids_from_extension $ext]
    if {$ffids == ""} {
        # If no valid extension given, default to native format
        set ext $nativeext
        append filename $ext
        set ffids [fileformat_ids_from_extension $ext]
    }
    set ffid -1
    foreach ffmtid $ffids {
        if {[fileformat_can_write $ffmtid]} {
            set ffid $ffmtid
        }
    }
    if {$ffid == -1} {
        # We can't write this format!
        tk_messageBox -parent $win -type ok -icon error -message "tkCAD does not have support to write out to that file format."
        return ""
    }

    set token [fileformat_token $ffid]
    set cmdname "ffmt_plugin_save_"
    append cmdname [string tolower $token]
    if {[info commands $cmdname] != {}} {
        eval [list $cmdname $win $canv $filename]
    }
    fileformat_remember_file $filename
}


proc fileformat_saveas {win canv} {
    set defffid [fileformat_id_from_token NATIVE]
    set nativeext [fileformat_extension $defffid]
    set filetypes [fileformat_get_written_filetypes]
    set winsys ""
    catch {set winsys [tk windowingsystem]}
    if {$winsys == "aqua"} {
        set filename [tk_getSaveFile \
            -title "Save File As..." \
            -message "Save File As..." \
            -parent $win \
            -filetypes $filetypes \
            -defaultextension $nativeext \
            ]
    } else {
        set filename [tk_getSaveFile \
            -title "Save File As..." \
            -parent $win \
            -filetypes $filetypes \
            -defaultextension $nativeext \
            ]
    }
    if {$filename == ""} {
        return ""
    }
    set ext [file extension $filename]
    set ffids [fileformat_ids_from_extension $ext]
    if {$ffids == ""} {
        # If no valid extension given, default to native format
        set ext $nativeext
        append filename $ext
        set ffids [fileformat_ids_from_extension $ext]
    }
    set ffid -1
    foreach ffmtid $ffids {
        if {[fileformat_can_write $ffmtid]} {
            set ffid $ffmtid
        }
    }
    if {$ffid == -1} {
        # We can't write this format!
        tk_messageBox -parent $win -type ok -icon error -message "tkCAD does not have support to write out to that file format."
        return ""
    }

    set token [fileformat_token $ffid]
    if {$token != "NATIVE"} {
        tk_messageBox -parent $win -type ok -icon warning -message "Saving to a file format other than the .tkcad native file format may result in some loss of object information.  Some objects may be decomposed into more generic lines and arcs in the saved file."
    } else {
        fileformat_set_filename $win $filename
    }

    set cmdname "ffmt_plugin_save_"
    append cmdname [string tolower $token]
    if {[info commands $cmdname] != {}} {
        eval [list $cmdname $win $canv $filename]
    }
    fileformat_remember_file $filename
}


proc fileformat_export {win canv} {
    global fileformatInfo

    set defffid [fileformat_id_from_token NATIVE]
    set nativeext [fileformat_extension $defffid]
    set writetypes [fileformat_get_written_filetypes]
    set winsys ""
    catch {set winsys [tk windowingsystem]}

    set base [toplevel .exportfile -padx 20 -pady 20]
    wm title $base "Export File"

    foreach ftinfo $writetypes {
        lassign $ftinfo name ext
        if {$ext == $nativeext} continue
        set fexts($name) $ext
        lappend ftypes $name
    }
    set ftypel [label $base.ftypel -text "Export format:"]
    set fileformatInfo(EXPDLG_TYPE) [lindex $ftypes 0]
    set ftypemb $base.ftypemb
    tk_optionMenu $ftypemb fileformatInfo(EXPDLG_TYPE) {*}$ftypes
    $ftypemb configure -width 20

    set miscfr [frame $base.miscfr]

    set fileformatInfo(EXPDLG_RES) 0
    set btns [frame $base.btns]
    button $btns.export -text Export -default active -command "set fileformatInfo(EXPDLG_RES) 1 ; destroy $base"
    button $btns.cancel -text Cancel -command "destroy $base"
    pack $btns.cancel -side right
    pack $btns.export -side right -padx 10

    grid columnconfigure $base 1 -minsize 5
    grid columnconfigure $base 2 -weight 1
    grid $ftypel   x $ftypemb   -sticky w
    grid $miscfr   - -          -sticky nsew
    grid $btns     - -          -sticky ew -pady {20 0}

    bind $base <Key-Escape> "$btns.cancel invoke ; break"
    bind $base <Key-Return> "$btns.export invoke ; break"

    # TODO: Populate miscfr frame with ffmt specific widgets as ftypemb changes.

    grab set $base
    tkwait window $base
    grab release $base

    if {!$fileformatInfo(EXPDLG_RES)} {
        return
    }

    # TODO: Umm, get misc data from ffmt specific widgets.
    set ftype $fileformatInfo(EXPDLG_TYPE)
    set fext $fexts($ftype)
    set filetypes [list [list $ftype $fext]]

    if {$winsys == "aqua"} {
        set filename [tk_getSaveFile \
            -title "Save File As..." \
            -message "Save File As $ftype..." \
            -parent $win \
            -filetypes $filetypes \
            -defaultextension $fext \
            ]
    } else {
        set filename [tk_getSaveFile \
            -title "Save File As..." \
            -parent $win \
            -filetypes $filetypes \
            -defaultextension $fext \
            ]
    }
    if {$filename == ""} {
        return ""
    }
    if {![string match -nocase "*$fext" $filename]} {
        # If no valid extension given, default to native format
        append filename $fext
    }
    set ffids [fileformat_ids_from_extension $fext]
    foreach ffmtid $ffids {
        if {[fileformat_name $ffmtid] == $ftype} {
            set ffid $ffmtid
        }
    }

    set token [fileformat_token $ffid]
    if {$token != "NATIVE"} {
        tk_messageBox -parent $win -type ok -icon warning -message "Saving to a file format other than the .tkcad native file format may result in some loss of object information.  Some objects may be decomposed into more generic lines and arcs in the saved file."
    } else {
        fileformat_set_filename $win $filename
    }

    set cmdname "ffmt_plugin_save_"
    append cmdname [string tolower $token]
    if {[info commands $cmdname] != {}} {
        eval [list $cmdname $win $canv $filename]
    }
    #fileformat_remember_file $filename
}


proc fileformat_open {win {import 0}} {
    set defffid [fileformat_id_from_token NATIVE]
    set nativeext [fileformat_extension $defffid]
    set filetypes [fileformat_get_read_filetypes]
    set pararg ""
    if {$win != "."} {
        set pararg "-parent $win"
    }
    set filename [tk_getOpenFile \
        -title "Open File..." \
        {*}$pararg \
        -filetypes $filetypes \
        -defaultextension $nativeext \
        ]
    if {$filename == ""} {
        return ""
    }
    return [fileformat_openfile $win $filename $import]
}


proc fileformat_openfile {win filename {import 0}} {
    if {![file exists $filename]} {
        tk_messageBox -type ok -icon error -message "The file \"[file tail $filename]\" does not exist!"
        return ""
    }
    if {![file readable $filename]} {
        tk_messageBox -type ok -icon error -message "The file \"[file tail $filename]\" is not readable!"
        return ""
    }
    set ext [string tolower [file extension $filename]]
    set ffids [fileformat_ids_from_extension $ext]
    if {$ffids == ""} {
        # TODO: warn that I don't know that filetype.
        return ""
    }
    set ffid -1
    foreach ffmtid $ffids {
        if {[fileformat_can_write $ffmtid]} {
            set ffid $ffmtid
        }
    }
    if {$ffid == -1} {
        # TODO: warn that I don't know how to read that filetype.
        return ""
    }

    fileformat_remember_file $filename

    set canv ""
    if {$win != "." } {
        set canv [mainwin_get_canvas $win]
    }
    if {$win != "." && ($import || [llength [cadobjects_object_ids $canv]] == 0)} {
        set newwin $win
    } else {
        set newwin [mainwin_create]
    }
    set newcanv [mainwin_get_canvas $newwin]
    if {!$import} {
        foreach layerid [layer_ids $newcanv] {
            layer_delete $newcanv $layerid
        }
        mainwin_update_layerwin $newwin
    }
    set token [fileformat_token $ffid]
    set cmdname "ffmt_plugin_open_"
    append cmdname [string tolower $token]
    if {[info commands $cmdname] != {}} {
        eval [list $cmdname $newwin $newcanv $filename]
    }
    fileformat_set_filename $newwin $filename
    if {!$import} {
        cutpaste_canvas_init $canv
        mainwin_canvas_zoom_all $newwin
    }
    cadobjects_redraw $newcanv
    return $newwin
}


# vim: set ts=4 sw=4 nowrap expandtab: settings

