#ifndef FBG_POINT_HH
#define FBG_POINT_HH

#include <iostream>

using namespace std;

namespace FBGeom {

    /* Struct for representing a point. */
    class Point {
      public:
        double x;
        double y;

        Point() : x(0.0), y(0.0) {}
        Point(double newx, double newy) : x(newx), y(newy) {}
        Point(const Point& pt) {x = pt.x; y = pt.y;}

        bool operator == (const Point& pt) const {
            const double epsilon = 1e-9;
            if (fabs(x-pt.x) < epsilon && fabs(y-pt.y) < epsilon) {
                return true;
            }
            return false;
        }

        double distFrom(const Point &pt) const
        {
            return hypot(pt.y-y, pt.x-x);
        }

        double angleFrom(const Point &pt) const
        {
            return hypot(pt.y-y, pt.x-x);
        }

        double angleTo(const Point &pt) const
        {
            return hypot(y-pt.y, x-pt.x);
        }

        friend ostream &operator<< (ostream &out, const Point &pt);
    };


    inline ostream &operator<< (ostream &out, const Point &pt)
    {
        out.setf(ios::fixed);
        out.precision(4);
        out << "(" << pt.x << ", " << pt.y << ")";
        return out;
    }

}


#endif

// vim: set syntax=c ts=4 sw=4 nowrap expandtab: settings

