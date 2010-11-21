package require critcl
package provide mlcnc_critcl 1.0

critcl::clibraries -lm

#========================================================================
# C code implementations
#========================================================================

critcl::ccode {
#include <stdlib.h>
#include <math.h>
#define min(x,y) (x<y?x:y)
#define max(x,y) (x>y?x:y)


    /* Struct for representing a point. */
    typedef struct mlcnc_point_t {
        double x;
        double y;
    } mlcnc_point;


    /* Struct for representing a point in a path. */
    typedef struct mlcnc_pathpoint_t {
        struct mlcnc_pathpoint_t* next;
        struct mlcnc_pathpoint_t* prev;
        mlcnc_point pt;
    } mlcnc_pathpoint;


    /* Struct for representing a path. */
    typedef struct mlcnc_path_t {
        mlcnc_pathpoint *head;
        mlcnc_pathpoint *tail;
        mlcnc_pathpoint *curr;
        int curridx;
        int count;
        struct mlcnc_path_t* next;
        struct mlcnc_path_t* prev;
    } mlcnc_path;


    /* Struct for representing a list of paths. */
    typedef struct mlcnc_pathlist_t {
        mlcnc_path *head;
        mlcnc_path *tail;
        mlcnc_path *curr;
        int curridx;
        int count;
    } mlcnc_pathlist;


    /* returns the pathpoint referred to by position idx in the path. */
    mlcnc_pathpoint*
    mlcnc_path_idx(mlcnc_path* path, int idx)
    {
        int i;
        mlcnc_pathpoint* ptr;
        if (path->curr == NULL && path->count > 0) {
            path->curr = path->head;
            path->curridx = 0;
        }
        if (idx < 0) {
            /* Bad idx */
            return NULL;
        } else if (idx < path->curridx/2) {
            ptr = path->head;
            for (i = 0; i < idx; i++) {
                ptr = ptr->next;
            }
        } else if (idx <= path->curridx) {
            ptr = path->curr;
            for (i = path->curridx; i > idx; i--) {
                ptr = ptr->prev;
            }
        } else if (idx < (path->curridx+path->count)/2) {
            ptr = path->curr;
            for (i = path->curridx; i < idx; i++) {
                ptr = ptr->next;
            }
        } else if (idx < path->count) {
            ptr = path->tail;
            for (i = path->count-1; i > idx; i--) {
                ptr = ptr->prev;
            }
        } else {
            /* Bad idx */
            return NULL;
        }
        path->curr = ptr;
        path->curridx = idx;
        return ptr;
    }


    /* returns a pointer to the point referred to by position idx in the path. */
    mlcnc_point*
    mlcnc_path_point_get(mlcnc_path* path, int idx)
    {
        mlcnc_pathpoint* ptr;
        ptr = mlcnc_path_idx(path, idx);
        if (!ptr) {
            return NULL;
        }
        return &ptr->pt;
    }


    /* Sets the value of the point referred to by position idx in the path. */
    void
    mlcnc_path_point_set(mlcnc_path* path, int idx, mlcnc_point pt)
    {
        mlcnc_pathpoint* ptr;
        ptr = mlcnc_path_idx(path, idx);
        if (ptr) {
            ptr->pt = pt;
        }
    }


    /*
     *  Inserts a new point into the given path, before the point referred
     *  to by idx.  If idx is < 0 or after the end of the path, then the new
     *  point will be appended to the end of the path.
     */
    void
    mlcnc_path_point_insert(mlcnc_path* path, int idx, mlcnc_point pt)
    {
        mlcnc_pathpoint* nu;
        mlcnc_pathpoint* ptr;
        nu = (mlcnc_pathpoint*)malloc(sizeof(mlcnc_pathpoint));
        nu->pt = pt;
        ptr = mlcnc_path_idx(path, idx);
        if (ptr) {
            nu->prev = ptr->prev;
            nu->next = ptr;
            if (ptr->prev){
                ptr->prev->next = nu;
            } else {
                path->head = nu;
            }
            ptr->prev = nu;
        } else {
            /* insert at end */
            nu->next = NULL;
            nu->prev = path->tail;
            if (path->tail) {
                path->tail->next = nu;
            } else {
                path->head = nu;
            }
            path->tail = nu;
        }
        path->curr = nu;
        path->curridx = idx;
    }


    /* Removes and frees the pathpoint referred to by idx. */
    void
    mlcnc_path_point_delete(mlcnc_path* path, int idx)
    {
        mlcnc_pathpoint* ptr;
        ptr = mlcnc_path_idx(path, idx);
        if (ptr) {
            if (ptr->prev) {
                ptr->prev->next = ptr->next;
            } else {
                path->head = ptr->next;
            }
            if (ptr->next) {
                ptr->next->prev = ptr->prev;
            } else {
                path->tail = ptr->prev;
            }
            if (idx < path->curridx) {
                path->curridx--;
            } else if (idx == path->curridx) {
                if (ptr->next) {
                    path->curr = ptr->next;
                } else if (ptr->prev) {
                    path->curr = ptr->prev;
                    path->curridx--;
                } else {
                    path->curridx = -1;
                    path->curr = NULL;
                }
            }
            free(ptr);
        }
    }


    /* Deletes and frees all points in the given path. */
    void
    mlcnc_path_clear(mlcnc_path* path)
    {
        mlcnc_pathpoint* next;
        mlcnc_pathpoint* ptr = path->head;
        while (ptr) {
            next = ptr->next;
            free(ptr);
            ptr = next;
        }
        path->head = path->tail = path->curr = NULL;
        path->curridx = -1;
        path->count = 0;
    }


    /* Mallocs and initializes a new path struct. */
    mlcnc_path*
    mlcnc_path_create()
    {
        mlcnc_path* path = (mlcnc_path*)malloc(sizeof(mlcnc_path));
        path->head = path->tail = path->curr = NULL;
        path->curridx = -1;
        path->count = 0;
        path->next = path->prev = NULL;
        return path;
    }


    /* Frees a path struct and all its pathpoints. */
    void
    mlcnc_path_free(mlcnc_path* path)
    {
        mlcnc_path_clear(path);
        free(path);
    }



    /* Returns a pointer to the path in the pathlist referenced by idx. */
    mlcnc_path*
    mlcnc_pathlist_idx(mlcnc_pathlist* paths, int idx)
    {
        int i;
        mlcnc_path* ptr;
        if (paths->curr == NULL && paths->count > 0) {
            paths->curr = paths->head;
            paths->curridx = 0;
        }
        if (idx < 0) {
            /* Bad idx */
            return NULL;
        } else if (idx < paths->curridx/2) {
            ptr = paths->head;
            for (i = 0; i < idx; i++) {
                ptr = ptr->next;
            }
        } else if (idx <= paths->curridx) {
            ptr = paths->curr;
            for (i = paths->curridx; i > idx; i--) {
                ptr = ptr->prev;
            }
        } else if (idx < (paths->curridx+paths->count)/2) {
            ptr = paths->curr;
            for (i = paths->curridx; i < idx; i++) {
                ptr = ptr->next;
            }
        } else if (idx < paths->count) {
            ptr = paths->tail;
            for (i = paths->count-1; i > idx; i--) {
                ptr = ptr->prev;
            }
        } else {
            /* Bad idx */
            return NULL;
        }
        paths->curr = ptr;
        paths->curridx = idx;
        return ptr;
    }


    /* Inserts a path into the pathlist, before the idx position. */
    void
    mlcnc_pathlist_path_insert(mlcnc_pathlist* paths, int idx, mlcnc_path* nu)
    {
        mlcnc_path* ptr;
        ptr = mlcnc_pathlist_idx(paths, idx);
        if (ptr) {
            nu->prev = ptr->prev;
            nu->next = ptr;
            if (ptr->prev){
                ptr->prev->next = nu;
            } else {
                paths->head = nu;
            }
            ptr->prev = nu;
        } else {
            /* insert at end */
            nu->next = NULL;
            nu->prev = paths->tail;
            if (paths->tail) {
                paths->tail->next = nu;
            } else {
                paths->head = nu;
            }
            paths->tail = nu;
        }
        paths->curr = nu;
        paths->curridx = idx;
    }


    /*  Removes a path from position idx of the pathlist.  Returns the path
     *  that was removed.  The caller is responsible for freeing the path.
     */
    mlcnc_path*
    mlcnc_pathlist_path_remove(mlcnc_pathlist* paths, int idx)
    {
        mlcnc_path* ptr;
        ptr = mlcnc_pathlist_idx(paths, idx);
        if (ptr) {
            if (ptr->prev) {
                ptr->prev->next = ptr->next;
            } else {
                paths->head = ptr->next;
            }
            if (ptr->next) {
                ptr->next->prev = ptr->prev;
            } else {
                paths->tail = ptr->prev;
            }
            if (idx < paths->curridx) {
                paths->curridx--;
            } else if (idx == paths->curridx) {
                if (ptr->next) {
                    paths->curr = ptr->next;
                } else if (ptr->prev) {
                    paths->curr = ptr->prev;
                    paths->curridx--;
                } else {
                    paths->curridx = -1;
                    paths->curr = NULL;
                }
            }
            ptr->next = ptr->prev = NULL;
            return ptr;
        }
        return NULL;
    }


    /* Deletes and frees all paths from the pathlist, leaving it empty. */
    void
    mlcnc_pathlist_clear(mlcnc_pathlist* paths)
    {
        mlcnc_path* next;
        mlcnc_path* ptr = paths->head;
        while (ptr) {
            next = ptr->next;
            mlcnc_path_free(ptr);
            ptr = next;
        }
        paths->head = paths->tail = paths->curr = NULL;
        paths->curridx = -1;
        paths->count = 0;
    }


    /* Allocates and initializes a new pathlist struct. */
    mlcnc_pathlist*
    mlcnc_pathlist_create()
    {
        mlcnc_pathlist* nu = (mlcnc_pathlist*)malloc(sizeof(mlcnc_pathlist));
        nu->head = nu->tail = nu->curr = NULL;
        nu->curridx = -1;
        nu->count = 0;
        return nu;
    }


    /* Frees a pathlist and all its contained paths and points. */
    void
    mlcnc_pathlist_free(mlcnc_pathlist* paths)
    {
        mlcnc_pathlist_clear(paths);
        free(paths);
    }






    /* Returns true if all three points are on the same line. */
    int
    mlcnc_c_points_are_collinear(
        double x1, double y1,
        double x2, double y2,
        double x3, double y3
    ) {
        double dx1, dy1, dx2, dy2;

        if (fabs(x2-x1) < 1e-10) {
            /* First pair are vertical to each other */
            if (fabs(y2-y1) < 1e-10) {
                /* First pair are the same point. */
                return 1;
            }
            if (fabs(x3-x2) < 1e-10) {
                /* Second pair are also vertical to each other */
                return 1;
            }
            /* Not collinear. */
            return 0;
        } else if (fabs(x3-x2) < 1e-10) {
            /* Second pair are vertical to each other */
            if (fabs(y3-y1) < 1e-10) {
                /* Second pair are the same point. */
                return 1;
            }
            /* Not collinear. */
            return 0;
        }

        /* Check if they have the same slope. */
        dx1 = x2-x1;
        dy1 = y2-y1;
        dx2 = x3-x2;
        dy2 = y3-y2;
        if (fabs((dy1/dx1) - (dy2/dx2)) < 1e-10) {
            return 1;
        }

        /* Not collinear. */
        return 0;
    }



    /* Returns true if the given lines are not parallel.
     * x and y are set to the intersection point of the extended lines,
     * if there is one.  The intersection point might not be inside
     * either line segment. */
    int
    mlcnc_c_find_line_intersection(
        double x1, double y1,
        double x2, double y2,
        double x3, double y3,
        double x4, double y4,
        double *x, double *y
    ) {
        double ua, denom;

        /* Calculate the denominator used to find the intersection point. */
        denom = (y4-y3)*(x2-x1) - (x4-x3)*(y2-y1);

        if (denom > -1e-10 && denom < 1e-10) {
            /* Either lines are parallel or at least one line is zero length. */

            if (fabs(x2-x1)+fabs(y2-y1) < 2e-10) {
                /* First line is zero length */
                if (fabs(x4-x3)+fabs(y4-y3) < 2e-10) {
                    /* Both lines are zero length! */
                    if (fabs(x3-x1)+fabs(y3-y1) < 2e-10) {
                        /* Both zero-length lines are the same! */
                        *x = x1;
                        *y = y1;
                        return 1;
                    } else {
                        /* Both lines are points, and they don't intersect. */
                        return 0;
                    }
                } else if (mlcnc_c_points_are_collinear(x1, y1, x3, y3, x4, y4)) {
                    /* Second line intersects the point that is the first line. */
                    *x = x1;
                    *y = y1;
                    return 1;
                } else {
                    /* No intersection. */
                    return 0;
                }
            } else if (fabs(x4-x3)+fabs(y4-y3) < 2e-10) {
                /* Second line is zero length */
                if (mlcnc_c_points_are_collinear(x1, y1, x2, y2, x4, y4)) {
                    /* But the first line intersects it. */
                    *x = x4;
                    *y = y4;
                    return 1;
                } else {
                    /* No intersection. */
                    return 0;
                }
            }

            /* At this point, all zero length lines have been handled. */
            /* Only parallel lines remain. */

            /* Check to see if endpoints match up */
            if (fabs(x3-x2)+fabs(y3-y2) < 2e-10) {
                *x = x2;
                *y = y2;
                return 1;
            }
            if (fabs(x4-x2)+fabs(y4-y2) < 2e-10) {
                *x = x2;
                *y = y2;
                return 1;
            }
            if (fabs(x3-x1)+fabs(y3-y1) < 2e-10) {
                *x = x1;
                *y = y1;
                return 1;
            }
            if (fabs(x4-x1)+fabs(y4-y1) < 2e-10) {
                *x = x1;
                *y = y1;
                return 1;
            }

            /* All lines with matching endpoints have been handled. */
            /* Check for collinear lines. */
            if (mlcnc_c_points_are_collinear(x1, y1, x2, y2, x4, y4) &&
                mlcnc_c_points_are_collinear(x1, y1, x3, y3, x4, y4)
            ) {
                /* Lines are collinear.  Return the midpoint. */
                double maxx = max(x1, max(x2, max(x3, x4)));
                double maxy = max(y1, max(y2, max(y3, y4)));
                double minx = min(x1, min(x2, min(x3, x4)));
                double miny = min(y1, min(y2, min(y3, y4)));
                *x = (maxx + minx) / 2.0;
                *y = (maxy + miny) / 2.0;
                return 1;
            }

            /* Lines are parallel and not collinear.  No intersection. */
            return 0;
        }

        /* Finish calculating intersection point. */
        ua = ((x4-x3)*(y1-y3) - (y4-y3)*(x1-x3)) / denom;
        *x = x1 + ua * (x2-x1);
        *y = y1 + ua * (y2-y1);

        return 1;
    }



    /* Returns true if the given line segments intersect */
    int
    mlcnc_c_line_segments_intersect(
        double x1, double y1, /* line seg 1 */
        double x2, double y2,
        double x3, double y3, /* line seg 2 */
        double x4, double y4
    ) {
        double x, y;

        /* Do fast test to see if line segments aren't even near each other. */
        if (min(x1,x2) > max(x3,x4)+1e-10) {
            return 0;
        }
        if (max(x1,x2) < min(x3,x4)-1e-10) {
            return 0;
        }
        if (min(y1,y2) > max(y3,y4)+1e-10) {
            return 0;
        }
        if (max(y1,y2) < min(y3,y4)-1e-10) {
            return 0;
        }

        /* Get the intersection point as if the lines were extended. */
        if (!mlcnc_c_find_line_intersection(x1,y1, x2,y2, x3,y3, x4,y4, &x,&y)) {
            return 0;
        }

        /* Is the intersection within the bounds of first segment? */
        if (x < min(x1,x2)-1e-10 || x > max(x1,x2)+1e-10) {
            return 0;
        }
        if (y < min(y1,y2)-1e-10 || y > max(y1,y2)+1e-10) {
            return 0;
        }

        /* Is the intersection within the bounds of second segment? */
        if (x < min(x3,x4)-1e-10 || x > max(x3,x4)+1e-10) {
            return 0;
        }
        if (y < min(y3,y4)-1e-10 || y > max(y3,y4)+1e-10) {
            return 0;
        }

        /* Yay!  Line segments intersect. */
        return 1;
    }



    /* Finds the distance between the given point and the closest part
     * of the given line segment. */
    double
    mlcnc_c_line_segment_dist_from_point(
        double x1, double y1,
        double x2, double y2,
        double px, double py
    ) {
        double dx, dy, x, y, pdist, d1, d2, dt;

        dx = x2 - x1;
        dy = y2 - y1;

        if (fabs(dx) < 1e-10) {
            /* Line is vertical. */
            x = x1;
            y = py;
            pdist = fabs(px-x1);
        } else if (fabs(dy) < 1e-10) {
            /* Line is horizontal. */
            x = px;
            y = y1;
            pdist = fabs(py-y1);
        } else {
            /* Line is slanted. */
            double m1, m2, c1, c2;
            m1 = dy/dx;
            m2 = -dx/dy;
            c1 = y1 - m1*x1;
            c2 = py - m2*px;
            x = (c2 - c1)/(m1 - m2);
            y = m1*x + c1;
            pdist = hypot(y-py,x-px);
        }

        /* Check if the perpendicular line through the given point
         * intersects with the original line outside of the segment. */
        d1 = hypot(y1-y,x1-x);
        d2 = hypot(y2-y,x2-x);
        dt = hypot(y2-y1,x2-x1);
        if (fabs(d1+d2-dt) < 1e-10) {
            /* Return perpendicular intersect point */
            return pdist;
        } else if (d1 < d2) {
            /* First endpoint is closer */
            return hypot(py-y1,px-x1);
        } else {
            /* Second endpoint is closer */
            return hypot(py-y2,px-x2);
        }
    }



    /* Returns the closest distance from the given point to the given path. */
    double
    mlcnc_c_path_min_dist_from_point(
        mlcnc_point pt,
        mlcnc_path* path
    ) {
        int havemin = 0;
        int numpoints = 0;
        int i;
        double dist, mindist = 0.0;
        double x0, y0, x1, y1;
        mlcnc_pathpoint *ptr;

        numpoints = path->count;
        /* TODO: check for empty path */

        ptr = path->head;
        x0 = ptr->pt.x;
        y0 = ptr->pt.y;
        while ((ptr = ptr->next) != NULL) {
            x1 = ptr->pt.x;
            y1 = ptr->pt.y;
            dist = mlcnc_c_line_segment_dist_from_point(x0, y0,  x1, y1,  pt.x, pt.y);
            if (!havemin || dist < mindist) {
                mindist = dist;
                havemin = 1;
            }
            x0 = x1;
            y0 = y1;
        }

        return mindist;
    }



    /* Returns the coords of the closest explicit point in the given path
     * to the given point.  This only includes path points, and does not
     * return closer interpolated line segment points. */
    mlcnc_point
    mlcnc_c_closest_point_on_path(
        mlcnc_point pt,
        mlcnc_path* path
    ) {
        int havemin = 0;
        int i;
        int numpoints = path->count;
        double dist, mindist = 0.0;
        mlcnc_pathpoint* ptr;
        mlcnc_point minpt;

        ptr = path->head;
        while (ptr) {
            dist = hypot(ptr->pt.x - pt.x, ptr->pt.y - pt.y);
            if (!havemin || dist < mindist) {
                minpt = ptr->pt;
                mindist = dist;
                havemin = 1;
            }
            ptr = ptr->next;
        }

        return minpt;
    }



    /* Deletes all repeated points in a path. */
    mlcnc_path*
    mlcnc_path_remove_repeated_points(
        mlcnc_path* path
    ) {
        double x0, y0;
        int i;
        mlcnc_pathpoint* ptr;
        mlcnc_pathpoint* next;

        ptr = path->head;
        if (!ptr) {
            return path;
        }
        x0 = ptr->pt.x;
        y0 = ptr->pt.y;
        i = 1;
        ptr = ptr->next;
        while (ptr) {
            while (path->count > i && abs(ptr->pt.x - x0) < 1e-6 &&  abs(ptr->pt.y - y0) < 1e-6) {
                mlcnc_path_point_delete(path, i);
                ptr = mlcnc_path_idx(path, i);
            }
            next = ptr->next;
            i++;
        }
        return path;
    }


    /* Closes the given path by joining the endpoint to the start point. */
    mlcnc_path*
    mlcnc_path_close(
        mlcnc_path* path
    ) {
        mlcnc_point pt0;
        mlcnc_point pte;
        if (path->count < 2) {
            return path;
        }
        if (!path->head) {
            return path;
        }
        pt0 = path->head->pt;
        pte = path->tail->pt;
        if (abs(pt0.x-pte.x) > 1e-6 || abs(pt0.y-pte.y) > 1e-6) {
            mlcnc_path_point_insert(path, -1, pt0);
        }
        return path;
    }


    /* Return true if the point is inside the given closed path. */
    /* Assumes the given path is, in fact, closed. */
    int
    mlcnc_path_encloses_point(
        mlcnc_path* path,
        mlcnc_point pt
    ) {
        double isx, isy;
        double osx, osy;
        double x0, y0, x1, y1;
        mlcnc_pathpoint* ptr;
        int isects = 0;

        ptr = path->head;
        if (!ptr) {
            return 0;
        }
        osx = ptr->pt.x;
        ptr = ptr->next;
        while (ptr) {
            if (ptr->pt.x > osx) {
                osx = ptr->pt.x;
            }
            ptr = ptr->next;
        }

        isx = pt.x;
        isy = pt.y;
        osx = osx + 1e-3;
        osy = pt.y;

        ptr = path->head;
        x0 = ptr->pt.x;
        y0 = ptr->pt.y;
        ptr = ptr->next;
        while (ptr) {
            x1 = ptr->pt.x;
            y1 = ptr->pt.y;
            if (abs(x1-x0)+abs(y1-y0) < 1e-6) {
                ptr = ptr->next;
                continue;
            }
            if (mlcnc_c_line_segments_intersect(isx, isy, osx, osy, x0, y0, x1, y1)) {
                double intx, inty;
                mlcnc_c_find_line_intersection(isx, isy, osx, osy, x0, y0, x1, y1, &intx, &inty);
                if (abs(intx-x1) >= 1e-6 || abs(inty-y1) >= 1e-6) {
                    isects++;
                }
            }
            x0 = x1;
            y0 = y1;
            ptr = ptr->next;
        }

        return (isects & 0x1);
    }


    /* Separates a self-crossing closed path into separate non-crossing
     *   subpaths.  Appends all found subpaths to the given pathlist.
     *   Caller is responsible for allocating, initializing, and freeing
     *   of the pathlist.
     */
    mlcnc_pathlist*
    mlcnc_path_separate_crossovers(
        mlcnc_path* path,
        mlcnc_pathlist* outPaths
    ) {
        double sx0, sy0, sx1, sy1;
        double x0, y0, x1, y1;
        mlcnc_pathpoint* ptr;
        mlcnc_pathpoint* nupt;
        mlcnc_path* nupath;

        ptr = path->head;
        x0 = ptr->pt.x;
        y0 = ptr->pt.y;
        ptr = ptr->next;
        while (ptr) {
            x1 = ptr->pt.x;
            y1 = ptr->pt.y;

            x0 = x1;
            y0 = y1;
            ptr = ptr->next;
        }
        return outPaths;
    }

}



