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
    struct mlcnc_point_t {
        double x;
        double y;
    };
    typedef struct mlcnc_point_t mlcnc_point;


    /* Struct for representing a point in a path. */
    struct mlcnc_pathpoint_t {
        struct mlcnc_pathpoint_t* next;
        struct mlcnc_pathpoint_t* prev;
        mlcnc_point pt;
    };
    typedef struct mlcnc_pathpoint_t mlcnc_pathpoint;


    /* Struct for representing a path. */
    struct mlcnc_path_t {
        mlcnc_pathpoint *head;
        mlcnc_pathpoint *tail;
        mlcnc_pathpoint *curr;
        int curridx;
        int count;
        struct mlcnc_path_t* next;
        struct mlcnc_path_t* prev;
    };
    typedef struct mlcnc_path_t mlcnc_path;


    /* Struct for representing a list of paths. */
    struct mlcnc_pathlist_t {
        mlcnc_path *head;
        mlcnc_path *tail;
        mlcnc_path *curr;
        int curridx;
        int count;
    };
    typedef struct mlcnc_pathlist_t mlcnc_pathlist;


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
        double x3, double y3,
        double tolerance
    ) {
        double dx1, dy1, dx2, dy2;

        if (fabs(x2-x1) < tolerance) {
            /* First pair are vertical to each other */
            if (fabs(y2-y1) < tolerance) {
                /* First pair are the same point. */
                return 1;
            }
            if (fabs(x3-x2) < tolerance) {
                /* Second pair are also vertical to each other */
                return 1;
            }
            /* Not collinear. */
            return 0;
        } else if (fabs(x3-x2) < tolerance) {
            /* Second pair are vertical to each other */
            if (fabs(y3-y1) < tolerance) {
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
        if (fabs((dy1/dx1) - (dy2/dx2)) < tolerance) {
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
                } else if (mlcnc_c_points_are_collinear(x1, y1, x3, y3, x4, y4, 1e-9)) {
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
                if (mlcnc_c_points_are_collinear(x1, y1, x2, y2, x4, y4, 1e-9)) {
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
            int res1 = mlcnc_c_points_are_collinear(x1, y1, x2, y2, x4, y4, 1e-9);
            int res2 = mlcnc_c_points_are_collinear(x1, y1, x3, y3, x4, y4, 1e-9);
            if (res1 && res2) {
                /* Lines are collinear. */
                if (abs(x2-x1) > abs(y2-y1)) {
                    if ((x1 > x3 && x1 < x4) || (x1 < x3 && x1 > x4)) {
                        *x = x1;
                        *y = y1;
                    } else {
                        if ((x2 > x3 && x2 < x4) || (x2 < x3 && x2 > x4)) {
                            *x = x2;
                            *y = y2;
                        }
                        if ((x3 > x1 && x3 < *x) || (x3 < x1 && x3 > *x)) {
                            *x = x3;
                            *y = y3;
                        }
                        if ((x4 > x1 && x4 < *x) || (x4 < x1 && x4 > *x)) {
                            *x = x4;
                            *y = y4;
                        }
                    }
                } else {
                    if ((y1 > y3 && y1 < y4) || (y1 < y3 && y1 > y4)) {
                        *x = x1;
                        *y = y1;
                    } else {
                        if ((y2 > y3 && y2 < y4) || (y2 < y3 && y2 > y4)) {
                            *x = x2;
                            *y = y2;
                        }
                        if ((y3 > y1 && y3 < *y) || (y3 < y1 && y3 > *y)) {
                            *x = x3;
                            *y = y3;
                        }
                        if ((y4 > y1 && y4 < *y) || (y4 < y1 && y4 > *y)) {
                            *x = x4;
                            *y = y4;
                        }
                    }
                }
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
        double x4, double y4,
        double *ix, double *iy /* output intersect point */
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

        if (ix)
            *ix = x;
        if (iy)
            *iy = y;

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
        double px, double py,
        double *nx, double *ny
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
            if (nx) *nx = x;
            if (ny) *ny = y;
            return pdist;
        } else if (d1 < d2) {
            /* First endpoint is closer */
            if (nx) *nx = x1;
            if (ny) *ny = y1;
            return hypot(py-y1,px-x1);
        } else {
            /* Second endpoint is closer */
            if (nx) *nx = x2;
            if (ny) *ny = y2;
            return hypot(py-y2,px-x2);
        }
    }



    void
    mlcnc_c_bezier_segment_point(
        double t,
        double x0, double y0,
        double x1, double y1,
        double x2, double y2,
        double x3, double y3,
        double *x, double *y
    ) {
        double xc = 3.0*(x1-x0);
        double yc = 3.0*(y1-y0);

        double xb = 3.0*(x2-x1)-xc;
        double yb = 3.0*(y2-y1)-yc;

        double xa = x3-x0-xc-xb;
        double ya = y3-y0-yc-yb;

        *x = ((xa*t+xb)*t+xc)*t+x0;
        *y = ((ya*t+yb)*t+yc)*t+y0;
    }


    void
    mlcnc_c_bezier_split(
        double t,
        double x0, double y0,
        double x1, double y1,
        double x2, double y2,
        double x3, double y3,
        double *nx1, double *ny1,
        double *nx2, double *ny2,
        double *nx3, double *ny3,
        double *nx4, double *ny4,
        double *nx5, double *ny5
    ) {
        double u = 1.0 - t;
        double mx01 = u*x0 + t*x1;
        double my01 = u*y0 + t*y1;
        double mx12 = u*x1 + t*x2;
        double my12 = u*y1 + t*y2;
        double mx23 = u*x2 + t*x3;
        double my23 = u*y2 + t*y3;
        double mx012 = u*mx01 + t*mx12;
        double my012 = u*my01 + t*my12;
        double mx123 = u*mx12 + t*mx23;
        double my123 = u*my12 + t*my23;
        double mx0123 = u*mx012 + t*mx123;
        double my0123 = u*my012 + t*my123;
        *nx1 = mx01;
        *ny1 = my01;
        *nx2 = mx012;
        *ny2 = my012;
        *nx3 = mx0123;
        *ny3 = my0123;
        *nx4 = mx123;
        *ny4 = my123;
        *nx5 = mx23;
        *ny5 = my23;
    }


    /* 
     * Finds the closest point on the given bezier segment to the given point.
     * Returns the distance, and sets nx and ny to the nearest point.
     */
    double
    mlcnc_c_bezier_segment_dist_from_point(
        double x0, double y0,
        double x1, double y1,
        double x2, double y2,
        double x3, double y3,
        double px, double py,
        double *nx, double *ny,
        double *nt
    ) {
        /*
        fprintf(stderr, "%.8f, %.8f  %.8f, %.8f  %.8f, %.8f  %.8f, %.8f\n", x0,y0, x1,y1, x2,y2, x3,y3);
        fprintf(stderr, "px,py=%.8f, %.8f\n", px, py);
        fprintf(stderr, "start_t=%.8f\n", start_t);
        fprintf(stderr, "segval=%.8f\n\n", segval);
        */
        double t0 = 0.0;
        double te = 1.0;
        double dt = 0.05;
        double t;
        double dist;
        double mindist = 1e9;
        double min_t;
        double bx, by;
        while (dt > 1e-6) {
            for (t = t0; t <= te; t += dt) {
                mlcnc_c_bezier_segment_point(t, x0,y0, x1,y1, x2,y2, x3,y3, &bx, &by);
                dist = hypot(by-py,bx-px);
                if (dist < mindist) {
                    min_t = t;
                    mindist = dist;
                }
            }
            dt /= 2.0;
            t0 = min_t - dt;
            te = min_t + dt;
        }
        mlcnc_c_bezier_segment_point(min_t, x0,y0, x1,y1, x2,y2, x3,y3, &bx, &by);
        dist = hypot(by-py,bx-px);
        if (nx) *nx = bx;
        if (ny) *ny = by;
        if (nt) *nt = min_t;
        return dist;
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
            dist = mlcnc_c_line_segment_dist_from_point(x0, y0,  x1, y1,  pt.x, pt.y, NULL, NULL);
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
        double isx, isy, ix, iy;
        double x0, y0, x1, y1, origx, origy;
        mlcnc_pathpoint* ptr;
        int isects = 0;

        ptr = path->head;
        if (!ptr) {
            return 0;
        }

        isx = pt.x;
        isy = pt.y;

        ptr = path->head;
        x0 = ptr->pt.x;
        y0 = ptr->pt.y;

        if (fabs(y0-isy) < 1e-9) {
            /* Keep vertex from matching test line exactly. */
            y0 += 1.1e-9;
        }

        origx = x0;
        origy = y0;

        ptr = ptr->next;

        /* Uses algorithm from: http://tog.acm.org/editors/erich/ptinpoly/ */
        while (ptr) {
            x1 = ptr->pt.x;
            y1 = ptr->pt.y;
            if (fabs(y1-isy) < 1e-9) {
                /* Keep vertex from matching test line exactly. */
                y1 += 1.1e-9;
            }
            if ((y0 > isy && y1 < isy) || (y0 < isy && y1 > isy)) {
                if (x0 >= isx && x1 >= isx) {
                    isects++;
                } else if ((x0 > isx && x1 < isx) || (x0 < isx && x1 > isx)) {
                    if (mlcnc_c_find_line_intersection(x0, y0, x1, y1,  isx, isy, 1e9, isy,  &ix, &iy)) {
                        if (ix >= isx) {
                            isects++;
                        }
                    }
                }
            }

            x0 = x1;
            y0 = y1;
            ptr = ptr->next;
        }

        /*
         * If path endpoint is not the same as the path startpoint, lets
         * treat it as if that segment existed, and that the path is closed.
         */
        if (fabs(origx-x0) > 1e-9 || fabs(origy-y0) > 1e-9) {
            x1 = origx;
            y1 = origy;
            if ((y0 > isy && y1 < isy) || (y0 < isy && y1 > isy)) {
                if (x0 >= isx && x1 >= isx) {
                    isects++;
                } else if ((x0 > isx && x1 < isx) || (x0 < isx && x1 > isx)) {
                    if (mlcnc_c_find_line_intersection(x0, y0, x1, y1,  isx, isy, 1e9, isy,  &ix, &iy)) {
                        if (ix >= isx) {
                            isects++;
                        }
                    }
                }
            }
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
    return mlcnc_c_line_segments_intersect(x1, y1,  x2, y2,  x3, y3,  x4, y4,  NULL, NULL);
}


##
## TCLCMD: mlcnc_line_dist_from_point x1 y1  x2 y2  px py
##
##   Returns the absolute closest distance (FP double) that the point (px,py) is
##     from the line segment (x1,y1) (x2,y2).  This does not extend the line
##     for purposes of the calculation.
##

critcl::cproc mlcnc_line_dist_from_point {double x1 double y1 double x2 double y2 double px double py} double {
    return mlcnc_c_line_segment_dist_from_point(x1, y1,  x2, y2,  px, py, NULL, NULL);
}



##
## TCLCMD: mlcnc_points_are_collinear x1 y1  x2 y2  x3 y3
##
##   Returns true if the three given points (x1,y1) (x2,y2) and (x3,y3) are
##     collinear (in a straight line) to within 1e-10 units.
##

critcl::cproc mlcnc_points_are_collinear {double x1 double y1 double x2 double y2 double x3 double y3} int {
    return mlcnc_c_points_are_collinear(x1, y1,  x2, y2,  x3, y3, 1e-9);
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

        dist = mlcnc_c_line_segment_dist_from_point(x0, y0,  x1, y1,  px, py,  NULL, NULL);
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
##   Returns the distance of the most distant consecutive points in the given path.
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
    Tcl_Obj *retval = Tcl_GetObjResult(ip);
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


##
## TCLCMD: mlcnc_path_circumscribes_point path x y
##
##   Returns true if the given closed path circumscribes the given x,y coords.
##

critcl::ccommand mlcnc_path_circumscribes_point {dummy ip objc objv} {
    double dist, mindist = 0;
    int result, i;
    int isects = 0;
    int coordslen;
    double px, py;
    double x0, y0, x1, y1, ix, iy, origx, origy;
    Tcl_Obj *retval = Tcl_GetObjResult(ip);
    Tcl_Obj *obj;
    Tcl_Obj *listElemXPtr;
    Tcl_Obj *listElemYPtr;

    if (objc < 4 || objc > 4) {
        Tcl_WrongNumArgs(ip, 1, objv, "coordslist x y");
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
    origx = px;

    /* Get double pointy */
    if (TCL_OK != Tcl_GetDoubleFromObj(ip, objv[3], &py)) {
        return TCL_ERROR ;
    }
    origy = py;

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

    if (fabs(y0-py) < 1e-9) {
        /* Keep vertex from matching test line exactly. */
        y0 += 1.1e-9;
    }

    origx = x0;
    origy = y0;

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

        if (fabs(y1-py) < 1e-9) {
            /* Keep vertex from matching test line exactly. */
            y1 += 1.1e-9;
        }
        if ((y0 > py && y1 < py) || (y0 < py && y1 > py)) {
            if (x0 >= px && x1 >= px) {
                isects++;
            } else if ((x0 > px && x1 < px) || (x0 < px && x1 > px)) {
                if (mlcnc_c_find_line_intersection(x0, y0, x1, y1,  px, py, 1e9, py,  &ix, &iy)) {
                    if (ix >= px) {
                        isects++;
                    }
                }
            }
        }

        x0 = x1;
        y0 = y1;
    }

    /*
     * If path endpoint is not the same as the path startpoint, lets
     * treat it as if that segment existed, and that the path is closed.
     */
    if (fabs(origx-x0) > 1e-9 || fabs(origy-y0) > 1e-9) {
        x1 = origx;
        y1 = origy;
        if ((y0 > py && y1 < py) || (y0 < py && y1 > py)) {
            if (x0 >= px && x1 >= px) {
                isects++;
            } else if ((x0 > px && x1 < px) || (x0 < px && x1 > px)) {
                if (mlcnc_c_find_line_intersection(x0, y0, x1, y1,  px, py, 1e9, py,  &ix, &iy)) {
                    if (ix >= px) {
                        isects++;
                    }
                }
            }
        }
    }

    /* If count of intersections is odd (non-even) then the path circumscribes the point px,py. */
    Tcl_SetBooleanObj(retval, (isects % 2 == 1));

    return TCL_OK;
}


##
## TCLCMD: mlcnc_path_find_line_segment_intersections path x0 y0 x1 y1
##
##   Finds all the intersections of the given path with the given line segment.
##   Returns a list with segment number (0 based), x, and y, triplets for each
##     intersection.  ie: a line that intersected a path at (2.0,1.5) in the
##     first segment of the path, and at (-1.1,0.9) in the third segment would
##     return the list: {0 2.0 1.5 2 -1.1 0.9}
##

critcl::ccommand mlcnc_path_find_line_segment_intersections {dummy ip objc objv} {
    double dist, mindist = 0;
    int segnum = 0;
    int result, i;
    int coordslen;
    double lx0, ly0, lx1, ly1;
    double origx, origy, ix, iy;
    double prevx, prevy;
    double x0, y0, x1, y1;
    Tcl_Obj *retval = Tcl_GetObjResult(ip);
    Tcl_Obj *listElemXPtr;
    Tcl_Obj *listElemYPtr;


    if (objc < 6 || objc > 6) {
        Tcl_WrongNumArgs(ip, 1, objv, "coordslist x0 y0 x1 y1");
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

    /* Get double lx0 */
    if (TCL_OK != Tcl_GetDoubleFromObj(ip, objv[2], &lx0)) {
        return TCL_ERROR ;
    }

    /* Get double ly0 */
    if (TCL_OK != Tcl_GetDoubleFromObj(ip, objv[3], &ly0)) {
        return TCL_ERROR ;
    }

    /* Get double lx1 */
    if (TCL_OK != Tcl_GetDoubleFromObj(ip, objv[4], &lx1)) {
        return TCL_ERROR ;
    }

    /* Get double ly1 */
    if (TCL_OK != Tcl_GetDoubleFromObj(ip, objv[5], &ly1)) {
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
    prevx = prevy = 1e9;
    origx = x0;
    origy = y0;

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

        if (fabs(x0-x1) < 1e-9 && fabs(y0-y1) < 1e-9) {
            /* If segment endpoints are the same, skip this one. */
            segnum++;
            continue;
        }

        if (mlcnc_c_line_segments_intersect(x0, y0, x1, y1,  lx0, ly0, lx1, ly1,  &ix, &iy)) {
    
            /*
             * If the intersect point is the startpoint of the segment,
             * lets skip it so it doesn't get double-counted.
             * Otherwise, count the intersection.
             */
            if (fabs(ix-prevx) > 1e-9 || fabs(iy-prevy) > 1e-9) {
                Tcl_ListObjAppendElement(ip, retval, Tcl_NewIntObj(segnum));
                Tcl_ListObjAppendElement(ip, retval, Tcl_NewDoubleObj(ix));
                Tcl_ListObjAppendElement(ip, retval, Tcl_NewDoubleObj(iy));
                prevx = ix;
                prevy = iy;
            }
        }
        x0 = x1;
        y0 = y1;
        segnum++;
    }

    /*
     * If path endpoint is not the same as the path startpoint, lets
     * treat it as if that segment existed, and that the path is closed.
     */
    if (fabs(origx-x1) > 1e-9 || fabs(origy-y1) > 1e-9) {
        if (mlcnc_c_line_segments_intersect(x1, y1, origx, origy,  lx0, ly0, lx1, ly1,  &ix, &iy)) {

            if (fabs(ix-prevx) > 1e-9 || fabs(iy-prevy) > 1e-9) {
                Tcl_ListObjAppendElement(ip, retval, Tcl_NewIntObj(segnum));
                Tcl_ListObjAppendElement(ip, retval, Tcl_NewDoubleObj(ix));
                Tcl_ListObjAppendElement(ip, retval, Tcl_NewDoubleObj(iy));
            }
        }
    }

    Tcl_SetObjResult(ip, retval);

    return TCL_OK;
}


##
## TCLCMD: mlcnc_path_find_self_intersections path
##
##   Finds all the intersections of the given path with itself.
##   Returns a list with both segment numbers (0 based), x, and y quartets
##     for each intersection.  ie: The path {0 0  1 1  2 0  2 1  1 0  0 1}
##     would return the list: {0 4 0.5 0.5  1 3 1.5 0.5} which translates as
##     There is an intersection of segments 0 and 4 at 0.5, 0.5 and an
##     intersection of segments 1 and 3 at 1.5, 0.5.
##

critcl::ccommand mlcnc_path_find_self_intersections {dummy ip objc objv} {
    double dist, mindist = 0;
    int segnum = 0;
    int result, i, j;
    int coordslen;
    double origx, origy, ix, iy;
    double prevx, prevy;
    double ax0, ay0, ax1, ay1;
    double bx0, by0, bx1, by1;
    Tcl_Obj *retval = Tcl_GetObjResult(ip);
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

    prevx = prevy = -1e9;
    for (i = 0; i < coordslen-6; i+=2) {
        Tcl_ListObjIndex(ip, objv[1], i, &listElemXPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemXPtr, &ax0);
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }
        Tcl_ListObjIndex(ip, objv[1], i+1, &listElemYPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemYPtr, &ay0);
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }
        Tcl_ListObjIndex(ip, objv[1], i+2, &listElemXPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemXPtr, &ax1);
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }
        Tcl_ListObjIndex(ip, objv[1], i+3, &listElemYPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemYPtr, &ay1);
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }
        if (i == 0) {
            prevx = ax0;
            prevy = ay0;
        }

        if (fabs(ax0-ax1) < 1e-9 && fabs(ay0-ay1) < 1e-9) {
            /* If segment endpoints are the same, skip this one. */
            continue;
        }

        for (j = i+4; j < coordslen-2; j+=2) {
            Tcl_ListObjIndex(ip, objv[1], j, &listElemXPtr);
            result=Tcl_GetDoubleFromObj(ip, listElemXPtr, &bx0);
            if (result != TCL_OK) {
                Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
                return TCL_ERROR ;
            }
            Tcl_ListObjIndex(ip, objv[1], j+1, &listElemYPtr);
            result=Tcl_GetDoubleFromObj(ip, listElemYPtr, &by0);
            if (result != TCL_OK) {
                Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
                return TCL_ERROR ;
            }

            Tcl_ListObjIndex(ip, objv[1], j+2, &listElemXPtr);
            result=Tcl_GetDoubleFromObj(ip, listElemXPtr, &bx1);
            if (result != TCL_OK) {
                Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
                return TCL_ERROR ;
            }
            Tcl_ListObjIndex(ip, objv[1], j+3, &listElemYPtr);
            result=Tcl_GetDoubleFromObj(ip, listElemYPtr, &by1);
            if (result != TCL_OK) {
                Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
                return TCL_ERROR ;
            }

            if (fabs(bx0-bx1) < 1e-9 && fabs(by0-by1) < 1e-9) {
                /* If segment endpoints are the same, skip this one. */
                continue;
            }

            if (mlcnc_c_line_segments_intersect(ax0, ay0, ax1, ay1,  bx0, by0, bx1, by1,  &ix, &iy)) {
    
                /*
                 * If the intersect point is the startpoint of the segment,
                 * lets skip it so it doesn't get double-counted.
                 * Otherwise, count the intersection.
                 */
                if (fabs(ix-prevx) > 1e-9 || fabs(iy-prevy) > 1e-9) {
                    Tcl_ListObjAppendElement(ip, retval, Tcl_NewIntObj(i/2));
                    Tcl_ListObjAppendElement(ip, retval, Tcl_NewIntObj(j/2));
                    Tcl_ListObjAppendElement(ip, retval, Tcl_NewDoubleObj(ix));
                    Tcl_ListObjAppendElement(ip, retval, Tcl_NewDoubleObj(iy));
                    prevx = ix;
                    prevy = iy;
                }
            }
        }
    }

    Tcl_SetObjResult(ip, retval);

    return TCL_OK;
}


##
## TCLCMD: mlcnc_path_find_path_intersections path1 path2
##
##   Finds all the intersections of the two given polygon paths.
##   Returns a list with both segment numbers (0 based), x, and y quartets
##     for each intersection.  ie: The paths {0 0  1 1  2 0} & {0 1  2 1  1 0}
##     would return the list: {0 2 0.5 0.5  1 1 1.5 0.5} which translates as:
##       Segment 0 of path 1 and seg 2 of path2 intersect at 0.5, 0.5.  Also,
##       segment 1 of path 1 and seg 1 of path2 intersect at 1.5, 0.5.
##

critcl::ccommand mlcnc_path_find_path_intersections {dummy ip objc objv} {
    double dist, mindist = 0;
    int segnum = 0;
    int result, i, j;
    int coordslen1;
    int coordslen2;
    double origx, origy, ix, iy;
    double ax0, ay0, ax1, ay1;
    double bx0, by0, bx1, by1;
    Tcl_Obj *retval = Tcl_GetObjResult(ip);
    Tcl_Obj *listElemXPtr;
    Tcl_Obj *listElemYPtr;


    if (objc < 3 || objc > 3) {
        Tcl_WrongNumArgs(ip, 1, objv, "path1 path2");
        return TCL_ERROR;
    }

    /* get list of x y values in path1 */
    result = Tcl_ListObjLength(ip, objv[1], &coordslen1);
    if (result != TCL_OK) {
        return TCL_ERROR ;
    }
    if (coordslen1 % 2 != 0) {
        Tcl_AppendStringsToObj(retval, " (expected an even number of values)", (char *) NULL);
        return TCL_ERROR ;
    }
    if (coordslen1 < 4) {
        Tcl_AppendStringsToObj(retval, " (expected at least 4 values)", (char *) NULL);
        return TCL_ERROR ;
    }

    /* get list of x y values in path1 */
    result = Tcl_ListObjLength(ip, objv[2], &coordslen2);
    if (result != TCL_OK) {
        return TCL_ERROR ;
    }
    if (coordslen2 % 2 != 0) {
        Tcl_AppendStringsToObj(retval, " (expected an even number of values)", (char *) NULL);
        return TCL_ERROR ;
    }
    if (coordslen2 < 4) {
        Tcl_AppendStringsToObj(retval, " (expected at least 4 values)", (char *) NULL);
        return TCL_ERROR ;
    }

    for (i = 0; i < coordslen1; i+=2) {
        Tcl_ListObjIndex(ip, objv[1], i, &listElemXPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemXPtr, &ax0);
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }
        Tcl_ListObjIndex(ip, objv[1], i+1, &listElemYPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemYPtr, &ay0);
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }
        Tcl_ListObjIndex(ip, objv[1], (i+2)%coordslen1, &listElemXPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemXPtr, &ax1);
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }
        Tcl_ListObjIndex(ip, objv[1], (i+3)%coordslen1, &listElemYPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemYPtr, &ay1);
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }

        if (fabs(ax0-ax1) < 1e-9 && fabs(ay0-ay1) < 1e-9) {
            /* If segment endpoints are the same, skip this one. */
            continue;
        }

        for (j = 0; j < coordslen2; j+=2) {
            Tcl_ListObjIndex(ip, objv[2], j, &listElemXPtr);
            result=Tcl_GetDoubleFromObj(ip, listElemXPtr, &bx0);
            if (result != TCL_OK) {
                Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
                return TCL_ERROR ;
            }
            Tcl_ListObjIndex(ip, objv[2], j+1, &listElemYPtr);
            result=Tcl_GetDoubleFromObj(ip, listElemYPtr, &by0);
            if (result != TCL_OK) {
                Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
                return TCL_ERROR ;
            }

            Tcl_ListObjIndex(ip, objv[2], (j+2)%coordslen2, &listElemXPtr);
            result=Tcl_GetDoubleFromObj(ip, listElemXPtr, &bx1);
            if (result != TCL_OK) {
                Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
                return TCL_ERROR ;
            }
            Tcl_ListObjIndex(ip, objv[2], (j+3)%coordslen2, &listElemYPtr);
            result=Tcl_GetDoubleFromObj(ip, listElemYPtr, &by1);
            if (result != TCL_OK) {
                Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
                return TCL_ERROR ;
            }

            if (fabs(bx0-bx1) < 1e-9 && fabs(by0-by1) < 1e-9) {
                /* If segment endpoints are the same, skip this one. */
                continue;
            }

            if (mlcnc_c_line_segments_intersect(ax0, ay0, ax1, ay1,  bx0, by0, bx1, by1,  &ix, &iy)) {
    
                /*
                 * If the intersect point is the startpoint of either segment,
                 * lets skip it so it doesn't get double-counted.
                 * Otherwise, count the intersection.
                 */
                if (fabs(ix-ax0) > 1e-9 || fabs(iy-ay0) > 1e-9) {
                    if (fabs(ix-bx0) > 1e-9 || fabs(iy-by0) > 1e-9) {
                        Tcl_ListObjAppendElement(ip, retval, Tcl_NewIntObj(i/2));
                        Tcl_ListObjAppendElement(ip, retval, Tcl_NewIntObj(j/2));
                        Tcl_ListObjAppendElement(ip, retval, Tcl_NewDoubleObj(ix));
                        Tcl_ListObjAppendElement(ip, retval, Tcl_NewDoubleObj(iy));
                    }
                }
            }
        }
    }

    Tcl_SetObjResult(ip, retval);

    return TCL_OK;
}


