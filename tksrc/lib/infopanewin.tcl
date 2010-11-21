proc infopanewin_init {} {
    global infopanewinInfo
}


proc infopanewin_create {base} {
    global infopanewinInfo
    toplevel $base
    set info [frame $base.info]
    set conf [frame $base.conf]
    label $info.xpos_l -text "X:" -font {Courier 11} -foreground red3  
    label $info.xpos   -text ""   -font {Courier 11} -foreground red3  
    label $info.ypos_l -text "Y:" -font {Courier 11} -foreground green4
    label $info.ypos   -text ""   -font {Courier 11} -foreground green4
    label $info.wid_l  -text "W:" -font {Courier 11}
    label $info.wid    -text ""   -font {Courier 11}
    label $info.hgt_l  -text "H:" -font {Courier 11}
    label $info.hgt    -text ""   -font {Courier 11}
    label $info.act_l  -text ""   -font {Courier 11}
    grid columnconfigure $info 0 -minsize 5
    grid columnconfigure $info 2 -minsize 0
    grid columnconfigure $info 4 -minsize 5
    grid rowconfigure $info 4 -weight 10
    grid x $info.xpos_l x $info.xpos x -sticky ne
    grid x $info.ypos_l x $info.ypos x -sticky ne
    grid x $info.wid_l  x $info.wid  x -sticky ne
    grid x $info.hgt_l  x $info.hgt  x -sticky ne
    grid x $info.act_l  - -          x -sticky sw

    pack $info -side left -anchor nw -expand 0 -fill y
    pack $conf -side left -anchor nw -expand 1 -fill both
    return $base
}


proc infopanewin_get_info_pane {base} {
    return $base.conf
}


proc infopanewin_get_conf_pane {base} {
    return $base.conf
}


proc infopane_update_mousepos {base realx realy unit} {
    $base.info.xpos configure -text [format "%7.4f %s" $realx $unit]
    $base.info.ypos configure -text [format "%7.4f %s" $realy $unit]
}


proc infopane_clear_widthheight {base} {
    $base.info.wid configure -text {}
    $base.info.hgt configure -text {}
}


proc infopane_update_widthheight {base realx realy unit} {
    $base.info.wid configure -text [format "%7.4f%s" $realx $unit]
    $base.info.hgt configure -text [format "%7.4f%s" $realy $unit]
}


proc infopane_update_actionstr {base str} {
    $base.info.act_l configure -text "$str"
}


infopanewin_init


# vim: set ts=4 sw=4 nowrap expandtab: settings