#==================================================================
# TCL command wrappers
#==================================================================


##
## TCLCMD: mlcnc_find_line_intersection x1 y1 x2 y2  x3 y3 x4 y4
##
##   Finds the intersection point for the two given line lines, defined
##     by the line segments (x1,y1) (x2,y2) and (x3,y3) (x4,y4).
##     This will project the segments out to see where they would join
##     if they don't join within the line segments.
##
##   Returns {} if the lines are parallel or identical.  Otherwise,
##     returns a list containing the X and Y coords of the intersection.
##

critcl::cproc mlcnc_find_line_intersection {Tcl_Interp* ip double x1 double y1 double x2 double y2 double x3 double y3 double x4 double y4} Tcl_Obj* {
    double x, y;
    int foundint = 0;
    Tcl_Obj *retval;
    Tcl_Obj *retvals[2];

    foundint = mlcnc_c_find_line_intersection(x1, y1,  x2, y2,  x3, y3,  x4, y4,  &x, &y);
    if (foundint) {
        retvals[0] = Tcl_NewDoubleObj(x);
        retvals[1] = Tcl_NewDoubleObj(y);
        retval = Tcl_NewListObj(2, retvals);
    } else {
        retval = Tcl_NewListObj(0, retvals);
    }
    Tcl_IncrRefCount(retval);

    return retval;
}



