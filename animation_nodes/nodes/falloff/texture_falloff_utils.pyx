import cython
from mathutils import Vector
from ... math cimport Vector3
from ... data_structures cimport BaseFalloff

cdef class calculateTextureFalloff(BaseFalloff):
    cdef:
        texture
        str mode
        matrix
        bint invert

    def __cinit__(self, texture, str modeInput, matrixInput, bint invertInput):
        self.texture = texture
        self.mode = modeInput
        self.matrix = matrixInput
        self.invert = invertInput

        self.dataType = "LOCATION"
        self.clamped = True

    cdef float evaluate(self, void *value, Py_ssize_t index):
        return calculateStrength(self, <Vector3*>value)

    cdef void evaluateList(self, void *values, Py_ssize_t startIndex, Py_ssize_t amount, float *target):
        cdef Py_ssize_t i
        for i in range(amount):
            target[i] = calculateStrength(self, <Vector3*>values + i)

cdef inline float calculateStrength(calculateTextureFalloff self, Vector3 *v):
    cdef float strength = colorValue(self, Vector((v.x, v.y, v.z)))
    if self.invert:
        return 1 - strength
    return strength

@cython.cdivision(True)
cdef float colorValue(calculateTextureFalloff self, v):
    v = self.matrix @ v
    cdef float r, g, b, a
    if self.mode == "INTENSITY":
        r, g, b, a = self.texture.evaluate(v)
        return (r + g + b) / 3.0
    elif self.mode == "RED":
        return self.texture.evaluate(v)[0]
    elif self.mode == "GREEN":
        return self.texture.evaluate(v)[1]
    elif self.mode == "BLUE":
        return self.texture.evaluate(v)[2]
    elif self.mode == "ALPHA":
        return self.texture.evaluate(v)[3]
