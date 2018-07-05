classdef CheckParam
    methods (Static)

        %Type checking

        %Numeric (double is the default matlab type for all numeric data)
        function confirm = isNumeric(inputParameter, errorIdentifier, errorMessage)
            if(~exist('errorMessage','var')) %if we didn't pass in a specific error message...
                errorMessage = 'Parameter must be a numeric value'; %...use a generic one
            end

            exception = MException(errorIdentifier,errorMessage);
            
            if(strcmp(class(inputParameter),'ScriptVariable'))
                numIterations = length(inputParameter.valueArray);
                if(numIterations == 0) %if empty
                    throwAsCaller(exception);
                else
                    for i=1:numIterations
                        CheckParam.isNumeric(inputParameter.valueArray{i}, errorIdentifier, errorMessage);
                    end
                end
            elseif(isempty(inputParameter))
                throwAsCaller(exception);
            elseif(~strcmp(class(inputParameter),'double'))
                throwAsCaller(exception);
            end
            confirm = true;
        end
        
        %Integer - NOTE that the default matlab type for all numeric data,
        %integer and floating point is double.  So, we test for
        %divisibility by 1 to determine if it is an integer
        function confirm = isInteger(inputParameter, errorIdentifier, errorMessage)
            if(~exist('errorMessage','var')) %if we didn't pass in a specific error message...
                errorMessage = 'Parameter must be an integer value'; %...use a generic one
            end
            
            exception = MException(errorIdentifier,errorMessage);
            
            if(strcmp(class(inputParameter),'ScriptVariable'))
                numIterations = length(inputParameter.valueArray);
                if(numIterations == 0) %if empty
                    throwAsCaller(exception);
                else
                    for i=1:numIterations
                        CheckParam.isInteger(inputParameter.valueArray{i}, errorIdentifier, errorMessage);
                    end
                end
            else
                try %make sure the parameter is at least numeric
                    CheckParam.isNumeric(inputParameter, 'CheckParam:isInteger:badInputs');
                catch err
                    throwAsCaller(exception);
                end
                %now that we know it is numeric, check for divisibility by one
                if(mod(inputParameter, 1))
                    throwAsCaller(exception);
                end
            end
            confirm = true;
        end

        %String
        function confirm = isString(inputParameter, errorIdentifier, errorMessage)
            if(~exist('errorMessage','var')) %if we didn't pass in a specific error message...
                errorMessage = 'Parameter must be a string value'; %...use a generic one
            end
            
            exception = MException(errorIdentifier,errorMessage);
            
            if(strcmp(class(inputParameter),'ScriptVariable'))
                numIterations = length(inputParameter.valueArray);
                if(numIterations == 0) %if empty
                    throwAsCaller(exception);
                else
                    for i=1:numIterations
                        CheckParam.isString(inputParameter.valueArray{i}, errorIdentifier, errorMessage);
                    end
                end
            elseif(~ischar(inputParameter))
                throwAsCaller(exception);
            end
            confirm = true;
        end

        %Char
        function confirm = isChar(inputParameter, errorIdentifier, errorMessage)
            if(~exist('errorMessage','var')) %if we didn't pass in a specific error message...
                errorMessage = 'Parameter must be a char value'; %...use a generic one
            end

            exception = MException(errorIdentifier,errorMessage);
            
            if(strcmp(class(inputParameter),'ScriptVariable'))
                numIterations = length(inputParameter.valueArray);
                if(numIterations == 0) %if empty
                    throwAsCaller(exception);
                else
                    for i=1:numIterations
                        CheckParam.isChar(inputParameter.valueArray{i}, errorIdentifier, errorMessage);
                    end
                end
            else
                try %make sure the parameter is at least a string
                    CheckParam.isString(inputParameter, 'CheckParam:isInteger:badInputs');
                catch err
                    throwAsCaller(exception);
                end
                %now that we know it is a string, check for a length of one
                if(length(inputParameter)~=1)
                    throwAsCaller(exception);
                end
            end
            confirm = true;
        end
        
        %Cell array
        function confirm = isCellArray(inputParameter, errorIdentifier, errorMessage)
            if(~exist('errorMessage','var')) %if we didn't pass in a specific error message...
                errorMessage = 'Parameter must be a cell array'; %...use a generic one
            end
            
            if(~iscell(inputParameter))
                exception = MException(errorIdentifier,errorMessage);
                throwAsCaller(exception);
            end
            confirm = true;            
        end
        
        %Cell array of strings
        function confirm = isCellArrayOfStrings(inputParameter, errorIdentifier, errorMessage)
            if(~exist('errorMessage','var')) %if we didn't pass in a specific error message...
                errorMessage = 'Parameter must be a cell array of strings'; %...use a generic one
            end
            
            if(~iscellstr(inputParameter))
                exception = MException(errorIdentifier,errorMessage);
                throwAsCaller(exception);
            end
            confirm = true;
        end
        
        %Boolean
        function confirm = isBoolean(inputParameter, errorIdentifier, errorMessage)
            if(~exist('errorMessage','var')) %if we didn't pass in a specific error message...
                errorMessage = 'Parameter must be a boolean variable'; %...use a generic one
            end          

            exception = MException(errorIdentifier,errorMessage);
            
            if(strcmp(class(inputParameter),'ScriptVariable'))
                numIterations = length(inputParameter.valueArray);
                if(numIterations == 0) %if empty
                    throwAsCaller(exception);
                else
                    for i=1:numIterations
                        CheckParam.isBoolean(inputParameter.valueArray{i}, errorIdentifier, errorMessage);
                    end
                end
            elseif(~isa(inputParameter, 'logical'))
                throwAsCaller(exception);
            end
            confirm = true;
        end
        
        %Any particular class type
        function confirm = isClassType(inputParameter, className, errorIdentifier, errorMessage)
            CheckParam.isString(className, 'CheckParam:isClassType:badInputs');
            if(~exist('errorMessage','var')) %if we didn't pass in a specific error message...
                errorMessage = 'Parameter must be of type ';
                errorMessage = strcat(errorMessage, className); %...use a generic one
            end
            
            if(~strcmp(class(inputParameter),className))
                exception = MException(errorIdentifier,errorMessage);
                throwAsCaller(exception);
            end
            confirm = true;
        end
        
        %Value checking (do only after type checking)

        %Check to make sure the parameter value is within a range
        function confirm = isWithinARange(param, lowerBound, upperBound, errorIdentifier, errorMessage)         
            CheckParam.isNumeric(param, 'CheckParam:isWithinARange:badInputs');
            CheckParam.isNumeric(lowerBound, 'CheckParam:isWithinARange:badInputs');
            CheckParam.isNumeric(upperBound, 'CheckParam:isWithinARange:badInputs');
            
            if(lowerBound > upperBound) %...if the bounding conditions are reversed
                temp = lowerBound; %switch
                lowerBound = upperBound;
                upperBound = temp;
            end

            if(~exist('errorMessage','var')) %if we didn't pass in a specific error message...
                errorMessage = sprintf('Parameter must be between %f and %f', lowerBound, upperBound); %...use a generic one
            end
            
            if((param < lowerBound) || (param > upperBound))
                exception = MException(errorIdentifier,errorMessage);
                throwAsCaller(exception);
            end
            confirm = true;
        end
        
        %Check to make sure the parameter is one of a short, finite list of acceptable values:
        function confirm = isInList(param, list, errorIdentifier, errorMessage)
            CheckParam.isCellArrayOfStrings(list, 'CheckParam:isInList:badInputs');
            
            if(~exist('errorMessage','var')) %if we didn't pass in a specific error message...
                errorMessage = 'Paramter value is not on the list of acceptable values'; %...use a generic one
            end
            exception = MException(errorIdentifier, errorMessage);
            
            if(strcmp(class(param),'ScriptVariable'))
                numIterations = length(param.valueArray)
                if(numIterations == 0) %if empty
                    throwAsCaller(exception);
                else
                    for i=1:numIterations
                        CheckParam.isInList(param.valueArray{i}, list, errorIdentifier, errorMessage);
                    end
                end
            else
                CheckParam.isString(param, 'CheckParam:isInList:badInputs');
                %param = param
                if(~ismember(param, list))
                    throwAsCaller(exception);
                end
            end
            confirm = true;
        end

        %Scan string input to make sure it adheres to a particular format and return the parameter values:
        function params = scanFormattedInput(inputString, formatString, numExpectedParams, errorIdentifier, errorMessage)
            CheckParam.isString(inputString, 'CheckParam:scanFormattedInput:badInputs');
            CheckParam.isString(formatString, 'CheckParam:scanFormattedInput:badInputs');
            CheckParam.isInteger(numExpectedParams, 'CheckParam:scanFormattedInput:badInputs');
            
            if(~exist('errorMessage','var')) %if we didn't pass in a specific error message...
                errorMessage = 'Input string could not be correctly parsed'; %...use a generic one
            end
            
            [params, count] = sscanf(inputString,formatString);
            if(count ~= numExpectedParams)
                exception = MException(errorIdentifier,errorMessage);
                throwAsCaller(exception);
            end
        end
        
    end
end