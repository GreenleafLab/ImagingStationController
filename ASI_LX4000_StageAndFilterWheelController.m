%#########################################################################
% TC_36_25_RS232_PeltierController
% Serial hardware control interface with the ASI LX-4000 stage and filter
% wheel controller
% Written by Curtis Layton 09/2012
%#########################################################################

classdef ASI_LX4000_StageAndFilterWheelController < handle
    
    properties % PROPERTIES
        serialCom;
        statusPollingDelay = 0.5; %time interval in between polling the device to see if still executing the last command, or otherwise 'busy' (in seconds)
        responseTimeout = 2; %max time to wait for a response (in seconds)
        positionTolerance = 50.0; %the servo reports back the position after a move, which will be slightly off of the requested position
                                 %If the position is within this tolerance, we consider the move has been completed successfully
                                 %TODO calibrate this
        moveCheckInterval = 3; %poll the position every 'moveCheckInterval' seconds to make sure the move is in progress
        
        %SERIAL COMMANDS
        serialCommands = containers.Map(); %create an associative array to contain all serial commands
        expectedSerialResponses = containers.Map(); %create an associative array to contain all expected responses to those commands
        haltFlag; %flag to indicate when a stage move has been halted
    end % END PROPERTIES

    properties (Constant)
        defaultLargeStepXY = '8000';
        defaultSmallStepXY = '2000';
        defaultLargeStepZ = '120';
        defaultSmallStepZ = '20';
        maxStep = 0.0001;
        minStep = 500000;

        stageXLimitMax =  1000000;
        stageXLimitMin = -1200000;
        stageYLimitMax =  1000000;
        stageYLimitMin = -1200000;
        stageZLimitMax =  1000000;
        stageZLimitMin = -1200000;

        %stageZSafePosition = -90000; % position of Z stage such that the objective is far away from the flow holder (i.e. position of Z such that XY stages can move without obstruction)
        stageZSafePosition = -111081; % new for TIRF machine (PLM 16-Dec-2013)
        stageSafeMoveLimit = 20000;
        %flowCellXmin = -593891;
        %flowCellXmax = -500000;
        %flowCellYmin = -364858;
        %flowCellYmax = -157885;
        %flowCellXmin = -748907; % new for TIRF machine (PLM 16-Dec-2013)
        %flowCellXmax = -711887; % new for TIRF machine (PLM 16-Dec-2013)
        %flowCellYmin = -558000; % new for TIRF machine (PLM 16-Dec-2013)
        %flowCellYmax = -466000; % new for TIRF machine (PLM 16-Dec-2013)
        %flowCellXmin = -748907; % new for TIRF machine (JA 11-Mar-2014)
        %flowCellXmax = -711887; % new for TIRF machine (JA 11-Mar-2014)
        %flowCellYmin = -604100; % new for TIRF machine (JA 11-Mar-2014)
        %flowCellYmax = -465000; % new for TIRF machine (JA 11-Mar-2014)
        flowCellXmin = -761100; % new for TIRF machine (AH 09-Dec-2014)
        flowCellXmax = -734000; % new for TIRF machine (AH 09-Dec-2014)
        flowCellYmin = -500000; % new for TIRF machine (AH 09-Dec-2014)
        flowCellYmax = -343000; % new for TIRF machine (AH 09-Dec-2014)

        filterPositions = {'0', '1', '2', '3', '4', '5', '6', '7'};
        filterDescriptions =   {'0-ILLM-0027',...
                                '1-ILLM-0037 (short WLs)',...
                                '2-Green, Semrock FF01-590/104-25',...
                                '3-Red, Semrock BLP01-664R-25',...
                                '4-closed',...
                                '5-closed',...
                                '6-open',...
                                '7-open'};
        numSerialRetries = 3; %number of times to attempt to read from a serial device.  (Hiccups occur from time to time, and re-reading is necessary.)
        serialHiccupPause = 0.3; %seconds to pause after a serial hiccup to reattempt communication
    end % END CONSTANT PROPERTIES
    
    methods (Access = private) % PRIVATE METHODS
        
        function response = getSerialResponse(LX4000)
            response = ''; %init
            responseByte = 0; %init
            while(responseByte ~= 3) %read until we get to the 'end of text' line terminator character
                numSerialTries = 0;
                responseByte = []; %init
                while((isempty(responseByte)) && (numSerialTries < LX4000.numSerialRetries))
                    lastwarn(''); %clear lastwarn so if we get a timeout warning we can throw a real error
                    responseByte = fread(LX4000.serialCom, 1, 'int8');
                    [warningMessage warningID] = lastwarn;
                    if(strcmp(warningID, 'MATLAB:serial:fread:unsuccessfulRead'))
                        pause on; pause(LX4000.serialHiccupPause);
                    end
                    numSerialTries = numSerialTries + 1;
                end
                
                [warningMessage warningID] = lastwarn;
                if(strcmp(warningID, 'MATLAB:serial:fread:unsuccessfulRead'))
                    error('ASI_LX4000_StageAndFilterWheelController:getSerialResponse:Timeout', 'More than the timeout limit (%f sec) passed waiting for a response from the LX-4000 X,Y,Z stage and filter wheel controller on port "%s".', LX4000.serialCom.Timeout, LX4000.serialCom.Port);
                elseif(isempty(responseByte))
                    error('ASI_LX4000_StageAndFilterWheelController:getSerialResponse:comError', 'Trouble communicating with the LX-4000 X,Y,Z stage and filter wheel controller on port "%s".', LX4000.serialCom.Port);
                end
                
                warning('off','MATLAB:nonIntegerTruncatedInConversionToChar')
                charResponseByte = char(responseByte);
                warning('on','MATLAB:nonIntegerTruncatedInConversionToChar')

                switch responseByte
                    case 3 %'end of text' terminator character
                        break;
                    case 10 %line feed
                        %do not add to the response
                    case 13 %carriage return
                        %do not add to the response
                    case 32 %space
                        if(~isempty(response)) %only if it is not a leading space
                            response = [response charResponseByte]; %add to the response
                        end
                    otherwise
                        response = [response charResponseByte]; %otherwise add to the response        
                end
            end
        end
        
        function response = sendSerialCommand(LX4000, command)    
            CheckParam.isString(command, 'ASI_LX4000_StageAndFilterWheelController:sendSerialCommand:badInput');
                        
            try
                fprintf(LX4000.serialCom, command);
            catch err
                error('ASI_LX4000_StageAndFilterWheelController:sendSerialCommand:cannotSend','Cannot send to the LX-4000 X,Y,Z stage and filter wheel controller through serial communication on port "%s".', LX4000.serialCom.Port);
            end
            
            response = LX4000.getSerialResponse();
        end
        
        function found = knownErrorResponse(LX4000, response, command)
            CheckParam.isString(response, 'ASI_LX4000_StageAndFilterWheelController:knownErrorResponses:badInput');
            
            switch response
                case ':N-1'
                    errorMessage = sprintf('Unknown command: "%s"', command);
                    exception = MException('ASI_LX4000_StageAndFilterWheelController:knownErrorResponses:unknownCommand',errorMessage);
                    throwAsCaller(exception);
                case ':N-2'
                    errorMessage = sprintf('Unrecognized axis parameter in command: "%s"', command);
                    exception = MException('ASI_LX4000_StageAndFilterWheelController:knownErrorResponses:unrecognizedAxis',errorMessage);
                    throwAsCaller(exception);
                case ':N-3'
                    errorMessage = sprintf('Missing parameters in command: "%s"', command);
                    exception = MException('ASI_LX4000_StageAndFilterWheelController:knownErrorResponses:missingParameters',errorMessage);
                    throwAsCaller(exception);
                case ':N-4'
                    errorMessage = sprintf('Parameter out of range in command: "%s"', command);
                    exception = MException('ASI_LX4000_StageAndFilterWheelController:knownErrorResponses:outOfRange',errorMessage);
                    throwAsCaller(exception);
                case ':N-5'
                    errorMessage = sprintf('Operation Failed!');
                    exception = MException('ASI_LX4000_StageAndFilterWheelController:knownErrorResponses:operationFailed',errorMessage);
                    throwAsCaller(exception);
                case ':N-6'
                    errorMessage = sprintf('Undefined Error.  The command "%s" is incorrect', command);
                    exception = MException('ASI_LX4000_StageAndFilterWheelController:knownErrorResponses:undefinedError',errorMessage);
                    throwAsCaller(exception);
                otherwise
                    found = false;
            end
        end
        
        function clearSerialBuffer(LX4000)
            if(LX4000.serialCom.BytesAvailable > 0)
                disp('clearing LX4000 buffer');
                fread(LX4000.serialCom, LX4000.serialCom.BytesAvailable);
            end
        end
        
        function confirm = checkResponse(LX4000, response, command, errorIdentifier, commandPlusArgs)
            CheckParam.isString(response, 'ASI_LX4000_StageAndFilterWheelController:checkResponse:badInput');
            CheckParam.isString(command, 'ASI_LX4000_StageAndFilterWheelController:checkResponse:badInput');
            
            if(~exist('commandPlusArgs','var'))
                commandPlusArgs = command;
            else
                try
                    CheckParam.isString(commandPlusArgs, 'ASI_LX4000_StageAndFilterWheelController:checkResponse:badInput');
                catch err
                    throwAsCaller(err);
                end
            end
            
            errorMessage = sprintf('Unexpected response ("%s") received to command "%s"', response, commandPlusArgs);
            try
                CheckParam.isInList(response,LX4000.expectedSerialResponses(command),errorIdentifier,errorMessage);
            catch err1
                try
                    LX4000.knownErrorResponse(response, commandPlusArgs)
                catch err2
                    throwAsCaller(err2);
                end
                throwAsCaller(err1);
            end
            confirm = true;
        end
        
        function params = scanResponse(LX4000, response, command, format, numExpectedParams, errorIdentifier, commandPlusArgs)
            CheckParam.isString(response, 'ASI_LX4000_StageAndFilterWheelController:scanResponse:badInput');
            CheckParam.isString(command, 'ASI_LX4000_StageAndFilterWheelController:scanResponse:badInput');
            CheckParam.isString(format, 'ASI_LX4000_StageAndFilterWheelController:scanResponse:badInput');
            CheckParam.isInteger(numExpectedParams, 'ASI_LX4000_StageAndFilterWheelController:scanResponse:badInput');
            
            if(~exist('commandPlusArgs','var'))
                commandPlusArgs = command;
            else
                CheckParam.isString(commandPlusArgs, 'ASI_LX4000_StageAndFilterWheelController:scanResponse:badInput');
            end
            
            errorMessage = sprintf('Unexpected response ("%s") received to command "%s"', response, commandPlusArgs);
            try
                params = CheckParam.scanFormattedInput(response, format, numExpectedParams, errorIdentifier, errorMessage);
            catch err
                if(~LX4000.knownErrorResponse(response, commandPlusArgs))
                    rethrow(err);
                end
            end
        end
        
        function pollUntilNotBusy(LX4000, busyQuery, notBusyIndex, timeout)
            %polls the LX-4000 with busyQuery until the response indexed by notBusyIndex is received

            CheckParam.isString(busyQuery, 'ASI_LX4000_StageAndFilterWheelController:pollUntilNotBusy:badInput');
            CheckParam.isInteger(notBusyIndex, 'ASI_LX4000_StageAndFilterWheelController:pollUntilNotBusy:badInput');
            if(CheckParam.isNumeric(timeout, 'ASI_LX4000_StageAndFilterWheelController:pollUntilNotBusy:badInput'))
                CheckParam.isWithinARange(timeout, 0, 3600, 'ASI_LX4000_StageAndFilterWheelController:pollUntilNotBusy:badInput');
            end
            
            expectedResponses = LX4000.expectedSerialResponses(busyQuery); %get all the expected responses to this query...
            notBusyResponse = expectedResponses{notBusyIndex}; %..then out of those get the query that signifies 'not busy'
            response = ['NOTEQUALTO' notBusyResponse]; %initialize to a value guaranteed not to be notBusyResponse
            tStart = tic; %start the clock, for timeout purposes
            while ~strcmp(response, notBusyResponse)
                pause on; pause(LX4000.statusPollingDelay);
                try
                    response = LX4000.sendSerialCommand(busyQuery); %BUSY? query
                    LX4000.checkResponse(response, busyQuery, 'ASI_LX4000_StageAndFilterWheelController:pollUntilNotBusy:unexpectedResponse');
                catch err
                    if(~strcmp(err.identifier, 'ASI_LX4000_StageAndFilterWheelController:getSerialResponse:Timeout'))
                        rethrow(err);
                    else
                        %clear the serial buffer if a timeout happens
                        LX4000.clearSerialBuffer();
                    end
                end
                elapsedTime = toc(tStart);
                if(elapsedTime > timeout)
                    error('ASI_LX4000_StageAndFilterWheelController:pollUntilNotBusy:Timeout', 'More than the timeout limit (%f sec) passed waiting for the LX-4000 X,Y,Z stage and filter wheel controller to be "not busy".', timeout);
                end
            end            
        end

        
        %MS-2000 Z stage private methods
        function enableZ(LX4000)
            command = LX4000.serialCommands('ENABLE Z MOTOR CONTROL'); %enable Z motor control
            response = LX4000.sendSerialCommand(command);
            LX4000.checkResponse(response, command, 'ASI_LX4000_StageAndFilterWheelController:enableZ:unexpectedResponse');
        end
        
        function disableZ(LX4000)
            command = LX4000.serialCommands('DISABLE Z MOTOR CONTROL'); %disable Z motor control
            response = LX4000.sendSerialCommand(command);
            LX4000.checkResponse(response, command, 'ASI_LX4000_StageAndFilterWheelController:disableZ:unexpectedResponse');
        end
        
        
        %MS-2000 XY stage private methods
        function enableXY(LX4000)
            command = LX4000.serialCommands('ENABLE XY MOTOR CONTROL'); %enable Z motor control
            response = LX4000.sendSerialCommand(command);
            LX4000.checkResponse(response, command, 'ASI_LX4000_StageAndFilterWheelController:enableXY:unexpectedResponse');
        end
        
        function disableXY(LX4000)
            command = LX4000.serialCommands('DISABLE XY MOTOR CONTROL'); %disable Z motor control
            response = LX4000.sendSerialCommand(command);
            LX4000.checkResponse(response, command, 'ASI_LX4000_StageAndFilterWheelController:disableXY:unexpectedResponse');
       end
        
        
        %FW-1000 filter wheel private methods
        function selectFilterWheelChannel(LX4000, whichFilterWheel)
            %the LX-4000 can control up to 2 filter wheels, indexed 0 and 1
            %when we send the command to select one of the filter wheels,
            %all future commands to the filter wheel (prefixed with '3F') will be
            %channeled to this wheel until another selection is made
            
            %TODO check to make sure the selected filter wheel is available
            %(i.e. actually connected to the machine)
                        
            if(CheckParam.isChar(whichFilterWheel, 'ASI_LX4000_StageAndFilterWheelController:selectFilterWheelChannel:badInputs'))
            	CheckParam.isInList(whichFilterWheel,{'0' '1'},'ASI_LX4000_StageAndFilterWheelController:selectFilterWheelChannel:badInputs','Bad inputs: only filter wheel channel "0" or "1" may be selected');
            end

            command = LX4000.serialCommands('SELECT FILTER WHEEL CHANNEL');
            commandPlusArgs = [command whichFilterWheel];
            response = LX4000.sendSerialCommand(commandPlusArgs);
            LX4000.checkResponse(response, command, 'ASI_LX4000_StageAndFilterWheelController:selectFilterWheelChannel:unexpectedResponse', commandPlusArgs);
        end
        
    end % END PRIVATE METHODS
       
    methods %PUBLIC METHODS

        %constructor
        function LX4000 = ASI_LX4000_StageAndFilterWheelController()
            
            %MS-2000 Z stage commands (channel 1H)
            LX4000.serialCommands('Z STAGE BUSY?') = '1H/';
            LX4000.expectedSerialResponses(LX4000.serialCommands('Z STAGE BUSY?')) = {  'N'... %Not busy - note convention is for 'not busy' response to be indexed 1st
                                                                                        'B'};  %Busy

            LX4000.serialCommands('WHERE IS Z?') = '1HW Z';
            LX4000.expectedSerialResponses(LX4000.serialCommands('WHERE IS Z?')) = {':A %f'};  %returns position of Z (float)

            LX4000.serialCommands('Z AXIS IS AT LIMIT SWITCH?') = '1HRB';
            LX4000.expectedSerialResponses(LX4000.serialCommands('Z AXIS IS AT LIMIT SWITCH?')) = {':A %f'};  %returns position of Z (float)
            
            LX4000.serialCommands('HALT Z') = '1HHALT'; %Halt any current motion on the Z axis
            LX4000.expectedSerialResponses(LX4000.serialCommands('HALT Z')) = { ':A'...   %no move was halted
                                                                                ':N-21'}; %a command in motion on the Z axis was halted

            LX4000.serialCommands('HOME Z') = '1H! Z'; %move Z stage to home (upper limit switch)
            LX4000.expectedSerialResponses(LX4000.serialCommands('HOME Z')) = {':A'}; %no errors

            LX4000.serialCommands('SET CURRENT Z STAGE POSITION') = '1HH Z=' ; %followed by float argument which is assigned to be the current Z position
            LX4000.expectedSerialResponses(LX4000.serialCommands('SET CURRENT Z STAGE POSITION')) = {':A'}; %no errors

            LX4000.serialCommands('ENABLE Z MOTOR CONTROL') = '2HMC Z+'; %enable Z motor control
            LX4000.expectedSerialResponses(LX4000.serialCommands('ENABLE Z MOTOR CONTROL')) = {':A'}; %no errors
            
            LX4000.serialCommands('DISABLE Z MOTOR CONTROL') = '2HMC Z-'; %disable Z motor control
            LX4000.expectedSerialResponses(LX4000.serialCommands('DISABLE Z MOTOR CONTROL')) = {':A'}; %no errors
            
            LX4000.serialCommands('MOVE Z') = '1HM Z='; %followed by float argument, move Z stage to that position
            LX4000.expectedSerialResponses(LX4000.serialCommands('MOVE Z')) = {':A'}; %no errors


            %MS-2000 XY stage commands (channel 2H)
            LX4000.serialCommands('XY STAGE BUSY?') = '2H/';
            LX4000.expectedSerialResponses(LX4000.serialCommands('XY STAGE BUSY?')) = { 'N'... %Not busy - note convention is for 'not busy' response to be indexed 1st
                                                                                        'B'};  %Busy
            LX4000.serialCommands('WHERE IS X?') = '2HW X';
            LX4000.expectedSerialResponses(LX4000.serialCommands('WHERE IS X?')) = {':A %f'}; %returns position of X (float)

            LX4000.serialCommands('WHERE IS Y?') = '2HW Y';
            LX4000.expectedSerialResponses(LX4000.serialCommands('WHERE IS Y?')) = {':A %f'}; %returns position of Y (float)

            LX4000.serialCommands('HALT XY') = '2HHALT'; %Halt any current motion on the X OR Y axis
            LX4000.expectedSerialResponses(LX4000.serialCommands('HALT XY')) = {':A'...   %no move was halted
                                                                                ':N-21'}; %a command in motion on the Z axis was halted

            LX4000.serialCommands('HOME X') = '2H! X'; %move X stage to home (left limit switch)
            LX4000.expectedSerialResponses(LX4000.serialCommands('HOME X')) = {':A'}; %no errors

            LX4000.serialCommands('HOME Y') = '2H! Y'; %move Y stage to home (front limit switch)
            LX4000.expectedSerialResponses(LX4000.serialCommands('HOME Y')) = {':A'}; %no errors

            LX4000.serialCommands('SET CURRENT X STAGE POSITION') = '2HH X=' ; %followed by float argument which is assigned to be the current Z position
            LX4000.expectedSerialResponses(LX4000.serialCommands('SET CURRENT X STAGE POSITION')) = {':A'}; %no errors
            
            LX4000.serialCommands('SET CURRENT Y STAGE POSITION') = '2HH Y=' ; %followed by float argument which is assigned to be the current Z position
            LX4000.expectedSerialResponses(LX4000.serialCommands('SET CURRENT Y STAGE POSITION')) = {':A'}; %no errors
            
            LX4000.serialCommands('ENABLE XY MOTOR CONTROL') = '2HMC X+ Y+'; %enable XY motor control
            LX4000.expectedSerialResponses(LX4000.serialCommands('ENABLE XY MOTOR CONTROL')) = {':A'}; %no errors

            LX4000.serialCommands('DISABLE XY MOTOR CONTROL') = '2HMC X- Y-'; %disable XY motor control
            LX4000.expectedSerialResponses(LX4000.serialCommands('DISABLE XY MOTOR CONTROL')) = {':A'}; %no errors

            LX4000.serialCommands('MOVE X') = '2HM X='; %followed by float argument, move X stage to that position
            LX4000.expectedSerialResponses(LX4000.serialCommands('MOVE X')) = {':A'}; %no errors

            LX4000.serialCommands('MOVE Y') = '2HM Y='; %followed by float argument, move Y stage to that position
            LX4000.expectedSerialResponses(LX4000.serialCommands('MOVE Y')) = {':A'}; %no errors


            %FW-1000 filter wheel commands (channel 3F)
            LX4000.serialCommands('FILTER WHEEL BUSY?') = '3F?';
            LX4000.expectedSerialResponses(LX4000.serialCommands('FILTER WHEEL BUSY?')) = {'0'... %Neither wheel moving (not busy) - note convention is for 'not busy' response to be indexed 1st
                                                                             '1'... %One wheel moving, but within tolerance for clear light path
                                                                             '2'... %Two wheels moving, but both are within tolerance for a clear light path
                                                                             '3'};  %At least one wheel not in tolerance for a clear light path

            LX4000.serialCommands('SELECT FILTER WHEEL CHANNEL') = '3FFW '; %followed by argument [0-1] to select one of the two channels
            LX4000.expectedSerialResponses(LX4000.serialCommands('SELECT FILTER WHEEL CHANNEL')) = {'0' '1'}; %indicates the selected wheel

            LX4000.serialCommands('HALT FILTER WHEEL') = '3FHA';
            LX4000.expectedSerialResponses(LX4000.serialCommands('HALT FILTER WHEEL')) = {'Spin flag 1 not supported'}; %emperically this is the output

            LX4000.serialCommands('HOME FILTER WHEEL') = '3FHO';
            LX4000.expectedSerialResponses(LX4000.serialCommands('HOME FILTER WHEEL')) = {''};

            LX4000.serialCommands('MOVE FILTER WHEEL') = '3FMP '; %followed by argument [0-7] to select one of the 8 positions 
            LX4000.expectedSerialResponses(LX4000.serialCommands('MOVE FILTER WHEEL')) = {'0' '1' '2' '3' '4' '5' '6' '7'}; %indicates the current position  
            warning('off', 'MATLAB:serial:fread:unsuccessfulRead');
        end %constructor
        
        function setupSerialCommunication(LX4000, serialPort, baudRate, dataBits, parityBit, stopBits, flowControl, lineTerminator)
            %default values
            if(~exist('baudRate','var'))
                baudRate = 115200;
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
            
            LX4000.serialCom = serial(serialPort);
            set(LX4000.serialCom, 'BaudRate', baudRate);
            set(LX4000.serialCom, 'DataBits', dataBits);
            set(LX4000.serialCom, 'Parity', parityBit);
            set(LX4000.serialCom, 'StopBits', stopBits);
            set(LX4000.serialCom, 'FlowControl', flowControl);
            set(LX4000.serialCom, 'Terminator', lineTerminator);
            set(LX4000.serialCom, 'Timeout', 2);
        end
        
        function serialConnect(LX4000)
             try
                fopen(LX4000.serialCom);
             catch err
             	error('ASI_LX4000_StageAndFilterWheelController:serialConnect:comError','Cannot open the serial port "%s" to communicate with the LX-4000 X,Y,Z stage and filter wheel controller.', LX4000.serialCom.Port);
             end
        end
        
        function serialDisconnect(LX4000)
             fclose(LX4000.serialCom);
        end
        
        %MS-2000 Z stage methods
        function Zpos = whereIsZ(LX4000)
            command = LX4000.serialCommands('WHERE IS Z?');
            response = LX4000.sendSerialCommand(command);
            
            expectedResponses = LX4000.expectedSerialResponses(LX4000.serialCommands('WHERE IS Z?'));
            format = char(expectedResponses(1));
            params = LX4000.scanResponse(response, command, format, 1, 'ASI_LX4000_StageAndFilterWheelController:whereIsZ:unexpectedResponse');
            Zpos = params(1);
        end

        function haltZ(LX4000)
            LX4000.haltFlag = true;
            command = LX4000.serialCommands('HALT Z'); %Halt any current motion on the Z axis
            response = LX4000.sendSerialCommand(command);
            LX4000.checkResponse(response, command, 'ASI_LX4000_StageAndFilterWheelController:haltZ:unexpectedResponse');
        end
        
        function homeZ(LX4000)
            LX4000.haltFlag = false;
            LX4000.enableZ();
            command = LX4000.serialCommands('HOME Z'); %move Z stage to home (upper limit switch)
            response = LX4000.sendSerialCommand(command);
            LX4000.checkResponse(response, command, 'ASI_LX4000_StageAndFilterWheelController:homeZ:unexpectedResponse');
            pollUntilNotBusy(LX4000, LX4000.serialCommands('Z STAGE BUSY?'), 1, 60.0);
            if(LX4000.haltFlag)
                error('ASI_LX4000_StageAndFilterWheelController:homeZ:halt','"Home" move was halted.  The Z stage did not reach the home position.');
            end
        end
        
        function setCurrentZ(LX4000, Zpos)
            if(CheckParam.isNumeric(Zpos,'ASI_LX4000_StageAndFilterWheelController:setCurrentZ:badInputs')) %numeric input
                % TODO check value?
            end            
            
            command = LX4000.serialCommands('SET CURRENT Z STAGE POSITION');
            commandPlusArgs = [command num2str(Zpos)];
            response = LX4000.sendSerialCommand(commandPlusArgs);
            LX4000.checkResponse(response, command, 'ASI_LX4000_StageAndFilterWheelController:setCurrentZ:unexpectedResponse', commandPlusArgs);
        end
        
        function moveZ(LX4000, Zpos, numRetries)
            LX4000.haltFlag = false;
            if(~exist('numRetries','var'))
                numRetries = 3;
            else
                CheckParam.isInteger(numRetries,'ASI_LX4000_StageAndFilterWheelController:moveZ:badInputs')
                CheckParam.isWithinARange(numRetries, 1, 1000, 'ASI_LX4000_StageAndFilterWheelController:moveZ:badInputs');
            end
            LX4000.enableZ();
            if(CheckParam.isNumeric(Zpos,'ASI_LX4000_StageAndFilterWheelController:moveZ:badInputs')) %numeric input
                % TODO check value -- XXXshould not be within ~1000, maybe more, of the limit switchXXX
            end            

            command = LX4000.serialCommands('MOVE Z');
            commandPlusArgs = [command num2str(Zpos)];
            response = LX4000.sendSerialCommand(commandPlusArgs);
            %LX4000.checkResponse(response, command, 'ASI_LX4000_StageAndFilterWheelController:moveZ:unexpectedResponse', commandPlusArgs);

            pollUntilNotBusy(LX4000, LX4000.serialCommands('Z STAGE BUSY?'), 1, 60.0);

            currZpos = LX4000.whereIsZ();

            if(abs(currZpos - Zpos) > LX4000.positionTolerance)
                error('ASI_LX4000_StageAndFilterWheelController:moveY:unsuccessfulMove','Unsuccesful request to move Z to position %f.  Current position = %f', Zpos, currZpos);
            end
        end
        
        %MS-2000 XY stage methods
        
        function Xpos = whereIsX(LX4000)
            command = LX4000.serialCommands('WHERE IS X?');
            response = LX4000.sendSerialCommand(command);
            expectedResponses = LX4000.expectedSerialResponses(LX4000.serialCommands('WHERE IS X?'));
            format = char(expectedResponses(1));
            params = LX4000.scanResponse(response, command, format, 1, 'ASI_LX4000_StageAndFilterWheelController:whereIsX:unexpectedResponse');
            Xpos = params(1);
        end
        
        function Ypos = whereIsY(LX4000)
            command = LX4000.serialCommands('WHERE IS Y?');
            response = LX4000.sendSerialCommand(command);         
            expectedResponses = LX4000.expectedSerialResponses(LX4000.serialCommands('WHERE IS Y?'));
            format = char(expectedResponses(1));
            params = LX4000.scanResponse(response, command, format, 1, 'ASI_LX4000_StageAndFilterWheelController:whereIsY:unexpectedResponse');
            Ypos = params(1);
        end
        
        function haltXY(LX4000)
            LX4000.haltFlag = true;
            command = LX4000.serialCommands('HALT XY'); %Halt any current motion on the Z axis
            response = LX4000.sendSerialCommand(command);
            LX4000.checkResponse(response, command, 'ASI_LX4000_StageAndFilterWheelController:haltXY:unexpectedResponse');
        end

        function homeX(LX4000)
            LX4000.haltFlag = false;
            LX4000.enableXY();
            command = LX4000.serialCommands('HOME X'); %move X stage to home (left limit switch)
            response = LX4000.sendSerialCommand(command);
            LX4000.checkResponse(response, command, 'ASI_LX4000_StageAndFilterWheelController:homeX:unexpectedResponse');
            pollUntilNotBusy(LX4000, LX4000.serialCommands('XY STAGE BUSY?'), 1, 60.0);
            if(LX4000.haltFlag)
                error('ASI_LX4000_StageAndFilterWheelController:homeX:halt','"Home" move was halted.  The stage did not reach the home position in X.');
            end
        end
        
        function homeY(LX4000)
            LX4000.haltFlag = false;
            LX4000.enableXY();
            command = LX4000.serialCommands('HOME Y'); %move X stage to home (front limit switch)
            response = LX4000.sendSerialCommand(command);
            LX4000.checkResponse(response, command, 'ASI_LX4000_StageAndFilterWheelController:homeY:unexpectedResponse');
            pollUntilNotBusy(LX4000, LX4000.serialCommands('XY STAGE BUSY?'), 1, 60.0);
            if(LX4000.haltFlag)
                error('ASI_LX4000_StageAndFilterWheelController:homeY:halt','"Home" move was halted.  The stage did not reach the home position in Y.');
            end
        end

        function setCurrentX(LX4000, Xpos)
            if(CheckParam.isNumeric(Xpos,'ASI_LX4000_StageAndFilterWheelController:setCurrentX:badInputs')) %numeric input
                % TODO check value?
            end            
            
            command = LX4000.serialCommands('SET CURRENT X STAGE POSITION');
            commandPlusArgs = [command num2str(Xpos)];
            response = LX4000.sendSerialCommand(commandPlusArgs);
            LX4000.checkResponse(response, command, 'ASI_LX4000_StageAndFilterWheelController:setCurrentX:unexpectedResponse', commandPlusArgs);
        end
        
        function setCurrentY(LX4000, Ypos)
            if(CheckParam.isNumeric(Ypos,'ASI_LX4000_StageAndFilterWheelController:setCurrentY:badInputs')) %numeric input
                % TODO check value?
            end            
            
            command = LX4000.serialCommands('SET CURRENT Y STAGE POSITION');
            commandPlusArgs = [command num2str(Ypos)];
            response = LX4000.sendSerialCommand(commandPlusArgs);
            LX4000.checkResponse(response, command, 'ASI_LX4000_StageAndFilterWheelController:setCurrentY:unexpectedResponse', commandPlusArgs);
        end
        
        function moveX(LX4000, Xpos, numRetries)
            LX4000.haltFlag = false;
            if(~exist('numRetries','var'))
                numRetries = 3;
            else
                CheckParam.isInteger(numRetries,'ASI_LX4000_StageAndFilterWheelController:moveX:badInputs')
                CheckParam.isWithinARange(numRetries, 1, 1000, 'ASI_LX4000_StageAndFilterWheelController:moveX:badInputs');
            end
            LX4000.enableXY();
            if(CheckParam.isNumeric(Xpos,'ASI_LX4000_StageAndFilterWheelController:moveX:badInputs','Input parameter must be a numeric value')) %numeric input
                % TODO check value -- XXXshould not be within ~1000, maybe
                % more, of the limit switchXXX
            end         

            command = LX4000.serialCommands('MOVE X');
            commandPlusArgs = [command num2str(Xpos)];
            response = LX4000.sendSerialCommand(commandPlusArgs);
            %LX4000.checkResponse(response, command, 'ASI_LX4000_StageAndFilterWheelController:moveX:unexpectedResponse', commandPlusArgs);

            pollUntilNotBusy(LX4000, LX4000.serialCommands('XY STAGE BUSY?'), 1, 60.0);

            currXpos = LX4000.whereIsX();

            if(abs(currXpos - Xpos) > LX4000.positionTolerance)
                error('ASI_LX4000_StageAndFilterWheelController:moveX:unsuccessfulMove','Unsuccesful request to move X to position %f.  Current position = %f', Xpos, currXpos);
            end
        end
        
        function moveY(LX4000, Ypos, numRetries)
            LX4000.haltFlag = false;
            if(~exist('numRetries','var'))
                numRetries = 3;
            else
                CheckParam.isInteger(numRetries,'ASI_LX4000_StageAndFilterWheelController:moveY:badInputs')
                CheckParam.isWithinARange(numRetries, 1, 1000, 'ASI_LX4000_StageAndFilterWheelController:moveY:badInputs');
            end
            LX4000.enableXY();
            if(CheckParam.isNumeric(Ypos,'ASI_LX4000_StageAndFilterWheelController:moveY:badInputs','Input parameter must be a numeric value')) %numeric input
                % TODO check value -- XXXshould not be within ~1000, maybe
                % more, of the limit switchXXX
            end         

            command = LX4000.serialCommands('MOVE Y');
            commandPlusArgs = [command num2str(Ypos)];
            response = LX4000.sendSerialCommand(commandPlusArgs);
            %LX4000.checkResponse(response, command, 'ASI_LX4000_StageAndFilterWheelController:moveY:unexpectedResponse', commandPlusArgs);

            pollUntilNotBusy(LX4000, LX4000.serialCommands('XY STAGE BUSY?'), 1, 60.0);

            currYpos = LX4000.whereIsY();

            if(abs(currYpos - Ypos) > LX4000.positionTolerance)
                error('ASI_LX4000_StageAndFilterWheelController:moveY:unsuccessfulMove','Unsuccesful request to move Y to position %f.  Current position = %f', Ypos, currYpos);
            end
        end
               
        %home X, Y, and Z
        function success = homeStage(LX4000)
            success = true;
            LX4000.homeZ();
            if(~LX4000.haltFlag)
                LX4000.homeX();               
            end
            if(~LX4000.haltFlag)
                LX4000.homeY();
            else
                success = false;
            end
        end
        
        %zero the stage to the current position
        function zeroStage(LX4000)
            LX4000.setCurrentX(0);
            LX4000.setCurrentY(0);
            LX4000.setCurrentZ(0); 
        end
        
        function tf = isAboveFlowCell(LX4000, xPos, yPos)
            CheckParam.isNumeric(xPos, 'ASI_LX4000_StageAndFilterWheelController:isAboveFlowCell:badInput');
            CheckParam.isNumeric(yPos, 'ASI_LX4000_StageAndFilterWheelController:isAboveFlowCell:badInput');
            tf = false;
            if (LX4000.flowCellXmin < xPos) && (xPos < LX4000.flowCellXmax) && (LX4000.flowCellYmin < yPos) && (yPos < LX4000.flowCellYmax)
                tf = true;
            end
        end
        
        function moveToXYZ(LX4000, newPosX, newPosY, newPosZ)
            currPosX = LX4000.whereIsX();
            CheckParam.isNumeric(newPosX, 'ASI_LX4000_StageAndFilterWheelController:moveToXYZ:newPosXnotNumeric');
            CheckParam.isWithinARange(newPosX, LX4000.stageXLimitMin, LX4000.stageXLimitMax, 'ASI_LX4000_StageAndFilterWheelController:moveToXYZ:newPosXNotInRange');
            deltaX = abs(newPosX - currPosX);

            currPosY = LX4000.whereIsY();
            CheckParam.isNumeric(newPosY, 'ASI_LX4000_StageAndFilterWheelController:moveToXYZ:newPosYnotNumeric');
            CheckParam.isWithinARange(newPosY, LX4000.stageYLimitMin, LX4000.stageYLimitMax, 'ASI_LX4000_StageAndFilterWheelController:moveToXYZ:newPosYNotInRange');
            deltaY = abs(newPosY - currPosY);

            currPosZ = LX4000.whereIsZ();
            CheckParam.isNumeric(newPosZ, 'ASI_LX4000_StageAndFilterWheelController:moveToXYZ:newPosZnotNumeric');
            CheckParam.isWithinARange(newPosZ, LX4000.stageZLimitMin, LX4000.stageZLimitMax, 'ASI_LX4000_StageAndFilterWheelController:moveToXYZ:newPosZNotInRange');

            Zonly = false;
            if((deltaX<LX4000.stageSafeMoveLimit)&&(deltaY<LX4000.stageSafeMoveLimit))
                Zonly = true;
            end

            Zup = false;
            if(newPosZ > currPosZ)
                Zup = true;
            end
            
            aboveZsafe = false;
            if(newPosZ > LX4000.stageZSafePosition)
                aboveZsafe = true;
            end
                        
            moveIsAboveFlowCell = false;
            if (LX4000.isAboveFlowCell(newPosX, newPosY) && LX4000.isAboveFlowCell(currPosX, currPosY))
                moveIsAboveFlowCell = true;
            end
            
            %establish order of axes
            if(aboveZsafe)
                LX4000.moveZ(newPosZ);
                LX4000.moveX(newPosX);
                LX4000.moveY(newPosY);
            elseif(moveIsAboveFlowCell) %moves above the flow cell (e.g. imaging)
                if(Zup)  % moving up (we distinguish between these two cases [going up and going down] to avoid scraping the objective on the flowcell)
                    LX4000.moveZ(newPosZ);
                    LX4000.moveX(newPosX);
                    LX4000.moveY(newPosY);
                else % moving down
                    LX4000.moveX(newPosX);
                    LX4000.moveY(newPosY);
                    LX4000.moveZ(newPosZ);
                end
            else %below Z safe
                if(Zonly) % only significantly moving Z
                    if(Zup) %moving Z up
                        LX4000.moveZ(newPosZ);
                        LX4000.moveX(newPosX);
                        LX4000.moveY(newPosY);
                    else %moving Z down
                        LX4000.moveX(newPosX);
                        LX4000.moveY(newPosY);
                        LX4000.moveZ(newPosZ);
                    end
                else %significant componants of X and Y in the move
                    if(currPosZ < LX4000.stageZSafePosition) %if we are below the safe level, move up first
                        % move to a safe Z position for XY translation
                        LX4000.moveZ(LX4000.stageZSafePosition);
                    end
                    LX4000.moveX(newPosX);
                    LX4000.moveY(newPosY);
                    LX4000.moveZ(newPosZ);
                end
            end
        end
                
        %FW-1000 filter wheel methods

        function haltFilterWheel(LX4000)
            %halts motion on both channels
            command = LX4000.serialCommands('HALT FILTER WHEEL');
            response = LX4000.sendSerialCommand(command);
            LX4000.checkResponse(response, command, 'ASI_LX4000_StageAndFilterWheelController:haltFilterWheel:unexpectedResponse');
        end
        
        function homeFilterWheel(LX4000, whichFilterWheel)
            LX4000.selectFilterWheelChannel(whichFilterWheel);
            
            command = LX4000.serialCommands('HOME FILTER WHEEL');
            response = LX4000.sendSerialCommand(command);
            LX4000.checkResponse(response, command, 'ASI_LX4000_StageAndFilterWheelController:homeFilterWheel:unexpectedResponse');
        end
        
        function moveFilterWheel(LX4000, whichFilterWheel, position)
            if(CheckParam.isChar(whichFilterWheel,'ASI_LX4000_StageAndFilterWheelController:moveFilterWheel:badInputs'))
            	CheckParam.isInList(whichFilterWheel,{'0' '1'},'ASI_LX4000_StageAndFilterWheelController:moveFilterWheel:badInputs','Bad inputs: only filter wheel channel "0" or "1" may be selected');
            end
            
            if(CheckParam.isChar(position, 'ASI_LX4000_StageAndFilterWheelController:selectFilterWheelChannel:badInputs')) %char input
            	CheckParam.isInList(position,LX4000.filterPositions,'ASI_LX4000_StageAndFilterWheelController:selectFilterWheelChannel:badInputs','Only filter wheel positions 1-7 may be selected');
            end

            LX4000.selectFilterWheelChannel(whichFilterWheel); 
            LX4000.pollUntilNotBusy(LX4000.serialCommands('FILTER WHEEL BUSY?'), 1, 10.0);
            
            command = LX4000.serialCommands('MOVE FILTER WHEEL');
            commandPlusArgs = [command position];
            response = LX4000.sendSerialCommand(commandPlusArgs);

            if(LX4000.checkResponse(response, command, 'ASI_LX4000_StageAndFilterWheelController:moveFilterWheel:unexpectedResponse', commandPlusArgs))
                if(~strcmp(response,position))
                    error('ASI_LX4000_StageAndFilterWheelController:moveFilterWheel:didNotComply','The filter wheel on channel %s did not move!', whichFilterWheel);
                end
            end
            
            LX4000.pollUntilNotBusy(LX4000.serialCommands('FILTER WHEEL BUSY?'), 1, 10.0);
        end
        
        function position = whereIsFilterWheel(LX4000, whichFilterWheel)
            %responds with the current position of the filter wheel out of the 8 channels [0-7]
            if(CheckParam.isChar(whichFilterWheel, 'ASI_LX4000_StageAndFilterWheelController:whereIsFilterWheel:badInputs'))
            	CheckParam.isInList(whichFilterWheel,{'0' '1'},'ASI_LX4000_StageAndFilterWheelController:whereIsFilterWheel:badInputs','Bad inputs: only filter wheel channel "0" or "1" may be selected');
            end
            
            LX4000.selectFilterWheelChannel(whichFilterWheel); %the
            LX4000.pollUntilNotBusy(LX4000.serialCommands('FILTER WHEEL BUSY?'), 1, 10.0);
            
            command = LX4000.serialCommands('MOVE FILTER WHEEL'); %if we send the "move" command with no args, it returns the current position of the filter wheel
            response = LX4000.sendSerialCommand(command);
            LX4000.checkResponse(response, command, 'ASI_LX4000_StageAndFilterWheelController:whereIsFilterWheel:unexpectedResponse');

            position = response;
        end
        
    end %methods
end