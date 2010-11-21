package require critcl
package provide enhimgcpy 1.0

set tkpath /Users/gminette/dev/Tcl/cocoahead/tk

critcl::tk
critcl::cheaders -DMAC_OSX_TK -I$tkpath/generic -I$tkpath/macosx
critcl::clibraries -lm

critcl::tsources enhimgcpy_tcl.tcl

critcl::ccode {
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include "tkInt.h"

#undef MIN
#define MIN(a, b)	((a) < (b)? (a): (b))
#undef MAX
#define MAX(a, b)	((a) > (b)? (a): (b))

/*
 * Definition of the data associated with each photo image master.
 */

typedef struct PhotoMaster {
    Tk_ImageMaster tkMaster;	/* Tk's token for image master. NULL means the
				 * image is being deleted. */
    Tcl_Interp *interp;		/* Interpreter associated with the application
				 * using this image. */
    Tcl_Command imageCmd;	/* Token for image command (used to delete it
				 * when the image goes away). NULL means the
				 * image command has already been deleted. */
    int	flags;			/* Sundry flags, defined below. */
    int	width, height;		/* Dimensions of image. */
    int userWidth, userHeight;	/* User-declared image dimensions. */
    Tk_Uid palette;		/* User-specified default palette for
				 * instances of this image. */
    double gamma;		/* Display gamma value to correct for. */
    char *fileString;		/* Name of file to read into image. */
    Tcl_Obj *dataString;	/* Object to use as contents of image. */
    Tcl_Obj *format;		/* User-specified format of data in image file
				 * or string value. */
    unsigned char *pix32;	/* Local storage for 32-bit image. */
    int ditherX, ditherY;	/* Location of first incorrectly dithered
				 * pixel in image. */
    TkRegion validRegion;	/* Tk region indicating which parts of the
				 * image have valid image data. */
    struct PhotoInstance *instancePtr;
				/* First in the list of instances associated
				 * with this master. */
} PhotoMaster;

/*
 * Bit definitions for the flags field of a PhotoMaster.
 * COLOR_IMAGE:			1 means that the image has different color
 *				components.
 * IMAGE_CHANGED:		1 means that the instances of this image need
 *				to be redithered.
 * COMPLEX_ALPHA:		1 means that the instances of this image have
 *				alpha values that aren't 0 or 255, and so need
 *				the copy-merge-replace renderer .
 */

#define COLOR_IMAGE		1
#define IMAGE_CHANGED		2
#define COMPLEX_ALPHA		4

/*
 * The following data structure is used to return information
 * from ParseSubcommandOptions:
 */

struct SubcommandOptions {
    int options;		/* Individual bits indicate which
                                   options were specified - see below. */
    Tcl_Obj *name;		/* Name specified without an option. */
    Tcl_Obj *name2;		/* Second name specified without an option. */
    int fromX, fromY;		/* Values specified for -from option. */
    int fromX2, fromY2;		/* Second coordinate pair for -from option. */
    int toX, toY;		/* Values specified for -to option. */
    int toX2, toY2;		/* Second coordinate pair for -to option. */
    int zoomX, zoomY;		/* Values specified for -zoom option. */
    int subsampleX, subsampleY;	/* Values specified for -subsample option. */
    double rotate;		/* Degrees to rotate the image with */
    double scaleX, scaleY;	/* Resize factors in the X and Y directions */
    int mirrorX, mirrorY;	/* 1 if mirroring the respective axis requested */
    char *filtername;		/* name of the interpolating lowpass filter */
    int smoothedge;		/* pixel width of frame used in edge smoothing:
                                   default value is 0 (means no smoothing)
                                   and 1 may be specified in the Tcl command */
    double blur;		/* defines the effect of blurring the image, must be > 1.0 */
    XColor *background;		/* Value specified for -background option. */
    int compositingRule;	/* Value specified for -compositingrule opt */
};

/*
 * Bit definitions for use with ParseSubcommandOptions:
 * Each bit is set in the allowedOptions parameter on a call to
 * ParseSubcommandOptions if that option is allowed for the current
 * photo image subcommand.  On return, the bit is set in the options
 * field of the SubcommandOptions structure if that option was specified.
 *
 * OPT_BACKGROUND:		
 * OPT_COMPOSITE:		Set if -compositingrule option allowed/spec'd.
 * OPT_FROM:			Set if -from option allowed/specified.
 * OPT_SHRINK:			Set if -shrink option allowed/specified.
 * OPT_SUBSAMPLE:		Set if -subsample option allowed/spec'd.
 * OPT_TO:	    		Set if -to option allowed/specified.
 * OPT_ZOOM:			Set if -zoom option allowed/specified.
 * OPT_ROTATE:			Set if -rotate option allowed/specified.
 * OPT_SCALE:			Set if -scale option allowed/specified.
 * OPT_MIRROR:			Set if -mirror option allowed/specified.
 * OPT_FILTER:			Set if -filter option allowed/specified.
 * OPT_SMOOTHEDGE:		Set if -filter option allowed/specified.
 * OPT_BLUR:			Set if -blur option allowed/specified.
 */

#define OPT_BACKGROUND	1
#define OPT_COMPOSITE	2
#define OPT_FROM	4
#define OPT_SHRINK	8
#define OPT_SUBSAMPLE	0x10
#define OPT_TO		0x20
#define OPT_ZOOM	0x40
#define OPT_ROTATE	0x80
#define OPT_SCALE	0x100
#define OPT_MIRROR	0x200
#define OPT_FILTER	0x400
#define OPT_SMOOTHEDGE	0x800
#define OPT_BLUR	0x1000

/*
 * List of option names.  The order here must match the order of
 * declarations of the OPT_* constants above.
 */

static char *optionNames[] = {
    "-background",
    "-compositingrule",
    "-from",
    "-shrink",
    "-subsample",
    "-to",
    "-zoom",
    "-rotate",
    "-scale",
    "-mirror",
    "-filter",
    "-smoothedge",
    "-blur",
    (char *) NULL
};


/*
 *----------------------------------------------------------------------
 *
 * ParseSubcommandOptions --
 *
 *	This procedure is invoked to process one of the options
 *	which may be specified for the photo image subcommands,
 *	namely, -from, -to, -zoom, -subsample, -shrink,
 *	and -compositingrule.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	Fields in *optPtr get filled in.
 *
 *----------------------------------------------------------------------
 */

static int
ParseSubcommandOptions(optPtr, interp, allowedOptions, optIndexPtr, objc, objv)
    struct SubcommandOptions *optPtr;
                /* Information about the options specified
                 * and the values given is returned here. */
    Tcl_Interp *interp;		/* Interpreter to use for reporting errors. */
    int allowedOptions;		/* Indicates which options are valid for
                 * the current command. */
    int *optIndexPtr;		/* Points to a variable containing the
                 * current index in objv; this variable is
                 * updated by this procedure. */
    int objc;			/* Number of arguments in objv[]. */
    Tcl_Obj *CONST objv[];	/* Arguments to be parsed. */
{
    int index, c, bit, currentBit;
    int length;
    char *option, **listPtr;
    int values[4];
    int numValues, maxValues, argIndex;
    char *temp;

    for (index = *optIndexPtr; index < objc; *optIndexPtr = ++index) {
        /*
         * We can have one value specified without an option;
         * it goes into optPtr->name.
         */

        option = Tcl_GetStringFromObj(objv[index], &length);
        if (option[0] != '-') {
            if (optPtr->name == NULL) {
                optPtr->name = objv[index];
                continue;
            } else if (optPtr->name2 == NULL) {
                optPtr->name2 = objv[index];
                continue;
            }
            break;
        }

        /*
         * Work out which option this is.
         */

        c = option[0];
        bit = 0;
        currentBit = 1;
        for (listPtr = optionNames; *listPtr != NULL; ++listPtr) {
            if ((c == *listPtr[0]) && (strncmp(option, *listPtr, (size_t) length) == 0)) {
                if (bit != 0) {
                    bit = 0;	/* An ambiguous option. */
                    break;
                }
                bit = currentBit;
            }
            currentBit <<= 1;
        }

        /*
         * If this option is not recognized and allowed, put
         * an error message in the interpreter and return.
         */

        if ((allowedOptions & bit) == 0) {
            Tcl_AppendResult(interp, "unrecognized option \"",
                    Tcl_GetString(objv[index]),
                "\": must be ", (char *)NULL);
            bit = 1;
            for (listPtr = optionNames; *listPtr != NULL; ++listPtr) {
                if ((allowedOptions & bit) != 0) {
                    if ((allowedOptions & (bit - 1)) != 0) {
                        Tcl_AppendResult(interp, ", ", (char *) NULL);
                        if ((allowedOptions & ~((bit << 1) - 1)) == 0) {
                            Tcl_AppendResult(interp, "or ", (char *) NULL);
                        }
                    }
                    Tcl_AppendResult(interp, *listPtr, (char *) NULL);
                }
                bit <<= 1;
            }
            return TCL_ERROR;
        }

        /*
         * For the -from, -to, -zoom, -subsample, -background, -rotate, -scale, -filter, -mirror,
         * -smoothedge, roll options parse the values given.  Report an error if too few
         * or too many values are given.
         */

        if (bit == OPT_BACKGROUND) {
            /*
             * The -background option takes a single XColor value.
             */

            if (index + 1 < objc) {
                *optIndexPtr = ++index;
                optPtr->background = Tk_GetColor(interp, Tk_MainWindow(interp),
                    Tk_GetUid(Tcl_GetString(objv[index])));
                if (!optPtr->background) {
                    return TCL_ERROR;
                }
            } else {
                Tcl_AppendResult(interp, "the \"-background\" option ",
                    "requires a value", (char *) NULL);
                return TCL_ERROR;
            }
        } else if (bit == OPT_COMPOSITE) {
            /*
             * The -compositingrule option takes a single value from
             * a well-known set.
             */

            if (index + 1 < objc) {
                /*
                 * Note that these must match the TK_PHOTO_COMPOSITE_*
                 * constants.
                 */
                static CONST char *compositingRules[] = {
                    "overlay", "set",
                    NULL
                };

                index++;
                if (Tcl_GetIndexFromObj(interp, objv[index], compositingRules,
                    "compositing rule", 0, &optPtr->compositingRule)
                    != TCL_OK) {
                    return TCL_ERROR;
                }
                *optIndexPtr = index;
            } else {
                Tcl_AppendResult(interp, "the \"-compositingrule\" option ",
                    "requires a value", (char *) NULL);
                return TCL_ERROR;
            }
        } else if (bit == OPT_ROTATE) {
            if (index + 1 < objc) {
                *optIndexPtr = ++index;
                if (Tcl_GetDoubleFromObj(interp, objv[index], &optPtr->rotate) != TCL_OK) {
                    Tcl_AppendResult(interp, "the -rotate value is invalid", (char *) NULL);
                    return TCL_ERROR;
                }
            } else {
                Tcl_AppendResult(interp, "the \"-rotate\" option ",
                    "requires a value", (char *) NULL);
                return TCL_ERROR;
            }
        } else if (bit == OPT_SCALE) {
            if (index + 1 < objc) {
                *optIndexPtr = ++index;
                if (Tcl_GetDoubleFromObj(interp, objv[index], &optPtr->scaleX) != TCL_OK) {
                    Tcl_AppendResult(interp, "the -scaleX value is invalid", (char *) NULL);
                    return TCL_ERROR;
                }
                optPtr->scaleY = optPtr->scaleX;
                if (index + 1 < objc) {
                    if (*(Tcl_GetString(objv[index+1])) != '-') {
                        *optIndexPtr = ++index;
                        if (Tcl_GetDoubleFromObj(interp, objv[index], &optPtr->scaleX) != TCL_OK) {
                            Tcl_AppendResult(interp, "the -scaleY value is invalid", (char *) NULL);
                            return TCL_ERROR;
                        }
                    } 
                } 
            } else {
                Tcl_AppendResult(interp, "the \"-scale\" option ",
                    "requires one or two values", (char *) NULL);
                return TCL_ERROR;
            }
        } else if (bit == OPT_MIRROR) {
            if (index + 1 < objc) {
                *optIndexPtr = ++index;
                temp = Tcl_GetString(objv[index]);
                if (temp[0] == '-') {
                    optPtr->mirrorX = optPtr->mirrorY = 1;
                    *optIndexPtr = --index;
                } else if ((temp[0] == 'x') && (temp[1] == '\x00')) {
                    optPtr->mirrorX = 1;
                } else if ((temp[0] == 'y') && (temp[1] == '\x00')) {
                    optPtr->mirrorY = 1;
                } else {
                    Tcl_AppendResult(interp, "wrong value for the \"-mirror\" option", (char *) NULL);
                    return TCL_ERROR;
                }
            } else {
               optPtr->mirrorX = optPtr->mirrorY = 1;
            }
        } else if (bit == OPT_FILTER) {
            if (index + 1 < objc) {
                *optIndexPtr = ++index;
                optPtr->filtername = Tcl_GetString(objv[index]);
                if (optPtr->filtername[0] == '-') {
                    optPtr->filtername = "Mitchell";
                    *optIndexPtr = --index;
                }
            } else {
                optPtr->filtername = "Mitchell";
            } 
        } else if (bit == OPT_SMOOTHEDGE) {
            if (index + 1 < objc) {
                *optIndexPtr = ++index;
                temp = Tcl_GetString(objv[index]);
                if (((temp[0] == '0') || (temp[0] == '1') || (temp[0] == '2')) && (temp[1] == '\x00')) {
                    optPtr->smoothedge = temp[0] - 0x30;
                } else {
                    Tcl_AppendResult(interp, "wrong value for the -smoothedge option", (char *) NULL);
                    return TCL_ERROR;
                }
            } else {
                optPtr->smoothedge = 2;
            }
        } else if (bit == OPT_BLUR) {
            if (index + 1 < objc) {
                *optIndexPtr = ++index;
                temp = Tcl_GetString(objv[index]);
                if (Tcl_GetDoubleFromObj(interp, objv[index], &optPtr->blur) != TCL_OK) {
                    Tcl_AppendResult(interp, "the -blur value is invalid", (char *) NULL);
                    return TCL_ERROR;
                }
            } else {
                Tcl_AppendResult(interp, "the -blur option requires a value", (char *) NULL);
                return TCL_ERROR;
            }
        } else if ((bit != OPT_SHRINK)) {
            char *val;
            maxValues = ((bit == OPT_FROM) || (bit == OPT_TO))? 4: 2;
            argIndex = index + 1;
            for (numValues = 0; numValues < maxValues; ++numValues) {
                if (argIndex >= objc) {
                    break;
                }
                    val = Tcl_GetString(objv[argIndex]);
                if ((argIndex < objc) && (isdigit(UCHAR(val[0]))
                    || ((val[0] == '-') && isdigit(UCHAR(val[1]))))) {
                    if (Tcl_GetInt(interp, val, &values[numValues]) != TCL_OK) {
                        return TCL_ERROR;
                    }
                } else {
                    break;
                }
                ++argIndex;
            }

            if (numValues == 0) {
                Tcl_AppendResult(interp, "the \"", option, "\" option ",
                     "requires one ", maxValues == 2? "or two": "to four",
                     " integer values", (char *) NULL);
                return TCL_ERROR;
            }
            *optIndexPtr = (index += numValues);

            /*
             * Y values default to the corresponding X value if not specified.
             */

            if (numValues == 1) {
                values[1] = values[0];
            }
            if (numValues == 3) {
                values[3] = values[2];
            }

            /*
             * Check the values given and put them in the appropriate
             * field of the SubcommandOptions structure.
             */

            switch (bit) {
            case OPT_FROM:
                if ((values[0] < 0) || (values[1] < 0) || ((numValues > 2)
                    && ((values[2] < 0) || (values[3] < 0)))) {
                    Tcl_AppendResult(interp, "value(s) for the -from",
                        " option must be non-negative", (char *) NULL);
                    return TCL_ERROR;
                }
                if (numValues <= 2) {
                    optPtr->fromX = values[0];
                    optPtr->fromY = values[1];
                    optPtr->fromX2 = -1;
                    optPtr->fromY2 = -1;
                } else {
                    optPtr->fromX = MIN(values[0], values[2]);
                    optPtr->fromY = MIN(values[1], values[3]);
                    optPtr->fromX2 = MAX(values[0], values[2]);
                    optPtr->fromY2 = MAX(values[1], values[3]);
                }
                break;
            case OPT_SUBSAMPLE:
                optPtr->subsampleX = values[0];
                optPtr->subsampleY = values[1];
                break;
            case OPT_TO:
                if ((values[0] < 0) || (values[1] < 0) || ((numValues > 2)
                    && ((values[2] < 0) || (values[3] < 0)))) {
                    Tcl_AppendResult(interp, "value(s) for the -to",
                        " option must be non-negative", (char *) NULL);
                    return TCL_ERROR;
                }
                if (numValues <= 2) {
                    optPtr->toX = values[0];
                    optPtr->toY = values[1];
                    optPtr->toX2 = -1;
                    optPtr->toY2 = -1;
                } else {
                    optPtr->toX = MIN(values[0], values[2]);
                    optPtr->toY = MIN(values[1], values[3]);
                    optPtr->toX2 = MAX(values[0], values[2]);
                    optPtr->toY2 = MAX(values[1], values[3]);
                }
                break;
            case OPT_ZOOM:
                if ((values[0] <= 0) || (values[1] <= 0)) {
                    Tcl_AppendResult(interp, "value(s) for the -zoom",
                        " option must be positive", (char *) NULL);
                    return TCL_ERROR;
                }
                optPtr->zoomX = values[0];
                optPtr->zoomY = values[1];
                break;
            }
        }

        /*
         * Remember that we saw this option.
         */

        optPtr->options |= bit;
    }

    return TCL_OK;
}


typedef struct Filter_ {
    struct Filter_ *next;
    char *name;
    double (*proc)(double);
    double span;
} Filter;


static double PI = 3.14159265358979323846;

static double
Mitchell (double x)
{
   if (x < -2.0)
      return(0.0);
   if (x < -1.0)
      return(1.77777777778 - (-3.33333333333 - (2.0 + 0.388888888889 * x) * x) * x);
   if (x < 0.0)
      return(0.888888888889 + (-2.0 - 1.16666666667 * x) * x * x);
   if (x < 1.0)
      return(0.888888888889 + (-2.0 + 1.16666666667 * x) * x * x);
   if (x < 2.0)
      return(1.77777777778 + (-3.33333333333 + (2.0 - 0.388888888889 * x) * x) * x);
   return(0.0);
}


static double
Lanczos(double x)
{
   double piX, pi033X;

  if (x == 0.0) return 1.0;
  if ((x >= -3.0) && (x < 3.0)) {
     if (x < 0) x = -x ;
     piX = PI * x; pi033X = piX /3.0;
     return (sin(piX) / piX) * (sin(pi033X) / pi033X);
  }
  return 0;
}


static double
BlackmanSinc (double x)
{
   double piX;

   piX = PI * x;
   if (x == 0.0) {
      return (0.42 + 0.5 * cos(piX) + 0.08 * cos(2 * piX));
   } else {
      return (0.42 + 0.5 * cos(piX) + 0.08 * cos(2 * piX)) * (sin(piX) / piX);
   }

}

/*
 *----------------------------------------------------------------------
 *
 * Tk_PhotoPutResizedRotatedBlock --
 *
 *       This procedure is called to put image data into a photo image,
 *       with possible resizing and/or rotating of the source image.
 *
 * Results:
 *       None.
 *
 * Side effects:
 *       The image data is stored.  The image may be expanded.
 *       The Tk image code is informed that the image has changed.
 *
 *----------------------------------------------------------------------
 */

static void
Tk_PhotoPutResizedRotatedBlock(interp, destHandle, srcBlkPtr, toX, toY, toXend, toYend, startX, startY, endX, endY,
                               scaleX, scaleY, rotate, mirrorX, mirrorY, filtername, smoothedge, blur, background, compRule)
   Tcl_Interp *interp;
   Tk_PhotoHandle destHandle;   /* Opaque handle for the photo image
                                 * to be updated. */
   register Tk_PhotoImageBlock *srcBlkPtr;
                                /* Pointer to a structure describing the
                                 * pixel data to be copied into the image. */
   int toX, toY;                /* Area coordinates of the receiving block */
   int toXend, toYend;          /* in the target image */
   int startX, startY;          /* Area coordinates of the selected block */
   int endX, endY;              /* in the source image */
   double scaleX, scaleY;       /* Zoom factors for the X and Y axes. */
   double rotate;               /* Angle of rotation in degrees */
   int mirrorX, mirrorY;        /* 1 if mirroring the x resp. y axis, 0 otherwise */
   char *filtername;            /* if not NULL, points to the name of the interpolating filter */
   int smoothedge;              /* pixel width of frame used in edge smoothing:
                                   default value is 2, 0 (means no smoothing)
                                   and 1 may be specified in the Tcl command */
   double blur;                 /* defines the effect of blurring the image, must be > 1.0*/
   XColor *background;          /* background color agains which edge smoothing is done*/
   int compRule;                /* Compositing rule to use when processing
                                 * transparent pixels. */
{
   register PhotoMaster *masterPtr;
   XRectangle rect;

   static const char sp[] = {2, 3, 1, 4, 1, 4, 2, 3, 4, 1, 3, 2, 3, 2, 4, 1, 1, 4, 2, 3, 4, 1, 3, 2, 3, 2, 4, 1, 2, 3, 1, 4};
   static const char pxpx[] = {1, -1, 1, -1, 0, 0, 0, 0, -1, 1, -1, 1, 0, 0, 0, 0, 1, -1, 1, -1, 0, 0, 0, 0, -1, 1, -1, 1, 0, 0, 0, 0};
   static const char pxpt[] = {0, 0, 0, 0, 1, 1, -1, -1, 0, 0, 0, 0, -1, -1, 1, 1, 0, 0, 0, 0, 1, 1, -1, -1, 0, 0, 0, 0, -1, -1, 1, 1};
   static const char ptpx[] = {0, 0, 0, 0, 1, -1, 1, -1, 0, 0, 0, 0, -1, 1, -1, 1, 0, 0, 0, 0, -1, 1, -1, 1, 0, 0, 0, 0, 1, -1, 1, -1};
   static const char ptpt[] = {-1, -1, 1, 1, 0, 0, 0, 0, 1, 1, -1, -1, 0, 0, 0, 0, 1, 1, -1, -1, 0, 0, 0, 0, -1, -1, 1, 1, 0, 0, 0, 0};

   static Filter filters[] = {{&filters[1], "Mitchell", Mitchell, 2.0}, {&filters[2], "Lanczos", Lanczos, 3.0}, {NULL, "BlackmanSinc", BlackmanSinc, 4.0}};

   int destWidth, destHeight;
   int angle_, roll, dir, pixelSize, pitch, width, height, N, dir_n_roll_n_mirror, force, create;
   int alphaOffset, resWidth, resHeight, resPixelSize, resPitch, resSizeX, resSizeY;
   int ofs0, ofs1, ofs2, ofs3, ph, xn, yn, ynS, ssX, ssY, xEnd, yEnd;
   double angle, zoomX, zoomY, widthZ, heightZ;
   double PI, FI, TAN, COTAN, SIN, COS, SIN_X, COS_X, SIN_Y, COS_Y;
   double xT1, xT2, xT3, xT4, yT1, yT2, yT3, yT4, xL1;
   double dispX, dispY, xTi1, yTi4, xx, yy, sUi, to, bndX, bndU, bndL;
   double sUmX, sUmY, sU, sL, sLb, dsU, dsL, sUx, sUy;
   double sx, sx_, sy, sy_, alpha, alpha_, beta;
   int columns, rows, left, right, run, ix, iy, idX, idY;
   double spanX, spanY, normfact, mid, val0, val1, val2, val3;
   double *weights;
   unsigned char *newImg, *transImg;
   unsigned char bg0, bg1, bg2, bg3;
   double sxsy, sxsy_, sx_sy, sx_sy_, xfX, xfY;
   int xf, xf2;
   Filter *filter;
   unsigned char *fromPtr,  *fromPtr0, *fromPtr1, *fromPtr2, *fromPtr3, *toPtr, *srcPixelPtr;
   unsigned char *destPtr, *destLinePtr, *resPixelPtr;

   /*  Do not work in vain */
   if ((compRule != TK_PHOTO_COMPOSITE_OVERLAY) && (compRule != TK_PHOTO_COMPOSITE_SET)) panic("unknown compositing rule: %d", compRule);


   masterPtr = (PhotoMaster *) destHandle;

   /* First, we juggle around a bit in order to decompose the rotation into a tilt 
    * between -45 and 45 degrees (inclusive) and an integral number of 90 degree 
    * counter-clockwise flips. (Direction is as we see it on the screen, not 
    * relative to the canvas coordinate system!) Furthermore, we only consider
    * positive tilt in the rotation algorithm, negative tilt is achieved by mirroring
    * the source as well as (before inserting it into the target image) the result
    * of the transformation over the x-axis. */

   create = (masterPtr->width == 0) || (masterPtr->height == 0);
   force = create || (compRule == TK_PHOTO_COMPOSITE_SET);

   /* Tcl_GetTime(&TimingZero); */

   rotate = rotate - (int) (rotate / 360) * 360;
   angle = (rotate < 0) ? (rotate + 360) : rotate;
   angle_ = (int) angle;

   roll = angle_ / 90; if (angle_ - roll * 90 > 45) roll += 1;
   angle -= (double) roll * 90;

   dir = (angle < 0) ? -1 : 1; angle = dir * angle;

   /* These are cumbersome but unavoidable */
   if ((startX >= srcBlkPtr->width) || (startY >= srcBlkPtr->height) || (scaleX <= 0) || (scaleY <= 0)) return;
   if ((toX < 0) || (toY < 0)) return;

   if (startX < 0) startX += srcBlkPtr->width; if (endX <= 0) endX += srcBlkPtr->width;
   if (endX > srcBlkPtr->width) endX = srcBlkPtr->width; --endX;
   if (startY < 0) startY += srcBlkPtr->height; if (endY <= 0) endY += srcBlkPtr->height; 
   if (endY > srcBlkPtr->height) endY = srcBlkPtr->height; --endY;


   xf = smoothedge;
   weights = (double *) Tcl_Alloc(2048); /* This buffer is also used elsewhere */

   if (background == (XColor *) NULL) {
      bg0 = '\xFF'; bg1 = '\xFF'; bg2 = '\xFF'; bg3 = '\xFF';
   } else {
      bg0 = (unsigned char) ((background->red) >> 8);
      bg1 = (unsigned char) ((background->green) >> 8);
      bg2 = (unsigned char) ((background->blue) >> 8);
   }

   /* If filtering is specifed and resizing is requested we create the filtered/scaled
      image and use it as the source for further rotation*/

   newImg = NULL;
   if ((filtername == NULL) || ((scaleX >= 1) && (scaleY >= 1))) goto afterFiltering;

   for (filter = filters; filter != NULL; filter = filter->next) {
      if (strcmp(filter->name, filtername) == 0) break;
   }
   if (filter == NULL) goto afterFiltering;

   xf2 = 2 * xf; xfX = blur * xf / scaleX; xfY = blur * xf / scaleY;

   width = endX - startX + 1;
   height = endY - startY + 1;
   srcPixelPtr = srcBlkPtr->pixelPtr + startX * srcBlkPtr->pixelSize + startY * srcBlkPtr->pitch;
   pixelSize = srcBlkPtr->pixelSize; pitch = srcBlkPtr->pitch;
   zoomX = scaleX; zoomY = scaleY;

   /* Tcl_GetTime(&TimingFiltStart) */;

   spanX = blur * filter->span / zoomX;
   spanY = blur * filter->span / zoomY;
   columns = (int) (width * zoomX + 0.5);
   rows = (int) (height * zoomY + 0.5);

   transImg = Tcl_Alloc(4 * (columns + xf2) * height);

   for (ix = - xf; ix < columns + xf; ix++) {
      mid = (double) (ix + 0.5) / zoomX;
      left = (int) MAX(mid - spanX + 0.5, - xfX);
      right = (int) MIN(mid + spanX + 0.5, width + xfX);
      normfact = 0.0; run = right - left;
      for (N = 0; N < run; N++) {
        normfact += weights[N] = filter->proc(zoomX * (left + N - mid + 0.5) / blur);
      }
      normfact = 1 / normfact;
      for (N = 0; N < run; N++) {
        weights[N] *= normfact;
      }
      for (iy = 0; iy < height; iy++) {
         val0 = val1 = val2 = val3 = 0.0;
         for (N = 0; N < run; N++) {
            if (((left + N) < 0) || ((left + N) >= width)) {
               val0 += weights[N] * bg0; 
               val1 += weights[N] * bg1; 
               val2 += weights[N] * bg2; 
            } else {
               idX = iy * pitch + (left + N) * pixelSize;
               val0 += weights[N] * srcPixelPtr[idX]; 
               val1 += weights[N] * srcPixelPtr[idX + 1]; 
               val2 += weights[N] * srcPixelPtr[idX + 2]; 
            }
         }
         idY = 4 * (iy * (columns + xf2) + ix + xf);
         transImg[idY] = (unsigned char) ((val0 < 0) ? 0 : ((val0 > 255) ? 255 : val0));
         transImg[idY + 1] = (unsigned char) ((val1 < 0) ? 0 : ((val1 > 255) ? 255 : val1));
         transImg[idY + 2] = (unsigned char) ((val2 < 0) ? 0 : ((val2 > 255) ? 255 : val2));
         transImg[idY + 3] = 255;
      }

   } 

   columns += xf2;

   newImg = Tcl_Alloc(4 * columns * (rows + xf2));

   pixelSize = 4; pitch = 4 * columns;
   srcPixelPtr = transImg;

   for (iy = - xf; iy < rows + xf; iy++) {
      mid = (double) (iy + 0.5) / zoomY;
      left = (int) MAX(mid - spanY + 0.5, - xfY);
      right = (int) MIN(mid + spanY + 0.5, height + xfY);
      normfact = 0.0; run = right - left;
      for (N = 0; N < run; N++) {
        normfact += weights[N] = filter->proc(zoomY * (left + N - mid + 0.5) / blur);
      }
      normfact = 1 / normfact;
      for (N = 0; N < run; N++) {
        weights[N] *= normfact;
      }
      for (ix = 0; ix < columns; ix++) {
         val0 = val1 = val2 = val3 = 0.0;
         for (N = 0; N < run; N++) {
            if (((left + N) < 0) || ((left + N) >= height)) {
               val0 += weights[N] * bg0; 
               val1 += weights[N] * bg1; 
               val2 += weights[N] * bg2; 
            } else {
               idY = ix * pixelSize + (left + N) * pitch;
               val0 += weights[N] * srcPixelPtr[idY]; 
               val1 += weights[N] * srcPixelPtr[idY + 1]; 
               val2 += weights[N] * srcPixelPtr[idY + 2]; 
            }
         }
         idX = 4 * ((iy + xf) * columns + ix);
         newImg[idX] = (unsigned char) ((val0 < 0) ? 0 : ((val0 > 255) ? 255 : val0));
         newImg[idX + 1] = (unsigned char) ((val1 < 0) ? 0 : ((val1 > 255) ? 255 : val1));
         newImg[idX + 2] = (unsigned char) ((val2 < 0) ? 0 : ((val2 > 255) ? 255 : val2));
         newImg[idX + 3] = 255;
      }

   } 

rows += xf2;

   /* Tcl_GetTime(&TimingFiltEnd) */;

   srcBlkPtr->pixelPtr = newImg;
   scaleX = scaleY = 1.0;
   startX = 0; endX = columns - 1; startY = 0; endY = rows - 1;
   srcBlkPtr->pixelSize = 4; srcBlkPtr->pitch = 4 * columns;
   Tcl_Free((char*) transImg); transImg = NULL;

afterFiltering:
   /* Next, we set up the parameters of the algorithm related to the 90 degree
    * flips and the mirroring of the source image by computing the elements of the 
    * corresponding *Tk_PhotoImageBlock* stucture. */

   dir_n_roll_n_mirror = 16 * ((dir < 0) ? 1 : 0) + 4 * (roll % 4) + 2 * mirrorY + mirrorX;

   switch (sp[dir_n_roll_n_mirror] - 1) {
      case 0:
         srcPixelPtr = srcBlkPtr->pixelPtr
                     + startX * srcBlkPtr->pixelSize
                     + startY * srcBlkPtr->pitch;
      break;
      case 1:
         srcPixelPtr = srcBlkPtr->pixelPtr
                     + startX * srcBlkPtr->pixelSize
                     + endY * srcBlkPtr->pitch;
      break;
      case 2:
         srcPixelPtr = srcBlkPtr->pixelPtr
                     + endX * srcBlkPtr->pixelSize
                     + endY * srcBlkPtr->pitch;
      break;
      case 3:
         srcPixelPtr = srcBlkPtr->pixelPtr
                     + endX * srcBlkPtr->pixelSize
                     + startY * srcBlkPtr->pitch;
      break;
   }
   
   pixelSize = pxpx[dir_n_roll_n_mirror] * srcBlkPtr->pixelSize + pxpt[dir_n_roll_n_mirror] * srcBlkPtr->pitch;
   pitch = ptpx[dir_n_roll_n_mirror] * srcBlkPtr->pixelSize + ptpt[dir_n_roll_n_mirror] * srcBlkPtr->pitch;

   switch (roll % 2) {
      case 0:
         zoomX = scaleX; zoomY = scaleY;
         width = endX - startX;
         height = endY - startY;
      break;
      case 1:
         zoomX = scaleY; zoomY = scaleX;
         width = endY - startY;
         height = endX - startX;
      break;
   }

   /* Here we start preparations for the combined scale/rotate algorithm */

   widthZ = (scaleX <= 1.0) ? width * zoomX : (width - 1) * zoomX;
   heightZ = (scaleY <= 1.0) ? height * zoomY : (height - 1) * zoomY;

   PI = 4 * atan(1); FI = angle * PI / 180;
   COS = cos(FI); SIN = sin(FI);
   if (heightZ * SIN < 1) {COS = 1; SIN = 0;}
   TAN = SIN / COS; if (TAN != 0) COTAN = 1 / TAN;

   /* The source image is first centered around the origin of the coordinate system, then scaled
    * and finally rotated. The coordinates of the resulting four corner vertices are computed below.
    * (Again the y-axis is directed upwards and the x-axis to the right!) */
   xT4 = widthZ / 2.0 * COS - heightZ / 2.0 * SIN;
   yT4 = widthZ / 2.0 * SIN + heightZ / 2.0 * COS;
   xT1 = -widthZ / 2.0 * COS - heightZ / 2.0 * SIN;
   yT1 = -widthZ / 2.0 * SIN + heightZ / 2.0 * COS;
   xT3 = -xT1; yT3 = -yT1; xT2 = -xT4; yT2 = -yT4;

   /* Depending on the parity of the heigth and width of the source in pixels the pixel grid
    * coincides with the integer raster or is shifted by 0.5 in the y direction, x direction
    * or both. This should be taken into account when rounding an arbitrary coordinate to a
    * pixel position*/
   dispX = 0.5 * (width % 2);
   dispY = 0.5 * (height % 2);

      /* The leftmost pixel grid coordinate to the right of the leftmost vertex of the transformed image */
      xTi1 = (int) (xT1 - dispX) + dispX;
      /* The topmost pixel grid coordinate below the topmost vertex of the transformed image */
      yTi4 = (int) (yT4 + dispY) - dispY;
   
      /* However, there may not be pixel grid points within the transformed area with either of the above coordinates! */
      if (TAN != 0) {
        if ((int) (yT1 + (xTi1 - xT1) * TAN - dispX) == (int) (yT1 - (xTi1 - xT1) * COTAN - dispX)) xTi1 += 1;
        if ((int) (xT4 - (yT4 - yTi4) * COTAN + dispY) == (int) (xT4 + (yT4 - yTi4) * TAN + dispY)) yTi4 -= 1;
      }   
      /* Size and rows/columns of the transformed image. */
      resSizeX = (int) (- 2 * xTi1); resSizeY = (int) (2 * yTi4); 
      resWidth = resSizeX + 1; resHeight = resSizeY + 1;
     
   /* We have to steal a glance at the target image metrics before we can proceed.
      The task is to determine whether clipping by the target image should be applied.
      If yes bounds are set up which limit the cycles of the transformation only to those
      pixels that fall within the target. The width as well as the height and pitch
      of the resulting image is also computed.
    */

   destWidth = toXend - toX; destHeight = toYend - toY;
   if (destWidth <= 0 || toXend < 0 || destHeight <= 0 || toYend < 0) {destWidth = resWidth;  destHeight = resHeight;}
   xEnd = toX + destWidth;  xEnd = (masterPtr->userWidth != 0) ? MIN(xEnd, masterPtr->userWidth) : xEnd;
   yEnd = toY + destHeight; yEnd = (masterPtr->userHeight != 0) ? MIN(yEnd, masterPtr->userHeight) : yEnd;
   destWidth = xEnd - toX; destHeight = yEnd -toY;

   /*FROM *Tk_PhotoPutZoomedBlock* */

   if ((xEnd > masterPtr->width) || (yEnd > masterPtr->height)) {
      int sameSrc = (srcBlkPtr->pixelPtr == masterPtr->pix32);
      Tk_PhotoSetSize(interp, masterPtr, MAX(xEnd, masterPtr->width),
          MAX(yEnd, masterPtr->height));
      if (sameSrc) {
          srcBlkPtr->pixelPtr = masterPtr->pix32;
      }
   }

   if ((toY < masterPtr->ditherY) || ((toY == masterPtr->ditherY)
         && (toX < masterPtr->ditherX))) {
      /*
       * The dithering isn't correct past the start of this block.
       */

      masterPtr->ditherX = toX;
      masterPtr->ditherY = toY;
   }

   /*
    * If this image block could have different red, green and blue
    * components, mark it as a color image.
    */

   alphaOffset = srcBlkPtr->offset[3];
   if ((alphaOffset >= srcBlkPtr->pixelSize) || (alphaOffset < 0)) {
      alphaOffset = 0;
   }

   if (((srcBlkPtr->offset[1] - srcBlkPtr->offset[0]) != 0) || ((srcBlkPtr->offset[2] - srcBlkPtr->offset[0]) != 0)) {
      masterPtr->flags |= COLOR_IMAGE;
   }
   
   /* Now we have sufficient data to complete the *Tk_PhotoImageBlock* structure for the resulting
    * transformed image. */

   resPixelSize = 4;
   resPitch = masterPtr->width * 4;
   resPixelPtr = masterPtr->pix32 + toX * 4 + toY * resPitch;

   /* If the rotation angle is negative the result of the transformation has to be mirrored over the
      x-axis. This is taken care by reversing the sign of the pitch and repositionig the start of the
      pixel array. */
   if (dir < 0) resPixelPtr += (resHeight - 1) * resPitch;
   resPitch = dir * resPitch;

   ofs0 = srcBlkPtr->offset[0]; ofs1 = srcBlkPtr->offset[1];
   ofs2 = srcBlkPtr->offset[2]; ofs3 = srcBlkPtr->offset[3];

   bndX = 4 * resSizeX;
   if (resWidth > destWidth) bndX = 4 * (destWidth - 1);

   bndL = - resSizeY / 2.0; bndU = resSizeY / 2.0;
   if (resHeight > destHeight) {
      if (dir > 0) {
         bndL = resSizeY / 2.0 - destHeight + 1;
      } else {
         bndU = - resSizeY / 2.0 + destHeight - 1;
      }
   }

   /* Here we commence in earnest.  */

   /* The principle of the algorithm is simple. We iterate over the pixels lying within or on the boundary
      of the area of the scaled and/or rotated the image. At each step the corresponding pixel position is
      rotated/scaled/translated back to its originating position within the source image. Then the pixel's
      color is computed as a weighted avarage of the colors of the four pixels that surround the resulting
      position. The transformation is executed incrementally in order to reduce the necessary computation
      in the internal, y direction, iteration to the necessary minimum. */


   /* This takes care of zooming */
   COS_X = COS / zoomX; SIN_X = SIN / zoomX;
   COS_Y = COS / zoomY; SIN_Y = SIN / zoomY;

   /* The starting position for the backward transformation */
   sUmX = width / 2.0 + (xTi1 - 1) * COS_X;
   sUmY = height / 2.0 - (xTi1 - 1) * SIN_Y;

   /* Tcl_GetTime(&TimingStart); */

   /* The interim of the area of the transformed image is scanned from left to write in the
      x direction and at each x coordinate from top to bottom in the y direction. The iteration
      is devided into four runs determined by the x coordinates of the four vertices. */

   xL1 = (xT2 < xT4) ? xT2 : xT4;
   for (xx = xTi1, ph = 0; ph < 4; ++ph) {
      switch (ph) {
         case 0:
            if (TAN == 0) continue;
            sU = yT1 + (xx - xT1) * TAN;
            sL = yT1 - (xx - xT1) * COTAN;
            to = xL1; dsU = TAN; dsL = - COTAN;
            break;   
         case 1:
            sU = yT1 + (xx - xT1) * TAN;
            sL = yT2 + (xx - xT2) * TAN;
            to = xT4; dsU = TAN; dsL = TAN;
            break;   
         case 2:
            if (TAN == 0) continue;
            sU = yT4 - (xx - xT4) * COTAN;
            sL = yT1 - (xx - xT1) * COTAN;
            to = xT2; dsU = - COTAN; dsL = - COTAN;
            break;   
         case 3:
            if (TAN == 0) continue;
            sU = yT4 - (xx - xT4) * COTAN;
            sL = yT2 + (xx - xT2) * TAN;
            to = xT3; dsU = - COTAN; dsL = TAN;
            break;   
      }

      /* For the record. Compiled with VC++6.0spk5 and run on win2k the transformation of a
         2M pixel 1168x1760 picture on a 550MHz Celeron with SDRAM takes 1.98 to 2.02 sec;
         on a 2.4GHz Pentium with DDR RAM it requires 0.48 sec.

         In comparison: on the former dithering takes 2.6 sec for 16 bit HighColor and 1.26 sec
         for 24 bit TrueColor. For the faster Pentium dithering requires 1.08 sec for 16 bit
         HighColor. The faster notebook had only 32 bit TrueColor on which Tk had paniced!
       */
         
      for ( ; xx < to; ++xx, sU = sU + dsU, sL = sL + dsL) {
         sUi = (int) (sU + dispY) - dispY - ((sU < 0) ? 1 : 0);
         if (sUi > bndU) sUi = bndU;
         sLb = (sL < bndL) ?  bndL : sL;

         sUmX = sUmX + COS_X;
         sUmY = sUmY - SIN_Y;

         sUx = sUmX + (sUi + 1) * SIN_X;
         sUy = sUmY + (sUi + 1) * COS_Y;

         xn = (int) (resSizeX / 2.0 + xx + 0.25) * 4; if (xn > bndX) break;  
         ynS = yn = (int) (resSizeY / 2.0 - sUi + 0.25) * resPitch; 

         for (yy = sUi; yy >= sLb; --yy) {

            sUx = sUx - SIN_X;
            sUy = sUy - COS_Y;
            ssX = (int) sUx; ssY = (int) sUy;

            fromPtr = srcPixelPtr + pixelSize * ssX  + pitch * ssY;
            toPtr = resPixelPtr + xn + yn; yn += resPitch;

            fromPtr0 = fromPtr + ofs0;
            fromPtr1 = fromPtr + ofs1;
            fromPtr2 = fromPtr + ofs2;
            fromPtr3 = fromPtr + ofs3;


            sx = sUx - ssX; sx_ = 1 - sx;
            sy = sUy - ssY; sy_ = 1 - sy;
            sxsy = sx * sy; sx_sy = sx_ * sy;  sxsy_ = sx * sy_; sx_sy_ = sx_ * sy_;
            val0 = val1 = val2 = val3= 0;
               if ((ssX < 0) || (ssX > width) || (ssY < 0) || (ssY > height)) {
                  val0 += bg0 * sx_sy_; val1 += bg1 * sx_sy_; val2 += bg2 * sx_sy_; val3 += bg3 * sx_sy_; 
               } else {
                  val0 += *fromPtr0 * sx_sy_; val1 += *fromPtr1 * sx_sy_; val2 += sx_sy_ * *fromPtr2; val3 +=  sx_sy_* *fromPtr3;
               }
               if ((ssX < -1) || (ssX > (width - 1)) || (ssY < 0) || (ssY > height)) {
                  val0 += bg0 * sxsy_; val1 += bg1 * sxsy_; val2 += bg2 * sxsy_; val3 += bg3 * sxsy_; 
               } else {
                  val0 += *(fromPtr0 + pixelSize) * sxsy_; val1 += *(fromPtr1 + pixelSize) * sxsy_;
                  val2 += *(fromPtr2 + pixelSize) * sxsy_; val3 += *(fromPtr3 + pixelSize) * sxsy_;
               }
               if ((ssX < 0) || (ssX > width) || (ssY < -1) || (ssY > (height - 1))) {
                  val0 += bg0 * sx_sy; val1 += bg1 * sx_sy; val2 += bg2 * sx_sy; val3 += bg3 * sx_sy; 
               } else {
                  val0 += *(fromPtr0 + pitch) * sx_sy; val1 += *(fromPtr1 + pitch) * sx_sy;
                  val2 += *(fromPtr2 + pitch) * sx_sy; val3 += *(fromPtr3 + pitch) * sx_sy;
               }
               if ((ssX < -1) || (ssX > (width - 1)) || (ssY < -1) || (ssY > (height - 1))) {
                  val0 += bg0 * sxsy; val1 += bg1 * sxsy; val2 += bg2 * sxsy; val3 += bg3 * sxsy; 
               } else {
                  val0 += *(fromPtr0 + pitch + pixelSize) * sxsy; val1 += *(fromPtr1 + pitch + pixelSize) * sxsy;
                  val2 += *(fromPtr2 + pitch + pixelSize) * sxsy; val3 += *(fromPtr3 + pitch + pixelSize) * sxsy;
               }

            if (force) {
               *toPtr++ = (unsigned char) val0;
               *toPtr++ = (unsigned char) val1;
               *toPtr++ = (unsigned char) val2;
               *toPtr   = (unsigned char) val3;
            } else {
               alpha  = ((ssX < 0) || (ssX > width) || (ssY < 0) || (ssY > height)) ? 0 : *fromPtr3 / 255.0;
               alpha_  = 1 - alpha;
               if (*(toPtr + 3) == 255) {
                  *toPtr += (unsigned char) ((val0 - *toPtr++) * alpha);
                  *toPtr += (unsigned char) ((val1 - *toPtr++) * alpha);
                  *toPtr += (unsigned char) ((val2 - *toPtr++) * alpha);
                  *toPtr += 255;
               } else {
                  beta = *(toPtr + 3) / 255.0;
                  *toPtr = (unsigned char) (val0 * alpha - alpha_ * beta * *toPtr++);
                  *toPtr = (unsigned char) (val1 * alpha - alpha_ * beta * *toPtr++);
                  *toPtr = (unsigned char) (val2 * alpha - alpha_ * beta * *toPtr++);
                  *toPtr = (unsigned char) (*fromPtr3 + (255 - *fromPtr3) * beta);
               }
            }
         }
      }
   }



   /* Tcl_GetTime(&TimingEnd); */

   if (newImg != NULL) Tcl_Free(newImg); newImg = NULL;

   /* The finishing touches are from  *Tk_PhotoPutZoomedBlock* */

   /*
    * Recompute the region of data for which we have valid pixels to plot.
    */
    if (alphaOffset) {
      int x1, y1, end;

      if (compRule != TK_PHOTO_COMPOSITE_OVERLAY) {
         /*
          * Don't need this when using the OVERLAY compositing rule, which
          * always strictly increases the valid region.
          */
         TkRegion workRgn = TkCreateRegion();

         rect.x = toX;
         rect.y = toY;
         rect.width = destWidth;
         rect.height = 1;
         TkUnionRectWithRegion(&rect, workRgn, workRgn);
         TkSubtractRegion(masterPtr->validRegion, workRgn,
                          masterPtr->validRegion);
         TkDestroyRegion(workRgn);
      }

      destLinePtr = masterPtr->pix32 + (toY * masterPtr->width + toX) * 4 + 3;
      for (y1 = 0; y1 < destHeight; y1++) {
         x1 = 0;
         destPtr = destLinePtr;
         while (x1 < destWidth) {
            /* search for first non-transparent pixel */
            while ((x1 < destWidth) && !*destPtr) {
                x1++;
                destPtr += 4;
            }
            end = x1;
            /* search for first transparent pixel */
            while ((end < destWidth) && *destPtr) {
               end++;
               destPtr += 4;
            }
            if (end > x1) {
               rect.x = toX + x1;
               rect.y = toY + y1;
               rect.width = end - x1;
               rect.height = 1;
               TkUnionRectWithRegion(&rect, masterPtr->validRegion,
                                    masterPtr->validRegion);
            }
            x1 = end;
         }
         destLinePtr += masterPtr->width * 4;
      }
    } else {
      rect.x = toX;
      rect.y = toY;
      rect.width = destWidth;
      rect.height = destHeight;
      TkUnionRectWithRegion(&rect, masterPtr->validRegion,
                            masterPtr->validRegion);
    }

    /*
     * Update each instance.
     */

    Tk_DitherPhoto((Tk_PhotoHandle)masterPtr, toX, toY, destWidth, destHeight);

    /*
     * Tell the core image code that this image has changed.
     */

    Tk_ImageChanged(masterPtr->tkMaster, toX, toY, destWidth, destHeight, masterPtr->width,
         masterPtr->height);
 
    /* The image copy command now returns the coordinates of the vertices of the rotated/scaled image
       to help create a boundary rectangle (not the bounding box!) */
    yT1 = -yT1; yT2 = -yT2; yT3 = -yT3; yT4 = -yT4;
    xT1 += xT3; yT1 += yT2; xT2 += xT3; yT3 += yT2; xT4 += xT3; yT4 += yT2; yT2 += yT2; xT3 += xT3;
    if (dir < 0) {
        yy = (yT1 + yT3) / 2.0;
        yT1 = 2 * yy - yT1; yT4 = 2 * yy - yT2; yT3 = 2 * yy - yT3; yT2 = 2 * yy - yT4;
        xx = xT2; xT2 = xT4; xT4 = xx;
    }
    xT1 += toX; yT1 +=toY; xT2 += toX; yT2 +=toY; xT3 += toX; yT3 +=toY; xT4 += toX; yT4 +=toY;
    sprintf((char *)weights, "%.1f% .1f% .1f% .1f% .1f% .1f% .1f% .1f", xT1, yT1, xT2, yT2, xT3, yT3, xT4, yT4);

    Tcl_AppendResult(masterPtr->interp, (char *)weights, (char *) NULL);

    if (weights != NULL)
        Tcl_Free((char*) weights);

    weights = NULL;
}

}

