%#########################################################################
% VICI_EMHMA_CE_SelectorValveController
% Serial hardware control interface with the VICI EMHMA-CE selector valve
% Written by Lauren Chircus and Curtis Layton 09/2012
%#########################################################################

classdef VICI_EMHMA_CE_SelectorValveController < handle
    
    properties % PROPERTIES
        commands = containers.Map();
        serialCom;
    end % END PROPERTIES
    
    properties (Constant)
        positionSelectorExclusionList = [16,17,18]; % which positions of the selector valve are blocked off and should not be selectable; BM removed 1,2,6,8 from list 10/14/13
        numSerialRetries = 3; %number of times to attempt to read from a serial device.  (Hiccups occur from time to time, and re-reading is necessary.)
        serialHiccupPause = 0.3; %seconds to pause after a serial hiccup to reattempt communication
    end % END CONSTANT PROPERTIES
    
    methods (Access = private) % PRIVATE METHODS
        
        % Send serial command to controller; adapted from Curtis
        function sendSerialCommand(EMHMA, command)
            CheckParam.isString(command, 'VICI_EMHMA_CE_SelectorValveController:sendSerialCommand:badInputs');
            
            try
                fprintf(EMHMA.serialCom, command);
            catch err
                error('VICI_EMHMA_CE_SelectorValveController:sendSerialCommand:cannotSend',...
                    'Cannot send to the EMHMA-CE Multipurpose Actuator Control Module through serial communication on port "%s".', EMHMA.serialCom.Port);
            end
        end
        
        
        % get response from controller; adapted from Curtis
        function response = getSerialResponse(EMHMA)
            response = ''; %init
            responseByte = 0; %init
            while(responseByte ~= 13) %read until we get to the 'carriage return' line terminator character
                numSerialTries = 0;
                responseByte = []; %init
                while((isempty(responseByte)) && (numSerialTries < EMHMA.numSerialRetries))
                    lastwarn(''); %clear lastwarn so if we get a timeout warning we can throw a real error
                    responseByte = fread(EMHMA.serialCom, 1, 'int8');
                    [warningMessage warningID] = lastwarn;
                    if(strcmp(warningID, 'MATLAB:serial:fread:unsuccessfulRead'))
                        pause on; pause(EMHMA.serialHiccupPause);
                    end
                    numSerialTries = numSerialTries + 1;
                end

                [warningMessage warningID] = lastwarn;
                if(strcmp(warningID, 'MATLAB:serial:fread:unsuccessfulRead'))
                    error('VICI_EMHMA_CE_SelectorValveController:getSerialResponse:Timeout',...
                        'More than the timeout limit (%f sec) passed waiting for a response from the EMHMA-CE Multipurpose Actuator Control Module on port "%s".',...
                        EMHMA.serialCom.Timeout, EMHMA.serialCom.Port);
                elseif(isempty(responseByte))
                    error('VICI_EMHMA_CE_SelectorValveController:getSerialResponse:comError',...
                        'Trouble communicating with the EMHMA-CE Multipurpose Actuator Control Module on port "%s".',...
                        EMHMA.serialCom.Port);
                end
                
                switch responseByte
                    case 13 %'carriage return' terminator character
                        break;
                    case 10 %line feed
                        %do not add to the response
                    case 32 %space
                        if (~isempty(response)) %only if it is not a leading space
                            response = [response char(responseByte)]; %add to the response
                        end
                    otherwise
                        response = [response char(responseByte)]; %otherwise add to the response
                end
            end
        end
        
        
        % checks the response to see if the command was bad and if the
        % output is appropriate for the sent command
        function confirm = checkResponse(EMHMA, response, command, errorIdentifier)
            CheckParam.isString(response, 'VICI_EMHMA_CE_SelectorValveController:checkResponse:badInput');
            CheckParam.isString(command, 'VICI_EMHMA_CE_SelectorValveController:checkResponse:badInput');
            
            if (length(response)>=10) && (strcmp(response(end-10:end),'Bad command'))
                error(errorIdentifier, 'Unexpected response ("%s") received to command "%s"', response, command)
            elseif strcmp(command,'CP')
                if (length(response)<15) || (~strcmp(response(1:15),'Position is  = '))
                    error(errorIdentifier, 'Unexpected response ("%s") received to command "%s"', response, command)
                end
            elseif (length(response)<2) || (~strcmp(response(1:2),command(1:2)))
                error(errorIdentifier, 'Unexpected response ("%s") received to command "%s"', response, command)
            end
            confirm = true;
        end
    end % END PRIVATE METHODS
    
    
   
    methods  % PUBLIC METHODS
        
        % Constructor method
        function EMHMA = VICI_EMHMA_CE_SelectorValveController()
            EMHMA.commands('READ POSITION') = 'CP';
            EMHMA.commands('SET POSITION') = 'GO';
            EMHMA.commands('READ ROTATIONAL DIRECTION') = 'SM';
            EMHMA.commands('SET ROTATIONAL DIRECTION') = 'SM';
            EMHMA.commands('READ NUMBER OF POSITIONS') = 'NP';
            EMHMA.commands('SET NUMBER OF POSITIONS') = 'NP';
            EMHMA.commands('READ OFFSET') = 'SO';     
            EMHMA.commands('SET OFFSET') = 'SO';
            warning('off', 'MATLAB:serial:fread:unsuccessfulRead');
        end
        
        
        % create serial object
        function setupSerialCommunication(EMHMA, serialPort, baudRate, dataBits, parityBit, stopBits, flowControl, lineTerminator)
            
            %default values
            if(~exist('baudRate','var'))
                baudRate = 9600;
            end
            if(~exist('dataBits','var'))
                dataBits = 8;
            end
            if(~exist('parityBit','var'))
                parityBit = 'none';
            end
            if(~exist('stopBits','var'))
                stopBits = 1;
            end
            if(~exist('flowControl','var'))
                flowControl = 'none';
            end
            if(~exist('lineTerminator','var'))
                lineTerminator = 'CR';
            end
            
            EMHMA.serialCom = serial(serialPort);
            set(EMHMA.serialCom, 'BaudRate', baudRate);
            set(EMHMA.serialCom, 'DataBits', dataBits);
            set(EMHMA.serialCom, 'Parity', parityBit);
            set(EMHMA.serialCom, 'StopBits', stopBits);
            set(EMHMA.serialCom, 'FlowControl', flowControl);
            set(EMHMA.serialCom, 'Terminator', lineTerminator);
        end
        
        
        % Open serial port
        function serialConnect(EMHMA)
            try
                fopen(EMHMA.serialCom);
            catch err
                error('VICI_EMHMA_CE_SelectorValveController:serialConnect:cannotConnect',...
                    'Cannot open the serial port "%s" to communicate with the EMHMA-CE Multipurpose Actuator Control Module.', EMHMA.serialCom.Port);
            end
        end
        
        
        % Close serial port
        function serialDisconnect(EMHMA)
            try
                fclose(EMHMA.serialCom);
            catch err
                error('VICI_EMHMA_CE_SelectorValveController:close:cannotClose',...
                    'Cannot close the serial port "%s" to communicate with the EMHMA-CE Multipurpose Actuator Control Module.', EMHMA.serialCom.Port);
            end
        end

        
        % Reading and setting position functions
        function position = getPosition(EMHMA)
            command = EMHMA.commands('READ POSITION');
            EMHMA.sendSerialCommand(command);
            response = EMHMA.getSerialResponse();
            try
                params = CheckParam.scanFormattedInput(response, 'Position is  = %d', 1, 'VICI_EMHMA_CE_SelectorValveController:getPosition:badResponse');
                position = params(1);
                CheckParam.isInteger(position, 'VICI_EMHMA_CE_SelectorValveController:getPosition:badResponse');
                numPositions = EMHMA.getNumPositions();
                CheckParam.isWithinARange(position, 0, numPositions, 'VICI_EMHMA_CE_SelectorValveController:getPosition:badResponse');
            catch err
                response = response
                params = CheckParam.scanFormattedInput(response, 'Position is near to = %d', 1, 'VICI_EMHMA_CE_SelectorValveController:getPosition:badResponse');
                position = -1;
            end
        end
        
        function setPosition(EMHMA, setValue)
            if(CheckParam.isInteger(setValue,'VICI_EMHMA_CE_SelectorValveController:setPosition:badInputs'))
                numPositions = EMHMA.getNumPositions();
                CheckParam.isWithinARange(setValue, 0, numPositions, 'VICI_EMHMA_CE_SelectorValveController:setPosition:badInputs');
            end
 
            currPosition = EMHMA.getPosition();
            if(currPosition ~= setValue) %only change position if a different position is requested
                command = [EMHMA.commands('SET POSITION') num2str(setValue)];
                EMHMA.sendSerialCommand(command);

                % read position 
                command = EMHMA.commands('READ POSITION');
                EMHMA.sendSerialCommand(command);
                response = EMHMA.getSerialResponse();
                %if the command is bad, there will still be another response in
                %the buffer from the read position
                if strcmp(response(end-10:end),'Bad command')
                    EMHMA.getSerialResponse();
                    command = [EMHMA.commands('SET POSITION') setValue];
                end

                EMHMA.checkResponse(response, command, 'VICI_EMHMA_CE_SelectorValveController:setPosition:badResponse');
            end
            currPosition = EMHMA.getPosition() % TEMP Debug -- REMOVE
        end
        
        % Reading and setting rotational direction functions
        % 'A' = Auto (rotate in the direction that yields the shortest path)
        % 'F' = Forward
        % 'R' = Reverse
        function direction = getRotationalDirection(EMHMA)
            command = EMHMA.commands('READ ROTATIONAL DIRECTION');
            EMHMA.sendSerialCommand(command);
            response = EMHMA.getSerialResponse();
            params = CheckParam.scanFormattedInput(response, 'SM = %c', 1, 'VICI_EMHMA_CE_SelectorValveController:getRotationalDirection:badResponse');
            direction = params(1);
            CheckParam.isInList(direction,{'A' 'R' 'F'},'VICI_EMHMA_CE_SelectorValveController:getRotationalDirection:badResponse');
        end
        
        function setRotationalDirection(EMHMA, setvalue)
            if CheckParam.isChar(setvalue,'VICI_EMHMA_CE_SelectorValveController:setRotationalDirection:badInputs');
                CheckParam.isInList(setvalue,{'A' 'R' 'F'},'VICI_EMHMA_CE_SelectorValveController:setRotationalDirection:badInputs');
            end
            
            command = [EMHMA.commands('SET ROTATIONAL DIRECTION') setvalue];
            EMHMA.sendSerialCommand(command);
            response = EMHMA.getSerialResponse();
            EMHMA.checkResponse(response, command, 'VICI_EMHMA_CE_SelectorValveController:setRotationalDirection:badResponse');
        end
        
        % Reading and setting number of positions functions
        function numPositions = getNumPositions(EMHMA)
            command = EMHMA.commands('READ NUMBER OF POSITIONS');
            EMHMA.sendSerialCommand(command);
            response = EMHMA.getSerialResponse();
            params = CheckParam.scanFormattedInput(response, 'NP = %d', 1, 'VICI_EMHMA_CE_SelectorValveController:getNumPositions:badResponse');
            numPositions = params(1);
            CheckParam.isInteger(numPositions, 'VICI_EMHMA_CE_SelectorValveController:getNumPositions:badResponse');          
        end
        
        function setNumPositions(EMHMA, setvalue)
            if(CheckParam.isInteger(setvalue,'VICI_EMHMA_CE_SelectorValveController:setNumPositions:badInputs'))
                if(setvalue<0)
                    error('VICI_EMHMA_CE_SelectorValveController:setNumPositions:badInputs',...
                        'Input parameter must be an integer value greater than or equal to 0');
                end
            end
            
            command = [EMHMA.commands('SET NUMBER OF POSITIONS') num2str(setvalue)];
            EMHMA.sendSerialCommand(command);
            response = EMHMA.getSerialResponse();
            EMHMA.checkResponse(response, command, 'VICI_EMHMA_CE_SelectorValveController:setNumPositions:badResponse');
        end
        
        % Reading and setting offset functions
        function offset = getOffset(EMHMA)
            command = EMHMA.commands('READ OFFSET');
            EMHMA.sendSerialCommand(command);
            response = EMHMA.getSerialResponse();
            params = CheckParam.scanFormattedInput(response, 'SO = %d', 1, 'VICI_EMHMA_CE_SelectorValveController:getOffset:badResponse');
            offset = params(1);
            CheckParam.isInteger(offset, 'VICI_EMHMA_CE_SelectorValveController:getOffset:badResponse');   
        end
        
        function setOffset(EMHMA, setValue)
            if CheckParam.isInteger(setValue,'VICI_EMHMA_CE_SelectorValveController:setOffset:badInputs')
                numPositions = EMHMA.getNumPositions();
                CheckParam.isWithinARange(setValue,1,96-numPositions,'VICI_EMHMA_CE_SelectorValveController:setOffset:badInputs');
            end
            
            command = [EMHMA.commands('SET OFFSET') num2str(setValue)];
            EMHMA.sendSerialCommand(command);
            currOffset = EMHMA.getOffset();
            if(currOffset ~= setValue)
                error('VICI_EMHMA_CE_SelectorValveController:setOffset:badResponse', 'Current offset "%d" could not be changed to the requested offset ("%d")', currOffset, setValue);
            end
        end
    end

end % END PUBLIC METHODS

