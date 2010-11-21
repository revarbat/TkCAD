global mlcncMillInfo
set mlcncMillInfo(RPM_DISCRETE)      0
set mlcncMillInfo(RPM_MIN)           0
set mlcncMillInfo(RPM_MAX)           0
set mlcncMillInfo(RPM_LIST)          {}
set mlcncMillInfo(RPM_FIXED)         0
set mlcncMillInfo(MILL_HP)           0.2
set mlcncMillInfo(FEED_MAX)         15.0
set mlcncMillInfo(AUTO_TOOL_CHANGER) 1
set mlcncMillInfo(SCALE)             1.0


tcl::OptProc mlcnc_define_mill {
    {-discretespeeds 0    "Notes that the mill cannot set arbitrary speeds."}
    {-minrpm         0    "The minimum rpm the mill spindle can spin at."}
    {-maxrpm         0    "The maximum rpm the mill spindle can spin at."}
    {-rpmlist       {}    "List of discrete RPMs the spindle can run at."}
    {-fixedrpm       0    "Specifies that RPM can't be changed while running."}
    {-hp           0.2    "Specifies spindle motor's horsepower."}
    {-maxfeed     15.0    "Specifies mill's maximum feed rate."}
    {-autotoolchanger 1   "Specifies the mill has an automatic tool changer."}
} {
    global mlcncMillInfo
    set mlcncMillInfo(RPM_DISCRETE) $discretespeeds
    set mlcncMillInfo(RPM_MIN) $minrpm
    set mlcncMillInfo(RPM_MAX) $maxrpm
    set mlcncMillInfo(RPM_LIST) $rpmlist
    set mlcncMillInfo(RPM_FIXED) $fixedrpm
    set mlcncMillInfo(MILL_HP) $hp
    set mlcncMillInfo(FEED_MAX) $maxfeed
    set mlcncMillInfo(AUTO_TOOL_CHANGER) $autotoolchanger
}


proc mlcnc_mill_get_scale {} {
    global mlcncMillInfo
    return $mlcncMillInfo(SCALE)
}


proc mlcnc_mill_set_scale {val} {
    global mlcncMillInfo
    set mlcncMillInfo(SCALE) $val
}


proc mlval {val} {
    global mlcncMillInfo
    return [expr {$val*$mlcncMillInfo(SCALE)}]
}


proc mlcnc_mill_speeds_are_discrete {} {
    global mlcncMillInfo
    return $mlcncMillInfo(RPM_DISCRETE)
}


proc mlcnc_mill_rpm_min {} {
    global mlcncMillInfo
    return $mlcncMillInfo(RPM_MIN)
}


proc mlcnc_mill_rpm_max {} {
    global mlcncMillInfo
    return $mlcncMillInfo(RPM_MAX)
}


proc mlcnc_mill_rpm_list {} {
    global mlcncMillInfo
    return $mlcncMillInfo(RPM_LIST)
}


proc mlcnc_mill_rpm_is_fixed {} {
    global mlcncMillInfo
    return $mlcncMillInfo(RPM_FIXED)
}


proc mlcnc_mill_hp {} {
    global mlcncMillInfo
    return $mlcncMillInfo(MILL_HP)
}


proc mlcnc_mill_feed_max {} {
    global mlcncMillInfo
    return $mlcncMillInfo(FEED_MAX)
}


proc mlcnc_mill_has_auto_tool_changer {} {
    global mlcncMillInfo
    return $mlcncMillInfo(AUTO_TOOL_CHANGER)
}



# vim: set ts=4 sw=4 nowrap expandtab: settings

