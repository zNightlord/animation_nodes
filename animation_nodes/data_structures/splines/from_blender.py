from . poly_spline import PolySpline
from .. import FloatList, Vector3DList
from . bezier_spline import BezierSpline

def createSplinesFromBlenderObject(bObject, applyModifiers = False):
    curve = bObject.an.getCurve(applyModifiers)
    if curve is None: return []

    splines = []
    for bSpline in curve.splines:
        spline = createSplineFromBlenderSpline(bSpline)
        if spline is not None:
            splines.append(spline)
    return splines

def createSplineFromBlenderSpline(bSpline):
    if bSpline.type == "BEZIER":
        return createBezierSpline(bSpline)
    elif bSpline.type == "POLY":
        return createPolySpline(bSpline)
    return None

def createBezierSpline(bSpline):
    amount = len(bSpline.bezier_points)
    points = Vector3DList(length = amount)
    leftHandles = Vector3DList(length = amount)
    rightHandles = Vector3DList(length = amount)
    radii = FloatList(length = amount)
    tilts = FloatList(length = amount)

    bSpline.bezier_points.foreach_get("co", points.asMemoryView())
    bSpline.bezier_points.foreach_get("handle_left", leftHandles.asMemoryView())
    bSpline.bezier_points.foreach_get("handle_right", rightHandles.asMemoryView())
    bSpline.bezier_points.foreach_get("radius", radii.asMemoryView())
    bSpline.bezier_points.foreach_get("tilt", tilts.asMemoryView())

    spline = BezierSpline(points, leftHandles, rightHandles, radii, tilts)
    spline.cyclic = bSpline.use_cyclic_u
    spline.materialIndex = bSpline.material_index
    return spline

def createPolySpline(bSpline):
    pointArray = FloatList(length = 4 * len(bSpline.points))
    bSpline.points.foreach_get("co", pointArray.asMemoryView())
    del pointArray[3::4]
    splinePoints = Vector3DList.fromFloatList(pointArray)

    radii = FloatList(length = len(bSpline.points))
    tilts = FloatList(length = len(bSpline.points))
    bSpline.points.foreach_get("radius", radii.asMemoryView())
    bSpline.points.foreach_get("tilt", tilts.asMemoryView())

    spline = PolySpline(splinePoints, radii, tilts)
    spline.cyclic = bSpline.use_cyclic_u
    spline.materialIndex = bSpline.material_index
    return spline
