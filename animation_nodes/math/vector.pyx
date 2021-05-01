import cython
from libc.math cimport sqrt, ceil, acos, sin, cos

cdef char isExactlyZeroVec3(Vector3* v):
    return v.x == v.y == v.z == 0

cdef char almostZeroVec3(Vector3* v):
    return lengthSquaredVec3(v) < 0.000001

cdef char isCloseVec3(Vector3* a, Vector3* b):
    return distanceSquaredVec3(a, b) < 0.000001

cdef void scaleVec3_Inplace(Vector3* v, float factor):
    v.x *= factor
    v.y *= factor
    v.z *= factor

cdef void scaleVec3(Vector3* target, Vector3* a, float factor):
    target.x = a.x * factor
    target.y = a.y * factor
    target.z = a.z * factor

cdef float lengthVec3(Vector3* v):
    return sqrt(v.x * v.x + v.y * v.y + v.z * v.z)

cdef float lengthSquaredVec3(Vector3* v):
    return v.x * v.x + v.y * v.y + v.z * v.z

cdef void addVec3(Vector3* target, Vector3* a, Vector3* b):
    target.x = a.x + b.x
    target.y = a.y + b.y
    target.z = a.z + b.z

cdef void addVec3_Inplace(Vector3* target, Vector3* other):
    target.x += other.x
    target.y += other.y
    target.z += other.z

cdef void subVec3(Vector3* target, Vector3* a, Vector3* b):
    target.x = a.x - b.x
    target.y = a.y - b.y
    target.z = a.z - b.z

cdef void multVec3(Vector3* target, Vector3* a, Vector3* b):
    target.x = a.x * b.x
    target.y = a.y * b.y
    target.z = a.z * b.z

@cython.cdivision(True)
cdef void divideVec3(Vector3* target, Vector3* a, Vector3* b):
    target.x = a.x / b.x if b.x != 0 else 0
    target.y = a.y / b.y if b.y != 0 else 0
    target.z = a.z / b.z if b.z != 0 else 0

cdef void mixVec3(Vector3* target, Vector3* a, Vector3* b, float factor):
    cdef float newX, newY, newZ
    newX = a.x * (1 - factor) + b.x * factor
    newY = a.y * (1 - factor) + b.y * factor
    newZ = a.z * (1 - factor) + b.z * factor
    target.x = newX
    target.y = newY
    target.z = newZ

@cython.cdivision(True)
cdef void normalizeVec3_InPlace(Vector3* v):
    cdef float length = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    if length != 0:
        v.x /= length
        v.y /= length
        v.z /= length
    else:
        v.x = v.y = v.z = 0

@cython.cdivision(True)
cdef void normalizeVec3(Vector3* target, Vector3* v):
    cdef float length = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    if length != 0:
        target.x = v.x / length
        target.y = v.y / length
        target.z = v.z / length
    else:
        target.x = target.y = target.z = 0

@cython.cdivision(True)
cdef void normalizeLengthVec3(Vector3* target, Vector3* v, float length):
    cdef float oldLength = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    cdef float factor
    if oldLength != 0:
        factor = length / oldLength
        target.x = v.x * factor
        target.y = v.y * factor
        target.z = v.z * factor
    else:
        target.x = target.y = target.z = 0

@cython.cdivision(True)
cdef void normalizeLengthVec3_Inplace(Vector3* v, float length):
    cdef float oldLength = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    cdef float factor
    if oldLength != 0:
        factor = length / oldLength
        v.x *= factor
        v.y *= factor
        v.z *= factor
    else:
        v.x = v.y = v.z = 0

cdef float distanceVec3(Vector3* a, Vector3* b):
    return sqrt(distanceSquaredVec3(a, b))

cdef float distanceSquaredVec3(Vector3* a, Vector3* b):
    cdef:
        float diff1 = (a.x - b.x)
        float diff2 = (a.y - b.y)
        float diff3 = (a.z - b.z)
    return diff1 * diff1 + diff2 * diff2 + diff3 * diff3

