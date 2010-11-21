#ifndef FBG_LINE_HH
#define FBG_LINE_HH

#include "Point.hh"

const double epsilon = 1e-9;

namespace FBGeom {

    /* Struct for representing a Line. */
    class Line {
      public:
        Point start, end;

        Line() : start(), end()  {}
        Line(double nx0, double ny0, double nx1, double ny1) : start(nx0,ny0), end(nx1,ny1) {}
        Line(const Point &s, const Point &e) : start(s), end(e) {}
        Line(const Line& ln) : start(ln.start), end(ln.end) {}

        bool operator == (const Line& pt) const;
        bool operator != (const Line& pt) const {return !(*this == pt);}

        double getLength() const;
        double getAngle() const;
        double getAngle(const Point &pt) const;
        double getAngle(const Line &ln) const;
        Line getLeftOffset(double dist) const;
        Line getRightOffset(double dist) const;
        bool pointIsCollinear(Point pt) const;
        bool pointIsInSegment(const Point &pt) const;
        bool extendedIntersectionPoint(const Line &ln, Point* pt) const;
        bool intersectionPoint(const Line &ln, Point* pt) const;
        Point getClosestPoint(const Point &pt) const;
        Point getClosestExtendedPoint(const Point &pt) const;

        friend ostream &operator<< (ostream &out, const Line &ln);
    };


    inline ostream &operator<< (ostream &out, const Line &ln)
    {
        out << "[" << ln.start << " to " << ln.end << "]";
        return out;
    }


}

#endif // FBG_LINE_HH

// vim: set syntax=c ts=4 sw=4 nowrap expandtab: settings

