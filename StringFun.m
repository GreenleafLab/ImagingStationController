classdef StringFun
    methods (Static)
        function str = all2str(inputParameter) %converts variables of many types to string
            if(ischar(inputParameter))
                str = inputParameter;
            elseif(strcmp(class(inputParameter),'double'))
                str = num2str(inputParameter);
            elseif(isa(inputParameter, 'logical'))
                if(inputParameter)
                    str = 'true';
                else
                    str = 'false';
                end
            elseif(iscell(inputParameter))
                len = length(inputParameter);
                str = '';
                for i = 1:len
                    if(i~=len)
                        separator = ',';
                    else
                        separator = '';
                    end
                    str = [str StringFun.all2str(inputParameter{i}) separator];
                end
            else
                error('StringFun:all2str:unrecognizedType','Inputs of type "%s" not supported in the current implementation of all2str.', class(inputParameter));
            end
        end
        
        function str = getIndent(depth)
            str = repmat(' ',[1 depth*3]);
        end

        function timestamp = getTimestampString()
            c = clock;
            timestamp = sprintf('%4d.%02d.%02d-%02d.%02d.%06.3f', c(1), c(2), c(3), c(4), c(5), c(6));
        end
        
        function filenameRoot = getFilenameRoot(pathAndFilename, delimiter)
            if(~exist('delimiter','var'))
                delimiter = '_';
            else
                CheckParam.isString(delimiter, 'StringFun:filenameRoot:badDelimiter');
            end
            [pathstr, name, ext] = fileparts(pathAndFilename);
            %find the last delimiter (e.g. underscore '_') and return everything before it
            underscoreList = strfind(name, delimiter);
            if(~isempty(underscoreList))
                lastUnderscore = underscoreList(end);
                filenameRoot = name(1:lastUnderscore);
            else
                %if no underscore was found, return an empty string
                filenameRoot = '';
            end
        end
        
    end

end
