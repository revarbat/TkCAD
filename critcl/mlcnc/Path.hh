#include <deque>
#include "Point.hh"
#include "PathItem.hh"
#include "PathStart.hh"
#include "PathLine.hh"
#include "PathArc.hh"
#include "PathBezier.hh"

using namespace std;

namespace FBGeom {

    /* Class for representing a Path. */
    class Path {
    private:
        deque<PathItem> items();
        bool closed;

    public:
        Path() : closed(false) { }

        int size() { return items.size(); }

        PathItem &operator [](int idx)
        {
            int len = items.size();
            if (idx < 0) {
                if (closed) {
                    idx = len - (abs(idx+1) % len) - 1;
                }
            } else if (idx >= len) {
                if (closed) {
                    idx %= len;
                }
            }
            return items[idx];
        }

        PolyLineIter front() {
            return items.front();
        }

        PolyLineIter back() {
            return items.back();
        }

        void appendPathItem(const PathItem &pitem) {
        {
            items.push_back(pitem);
        }

        void setPathItem(int idx, const PathItem &pitem) {
            items[idx] = pitem;
        }

        void insertPathItem(int idx, const PathItem &pitem) {
            items.insert(idx, pitem);
        }

        void isClosed() const
        {
            return closed;
        }

        void close()
        {
            closed = true;
        }

    };

}

// vim: set syntax=c ts=4 sw=4 nowrap expandtab: settings

