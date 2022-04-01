import cython
from mathutils import Vector
from ... data_structures import GPStroke
from ... math cimport Vector3, toVector3
from ... algorithms.mesh_generation.line import getLinesMesh
from ... data_structures cimport(
    Mesh,
    ColorList,
    FloatList,
    PolySpline,
    Vector3DList,
    FalloffEvaluator,
)

# Reference https://blender.stackexchange.com/questions/94991/trace-visualisation-in-3d-how-to-wrap-curves-onto-a-3d-mesh/95577#95577
@cython.cdivision(True)
def curlOfFalloff2D(Vector3DList vectorsIn, long iterations, float step, long style, str noiseMode,
                    baseNoise, FalloffEvaluator evaluator):
    cdef long amount = vectorsIn.length
    cdef long twiAmount = 2 * amount
    cdef Vector3DList vectors = Vector3DList(length = amount)
    cdef FloatList values = FloatList(length = 4 * twiAmount)
    cdef Vector3DList vectorsForFalloff = Vector3DList(length = 4 * twiAmount)
    cdef Vector3DList curlVectors = Vector3DList(length = amount * iterations)
    cdef Vector3DList curls = Vector3DList(length = amount * iterations)
    cdef Vector3 vector
    cdef float dFxdx, dFydy
    cdef float dr = 1.0 / (2.0 * max(step, 0.00001))
    cdef long amountX1, amountX2, amountX3, amountX4
    cdef Py_ssize_t i, j, index

    amountX1 = amount
    amountX2 = 2 * amount
    amountX3 = 3 * amount
    amountX4 = 4 * amount

    # Initialization of vectors.
    for i in range(amount):
        vector = vectorsIn.data[i]
        vectors.data[i] = vector

    curls.fill((0, 0, 0))
    curlVectors.fill((0, 0, 0))
    vectorsForFalloff.fill((0, 0, 0))
    values.fill(0)
    index = 0
    for i in range(iterations):
        # Set vectors from previous step.
        for j in range(amount):
            vector = vectors.data[j]
            curlVectors.data[j + index] = vector

            # Change along x-axis.
            vectorsForFalloff.data[j] = vector
            vectorsForFalloff.data[j].x += step
            vectorsForFalloff.data[amountX1 + j] = vector
            vectorsForFalloff.data[amountX1 + j].x -= step

            # Change along y-axis.
            vectorsForFalloff.data[amountX2 + j] = vector
            vectorsForFalloff.data[amountX2 + j].y += step
            vectorsForFalloff.data[amountX3 + j] = vector
            vectorsForFalloff.data[amountX3 + j].y -= step

        # Calculate falloff field.
        values = evaluator.evaluateList(vectorsForFalloff)

        # Calculate curl.
        for j in range(amount):
            dFxdx = (values.data[j] - values.data[amountX1 + j]) * dr
            dFydy = (values.data[amountX2 + j] - values.data[amountX3 + j]) * dr
            if style == 1:
                vectors.data[j].x += dFydy
                vectors.data[j].y -= dFxdx
                curls.data[j + index].x = dFydy
                curls.data[j + index].y = -dFxdx
            elif style == 2:
                vectors.data[j].x += dFydy
                vectors.data[j].y += dFxdx
                curls.data[j + index].x = dFydy
                curls.data[j + index].y = dFxdx
            elif style == 3:
                vectors.data[j].x += dFxdx
                vectors.data[j].y += dFydy
                curls.data[j + index].x = dFxdx
                curls.data[j + index].y = dFydy
            elif style == 4:
                vectors.data[j].x -= dFxdx
                vectors.data[j].y += dFydy
                curls.data[j + index].x = -dFxdx
                curls.data[j + index].y = dFydy

        index += amount

    return curlVectors, curls


