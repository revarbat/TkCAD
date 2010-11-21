#include <deque>
#include "Point.hh"
#include "PathItem.hh"

using namespace std;

namespace FBGeom {

    enum PathArcDirection {CW, CCW};

    /* Class for representing a PathArc. */
    class PathArc : public PathItem {
    private:
        PathArcDirection direction;
        double radius;

    public:
        PathArc() : PathItem(0.0, 0.0), direction(CW), radius(0.0) { }
        PathArc(PathArcDirection dir, double rad, double x, double y) : PathItem(x, y), direction(dir), radius(rad) {}

        virtual PathItemType getType() const { return ARC; }

        Point getCenter(const Point &pt) const
        {
            Point pt;
            double mdist, cdist, mx, my, ang, pang;
            mx = (pt.x + x) / 2.0;
            my = (pt.y + y) / 2.0;
            mdist = hypot(y-pt.y, x-pt.x)/2.0;
            ang = atan2(y-pt.y, x-pt.x);
            cdist = sqrt(radius*radius-mdist*mdist);
            if (direction == CCW) {
                pang = ang + M_PI_2;
            } else {
                pang = ang - M_PI_2;
            }
            pt.x = cos(pang)*cdist+mx;
            pt.y = sin(pang)*cdist+my;
            return pt;
        }

        virtual double getEntryAngle(const Point &pt) const
        {
            Point center = getCenter(pt);
            double ang = atan2(pt.y-center.y, pt.x-center.x);
            if (direction == CCW) {
                return ang+M_PI_2;
            }
            return ang-M_PI_2;
        }

        virtual double getExitAngle(const Point &pt) const
        {
            Point center = getCenter(pt);
            double ang = atan2(y-center.y, x-center.x);
            if (direction == CCW) {
                return ang+M_PI_2;
            }
            return ang-M_PI_2;
        }

        PathArc getLeftOffset(const Point &pt, double dist) const
        {
            PathArc pa();
            Point center = getCenter(pt);
            double ang = atan2(y-center.y, x-center.x);
            if (direction == CCW) {
                pa.radius = radius - dist;
            } else {
                pa.radius = radius + dist;
            }
            if (pa.radius < 0) {
                pa.radius = 0;
            }
            pa.x = cos(ang)*pa.radius+center.x;
            pa.y = sin(ang)*pa.radius+center.y;
            return pa;
        }


    };

}

// vim: set syntax=c ts=4 sw=4 nowrap expandtab: settings

