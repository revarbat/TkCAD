package require critcl
package provide fontdata 1.0

critcl::tk

if {[llength [info commands ::critcl::framework]]} { 
    ::critcl::framework Carbon 
} else { 
    lappend ::critcl::v::compile -framework Carbon 
}

switch -glob -- $::tcl_platform(os) { 
    Windows* { 
        # .../... 
    } 
    Linux { 
        # .../... 
    } 
    Darwin { 
        set tcl_prefix /Library/Frameworks/Tcl.framework
        set tk_prefix /Library/Frameworks/Tk.framework
        set platform "unix" 

        lappend critcl::v::compile \
            -I$tk_prefix/generic \
            -I$tk_prefix/xlib \
            -I$tk_prefix/$platform \
            -I$tk_prefix \
            -I$tcl_prefix/generic \
            -I$tcl_prefix/$platform \
            -I$tcl_prefix \
            -I[pwd] \
            -DMAC_OSX_TK 

        critcl::cheaders \
            -I$tk_prefix/generic \
            -I$tk_prefix/xlib \
            -I$tk_prefix/$platform \
            -I$tk_prefix -I$tcl_prefix/generic \
            -I$tcl_prefix/$platform -I$tcl_prefix \
            -I[pwd] \
            -DMAC_OSX_TK 
    } 
} 

#critcl::cheaders -DMAC_OSX_TK -Itk/generic -Itk/macosx -Itk/generic
#critcl::clibraries -lm

critcl::ccode {
#include <stdio.h>
#define Cursor X11Cursor
#include <Carbon/Carbon.h>

typedef struct {
    Tk_Uid family;
    int size;
    int weight;
    int slant;
    int underline;
    int overstrike;
} TkFontAttributes;

typedef struct {
    int ascent;
    int descent;
    int maxWidth;
    int fixed;
} TkFontMetrics;

typedef struct TkFont_t {
    int resourceRefCount;
    int objRefCount;
    Tcl_HashEntry *cacheHashPtr;
    Tcl_HashEntry *namedHashPtr;
    Screen *screen;
    int tabWidth;
    int underlinePos;
    int underlineHeight;
    Font fid;
    TkFontAttributes fa;
    TkFontMetrics fm;
    struct TkFont_t *nextPtr;
} TkFont;

typedef struct {
    TkFont font;
    ATSUFontID atsuFontId;
    ATSUTextLayout atsuLayout;
    ATSUStyle atsuStyle;
    FMFontFamily qdFont;
    short qdSize;
    short qdStyle;
} MacFont;

typedef struct {
    Tcl_Interp* ip;
    Tcl_Obj* res;
    double xoff;
    double yoff;
} FontDataCBInfo;


OSStatus MyATSCubicMoveToCallback(const Float32Point *pt, void *cbd)
{
    Tcl_Obj* subobj;
    FontDataCBInfo *cbi = (FontDataCBInfo*)cbd;

    subobj = Tcl_NewStringObj("M", 1);
    Tcl_ListObjAppendElement(cbi->ip, cbi->res, subobj);
    subobj = Tcl_NewDoubleObj(pt->x + cbi->xoff);
    Tcl_ListObjAppendElement(cbi->ip, cbi->res, subobj);
    subobj = Tcl_NewDoubleObj(pt->y + cbi->yoff);
    Tcl_ListObjAppendElement(cbi->ip, cbi->res, subobj);

    return noErr;
}


OSStatus MyATSCubicLineToCallback (const Float32Point *pt, void *cbd)
{
    Tcl_Obj* subobj;
    FontDataCBInfo *cbi = (FontDataCBInfo*)cbd;

    subobj = Tcl_NewStringObj("L", 1);
    Tcl_ListObjAppendElement(cbi->ip, cbi->res, subobj);
    subobj = Tcl_NewDoubleObj(pt->x + cbi->xoff);
    Tcl_ListObjAppendElement(cbi->ip, cbi->res, subobj);
    subobj = Tcl_NewDoubleObj(pt->y + cbi->yoff);
    Tcl_ListObjAppendElement(cbi->ip, cbi->res, subobj);

    return noErr;
}


OSStatus MyATSCubicCurveToCallback(
        const Float32Point *pt1,
        const Float32Point *pt2,
        const Float32Point *pt3,
        void *cbd)
{
    Tcl_Obj* subobj;
    FontDataCBInfo *cbi = (FontDataCBInfo*)cbd;

    subobj = Tcl_NewStringObj("C", 1);
    Tcl_ListObjAppendElement(cbi->ip, cbi->res, subobj);

    subobj = Tcl_NewDoubleObj(pt1->x + cbi->xoff);
    Tcl_ListObjAppendElement(cbi->ip, cbi->res, subobj);
    subobj = Tcl_NewDoubleObj(pt1->y + cbi->yoff);
    Tcl_ListObjAppendElement(cbi->ip, cbi->res, subobj);

    subobj = Tcl_NewDoubleObj(pt2->x + cbi->xoff);
    Tcl_ListObjAppendElement(cbi->ip, cbi->res, subobj);
    subobj = Tcl_NewDoubleObj(pt2->y + cbi->yoff);
    Tcl_ListObjAppendElement(cbi->ip, cbi->res, subobj);

    subobj = Tcl_NewDoubleObj(pt3->x + cbi->xoff);
    Tcl_ListObjAppendElement(cbi->ip, cbi->res, subobj);
    subobj = Tcl_NewDoubleObj(pt3->y + cbi->yoff);
    Tcl_ListObjAppendElement(cbi->ip, cbi->res, subobj);

    return noErr;
}


OSStatus MyATSCubicClosePathCallback(void *cbd)
{
    return noErr;
}

}


