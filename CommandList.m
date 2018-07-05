%#########################################################################
% CommandList
% List to contain ControlCommands to be executed in order
% Written by Curtis Layton 10/2012
%#########################################################################

classdef CommandList < handle
    
    properties % PROPERTIES
        commandArray; %cell array to store commands
        parent;
        
        variableList;
    end % END PROPERTIES
        
    
    methods (Access = private) % PRIVATE METHODS
        
    end % END PRIVATE METHODS
    
    methods % PUBLIC METHODS
        
        function command = CommandList() %constructor
            command.commandArray = {};
        end  
        
        function setParent(command, parent)
            command.parent = parent;
        end
        
        function parent = getParent(command)
            parent = command.parent;
        end
        
        function numCommands = getNumCommands(command)
            numCommands = length(command.commandArray);
        end
        
        function currCommand = getCommand(command, index)
            numCommands = command.getNumCommands();
            if(CheckParam.isInteger(index, 'CommandList:currCommand:badInputs'))
                CheckParam.isWithinARange(index, 1, numCommands, 'CommandList:currCommand:badInputs');
            end
            currCommand = command.commandArray{index};
        end
        
        function addCommand(command, newCommand, index) %adds a new command to the indicated index in commandArray
            newCommand.setParent(command);
            
            endPosition = length(command.commandArray) + 1;
            if(~exist('index', 'var'))
                index = endPosition; %if no position is specified, add the command to the end
            else
                if(CheckParam.isInteger(index, 'CommandList:addCommand:badInputs'))
                    %enforce limits on where insertions can be made 
                    if(index < 1)
                        index = 1;
                    end
                    if(index > endPosition)
                        index = endPosition;
                    end
                end
            end
            
            %initially, add all commands to the end of the array
            command.commandArray{endPosition} = newCommand;
            
            if(index < endPosition) %if the command was to be inserted into the middle of the array
                command.reorderCommands(endPosition, index); %reorder
            end
        end
             
        function deleteCommand(command, index) %deletes the command at index
            CheckParam.isInteger(index, 'CommandList:deleteCommand:badInputs');
            lastPosition = length(command.commandArray);
            if((index < 1) || (index > lastPosition)) %if the index to be deleted is out of bounds
                %do nothing
            elseif(isempty(command.commandArray)) %if the commandArray is empty
                %do nothing
            elseif(index == lastPosition) %if the last position is to be deleted
                command.commandArray = command.commandArray(1:(lastPosition-1));
            elseif(index == 1) %if the first position is to be deleted
                command.commandArray = command.commandArray(2:lastPosition);
            else %if an internal position is to be deleted
                pre = command.commandArray(1:(index-1));
                post = command.commandArray((index+1):lastPosition);
                command.commandArray = [pre post]; %concatenate
            end
        end
        
        function reorderCommands(command, fromIndex, destinationIndex) %moves the command at fromIndex to position destinationIndex
            CheckParam.isInteger(fromIndex, 'CommandList:reorderCommands:badInputs');
            lastPosition = length(command.commandArray);
            if(CheckParam.isInteger(destinationIndex, 'CommandList:reorderCommands:badInputs'))
                %enforce limits on destination indices 
                if(index < 1)
                    index = 1;
                end
                if(index > lastPosition)
                    index = lastPosition;
                end
            end
            if((fromIndex < 1) || (fromIndex > lastPosition) || (fromIndex == destinationIndex)) %if the index to be moved is out of bounds
                %do nothing
            elseif(isempty(command.commandArray)) %if the commandArray is empty
                %do nothing
            else
                commandToBeMoved = command.commandArray{fromIndex};
                command.deleteCommand(fromIndex);
                if(index == lastPosition) %if it is being moved to the last position
                    command.commandArray = [command.commandArray commandToBeMoved];
                elseif(index == 1) %if it is being moved to the first position
                    command.commandArray = [commandToBeMoved command.commandArray];
                else %if the command is being moved to an internal position
                    pre = command.commandArray(1:(destinationIndex-1));
                    post = command.commandArray(destinationIndex:length(command.commandArray));
                    command.commandArray = [pre commandToBeMoved post]; %concatenate
                end
            end        
        end

        function execute(command, scriptDepth, depthIndex)
            if(~exist('scriptDepth','var'))
                scriptDepth = 1;
            end
            if(~exist('depthIndex','var'))
                depthIndex = [];
            end
            for i = 1:command.getNumCommands()  %iterate through each individual command
                currCommand = command.getCommand(i);
                currCommand.execute(scriptDepth, depthIndex);
            end
        end
        
        %get a script from the control command list
        function script = getScript(command, scriptDepth)
            if(~exist('scriptDepth','var'))
                scriptDepth = 0;
            end
 
            script = '';

            for i = 1:command.getNumCommands()  %iterate through each individual command
                currCommand = command.getCommand(i);
                if(strcmp(currCommand.commandName,'loop'))
                    script = [script currCommand.getScript(scriptDepth)]; %concatenate
                else
                    script = [script currCommand.getScript(scriptDepth)]; %concatenate
                end
            end
        end

    end % END PUBLIC METHODS
    
end