##
## TCLCMD: mlcnc_bezier_nearest_point_to_point bezpath px py
##
##   Returns an array with the distance, x-y position, segment number, and
##     t value of the closest point on the given bezier path to the given
##     point px,py.
##

critcl::ccommand mlcnc_bezier_nearest_point_to_point {dummy ip objc objv} {
    int segnum = 0;
    int result, i, j;
    int coordslen;
    double px, py;
    double ax0, ay0, ax1, ay1;
    double ax2, ay2, ax3, ay3;
    double save_x, save_y, save_dist, save_t;
    double nx, ny, dist, nt;
    int save_seg;
    Tcl_Obj *retval = Tcl_GetObjResult(ip);
    Tcl_Obj *listElemXPtr;
    Tcl_Obj *listElemYPtr;


    if (objc < 4 || objc > 4) {
        Tcl_WrongNumArgs(ip, 1, objv, "bezierpath px py");
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
    if (coordslen > 6 && (coordslen/2)%3 != 1) {
        Tcl_AppendStringsToObj(retval, " (expected a well formed bezier path)", (char *) NULL);
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


    save_x = save_y = 1e9;
    save_dist = 1e9;
    save_seg = 0;
    save_t = 0.0;

    for (i = 0; i < coordslen-6; i+=6) {

        Tcl_ListObjIndex(ip, objv[1], i, &listElemXPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemXPtr, &ax0);
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }
        Tcl_ListObjIndex(ip, objv[1], i+1, &listElemYPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemYPtr, &ay0);
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }

        Tcl_ListObjIndex(ip, objv[1], i+2, &listElemXPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemXPtr, &ax1);
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }
        Tcl_ListObjIndex(ip, objv[1], i+3, &listElemYPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemYPtr, &ay1);
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }

        Tcl_ListObjIndex(ip, objv[1], i+4, &listElemXPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemXPtr, &ax2);
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }
        Tcl_ListObjIndex(ip, objv[1], i+5, &listElemYPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemYPtr, &ay2);
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }

        Tcl_ListObjIndex(ip, objv[1], i+6, &listElemXPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemXPtr, &ax3);
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }
        Tcl_ListObjIndex(ip, objv[1], i+7, &listElemYPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemYPtr, &ay3);
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }

        dist = mlcnc_c_bezier_segment_dist_from_point(ax0,ay0, ax1,ay1, ax2,ay2, ax3,ay3, px,py, &nx, &ny, &nt);
        if (dist < save_dist) {
            save_dist = dist;
            save_x = nx;
            save_y = ny;
            save_t = nt;
            save_seg = i/6;
        }
    }

    Tcl_ListObjAppendElement(ip, retval, Tcl_NewDoubleObj(save_dist));
    Tcl_ListObjAppendElement(ip, retval, Tcl_NewDoubleObj(save_x));
    Tcl_ListObjAppendElement(ip, retval, Tcl_NewDoubleObj(save_y));
    Tcl_ListObjAppendElement(ip, retval, Tcl_NewIntObj(save_seg));
    Tcl_ListObjAppendElement(ip, retval, Tcl_NewDoubleObj(save_t));

    Tcl_SetObjResult(ip, retval);

    return TCL_OK;
}



