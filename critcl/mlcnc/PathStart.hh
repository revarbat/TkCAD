#include <deque>
#include "Point.hh"
#include "PathItem.hh"

using namespace std;

namespace FBGeom {

    /* Class for representing a PathStart. */
    class PathStart : public PathItem {
    public:
        PathStart() : PathItem(0.0, 0.0) { }
        PathStart(double x, double y) : PathItem(x, y) { }

        virtual PathItemType getType() { return START; }
    };

}

// vim: set syntax=c ts=4 sw=4 nowrap expandtab: settings

