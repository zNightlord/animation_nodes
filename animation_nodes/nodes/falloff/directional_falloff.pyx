import bpy
from bpy.props import *
from ... data_structures cimport BaseFalloff
from ... base_types import AnimationNode
from . constant_falloff import ConstantFalloff
from ... math cimport Vector3, setVector3, normalizeVec3_InPlace
from ... math cimport signedDistancePointToPlane_Normalized as signedDistance

class DirectionalFalloffNode(AnimationNode, bpy.types.Node):
    bl_idname = "an_DirectionalFalloffNode"
    bl_label = "Directional Falloff"

    __annotations__ = {}
    __annotations__["falloffLeft"] = BoolProperty(name = "Falloff Left", default = False)
    __annotations__["falloffRight"] = BoolProperty(name = "Falloff Right", default = True)

    def create(self):
        self.newInput("Vector", "Position", "position")
        self.newInput("Vector", "Direction", "direction", value = (1, 0, 0))
        self.newInput("Float", "Size", "size", value = 2, minValue = 0)
        self.newOutput("Falloff", "Falloff", "falloff")

    def draw(self, layout):
        row = layout.row(align = True)
        row.prop(self, "falloffLeft", icon = "TRIA_LEFT", text = "Left")
        row.prop(self, "falloffRight", icon = "TRIA_RIGHT", text = "Right")

    def execute(self, position, direction, size):
        size = max(0.0001, size)
        if self.falloffLeft and self.falloffRight:
            return BiDirectionalFalloff(position, direction, size)
        elif self.falloffLeft:
            return UniDirectionalFalloff(position, -direction, size)
        elif self.falloffRight:
            return UniDirectionalFalloff(position, direction, size)
        else:
            return ConstantFalloff(0)


cdef class DirectionalFalloff(BaseFalloff):
    cdef float size
    cdef Vector3 position, direction

    def __cinit__(self, position, direction, float size):
        assert size >= 0
        if size == 0: size = 0.00001
        setVector3(&self.position, position)
        setVector3(&self.direction, direction)
        normalizeVec3_InPlace(&self.direction)
        self.size = size
        self.clamped = True
        self.dataType = "LOCATION"

cdef class UniDirectionalFalloff(DirectionalFalloff):
    cdef float evaluate(self, void *value, Py_ssize_t index):
        cdef float distance = signedDistance(&self.position, &self.direction, <Vector3*>value)
        cdef float result = 1 - distance / self.size
        if result < 0: return 0
        if result > 1: return 1
        return result

cdef class BiDirectionalFalloff(DirectionalFalloff):
    cdef float evaluate(self, void *value, Py_ssize_t index):
        cdef float distance = abs(signedDistance(&self.position, &self.direction, <Vector3*>value))
        cdef float result = 1 - distance / self.size
        if result < 0: return 0
        return result