@cython.cdivision(True)
def curlOfFalloff3D(Vector3DList vectorsIn, long iterations, float step, str noiseMode, baseNoise,
                    FalloffEvaluator evaluator):
    cdef long amount = vectorsIn.length
    cdef long triAmount = 3 * amount
    cdef Vector3DList vectors = Vector3DList(length = amount)
    cdef Vector3DList normals = Vector3DList(length = amount)
    cdef Vector3DList vectorsOffset = Vector3DList(length = triAmount)
    cdef FloatList dFdx = FloatList(length = triAmount)
    cdef FloatList dFdy = FloatList(length = triAmount)
    cdef FloatList dFdz = FloatList(length = triAmount)
    cdef FloatList values = FloatList(length = 6 * triAmount)
    cdef Vector3DList vectorsForFalloff = Vector3DList(length = 6 * triAmount)
    cdef Vector3DList curlVectors = Vector3DList(length = amount * iterations)
    cdef Vector3DList curls = Vector3DList(length = amount * iterations)
    cdef Vector3 vector, vectorNew
    cdef float dr = 1.0 / (2.0 * max(step, 0.00001))
    cdef float dFydx, dFzdx, dFxdy, dFzdy, dFxdz, dFydz
    cdef long amountX1, amountX2, triAmountX1, triAmountX2, triAmountX3, triAmountX4, triAmountX5, triAmountX6
    cdef Py_ssize_t i, j, index

    amountX1 = amount
    amountX2 = 2 * amount
    triAmountX1 = triAmount
    triAmountX2 = 2 * triAmount
    triAmountX3 = 3 * triAmount
    triAmountX4 = 4 * triAmount
    triAmountX5 = 5 * triAmount
    triAmountX6 = 6 * triAmount

    # Initialization of vectors.
    for i in range(amount):
        vector = vectorsIn.data[i]
        vectors.data[i] = vector

    curls.fill((0, 0, 0))
    curlVectors.fill((0, 0, 0))
    vectorsForFalloff.fill((0, 0, 0))
    values.fill(0)
    index = 0
    for i in range(iterations):
        # Set vectors from previous step.
        for j in range(amount):
            vector = vectors.data[j]
            curlVectors.data[j + index] = vector

            vectorsOffset.data[j] = vector

            vectorNew.x = vector.x + 1000.0
            vectorNew.y = vector.y + 1000.0
            vectorNew.z = vector.z + 1000.0
            vectorsOffset.data[amountX1 + j] = vectorNew

            vectorNew.x += 1000.0
            vectorNew.y += 1000.0
            vectorNew.z += 1000.0
            vectorsOffset.data[amountX2 + j] = vectorNew

        for j in range(triAmount):
            vector = vectorsOffset.data[j]

            # Change along x-axis.
            vectorsForFalloff.data[j] = vector
            vectorsForFalloff.data[j].x += step
            vectorsForFalloff.data[triAmountX1 + j] = vector
            vectorsForFalloff.data[triAmountX1 + j].x -= step

            # Change along y-axis.
            vectorsForFalloff.data[triAmountX2 + j] = vector
            vectorsForFalloff.data[triAmountX2 + j].y += step
            vectorsForFalloff.data[triAmountX3 + j] = vector
            vectorsForFalloff.data[triAmountX3 + j].y -= step

            # Change along z-axis.
            vectorsForFalloff.data[triAmountX4 + j] = vector
            vectorsForFalloff.data[triAmountX4 + j].z += step
            vectorsForFalloff.data[triAmountX5 + j] = vector
            vectorsForFalloff.data[triAmountX5 + j].z -= step

        # Calculate falloff field.
        values = evaluator.evaluateList(vectorsForFalloff)

        # Calculate curl.
        for j in range(triAmount):
            dFdx.data[j] = (values.data[j] - values.data[triAmountX1 + j]) * dr
            dFdy.data[j] = (values.data[triAmountX2 + j] - values.data[triAmountX3 + j]) * dr
            dFdz.data[j] = (values.data[triAmountX4 + j] - values.data[triAmountX5 + j]) * dr

        for j in range(amount):
            # dFxdx = dFdx.data[j]
            dFydx = dFdx.data[amountX1 + j]
            dFzdx = dFdx.data[amountX2 + j]

            dFxdy = dFdy.data[j]
            # dFydy = dFdy.data[amountX1 + j]
            dFzdy = dFdy.data[amountX2 + j]

            dFxdz = dFdz.data[j]
            dFydz = dFdz.data[amountX1 + j]
            # dFzdz = dFdz.data[amountX2 + j]

            vectors.data[j].x += dFzdy - dFydz
            vectors.data[j].y += dFxdz - dFzdx
            vectors.data[j].z += dFydx - dFxdy

            curls.data[j + index].x = dFzdy - dFydz
            curls.data[j + index].y = dFxdz - dFzdx
            curls.data[j + index].z = dFydx - dFxdy

        index += amount

    return curlVectors, curls