##
## TCLCMD: mlcnc_lines_intersect x1 y1 x2 y2  x3 y3 x4 y4
##
##   Returns true if the two given line segments (x1,y1) (x2,y2) and
##     (x3,y3) (x4,y4) intersect.  This will only return true if the
##     lines intersect within the line segments.
##

critcl::cproc mlcnc_lines_intersect {double x1 double y1 double x2 double y2 double x3 double y3 double x4 double y4} int {
    return mlcnc_c_line_segments_intersect(x1, y1,  x2, y2,  x3, y3,  x4, y4);
}


##
## TCLCMD: mlcnc_line_dist_from_point x1 y1  x2 y2  px py
##
##   Returns the absolute closest distance (FP double) that the point (px,py) is
##     from the line segment (x1,y1) (x2,y2).  This does not extend the line
##     for purposes of the calculation.
##

critcl::cproc mlcnc_line_dist_from_point {double x1 double y1 double x2 double y2 double px double py} double {
    return mlcnc_c_line_segment_dist_from_point(x1, y1,  x2, y2,  px, py);
}



##
## TCLCMD: mlcnc_points_are_collinear x1 y1  x2 y2  x3 y3
##
##   Returns true if the three given points (x1,y1) (x2,y2) and (x3,y3) are
##     collinear (in a straight line) to within 1e-10 units.
##

