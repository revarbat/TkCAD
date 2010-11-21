#include <math.h>
#include "Line.hh"

namespace FBGeom {
    bool Line::operator == (const Line& pt) const {
        if (pt.start == start && pt.end == end) {
            return true;
        }
        return false;
    }


    double Line::getLength() const
    {
        return hypot(end.y-start.y,end.x-start.x);
    }


    double Line::getAngle() const
    {
        return atan2(end.y-start.y,end.x-start.x);
    }


    // Returns the angle delta between the vector in this line, and the
    // vector from this line's endpoint to a given point.
    double Line::getAngle(const Point &pt) const
    {
        double ang1 = getAngle();
        double ang2 = atan2(pt.y-end.y, pt.x-end.x);
        double delta = ang2 - ang1;
        if (delta <= -M_PI_2) {
            delta += M_PI;
        } else if (delta > M_PI_2) {
            delta -= M_PI;
        }
        return delta;
    }


    // Returns the angle delta between the vector in this line, and the
    // vector represented by the second line.
    double Line::getAngle(const Line &ln) const
    {
        double ang1 = getAngle();
        double ang2 = ln.getAngle();
        double delta = ang2 - ang1;
        if (delta <= -M_PI_2) {
            delta += M_PI;
        } else if (delta > M_PI_2) {
            delta -= M_PI;
        }
        return delta;
    }


    Line Line::getLeftOffset(double dist) const
    {
        Line res;
        double pang = getAngle() + M_PI_2;

        res.start.x = cos(pang)*dist+start.x;
        res.start.y = sin(pang)*dist+start.y;
        res.end.x = cos(pang)*dist+end.x;
        res.end.y = sin(pang)*dist+end.y;
        return res;
    }


    Line Line::getRightOffset(double dist) const
    {
        return getLeftOffset(-dist);
    }


    bool Line::pointIsCollinear(Point pt) const
    {
        double m, c;
        if (pt == start || pt == end) {
            // Point is one of this line's endpoints.
            return true;
        }
        if (fabs(start.x - end.x) < epsilon && fabs(pt.x-end.x) < epsilon) {
            // This line is vertical, and we are on it.
            return true;
        }
        m = (end.y-start.y)/(end.x-start.x);
        c = start.y - m * start.x;
        if (fabs(m*pt.x+c-pt.y) < epsilon) {
            // The point is on this line.
            return true;
        }
        return false;
    }


    bool Line::pointIsInSegment(const Point &pt) const
    {
        if (pt.x > start.x && pt.x > end.x) {
            return false;
        }
        if (pt.x < start.x && pt.x < end.x) {
            return false;
        }
        if (pt.y > start.y && pt.y > end.y) {
            return false;
        }
        if (pt.y < start.y && pt.y < end.y) {
            return false;
        }
        if (!pointIsCollinear(pt)) {
            return false;
        }
        return true;
    }


    bool Line::extendedIntersectionPoint(const Line &ln, Point* pt) const
    {
        double m1, m2, c1, c2;
        if (start == end) {
            // We are a point.
            if (start == ln.start || start == ln.end) {
                // We are the same as one of the other Line's endpoints
                if (pt) {
                    *pt = start;
                }
                return true;
            } else if (ln.start == ln.end) {
                // Both Lines are different points.
                return false;
            } else if (ln.pointIsCollinear(start)) {
                // We are a point on the other Line.
                if (pt) {
                    *pt = start;
                }
                return true;
            } else {
                // We are not on the other Line.
                return false;
            }
        } else if (ln.start == ln.end) {
            // Other Line is a point.
            // Lets see if we are colinear.
            if (pointIsCollinear(ln.start)) {
                // Other line is a point on our Line.
                if (pt) {
                    *pt = ln.start;
                }
                return true;
            } else {
                // We are not on the other Line.
                return false;
            }
        }
        if (fabs(end.x-start.x) < epsilon) {
            // We are vertical
            if (fabs(ln.end.x-ln.start.x) < epsilon) {
                // Both lines are vertical
                if (fabs(start.x-ln.start.x) < epsilon) {
                    // Lines are collinear.
                    if (pt) {
                        // Set intersection point as midmoint of the two lines.
                        pt->x = start.x;
                        pt->y = (start.y+ln.end.y)/2.0;
                    }
                    return true;
                } else {
                    // Lines do not intersect.
                    return false;
                }
            } else {
                // We are vertical.  Other Line is not.
                // Lets see where the other Line intersects us.
                if (pt) {
                    m2 = (ln.end.y-ln.start.y)/(ln.end.x-ln.start.x);
                    c2 = ln.start.y - m2 * ln.start.x;
                    pt->x = start.x;
                    pt->y = m2 * start.x + c2;
                }
                return true;
            }
        } else if (fabs(ln.end.x-ln.start.x) < epsilon) {
            // Other Line is vertical.  We are not.
            // Lets see where we intersect it.
            if (pt) {
                m1 = (end.y-start.y)/(end.x-start.x);
                c1 = start.y - m1 * start.x;
                pt->x = ln.start.x;
                pt->y = m1 * ln.start.x + c1;
            }
            return true;
        } else {
            // Both lines have non-vertical slopes.
            m1 = (end.y-start.y)/(end.x-start.x);
            c1 = start.y - m1 * start.x;
            m2 = (ln.end.y-ln.start.y)/(ln.end.x-ln.start.x);
            c2 = ln.start.y - m2 * ln.start.x;
            if (fabs(m1-m2) < epsilon) {
                // Lines are parallel.
                if (fabs(c1-c2) < epsilon) {
                    // Lines are collinear.
                    if (pt) {
                        // Set intersection point as midmoint of the two lines.
                        pt->x = (start.x+ln.end.x)/2.0;
                        pt->y = (start.y+ln.end.y)/2.0;
                    }
                    return true;
                } else {
                    // Lines do not intersect.
                    return false;
                }
            } else {
                // Lines are not parallel.
                if (pt) {
                    pt->x = (c1 - c2) / (m2 - m1);
                    pt->y = m1 * pt->x + c1;
                }
                return true;
            }
        }
    }


    bool Line::intersectionPoint(const Line &ln, Point* pt) const
    {
        if (extendedIntersectionPoint(ln, pt)) {
            if (pointIsInSegment(*pt)) {
                return true;
            }
        }
        return false;
    }


    Point Line::getClosestExtendedPoint(const Point &pt) const
    {
        Point res;
        double m1, c1, m2, c2;
        if (fabs(start.x-end.x) < epsilon) {
            res.x = start.x;
            res.y = pt.y;
        } else if (fabs(start.y-end.y) < epsilon) {
            res.x = pt.x;
            res.y = start.y;
        } else {
            m1 = (end.y-start.y) / (end.x-start.x);
            c1 = start.y - m1 * start.x;
            m2 = -1.0 / m1;
            c2 = pt.y - m2 * pt.x;
            res.x = (c1 - c2) / (m2 - m1);
            res.y = m1 * res.x + c1;
        }
        return res;
    }


    Point Line::getClosestPoint(const Point &pt) const
    {
        if (pointIsInSegment(pt)) {
            return getClosestExtendedPoint(pt);
        } else {
            double ds = pt.distFrom(start);
            double de = pt.distFrom(end);
            if (ds < de) {
                return start;
            } else {
                return end;
            }
        }
    }
}

// vim: set syntax=c ts=4 sw=4 nowrap expandtab: settings

