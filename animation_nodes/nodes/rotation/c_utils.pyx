
from libc.math cimport M_PI as PI, sqrt, sin, cos, asin, acos
from ... math cimport (
    quaternionNormalize_InPlace, normalizeVec3_InPlace,
    euler3ToQuaternion, quaternionToMatrix4,
    quaternionToEuler3, quaternionToAxisAngle,
    quaternionFromAxisAngle
)
from ... algorithms.random_number_generators cimport XoShiRo256Plus

from ... data_structures cimport (
    Vector3DList, EulerList, DoubleList, Matrix4x4List,
    VirtualDoubleList, Quaternion, QuaternionList
)

cdef float degreeToRadianFactor = <float>(PI / 180)
cdef float radianToDegreeFactor = <float>(180 / PI)

def combineEulerList(Py_ssize_t amount,
                     VirtualDoubleList x, VirtualDoubleList y, VirtualDoubleList z,
                     bint useDegree = False):
    cdef EulerList output = EulerList(length = amount)
    cdef float factor = degreeToRadianFactor if useDegree else 1
    cdef Py_ssize_t i
    for i in range(amount):
        output.data[i].x = <float>x.get(i) * factor
        output.data[i].y = <float>y.get(i) * factor
        output.data[i].z = <float>z.get(i) * factor
        output.data[i].order = 0
    return output

def vectorsToEulers(Vector3DList vectors, bint useDegree):
    cdef EulerList eulers = EulerList(length = len(vectors))
    cdef Py_ssize_t i
    if useDegree:
        for i in range(len(vectors)):
            eulers.data[i].order = 0
            eulers.data[i].x = vectors.data[i].x * degreeToRadianFactor
            eulers.data[i].y = vectors.data[i].y * degreeToRadianFactor
            eulers.data[i].z = vectors.data[i].z * degreeToRadianFactor
    else:
        for i in range(len(vectors)):
            eulers.data[i].order = 0
            eulers.data[i].x = vectors.data[i].x
            eulers.data[i].y = vectors.data[i].y
            eulers.data[i].z = vectors.data[i].z
    return eulers

def eulersToVectors(EulerList eulers, bint useDegree):
    cdef Vector3DList vectors = Vector3DList(length = len(eulers))
    cdef Py_ssize_t i
    if useDegree:
        for i in range(len(eulers)):
            vectors.data[i].x = eulers.data[i].x * radianToDegreeFactor
            vectors.data[i].y = eulers.data[i].y * radianToDegreeFactor
            vectors.data[i].z = eulers.data[i].z * radianToDegreeFactor
    else:
        for i in range(len(eulers)):
            vectors.data[i].x = eulers.data[i].x
            vectors.data[i].y = eulers.data[i].y
            vectors.data[i].z = eulers.data[i].z
    return vectors

def getAxisListOfEulerList(EulerList eulers, str axis, bint useDegree):
    assert axis in "xyz"
    cdef DoubleList output = DoubleList(length = eulers.length)
    cdef float factor = radianToDegreeFactor if useDegree else 1
    cdef Py_ssize_t i
    if axis == "x":
        for i in range(output.length):
            output.data[i] = eulers.data[i].x * factor
    elif axis == "y":
        for i in range(output.length):
            output.data[i] = eulers.data[i].y * factor
    elif axis == "z":
        for i in range(output.length):
            output.data[i] = eulers.data[i].z * factor
    return output

def combineQuaternionList(Py_ssize_t amount,
                          VirtualDoubleList w, VirtualDoubleList x,
                          VirtualDoubleList y, VirtualDoubleList z):
    cdef QuaternionList output = QuaternionList(length = amount)
    cdef Py_ssize_t i
    for i in range(amount):
        output.data[i].w = <float>w.get(i)
        output.data[i].x = <float>x.get(i)
        output.data[i].y = <float>y.get(i)
        output.data[i].z = <float>z.get(i)
        quaternionNormalize_InPlace(&output.data[i])
    return output

