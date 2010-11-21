MAINFILES=tksrc/main.tcl
LIBFILES=tksrc/lib/*.tcl
MLCNCFILES=tksrc/lib/mlcnc/*.tcl
WIZFILES=tksrc/lib/wizards/*.tcl
FILES=$(MAINFILES) $(LIBFILES) $(MLCNCFILES) $(WIZFILES)

tags:
	grep '^[	 ]*proc[	 ]' $(FILES) | grep -v rename | sed 's/^\([^:]*\):[	 ]*proc[	 ]*\([^	 ]*\).*/\2	\1	\/proc \2 \//' | sort -u > tags

package:
	cd scripts && ./mktkcad

