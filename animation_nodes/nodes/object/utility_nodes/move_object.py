import bpy
from .... base_types import AnimationNode
from .... utils.depsgraph import getEvaluatedID

class MoveObjectNode(AnimationNode, bpy.types.Node):
    bl_idname = "an_MoveObjectNode"
    bl_label = "Move Object"

    def create(self):
        self.newInput("Object", "Object", "object").defaultDrawType = "PROPERTY_ONLY"
        self.newInput("Vector", "Translation", "translation").defaultDrawType = "PROPERTY_ONLY"
        self.newOutput("Object", "Object", "object")

    def getExecutionCode(self, required):
        return "if object: object.location = AN.utils.depsgraph.getEvaluatedID(object).location + translation"