#==================================================================
# TCL command wrappers
#==================================================================


##
## TCLCMD: image_copy source-image target-image ?options ...?
##   The options can be any of those accepted by the photo copy command,
##   with a few additions.  The additions are:
##       -scale X ?Y?       Scales the image by X and Y factors. Can be floats.
##       -rotate DOUBLE     Rotates the image by the given number of degrees.
##       -mirror STRING     Mirrors in "x", "y" or "-" (both) directions.
##       -filter ?STRING?   One of "Mitchell", "Lanczos", or "BlackmanSinc".
##       -blur DOUBLE       Blurs the image with the given blur radius.
##       -smoothedge INT    Anti-alias the edges up to the given pixel width.
##
##  If only one value is given to the -scale option, then the Y scaling factor
##    will be equal to the X sfaling factor.
##  If no value is given to the -filter option, "Mitchell" is assumed.
##  If no -filter option is given at all, then Nearest Neighbor is used.
##  If the value given to -smoothedge is 0, then no edge smoothing is done.
##  The -edgesmooth option can only take values of 0, 1 or 2.
##

critcl::ccommand image_copy {dummy ip objc objv} {
    int index;
    struct SubcommandOptions options;
    Tk_PhotoImageBlock block;
    Tk_PhotoHandle srcHandle;
    Tk_PhotoHandle targHandle;

    index = 1;
    memset((VOID *) &options, 0, sizeof(options));
    options.zoomX = options.zoomY = 1;
    options.subsampleX = options.subsampleY = 1;
    options.scaleX = options.scaleY = 1;
    options.rotate = 0;
    options.mirrorX = options.mirrorY = 0;
    options.filtername = NULL;
    options.smoothedge = 0;
    options.blur = 0;
    options.name = NULL;
    options.name2 = NULL;
    options.compositingRule = TK_PHOTO_COMPOSITE_OVERLAY;
    if (ParseSubcommandOptions(&options, ip,
        OPT_FROM | OPT_TO | OPT_ZOOM | OPT_SUBSAMPLE | OPT_SHRINK |
        OPT_ROTATE | OPT_SCALE | OPT_MIRROR | OPT_FILTER | OPT_SMOOTHEDGE |
        OPT_BACKGROUND | OPT_COMPOSITE | OPT_BLUR, &index, objc, objv) != TCL_OK) {
        return TCL_ERROR;
    }
    if (options.background == NULL) {
        options.background = Tk_GetColor(ip, Tk_MainWindow(ip), Tk_GetUid("SystemButtonFace"));
    }
    if ((options.filtername == NULL) && (options.smoothedge != 0)) {
        options.filtername = "Mitchell";
    }

    if (options.blur != 0) {
        if(options.filtername == NULL) {
            options.filtername = "Mitchell";
        }
        if(options.blur < 1.0) {
            options.blur = 1.0;
        }
    } else {
        options.blur = 1.0;
    }
    if (options.name == NULL || options.name2 == NULL || index < objc) {
        Tcl_WrongNumArgs(ip, 2, objv,
            "source-image target-image ?-compositingrule rule? ?-from x1 y1 x2 y2? ?-to x1 y1 x2 y2? ?-zoom x y? ?-subsample x y? ?-background color? ?-scale x y? ?-rotate deg? ?-mirror x|y|-? ?-filter filtname? ?-blur val? ?-smoothedge val?");
        return TCL_ERROR;
    }

    /*
     * Look for the source image and get a pointer to its image data.
     * Check the values given for the -from option.
     */

    srcHandle = Tk_FindPhoto(ip, Tcl_GetString(options.name));
    if (srcHandle == NULL) {
        Tcl_AppendResult(ip, "image \"",
            Tcl_GetString(options.name), "\" doesn't",
            " exist or is not a photo image", (char *) NULL);
        return TCL_ERROR;
    }

    /*
     * Look for the target image.
     */

    targHandle = Tk_FindPhoto(ip, Tcl_GetString(options.name2));
    if (targHandle == NULL) {
        Tcl_AppendResult(ip, "image \"",
            Tcl_GetString(options.name2), "\" doesn't",
            " exist or is not a photo image", (char *) NULL);
        return TCL_ERROR;
    }

    Tk_PhotoGetImage(srcHandle, &block);

    Tk_PhotoPutResizedRotatedBlock(ip, targHandle, &block,
                                   options.toX, options.toY, options.toX2, options.toY2,
                                   options.fromX, options.fromY, options.fromX2, options.fromY2,
                                   options.scaleX, options.scaleY, options.rotate,
                                   options.mirrorX, options.mirrorY, options.filtername, options.smoothedge,
                                   options.blur, options.background, options.compositingRule);

    return TCL_OK;
}


# vim: set syntax=c ts=8 sw=4 nowrap expandtab: settings