critcl::cproc mlcnc_points_are_collinear {double x1 double y1 double x2 double y2 double x3 double y3} int {
    return mlcnc_c_points_are_collinear(x1, y1,  x2, y2,  x3, y3);
}



##
## TCLCMD: mlcnc_path_min_dist_from_point path px py
##
##   Returns the absolute closest distance (FP double) that the point (px,py) is
##     from the path given.  The path is a list of alternating X and Y
##     coordinates.
##

critcl::ccommand mlcnc_path_min_dist_from_point {dummy ip objc objv} {
    double dist, mindist = 0;
    int havemin = 0;
    int result, i;
    int coordslen;
    double px, py;
    double x0, y0, x1, y1;
    Tcl_Obj *retval = Tcl_GetObjResult(ip);
    Tcl_Obj *listElemPtr;


    if (objc < 4 || objc > 4) {
        Tcl_WrongNumArgs(ip, 1, objv, "{list of X and Y} pointx pointy");
        return TCL_ERROR;
    }

    /* get list of x y values */
    result = Tcl_ListObjLength(ip, objv[1], &coordslen);
    if (result != TCL_OK) {
        return TCL_ERROR ;
    }
    if (coordslen % 2 != 0) {
        Tcl_AppendStringsToObj(retval, " (expected an even number of values)", (char *) NULL);
        return TCL_ERROR ;
    }
    if (coordslen < 4) {
        Tcl_AppendStringsToObj(retval, " (expected at least 4 values)", (char *) NULL);
        return TCL_ERROR ;
    }


    /* Get double pointx */
    if (TCL_OK != Tcl_GetDoubleFromObj(ip, objv[2], &px)) {
        return TCL_ERROR ;
    }

    /* Get double pointy */
    if (TCL_OK != Tcl_GetDoubleFromObj(ip, objv[3], &py)) {
        return TCL_ERROR ;
    }

    Tcl_ListObjIndex(ip, objv[1], 0, &listElemPtr);
    result=Tcl_GetDoubleFromObj(ip, listElemPtr, &x0);
    /* Error if data item cannot be converted into  double */
    if (result != TCL_OK) {
        Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
        return TCL_ERROR ;
    }

    Tcl_ListObjIndex(ip, objv[1], 1, &listElemPtr);
    result=Tcl_GetDoubleFromObj(ip, listElemPtr, &y0);
    /* Error if data item cannot be converted into  double */
    if (result != TCL_OK) {
        Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
        return TCL_ERROR ;
    }

    for (i = 2; i < coordslen; i += 2) {
        Tcl_ListObjIndex(ip, objv[1], i, &listElemPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemPtr, &x1);
        /* Error if data item cannot be converted into  double */
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }

        Tcl_ListObjIndex(ip, objv[1], i+1, &listElemPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemPtr, &y1);
        /* Error if data item cannot be converted into  double */
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }

        dist = mlcnc_c_line_segment_dist_from_point(x0, y0,  x1, y1,  px, py);
        if (havemin == 0 || dist < mindist) {
            mindist = dist;
            havemin = 1;
        }

        x0 = x1;
        y0 = y1;
    }

    Tcl_SetDoubleObj(retval, mindist);

    return TCL_OK;
}



