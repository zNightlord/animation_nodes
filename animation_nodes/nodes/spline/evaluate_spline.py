import bpy
from bpy.props import *
from mathutils import Vector
from ... events import executionCodeChanged
from . spline_evaluation_base import SplineEvaluationBase
from ... base_types import AnimationNode, VectorizedSocket

evaluationTypeItems = [
    ("PARAMETER", "Parameter", "", "NONE", 0),
    ("RANGE_COUNT", "Range Count", "", "NONE", 1),
    ("RANGE_STEP", "Range Step", "", "NONE", 2),
]

class EvaluateSplineNode(AnimationNode, bpy.types.Node, SplineEvaluationBase):
    bl_idname = "an_EvaluateSplineNode"
    bl_label = "Evaluate Spline"

    evaluationType: EnumProperty(name = "Evaluation Type", default = "PARAMETER",
        items = evaluationTypeItems, description = "Type of evaluation",
        update = AnimationNode.refresh)

    wrapParameters: BoolProperty(name = "Wrap Parameters", default = False,
        description = ("Wrap the input parameters such that a parameter larger than 1"
                       " wraps to the start of the spline and vice versa"),
        update = AnimationNode.refresh)

    useParameterList: VectorizedSocket.newProperty()

    def create(self):
        self.newInput("Spline", "Spline", "spline", defaultDrawType = "PROPERTY_ONLY")
        if self.evaluationType in ("RANGE_COUNT", "RANGE_STEP"):
            if self.evaluationType == "RANGE_COUNT":
                self.newInput("Integer", "Amount", "amount", value = 50)
            else:
                self.newInput("Float", "Step", "step", value = 0.1)
            self.newInput("Float", "Start", "start", value = 0.0).setRange(0.0, 1.0)
            self.newInput("Float", "End", "end", value = 1.0).setRange(0.0, 1.0)
            self.newOutput("Vector List", "Locations", "locations")
            self.newOutput("Vector List", "Tangents", "tangents")
            self.newOutput("Vector List", "Normals", "normals")
            self.newOutput("Float List", "Radii", "radii")
            self.newOutput("Float List", "Tilts", "tilts", hide = True)
            self.newOutput("Float List", "Curvatures", "curvatures", hide = True)
            self.newOutput("Matrix List", "Matrices", "matrices")
        else:
            parameterInputSettings = dict()
            if not self.wrapParameters:
                parameterInputSettings = dict(minValue = 0, maxValue = 1)
            self.newInput(VectorizedSocket("Float", "useParameterList",
                ("Parameter", "parameter", parameterInputSettings),
                ("Parameters", "parameters")))

            self.newOutput(VectorizedSocket("Vector", "useParameterList",
                ("Location", "location"),
                ("Locations", "locations")))
            self.newOutput(VectorizedSocket("Vector", "useParameterList",
                ("Tangent", "tangent"),
                ("Tangents", "tangents")))
            self.newOutput(VectorizedSocket("Vector", "useParameterList",
                ("Normal", "normal"),
                ("Normals", "normals")))
            self.newOutput(VectorizedSocket("Float", "useParameterList",
                ("Radius", "radius"),
                ("Radii", "radii")))
            self.newOutput(VectorizedSocket("Float", "useParameterList",
                ("Tilt", "tilt", dict(hide = True)),
                ("Tilts", "tilts", dict(hide = True))))
            self.newOutput(VectorizedSocket("Float", "useParameterList",
                ("Curvature", "curvature", dict(hide = True)),
                ("Curvatures", "curvatures", dict(hide = True))))
            self.newOutput(VectorizedSocket("Matrix", "useParameterList",
                ("Matrix", "matrix"),
                ("Matrices", "matrices")))

    def draw(self, layout):
        layout.prop(self, "evaluationType", text = "")
        if self.evaluationType != "RANGE_STEP":
            layout.prop(self, "parameterType", text = "")

    def drawAdvanced(self, layout):
        col = layout.column()
        col.active = self.parameterType == "UNIFORM"
        col.prop(self, "resolution")

        col = layout.column()
        col.active = self.evaluationType == "PARAMETER"
        col.prop(self, "wrapParameters")

    def getExecutionCode(self, required):
        yield "if spline.isEvaluable():"
        if self.parameterType == "UNIFORM" or self.evaluationType == "RANGE_STEP":
            yield "    spline.ensureUniformConverter(self.resolution)"
        if any(output in required for output in ("normal", "normals", "matrix", "matrices")):
            yield "    spline.ensureNormals()"

        if self.evaluationType in ("RANGE_COUNT", "RANGE_STEP"):
            yield from ("    " + c for c in self.getExecutionCode_Range(required))
        else:
            yield from ("    " + c for c in self.getExecutionCode_Parameters(required))

        yield "else:"
        for s in self.outputs:
            yield "    {} = self.outputs['{}'].getDefaultValue()".format(s.identifier, s.name)

    def getExecutionCode_Range(self, required):
        yield "_start = min(max(start, 0), 1)"
        yield "_end = min(max(end, 0), 1)"

        if self.evaluationType == "RANGE_STEP":
            yield "uniformStart = spline.toUniformParameter(_start)"
            yield "uniformEnd = spline.toUniformParameter(_end)"
            yield "length = spline.getPartialLength(uniformStart, uniformEnd, self.resolution)"
            yield "_amount = int(length / step) if step > 0 else 0"
            yield "parameterType = 'UNIFORM'"
        else:
            yield "_amount = max(amount, 0)"
            yield "parameterType = self.parameterType"

        if "locations" in required:
            yield "locations = spline.getDistributedPoints(_amount, _start, _end, parameterType)"
        if "tangents" in required:
            yield "tangents = spline.getDistributedTangents(_amount, _start, _end, parameterType)"
        if "normals" in required:
            yield "normals = spline.getDistributedNormals(_amount, _start, _end, parameterType)"
        if "radii" in required:
            yield "_radii = spline.getDistributedRadii(_amount, _start, _end, parameterType)"
            yield "radii = DoubleList.fromValues(_radii)"
        if "tilts" in required:
            yield "_tilts = spline.getDistributedTilts(_amount, _start, _end, parameterType)"
            yield "tilts = DoubleList.fromValues(_tilts)"
        if "curvatures" in required:
            yield "_curvatures = spline.getDistributedCurvatures(_amount, _start, _end, parameterType)"
            yield "curvatures = DoubleList.fromValues(_curvatures)"
        if "matrices" in required:
            yield "matrices = spline.getDistributedMatrices(_amount, _start, _end, parameterType)"

    def getExecutionCode_Parameters(self, required):
        if self.useParameterList:
            yield from self.getExecutionCode_Parameters_List(required)
        else:
            yield from self.getExecutionCode_Parameters_Single(required)

    def getExecutionCode_Parameters_List(self, required):
        yield "_parameters = FloatList.fromValues(parameters)"
        if self.wrapParameters:
            yield "_parameters = AN.nodes.spline.c_utils.wrapSplineParameters(_parameters)"
        else:
            yield "_parameters.clamp(0, 1)"

        if self.parameterType == "UNIFORM":
            yield "_parameters = spline.toUniformParameters(_parameters)"

        if "locations" in required:
            yield "locations = spline.samplePoints(_parameters, False, 'RESOLUTION')"
        if "tangents" in required:
            yield "tangents = spline.sampleTangents(_parameters, False, 'RESOLUTION')"
        if "normals" in required:
            yield "normals = spline.sampleNormals(_parameters, False, 'RESOLUTION')"
        if "radii" in required:
            yield "_radii = spline.sampleRadii(_parameters, False, 'RESOLUTION')"
            yield "radii = DoubleList.fromValues(_radii)"
        if "tilts" in required:
            yield "_tilts = spline.sampleTilts(_parameters, False, 'RESOLUTION')"
            yield "tilts = DoubleList.fromValues(_tilts)"
        if "curvatures" in required:
            yield "_curvatures = spline.sampleCurvatures(_parameters, False, 'RESOLUTION')"
            yield "curvatures = DoubleList.fromValues(_curvatures)"
        if "matrices" in required:
            yield "matrices = spline.sampleMatrices(_parameters, False, 'RESOLUTION')"

    def getExecutionCode_Parameters_Single(self, required):
        if self.wrapParameters:
            yield "_parameter = 1 if parameter != 0 and parameter % 1 == 0 else parameter % 1"
        else:
            yield "_parameter = min(max(parameter, 0), 1)"

        if self.parameterType == "UNIFORM":
            yield "_parameter = spline.toUniformParameter(_parameter)"

        if "location" in required:
            yield "location = spline.evaluatePoint(_parameter)"
        if "tangent" in required:
            yield "tangent = spline.evaluateTangent(_parameter)"
        if "normal" in required:
            yield "normal = spline.evaluateNormal(_parameter)"
        if "radius" in required:
            yield "radius = spline.evaluateRadius(_parameter)"
        if "tilt" in required:
            yield "tilt = spline.evaluateTilt(_parameter)"
        if "curvature" in required:
            yield "curvature = spline.evaluateCurvature(_parameter)"
        if "matrix" in required:
            yield "matrix = spline.evaluateMatrix(_parameter)"
