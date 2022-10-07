import bpy
from ... base_types import AnimationNode
from ... data_structures cimport BaseFalloff, FloatList
from . interpolate_falloff import InterpolateFalloff

class DelayFalloffNode(AnimationNode, bpy.types.Node):
    bl_idname = "an_DelayFalloffNode"
    bl_label = "Delay Falloff"

    def create(self):
        self.newInput("Float", "Time", "time")
        self.newInput("Float", "Delay", "delay", value = 5)
        self.newInput("Float", "Duration", "duration", value = 20)
        self.newInput("Interpolation", "Interpolation", "interpolation", defaultDrawType = "PROPERTY_ONLY")
        self.newInput("Float List", "Offsets", "offsets")
        self.newOutput("Falloff", "Falloff", "falloff")

    def execute(self, frame, delay, duration, interpolation, offsets):
        _offsets = FloatList.fromValues(offsets)
        falloff = DelayFalloff(frame, delay, duration, _offsets)
        return InterpolateFalloff(falloff, interpolation)

cdef class DelayFalloff(BaseFalloff):
    cdef float frame
    cdef float delay
    cdef float duration
    cdef FloatList offsets

    def __cinit__(self, float frame, float delay, float duration, FloatList offsets = None):
        self.frame = frame
        self.delay = delay
        self.duration = duration
        self.offsets = FloatList() if offsets is None else offsets
        self.clamped = True
        self.dataType = "NONE"

    cdef float evaluate(self, void *object, Py_ssize_t index):
        cdef float offset
        if index >= self.offsets.length: offset = index
        else: offset = self.offsets.data[index]

        cdef float localFrame = self.frame - offset * self.delay
        if localFrame <= 0: return 0
        if localFrame <= self.duration: return localFrame / self.duration
        return 1
