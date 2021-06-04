import bpy
from bpy.props import *
from ... base_types import AnimationNode
from .. rotation.c_utils import flatDoubleListToEulerList
from ... data_structures import (
    DoubleList,
    EulerList,
    IntegerList,
    BooleanList,
    Vector2DList,
    Vector3DList,
    Matrix4x4List,
    QuaternionList,
)

dataTypes = [
    ("INTEGER", "Integer List", "", "NONE", 0),
    ("FLOAT", "Float List", "", "NONE", 1),
    ("VECTOR2D", "Vector 2D List", "", "NONE", 2),
    ("VECTOR", "Vector List", "", "NONE", 3),
    ("EULER", "Euler List", "", "NONE", 4),
    ("QUATERNION", "Quaternion List", "", "NONE", 5),
    ("MATRIX", "Matrix List", "", "NONE", 6),
    ("BOOLEAN", "Boolean List", "", "NONE", 7),
    ("TEXT", "Text List", "", "NONE", 8),
    ("GENERIC", "Generic", "", "NONE", 9),
]

class FromNumpyNode(bpy.types.Node, AnimationNode):
    bl_idname = "an_FromNumpyNode"
    bl_label = "From Numpy"

    dataType: EnumProperty(name = "Data Types", default = "INTEGER",
        items = dataTypes, update = AnimationNode.refresh)

    def create(self):
        self.newInput("Numpy Array", "Numpy Array", "numpyArray")

        if self.dataType == "INTEGER":
            self.newOutput("Integer List", "Integer List", "integerList")
        elif self.dataType == "FLOAT":
            self.newOutput("Float List", "Float List", "floatList")
        elif self.dataType == "VECTOR2D":
            self.newOutput("Vector 2D List", "Vector 2D List", "vector2DList")
        elif self.dataType == "VECTOR":
            self.newOutput("Vector List", "Vector List", "vectorList")
        elif self.dataType == "EULER":
            self.newOutput("Euler List", "Euler List", "eulerList")
        elif self.dataType == "QUATERNION":
            self.newOutput("Quaternion List", "Quaternion List", "quaternionList")
        elif self.dataType == "MATRIX":
            self.newOutput("Matrix List", "Matrix List", "matrixList")
        elif self.dataType == "BOOLEAN":
            self.newOutput("Boolean List", "Boolean List", "booleanList")
        elif self.dataType == "TEXT":
            self.newOutput("Text List", "Text List", "textList")
        elif self.dataType == "GENERIC":
            self.newOutput("Generic", "Generic", "generic")

    def draw(self, layout):
        layout.prop(self, "dataType", text = "")

    def execute(self, numpyArray):
        if self.dataType == "INTEGER":
            if numpyArray.size == 0: return IntegerList()
            return IntegerList.fromNumpyArray(numpyArray.astype('i'))
        elif self.dataType == "FLOAT":
            if numpyArray.size == 0: return DoubleList()
            return DoubleList.fromNumpyArray(numpyArray.astype('d'))
        elif self.dataType == "VECTOR2D":
            if numpyArray.size == 0: return Vector2DList()
            return Vector2DList.fromNumpyArray(numpyArray.ravel().astype('f'))
        elif self.dataType == "VECTOR":
            if numpyArray.size == 0: return Vector3DList()
            return Vector3DList.fromNumpyArray(numpyArray.ravel().astype('f'))
        elif self.dataType == "EULER":
            if numpyArray.size == 0: return EulerList()
            return flatDoubleListToEulerList(DoubleList.fromNumpyArray(numpyArray.ravel().astype('d')))
        elif self.dataType == "QUATERNION":
            if numpyArray.size == 0: return QuaternionList()
            return QuaternionList.fromNumpyArray(numpyArray.ravel().astype('f'))
        elif self.dataType == "MATRIX":
            if numpyArray.size == 0: return Matrix4x4List()
            return Matrix4x4List.fromNumpyArray(numpyArray.ravel().astype('f'))
        elif self.dataType == "BOOLEAN":
            if numpyArray.size == 0: return BooleanList()
            return BooleanList.fromNumpyArray(numpyArray.astype('b'))
        elif self.dataType in ["TEXT", "GENERIC"]:
            return numpyArray.tolist()
