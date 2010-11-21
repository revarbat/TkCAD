package require Img
package require enhimgcpy

set orig [image create photo -file [file join $env(HOME) Pictures FoxyBounce.JPG]]

set cnt 0
foreach filt {Mitchell Lanczos BlackmanSinc} {
    set thumb [image create photo]
    image_copy_to_size $orig $thumb 100 100 -filter $filt
    set lbl [label .l$cnt -image $thumb]
    pack $lbl -side left
    incr cnt
}


