proc editpanewin_init {} {
    global editpanewinInfo
}


proc editpanewin_create {base} {
    global editpanewinInfo
    toplevel $base
    set nb [::ttk::notebook $base.nb -padding 0]
    set conf [frame $nb.conf -height 150]
    set cam [frame $nb.cam -height 150]
    $nb add $conf -text Stroke -sticky nsew -padding 0
    $nb add $cam -text CAM -sticky nsew -padding 0
    pack $nb -side left -anchor nw -expand 1 -fill both
    return $base
}


proc editpanewin_get_conf_pane {base} {
    return $base.nb.conf
}


proc editpanewin_get_cam_pane {base} {
    return $base.nb.cam
}


editpanewin_init


# vim: set ts=4 sw=4 nowrap expandtab: settings

