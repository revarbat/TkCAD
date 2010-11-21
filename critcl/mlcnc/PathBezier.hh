#include <deque>
#include "Point.hh"
#include "PathItem.hh"

using namespace std;

namespace FBGeom {

    /* Class for representing a PathBezier. */
    class PathBezier : public PathItem {
    private:
        double cpx1, cpy1, cpx2, cpy2;

    public:
        PathBezier() : PathItem(0.0, 0.0), cpx1(0.0), cpy1(0.0), cpx2(0.0), cpy2(0.0) { }
        PathBezier(double cpx1, double cpy1, double cpx2, double cpy2, double x, double y) : PathItem(x, y), cpx1(cpx1), cpy1(cpy1), cpx2(cpx2), cpy2(cpy2) {}

        virtual PathItemType getType() { return BEZIER; }
    };

}

// vim: set syntax=c ts=4 sw=4 nowrap expandtab: settings