@cython.cdivision(True)
def curlOfFalloff3DOnMesh(Vector3DList vectorsIn, long iterations, float step, bvhTree,
                          float maxDistance, str noiseMode, baseNoise, FalloffEvaluator evaluator,
                          bint relativeCurls):
    cdef long amount = vectorsIn.length
    cdef Vector3DList vectors = Vector3DList(length = amount)
    cdef Vector3DList normals = Vector3DList(length = amount)
    cdef FloatList values = FloatList(length = 6 * amount)
    cdef Vector3DList vectorsForFalloff = Vector3DList(length = 6 * amount)
    cdef Vector3DList curlVectors = Vector3DList(length = amount * iterations)
    cdef Vector3DList curls = Vector3DList(length = amount * iterations)
    cdef Vector3 vector, normal
    cdef float dr = 1.0 / (2.0 * max(step, 0.00001))
    cdef float dFdx, dFdy, dFdz
    cdef long amountX1, amountX2, amountX3, amountX4, amountX5, amountX6
    cdef Py_ssize_t i, j, index

    amountX1 = amount
    amountX2 = 2 * amount
    amountX3 = 3 * amount
    amountX4 = 4 * amount
    amountX5 = 5 * amount
    amountX6 = 6 * amount

    # Initialization of vectors.
    for i in range(amount):
        vectors.data[i] = vectorsIn.data[i]

    vectorsForFalloff.fill((0, 0, 0))
    curlVectors.fill((0, 0, 0))
    curls.fill((0, 0, 0))
    values.fill(0)
    index = 0
    for i in range(iterations):
        # Project vectors on mesh, and set vectors from previous step.
        for j in range(amount):
            vector = vectors.data[j]
            bvhVector, bvhNormal = bvhTree.find_nearest(Vector((vector.x, vector.y, vector.z)), maxDistance)[:2]
            vector = toVector3(bvhVector)
            normals.data[j] = toVector3(bvhNormal)

            vectors.data[j] = vector
            curlVectors.data[j + index] = vector

            # Change along x-axis.
            vectorsForFalloff.data[j] = vector
            vectorsForFalloff.data[j].x += step
            vectorsForFalloff.data[amountX1 + j] = vector
            vectorsForFalloff.data[amountX1 + j].x -= step

            # Change along y-axis.
            vectorsForFalloff.data[amountX2 + j] = vector
            vectorsForFalloff.data[amountX2 + j].y += step
            vectorsForFalloff.data[amountX3 + j] = vector
            vectorsForFalloff.data[amountX3 + j].y -= step

            # Change along z-axis.
            vectorsForFalloff.data[amountX4 + j] = vector
            vectorsForFalloff.data[amountX4 + j].z += step
            vectorsForFalloff.data[amountX5 + j] = vector
            vectorsForFalloff.data[amountX5 + j].z -= step

        # Calculate falloff field.
        values = evaluator.evaluateList(vectorsForFalloff)

        # Calculate curl.
        for j in range(amount):
            dFdx = (values.data[j] - values.data[amountX1 + j]) * dr
            dFdy = (values.data[amountX2 + j] - values.data[amountX3 + j]) * dr
            dFdz = (values.data[amountX4 + j] - values.data[amountX5 + j]) * dr

            normal = normals.data[j]
            vectors.data[j].x += normal.z * dFdy - normal.y * dFdz
            vectors.data[j].y += normal.x * dFdz - normal.z * dFdx
            vectors.data[j].z += normal.y * dFdx - normal.x * dFdy

        if relativeCurls:
            for j in range(amount):
                curls.data[j + index].x = vectors.data[j].x - vectorsIn.data[j].x
                curls.data[j + index].y = vectors.data[j].y - vectorsIn.data[j].y
                curls.data[j + index].z = vectors.data[j].z - vectorsIn.data[j].z
        else:
            for j in range(amount):
                curls.data[j + index].x = vectors.data[j].x - curlVectors.data[j + index].x
                curls.data[j + index].y = vectors.data[j].y - curlVectors.data[j + index].y
                curls.data[j + index].z = vectors.data[j].z - curlVectors.data[j + index].z

        index += amount

    return curlVectors, curls

