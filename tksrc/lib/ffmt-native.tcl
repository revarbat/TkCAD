proc ffmt_plugin_save_native {win canv filename} {
    return [ffmt_plugin_writefile_native $win $canv $filename]
}



proc ffmt_plugin_open_native {win canv filename} {
    return [ffmt_plugin_readfile_native $win $canv $filename]
}




proc ffmt_plugin_init_native {} {
    fileformat_register READWRITE NATIVE "tkCAD 1.0 Files" .tkcad
}

ffmt_plugin_init_native 




####################################################################
# Private functions follow below.
# These are NOT part of the FileFormat Plugin API.
####################################################################

proc ffmt_plugin_writeobj_native {win canv f objid {linepfx ""}} {
    set type   [cadobjects_object_gettype $canv $objid]
    set coords [cadobjects_object_get_coords $canv $objid]
    set important_datums [tool_get_important_fields $type]

    if {$type == "GROUP"} {
        set children [cadobjects_object_getdatum $canv $objid "CHILDREN"]
        if {[llength $children] > 0} {
            puts -nonewline $f $linepfx
            xmlutil_write_block_open $f "group"
            foreach child $children {
                ffmt_plugin_writeobj_native $win $canv $f $child "  $linepfx"
            }
            puts -nonewline $f $linepfx
            xmlutil_write_block_close $f "group"
        }
    } else {
        # TODO: translate to millimeters for metric saves?
        puts -nonewline $f $linepfx
        set cleancoords {}
        foreach coordx $coords {
            set coordx [format "%.5f" $coordx]
            set coordx [string trimright $coordx "0"]
            if {[string index $coordx end] == "."} {
                append coordx "0"
            }
            lappend cleancoords $coordx
        }
        set attrs [list type $type coords $cleancoords]
        foreach datname $important_datums {
            if {$datname == "GROUPS"} continue
            set datval [cadobjects_object_getdatum $canv $objid $datname]
            set datname [string tolower $datname]
            lappend attrs $datname $datval
        }
        xmlutil_write_element $f "cadobject" {*}$attrs
    }
}


proc ffmt_plugin_writefile_native {win canv filename} {
    set objcount [llength [cadobjects_object_ids $canv]]
    set objnum 0
    set f [open $filename "w"]
    progwin_create .native-progwin "TkCAD Save" "Saving file..."
    set material [cadobjects_get_material $canv]
    lassign [cadobjects_unit_system $canv] units fract mult abbrev
    if {$fract} {
        set fract "YES"
    } else {
        set fract "NO"
    }
    set units [string tolower [lindex $units 0]]
    xmlutil_write_block_open $f "tkcad" formatversion 1.1 units $units showfractions $fract material $material
    puts $f "<!-- Units attribute above is for remembering preferred display mode.  All units below are actually in inches. -->"
    foreach layer [layer_ids $canv] {
        progwin_callback .native-progwin $objcount $objnum
        incr objnum
        set layername [layer_name $canv $layer]
        set layercolor [layer_color $canv $layer]
        set layerbit [layer_cutbit $canv $layer]
        set layerdepth [layer_cutdepth $canv $layer]
        puts -nonewline $f "  "
        xmlutil_write_block_open $f "layer" name $layername color $layercolor cutbit $layerbit cutdepth $layerdepth
        foreach objid [layer_objects $canv $layer] {
            ffmt_plugin_writeobj_native $win $canv $f $objid "    "
        }
        puts -nonewline $f "  "
        xmlutil_write_block_close $f "layer"
    }
    xmlutil_write_block_close $f "tkcad"
    close $f
    progwin_destroy .native-progwin
}


proc ffmt_plugin_readfile_native {win canv filename} {
    set fileformat 0.0
    set currgroups {}
    set filesize [file size $filename]
    set f [open $filename "r"]
    progwin_create .native-progwin "TkCAD Open File" "Reading TkCAD file..."
    set cbcall "progwin_callback .native-progwin $filesize"
    while {1} {
        foreach {elem attributes} [xmlutil_read_element $f $cbcall] break
        if {$elem == "EOF"} {
            # We're done here.
            break
        } elseif {$elem == "ERROR"} {
            # Ignore element.  Try next.
            continue
        } elseif {$elem == "TEXT"} {
            # All text between elems is whitespace as far as we're concerned.
            continue
        }
        
        catch {unset attr}
        array set attr $attributes
        switch -exact -- $elem {
            "<tkcad>" {
                set formatversion 0.0
                catch {
                    set formatversion $attr(formatversion)
                }
                set units "inches"
                catch {
                    set units $attr(units)
                }
                set fracts "YES"
                catch {
                    set fracts $attr(showfractions)
                }
                cadobjects_set_unitsystem $canv $units $fracts
                set material "Aluminum"
                catch {
                    set material $attr(material)
                }
                cadobjects_set_material $canv $material
            }
            "<layer>" {
                set name ""
                catch {
                    set name $attr(name)
                }
                set lcolor "#000"
                set lcutbit ""
                set lcutdepth 0.0
                catch {
                    set lcolor $attr(color)
                }
                catch {
                    set lcutbit $attr(cutbit)
                }
                catch {
                    set lcutdepth $attr(cutdepth)
                }

                set layerid [layer_name_id $canv $name]
                if {$layerid == ""} {
                    set layerid [layer_create $canv $name]
                }
                layer_set_color $canv $layerid $lcolor
                if {$lcutbit != ""} {
                    layer_set_cutbit $canv $layerid $lcutbit
                }
                layer_set_cutdepth $canv $layerid $lcutdepth
                layer_set_current $canv $layerid
            }
            "<group>" {
                lappend currgroups [cadobjects_object_create $canv GROUP {} {}]
            }
            "<cadobject>" -
            "<cadobject/>" {
                set type ""
                catch {
                    set type [string toupper $attr(type)]
                    unset attr(type)
                }
                set coords ""
                catch {
                    set coords $attr(coords)
                    unset attr(coords)
                }
                set parms {}
                foreach {key val} [array get attr] {
                    lappend parms [string toupper $key]
                    lappend parms $val
                }
                set newobj [cadobjects_object_create $canv $type $coords $parms]
                if {$currgroups != {}} {
                    set group [lindex $currgroups end]
                    cadobjects_object_group_addobj $canv $group $newobj
                }
                cadobjects_object_recalculate $canv $newobj
            }
            "</group>" {
                set group [lindex $currgroups end]
                set currgroups [lrange $currgroups 0 end-1]
                if {$currgroups != {}} {
                    set parent [lindex $currgroups end]
                    cadobjects_object_group_addobj $canv $parent $group
                }
            }
            "</layer>" -
            "</tkcad>" {
                continue
            }
        }
    }
    close $f

    #cutpaste_canvas_init $canv
    #mainwin_redraw $win
    #mainwin_canvas_zoom_all $win
    progwin_destroy .native-progwin
}


# vim: set ts=4 sw=4 nowrap expandtab: settings