##
## TCLCMD: mlcnc_path_insert_path_intersections path1 path2
##
##   Finds all the intersections of the two given polygon paths.
##   Returns the two paths in a list, with new points added where the two
##     paths intersected.
##

critcl::ccommand mlcnc_path_insert_path_intersections {dummy ip objc objv} {
    double dist, mindist = 0;
    int segnum = 0;
    int result, i, j;
    int coordslen1;
    int coordslen2;
    double origx, origy, ix, iy;
    double ax0, ay0, ax1, ay1;
    double bx0, by0, bx1, by1;
    Tcl_Obj *xyPtrs[2];
    Tcl_Obj *retval = Tcl_GetObjResult(ip);
    Tcl_Obj *listElemXPtr;
    Tcl_Obj *listElemYPtr;
    Tcl_Obj *path1;
    Tcl_Obj *path2;

    if (objc < 3 || objc > 3) {
        Tcl_WrongNumArgs(ip, 1, objv, "path1 path2");
        return TCL_ERROR;
    }

    /* get list of x y values in path1 */
    result = Tcl_ListObjLength(ip, objv[1], &coordslen1);
    if (result != TCL_OK) {
        return TCL_ERROR ;
    }
    if (coordslen1 % 2 != 0) {
        Tcl_AppendStringsToObj(retval, " (expected an even number of values)", (char *) NULL);
        return TCL_ERROR ;
    }
    if (coordslen1 < 4) {
        Tcl_AppendStringsToObj(retval, " (expected at least 4 values)", (char *) NULL);
        return TCL_ERROR ;
    }

    /* get list of x y values in path2 */
    result = Tcl_ListObjLength(ip, objv[2], &coordslen2);
    if (result != TCL_OK) {
        return TCL_ERROR ;
    }
    if (coordslen2 % 2 != 0) {
        Tcl_AppendStringsToObj(retval, " (expected an even number of values)", (char *) NULL);
        return TCL_ERROR ;
    }
    if (coordslen2 < 4) {
        Tcl_AppendStringsToObj(retval, " (expected at least 4 values)", (char *) NULL);
        return TCL_ERROR ;
    }

    path1 = objv[1];
    if (Tcl_IsShared(path1)) {
        path1 = Tcl_DuplicateObj(path1);
    }

    path2 = objv[2];
    if (Tcl_IsShared(path2)) {
        path2 = Tcl_DuplicateObj(path2);
    }

    for (i = 0; i < coordslen1-2; i+=2) {
        Tcl_ListObjIndex(ip, path1, i, &listElemXPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemXPtr, &ax0);
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }
        Tcl_ListObjIndex(ip, path1, (i+1)%coordslen1, &listElemYPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemYPtr, &ay0);
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }
        Tcl_ListObjIndex(ip, path1, (i+2)%coordslen1, &listElemXPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemXPtr, &ax1);
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }
        Tcl_ListObjIndex(ip, path1, (i+3)%coordslen1, &listElemYPtr);
        result=Tcl_GetDoubleFromObj(ip, listElemYPtr, &ay1);
        if (result != TCL_OK) {
            Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
            return TCL_ERROR ;
        }

        if (fabs(ax0-ax1) < 1e-9 && fabs(ay0-ay1) < 1e-9) {
            /* If segment endpoints are the same, skip this one. */
            continue;
        }

        for (j = 0; j < coordslen2-2; j+=2) {
            Tcl_ListObjIndex(ip, path2, j, &listElemXPtr);
            result=Tcl_GetDoubleFromObj(ip, listElemXPtr, &bx0);
            if (result != TCL_OK) {
                Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
                return TCL_ERROR ;
            }
            Tcl_ListObjIndex(ip, path2, (j+1)%coordslen2, &listElemYPtr);
            result=Tcl_GetDoubleFromObj(ip, listElemYPtr, &by0);
            if (result != TCL_OK) {
                Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
                return TCL_ERROR ;
            }

            Tcl_ListObjIndex(ip, path2, (j+2)%coordslen2, &listElemXPtr);
            result=Tcl_GetDoubleFromObj(ip, listElemXPtr, &bx1);
            if (result != TCL_OK) {
                Tcl_AppendStringsToObj(retval, " in x coordinate value.", (char *) NULL);
                return TCL_ERROR ;
            }
            Tcl_ListObjIndex(ip, path2, (j+3)%coordslen2, &listElemYPtr);
            result=Tcl_GetDoubleFromObj(ip, listElemYPtr, &by1);
            if (result != TCL_OK) {
                Tcl_AppendStringsToObj(retval, " in y coordinate value.", (char *) NULL);
                return TCL_ERROR ;
            }

            if (fabs(bx0-bx1) < 1e-9 && fabs(by0-by1) < 1e-9) {
                /* If segment endpoints are the same, skip this one. */
                continue;
            }

            if (mlcnc_c_line_segments_intersect(ax0, ay0, ax1, ay1,  bx0, by0, bx1, by1,  &ix, &iy)) {
                /*
                 * If the intersect point is the start or endpoint of a segment,
                 * lets skip it so it doesn't add unnecessary points.
                 */
                if (fabs(ix-ax0) > 1e-9 || fabs(iy-ay0) > 1e-9) {
                    if (fabs(ix-ax1) > 1e-9 || fabs(iy-ay1) > 1e-9) {
                        xyPtrs[0] = Tcl_NewDoubleObj(ix);
                        xyPtrs[1] = Tcl_NewDoubleObj(iy);
                        Tcl_ListObjReplace(ip, path1, i+2, 0, 2, xyPtrs);
                        coordslen1 += 2;
                        ax1 = ix;
                        ay1 = iy;
                    }
                }
                if (fabs(ix-bx0) > 1e-9 || fabs(iy-by0) > 1e-9) {
                    if (fabs(ix-bx1) > 1e-9 || fabs(iy-by1) > 1e-9) {
                        xyPtrs[0] = Tcl_NewDoubleObj(ix);
                        xyPtrs[1] = Tcl_NewDoubleObj(iy);
                        Tcl_ListObjReplace(ip, path2, j+2, 0, 2, xyPtrs);
                        coordslen2 += 2;
                        j+=2;
                    }
                }
            }
        }
    }

    Tcl_ListObjAppendElement(ip, retval, path1);
    Tcl_ListObjAppendElement(ip, retval, path2);
    Tcl_SetObjResult(ip, retval);

    return TCL_OK;
}


# vim: set syntax=c ts=4 sw=4 nowrap expandtab: settings

