# Misc gui-related routines.


proc mlgui_optionmenu_value_get {wname} {
    global mlguiMiscInfo

    return $mlguiMiscInfo(WIDGETVAL-$wname)
}


proc mlgui_optionmenu_value_set {wname value} {
    global mlguiMiscInfo

    set mlguiMiscInfo(WIDGETVAL-$wname) $value
    mlgui_optionmenu_update $wname

    return $value
}


proc mlgui_optionmenu_update {wname} {
    global mlguiMiscInfo

    set value [mlgui_optionmenu_value_get $wname]
    set txt $mlguiMiscInfo(WIDGETOPTION-$wname-$value)
    $wname configure -text $txt
}


proc mlgui_optionmenu_destroy {wname} {
    global mlguiMiscInfo

    unset mlguiMiscInfo(WIDGETVAL-$wname)
    foreach key [array names mlguiMiscInfo "WIDGETOPTION-$wname-*"] {
	unset mlguiMiscInfo($key)
    }
}


proc mlgui_optionmenu {wname value options} {
    global mlguiMiscInfo

    set var mlguiMiscInfo(WIDGETVAL-$wname)
    set $var $value
    set typemenu $wname.menu
    menubutton $wname \
        -menu $typemenu -indicatoron 1 -relief raised \
        -direction flush -takefocus 1
    bind $wname <Destroy> [list mlgui_optionmenu_destroy $wname]
    menu $typemenu -tearoff false
    foreach item $options {
	set val [lindex $item 0]
	set txt [lindex $item 1]
	if {$txt == ""} {
	    set txt $val
	}
	set mlguiMiscInfo(WIDGETOPTION-$wname-$val) $txt
	$typemenu add radiobutton -label $txt -value $val -variable $var \
	    -command [list mlgui_optionmenu_update $wname]
    }
    mlgui_optionmenu_update $wname
    return $wname
}


# sw_label    win name -label
# sw_button   win name -label -command

# sw_boolean  win name -label -value
# sw_integer  win name -label -value -min -max
# sw_float    win name -label -value -min -max
# sw_string   win name -label -value -maxlen
# sw_combobox win name -label -value -maxlen -options
# sw_text     win name -label -value
# sw_option   win name -label -value -options
# sw_listbox  win name -label -value -options
# sw_slider   win name -label -value -min -max
# sw_radio    win name -label -value { value label ... }
# sw_group    win name -label { ... }
# sw_notebook win name { ... }