@cython.cdivision(True)
def gradientOfFalloff3D(Vector3DList vectorsIn, long iterations, float step, axisScale,
                        str noiseMode, baseNoise, FalloffEvaluator evaluator):
    cdef long amount = vectorsIn.length
    cdef Vector3DList vectors = Vector3DList(length = amount)
    cdef FloatList values = FloatList(length = 6 * amount)
    cdef Vector3DList vectorsForFalloff = Vector3DList(length = 6 * amount)
    cdef Vector3DList gradientVectors = Vector3DList(length = amount * iterations)
    cdef Vector3DList gradients = Vector3DList(length = amount * iterations)
    cdef Vector3 vector
    cdef Vector3 newAxisScale = toVector3(axisScale)
    cdef float dr = 1.0 / (2.0 * max(step, 0.00001))
    cdef float dFdx, dFdy, dFdz
    cdef long amountX1, amountX2, amountX3, amountX4, amountX5, amountX6
    cdef Py_ssize_t i, j, index

    amountX1 = amount
    amountX2 = 2 * amount
    amountX3 = 3 * amount
    amountX4 = 4 * amount
    amountX5 = 5 * amount
    amountX6 = 6 * amount

    # Initialization of vectors.
    for i in range(amount):
        vector = vectorsIn.data[i]
        vectors.data[i] = vector

    vectorsForFalloff.fill((0, 0, 0))
    gradientVectors.fill((0, 0, 0))
    gradients.fill((0, 0, 0))
    values.fill(0)
    index = 0
    for i in range(iterations):
        # Set vectors from previous step.
        for j in range(amount):
            vector = vectors.data[j]
            gradientVectors.data[j + index] = vector

            # Change along x-axis.
            vectorsForFalloff.data[j] = vector
            vectorsForFalloff.data[j].x += step
            vectorsForFalloff.data[amountX1 + j] = vector
            vectorsForFalloff.data[amountX1 + j].x -= step

            # Change along y-axis.
            vectorsForFalloff.data[amountX2 + j] = vector
            vectorsForFalloff.data[amountX2 + j].y += step
            vectorsForFalloff.data[amountX3 + j] = vector
            vectorsForFalloff.data[amountX3 + j].y -= step

            # Change along z-axis.
            vectorsForFalloff.data[amountX4 + j] = vector
            vectorsForFalloff.data[amountX4 + j].z += step
            vectorsForFalloff.data[amountX5 + j] = vector
            vectorsForFalloff.data[amountX5 + j].z -= step

        # Calculate falloff field.
        values = evaluator.evaluateList(vectorsForFalloff)

        # Calculate curl noise.
        for j in range(amount):
            dFdx = (values.data[j] - values.data[amountX1 + j]) * dr * newAxisScale.x
            dFdy = (values.data[amountX2 + j] - values.data[amountX3 + j]) * dr * newAxisScale.y
            dFdz = (values.data[amountX4 + j] - values.data[amountX5 + j]) * dr * newAxisScale.z

            vectors.data[j].x += dFdx
            vectors.data[j].y += dFdy
            vectors.data[j].z += dFdz

            gradients.data[j + index].x = dFdx
            gradients.data[j + index].y = dFdy
            gradients.data[j + index].z = dFdz

        index += amount

    return gradientVectors, gradients

