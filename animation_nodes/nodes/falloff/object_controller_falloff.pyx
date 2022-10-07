import bpy
from bpy.props import *
from ... events import propertyChanged
from ... utils.depsgraph import getEvaluatedID
from ... algorithms.rotations import eulerToDirection
from ... base_types import AnimationNode, VectorizedSocket

from . mix_falloffs import MixFalloffs
from . invert_falloff import InvertFalloff
from . radial_falloff import RadialFalloff
from . constant_falloff import ConstantFalloff
from . interpolate_falloff import InterpolateFalloff
from . directional_falloff import UniDirectionalFalloff
from . point_distance_falloff import PointDistanceFalloff

falloffTypeItems = [
    ("SPHERE", "Sphere", "", "NONE", 0),
    ("DIRECTIONAL", "Directional", "", "NONE", 1),
    ("RADIAL", "Radial", "", "NONE", 2),
]

mixListTypeItems = [
    ("MAX", "Max", "", "NONE", 0),
    ("ADD", "Add", "", "NONE", 1),
]

axisDirectionItems = [(axis, axis, "") for axis in ("X", "Y", "Z", "-X", "-Y", "-Z")]

class ObjectControllerFalloffNode(AnimationNode, bpy.types.Node):
    bl_idname = "an_ObjectControllerFalloffNode"
    bl_label = "Object Controller Falloff"
    bl_width_default = 160

    __annotations__ = {}

    __annotations__["falloffType"] = EnumProperty(name = "Falloff Type", items = falloffTypeItems,
        update = AnimationNode.refresh)

    __annotations__["axisDirection"] = EnumProperty(name = "Axis Direction", default = "Z",
        items = axisDirectionItems, update = propertyChanged)

    __annotations__["mixListType"] = EnumProperty(name = "Mix List Type", default = "MAX",
        items = mixListTypeItems, update = propertyChanged)

    __annotations__["useObjectList"] = VectorizedSocket.newProperty()

    def create(self):
        self.newInput(VectorizedSocket("Object", "useObjectList",
            ("Object", "object", dict(defaultDrawType = "PROPERTY_ONLY")),
            ("Objects", "objects"),
            codeProperties = dict(allowListExtension = False)))

        if self.falloffType == "SPHERE":
            self.newInput("Float", "Offset", "offset", value = 0)
            self.newInput("Float", "Falloff Width", "falloffWidth", value = 1.0)

        if self.falloffType == "RADIAL":
            self.newInput("Float", "Phase", "phase")

        self.newInput("Interpolation", "Interpolation", "interpolation", defaultDrawType = "PROPERTY_ONLY")
        self.newInput("Boolean", "Invert", "invert", value = False)
        self.newOutput("Falloff", "Falloff", "falloff")

    def draw(self, layout):
        col = layout.column()
        col.prop(self, "falloffType", text = "")
        if self.falloffType in ("DIRECTIONAL", "RADIAL"):
            col.row().prop(self, "axisDirection", expand = True)
        if self.useObjectList:
            col.prop(self, "mixListType", text = "")

    def drawAdvanced(self, layout):
        self.invokeFunction(layout, "createAutoExecutionTrigger", text = "Create Execution Trigger")

    def getExecutionFunctionName(self):
        if self.useObjectList:
            if self.falloffType == "SPHERE":
                return "execute_Sphere_List"
            elif self.falloffType == "DIRECTIONAL":
                return "execute_Directional_List"
            elif self.falloffType == "RADIAL":
                return "execute_Radial_List"
        else:
            if self.falloffType == "SPHERE":
                return "execute_Sphere"
            elif self.falloffType == "DIRECTIONAL":
                return "execute_Directional"
            elif self.falloffType == "RADIAL":
                return "execute_Radial"

    def execute_Sphere_List(self, objects, offset, falloffWidth, interpolation, invert):
        falloffs = []
        for object in objects:
            if object is not None:
                falloffs.append(self.getSphereFalloff(object, offset, falloffWidth))
        if len(falloffs) == 0:
            return ConstantFalloff(0)
        else:
            return self.applyMixInterpolationAndInvert(falloffs, interpolation, invert)

    def execute_Sphere(self, object, offset, falloffWidth, interpolation, invert):
        falloff = self.getSphereFalloff(object, offset, falloffWidth)
        return self.applyInterpolationAndInvert(falloff, interpolation, invert)

    def getSphereFalloff(self, object, offset, falloffWidth):
        if object is None:
            return ConstantFalloff(0)
        
        evaluatedObject = getEvaluatedID(object)
        matrix = evaluatedObject.matrix_world
        center = matrix.to_translation()
        size = abs(matrix.to_scale().x) + offset
        return PointDistanceFalloff(center, size - 1, falloffWidth)

    def execute_Directional_List(self, objects, interpolation, invert):
        falloffs = []
        for object in objects:
            if object is not None:
                falloffs.append(self.getDirectionalFalloff(object))
        if len(falloffs) == 0:
            return ConstantFalloff(0)
        else:
            return self.applyMixInterpolationAndInvert(falloffs, interpolation, invert)

    def execute_Directional(self, object, interpolation, invert):
        falloff = self.getDirectionalFalloff(object)
        return self.applyInterpolationAndInvert(falloff, interpolation, invert)

    def getDirectionalFalloff(self, object):
        if object is None:
            return ConstantFalloff(0)

        evaluatedObject = getEvaluatedID(object)
        matrix = evaluatedObject.matrix_world
        location = matrix.to_translation()
        size = max(matrix.to_scale().x, 0.0001)
        direction = eulerToDirection(matrix.to_euler(), self.axisDirection)

        return UniDirectionalFalloff(location, direction, size)

    def execute_Radial_List(self, objects, phase, interpolation, invert):
        falloffs = []
        for object in objects:
            if object is not None:
                falloffs.append(self.getRadialFalloff(object, phase))
        if len(falloffs) == 0:
            return ConstantFalloff(0)
        else:
            return self.applyMixInterpolationAndInvert(falloffs, interpolation, invert)

    def execute_Radial(self, object, phase, interpolation, invert):
        falloff = self.getRadialFalloff(object, phase)
        return self.applyInterpolationAndInvert(falloff, interpolation, invert)

    def getRadialFalloff(self, object, phase):
        if object is None:
            return ConstantFalloff(0)
        
        evaluatedObject = getEvaluatedID(object)
        matrix = evaluatedObject.matrix_world
        origin = matrix.to_translation()
        normal = eulerToDirection(matrix.to_euler(), self.axisDirection)
        return RadialFalloff(origin, normal, phase)

    def applyMixInterpolationAndInvert(self, falloffs, interpolation, invert):
        if self.mixListType == "MAX":
            falloff = MixFalloffs(falloffs, "MAX")
            return self.applyInterpolationAndInvert(falloff, interpolation, invert)
        elif self.mixListType == "ADD":
            falloffs = [InterpolateFalloff(falloff, interpolation) for falloff in falloffs]
            falloff = MixFalloffs(falloffs, "ADD")
            if invert: falloff = InvertFalloff(falloff)
            return falloff

    def applyInterpolationAndInvert(self, falloff, interpolation, invert):
        falloff = InterpolateFalloff(falloff, interpolation)
        if invert: falloff = InvertFalloff(falloff)
        return falloff

    def createAutoExecutionTrigger(self):
        if self.useObjectList or self.inputs["Object"].object is None:
            return

        customTriggers = self.nodeTree.autoExecution.customTriggers

        attrs = []
        if self.falloffType in ("DIRECTIONAL", "SPHERE"): attrs.append("scale")
        if self.falloffType in ("DIRECTIONAL", "RADIAL"): attrs.append("rotation_euler")
        attrs.append("location")
        
        if attrs:
            item = self.nodeTree.autoExecution.customTriggers.new("MONITOR_PROPERTY")
            item.idType = "OBJECT"
            item.dataPaths = ",".join(attrs)
            item.object = self.inputs["Object"].object
