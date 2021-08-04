import bpy
from ... base_types import AnimationNode, VectorizedSocket

class ShadeObjectSmooth(bpy.types.Node, AnimationNode):
    bl_idname = "an_ShadeObjectSmoothNode"
    bl_label = "Shade Object Smooth"
    codeEffects = [VectorizedSocket.CodeEffect]

    useObjectList: VectorizedSocket.newProperty()
    useSmoothList: VectorizedSocket.newProperty()

    def create(self):
        self.newInput(VectorizedSocket("Object", "useObjectList",
            ("Object", "object", dict(defaultDrawType = "PROPERTY_ONLY")),
            ("Objects", "objects"),
            codeProperties = dict(allowListExtension = False)))

        self.newInput(VectorizedSocket("Boolean", "useSmoothList",
            ("Smooth", "smooth"), ("Smooth", "smooth")))
        socket = self.inputs[1]
        socket.useIsUsedProperty = True
        socket.isUsed = True

        self.newOutput(VectorizedSocket("Object", "useObjectList",
            ("Object", "object"), ("Objects", "objects")))

    def getExecutionCode(self, required):
        if self.inputs[1].isUsed:
            return "object = self.execute_Single(object, smooth)"

    def execute_Single(self, object, smooth):
        if getattr(object, "type", "") == "MESH":
            mesh = object.data
            if len(mesh.polygons) > 0:
                smoothList = [smooth] * len(mesh.polygons)
                mesh.polygons.foreach_set("use_smooth", smoothList)

                # trigger update
                mesh.polygons[0].use_smooth = smooth
        elif getattr(object, "type", "") == "CURVE":
            for spline in object.data.splines:
                spline.use_smooth = smooth
        return object
