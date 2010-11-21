proc xmlutil_expand_value {val} {
    return [string map -nocase {
        "&quot;" "\""
        "&apos;" "\'"
        "&gt;"   "<"
        "&lt;"   ">"
        "&amp;"  "&"
        } $val]
}


proc xmlutil_escape_value {val} {
    return [string map -nocase {
        "\"" "&quot;"
        "\'" "&apos;"
        "<"  "&gt;"
        ">"  "&lt;"
        "&"  "&amp;"
        } $val]
}


proc xmlutil_write_element {f elemname args} {
    set out "<"
    append out [xmlutil_escape_value $elemname]
    foreach {key val} $args {
        if {$val != ""} {
            append out " "
            append out [xmlutil_escape_value $key]
            append out "=\""
            append out [xmlutil_escape_value $val]
            append out "\""
        }
    }
    append out " />"
    puts $f $out
}


proc xmlutil_write_block_open {f elemname args} {
    set out "<"
    append out [xmlutil_escape_value $elemname]
    foreach {key val} $args {
        if {$val != ""} {
            append out " "
            append out [xmlutil_escape_value $key]
            append out "=\""
            append out [xmlutil_escape_value $val]
            append out "\""
        }
    }
    append out ">"
    puts $f $out
}


proc xmlutil_write_block_close {f elemname} {
    set out "</"
    append out [xmlutil_escape_value $elemname]
    append out ">"
    puts $f $out
}


proc xmlutil_read_element {f {progcb ""}} {
    set readsize 1024
    upvar #0 xmlutil_read_buffer readbuf
    if {![info exists readbuf]} {
        set readbuf ""
    }
    while {1} {
        set pos [string first "<" $readbuf]
        set rblen [string length $readbuf]
        while {![eof $f] && $pos == -1} {
            set tmpbuf [read $f $readsize]
            set currbytes [tell $f]
            if {$progcb != ""} {
                eval $progcb $currbytes
            }
            append readbuf $tmpbuf
            set pos [string first "<" $readbuf [expr {$rblen-1}]]
            incr rblen [string length $tmpbuf]
        }
        if {$pos == -1} {
            # Text at end of file
            if {$readbuf == ""} {
                set retval {EOF ""}
            } else {
                set retval [list TEXT [xmlutil_expand_value $readbuf]]
                set readbuf {}
            }
            return $retval
        } elseif {$pos > 0} {
            # Text before next <elem>
            set val [string range $readbuf 0 [expr {$pos-1}]]
            set readbuf [string trimleft [string range $readbuf $pos end]]
            set retval [list TEXT [xmlutil_expand_value $val]]
            return $retval
        }
        # First char is '<', so this is an element or a comment.
        if {[string range $readbuf 0 4] == "<?xml"} {
            # We're in the xml header!  Skip everything until "?>"
            set readbuf [string range $readbuf 5 end]
            set pos [string first "?>" $readbuf]
            set rblen [string length $readbuf]
            while {![eof $f] && $pos == -1} {
                set tmpbuf [read $f $readsize]
                set currbytes [tell $f]
                if {$progcb != ""} {
                    eval $progcb $currbytes
                }
                append readbuf $tmpbuf
                set pos [string first "?>" $readbuf $rblen]
                incr rblen [string length $tmpbuf]
            }
            if {$pos == -1} {
                # Reached end of file inside a comment.  Return an error.
                set retval {ERROR "Unterminated XML header at end of file."}
                return $retval
            }
            set readbuf [string range $readbuf [incr pos 2] end]
        } elseif {[string range $readbuf 0 3] == "<!--"} {
            # We're in a comment!  Skip everything until "-->"
            set readbuf [string range $readbuf 4 end]
            set pos [string first "-->" $readbuf]
            set rblen [string length $readbuf]
            while {![eof $f] && $pos == -1} {
                set tmpbuf [read $f $readsize]
                set currbytes [tell $f]
                if {$progcb != ""} {
                    eval $progcb $currbytes
                }
                append readbuf $tmpbuf
                set pos [string first "-->" $readbuf $rblen]
                incr rblen [string length $tmpbuf]
            }
            if {$pos == -1} {
                # Reached end of file inside a comment.  Return an error.
                set retval {ERROR "Unterminated comment at end of file."}
                return $retval
            }
            set readbuf [string range $readbuf [incr pos 3] end]
        } else {
            break
        }
        # Loop until done with TEXT and comments
    }

    # First char is '<', so this is an element.
    # TODO: Technically, '>' inside a quoted attr value is allowed.
    # We should parse this better.
    set pos [string first ">" $readbuf]
    set rblen [string length $readbuf]
    while {![eof $f] && $pos == -1} {
        set tmpbuf [read $f $readsize]
        set currbytes [tell $f]
        if {$progcb != ""} {
            eval $progcb $currbytes
        }
        append readbuf $tmpbuf
        set pos [string first ">" $readbuf [expr {$rblen-1}]]
        incr rblen [string length $tmpbuf]
    }
    if {$pos == -1} {
        # Reached end of file inside an element.  Return an error.
        set retval {ERROR "Unterminated element at end of file."}
        return $retval
    }
    # Element string should be fully read now.
    set elem [string range $readbuf 0 $pos]
    set readbuf [string trimleft [string range $readbuf [expr {$pos+1}] end]]
    if {![regexp -nocase {^<(/?[a-z_][a-z0-9_:-]*)[[:space:]]*([^>]*>)$} $elem dummy tagname elem]} {
        set retval {ERROR "Malformed tag."}
        return $retval
    }
    set attrs {}
    while {$elem != ">" && $elem != "/>"} {
        # Get next attribute
        if {![regexp -nocase "^\[\[:space:\]\]*(\[a-z_\]\[a-z0-9_:-\]*)=\['\"\](\[^'\"\]*)\['\"\]\[\[:space:\]\]*(\[^>\]*>)\$" $elem dummy attrname attrval nuelem]} {
            if {![regexp -nocase "^\[\[:space:\]\]*(\[a-z_\]\[a-z0-9_:-\]*)=(\[^ \]*)\[\[:space:\]\]*(\[^>\]*>)\$" $elem dummy attrname attrval nuelem]} {
                if {![regexp -nocase "^\[\[:space:\]\]*(\[a-z_\]\[a-z0-9_:-\]*)(\[\[:space:\]\]\[\[:space:\]\]*\[^>\]*>|>)\$" $elem dummy attrname nuelem]} {
                    set retval {ERROR "Malformed attribute."}
                    return $retval
                } else {
                    set attrval $attrname
                }
            }
        }
        set elem $nuelem
        lappend attrs [xmlutil_expand_value $attrname]
        lappend attrs [xmlutil_expand_value $attrval]
    }
    set tagname [string tolower $tagname]
    if {[string index $elem 0] == "/"} {
        append tagname "/"
    }
    set retval [list "<$tagname>" $attrs]
    return $retval
}


# vim: set ts=4 sw=4 nowrap expandtab: settings

