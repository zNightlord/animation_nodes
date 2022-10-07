import bpy
from bpy.props import *
from ... base_types import AnimationNode
from . constant_falloff import ConstantFalloff
from ... data_structures cimport CompoundFalloff, Falloff

mixTypeItems = [
    ("ADD", "Add", "", "NONE", 0),
    ("MULTIPLY", "Multiply", "", "NONE", 1),
    ("MAX", "Max", "", "NONE", 2),
    ("MIN", "Min", "", "NONE", 3),
    ("SUBTRACT", "Subtract", "", "NONE", 4),
    ("OVERLAY", "Overlay", "", "NONE", 5),
]

# Types that don't support list mixing.
onlyTwoTypes = ["SUBTRACT", "OVERLAY"]

class MixFalloffsNode(AnimationNode, bpy.types.Node):
    bl_idname = "an_MixFalloffsNode"
    bl_label = "Mix Falloffs"
    errorHandlingType = "EXCEPTION"

    __annotations__ = {}

    __annotations__["mixType"] = EnumProperty(name = "Mix Type", items = mixTypeItems,
        default = "MAX", update = AnimationNode.refresh)

    __annotations__["mixFalloffList"] = BoolProperty(name = "Mix Falloff List", default = False,
        update = AnimationNode.refresh)

    def create(self):
        if self.mixFalloffList:
            self.newInput("Falloff List", "Falloffs", "falloffs")
        else:
            self.newInput("Falloff", "A", "a")
            self.newInput("Falloff", "B", "b")
        self.newOutput("Falloff", "Falloff", "falloff")

    def draw(self, layout):
        row = layout.row(align = True)
        row.prop(self, "mixType", text = "")
        row.prop(self, "mixFalloffList", text = "", icon = "LINENUMBERS_ON")

    def getExecutionFunctionName(self):
        if self.mixFalloffList:
            return "execute_List"
        else:
            return "execute_Two"

    def execute_List(self, falloffs):
        if self.mixType in onlyTwoTypes:
            self.raiseErrorMessage("The chosen mix type doesn't support list mixing.")
        return MixFalloffs(falloffs, self.mixType, default = 1)

    def execute_Two(self, a, b):
        return MixFalloffs([a, b], self.mixType, default = 1)


class MixFalloffs:
    def __new__(cls, list falloffs not None, str method not None, double default = 1):
        if len(falloffs) == 0:
            return ConstantFalloff(default)
        elif len(falloffs) == 1:
            return falloffs[0]
        elif len(falloffs) == 2:
            if method == "ADD": return AddTwoFalloffs(*falloffs)
            elif method == "MULTIPLY": return MultiplyTwoFalloffs(*falloffs)
            elif method == "MAX": return MaxTwoFalloffs(*falloffs)
            elif method == "MIN": return MinTwoFalloffs(*falloffs)
            elif method == "SUBTRACT": return SubtractTwoFalloffs(*falloffs)
            elif method == "OVERLAY": return OverlayTwoFalloffs(*falloffs)
            raise Exception("invalid method")
        else:
            if method == "ADD": return AddFalloffs(falloffs)
            elif method == "MULTIPLY": return MultiplyFalloffs(falloffs)
            elif method == "MAX": return MaxFalloffs(falloffs)
            elif method == "MIN": return MinFalloffs(falloffs)
            raise Exception("invalid method")


cdef class MixTwoFalloffsBase(CompoundFalloff):
    cdef:
        Falloff a, b

    def __cinit__(self, Falloff a, Falloff b):
        self.a = a
        self.b = b

    cdef list getDependencies(self):
        return [self.a, self.b]

cdef class AddTwoFalloffs(MixTwoFalloffsBase):
    cdef float evaluate(self, float *dependencyResults):
        return dependencyResults[0] + dependencyResults[1]

    cdef void evaluateList(self, float **dependencyResults, Py_ssize_t amount, float *target):
        cdef Py_ssize_t i
        cdef float *a = dependencyResults[0]
        cdef float *b = dependencyResults[1]
        for i in range(amount):
            target[i] = a[i] + b[i]

cdef class MultiplyTwoFalloffs(MixTwoFalloffsBase):
    cdef float evaluate(self, float *dependencyResults):
        return dependencyResults[0] * dependencyResults[1]

    cdef void evaluateList(self, float **dependencyResults, Py_ssize_t amount, float *target):
        cdef Py_ssize_t i
        cdef float *a = dependencyResults[0]
        cdef float *b = dependencyResults[1]
        for i in range(amount):
            target[i] = a[i] * b[i]

