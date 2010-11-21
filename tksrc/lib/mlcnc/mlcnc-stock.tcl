        # Material       DrillSFM MillSFM FeedIPT HPUnit
global mlcncStockData
set mlcncStockData {
        "acrylic"             500     500   0.003    0.05
        "magnesium"           300     300   0.003    0.2
        "aluminum"            250     250   0.003    0.3
        "brass"               200     150   0.003    0.6
        "brass (hard)"        200     150   0.003    1.0
        "bronze"              200     110   0.003    0.7
        "bronze (very hard)"  200     110   0.003    1.5
        "copper"               70     100   0.003    0.7
        "cast iron (soft)"    120      80   0.003    0.7
        "cast iron (hard)"     80      50   0.002    1.4
        "mild steel"          110      90   0.003    1.1
        "cast steel"           50      80   0.003    1.6
        "alloy steel"          60      40   0.002    1.6
        "tool steel"           60      50   0.002    1.6
        "stainless steel"      30      60   0.003    1.4
        "titanium"             30      50   0.002    1.2
}


tcl::OptProc mlcnc_define_stock {
    {xsize -float "The length of the stock."}
    {ysize -float "The width of the stock."}
    {zsize -float "The height of the stock."}
    {-material {} "Material that the stock is made out of."}
} {
    global mlcncStockInfo
    global mlcncStockData
    set found 0
    set mat [string tolower $material]
    foreach {material drillsfm millsfm feedipt hpunit} $mlcncStockData {
        if {$mat == [string tolower $material]} {
            set mlcncStockInfo(STOCK_DRILLSFM) $drillsfm
            set mlcncStockInfo(STOCK_MILLSFM) $millsfm
            set mlcncStockInfo(STOCK_FEEDIPT) $feedipt
            set mlcncStockInfo(STOCK_HPUNIT) $hpunit
            set found 1
            break
        }
    }
    if {!$found} {
        error "I don't know this material!"
    }
    set mlcncStockInfo(STOCKX) $xsize
    set mlcncStockInfo(STOCKY) $ysize
    set mlcncStockInfo(STOCKZ) $zsize
    set mlcncStockInfo(STOCKMATERIAL) $material
}


proc mlcnc_stock_types {} {
    global mlcncStockData
    set materials {}
    foreach {material drillsfm millsfm feedipt hpunit} $mlcncStockData {
        lappend materials [string totitle $material]
    }
    return $materials
}


proc mlcnc_stock_unithp {} {
    global mlcncStockInfo
    return $mlcncStockInfo(STOCK_HPUNIT)
}



proc mlcnc_stock_xsize {} {
    global mlcncStockInfo
    return $mlcncStockInfo(STOCKX)
}



proc mlcnc_stock_ysize {} {
    global mlcncStockInfo
    return $mlcncStockInfo(STOCKY)
}



proc mlcnc_stock_zsize {} {
    global mlcncStockInfo
    return $mlcncStockInfo(STOCKZ)
}



proc mlcnc_stock_material {} {
    global mlcncStockInfo
    return $mlcncStockInfo(STOCKMATERIAL)
}



proc mlcnc_stock_set_material {mat} {
    global mlcncStockInfo
    global mlcncStockData
    set found 0
    foreach {material drillsfm millsfm feedipt hpunit} $mlcncStockData {
        if {$mat == [string tolower $material]} {
            set found 1
            break
        }
    }
    if {!$found} {
        error "Unknown stock material!"
    }
    set mlcncStockInfo(STOCKMATERIAL) $mat
}



proc mlcnc_stock_millsfm {} {
    global mlcncStockInfo
    if {![info exists mlcncStockInfo(STOCKMATERIAL)]} {
        error "Stock wasn't defined.  Use mlcnc_define_stock to specify stock properties."
    }
    return $mlcncStockInfo(STOCK_MILLSFM)
}


proc mlcnc_stock_drillsfm {} {
    global mlcncStockInfo
    if {![info exists mlcncStockInfo(STOCKMATERIAL)]} {
        error "Stock wasn't defined.  Use mlcnc_define_stock to specify stock properties."
    }
    return $mlcncStockInfo(STOCK_DRILLSFM)
}


proc mlcnc_stock_feedipt {} {
    global mlcncStockInfo
    if {![info exists mlcncStockInfo(STOCKMATERIAL)]} {
        error "Stock wasn't defined.  Use mlcnc_define_stock to specify stock properties."
    }
    return $mlcncStockInfo(STOCK_FEEDIPT)
}


proc mlcnc_rapid_z {} {
    return 0.1
}


proc mlcnc_stock_top {} {
    return 0.0
}


# vim: set ts=4 sw=4 nowrap expandtab: settings

