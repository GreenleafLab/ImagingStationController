%#########################################################################
% SubCallCommand
% Command for calling a subroutine
% Written by Curtis Layton 10/2012
%#########################################################################

classdef SubCallCommand < ControlCommand
    
    properties % PROPERTIES
        mySubroutine; %a reference to the subroutine this call calls
        variableList; %associative array of variables for this call
        scriptDepth; %gets assigned on execute to be the depth of this loop
    end % END PROPERTIES
    
    methods (Access = private) % PRIVATE METHODS
        function transferVariableValues(command)
            keySet = keys(command.mySubroutine.variableList);
            for i = 1:length(keySet)
                currKey = keySet(i);
                currKey = currKey{1};
                if(isKey(command.variableList,currKey))
                    localVariableList = command.variableList(currKey);
                    subVariableList = command.mySubroutine.variableList(currKey);
                    subVariableList.valueArray = localVariableList.valueArray;
                    command.mySubroutine.variableList(currKey) = subVariableList;
                else
                    error('SubCallCommand:transferVariableValues:incompleteArgumentList', 'all variables in subroutine "%s" could not be assigned in this subroutine call', command.mySubroutine.getName());
                end
            end    
        end
    end % END PRIVATE METHODS
    
    methods % PUBLIC METHODS
        
        function command = SubCallCommand(hardware, mySubroutine) %constructor
            CheckParam.isClassType(mySubroutine, 'SubCommand', 'SubCallCommand:SubCallCommand:badInputs');
            command = command@ControlCommand(hardware, 'sub call', 'subroutine call'); %call parent constructor
            
            command.mySubroutine = mySubroutine;
            command.scriptDepth = -1; %initialize.  gets set at run time on execute()
            command.updateVariableList(); %transfers the variableList (deep copy) from mySubroutine so all the local variables can be assigned
        end
        
        function updateVariableList(command)
            if(isempty(command.variableList))
                command.variableList = containers.Map();
            end
            
            %add new variables
            keySet = keys(command.mySubroutine.variableList);
            for i = 1:length(keySet)
                currKey = keySet(i);
                currKey = currKey{1};
                if(~isKey(command.variableList,currKey))
                    currVariable = command.mySubroutine.variableList(currKey);
                    newScriptVariable = ScriptVariable(currVariable.name, currVariable.dataType);
                    newScriptVariable.setParent(command);
                    newScriptVariable.valueArray = currVariable.valueArray;
                    command.variableList(currKey) = newScriptVariable;
                end
            end
            
            %remove variables that have been removed from the subroutine
            keySet = keys(command.variableList);
            for i = 1:length(keySet)
                currKey = keySet(i);
                currKey = currKey{1};
                if(~isKey(command.mySubroutine.variableList,currKey))
                    remove(command.variableList,currKey);
                end
            end
        end
        
        function TF = isVariable(command, variableName)
            CheckParam.isString(variableName, 'SubCallCommand:isVariable:badInputs');
            if(isKey(command.variableList, variableName))
                TF = true;
            else
                TF = false;
            end
        end
        
        function variable = getVariable(command, variableName)
            CheckParam.isString(variableName, 'SubCallCommand:getVariable:badInputs');
            variable = command.variableList(variableName);
        end
                
        function assignVariableValues(command, variableName, cellArrayOfValues)
            CheckParam.isString(variableName, 'SubCallCommand:assignVariableValues:badInputs');
            if(CheckParam.isCellArray(cellArrayOfValues, 'SubCallCommand:assignVariableValues:badInputs'))
                inputArrayLength = length(cellArrayOfValues);
                currScriptVariable = command.variableList(variableName);
                internalArrayLength = length(currScriptVariable.valueArray);
                if(inputArrayLength ~= internalArrayLength)
                    error('SubCallCommand:assignVariableValues:badInputs','variable "%s" of length %d cannot be assigned with a cell array of length %d.  Array lengths must match.', variableName, internalArrayLength, inputArrayLength);
                end
            end
            currVariable = command.variableList(variableName);
            currVariable.valueArray = cellArrayOfValues;
            command.variableList(variableName) = currVariable;
        end
        
        function depth = getScriptDepth(command)
            depth = command.scriptDepth;
        end

        function execute(command, scriptDepth, depthIndex)
            if(~exist('scriptDepth','var'))
                scriptDepth = 1;
            else
                scriptDepth = scriptDepth + 1;
            end
            if(~exist('depthIndex','var'))
                depthIndex = [];
            end
            
            command.updateVariableList();
            
            %assign variables
            command.transferVariableValues();

            %check if any of the variables have not been assigned
             if(~command.mySubroutine.allVariablesAreFullyAssigned())
                 error('SubCallCommand:execute:unassignedVariables','All variables must be fully assigned before the subroutine is executed');
             end
            
            %now that the variables are assigned, execute the subroutine
            depthIndex(scriptDepth) = 1;
            command.mySubroutine.scriptDepth = scriptDepth;          
            command.mySubroutine.commandList.execute(scriptDepth, depthIndex);
        end

        function script = getScript(command, scriptDepth)
            if(~exist('scriptDepth','var'))
                scriptDepth = 0;
            end
            
            script = ''; %initialize
            text = sprintf('%s<subcall name="%s">\n', StringFun.getIndent(scriptDepth), command.mySubroutine.getName());
            script = [script text]; %concatenate

            keySet = keys(command.variableList);
            for i = 1:length(keySet)
                currKey = keySet(i);
                currKey = currKey{1};
                currScriptVariable = command.variableList(currKey);
                currValueArray = currScriptVariable.valueArray;
                text = sprintf('%s<var name="%s" dataType="%s" value="%s"></var>\n', StringFun.getIndent(scriptDepth+1), currKey, currScriptVariable.dataType, StringFun.all2str(currValueArray));
                script = [script text];
            end

            text = sprintf('%s</subcall>\n', StringFun.getIndent(scriptDepth));
            script = [script text]; %concatenate
        end
        
    end % END PUBLIC METHODS
    
end