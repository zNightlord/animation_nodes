import bpy
from bpy.props import *
from ... events import propertyChanged
from ... base_types import AnimationNode
from . texture_falloff_utils import calculateTextureFalloff

modeItems = [
    ("INTENSITY", "Intensity", "Falloff as intensity of color", "NONE", 0),
    ("RED", "Red", "Falloff as intensity of red color", "NONE", 1),
    ("GREEN", "Green", "Falloff as intensity of green color", "NONE", 2),
    ("BLUE", "Blue", "Falloff as intensity of blue color", "NONE", 3),
    ("ALPHA", "Alpha", "Falloff as intensity of alpha color", "NONE", 4)
]

class TextureFalloffNode(bpy.types.Node, AnimationNode):
    bl_idname = "an_TextureFalloffNode"
    bl_label = "Texture Falloff"
    errorHandlingType = "EXCEPTION"

    mode: EnumProperty(name = "Mode", default = "INTENSITY",
        items = modeItems, update = AnimationNode.refresh)

    def create(self):
        self.newInput("Texture", "Texture", "texture", defaultDrawType = "PROPERTY_ONLY")
        self.newInput("Matrix", "Transformation", "transformation", hide = True)
        self.newInput("Boolean", "Invert", "invert", value = False)
        self.newInput("Scene", "Scene", "scene", hide = True)

        self.newOutput("Falloff", "Falloff", "falloff")

    def draw(self, layout):
        layout.prop(self, "mode", text = "")

    def drawAdvanced(self, layout):
        box = layout.box()
        col = box.column(align = True)
        col.label(text = "Info", icon = "INFO")
        col.label(text = "For External Texture, Alpha = Alpha")
        col.label(text = "For Internal Texture, Alpha = Intensity")

    def execute(self, texture, transformation, invert, scene):
        if texture is None:
            self.raiseErrorMessage("Texture can't be empty.")

        if texture.type == "IMAGE":
            if texture.image is not None and texture.image.source in ["SEQUENCE", "MOVIE"]:
                texture.image_user.frame_current = scene.frame_current
        return calculateTextureFalloff(texture, self.mode, transformation, invert)