##
## TCLCMD: mlcnc_max_consecutive_path_point_dist path
##
##   Returns the distance of the closest consecutive points in the given path.
##     The path is a list of alternating X and Y coordinates.
##     The return value is a double, containing the distance.
##

critcl::ccommand mlcnc_max_consecutive_path_point_dist {dummy ip objc objv} {
    double dist, maxdist = 0;
    int result, i;
    int coordslen;
    double closex, closey;
    double x0, y0, x1, y1;
    Tcl_Obj *retval = Tcl_GetObjResult(ip);
    Tcl_Obj *retvals[2];
    Tcl_Obj *listElemPtr;
    Tcl_Obj *listElemXPtr;
    Tcl_Obj *listElemYPtr;


    if (objc < 2 || objc > 2) {
        Tcl_WrongNumArgs(ip, 1, objv, "{list of X and Y}");
        return TCL_ERROR;
    }

    /* get list of x y values */
    result = Tcl_ListObjLength(ip, objv[1], &coordslen);
    if (result != TCL_OK) {
        return TCL_ERROR ;
    }
    if (coordslen % 2 != 0) {
        Tcl_AppendStringsToObj(retval, " (expected an even number of values)", (char *) NULL);
        return TCL_ERROR ;
    }
    if (coordslen < 2) {
        Tcl_AppendStringsToObj(retval, " (expected at least 2 values)", (char *) NULL);
        return TCL_ERROR ;
    }

    Tcl_ListObjIndex(ip, objv[1], 0, &listElemXPtr);
    result=Tcl_GetDoubleFromObj(ip, listElemXPtr, &x0);
    /* Error if data item cannot be converted into  double */
    if (result != TCL_OK) {
        Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
        return TCL_ERROR ;
    }

    Tcl_ListObjIndex(ip, objv[1], 1, &listElemYPtr);
    result=Tcl_GetDoubleFromObj(ip, listElemYPtr, &y0);
    /* Error if data item cannot be converted into  double */
    if (result != TCL_OK) {
        Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
        return TCL_ERROR ;
    }

    for (i = 2; i < coordslen; i += 2) {
        Tcl_ListObjIndex(ip, objv[1], i, &listElemPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemPtr, &x1);
        /* Error if data item cannot be converted into  double */
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }

        Tcl_ListObjIndex(ip, objv[1], i+1, &listElemPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemPtr, &y1);
        /* Error if data item cannot be converted into  double */
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }

        dist = hypot(y1-y0, x1-x0);
        if (dist > maxdist) {
            maxdist = dist;
        }
        x0 = x1;
        y0 = y1;
    }

    Tcl_SetDoubleObj(retval, maxdist);

    return TCL_OK;
}