cdef class MinTwoFalloffs(MixTwoFalloffsBase):
    cdef float evaluate(self, float *dependencyResults):
        return min(dependencyResults[0], dependencyResults[1])

    cdef void evaluateList(self, float **dependencyResults, Py_ssize_t amount, float *target):
        cdef Py_ssize_t i
        cdef float *a = dependencyResults[0]
        cdef float *b = dependencyResults[1]
        for i in range(amount):
            target[i] = min(a[i], b[i])

cdef class MaxTwoFalloffs(MixTwoFalloffsBase):
    cdef float evaluate(self, float *dependencyResults):
        return max(dependencyResults[0], dependencyResults[1])

    cdef void evaluateList(self, float **dependencyResults, Py_ssize_t amount, float *target):
        cdef Py_ssize_t i
        cdef float *a = dependencyResults[0]
        cdef float *b = dependencyResults[1]
        for i in range(amount):
            target[i] = max(a[i], b[i])

cdef class SubtractTwoFalloffs(MixTwoFalloffsBase):
    cdef float evaluate(self, float *dependencyResults):
        return dependencyResults[0] - dependencyResults[1]

    cdef void evaluateList(self, float **dependencyResults, Py_ssize_t amount, float *target):
        cdef Py_ssize_t i
        cdef float *a = dependencyResults[0]
        cdef float *b = dependencyResults[1]
        for i in range(amount):
            target[i] = a[i] - b[i]

# Overlay is defined as follows:
# - First the A falloff is clamped.
# - If the A falloff evaluates to a value less than 0.5, the B falloff is
# evaluated and the overlay evaluates to (A + B * A), or more compactly,
# (A *(1 + B)).  Essentially, B has no effect when A is zero and have the
# maximum effect when A is 0.5. Since B is multiplied by A, only half of
# B is added at its maximum, which is artistically desirable to have the
# overlay in the [0, 1] range assuming B is clamped.
# - If the A falloff evaluates to a value larger than 0.5. The same
# evaluation happens but in reverse. In particular, B has no effect when
# A is 1 and have the maximum effect when A is 0.5.
cdef class OverlayTwoFalloffs(MixTwoFalloffsBase):
    cdef list getClampingRequirements(self):
        return [True, False]

    cdef float evaluate(self, float *dependencyResults):
        cdef float a = dependencyResults[0]
        cdef float b = dependencyResults[1]
        if a < 0.5:
            return a * (1 + b)
        else:
            return a + b * (1 - a)

    cdef void evaluateList(self, float **dependencyResults, Py_ssize_t amount, float *target):
        cdef Py_ssize_t i
        cdef float *a = dependencyResults[0]
        cdef float *b = dependencyResults[1]
        for i in range(amount):
            if a[i] < 0.5:
                target[i] = a[i] * (1 + b[i])
            else:
                target[i] = a[i] + b[i] * (1 - a[i])


cdef class MixFalloffsBase(CompoundFalloff):
    cdef list falloffs
    cdef int amount

    def __init__(self, list falloffs not None):
        self.falloffs = falloffs
        self.amount = len(falloffs)
        if self.amount == 0:
            raise Exception("at least one falloff required")

    cdef list getDependencies(self):
        return self.falloffs

cdef class AddFalloffs(MixFalloffsBase):
    cdef float evaluate(self, float *dependencyResults):
        cdef int i
        cdef float sum = 0
        for i in range(self.amount):
            sum += dependencyResults[i]
        return sum

cdef class MultiplyFalloffs(MixFalloffsBase):
    cdef float evaluate(self, float *dependencyResults):
        cdef int i
        cdef float product = 1
        for i in range(self.amount):
            product *= dependencyResults[i]
        return product

cdef class MinFalloffs(MixFalloffsBase):
    cdef float evaluate(self, float *dependencyResults):
        cdef int i
        cdef float minValue = dependencyResults[0]
        for i in range(1, self.amount):
            if dependencyResults[i] < minValue:
                minValue = dependencyResults[i]
        return minValue

cdef class MaxFalloffs(MixFalloffsBase):
    cdef float evaluate(self, float *dependencyResults):
        cdef int i
        cdef float maxValue = dependencyResults[0]
        for i in range(1, self.amount):
            if dependencyResults[i] > maxValue:
                maxValue = dependencyResults[i]
        return maxValue
