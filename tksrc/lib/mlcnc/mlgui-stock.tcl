# Window for specifying information about the Stock to be milled.


proc mlgui_stock_create {wname {stocknum ""}} {
    global mlguiStockInfo

    set materials {
        "Acrylic"
        "Aluminum"
        "Brass"
        "Bronze"
        "Copper"
        "Magnesium"
        {"alloy steel"     "Steel (alloy)"}
        {"cast steel"      "Steel (cast)"}
        {"mild steel"      "Steel (mild)"}
        {"stainless steel" "Steel (stainless)"}
        "Titanium"
    }

    set base [toplevel $wname]
    wm title $base "Stock Data"
    
    set xsize    [mlcnc_stock_xsize]
    set ysize    [mlcnc_stock_ysize]
    set zsize    [mlcnc_stock_zsize]
    set material [mlcnc_stock_material]

    label $base.xsize_lbl -text "X Dimension (length)"
    spinbox $base.xsize -width 8 -format "%.5f" \
        -from 0.0 -to 999.0 -increment [expr {1/32.0}] -validate all \
        -validatecommand [list mlcnc_stock_validate_float $base %P]
    $base.xsize set [format [$base.xsize cget -format] $xsize]

    label $base.ysize_lbl -text "Y Dimension (width)"
    spinbox $base.ysize -width 8 -format "%.5f" \
        -from 0.0 -to 999.0 -increment [expr {1/32.0}] -validate all \
        -validatecommand [list mlcnc_stock_validate_float $base %P]
    $base.ysize set [format [$base.ysize cget -format] $ysize]

    label $base.zsize_lbl -text "Z Dimension (height)"
    spinbox $base.zsize -width 8 -format "%.5f" \
        -from 0.0 -to 999.0 -increment [expr {1/32.0}] -validate all \
        -validatecommand [list mlcnc_stock_validate_float $base %P]
    $base.zsize set [format [$base.zsize cget -format] $zsize]

    label $base.material_lbl -text "Stock Material"
    mlgui_optionmenu $base.material $material $materials

    button $base.savebtn   -text "Save"   -width 10 -default active -command [list mlgui_stock_save $base]
    button $base.cancelbtn -text "Cancel" -width 10 -command [list destroy $base]
    bind $base <KeyPress-Return> [list $base.savebtn invoke]
    bind $base <KeyPress-Escape> [list $base.cancelbtn invoke]

    grid columnconfigure $base 0 -minsize 25
    grid columnconfigure $base 2 -minsize 10
    grid columnconfigure $base 3 -minsize 150
    grid columnconfigure $base 4 -minsize 25
    grid rowconfigure $base 0 -minsize 25
    grid rowconfigure $base 2 -minsize 20
    grid rowconfigure $base 4 -minsize 20
    grid rowconfigure $base 6 -minsize 20
    grid rowconfigure $base 8 -minsize 20
    grid rowconfigure $base 10 -minsize 30

    set row -1
    set fr [frame $base.frdummy -borderwidth 0 -relief flat]
    grid configure $fr     x            x        x       x -in $base
    grid configure ^ $base.xsize_lbl    x $base.xsize    x
    grid configure ^       x            x        x       x -in $base
    grid configure ^ $base.ysize_lbl    x $base.ysize    x
    grid configure ^       x            x        x       x -in $base
    grid configure ^ $base.zsize_lbl    x $base.zsize    x
    grid configure ^       x            x        x       x -in $base
    grid configure ^ $base.material_lbl x $base.material x
    grid configure ^       x            x        x       x -in $base
    grid configure ^ $base.cancelbtn    x $base.savebtn  x
    grid configure ^       x            x        x       x -in $base

    grid configure $base.xsize_lbl $base.ysize_lbl $base.zsize_lbl -sticky w
    grid configure $base.material_lbl -sticky e
    grid configure $base.xsize $base.ysize $base.zsize $base.material -sticky w

    return $base
}


proc mlgui_stock_save {wname} {
    set xsize [$wname.xsize get]
    set ysize [$wname.ysize get]
    set zsize [$wname.zsize get]
    set material [mlgui_optionmenu_value_get $wname.material]

    mlcnc_define_stock $xsize $ysize $zsize -material $material

    destroy $wname
}


proc mlcnc_stock_validate_float {wname newval} {
    if {![string is double $newval]} {
        return 0
    }
    return 1
}


if {[info commands main] == {}} {
    bind all <Command-KeyPress-q> "exit"
    mlcnc_define_stock 1.0 1.0 1.0 -material Aluminum
    source mlgui-misc.tcl
    mlgui_stock_create .stock
    after 100 raise .stock
}

