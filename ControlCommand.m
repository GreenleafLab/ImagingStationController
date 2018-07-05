%#########################################################################
% ControlCommand
% Parent class for all commands in the ImagingStationController
% Written by Curtis Layton 10/2012
%#########################################################################

classdef ControlCommand < handle
    
    properties % PROPERTIES
        hardware; % a reference to the hardware interface
        parent;
        commandName;
        helpDescription;
        parameters; % all the parameters of the command are stored under this data structure. (NB any of these parameters may be assigned to be ScriptVariables)
        currentParameters
    end % END PROPERTIES
    
    methods % PUBLIC METHODS
        function cc = ControlCommand(hardware, commandName, helpDescription)
            CheckParam.isClassType(hardware, 'ImagingStationHardware', 'ControlCommand:ControlCommand:badInputs');
            cc.hardware = hardware;
            cc.commandName = commandName;
            cc.helpDescription = helpDescription;
        end
        
        function setParent(cc, parent)
            cc.parent = parent;
        end
        
        function parent = getParent(cc)
            parent = cc.parent;
        end
        
        function value = getParameter(cc, parameterName, depthIndex)
            if(~exist('depthIndex', 'var'))
                depthIndex = 1;
                insideLoop = false;
            else
                insideLoop = true;
            end

            currParameter = cc.parameters.(parameterName);
            if(insideLoop && (strcmp(class(currParameter),'ScriptVariable')))
                %if this parameter is a loop variable, assign it for the
                %current iteration
                scriptDepth = currParameter.getScriptDepth();
                if(scriptDepth == -1)
                    error('ControlCommand:getParameter:uninitializedVariable','Variable "%s" used outside of its declared structure.', currParameter.name);
                elseif(scriptDepth == 1)
                    %global variable
                    value = currParameter.valueArray{1};
                else
                    %assign sub or loop variable from the appropriate sub call or loop iteration
                    variableIndex = depthIndex(scriptDepth);
                    currValueArray = currParameter.valueArray;
                    value = currValueArray{variableIndex};
                end
                
            else
                %or else just transfer its value to output
                value = currParameter;
            end

            %in strings, substitute variable names (preceded with "VAR_")
            if isa(value, 'char') %if the value is a string
                
                [startIndex, endIndex] = regexp(value, 'VAR_'); %count candidate variable substrings in the string
                numMatches = length(startIndex);
                
                if(numMatches > 0) %if the string has candidate variable substrings in it
                    %substitue reserved word variables
                    value = strrep(value, 'VAR_TIMESTAMP', StringFun.getTimestampString());
                    
                    %substitute variables, working backwards through levels of the scope
                    currNode = cc;                    
                    %while(~isempty(find(strcmp('parent', properties(currNode)), 1)))
                    while(~isempty(currNode))
                        if(~isempty(find(strcmp('variableList', properties(currNode)), 1))) %if the current structure has a variable list
                            if ~isempty(currNode.variableList) %if the variable list is not empty

                                keyList = keys(currNode.variableList);
                                
                                for currKey = keyList
                                    currKey = currKey{1};
                                    currVarName = strcat('VAR_', currKey);                                    
                                    if(~isempty(strfind(value, currVarName))) %if it matches...
                                        %...get the value...
                                        currVariable = currNode.variableList(currKey);
                                        scriptDepth = currVariable.getScriptDepth();
                                        if(scriptDepth == -1)
                                            error('ControlCommand:getParameter:uninitializedVariable','Variable "%s" used outside of its declared structure.', currVarName{1});
                                        elseif(scriptDepth == 1)
                                            %global variable
                                            variableIndex = 1;
                                        else
                                            variableIndex = depthIndex(scriptDepth);
                                        end
                                        currValueArray = currVariable.valueArray;
                                        newValue = currValueArray{variableIndex};

                                        %...and substitute it
                                        value = strrep(value, currVarName, StringFun.all2str(newValue));
                                    end
                                end
                            end
                        end
                        currNode = currNode.parent;
                    end
                end
            end
        end
                
        function script = getScript(cc, scriptDepth)
            if(~exist('scriptDepth','var'))
                scriptDepth = 0;
            end
            
            script = '';

            text = sprintf('%s<%s ', StringFun.getIndent(scriptDepth), cc.commandName);
            script = [script text];
            
            parameterNames = fieldnames(cc.parameters);
            len = length(parameterNames);
            for i = 1:len
                currParameterName = parameterNames{i};
                currParameter = cc.parameters.(currParameterName);
                if(i~=len)
                    spacer = ' ';
                else
                    spacer = sprintf('></%s>\n', cc.commandName);
                end
                if(strcmp(class(currParameter),'ScriptVariable'))
                    %if this parameter is a loop variable, give its name
                    text = sprintf('%s="VAR_%s"', currParameterName, currParameter.name);
                else
                    %or else just transfer its value to the output array
                    text = sprintf('%s="%s"', currParameterName, StringFun.all2str(currParameter));
                end
                script = [script text spacer]; %concatenate
            end           
        end

    end % END PUBLIC METHODS
    
end

