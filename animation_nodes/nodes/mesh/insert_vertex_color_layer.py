import bpy
from bpy.props import *
from ... events import propertyChanged
from ... base_types import AnimationNode, VectorizedSocket
from .. color.c_utils import getLoopColorsFromVertexColors, getLoopColorsFromPolygonColors
from ... data_structures import (
    Color,
    ColorList,
    Attribute,
    AttributeType,
    AttributeDomain,
    VirtualColorList,
    AttributeDataType,
)

colorModeItems = [
    ("LOOP", "Loop", "Get color of every loop vertex", "NONE", 0),
    ("VERTEX", "Vertex", "Get color of every vertex", "NONE", 1),
    ("POLYGON", "Polygon", "Get color of every polygon", "NONE", 2)
]

class InsertVertexColorLayerNode(AnimationNode, bpy.types.Node):
    bl_idname = "an_InsertVertexColorLayerNode"
    bl_label = "Insert Vertex Color Layer"
    errorHandlingType = "EXCEPTION"

    colorMode: EnumProperty(name = "Color Mode", default = "LOOP",
        items = colorModeItems, update = propertyChanged)

    useColorList: VectorizedSocket.newProperty()

    def create(self):
        self.newInput("Mesh", "Mesh", "mesh", dataIsModified = True)
        self.newInput("Text", "Name", "colorLayerName", value = "AN-Col")
        self.newInput(VectorizedSocket("Color", "useColorList",
            ("Color", "color"), ("Colors", "colors")))
        self.newOutput("Mesh", "Mesh", "mesh")

    def draw(self, layout):
        if self.useColorList:
            layout.prop(self, "colorMode", text = "")

    def getExecutionFunctionName(self):
        if self.useColorList:
            return "execute_ColorsList"
        else:
            return "execute_SingleColor"

    def execute_SingleColor(self, mesh, colorLayerName, color):
        self.checkAttributeName(mesh, colorLayerName)

        defaultColor = Color((0, 0, 0, 1))
        colorsList = VirtualColorList.create(color, defaultColor).materialize(len(mesh.polygons.indices))

        mesh.insertVertexColorAttribute(Attribute(colorLayerName, AttributeType.VERTEX_COLOR, AttributeDomain.CORNER,
                                                  AttributeDataType.BYTE_COLOR, colorsList))
        return mesh

    def execute_ColorsList(self, mesh, colorLayerName, colors):
        self.checkAttributeName(mesh, colorLayerName)

        defaultColor = Color((0, 0, 0, 1))
        colorsList = VirtualColorList.create(colors, defaultColor)

        if self.colorMode == "LOOP":
            colorsList = colorsList.materialize(len(mesh.polygons.indices))
        elif self.colorMode == "VERTEX":
            polygonIndices = mesh.polygons
            colorsList = getLoopColorsFromVertexColors(polygonIndices, colorsList)
        elif self.colorMode == "POLYGON":
            polygonIndices = mesh.polygons
            colorsList = getLoopColorsFromPolygonColors(polygonIndices, colorsList)

        mesh.insertVertexColorAttribute(Attribute(colorLayerName, AttributeType.VERTEX_COLOR, AttributeDomain.CORNER,
                                                  AttributeDataType.BYTE_COLOR, colorsList))
        return mesh

    def checkAttributeName(self, mesh, attributeName):
        if attributeName == "":
            self.raiseErrorMessage("Vertex color layer name can't be empty.")
        elif attributeName in mesh.getAllVertexColorAttributeNames():
            self.raiseErrorMessage(f"Mesh has already a vertex color layer with the name '{attributeName}'.")