def getAxisListOfQuaternionList(QuaternionList quaternions, str axis):
    assert axis in "wxyz"
    cdef DoubleList output = DoubleList(length = quaternions.length)
    cdef Py_ssize_t i
    if axis == "w":
        for i in range(output.length):
            output.data[i] = quaternions.data[i].w
    elif axis == "x":
        for i in range(output.length):
            output.data[i] = quaternions.data[i].x
    elif axis == "y":
        for i in range(output.length):
            output.data[i] = quaternions.data[i].y
    elif axis == "z":
        for i in range(output.length):
            output.data[i] = quaternions.data[i].z
    return output

#base on the expression from http://planning.cs.uiuc.edu/node198.html
def randomQuaternionList(int seed, int amount):
    cdef QuaternionList result = QuaternionList(length = amount)
    cdef XoShiRo256Plus rng = XoShiRo256Plus(seed)
    cdef double u1, u2, u3, k1, k2
    cdef Py_ssize_t i
    for i in range(amount):
        u1 = rng.nextFloat()
        u2 = rng.nextFloat() * 2 * PI
        u3 = rng.nextFloat() * 2 * PI
        k1 = sqrt(1 - u1)
        k2 = sqrt(u1)
        result.data[i].w = k1 * sin(u2)
        result.data[i].x = k1 * cos(u2)
        result.data[i].y = k2 * sin(u3)
        result.data[i].z = k2 * cos(u3)
        quaternionNormalize_InPlace(result.data + i)

    return result

def quaternionListToMatrixList(QuaternionList qs):
    cdef Py_ssize_t i
    cdef long amount = qs.length
    cdef Matrix4x4List ms = Matrix4x4List(length = amount)

    for i in range(amount):
        quaternionToMatrix4(ms.data + i, qs.data + i)
    return ms

def eulerListToQuaternionList(EulerList es):
    cdef Py_ssize_t i
    cdef long amount = es.length
    cdef QuaternionList qs = QuaternionList(length = amount)

    for i in range(amount):
        euler3ToQuaternion(qs.data + i, es.data + i)

    return qs

def quaternionListToEulerList(QuaternionList qs):
    cdef Py_ssize_t i
    cdef long amount = qs.length
    cdef EulerList es = EulerList(length = amount)

    for i in range(amount):
        quaternionToEuler3(es.data + i, qs.data + i)

    return es

def axisListAngleListToQuaternionList(Vector3DList vs, DoubleList angles, bint useDegree = False):
    cdef Py_ssize_t i
    cdef long amount = vs.length
    cdef QuaternionList qs = QuaternionList(length = amount)

    for i in range(amount):
        angle = <float>angles.data[i]
        if useDegree:
            angle = angle * degreeToRadianFactor

        quaternionFromAxisAngle(qs.data + i, vs.data + i, angle)
        quaternionNormalize_InPlace(qs.data + i)

    return qs

def quaternionListToAxisListAngleList(QuaternionList qs, bint useDegree = False):
    cdef Py_ssize_t i
    cdef float angle
    cdef long amount = qs.length
    cdef Vector3DList vs = Vector3DList(length = amount)
    cdef DoubleList angles = DoubleList(length = amount)

    for i in range(amount):
        quaternionToAxisAngle(vs.data + i, &angle, qs.data + i)
        normalizeVec3_InPlace(vs.data + i)

        if useDegree:
            angle *= radianToDegreeFactor
        angles.data[i] = angle

    return vs, angles

def eulerListToFlatDoubleList(EulerList es):
    cdef Py_ssize_t i, index
    cdef long amount = es.length
    cdef DoubleList vs = DoubleList(length = 3 * amount)

    index = 0
    for i in range(amount):
        vs.data[index] = es.data[i].x
        index += 1
        vs.data[index] = es.data[i].y
        index += 1
        vs.data[index] = es.data[i].z
        index += 1

    return vs

def flatDoubleListToEulerList(DoubleList vs):
    cdef Py_ssize_t i, index
    cdef long amount = <long>(vs.length / 3)
    cdef EulerList es = EulerList(length = amount)

    index = 0
    for i in range(amount):
        es.data[i].order = 0
        es.data[i].x = vs.data[index]
        index += 1
        es.data[i].y = vs.data[index]
        index += 1
        es.data[i].z = vs.data[index]
        index += 1

    return es
