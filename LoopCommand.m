%#########################################################################
% LoopCommand
% Command for looping through commands
% Written by Curtis Layton 10/2012
%#########################################################################

classdef LoopCommand < ControlCommand
    
    properties % PROPERTIES
        numIterations;
        currentIteration;
        commandList; % list of ControlCommands to be iterated through
        variableList; %associative array of the variables that will be changed as we iterate through the loop
        scriptDepth; %gets assigned on execute to be the depth of this loop
    end % END PROPERTIES
               
    properties (Constant) % CONSTANT PROPERTIES
        maxNumIterations = 1000;
    end % END CONSTANT PROPERTIES
    
    methods (Access = private) % PRIVATE METHODS
        
    end % END PRIVATE METHODS
    
    methods % PUBLIC METHODS
        
        function command = LoopCommand(hardware, numIterations) %constructor

            command = command@ControlCommand(hardware, 'loop', 'loop through a list of commands over multiple iterations'); %call parent constructor
            
            if(CheckParam.isInteger(numIterations, 'LoopCommand:LoopCommand:badInputs'))
                CheckParam.isWithinARange(numIterations,1,command.maxNumIterations,'LoopCommand:LoopCommand:badInputs');
            end
            
            command.numIterations = numIterations; %initialize the number of iterations in the loop
            command.currentIteration = -1; %-1 is a flag that the loop is not currently being executed
            command.commandList = CommandList();
            command.commandList.setParent(command);
            command.variableList = containers.Map();
            command.scriptDepth = -1; %initialize.  gets set at run time on execute()
        end
                
        function setNumIterations(command, numIterations)
            if(CheckParam.isInteger(numIterations, 'LoopCommand:setNumIterations:badInputs'))
                CheckParam.isWithinARange(numIterations,2,command.maxNumIterations,'LoopCommand:setNumIterations:badInputs');
            end
            
            if(numIterations ~= command.numIterations) %nothing needs to be done if numIterations is not actually changing
                %if we are changing the num iterations, we must fix all
                %variables in variableList to contain the corresponding number of elements
                keySet = keys(command.variableList);
                for(i = 1:length(keySet)) %resize variable arrays one by one
                    currKey = keySet(i);
                    currKey = currKey{1};
                    if(numIterations > command.numIterations) %--adding more iterations
                        numAdditionalIterations = numIterations - command.numIterations;
                        newVariable = [command.variableList(currKey) cell(1,numAdditionalIterations)];
                        command.variableList(currKey) = newVariable;
                    else % if numIterations < command.numIterations --deleting iterations
                        currCellArray = command.variableList(currKey);
                        command.variableList(currKey) = currCellArray(1:numIterations);
                    end
                end
                command.numIterations = numIterations; %assign numIterations
            end
        end
        
        function numIterations = getNumIterations(command)
            numIterations = command.numIterations;
        end
        
        function addVariable(command, variableName, dataType)
            CheckParam.isString(variableName, 'LoopCommand:addVariable:badInputs');
            newScriptVariable = ScriptVariable(variableName, dataType, command.numIterations);
            newScriptVariable.setParent(command);
            command.variableList(variableName) = newScriptVariable; %preallocate an empty ScriptVariable object to hold variable values
        end
        
        function variable = getVariable(command, variableName)
            CheckParam.isString(variableName, 'LoopCommand:getVariable:badInputs');
            variable = command.variableList(variableName);
        end
        
        function deleteVariable(command, variableName)
            CheckParam.isString(fromPosition, 'LoopCommand:deleteVariable:badInputs');
            remove(command.variableList, variableName);
        end
        
        function assignVariableValue(command, variableName, index, value)
            CheckParam.isString(variableName, 'LoopCommand:assignVariableValue:badInputs');
            CheckParam.isInteger(index, 'LoopCommand:assignVariableValue:badInputs');
            currVariable = command.variableList(variableName);
            currVariable.valueArray{index} = value;
            command.variableList(variableName) = currVariable;
        end
        
        function assignVariableValues(command, variableName, cellArrayOfValues)
            CheckParam.isString(variableName, 'LoopCommand:assignVariableValues:badInputs');
            if(CheckParam.isCellArray(cellArrayOfValues, 'LoopCommand:assignVariableValues:badInputs'))
                inputArrayLength = length(cellArrayOfValues);
                currScriptVariable = command.variableList(variableName);
                internalArrayLength = length(currScriptVariable.valueArray);
                if(inputArrayLength ~= internalArrayLength)
                    error('LoopCommand:assignVariableValues:badInputs','variable "%s" of length %d cannot be assigned with a cell array of length %d.  Array lengths must match.', variableName, internalArrayLength, inputArrayLength);
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
        
        function currentIteration = getCurrentIteration(command)
            currentIteration = command.currentIteration;
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
            
            %check if any of the loop variables have not been assigned values at any position
            if(~command.allVariablesAreFullyAssigned())
                error('LoopCommand:execute:unassignedVariables','All loop variables must be fully assigned before the loop is executed');
            end
            
            command.scriptDepth = scriptDepth;
            
            for i = 1:command.numIterations %iterate through the loop
                depthIndex(scriptDepth) = i;
                command.currentIteration = i;
                command.commandList.execute(scriptDepth, depthIndex);
            end
            command.currentIteration = -1;
        end
        
        function script = getScript(command, scriptDepth)
            if(~exist('scriptDepth','var'))
                scriptDepth = 0;
            end
            
            script = ''; %initialize
            text = sprintf('%s<loop numIterations="%d">\n', StringFun.getIndent(scriptDepth), command.getNumIterations());
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

            script = [script command.commandList.getScript(scriptDepth+1)]; %concatenate

            text = sprintf('%s</loop>\n', StringFun.getIndent(scriptDepth));
            script = [script text]; %concatenate
        end
    end % END PUBLIC METHODS
    
end