cdef float dotVec3(Vector3* a, Vector3* b):
    return a.x * b.x + a.y * b.y + a.z * b.z

@cython.cdivision(True)
cdef float angleVec3(Vector3 *a, Vector3 *b):
    cdef float denominator = lengthVec3(a) * lengthVec3(b)
    if denominator == 0: return 0

    cdef float dot = dotVec3(a, b)
    cdef float val = dot / denominator
    if val > 1: val = 1
    elif val < -1: val = -1
    return acos(val)

@cython.cdivision(True)
cdef float angleVec3Normalized(Vector3 *a, Vector3 *b):
    cdef float denominator = lengthVec3(a) * lengthVec3(b)
    if denominator == 0: return 0

    cdef float dot = dotVec3(a, b)
    cdef float val = dot / denominator
    if val > 1: val = 1
    elif val < -1: val = -1
    return acos(val)

cdef float angleNormalizedVec3(Vector3 *a, Vector3 *b):
    cdef float dot = dotVec3(a, b)
    return acos(dot)

cdef void crossVec3(Vector3* result, Vector3* a, Vector3* b):
    result.x = a.y * b.z - a.z * b.y
    result.y = a.z * b.x - a.x * b.z
    result.z = a.x * b.y - a.y * b.x

cdef float scalarTripleProduct(Vector3 *a, Vector3 *b, Vector3 *c):
    cdef Vector3 crossProduct
    crossVec3(&crossProduct, b, c)
    return dotVec3(a, &crossProduct)

@cython.cdivision(True)
cdef void projectVec3(Vector3* result, Vector3* a, Vector3* b):
    # https://en.wikipedia.org/wiki/Vector_projection#Vector_projection_2
    if b.x != 0 or b.y != 0 or b.z != 0:
        scaleVec3(result, b, dotVec3(a, b) / dotVec3(b, b))
    else:
        result.x = 0
        result.y = 0
        result.z = 0

cdef void projectOnCenterPlaneVec3(Vector3 *result, Vector3 *v, Vector3 *planeNormal):
    cdef Vector3 unitNormal, projVector
    normalizeVec3(&unitNormal, planeNormal)
    cdef float distance = dotVec3(v, &unitNormal)
    scaleVec3(&projVector, &unitNormal, -distance)
    addVec3(result, v, &projVector)

cdef void reflectVec3(Vector3* result, Vector3* v, Vector3* axis):
    cdef Vector3 _axis
    normalizeVec3(&_axis, axis)
    cdef float factor = 2 * dotVec3(v, &_axis)
    result.x = v.x - factor * _axis.x
    result.y = v.y - factor * _axis.y
    result.z = v.z - factor * _axis.z

cdef void absoluteVec3(Vector3* target, Vector3* source):
    target.x = abs(source.x)
    target.y = abs(source.y)
    target.z = abs(source.z)

@cython.cdivision(True)
cdef void snapVec3(Vector3* target, Vector3* v, Vector3* step):
    target.x = ceil(v.x / step.x - 0.5) * step.x if step.x != 0 else v.x
    target.y = ceil(v.y / step.y - 0.5) * step.y if step.y != 0 else v.y
    target.z = ceil(v.z / step.z - 0.5) * step.z if step.z != 0 else v.z

cdef void rotateAroundAxisVec3(Vector3 *target, Vector3 *v, Vector3 *axis, float angle):
    cdef Vector3 n
    normalizeVec3(&n, axis)
    cdef Vector3 d
    scaleVec3(&d, &n, dotVec3(&n, v))
    cdef Vector3 r
    subVec3(&r, v, &d)
    cdef Vector3 g
    crossVec3(&g, &n, &r)
    cdef float ca = cos(angle)
    cdef float sa = sin(angle)

    target.x = d.x + r.x * ca + g.x * sa
    target.y = d.y + r.y * ca + g.y * sa
    target.z = d.z + r.z * ca + g.z * sa