::critcl::ccommand GetFontCurves  {ClientData ip objc objv} {
    Tk_Window tkwin;
    Tk_Font tkf;
    MacFont* mf;
    OSStatus osstat;
    ByteCount bc;
    ItemCount   count;
    ATSLayoutRecord*layoutRec = NULL;
    ATSUCurvePaths *paths;
    ATSUCurvePaths *path;
    UniCharArrayPtr unistr;
    FontDataCBInfo fdcbi;
    Tcl_Obj* subobj;
    int i, j, len;
    char* win;
    char* font;
    char* str;

    if (objc != 4) {
        Tcl_WrongNumArgs(ip, 1, objv, "win font str");
        return TCL_ERROR;
    }

    win  = Tcl_GetString(objv[1]);
    font = Tcl_GetString(objv[2]);
    str  = Tcl_GetString(objv[3]);

    tkwin = Tk_NameToWindow(ip,win,Tk_MainWindow(ip));
    if (!tkwin) {
        Tcl_AppendResult(ip, "Could not find window.", NULL);
        return TCL_ERROR;
    }
    tkf = Tk_GetFont(ip, tkwin, font);
    mf = (MacFont*)tkf;

    len = strlen(str);
    unistr = (UniCharArrayPtr) NewPtr(len * sizeof(UniChar));
    for (i = 0; i < len; i++) {
        unistr[i] = str[i];
    }

    osstat = ATSUSetTextPointerLocation(mf->atsuLayout, unistr, 0, len, len); 
    osstat = ATSUSetRunStyle(mf->atsuLayout, mf->atsuStyle, 0, len);
    osstat = ATSUDirectGetLayoutDataArrayPtrFromTextLayout(mf->atsuLayout, 0, kATSUDirectDataLayoutRecordATSLayoutRecordCurrent, (void*) &layoutRec, &count);

    fdcbi.ip = ip;
    fdcbi.res = Tcl_NewListObj(0, NULL);
    fdcbi.xoff = 0.0;
    fdcbi.yoff = 0.0;

    for (i = 0; i < count; ++i) {
        if (layoutRec[i].glyphID < 0xfffe) {
            fdcbi.xoff = Fix2X(layoutRec[i].realPos);
            fdcbi.yoff = 0.0;

            osstat = ATSUGlyphGetCubicPaths(
                        mf->atsuStyle, layoutRec[i].glyphID,
                        MyATSCubicMoveToCallback,
                        MyATSCubicLineToCallback,
                        MyATSCubicCurveToCallback,
                        MyATSCubicClosePathCallback,
                        (void*)&fdcbi, &osstat
                    );

            if (osstat != noErr) {
                break;
            }
        }
    }

    ATSUDirectReleaseLayoutDataArrayPtr(NULL, kATSUDirectDataLayoutRecordATSLayoutRecordCurrent, (void*)&layoutRec);

    if (osstat != noErr) {
        Tcl_AppendResult(ip, "Could not get Curve Data.", NULL);
        return TCL_ERROR;
    }

    subobj = Tcl_NewStringObj("z", 1);
    Tcl_ListObjAppendElement(ip, fdcbi.res, subobj);

    Tcl_SetObjResult(ip, fdcbi.res);
    return TCL_OK;
}


# vim: set syntax=c ts=8 sw=4 nowrap expandtab: settings

