set ffams [list Times Helvetica Courier Zapfino]

lappend auto_path [file join [pwd] lib]
package require fontdata
package require tkpath

set ::tkpath::antialias 1

canvas .c -width 800 -height 800
pack .c -expand 1 -fill both
.c create rectangle 0 0 1000 100
set path [list M 0 0 L 1 0 L 1 1 L 0 1 z]
set item [.c create path $path -fill "" -strokewidth 0.5]

foreach ffam $ffams {
    set font [list $ffam 100]

    set ascent [font metrics $font -ascent]
    set descent [font metrics $font -descent]
    set lineh [font metrics $font -linespace]

    catch {
	set path [GetFontCurves . $font $ffam]

	.c coords $item $path
	.c move $item 10 $ascent
	.c move $item 0.5 0.5
	set sc [expr {100.0/$ascent}]
	.c scale $item 0 0 $sc $sc
	update
	after 1000
    }
}


