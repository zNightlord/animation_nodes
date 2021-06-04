import bpy
import numpy as np
from bpy.props import *
from ... base_types import AnimationNode
from .. rotation.c_utils import eulerListToFlatDoubleList

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

class ToNumpyNode(bpy.types.Node, AnimationNode):
    bl_idname = "an_ToNumpyNode"
    bl_label = "To Numpy"

    dataType: EnumProperty(name = "Data Types", default = "INTEGER",
        items = dataTypes, update = AnimationNode.refresh)

    def create(self):
        if self.dataType == "INTEGER":
            self.newInput("Integer List", "Integer List", "data")
        elif self.dataType == "FLOAT":
            self.newInput("Float List", "Float List", "data")
        elif self.dataType == "VECTOR2D":
            self.newInput("Vector 2D List", "Vector 2D List", "data")
        elif self.dataType == "VECTOR":
            self.newInput("Vector List", "Vector List", "data")
        elif self.dataType == "EULER":
            self.newInput("Euler List", "Euler List", "data")
        elif self.dataType == "QUATERNION":
            self.newInput("Quaternion List", "Quaternion List", "data")
        elif self.dataType == "MATRIX":
            self.newInput("Matrix List", "Matrix List", "data")
        elif self.dataType == "BOOLEAN":
            self.newInput("Boolean List", "Boolean List", "data")
        elif self.dataType == "TEXT":
            self.newInput("Text List", "Text List", "data")
        elif self.dataType == "GENERIC":
            self.newInput("Generic", "Generic", "data")

        self.newOutput("Numpy Array", "Numpy Array", "numpyArray")

    def draw(self, layout):
        layout.prop(self, "dataType", text = "")

    def execute(self, data):
        if self.dataType == "INTEGER":
            return data.asNumpyArray().astype("i")
        elif self.dataType == "FLOAT":
            return data.asNumpyArray().astype("f")
        elif self.dataType == "VECTOR2D":
            return data.asNumpyArray().astype("f").reshape(len(data), 2)
        elif self.dataType == "VECTOR":
            return data.asNumpyArray().astype("f").reshape(len(data), 3)
        elif self.dataType == "EULER":
            vs = eulerListToFlatDoubleList(data)
            return vs.asNumpyArray().astype("f").reshape(len(data), 3)
        elif self.dataType == "QUATERNION":
            return data.asNumpyArray().astype("f").reshape(len(data), 4)
        elif self.dataType == "MATRIX":
            return data.asNumpyArray().astype("f").reshape(len(data), 4, 4)
        elif self.dataType in ["BOOLEAN", "TEXT", "GENERIC"]:
            return np.array(data)
