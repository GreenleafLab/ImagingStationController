%#########################################################################
% SubCommand
% Command for defining subroutines
% Written by Curtis Layton 10/2012
%#########################################################################

classdef SubCommand < ControlCommand
    
    properties % PROPERTIES
        name; %subroutine name
        commandList; % list of ControlCommands
        variableList; %associative array of variables
        scriptDepth; %gets assigned on execute to be the depth of this loop
    end % END PROPERTIES
    
    methods (Access = private) % PRIVATE METHODS
        
    end % END PRIVATE METHODS
    
    methods % PUBLIC METHODS
        
        function command = SubCommand(hardware, name) %constructor
            CheckParam.isString(name, 'SubCommand:SubCommand:badInputs');
            command = command@ControlCommand(hardware, 'sub', 'subroutine'); %call parent constructor
            
            command.name = name;
            command.commandList = CommandList();
            command.commandList.setParent(command);
            command.variableList = containers.Map();
            command.scriptDepth = -1; %initialize.  gets set at run time on execute()
        end

        function addVariable(command, variableName, dataType)
            CheckParam.isString(variableName, 'SubCommand:addVariable:badInputs');
            newScriptVariable = ScriptVariable(variableName, dataType);
            newScriptVariable.setParent(command);
            command.variableList(variableName) = newScriptVariable; %preallocate an empty ScriptVariable object to hold variable values
        end
        
        function variable = getVariable(command, variableName)
            CheckParam.isString(variableName, 'SubCommand:getVariable:badInputs');
            variable = command.variableList(variableName);
        end
        
        function deleteVariable(command, variableName)
            CheckParam.isString(fromPosition, 'SubCommand:addVariable:badInputs');
            remove(command.variableList, variableName);
        end
        
        function assignVariableValues(command, variableName, cellArrayOfValues)
            CheckParam.isString(variableName, 'SubCommand:assignVariableValues:badInputs');
            if(CheckParam.isCellArray(cellArrayOfValues, 'SubCommand:assignVariableValues:badInputs'))
                inputArrayLength = length(cellArrayOfValues);
                currScriptVariable = command.variableList(variableName);
                internalArrayLength = length(currScriptVariable.valueArray);
                if(inputArrayLength ~= internalArrayLength)
                    error('SubCommand:assignVariableValues:badInputs','variable "%s" of length %d cannot be assigned with a cell array of length %d.  Array lengths must match.', variableName, internalArrayLength, inputArrayLength);
                end
            end
            currVariable = command.variableList(variableName);
            currVariable.valueArray = cellArrayOfValues;
            command.variableList(variableName) = currVariable;
        end
        
        function confirm = allVariablesAreFullyAssigned(command)
            confirm = true;
            keySet = keys(command.variableList);
            for i = 1:length(keySet) %iterate through variable arrays one by one
                currKey = keySet(i);
                currKey = currKey{1};
                currScriptVariable = command.variableList(currKey);
                currValueArray = currScriptVariable.valueArray;
                if(~isempty(find(cellfun('isempty', currValueArray), 1))) %if any value is unassigned
                    confirm = false;
                    break;
                end
            end
        end
        
        function depth = getScriptDepth(command)
            depth = command.scriptDepth;
        end
        
        function name = getName(command)
            name = command.name;
        end
                     
        function script = getScript(command, scriptDepth)
            if(~exist('scriptDepth','var'))
                scriptDepth = 0;
            end
            
            script = ''; %initialize
            text = sprintf('%s<sub name="%s">\n', StringFun.getIndent(scriptDepth), command.getName());
            script = [script text]; %concatenate

            keySet = keys(command.variableList);
            for i = 1:length(keySet)
                currKey = keySet(i);
                currKey = currKey{1};
                currScriptVariable = command.variableList(currKey);
                currValueArray = currScriptVariable.valueArray;
                text = sprintf('%s<var name="%s" dataType="%s"></var>\n', StringFun.getIndent(scriptDepth+1), currKey, currScriptVariable.dataType);
                script = [script text];
            end

            script = [script command.commandList.getScript(scriptDepth+1)]; %concatenate

            text = sprintf('%s</sub>\n', StringFun.getIndent(scriptDepth));
            script = [script text]; %concatenate
        end
    end % END PUBLIC METHODS
    
end