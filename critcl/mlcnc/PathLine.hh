#include <deque>
#include "Point.hh"
#include "PathItem.hh"

using namespace std;

namespace FBGeom {

    /* Class for representing a PathLine. */
    class PathLine : public PathItem {
    public:
        PathLine() : PathItem(0.0, 0.0) { }
        PathLine(double x, double y) : PathItem(x, y) { }

        virtual PathItemType getType() { return LINE; }

        virtual double getEntryAngle(const Point &pt) const
        {
            return atan2(y-pt.y, x-pt.x);
        }

        virtual double getExitAngle(const Point &pt) const
        {
            return atan2(y-pt.y, x-pt.x);
        }

        PathLine getLeftOffset(const Point &pt, double dist) const
        {
            PathLine pl();
            double ang = atan2(y-pt.y, x-pt.x);
            double pang = ang + M_PI_2;
            pl.x = cos(ang)*dist+x;
            pl.y = sin(ang)*dist+y;
            return pl;
        }
    };

}

// vim: set syntax=c ts=4 sw=4 nowrap expandtab: settings

