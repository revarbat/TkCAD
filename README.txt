Around June of 2007 I got offended at how much CAD/CAM programs cost for
generating GCode toolpath files for CNC mills.  So I did what any insane idiot
coder would do.  I started writing my own.  Most coders would get a ways into
it and give it up, but I kept working on it.  The result is TkCAD, written in
42,000+ lines of TCL code and just a few hundred lines of C extensions.

It's currently for OS X only, almost completely due to the extensions it uses:
  fontdata        Gets font glyph curves. (Critcl, Carbon only, simple)
  mlcnc_critcl    Speeds up geometry calculations. (Critcl, portable)
  enhimgcopy      Allows scaling and rotation of images.  (Critcl, portable)
  Img             Allows loading of JPEG images and such.  (TEA, portable)
  MacCarbonPrint  Allows printing under OS X.  (TEA, Carbon only, complex)

If you ported the extensions, you could port TkCAD to other platforms easily,
other than printing.  The mlcnc extension actually has TCL equivalents
of its calls as a fallback, but they're much slower.  I used to use the
tkpath extension, as it makes much cleaner beziers, but it has occasional
crashes with complex files.  Sadly, MacCarbonPrint and tkpath are both
orphaned works, due to the death of the developer.

If running under Wish 8.6, TkCAD supports canvas font rotation.  If the
tkpath extension is loaded, that is used instead.  Finally, as a fallback,
the font glyph curves are extracted by the fontdata extension and they
are displayed as beziers.