##
## TCLCMD: mlcnc_closest_point_on_path path px py
##
##   Returns the closest explicit point in the path to the given point (px,py).
##     The path is a list of alternating X and Y coordinates.
##     The return value is a two item list with the X and Y coordinate
##     of the closest point in the path.  This does not interpolate lines,
##     but only finds the closest point in the path list.
##

critcl::ccommand mlcnc_closest_point_on_path {dummy ip objc objv} {
    double dist, mindist = 0;
    int havemin = 0;
    int result, i;
    int coordslen;
    double px, py;
    double closex, closey;
    double x0, y0, x1, y1;
    Tcl_Obj *retval = Tcl_GetObjResult(ip);
    Tcl_Obj *retvals[2];
    Tcl_Obj *listElemPtr;


    if (objc < 4 || objc > 4) {
        Tcl_WrongNumArgs(ip, 1, objv, "{list of X and Y} pointx pointy");
        return TCL_ERROR;
    }

    /* get list of x y values */
    result = Tcl_ListObjLength(ip, objv[1], &coordslen);
    if (result != TCL_OK) {
        return TCL_ERROR ;
    }
    if (coordslen % 2 != 0) {
        Tcl_AppendStringsToObj(retval, " (expected an even number of values)", (char *) NULL);
        return TCL_ERROR ;
    }
    if (coordslen < 2) {
        Tcl_AppendStringsToObj(retval, " (expected at least 2 values)", (char *) NULL);
        return TCL_ERROR ;
    }


    /* Get double pointx */
    if (TCL_OK != Tcl_GetDoubleFromObj(ip, objv[2], &px)) {
        return TCL_ERROR ;
    }

    /* Get double pointy */
    if (TCL_OK != Tcl_GetDoubleFromObj(ip, objv[3], &py)) {
        return TCL_ERROR ;
    }

    for (i = 0; i < coordslen; i += 2) {
        Tcl_ListObjIndex(ip, objv[1], i, &listElemPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemPtr, &x0);
        /* Error if data item cannot be converted into  double */
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }

        Tcl_ListObjIndex(ip, objv[1], i+1, &listElemPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemPtr, &y0);
        /* Error if data item cannot be converted into  double */
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }

        dist = hypot(x0 - px, y0 - py);
        if (havemin == 0 || dist < mindist) {
            mindist = dist;
            closex = x0;
            closey = y0;
            havemin = 1;
        }
    }

    retvals[0] = Tcl_NewDoubleObj(closex);
    retvals[1] = Tcl_NewDoubleObj(closey);
    Tcl_SetListObj(retval, 2, retvals);

    return TCL_OK;
}