@cython.cdivision(True)
def gradientOfFalloff3DOnMesh(Vector3DList vectorsIn, long iterations, float step, bvhTree,
                              float maxDistance, str noiseMode, baseNoise, FalloffEvaluator evaluator,
                              bint relativeGradients):
    cdef long amount = vectorsIn.length
    cdef Vector3DList vectors = Vector3DList(length = amount)
    cdef FloatList values = FloatList(length = 6 * amount)
    cdef Vector3DList vectorsForFalloff = Vector3DList(length = 6 * amount)
    cdef Vector3DList gradientVectors = Vector3DList(length = amount * iterations)
    cdef Vector3DList gradients = Vector3DList(length = amount * iterations)
    cdef Vector3 vector
    cdef float dr = 1.0 / (2.0 * max(step, 0.00001))
    cdef float dFdx, dFdy, dFdz
    cdef long amountX1, amountX2, amountX3, amountX4, amountX5, amountX6
    cdef Py_ssize_t i, j, index

    amountX1 = amount
    amountX2 = 2 * amount
    amountX3 = 3 * amount
    amountX4 = 4 * amount
    amountX5 = 5 * amount
    amountX6 = 6 * amount

    # Initialization of vectors.
    for i in range(amount):
        vectors.data[i] = vectorsIn.data[i]

    vectorsForFalloff.fill((0, 0, 0))
    gradientVectors.fill((0, 0, 0))
    gradients.fill((0, 0, 0))
    values.fill(0)
    index = 0
    for i in range(iterations):
        # Project vectors on mesh, and set vectors from previous step.
        for j in range(amount):
            vector = vectors.data[j]

            bvhVector = bvhTree.find_nearest(Vector((vector.x, vector.y, vector.z)), maxDistance)[0]
            vector = toVector3(bvhVector)
            vectors.data[j] = vector

            gradientVectors.data[j + index] = vector

            # Change along x-axis.
            vectorsForFalloff.data[j] = vector
            vectorsForFalloff.data[j].x += step
            vectorsForFalloff.data[amountX1 + j] = vector
            vectorsForFalloff.data[amountX1 + j].x -= step

            # Change along y-axis.
            vectorsForFalloff.data[amountX2 + j] = vector
            vectorsForFalloff.data[amountX2 + j].y += step
            vectorsForFalloff.data[amountX3 + j] = vector
            vectorsForFalloff.data[amountX3 + j].y -= step

            # Change along z-axis.
            vectorsForFalloff.data[amountX4 + j] = vector
            vectorsForFalloff.data[amountX4 + j].z += step
            vectorsForFalloff.data[amountX5 + j] = vector
            vectorsForFalloff.data[amountX5 + j].z -= step

        # Calculate falloff field.
        values = evaluator.evaluateList(vectorsForFalloff)

        # Calculate curl noise.
        for j in range(amount):
            dFdx = (values.data[j] - values.data[amountX1 + j]) * dr
            dFdy = (values.data[amountX2 + j] - values.data[amountX3 + j]) * dr
            dFdz = (values.data[amountX4 + j] - values.data[amountX5 + j]) * dr

            vectors.data[j].x += dFdx
            vectors.data[j].y += dFdy
            vectors.data[j].z += dFdz

        if relativeGradients:
            for j in range(amount):
                gradients.data[j + index].x = vectors.data[j].x - vectorsIn.data[j].x
                gradients.data[j + index].y = vectors.data[j].y - vectorsIn.data[j].y
                gradients.data[j + index].z = vectors.data[j].z - vectorsIn.data[j].z
        else:
            for j in range(amount):
                gradients.data[j + index].x = vectors.data[j].x - gradientVectors.data[j + index].x
                gradients.data[j + index].y = vectors.data[j].y - gradientVectors.data[j + index].y
                gradients.data[j + index].z = vectors.data[j].z - gradientVectors.data[j + index].z

        index += amount

    return gradientVectors, gradients


