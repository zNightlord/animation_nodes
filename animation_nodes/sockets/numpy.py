import bpy
import numpy as np
from .. base_types import AnimationNodeSocket, PythonListSocket

class NumpyArraySocket(bpy.types.NodeSocket, AnimationNodeSocket):
    bl_idname = "an_NumpyArraySocket"
    bl_label = "Numpy Array Socket"
    dataType = "Numpy Array"
    drawColor = (1.0, 0.05, 1.0, 1.0)
    storable = True
    comparable = True

    @classmethod
    def getDefaultValue(cls):
        return np.array([])

    @classmethod
    def getCopyExpression(cls):
        return "value.copy()"

    @classmethod
    def correctValue(cls, value):
        if isinstance(value, np.ndarray):
            return value, 0
        return cls.getDefaultValue(), 2


class NumpyArrayListSocket(bpy.types.NodeSocket, PythonListSocket):
    bl_idname = "an_NumpyArrayListSocket"
    bl_label = "Numpy Array List Socket"
    dataType = "Numpy Array List"
    baseType = NumpyArraySocket
    drawColor = (1.0, 0.05, 1.0, 0.5)
    storable = True
    comparable = False

    @classmethod
    def getCopyExpression(cls):
        return "[element.copy() for element in value]"

    @classmethod
    def correctValue(cls, value):
        if isinstance(value, list):
            if all(isinstance(element, np.ndarray) for element in value):
                return value, 0
        return cls.getDefaultValue(), 2
