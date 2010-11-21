proc plugin_alignleft_execute {canv coords isconf} {
    $canv delete Preview
    foreach {x0 y0} $coords break
    set objids [cadobjects_topmost_objects $canv "SELECTED"]
    cadobjects_object_align_left $canv $objids $x0
}





proc plugin_alignhcenter_execute {canv coords isconf} {
    $canv delete Preview
    foreach {x0 y0} $coords break
    set objids [cadobjects_topmost_objects $canv "SELECTED"]
    cadobjects_object_align_hcenter $canv $objids $x0
}





proc plugin_alignhcenter2_execute {canv coords isconf} {
    $canv delete Preview
    foreach {x0 y0 x1 y1} $coords break
    set objids [cadobjects_topmost_objects $canv "SELECTED"]
    set xpos [expr {($x0+$x1)/2.0}]
    cadobjects_object_align_hcenter $canv $objids $xpos
}





proc plugin_alignright_execute {canv coords isconf} {
    $canv delete Preview
    foreach {x0 y0} $coords break
    set objids [cadobjects_topmost_objects $canv "SELECTED"]
    cadobjects_object_align_right $canv $objids $x0
}





proc plugin_aligntop_execute {canv coords isconf} {
    $canv delete Preview
    foreach {x0 y0} $coords break
    set objids [cadobjects_topmost_objects $canv "SELECTED"]
    cadobjects_object_align_top $canv $objids $y0
}





proc plugin_alignvcenter_execute {canv coords isconf} {
    $canv delete Preview
    foreach {x0 y0} $coords break
    set objids [cadobjects_topmost_objects $canv "SELECTED"]
    cadobjects_object_align_vcenter $canv $objids $y0
}





proc plugin_alignvcenter2_execute {canv coords isconf} {
    $canv delete Preview
    foreach {x0 y0 x1 y1} $coords break
    set objids [cadobjects_topmost_objects $canv "SELECTED"]
    set ypos [expr {($y0+$y1)/2.0}]
    cadobjects_object_align_vcenter $canv $objids $ypos
}





proc plugin_alignbottom_execute {canv coords isconf} {
    $canv delete Preview
    foreach {x0 y0} $coords break
    set objids [cadobjects_topmost_objects $canv "SELECTED"]
    cadobjects_object_align_bottom $canv $objids $y0
}








proc plugin_aligns_register {} {
    tool_register_ex ALIGNLEFT "La&yout" "Align To &Left" {
        {1    "Point to Align To"}
    } -icon "tool-alignleft"
    tool_register_ex ALIGNHCENTER "La&yout" "Center &Horizontally" {
        {1    "Point to Center To"}
    } -icon "tool-alignhcenter"
    tool_register_ex ALIGNRIGHT "La&yout" "Align To &Right" {
        {1    "Point to Align To"}
    } -icon "tool-alignright"
    tool_register_ex ALIGNTOP "La&yout" "Align To &Top" {
        {1    "Point to Align To"}
    } -icon "tool-aligntop"
    tool_register_ex ALIGNVCENTER "La&yout" "Center &Vertically" {
        {1    "Point to Center To"}
    } -icon "tool-alignvcenter"
    tool_register_ex ALIGNBOTTOM "La&yout" "Align To &Bottom" {
        {1    "Point to Align To"}
    } -icon "tool-alignbottom"
    tool_register_ex ALIGNHCENTER2 "La&yout" "&Center Horizontally Between" {
        {1    "First Point to Center Between"}
        {2    "Second Point to Center Between"}
    } -icon "tool-alignhcenter2"
    tool_register_ex ALIGNVCENTER2 "La&yout" "C&enter Vertically Between" {
        {1    "First Point to Center Between"}
        {2    "Second Point to Center Between"}
    } -icon "tool-alignvcenter2"
}
plugin_aligns_register 


# vim: set ts=4 sw=4 nowrap expandtab: settings