def getCurvesPerVectors(long amount, long iterations, Vector3DList vectorsIn,
                        str curveType = "MESH"):
    cdef list meshes, splines, strokes
    cdef Vector3DList vectors
    cdef Py_ssize_t i, j

    if curveType == "MESH":
        meshes = []
        for i in range(amount):
            vectors = Vector3DList(length = iterations)
            for j in range(iterations):
                vectors.data[j] = vectorsIn.data[i + j * amount]
            meshes.append(getLinesMesh(vectors, False))

        return meshes

    elif curveType == "SPLINE":
        splines = []
        for i in range(amount):
            vectors = Vector3DList(length = iterations)
            for j in range(iterations):
                vectors.data[j] = vectorsIn.data[i + j * amount]
            splines.append(PolySpline.__new__(PolySpline, vectors))
        return splines

    elif curveType == "STROKE":
        strokes = []
        for i in range(amount):
            vectors = Vector3DList(length = iterations)
            for j in range(iterations):
                vectors.data[j] = vectorsIn.data[i + j * amount]
            strengths = FloatList(length = iterations)
            pressures = FloatList(length = iterations)
            uvRotations = FloatList(length = iterations)
            vertexColors = ColorList(length = iterations)
            strengths.fill(1)
            pressures.fill(1)
            uvRotations.fill(0)
            vertexColors.fill((0, 0, 0, 0))
            strokes.append(GPStroke(vectors, strengths, pressures, uvRotations, vertexColors, 10))

        return strokes

def getCurvesPerIterations(long amount, long iterations, Vector3DList vectorsIn,
                           str curveType = "MESH", bint cyclic = False):
    cdef list meshes, splines, strokes
    cdef Vector3DList vectors
    cdef PolySpline spline
    cdef Py_ssize_t i, j

    if curveType == "MESH":
        meshes = []
        for i in range(iterations):
            vectors = Vector3DList(length = amount)
            for j in range(amount):
                vectors.data[j] = vectorsIn.data[i * amount + j]
            meshes.append(getLinesMesh(vectors, cyclic))

        return meshes

    elif curveType == "SPLINE":
        splines = []
        for i in range(iterations):
            vectors = Vector3DList(length = amount)
            for j in range(amount):
                vectors.data[j] = vectorsIn.data[i * amount + j]
            spline = PolySpline.__new__(PolySpline, vectors)
            spline.cyclic = cyclic
            splines.append(spline)
        return splines

    elif curveType == "STROKE":
        strokes = []
        for i in range(iterations):
            vectors = Vector3DList(length = amount)
            for j in range(amount):
                vectors.data[j] = vectorsIn.data[i * amount + j]
            strengths = FloatList(length = amount)
            pressures = FloatList(length = amount)
            uvRotations = FloatList(length = amount)
            vertexColors = ColorList(length = amount)
            strengths.fill(1)
            pressures.fill(1)
            uvRotations.fill(0)
            vertexColors.fill((0, 0, 0, 0))
            stroke = GPStroke(vectors, strengths, pressures, uvRotations, vertexColors, 10)
            stroke.drawCyclic = cyclic
            strokes.append(stroke)

        return strokes
