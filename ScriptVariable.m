%#########################################################################
% ScriptVariable
% simple placeholder object to designate a variable
% Written by Curtis Layton 10/2012
%#########################################################################

classdef ScriptVariable < handle

    properties % PROPERTIES
        name;
        valueArray;
        dataType;
        parentStructure; % a reference to the parent loop or sub of this variable
    end % END PROPERTIES

    methods (Access = private) % PRIVATE METHODS
        
        function initArray(scriptVariable)
            numIterations = length(scriptVariable.valueArray);
            for i = 1:numIterations
                switch scriptVariable.dataType %init to default values
                    case 'num'
                        scriptVariable.valueArray{i} = 0;
                    case 'str'
                        scriptVariable.valueArray{i} = '';
                    case 'bool'
                        scriptVariable.valueArray{i} = false;
                    otherwise
                        error('xml2struct:initArray:invalidDataType','only values of type "num" "str" or "bool" are supported');
                end
                
            end
        end
        
    end % END PRIVATE METHODS
    
    methods % PUBLIC METHODS
        function scriptVariable = ScriptVariable(name, dataType, numIterations) %constructor
            CheckParam.isString(name, 'ScriptVariable:ScriptVariable:badInputs');
            if(~exist('numIterations','var'))
                numIterations = 1;
            else
                CheckParam.isInteger(numIterations, 'ScriptVariable:ScriptVariable:badInputs');
            end
            scriptVariable.name = name;
            scriptVariable.dataType = dataType;
            scriptVariable.valueArray = cell(1, numIterations);
            scriptVariable.initArray();
        end

        function setName(scriptVariable, name)
            CheckParam.isString(name, 'ScriptVariable:setName:badInputs');
            scriptVariable.name = name;
        end

        function name = getName(scriptVariable)
            name = scriptVariable.name;
        end

        function setParent(scriptVariable, parent)
            scriptVariable.parentStructure = parent;
        end

        function depth = getScriptDepth(scriptVariable)
            if(isempty(scriptVariable.parentStructure))
                depth = 1;
            else
                depth = scriptVariable.parentStructure.getScriptDepth();
            end
        end
    end % END PUBLIC METHODS
end