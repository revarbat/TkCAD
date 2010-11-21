#include <math.h>
#include <iostream>
#include "Point.hh"
#include "Line.hh"

using namespace std;
using namespace FBGeom;

int
main(int argc, char** argv)
{
    Line l1(1.0,0.0, 0.0,1.0);
    Line l2(0.0,1.0, 1.0,0.0);

    cout << "Line is " << l1 << endl;
    cout << "Angle is " << l1.getAngle(l2) * 180.0 / M_PI << endl;
    cout << "Angle is " << l1.getAngle(l2.end) * 180.0 / M_PI << endl;

    return 0;
}


