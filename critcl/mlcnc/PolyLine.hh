#include <deque>
#include "Point.hh"

using namespace std;

namespace FBGeom {

    typedef deque<Point>::iterator PolyLineIter;

    /* Class for representing a PolyLine. */
    class PolyLine {
    private:
        deque<Point> points();
        bool closed;

    public:
        PolyLine() : closed(false) { }

        int size() { return points.size(); }

        Point &operator [](int idx)
        {
            int len = points.size();
            if (idx < 0) {
                if (closed) {
                    idx = len - (abs(idx+1) % len) - 1;
                }
            } else if (idx >= len) {
                if (closed) {
                    idx %= len;
                }
            }
            return points[idx];
        }

        PolyLineIter front() {
            return points.front();
        }

        PolyLineIter back() {
            return points.back();
        }

        void appendPoint(double x, double y)
        {
            points.push_back(Point(x,y));
        }

        void setPoint(int idx, const Point &pt) {
            points[idx].x = pt.x;
            points[idx].y = pt.y;
        }

        void setPoint(int idx, double x, double y) {
            points[idx].x = x;
            points[idx].y = y;
        }

        void insertPoint(int idx, const Point &pt) {
            points.insert(idx, pt);
        }

        void insertPoint(int idx, double x, double y) {
            Point pt(x,y);
            points.insert(idx, pt);
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