##
## TCLCMD: mlcnc_path_remove_repeated_points path
##
##   Returns the input path list after removing  all duplicate
##     consecutive X-Y coords.
##

critcl::ccommand mlcnc_path_remove_repeated_points {dummy ip objc objv} {
    double dist, mindist = 0;
    int havemin = 0;
    int result, i;
    int coordslen;
    double px, py;
    double closex, closey;
    double x0, y0, x1, y1;
    Tcl_Obj *retval;
    Tcl_Obj *obj;
    Tcl_Obj *listElemXPtr;
    Tcl_Obj *listElemYPtr;


    if (objc < 2 || objc > 2) {
        Tcl_WrongNumArgs(ip, 1, objv, "coordslist");
        return TCL_ERROR;
    }

    /* get list of x y values */
    result = Tcl_ListObjLength(ip, objv[1], &coordslen);
    if (result != TCL_OK) {
        return TCL_ERROR ;
    }
    if (coordslen % 2 != 0) {
        Tcl_AppendStringsToObj(retval, " (expected an even number of values)", (char *) NULL);
        return TCL_ERROR ;
    }
    if (coordslen < 4) {
        Tcl_AppendStringsToObj(retval, " (expected at least 4 values)", (char *) NULL);
        return TCL_ERROR ;
    }

    Tcl_ListObjIndex(ip, objv[1], 0, &listElemXPtr);
    result=Tcl_GetDoubleFromObj(ip, listElemXPtr, &x0);
    /* Error if data item cannot be converted into  double */
    if (result != TCL_OK) {
        Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
        return TCL_ERROR ;
    }

    Tcl_ListObjIndex(ip, objv[1], 1, &listElemYPtr);
    result=Tcl_GetDoubleFromObj(ip, listElemYPtr, &y0);
    /* Error if data item cannot be converted into  double */
    if (result != TCL_OK) {
        Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
        return TCL_ERROR ;
    }

    retval = Tcl_NewListObj(1, &listElemXPtr);
    Tcl_ListObjAppendElement(ip, retval, listElemYPtr);

    for (i = 2; i < coordslen; i += 2) {
        Tcl_ListObjIndex(ip, objv[1], i, &listElemXPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemXPtr, &x1);
        /* Error if data item cannot be converted into  double */
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }

        Tcl_ListObjIndex(ip, objv[1], i+1, &listElemYPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemYPtr, &y1);
        /* Error if data item cannot be converted into  double */
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }

        if (fabs(x1-x0)+fabs(y1-y0) > 2e-10) {
            Tcl_ListObjAppendElement(ip, retval, listElemXPtr);
            Tcl_ListObjAppendElement(ip, retval, listElemYPtr);

            x0 = x1;
            y0 = y1;
        }
    }

    Tcl_SetObjResult(ip, retval);

    return TCL_OK;
}


// vim: set syntax=c ts=4 sw=4 nowrap expandtab: settings

