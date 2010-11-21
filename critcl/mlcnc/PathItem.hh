#include <deque>
#include "Point.hh"

using namespace std;

namespace FBGeom {

    enum PathItemType {NONE, START, LINE, ARC, BEZIER};

    /* Class for representing a PathItem. */
    class PathItem {
    public:
        double endx, endy;
        virtual PathItem() : endx(0.0), endy(0.0) { }
        virtual PathItem(double x, double y) : endx(x), endy(y) { }

        virtual PathItemType getType() const { return NONE; }

        virtual Point getEndPoint() {
            return Point(x,y);
        }

        virtual void setEndPoint(const Point &pt) {
            this->endx = pt.x;
            this->endy = pt.y;
        }

        virtual void setEndPoint(double x, double y) {
            this->endx = x;
            this->endy = y;
        }

        virtual double getExitAngle(const Point &pt) const = 0;
        virtual double getEntryAngle(const Point &pt) const = 0;
        // PathItem getLeftOffset(const Point &pt, double dist) const = 0;
    };

}

// vim: set syntax=c ts=4 sw=4 nowrap expandtab: settings

