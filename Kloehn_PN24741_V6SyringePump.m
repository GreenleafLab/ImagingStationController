%#########################################################################
% Kloehn_PN24741_V6SyringePump
% Serial hardware control interface with the Kloehn PN24741 8 Channel
% V6 Syringe Pump
% Written by Lauren Chircus and Curtis Layton 09/2012
%#########################################################################

classdef Kloehn_PN24741_V6SyringePump < handle
    
    properties % GENERAL PROPERTIES
        serialCom;
        statusByte = containers.Map();
        commands = containers.Map();
        stepsPeruL; %number of steps per ul
        minFlowRate;
        maxFlowRate;
        mutex; %mutually exclusive access to the serial port for multi-threaded access, true = available, false = locked
    end % END GENERAL PROPERTIES
    
    properties (Constant) % CONSTANT PROPERTIES
        volume = 250; %volume of syringe
        maxSteps = 48000; %number of syringe positions
        defaultPumpVolume = '100';
        defaultPumpFlowRate = '60';
        minPumpFlowRate = 1; %µL/min
        maxPumpFlowRate = 2000; %µL/min
        minVolume = .5; %min volume the program will allow you to push in one command
        maxVolume = 5000; %max volume the program will allow you to push in one command
        defaultPumpPosition = 7; % note: don't use a value that is excluded!
        numSerialRetries = 3; %number of times to attempt to read from a serial device.  (Hiccups occur from time to time, and re-reading is necessary.)
        serialHiccupPause = 0.3; %seconds to pause after a serial hiccup to reattempt communication
    end % END CONSTANT PROPERTIES

    methods (Access = private) % PRIVATE METHODS
        
        function response = getSerialResponse(PN24741)
            response = ''; %init
            responseByte = 0; %init
            while(responseByte ~= -1) %read until we get to the 'end of text' line terminator character
                numSerialTries = 0;
                responseByte = []; %init
                while((isempty(responseByte)) && (numSerialTries < PN24741.numSerialRetries))
                    lastwarn(''); %clear lastwarn so if we get a timeout warning we can throw a real error
                    responseByte = fread(PN24741.serialCom, 1, 'int8');
                    [warningMessage warningID] = lastwarn;
                    if(strcmp(warningID, 'MATLAB:serial:fread:unsuccessfulRead'))
                        pause on; pause(PN24741.serialHiccupPause);
                    end
                    numSerialTries = numSerialTries + 1;
                end

                [warningMessage warningID] = lastwarn;
                if(strcmp(warningID, 'MATLAB:serial:fread:unsuccessfulRead'))
                    error('Kloehn_PN24741_V6SyringePump:getSerialResponse:Timeout', 'More than the timeout limit (%f sec) passed waiting for a response from the Kloehn PN24741 V6 Syringe Pump on port "%s".', PN24741.serialCom.Timeout, PN24741.serialCom.Port);
                elseif(isempty(responseByte))
                    error('Kloehn_PN24741_V6SyringePump:getSerialResponse:Timeout', 'Trouble communicating with the Kloehn PN24741 V6 Syringe Pump on port "%s".', PN24741.serialCom.Port);
                end
                
                switch responseByte
                    case -1 % terminator character
                        break;
                    case 3 % 'end of text'
                        %do not add to the response
                    case 10 %line feed
                        %do not add to the response
                    case 13 %carriage return
                        %do not add to the response
                    case 32 %space
                        %do not add to the response
                    otherwise
                        response = [response char(responseByte)]; %otherwise add to the response
                end
            end
        end
        
        
        function response = sendSerialCommand(PN24741, command)
            CheckParam.isString(command, 'Kloehn_PN24741_V6SyringePump:sendSerialCommand:badInput');
            
            if(PN24741.mutex.tryAcquire() == true)
                try
                    fprintf(PN24741.serialCom, command);
                catch err
                    error('Kloehn_PN24741_V6SyringePump:sendSerialCommand:cannotSend','Cannot send to the Kloehn PN24741 V6 Syringe Pump through serial communication on port "%s".', PN24741.serialCom.Port);
                end
                response = PN24741.getSerialResponse();
                PN24741.mutex.release(); %release mutex lock
            else
                response = '__BLOCKED_';
            end
        end
        
        
        function status = checkResponse(PN24741, response, command, errorIdentifier)
            CheckParam.isString(response, 'Kloehn_PN24741_V6SyringePump:checkResponse:badInput');
            CheckParam.isString(command, 'Kloehn_PN24741_V6SyringePump:checkResponse:badInput');
            
            if(strcmp(response, '__BLOCKED_'))
                status = '__BLOCKED_';
            else
                if ~strcmp(response(1:2),'/0')
                    error(errorIdentifier, 'Unexpected response ("%s") received to command "%s"', response, command)
                elseif ismember(response(3),keys(PN24741.statusByte))
                    myError = PN24741.statusByte(response(3));
                    error(errorIdentifier, 'Unexpected response ("%s") received to command "%s"; error listed as "%s"',...
                        response, command, myError{2})
                elseif strcmp(response(3),'@')
                    status = 'busy';
                elseif strcmp(response(3),char(96))
                    status = 'ready';
                else
                    error(errorIdentifier, 'Unexpected response ("%s") received to command "%s"', response, command)
                end
            end
        end
        
        
        function response = getSyringePosition(PN24741, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            command = ['/1' PN24741.commands('GET SYRINGE POSITION')];
            
            response = PN24741.sendSerialCommand(command);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = PN24741.sendSerialCommand(command);
            end
            
            PN24741.checkResponse(response, command, 'Kloehn_PN24741_V6SyringePump:getSyringePosition:unexpectedResponse');
            if(~strcmp(response, '__BLOCKED_'))
                response = str2double(response(4:end));
            end
        end

    end % END PRIVATE METHODS
    
    
    
    
    methods   % PUBLIC METHODS
        
        % Constructor
        function PN24741 = Kloehn_PN24741_V6SyringePump()
            
            PN24741.commands('INITIALIZE') = 'W4';
            PN24741.commands('SET HOME') = 'W5';
            PN24741.commands('OUTPUT TO WASTE') = 'O';
            PN24741.commands('INPUT FROM FLOWCELL') = 'I';
            PN24741.commands('MOVE SYRINGE') = 'A';
            PN24741.commands('GET SYRINGE POSITION') = '?';
            PN24741.commands('SET SYRINGE SPEED') = 'V';
            
            % Fill statusByte            
            PN24741.statusByte('A') = {'busy' 'syringe failed to initialize'};
            PN24741.statusByte('a') = {'ready' 'syringe failed to initialize'};
            PN24741.statusByte('B') = {'busy' 'invalid command'};
            PN24741.statusByte('b') = {'ready' 'invalid command'};
            PN24741.statusByte('C') = {'busy' 'invalid argument; out of the allowed range of values for command'};
            PN24741.statusByte('c') = {'ready' 'invalid argument; out of the allowed range of values for command'};
            PN24741.statusByte('E') = {'busy' 'invalid "R" (run) command'};
            PN24741.statusByte('e') = {'ready' 'invalid "R" (run) command'};
            PN24741.statusByte('F') = {'busy' 'supply voltage too low'};
            PN24741.statusByte('f') = {'ready' 'supply voltage too low'};
            PN24741.statusByte('G') = {'busy' 'device not initialized'};
            PN24741.statusByte('g') = {'ready' 'device not initialized'};
            PN24741.statusByte('H') = {'busy' 'command execution in progress'};
            PN24741.statusByte('h') = {'ready' 'command execution in progress'};
            PN24741.statusByte('I') = {'busy' 'syringe overload'};
            PN24741.statusByte('i') = {'ready' 'syringe overload'};
            PN24741.statusByte('J') = {'busy' 'valve overload'};
            PN24741.statusByte('j') = {'ready' 'valve overload'};
            PN24741.statusByte('K') = {'busy' 'syringe move not allowed'};
            PN24741.statusByte('k') = {'ready' 'syringe move not allowed'};
            PN24741.statusByte('O') = {'busy' 'command buffer overflow'};
            PN24741.statusByte('o') = {'ready' 'command buffer overflow'};
            PN24741.statusByte('U') = {'busy' 'HOME not set'};
            PN24741.statusByte('u') = {'ready' 'HOME not set'};
            PN24741.statusByte('X') = {'busy' 'valve position error'};
            PN24741.statusByte('x') = {'ready' 'valve position error'};
            PN24741.statusByte('Y') = {'busy' 'syringe position corrupted'};
            PN24741.statusByte('y') = {'ready' 'syringe position corrupted'};
            PN24741.statusByte('Z') = {'busy' 'syringe may go past HOME'};
            PN24741.statusByte('z') = {'ready' 'syringe may go past HOME'};
            
            PN24741.stepsPeruL = PN24741.maxSteps/PN24741.volume; %number of steps per ul
            PN24741.minFlowRate = 60*40/PN24741.stepsPeruL;
            PN24741.maxFlowRate = 60*10000/PN24741.stepsPeruL;
            PN24741.mutex = java.util.concurrent.Semaphore(1);
            warning('off', 'MATLAB:serial:fread:unsuccessfulRead');
        end
        
        
        function setupSerialCommunication(PN24741, serialPort, baudRate, dataBits, parityBit, stopBits, flowControl, lineTerminator)
            
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
            
            PN24741.serialCom = serial(serialPort);
            set(PN24741.serialCom, 'BaudRate', baudRate);
            set(PN24741.serialCom, 'DataBits', dataBits);
            set(PN24741.serialCom, 'Parity', parityBit);
            set(PN24741.serialCom, 'StopBits', stopBits);
            set(PN24741.serialCom, 'FlowControl', flowControl);
            set(PN24741.serialCom, 'Terminator', lineTerminator);
        end
        
        
        function serialConnect(PN24741)
            try
                fopen(PN24741.serialCom);
            catch err
                error('Kloehn_PN24741_V6SyringePump:serialConnect:comError',...
                    'Cannot open the serial port "%s" to communicate with the Kloehn PN24741 V6 Syringe Pump.', PN24741.serialCom.Port);
            end
        end
        
        
        function serialDisconnect(PN24741)
            try
                fclose(PN24741.serialCom);
            catch err
                error('Kloehn_PN24741_V6SyringePump:serialDisconnect:comError',...
                    'Cannot close the serial port "%s" to communicate with the Kloehn PN24741 V6 Syringe Pump.', PN24741.serialCom.Port);
            end
        end
        
        
        function waitUntilReady(PN24741)
            status = 'busy';
            while ~strcmp(status,'ready')
                pause on; pause(.1);
                status = PN24741.queryStatus(false);
            end
        end
        
        
        % This function pumps the desired volume of fluid. If
        % the volume to pump exceeds the remaining volume in the
        % syringe, the syringe will automatically empty itself as many 
        % times as necessary.  This assumes
        % that the flow cell is connected to the NO port of the valve and
        % the waste is connected to the NC port.  At the end of pumping the
        % desired volume, the syringe will empty.
        function pump(PN24741, volume, aspFlowRate, dispFlowRate, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            % volume is in ul and speed is in ul/min
            
            if CheckParam.isNumeric(volume,'Kloehn_PN24741_V6SyringePump:aspirate:badInputs');
                CheckParam.isWithinARange(volume,PN24741.minVolume,PN24741.maxVolume,'Kloehn_PN24741_V6SyringePump:aspirate:badInputs');
            end
            if CheckParam.isNumeric(aspFlowRate,'Kloehn_PN24741_V6SyringePump:aspirate:badInputs');
                CheckParam.isWithinARange(aspFlowRate,PN24741.minFlowRate,PN24741.maxFlowRate,'Kloehn_PN24741_V6SyringePump:aspirate:badInputs');
            end
            if(~exist('dispFlowRate','var'))
                dispFlowRate = PN24741.maxFlowRate;
            elseif CheckParam.isNumeric(dispFlowRate,'Kloehn_PN24741_V6SyringePump:aspirate:badInputs');
                CheckParam.isWithinARange(dispFlowRate,PN24741.minFlowRate,PN24741.maxFlowRate,'Kloehn_PN24741_V6SyringePump:aspirate:badInputs');
            end
            
            numSteps = round(PN24741.stepsPeruL*volume); %convert volume to steps
            aspFlowRate = round(PN24741.stepsPeruL*aspFlowRate/60); %convert flow rate to steps/sec
            dispFlowRate = round(PN24741.stepsPeruL*dispFlowRate/60); %convert flow rate to steps/sec
            
            
            currentPosition = PN24741.getSyringePosition();
            if numSteps > (PN24741.maxSteps-currentPosition)
                %move to bottom position, dispense to waste, and aspirate
                %again as many times as needed
                furtherSteps = numSteps - (PN24741.maxSteps-currentPosition);
                numDispense = (furtherSteps-mod(furtherSteps,PN24741.maxSteps))/PN24741.maxSteps + 1;
                command = ['/1gV' num2str(aspFlowRate) 'IA' num2str(PN24741.maxSteps)...
                        'V' num2str(dispFlowRate) 'OA0G' num2str(numDispense) 'V' num2str(aspFlowRate) 'IA'...
                        num2str(mod(furtherSteps,PN24741.maxSteps)) 'V' num2str(dispFlowRate) 'OA0IR'];
            else
                numSteps = numSteps + currentPosition;
                command = ['/1gV' num2str(aspFlowRate) 'IA' num2str(numSteps) 'V' num2str(dispFlowRate) 'OA0IR'];
            end
            
            response = PN24741.sendSerialCommand(command);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = PN24741.sendSerialCommand(command);
            end
            
            PN24741.checkResponse(response, command, 'Kloehn_PN24741_V6SyringePump:aspirate:unexpectedResponse');
            
        end
        
        
        function initializeSyringe(PN24741, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            command = ['/1' PN24741.commands('INITIALIZE') 'R'];
            
            response = PN24741.sendSerialCommand(command);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = PN24741.sendSerialCommand(command);
            end
            
            PN24741.checkResponse(response, command, 'Kloehn_PN24741_V6SyringePump:initializePump:unexpectedResponse');
        end
        
        
        function haltSyringe(PN24741, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            command = ['/1' 'T'];
            
            response = PN24741.sendSerialCommand(command);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = PN24741.sendSerialCommand(command);
            end
            
            PN24741.checkResponse(response, command, 'Kloehn_PN24741_V6SyringePump:haltSyringe:unexpectedResponse');
        end
        
        function resetSyringe(PN24741, retryOnBlock)
            %reset the syringe to starting position, dispensing syringe
            %contents to waste.  e.g. for use after haltSyringe() leaves the
            %syringe in a mid-stroke position
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            
            PN24741.waitUntilReady();
            PN24741.closeSolenoidValve(retryOnBlock);
            PN24741.waitUntilReady();
            PN24741.setSyringeSpeed(PN24741.maxFlowRate, retryOnBlock);
            PN24741.waitUntilReady();
            PN24741.initializeSyringe(retryOnBlock);
            PN24741.waitUntilReady();
            PN24741.openSolenoidValve(retryOnBlock);
            PN24741.waitUntilReady();
        end
        
        function setSyringeSpeed(PN24741, speed, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            CheckParam.isInteger(speed,'Kloehn_PN24741_V6SyringePump:setSyringeSpeed:badInputs');
            command = ['/1' PN24741.commands('SET SYRINGE SPEED') num2str(speed)];
            
            response = PN24741.sendSerialCommand(command);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = PN24741.sendSerialCommand(command);
            end
            
            PN24741.checkResponse(response, command, 'Kloehn_PN24741_V6SyringePump:setSyringeSpeed:unexpectedResponse');
        end
        
        function response = queryStatus(PN24741, retryOnBlock) %returns 'busy' or 'ready' depending on pump status
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            command = '/1';
            
            response = PN24741.sendSerialCommand(command);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = PN24741.sendSerialCommand(command);
            end
            
            response = PN24741.checkResponse(response, command, 'Kloehn_PN24741_V6SyringePump:queryStatus:unexpectedResponse');
        end
        
        % When the flow cell is connected to the NO port of the valve and
        % a reservior is connected to the NC port, this function should
        % be used to flow buffer into the cell.  If
        % the volume to dispense exceeds the remaining volume in the
        % syringe, the syringe will automatically refill itself(draw the
        % full volume of buffer in from the reservior) as many times as
        % necessary.  At the end of pumping, the syringe will refill
        % itself.
        function pumpReverse(PN24741, volume, dispFlowRate, aspFlowRate, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            % volume is in ul and speed is in ul/min
            
            if CheckParam.isNumeric(volume,'Kloehn_PN24741_V6SyringePump:dispense:badInputs');
                CheckParam.isWithinARange(volume,PN24741.minVolume,PN24741.maxVolume,'Kloehn_PN24741_V6SyringePump:dispense:badInputs');
            end
            if CheckParam.isNumeric(aspFlowRate,'Kloehn_PN24741_V6SyringePump:dispense:badInputs');
                CheckParam.isWithinARange(aspFlowRate,PN24741.minFlowRate,PN24741.maxFlowRate,'Kloehn_PN24741_V6SyringePump:dispense:badInputs');
            end
            if CheckParam.isNumeric(dispFlowRate,'Kloehn_PN24741_V6SyringePump:dispense:badInputs');
                CheckParam.isWithinARange(dispFlowRate,PN24741.minFlowRate,PN24741.maxFlowRate,'Kloehn_PN24741_V6SyringePump:dispense:badInputs');
            end
            
            numSteps = round(PN24741.stepsPeruL*volume); %convert volume to steps
            aspFlowRate = round(PN24741.stepsPeruL*aspFlowRate/60); %convert flow rate to steps/sec
            dispFlowRate = round(PN24741.stepsPeruL*dispFlowRate/60); %convert flow rate to steps/sec
            
            currentPosition = PN24741.getSyringePosition();
            if numSteps > currentPosition
                %move to bottom position, dispense to waste, and aspirate
                %again as many times as needed
                furtherSteps = numSteps - currentPosition;
                numAspirate = (furtherSteps-mod(furtherSteps,PN24741.maxSteps))/PN24741.maxSteps + 1;
                command = ['/1gV' num2str(dispFlowRate) 'IA0V' num2str(aspFlowRate)...
                    'OA' num2str(PN24741.maxSteps) 'G' num2str(numAspirate) 'V'...
                    num2str(dispFlowRate) 'IA' num2str(PN24741.maxSteps-mod(furtherSteps,PN24741.maxSteps))...
                    'V' num2str(aspFlowRate) 'OA'  num2str(PN24741.maxSteps) 'IR'];
            else
                command = ['/1gV' num2str(dispFlowRate) 'IA' num2str(currentPosition-numSteps)...
                    'V' num2str(aspFlowRate) 'OA'  num2str(PN24741.maxSteps) 'IR'];
            end
            
            response = PN24741.sendSerialCommand(command);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = PN24741.sendSerialCommand(command);
            end
            
            PN24741.checkResponse(response, command, 'Kloehn_PN24741_V6SyringePump:dispense:unexpectedResponse');
            
        end
        
    end  % END PUBLIC METHODS
    
    
    methods % MAINTNANCE AND TEST METHODS
        
        function setHomePosition(PN24741, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            % When the pump set up has been altered, the pump must be
            % reinitialized by first using the "initializeSyringe" method
            % followed by the "setHomePosition" method
            command = ['/1' PN24741.commands('SET HOME') 'R'];
            
            response = PN24741.sendSerialCommand(command);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = PN24741.sendSerialCommand(command);
            end
            
            PN24741.checkResponse(response, command, 'Kloehn_PN24741_V6SyringePump:setHomePosition:unexpectedResponse');
        end
        
        
        function closeSolenoidValve(PN24741, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            command = ['/1' PN24741.commands('OUTPUT TO WASTE') 'R'];
            
            response = PN24741.sendSerialCommand(command);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = PN24741.sendSerialCommand(command);
            end
            
            PN24741.checkResponse(response, command, 'Kloehn_PN24741_V6SyringePump:outputToWaste:unexpectedResponse');
        end
        
        
        function openSolenoidValve(PN24741, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            command = ['/1' PN24741.commands('INPUT FROM FLOWCELL') 'R'];
            
            response = PN24741.sendSerialCommand(command);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = PN24741.sendSerialCommand(command);
            end
            
            PN24741.checkResponse(response, command, 'Kloehn_PN24741_V6SyringePump:inputFromFlowcell:unexpectedResponse');
        end
        
        
        function moveSyringe(PN24741, absPosition, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            CheckParam.isInteger(absPosition,'Kloehn_PN24741_V6SyringePump:moveSyringe:badInputs');
            command = ['/1' PN24741.commands('MOVE SYRINGE') num2str(absPosition) 'R'];
            
            response = PN24741.sendSerialCommand(command);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = PN24741.sendSerialCommand(command);
            end
            
            PN24741.checkResponse(response, command, 'Kloehn_PN24741_V6SyringePump:moveSyringe:unexpectedResponse');
        end
        
        
        function runCommand(PN24741, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            command = ['/1' 'R'];
            
            response = PN24741.sendSerialCommand(command);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = PN24741.sendSerialCommand(command);
            end
            
            PN24741.checkResponse(response, command, 'Kloehn_PN24741_V6SyringePump:runCommand:unexpectedResponse');
        end
        
    end % END MAINTNANCE AND TEST METHODS
    
end