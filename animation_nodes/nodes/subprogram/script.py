import bpy
from bpy.props import *
from ... sockets.info import toIdName
from ... tree_info import getNodesByType
from ... utils.handlers import eventHandler
from ... utils.names import toInterfaceName
from ... events import executionCodeChanged
from ... base_types import AnimationNode
from . subprogram_base import SubprogramBaseNode
from ... execution.units import getSubprogramUnitByIdentifier
from . subprogram_sockets import SubprogramData, subprogramInterfaceChanged

class ScriptNode(AnimationNode, bpy.types.Node, SubprogramBaseNode):
    bl_idname = "an_ScriptNode"
    bl_label = "Script"
    bl_width_default = 200

    def scriptExecutionCodeChanged(self, context):
        self.errorMessage = ""
        executionCodeChanged()

    executionCode: StringProperty(default = "")
    textBlock: PointerProperty(type = bpy.types.Text)

    debugMode: BoolProperty(name = "Debug Mode", default = True,
        description = "Give error message inside the node", update = scriptExecutionCodeChanged)
    errorMessage: StringProperty()

    interactiveMode: BoolProperty(name = "Interactive Mode", default = True,
        description = "Recompile the script on each change in the text block")

    initializeMissingOutputs: BoolProperty(name = "Initialize Missing Outputs",
        default = True, description = "Use default values for uninitialized outputs",
        update = scriptExecutionCodeChanged)

    correctOutputTypes: BoolProperty(name = "Correct Output Types", default = True,
        description = "Try to correct the type of variables, return default otherwise",
        update = scriptExecutionCodeChanged)

    def setup(self):
        self.randomizeNetworkColor()
        self.subprogramName = "My Script"
        self.newInput("an_NodeControlSocket", "New Input", "newInput")
        self.newOutput("an_NodeControlSocket", "New Output", "newOutput")

    def draw(self, layout):
        layout.separator()

        col = layout.column(align = True)
        row = col.row(align = True)
        if self.textBlock is None:
            self.invokeFunction(row, "createNewTextBlock", icon = "ADD")
        else:
            self.invokeSelector(row, "AREA", "viewTextBlockInArea",
                icon = "ZOOM_SELECTED")
        row.prop(self, "textBlock", text = "")
        subrow = row.row(align = True)
        subrow.active = self.textBlock is not None
        self.invokeFunction(subrow, "writeToTextBlock", icon = "COPYDOWN",
            description = "Write script code into the selected text block")

        subcol = col.column(align = True)
        subcol.scale_y = 1.4
        subcol.active = self.textBlock is not None

        icon = "NONE"
        text = self.textInTextBlock
        if text is not None:
            if self.executionCode != text: icon = "ERROR"

        if not self.interactiveMode:
            self.invokeFunction(subcol, "readFromTextBlock", text = "Import Changes", icon = icon,
                description = "Import the changes from the selected text block")

        layout.prop(self, "subprogramName", text = "", icon = "GROUP_VERTEX")

        self.drawErrorMessages(layout, onlyErrors = False)

        layout.separator()

    def drawErrorMessages(self, layout, onlyErrors = False):
        if self.errorMessage != "":
            layout.label(text = self.errorMessage, icon = "ERROR")
            return

        col = layout.column(align = True)
        for socket in self.outputs[:-1]:
            variableName = socket.text
            if self.initializeMissingOutputs:
                if not getattr(socket, '["variableInitialized"]', True):
                    col.label(text = "'{}' - Not Initialized, used default".format(variableName), icon = "ERROR")
            if self.correctOutputTypes:
                correctionType = getattr(socket, '["correctionType"]', 0)
                if correctionType == 1 and not onlyErrors:
                    col.label(text = "'{}' - Type Corrected".format(variableName), icon = "INFO")
                elif correctionType == 2:
                    col.label(text = "'{}' - Wrong Type, expected '{}'".format(variableName, socket.dataType), icon = "ERROR")

    def drawAdvanced(self, layout):
        col = layout.column()
        col.label(text = "Description:")
        col.prop(self, "subprogramDescription", text = "")
        layout.prop(self, "interactiveMode")
        col = layout.column(align = True)
        col.prop(self, "debugMode")
        col.prop(self, "initializeMissingOutputs")
        col.prop(self, "correctOutputTypes")

        col = layout.column()
        col.label(text = "Input Defaults:")
        box = col.box()
        for socket in list(self.inputs)[:-1]:
            subBox = box.box()
            subBox.label(text = repr(socket.text))
            socket.drawSocket(subBox, "Default", node = self, drawType = "PROPERTY_ONLY")
            subBox.prop(socket.subprogram, "hideByDefault", text = "Hide")

        col = layout.column()
        col.label(text = "Output Defaults:")
        box = col.box()
        for socket in list(self.outputs)[:-1]:
            subBox = box.box()
            subBox.label(text = repr(socket.text))
            subBox.prop(socket.subprogram, "hideByDefault", text = "Hide")

    def drawControlSocket(self, layout, socket):
        if socket in list(self.inputs):
            self.invokeSelector(layout, "DATA_TYPE", "newInputSocket",
                text = "New Input", icon = "ADD")
        else:
            self.invokeSelector(layout, "DATA_TYPE", "newOutputSocket",
                text = "New Output", icon = "ADD")

    def edit(self):
        removedLink = self.removeLinks()

    def newInputSocket(self, dataType):
        socket = self.newInput(dataType, dataType)
        self.setupSocket(socket)

    def newOutputSocket(self, dataType):
        socket = self.newOutput(dataType, dataType)
        self.setupSocket(socket)

    def setupSocket(self, socket):
        socket.textProps.editable = True
        socket.textProps.variable = True
        socket.textProps.unique = True
        socket.display.textInput = True
        socket.display.text = True
        socket.display.removeOperator = True
        socket.moveable = True
        socket.removeable = True
        socket.moveUp()
        socket.text = socket.dataType

    def socketChanged(self):
        subprogramInterfaceChanged()

    def delete(self):
        self.clearSockets()
        subprogramInterfaceChanged()

    def duplicate(self, sourceNode):
        self.randomizeNetworkColor()
        self.textBlock = None

    def getSocketData(self):
        data = SubprogramData()
        for socket in self.inputs[:-1]:
            socketData = data.newInputFromSocket(socket)
            socketData.text = toInterfaceName(socket.text)
        for socket in self.outputs[:-1]:
            socketData = data.newOutputFromSocket(socket)
            socketData.text = toInterfaceName(socket.text)
        return data

    def createNewTextBlock(self):
        textBlock = bpy.data.texts.new(name = self.subprogramName)
        self.textBlock = textBlock
        self.writeToTextBlock()

    def viewTextBlockInArea(self, area):
        area.type = "TEXT_EDITOR"
        space = area.spaces.active
        space.text = self.textBlock
        space.show_line_numbers = True
        space.show_syntax_highlight = True

    def writeToTextBlock(self):
        if not self.textBlock: return
        self.textBlock.from_string(self.executionCode)

    def readFromTextBlock(self):
        if not self.textBlock: return
        self.executionCode = self.textInTextBlock
        self.errorMessage = ""
        executionCodeChanged()

    def interactiveUpdate(self):
        if not self.textBlock: return
        text = self.textInTextBlock
        if self.executionCode == text: return
        executionUnit = self.executionUnit
        if executionUnit is None: return
        self.executionCode = text
        executionUnit.scriptUpdated()

    @property
    def textInTextBlock(self):
        if self.textBlock:
            return self.textBlock.as_string()
        return None

    @property
    def textBlock(self):
        return self.textBlock

    @property
    def executionUnit(self):
        return getSubprogramUnitByIdentifier(self.identifier)


@eventHandler("ALWAYS")
def sceneUpdate():
    for node in getNodesByType("an_ScriptNode"):
        if node.interactiveMode:
            node.interactiveUpdate()
