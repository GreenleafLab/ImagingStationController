%#########################################################################
% TC_36_25_RS232_PeltierController
% Serial hardware control interface with the TE Technology TC-36-25-RS232
% Thermoelectric temperature controller.
% Written by Lauren Chircus and Curtis Layton 09/2012
%#########################################################################

classdef TC_36_25_RS232_PeltierController < handle
    
    properties % PROPERTIES
        serialCom;
        % Command Associative Arrays
        % Full commands are of the form "AACCDDDDDDDDSS" where "AA" is the
        % address of the controller (always '00'), "CC" is the command,
        % "DDDDDDDD" (hereafter referred to as "D") is the variable section
        % of the command that specifies a value (i.e. the temperature for a
        % set temp command; D is '00000000' for all read commands), and
        % "SS" is the 2 least significant digits of the hexadecimal
        % checksum of the previous 12 ASCII characters
        commands = containers.Map();
        presetDSS = containers.Map();
        expect0;
        expect1;
        expect2;
        mutex; %mutually exclusive access to the serial port for multi-threaded access, true = available, false = locked
        
        pollingLoop;
        
        temperatureHistory;
        
        rampRate;
        rampDestinationTemperature;
        temporaryIntegralGain;
        temporaryTemp;
        temporaryDerivativeGain;
        goingUp;
    end % END PROPERTIES
    
    properties (Constant) % CONSTANT PROPERTIES
        resolution = 0.2;
        tolerance = 0.4; %when the current temp gets within this tolerance, we say that it has arrived at the setTemp
        window = 3; %current temp must remain within tolerance of the setTemp for this window of time (in s) to be considered to have arrived at the setTemp
        numSerialRetries = 3; %number of times to attempt to read from a serial device.  (Hiccups occur from time to time, and re-reading is necessary.)
        serialHiccupPause = 0.3; %seconds to pause after a serial hiccup to reattempt communication
    end % CONSTANT PROPERTIES
    
    methods (Access = private) % PRIVATE METHODS
        
       
        % get response from controller; adapted from Curtis
        function response = getSerialResponse(TC3625)
            response = ''; %init
            responseByte = 0; %init
            while(responseByte ~= 94) %read until we get to the '^' line terminator character
                numSerialTries = 0;
                responseByte = []; %init
                while((isempty(responseByte)) && (numSerialTries < TC3625.numSerialRetries))
                    lastwarn(''); %clear lastwarn so if we get a timeout warning we can throw a real error
                    responseByte = fread(TC3625.serialCom, 1, 'int8');
                    [warningMessage warningID] = lastwarn;
                    if(strcmp(warningID, 'MATLAB:serial:fread:unsuccessfulRead'))
                        pause on; pause(TC3625.serialHiccupPause);
                    end
                    numSerialTries = numSerialTries + 1;
                end
                
                [warningMessage warningID] = lastwarn;
                if(strcmp(warningID, 'MATLAB:serial:fread:unsuccessfulRead'))
                    error('TC_36_25_RS232_PeltierController:getSerialResponse:Timeout',...
                        'More than the timeout limit (%f sec) passed waiting for a response from the TC-36-25 Thermoelectric Cooler/Temperature Controller on port "%s".',...
                        TC3625.serialCom.Timeout, TC3625.serialCom.Port);
                elseif(isempty(responseByte))
                    error('TC_36_25_RS232_PeltierController:getSerialResponse:comError',...
                        'Trouble communicating with the TC-36-25 Thermoelectric Cooler/Temperature Controller on port "%s"', TC3625.serialCom.Port);
                end

                switch responseByte
                    case 94 %'^' terminator character
                        break;
                    case 10 %line feed
                        %do not add to the response
                    case 13 %carriage return
                        %do not add to the response
                    case 42 %*
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
        
        % Send serial command to controller
        function response = sendSerialCommand(TC3625, command, setValue)
            CheckParam.isString(command, 'TC_36_25_RS232_PeltierController:sendSerialCommand:badInputs');

            command = TC3625.makeCommand(command, setValue);

            if(TC3625.mutex.tryAcquire() == true)
                try
                    fprintf(TC3625.serialCom, command);
                catch err
                    error('TC_36_25_RS232_PeltierController:sendSerialCommand:cannotSend',...
                          'Cannot send to the TC-36-25 RS232 Thermoelectric Cooler/Temperature Controller through serial communication on port "%s".', TC3625.serialCom.Port);
                end
                response = TC3625.getSerialResponse();

                TC3625.mutex.release(); %release mutex lock
            else
                response = '__BLOCKED_';
            end
        end
       
        % used to calculate hexadecimal sum of charcters in ASCII string
        function myhexsum = hexsum(TC3625, ASCIIstring)
            if(CheckParam.isString(ASCIIstring, 'TC_36_25_RS232_PeltierController:hexsum:badInputs'))
                if (~(length(ASCIIstring)==12))
                    error('TC_36_25_RS232_PeltierController:hexsum:badInputs','Input parameter must be a string value with length 12');
                end
            end
            
            decimalString = sprintf('%u ', ASCIIstring);
            decimalArray = str2num(decimalString);
            myhexsum = sprintf('%x',sum(decimalArray));
        end

        %used to convert a hex value to a binary vector of bits
        function binaryValue = hex2binary(TC3625, hexString)
            if(CheckParam.isString(hexString, 'TC_36_25_RS232_PeltierController:hexsum:badInputs'))
                if (~(length(hexString)==8))
                    error('TC_36_25_RS232_PeltierController:hexsum:badInputs','Input parameter must be a string value with length 12');
                end
            end
            
            decimalValue = hex2dec(hexString);
            binaryValue = dec2bin(decimalValue);
        end
        
        function confirm = checkResponse(TC3625, response, expectedResponses, command, errorIdentifier)
            CheckParam.isString(response, 'TC_36_25_RS232_PeltierController:checkResponse:badInput');
            CheckParam.isCellArrayOfStrings(expectedResponses, 'TC_36_25_RS232_PeltierController:checkResponse:badInput');
            CheckParam.isString(command, 'TC_36_25_RS232_PeltierController:checkResponse:badInput');
            
            if(strcmp(response, '__BLOCKED_'))
                confirm = '__BLOCKED_';
            else
                try
                    errorMessage = sprintf('Unexpected response ("%s") received to command "%s"', response, command);
                    CheckParam.isInList(response,expectedResponses,errorIdentifier,errorMessage);
                catch err
                    throwAsCaller(err);
                end

                confirm = true;
            end
        end
        
        % Function to create commands
        function command = makeCommand(TC3625, textcommand, setValue)
            CheckParam.isString(textcommand, 'TC_36_25_RS232_PeltierController:makeCommand:badInputs');
            
            % check if there's a presetDSS, if so concatenate to make command
            if ismember(textcommand,keys(TC3625.presetDSS))
                command = strcat(TC3625.commands(textcommand),TC3625.presetDSS(textcommand));

            elseif ismember(textcommand,{'SET ALARM SENSOR', 'READ ALARM SENSOR', 'SET ALARM TYPE', 'READ ALARM TYPE'})
                % some commands that select from a short finite list (e.g. select item 0, 1, or 2)
                % do not require conversion of the setValue to hex.  We
                % construct the command, then compute the checksum
                if(CheckParam.isInteger(setValue, 'TC_36_25_RS232_PeltierController:makeCommand:badInputs'))
                    CheckParam.isWithinARange(setValue,0,99999999,'TC_36_25_RS232_PeltierController:makeCommand:badInputs');
                end
                ASCIIcommand = TC3625.commands(textcommand);
                ASCIIcommand = ASCIIcommand(2:end); %strip initial *
                zeroString = '00000000';
                paramValue = zeroString;
                if(setValue~=0)
                    numString = sprintf('%d',setValue);
                    paramValue = strcat(zeroString(1:end-(1+floor(log10(setValue)))), numString);
                end
                command = strcat(ASCIIcommand, paramValue);
                SS = TC3625.hexsum(command);
                SS = SS(end-1:end);
                command = strcat('*',command,SS);
            else
                % commands with a numerical setValue (e.g. set temp to 25.5°C) require
                % translation of the setValue to hexadecimal.  We then construct the 12
                % character command, and compute the checksum
                CheckParam.isNumeric(setValue, 'TC_36_25_RS232_PeltierController:makeCommand:badInputs');
                %Added by Johan: if dec2hex fails for negative values
                if (setValue<0)
                   D = lower(dec2hex(round(setValue.*100)+hex2dec('ffffffff'), 8));
                %end Added by Johan
                else
                    D = lower(dec2hex(round(setValue.*100),8));
                end
                ASCIIcommand = TC3625.commands(textcommand);
                ASCIIcommand = ASCIIcommand(2:end); %strip initial *
                command = strcat(ASCIIcommand,D);
                SS = TC3625.hexsum(command);
                SS = SS(end-1:end);
                command = strcat('*',command,SS);
            end
        end
        
        % reads the character string response from the controller and tells
        % you what it means
        function response = interpretResponse(TC3625, ASCIIstringResponse, textcommand)
            if(CheckParam.isString(ASCIIstringResponse, 'TC_36_25_RS232_PeltierController:interpretResponse:badInputs'))
                if (~(length(ASCIIstringResponse)==10))
                    error('TC_36_25_RS232_PeltierController:interpretResponse:badInputs',...
                          'Input parameter must be a string value with length 10');
                end
            end
            
            % controller returns 'XXXXXXXXc0' when the checksum is incorrect
            if(strcmp(ASCIIstringResponse, '__BLOCKED_'))
                response = '__BLOCKED_';
            elseif strcmpi(ASCIIstringResponse,'XXXXXXXXc0')
                error('TC_36_25_RS232_PeltierController:interpretResponse:badCommand',...
                    'TC-36-25 RS232 Thermoelectric Cooler/Temperature Controller did not accept command because the checksum was incorrect')
            elseif ismember(textcommand,{'READ CURRENT TEMP', 'READ CURRENT TEMP2', 'SET TEMP',...
                    'SET ALARM DEADBAND', 'READ ALARM DEADBAND',...
                    'SET HIGH ALARM', 'READ HIGH ALARM', 'SET LOW ALARM', 'READ LOW ALARM',...
                    'SET HEAT MULTIPLIER', 'READ HEAT MULTIPLIER',...
                    'SET COOL MULTIPLIER', 'READ COOL MULTIPLIER',...
                    'READ SET TEMP', 'SET PROPORTIONAL BANDWITH',...
                    'READ PROPORTIONAL BANDWITH', 'SET INTEGRAL GAIN',...
                    'READ INTEGRAL GAIN', 'SET DERIVATIVE GAIN', 'READ DERIVATIVE GAIN'})
                response = hex2dec(ASCIIstringResponse(1:end-2))./100;
            elseif ismember(textcommand,{'SET ALARM SENSOR', 'READ ALARM SENSOR', 'SET ALARM TYPE', 'READ ALARM TYPE'})
                response = str2double(ASCIIstringResponse(5:end-2));
            %elseif ismember(textcommand,{'SET OUTPUT POWER'})
            %    response = hex2dec(ASCIIstringResponse(1:end-2))
            elseif ismember(textcommand,{'READ OUTPUT POWER','SET OUTPUT POWER'})
                %response = hex2dec(ASCIIstringResponse(1:end-2))/5.11;
                response = hex2dec(ASCIIstringResponse(1:end-2));
                maxresponse=hex2dec('ffffffff');
                if (response>maxresponse/2)
                    response=response-maxresponse;
                end
                response=response/100; %Max is 5.11, min is -5.10. Scale appropriately if you want percentages
            else
                response = ASCIIstringResponse(1:end-2);
            end
        end
                        
        function updateRampTemperature(TC3625, args)
            try
                if(TC3625.isCurrentlyRamping())
                    currPollingLoopListItem = TC3625.pollingLoop.pollingLoopList('updateRampTemperature');
                    elapsedTime = currPollingLoopListItem.getElapsedTime()/60;
                    totalDeltaTemp = args.destinationTemperature - args.startTemperature;
                    totalDeltaTime = abs(totalDeltaTemp)/args.rampRate;

                    if(elapsedTime > totalDeltaTime) %if we are past the calculated time for the ramp at the specified rate
                        setTemp = TC3625.setTemp(args.destinationTemperature, false); %set the temp to exactly the destination temp
                        if(~strcmp(setTemp,'__BLOCKED_'))
                            if(TC3625.pollingLoop.isInPollingList('updateRampTemperature'))
                                TC3625.pollingLoop.removeFromPollingLoop('updateRampTemperature'); %and remove the completed ramp from the polling list
                            end
                        end
                    else
                        currDeltaTemp = (elapsedTime/totalDeltaTime)*totalDeltaTemp;
                        currSetTemp = args.startTemperature + currDeltaTemp;
                        setTemp = TC3625.setTemp(currSetTemp, false, true);
                    end
                end
            catch err
                if(~strcmp(err.identifier, 'TC_36_25_RS232_PeltierController:getSerialResponse:Timeout'))
                    rethrow(err);
                end
            end
        end

        function updateTemperatureHistory(TC3625, args)
            %update the temperature history with the current timepoint
            currPollingLoopListItem = TC3625.pollingLoop.pollingLoopList('updateTemperatureHistory');
            
            %get elapsed time since starting the temperature history
            elapsedTime = currPollingLoopListItem.getElapsedTime();

            try
                %update the temperature history
                if(isempty(TC3625.temperatureHistory))
                        tempIndex = 0;
                        TC3625.temperatureHistory.temp(1) = -99; %init
                        temp2Index = 0;
                        TC3625.temperatureHistory.temp2(1) = -99; %init
                        outputPowerIndex = 0;
                        TC3625.temperatureHistory.outputPower(1) = -99; %init
                        setTempIndex = 0;
                        TC3625.temperatureHistory.setTemp(1) = -99; %init
                        timeIndex = 0;
                        TC3625.temperatureHistory.time(1) = -99; %init
                else
                        tempIndex = length(TC3625.temperatureHistory.temp);
                        outputPowerIndex = length(TC3625.temperatureHistory.outputPower);
                        temp2Index = length(TC3625.temperatureHistory.temp2);
                        setTempIndex = length(TC3625.temperatureHistory.setTemp);
                        timeIndex = length(TC3625.temperatureHistory.time);
                end
                                              
                currTemp = TC3625.getCurrentTemp(false);
                if(~strcmp(currTemp,'__BLOCKED_'))
                    TC3625.temperatureHistory.temp(tempIndex+1) = currTemp;
                else
                    TC3625.temperatureHistory.temp(tempIndex+1) = 0;
                end
                               
                currTemp2 = TC3625.getCurrentTemp2(false);
                if(~strcmp(currTemp2,'__BLOCKED_'))
                    TC3625.temperatureHistory.temp2(temp2Index+1) = currTemp2;
                else
                    TC3625.temperatureHistory.temp2(temp2Index+1) = 0;
                end
                
                currOutputPower = TC3625.getOutputPower(false);
                if(~strcmp(currOutputPower,'__BLOCKED_'))
                    TC3625.temperatureHistory.outputPower(outputPowerIndex+1) = currOutputPower;
                else
                    TC3625.temperatureHistory.outputPower(outputPowerIndex+1) = 0;
                end    
                    
                currSetTemp=TC3625.getSetTemp(false);
                if(~strcmp(currSetTemp,'__BLOCKED_'))
                    TC3625.temperatureHistory.setTemp(setTempIndex+1) = currSetTemp;
                else
                    TC3625.temperatureHistory.setTemp(setTempIndex+1) = 0;
                end   
                
                
                TC3625.temperatureHistory.time(timeIndex+1) = elapsedTime;
                %disp(['TC_36_25_RS232_PeltierController:updateTemperatureHistory: ', num2str(elapsedTime)])
            catch err
                disp(['Error: TC_36_25_RS232_PeltierController:updateTemperatureHistory: ', err.identifier])
                if(~strcmp(err.identifier, 'TC_36_25_RS232_PeltierController:getSerialResponse:Timeout'))
                    rethrow(err);
                end
            end
        end
        
        
    end % END PRIVATE METHODS
    
    
    methods % PUBLIC METHODS
        
        % Contructor method to create controller object
        function TC3625 = TC_36_25_RS232_PeltierController()
            % Fill command associative array with the commands and another
            % with pre-calculated responses
            
            % Turn on and off
            TC3625.commands('TURN ON') = '*002d';
            TC3625.presetDSS('TURN ON') = '0000000177';
            
            TC3625.commands('TURN OFF') = '*002d';
            TC3625.presetDSS('TURN OFF') = '0000000076';
            
            TC3625.commands('READ ON/OFF') = '*0046';
            TC3625.presetDSS('READ ON/OFF') = '000000004a';
            
            % Change temp control type
            TC3625.commands('DEADBAND CONTROL') = '*002b';
            TC3625.presetDSS('DEADBAND CONTROL') = '0000000074';
            
            TC3625.commands('PID CONTROL') = '*002b';
            TC3625.presetDSS('PID CONTROL') = '0000000175';
            
            % Control type Computer Control %Bojan and Johan Oct 2013
            TC3625.commands('COMPUTER CONTROL') = '*002b';
            TC3625.presetDSS('COMPUTER CONTROL') = '0000000276';
            
            TC3625.commands('READ CONTROL TYPE') = '*0044';
            TC3625.presetDSS('READ CONTROL TYPE') = '0000000048';
           
            % Change units
            TC3625.commands('SET UNITS TO F') = '*0032';
            TC3625.presetDSS('SET UNITS TO F') = '0000000045';
            
            TC3625.commands('SET UNITS TO C') = '*0032';
            TC3625.presetDSS('SET UNITS TO C') = '0000000146';
            
            TC3625.commands('READ UNITS') = '*004b';
            TC3625.presetDSS('READ UNITS') = '0000000076';
            
            % Temperature settings
            TC3625.commands('READ CURRENT TEMP') = '*0001';
            TC3625.presetDSS('READ CURRENT TEMP') = '0000000041';
            
            TC3625.commands('READ SET TEMP') = '*0050';
            TC3625.presetDSS('READ SET TEMP') = '0000000045';
            
            TC3625.commands('SET TEMP') = '*001c';
            
            % Temperature settings Input2 %Bojan and Johan Oct 2013
            TC3625.commands('READ CURRENT TEMP2') = '*0006';
            TC3625.presetDSS('READ CURRENT TEMP2') = '0000000046';
            
            % Power Output %Bojan and Johan Oct 2013
            TC3625.commands('SET OUTPUT POWER') = '*001c';   %Same command as 'SET TEMP'
            
            TC3625.commands('READ OUTPUT POWER') = '*0002';
            TC3625.presetDSS('READ OUTPUT POWER') = '0000000042';
            
            % Proportional bandwidth settings
            TC3625.commands('READ PROPORTIONAL BANDWITH') = '*0051';
            TC3625.presetDSS('READ PROPORTIONAL BANDWITH') = '0000000046';
            
            TC3625.commands('SET PROPORTIONAL BANDWITH') = '*001d';
            
            % Integral gain settings
            TC3625.commands('READ INTEGRAL GAIN') = '*0052';
            TC3625.presetDSS('READ INTEGRAL GAIN') = '0000000047';
            
            TC3625.commands('SET INTEGRAL GAIN') = '*001e';
            
            % Derivative gain settings
            TC3625.commands('READ DERIVATIVE GAIN') = '*0053';
            TC3625.presetDSS('READ DERIVATIVE GAIN') = '0000000048';
            
            TC3625.commands('SET DERIVATIVE GAIN') = '*001f';
            
            % Alarm settings
            TC3625.commands('SET HIGH ALARM') = '*0023';

            TC3625.commands('READ HIGH ALARM') = '*0057';
            TC3625.presetDSS('READ HIGH ALARM') = '000000004c';
            
            TC3625.commands('SET LOW ALARM') = '*0024';
            
            TC3625.commands('READ LOW ALARM') = '*0058';
            TC3625.presetDSS('READ LOW ALARM') = '000000004d';
            
            TC3625.commands('SHUTDOWN IF ALARM ON') = '*002e';
            TC3625.presetDSS('SHUTDOWN IF ALARM ON') = '0000000178';
            
            TC3625.commands('SHUTDOWN IF ALARM OFF') = '*002e';
            TC3625.presetDSS('SHUTDOWN IF ALARM OFF') = '0000000077';
            
            TC3625.commands('READ SHUTDOWN IF ALARM') = '*0047';
            TC3625.presetDSS('READ SHUTDOWN IF ALARM') = '000000004b';
            
            TC3625.commands('ALARM LATCH ON') = '*002f';
            TC3625.presetDSS('ALARM LATCH ON') = '0000000179';
            
            TC3625.commands('ALARM LATCH OFF') = '*002f';
            TC3625.presetDSS('ALARM LATCH OFF') = '0000000078';
            
            TC3625.commands('READ ALARM LATCH') = '*0048';
            TC3625.presetDSS('READ ALARM LATCH') = '000000004c';
            
            TC3625.commands('ALARM RESET') = '*0033';
            TC3625.presetDSS('ALARM RESET') = '0000000046';
            
            TC3625.commands('READ ALARM STATE') = '*0005';
            TC3625.presetDSS('READ ALARM STATE') = '0000000045';
            
            % Heat/Cool multiplier
            TC3625.commands('SET HEAT MULTIPLIER') = '*000c';
            
            TC3625.commands('READ HEAT MULTIPLIER') = '*005c';
            TC3625.presetDSS('READ HEAT MULTIPLIER') = '0000000078';
            
            TC3625.commands('SET COOL MULTIPLIER') = '*000d';
            
            TC3625.commands('READ COOL MULTIPLIER') = '*005d';
            TC3625.presetDSS('READ COOL MULTIPLIER') = '0000000079';

            TC3625.commands('SET ALARM SENSOR') = '*0031';
            
            TC3625.commands('READ ALARM SENSOR') = '*004a';
            TC3625.presetDSS('READ ALARM SENSOR') = '0000000075';
            
            TC3625.commands('SET ALARM TYPE') = '*0028';
            
            TC3625.commands('READ ALARM TYPE') = '*0041';
            TC3625.presetDSS('READ ALARM TYPE') = '0000000045';
            
            TC3625.commands('SET ALARM DEADBAND') = '*0022';
            
            TC3625.commands('READ ALARM DEADBAND') = '*0056';
            TC3625.presetDSS('READ ALARM DEADBAND') = '000000004b';
            
            % Expected serial responses if the commands are 1 or 0
            TC3625.expect2 = '0000000282';
            TC3625.expect1 = '0000000181';
            TC3625.expect0 = '0000000080';
            
            TC3625.rampRate = 2;
            
            TC3625.mutex = java.util.concurrent.Semaphore(1);
            TC3625.pollingLoop = PollingLoop();
            
            %start temperature history graph updates
            TC3625.pollingLoop.addToPollingLoop(@TC3625.updateTemperatureHistory, {}, 'updateTemperatureHistory', 2);
            warning('off', 'MATLAB:serial:fread:unsuccessfulRead');
        end
        
        function stopPollingLoop(TC3625)
            TC3625.pollingLoop.stopPollingLoop();
        end
        
        function setupSerialCommunication(TC3625, serialPort, baudRate, dataBits, parityBit, stopBits, flowControl, lineTerminator)
            
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
            
            TC3625.serialCom = serial(serialPort);
            set(TC3625.serialCom, 'BaudRate', baudRate);
            set(TC3625.serialCom, 'DataBits', dataBits);
            set(TC3625.serialCom, 'Parity', parityBit);
            set(TC3625.serialCom, 'StopBits', stopBits);
            set(TC3625.serialCom, 'FlowControl', flowControl);
            set(TC3625.serialCom, 'Terminator', lineTerminator);
            set(TC3625.serialCom, 'Timeout', 2);
        end

        % Open serial port
        function serialConnect(TC3625)
            try
                fopen(TC3625.serialCom);
            catch err
                error('TC_36_25_RS232_PeltierController:serialConnect:cannotConnect','Cannot open the serial port "%s" to communicate with the  TC-36-25 RS232 Thermoelectric Cooler/Temperature Controller.', TC3625.serialCom.Port);
            end
        end
        
        
        % Close serial port
        function serialDisconnect(TC3625)
            try
                fclose(TC3625.serialCom);
            catch err
                error('TC_36_25_RS232_PeltierController:close:cannotClose','Cannot close the serial port "%s" to communicate with the TC-36-25 RS232 Thermoelectric Cooler/Temperature Controller.', TC3625.serialCom.Port);
            end
        end
        
        
        % turn on and off
        function turnOn(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('TURN ON',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('TURN ON',0);
            end
            TC3625.checkResponse(response, {TC3625.expect1}, 'TURN ON', 'TC_36_25_RS232_PeltierController:turnOn:unexpectedResponse');
        end
        
        function turnOff(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('TURN OFF',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('TURN OFF',0);
            end
            TC3625.checkResponse(response, {TC3625.expect0}, 'TURN OFF', 'TC_36_25_RS232_PeltierController:turnOff:unexpectedResponse');
        end
        
        function onOff = getOnOff(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('READ ON/OFF',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('READ ON/OFF',0);
            end
            TC3625.checkResponse(response, {TC3625.expect0, TC3625.expect1}, 'READ ON/OFF', 'TC_36_25_RS232_PeltierController:getOnOff:unexpectedResponse');
            if(strcmp(response, TC3625.expect0))
                onOff = false;
            else
                onOff = true;
            end
        end
        
        %output shutdown if alarm on and off
        %kills output power to the peltier if an alarm is triggered
        %(e.g. over temperature alarm)
        function shutdownIfAlarmOn(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('SHUTDOWN IF ALARM ON',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('SHUTDOWN IF ALARM ON',0);
            end
            TC3625.checkResponse(response, {TC3625.expect1}, 'SHUTDOWN IF ALARM ON', 'TC_36_25_RS232_PeltierController:shutdownIfAlarmOn:unexpectedResponse');
        end
        
        function shutdownIfAlarmOff(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('SHUTDOWN IF ALARM OFF',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('SHUTDOWN IF ALARM OFF',0);
            end
            TC3625.checkResponse(response, {TC3625.expect0}, 'SHUTDOWN IF ALARM OFF', 'TC_36_25_RS232_PeltierController:shutdownIfAlarmOff:unexpectedResponse');
        end

        function shutdownIfAlarm = getShutdownIfAlarm(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('READ SHUTDOWN IF ALARM',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('READ SHUTDOWN IF ALARM',0);
            end
            TC3625.checkResponse(response, {TC3625.expect0, TC3625.expect1}, 'READ SHUTDOWN IF ALARM', 'TC_36_25_RS232_PeltierController:getShutdownIfAlarm:unexpectedResponse');
            if(strcmp(response, TC3625.expect0))
                shutdownIfAlarm = false;
            else
                shutdownIfAlarm = true;
            end
        end
        
        %if the alarm latch is on, the controller will maintain the alarm condition until it is manually cleared
        function alarmLatchOn(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('ALARM LATCH ON',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('ALARM LATCH ON',0);
            end
            TC3625.checkResponse(response, {TC3625.expect1}, 'ALARM LATCH ON', 'TC_36_25_RS232_PeltierController:alarmLatchOn:unexpectedResponse');
        end
        
        %if the alarm latch is off, the controller will automatically reset to a non?alarm state if the alarm condition self?corrects
        function alarmLatchOff(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('ALARM LATCH OFF',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('ALARM LATCH OFF',0);
            end
            TC3625.checkResponse(response, {TC3625.expect0}, 'ALARM LATCH OFF', 'TC_36_25_RS232_PeltierController:alarmLatchOff:unexpectedResponse');
         end      
         
        function alarmLatch = getAlarmLatch(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('READ ALARM LATCH',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('READ ALARM LATCH',0);
            end
            TC3625.checkResponse(response, {TC3625.expect0, TC3625.expect1}, 'READ ALARM LATCH', 'TC_36_25_RS232_PeltierController:getAlarmLatch:unexpectedResponse');
            if(strcmp(response, TC3625.expect0))
                alarmLatch = false;
            else
                alarmLatch = true;
            end
        end
        
        %manually reset alarm condition
        function resetAlarm(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('ALARM RESET',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('ALARM RESET',0);
            end
            TC3625.checkResponse(response, {TC3625.expect0}, 'ALARM RESET', 'TC_36_25_RS232_PeltierController:resetAlarm:unexpectedResponse');
        end

        function alarmStatus = getAlarmStatus(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('READ ALARM STATE',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('READ ALARM STATE',0);
            end
            
            if(~strcmp(response, '__BLOCKED_'))
                %convert hex response to binary
                binaryValue = TC3625.hex2binary(response(1:end-2));

                %interpret binary response bit by bit
                binaryVectorSize = length(binaryValue);

                errorString = '';
                if (binaryVectorSize >= 1) && (binaryValue(end) == '1')
                    % bit0 - HIGH ALARM
                    if(~strcmp(errorString, ''))
                        errorString = strcat(errorString, ', ');
                    end
                    errorString = strcat(errorString, 'OVER HIGH TEMPERATURE ALARM');
                end

                if (binaryVectorSize >= 2) && (binaryValue(end-1) == '1')
                    % bit1 - LOW ALARM
                    if(~strcmp(errorString, ''))
                        errorString = strcat(errorString, ', ');
                    end
                    errorString = strcat(errorString, 'UNDER LOW TEMPERATURE ALARM');
                end

                if (binaryVectorSize >= 3) && (binaryValue(end-2) == '1')
                    % bit2 - COMPUTER CONTROLLED ALARM
                    if(~strcmp(errorString, ''))
                        errorString = strcat(errorString, ', ');
                    end
                    errorString = strcat(errorString, 'COMPUTER CONTROLLED ALARM');
                end

                if (binaryVectorSize >= 4) && (binaryValue(end-3) == '1')
                    % bit3 - OVER CURRENT DETECTED
                    if(~strcmp(errorString, ''))
                        errorString = strcat(errorString, ', ');
                    end
                    errorString = strcat(errorString, 'OVER CURRENT DETECTED');
                end

                if (binaryVectorSize >= 5) && (binaryValue(end-4) == '1')
                    % bit4 - OPEN INPUT1
                    if(~strcmp(errorString, ''))
                        errorString = strcat(errorString, ', ');
                    end
                    errorString = strcat(errorString, 'INPUT1 OPEN');
                end

                if (binaryVectorSize >= 6) && (binaryValue(end-5) == '1')
                    % bit5 - OPEN INPUT2
                    if(~strcmp(errorString, ''))
                        errorString = strcat(errorString, ', ');
                    end
                    errorString = strcat(errorString, 'INPUT2 OPEN');
                end

                if (binaryVectorSize >= 7) && (binaryValue(end-6) == '1')
                    % bit6 - DRIVER LOW INPUT VOLTAGE
                    if(~strcmp(errorString, ''))
                        errorString = strcat(errorString, ', ');
                    end
                    errorString = strcat(errorString, 'DRIVER LOW INPUT VOLTAGE');
                end

                if(~strcmp(errorString, ''))
                    error('TC_36_25_RS232_PeltierController:getAlarmStatus:hardwareError',...
                                'Hardware error(s) received from the TE Technology TC-36-25 peltier controller: [%s]', ...
                                errorString);
                end
                alarmStatus = binaryValue;
            else
                alarmStatus = response;
            end
        end
         
        %specify which sensor the alarm looks at to determine alarms
        %e.g. over temperature alarm
        function setAlarmSensor(TC3625, whichSensor, retryOnBlock)
            if(CheckParam.isInteger(whichSensor, 'TC_36_25_RS232_PeltierController:setAlarmSensor:badInputs'))
                CheckParam.isWithinARange(whichSensor,0,1,'TC_36_25_RS232_PeltierController:setAlarmSensor:badInputs');
            end
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('SET ALARM SENSOR',whichSensor);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('SET ALARM SENSOR',whichSensor);
            end
            response = TC3625.interpretResponse(response, 'SET ALARM SENSOR');
            if(~strcmp(response, '__BLOCKED_'))
                if (response ~= whichSensor)
                    error('TC_36_25_RS232_PeltierController:setAlarmSensor:unexpectedResponse',...
                        'Unexpected response ("%d") received to command "%s", does not equal setValue ("%d")', ...
                        response, 'SET ALARM SENSOR', whichSensor)
                end
            end
        end
            
        function whichAlarmSensor = getAlarmSensor(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('READ ALARM SENSOR',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('READ ALARM SENSOR',0);
            end
            whichAlarmSensor = TC3625.interpretResponse(response, 'READ ALARM SENSOR');
        end
            
        %set the alarm type:
        %0: alarm off
        %1: tracking alarm (alarm based on a delta from the set temp)
        %2: fixed alarm (alarm based on absolute temperature points)
        %3: computer-controlled alarm
        function setAlarmType(TC3625, setValue, retryOnBlock)
            if(CheckParam.isInteger(setValue, 'TC_36_25_RS232_PeltierController:setAlarmType:badInputs'))
                CheckParam.isWithinARange(setValue,0,3,'TC_36_25_RS232_PeltierController:setAlarmType:badInputs');
            end
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('SET ALARM TYPE',setValue);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('SET ALARM TYPE',setValue);
            end
            response = TC3625.interpretResponse(response, 'SET ALARM TYPE');
            if(~strcmp(response, '__BLOCKED_'))
                if (response ~= setValue)
                    error('TC_36_25_RS232_PeltierController:setAlarmType:unexpectedResponse',...
                        'Unexpected response ("%d") received to command "%s", does not equal setValue ("%d")', ...
                        response, 'SET ALARM TYPE', setValue)
                end
            end
        end
        
        %get the currently set alarm type
        %0: alarm off
        %1: tracking alarm (alarm based on a delta from the set temp)
        %2: fixed alarm (alarm based on absolute temperature points)
        %3: computer-controlled alarm
        function alarmType = getAlarmType(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('READ ALARM TYPE',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('READ ALARM TYPE',0);
            end
            
            alarmType = TC3625.interpretResponse(response, 'READ ALARM TYPE');
        end
       
        function setAlarmDeadband(TC3625, setValue, retryOnBlock)
            if(CheckParam.isNumeric(setValue, 'TC_36_25_RS232_PeltierController:setAlarmDeadband:badInputs'))
                CheckParam.isWithinARange(setValue,0.1,100,'TC_36_25_RS232_PeltierController:setAlarmDeadband:badInputs');
            end
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('SET ALARM DEADBAND',setValue);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('SET ALARM DEADBAND',setValue);
            end
            response = TC3625.interpretResponse(response, 'SET ALARM DEADBAND');
            if(~strcmp(response, '__BLOCKED_'))
                if round(response*100) ~= round(setValue*100)
                    error('TC_36_25_RS232_PeltierController:setAlarmDeadband:unexpectedResponse',...
                        'Unexpected response ("%s") received to command "%s", does not equal setValue ("%s")', ...
                        response, 'SET ALARM DEADBAND', setValue)
                end
            end
        end
        
        function alarmDeadband = getAlarmDeadband(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('READ ALARM DEADBAND',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('READ ALARM DEADBAND',0);
            end
            
            alarmDeadband = TC3625.interpretResponse(response, 'READ ALARM DEADBAND');
        end
        
        % control types
        function deadbandControl(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('DEADBAND CONTROL',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('DEADBAND CONTROL',0);
            end
            TC3625.checkResponse(response, {TC3625.expect0}, 'DEADBAND CONTROL', 'TC_36_25_RS232_PeltierController:deadbandControl:unexpectedResponse');
        end
        
        function PIDControl(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('PID CONTROL',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('PID CONTROL',0);
            end
            TC3625.checkResponse(response, {TC3625.expect1}, 'PID CONTROL', 'TC_36_25_RS232_PeltierController:PIDControl:unexpectedResponse');
        end
        %Added by Johan and Bojan, Oct 2013
        function computerControl(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('COMPUTER CONTROL',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('COMPUTER CONTROL',0);
            end
            TC3625.checkResponse(response, {TC3625.expect2}, 'COMPUTER CONTROL', 'TC_36_25_RS232_PeltierController:computerControl:unexpectedResponse');
        end
        %End Added
        function controlType = getControlType(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('READ CONTROL TYPE',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('READ CONTROL TYPE',0);
            end
            TC3625.checkResponse(response, {TC3625.expect0 TC3625.expect1 TC3625.expect2}, 'READ CONTROL TYPE', 'TC_36_25_RS232_PeltierController:readControlType:unexpectedResponse');

            if strcmp(response,TC3625.expect0)
                controlType = 'DEADBAND';
            elseif strcmp(response,TC3625.expect1)
                controlType = 'PID';
            elseif strcmp(response,TC3625.expect2)
                controlType = 'COMPUTER CONTROL';
            end
        end
        
        % heat/cool multiplier      
        function setHeatMultiplier(TC3625, setValue, retryOnBlock)
            if(CheckParam.isNumeric(setValue, 'TC_36_25_RS232_PeltierController:setHeatMultiplier:badInputs'))
                CheckParam.isWithinARange(setValue,0,2,'TC_36_25_RS232_PeltierController:setHeatMultiplier:badInputs');
            end
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            
            response = TC3625.sendSerialCommand('SET HEAT MULTIPLIER',setValue);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('SET HEAT MULTIPLIER',setValue);
            end
            response = TC3625.interpretResponse(response, 'SET HEAT MULTIPLIER');
            if(~strcmp(response, '__BLOCKED_'))
                if round(response*100) ~= round(setValue*100)
                    error('TC_36_25_RS232_PeltierController:setHeatMultiplier:unexpectedResponse',...
                        'Unexpected response ("%s") received to command "%s", does not equal setValue ("%f")', ...
                        response, 'SET HEAT MULTIPLIER', setValue);
                end
            end
        end
        
        function heatMultiplier = getHeatMultiplier(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('READ HEAT MULTIPLIER',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('READ HEAT MULTIPLIER',0);
            end
            heatMultiplier = TC3625.interpretResponse(response, 'READ HEAT MULTIPLIER');
        end
        
        function setCoolMultiplier(TC3625, setValue, retryOnBlock)
            if(CheckParam.isNumeric(setValue, 'TC_36_25_RS232_PeltierController:setCoolMultiplier:badInputs'))
                CheckParam.isWithinARange(setValue,0,2,'TC_36_25_RS232_PeltierController:setCoolMultiplier:badInputs');
            end
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            
            response = TC3625.sendSerialCommand('SET COOL MULTIPLIER',setValue);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('SET COOL MULTIPLIER',setValue);
            end
            response = TC3625.interpretResponse(response, 'SET COOL MULTIPLIER');
            if(~strcmp(response, '__BLOCKED_'))
                if round(response*100) ~= round(setValue*100)
                    error('TC_36_25_RS232_PeltierController:setCoolMultiplier:unexpectedResponse',...
                        'Unexpected response ("%s") received to command "%s", does not equal setValue ("%f")', ...
                        response, 'SET COOL MULTIPLIER', setValue);
                end
            end
        end
        
        function coolMultiplier = getCoolMultiplier(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('READ COOL MULTIPLIER',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('READ COOL MULTIPLIER',0);
            end
            coolMultiplier = TC3625.interpretResponse(response, 'READ COOL MULTIPLIER');
        end
        
        % temperature units
        function setUnitsF(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('SET UNITS TO F',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('SET UNITS TO F',0);
            end
            TC3625.checkResponse(response, {TC3625.expect0}, 'SET UNITS TO F', 'TC_36_25_RS232_PeltierController:setUnitsF:unexpectedResponse');
        end
        
        function setUnitsC(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('SET UNITS TO C',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('SET UNITS TO C',0);
            end
            TC3625.checkResponse(response, {TC3625.expect1}, 'SET UNITS TO C', 'TC_36_25_RS232_PeltierController:setUnitsC:unexpectedResponse');
        end
        
        function units = getUnits(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('READ UNITS',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('READ UNITS',0);
            end
            TC3625.checkResponse(response, {TC3625.expect0 TC3625.expect1}, 'READ UNITS', 'TC_36_25_RS232_PeltierController:getUnits:unexpectedResponse');
            
            if strcmp(response,TC3625.expect0)
                units = 'F';
            elseif strcmp(response,TC3625.expect1)
                units = 'C';
            end
        end
        
        
        % temperature settings     
        function currentTemp = getCurrentTemp(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('READ CURRENT TEMP',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('READ CURRENT TEMP',0);
            end
            currentTemp = TC3625.interpretResponse(response, 'READ CURRENT TEMP');
        end
        
        function currentTemp2 = getCurrentTemp2(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('READ CURRENT TEMP2',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('READ CURRENT TEMP2',0);
            end
            currentTemp2 = TC3625.interpretResponse(response, 'READ CURRENT TEMP2');
        end
        
        function setTemp = getSetTemp(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end

            response = TC3625.sendSerialCommand('READ SET TEMP',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('READ SET TEMP',0);
            end
            setTemp = TC3625.interpretResponse(response, 'READ SET TEMP');            
        end
        
        function response = setTemp(TC3625, setValue, retryOnBlock, rampCall)
            if(CheckParam.isNumeric(setValue, 'TC_36_25_RS232_PeltierController:setTemp:badInputs'))
                CheckParam.isWithinARange(setValue,0,100,'TC_36_25_RS232_PeltierController:setTemp:badInputs');
            end
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            if(~exist('rampCall','var'))
                rampCall = false;
            end
            if((~rampCall)&&(TC3625.isCurrentlyRamping())) %stop any currently running temperature ramps
                TC3625.pollingLoop.removeFromPollingLoop('updateRampTemperature');
            end
            
            response = TC3625.sendSerialCommand('SET TEMP',setValue);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('SET TEMP',setValue);
            end
            response = TC3625.interpretResponse(response, 'SET TEMP');
            if(~strcmp(response, '__BLOCKED_'))
                if round(response*100) ~= round(setValue*100)
                    error('TC_36_25_RS232_PeltierController:setTemp:unexpectedResponse',...
                        'Unexpected response ("%s") received to command "%s", does not equal setValue ("%f")', ...
                        response, 'SET TEMP', setValue);
                end
            end
        end
        
        %Added by Johan and Bojan, Oct 2013
        function response = setOutputPower(TC3625, setValue, retryOnBlock)
            if(CheckParam.isNumeric(setValue, 'TC_36_25_RS232_PeltierController:setOutputPower:badInputs'))
                CheckParam.isWithinARange(setValue,-511,511,'TC_36_25_RS232_PeltierController:setOutputPower:badInputs');
            end
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
                   
            response = TC3625.sendSerialCommand('SET OUTPUT POWER',setValue);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('SET OUTPUT POWER',setValue);
            end
            response = TC3625.interpretResponse(response, 'SET OUTPUT POWER');
            if(~strcmp(response, '__BLOCKED_'))
                if round(response) ~= round(setValue)
                    error('TC_36_25_RS232_PeltierController:setOutputPower:unexpectedResponse',...
                        'Unexpected response ("%s") received to command "%s", does not equal setValue ("%f")', ...
                        response, 'SET OUTPUT POWER', setValue)
                end
            end
        end
        %End Added
        
        function response = setHighAlarm(TC3625, setValue, retryOnBlock)
            if(CheckParam.isNumeric(setValue, 'TC_36_25_RS232_PeltierController:setHighAlarm:badInputs'))
                CheckParam.isWithinARange(setValue,0,100,'TC_36_25_RS232_PeltierController:setHighAlarm:badInputs');
            end
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            
            response = TC3625.sendSerialCommand('SET HIGH ALARM',setValue);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('SET HIGH ALARM',setValue);
            end
            response = TC3625.interpretResponse(response, 'SET HIGH ALARM');
            if(~strcmp(response, '__BLOCKED_'))
                if round(response*100) ~= round(setValue*100)
                    error('TC_36_25_RS232_PeltierController:setHighAlarm:unexpectedResponse',...
                        'Unexpected response ("%s") received to command "%s", does not equal setValue ("%f")', ...
                        response, 'SET HIGH ALARM', setValue);
                end
            end
        end
        
        function highAlarm = getHighAlarm(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end

            response = TC3625.sendSerialCommand('READ HIGH ALARM',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('READ HIGH ALARM',0);
            end
            highAlarm = TC3625.interpretResponse(response, 'READ HIGH ALARM'); 
        end
        
        function response = setLowAlarm(TC3625, setValue, retryOnBlock)
            if(CheckParam.isNumeric(setValue, 'TC_36_25_RS232_PeltierController:setLowAlarm:badInputs'))
                CheckParam.isWithinARange(setValue,0,100,'TC_36_25_RS232_PeltierController:setLowAlarm:badInputs');
            end
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            
            response = TC3625.sendSerialCommand('SET LOW ALARM',setValue);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('SET LOW ALARM',setValue);
            end
            response = TC3625.interpretResponse(response, 'SET LOW ALARM');
            if(~strcmp(response, '__BLOCKED_'))
                if round(response*100) ~= round(setValue*100)
                    error('TC_36_25_RS232_PeltierController:setLowAlarm:unexpectedResponse',...
                        'Unexpected response ("%s") received to command "%s", does not equal setValue ("%f")', ...
                        response, 'SET LOW ALARM', setValue);
                end
            end
        end
        
        function lowAlarm = getLowAlarm(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end

            response = TC3625.sendSerialCommand('READ LOW ALARM',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('READ LOW ALARM',0);
            end
            lowAlarm = TC3625.interpretResponse(response, 'READ LOW ALARM'); 
        end
        
        function TF = hasReachedDestinationTemp(TC3625)
            if(TC3625.isCurrentlyRamping()) %if there is a temperature ramp currently going on
                destinationTemp = TC3625.rampDestinationTemperature;
            else
                destinationTemp = TC3625.getSetTemp();
            end
            
            numPoints = 3;
            currPoint = 1;
            windowInterval = TC3625.window/(numPoints-1.0);
            TF = true;
            while(TF && (currPoint <= numPoints))
                if(currPoint ~= 1)
                    pause on; pause(windowInterval);
                end
                currTemp = TC3625.getCurrentTemp();
                if(abs(currTemp - destinationTemp) > TC3625.tolerance)
                    TF = false;
                end
                currPoint = currPoint + 1;
            end
        end
        
        function waitUntilTemperatureReached(TC3625)
            %pauses the flow of execution until the temperature is reached
            while(~TC3625.hasReachedDestinationTemp())%busy wait
                pause on; pause(5);
            end
        end
        
        function rampTempLinear(TC3625, destinationTemperature, rampRate)
            if(CheckParam.isNumeric(destinationTemperature, 'TC_36_25_RS232_PeltierController:rampTempLinear:badInputs'))
                CheckParam.isWithinARange(destinationTemperature,0,100,'TC_36_25_RS232_PeltierController:rampTempLinear:badInputs');
            end
            
            %rampRate is in °C/min
            if(CheckParam.isNumeric(rampRate, 'TC_36_25_RS232_PeltierController:rampTempLinear:badInputs'))
                CheckParam.isWithinARange(rampRate,0.01,30,'TC_36_25_RS232_PeltierController:rampTempLinear:badInputs');
            end
            
            %if another temperature ramp is currently going on, delete it first
            if(TC3625.isCurrentlyRamping())
                TC3625.pollingLoop.removeFromPollingLoop('updateRampTemperature');
            end
            
            args.startTemperature = TC3625.getCurrentTemp();
            TC3625.rampDestinationTemperature = destinationTemperature;
            args.destinationTemperature = destinationTemperature;
            TC3625.rampRate = rampRate; %update the object property to reflect the current ramp rate
            args.rampRate = rampRate;
            TC3625.pollingLoop.addToPollingLoop(@TC3625.updateRampTemperature, args, 'updateRampTemperature', 2);   
        end
        
        % Proportional bandwidth settings
        function proportionalBandwidth = getProportionalBandwidth(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('READ PROPORTIONAL BANDWITH',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('READ PROPORTIONAL BANDWITH',0);
            end
            proportionalBandwidth = TC3625.interpretResponse(response, 'READ PROPORTIONAL BANDWITH');          
        end
        
        function setProportionalBandwidth(TC3625, setValue, retryOnBlock)
            CheckParam.isNumeric(setValue, 'TC_36_25_RS232_PeltierController:setProportionalBandwidth:badInputs');
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('SET PROPORTIONAL BANDWITH',setValue);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('SET PROPORTIONAL BANDWITH',setValue);
            end
            response = TC3625.interpretResponse(response, 'SET PROPORTIONAL BANDWITH');
            if(~strcmp(response, '__BLOCKED_'))
                if round(response*100) ~= round(setValue*100)
                    error('TC_36_25_RS232_PeltierController:setProportionalBandwidth:unexpectedResponse',...
                        'Unexpected response ("%s") received to command "%s", does not equal setValue ("%s")', ...
                        response, 'SET PROPORTIONAL BANDWITH', setValue)
                end
            end
        end
        
        
        % Integral gain settings
        function integralGain = getIntegralGain(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('READ INTEGRAL GAIN',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('READ INTEGRAL GAIN',0);
            end
            integralGain = TC3625.interpretResponse(response, 'READ INTEGRAL GAIN');
        end
        
        function setIntegralGain(TC3625, setValue, retryOnBlock)
            CheckParam.isNumeric(setValue, 'TC_36_25_RS232_PeltierController:setIntegralGain:badInputs');
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('SET INTEGRAL GAIN',setValue);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('SET INTEGRAL GAIN',setValue);
            end
            response = TC3625.interpretResponse(response, 'SET INTEGRAL GAIN');
            if(~strcmp(response, '__BLOCKED_'))
                if round(response*100) ~= round(setValue*100)
                    error('TC_36_25_RS232_PeltierController:setIntegralGain:unexpectedResponse',...
                        'Unexpected response ("%s") received to command "%s", does not equal setValue ("%s")', ...
                        response, 'SET INTEGRAL GAIN', setValue)
                end
            end
        end
        
        
        % Derivative gain settings
        function derivativeGain = getDerivativeGain(TC3625, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('READ DERIVATIVE GAIN',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('READ DERIVATIVE GAIN',0);
            end
            derivativeGain = TC3625.interpretResponse(response, 'READ DERIVATIVE GAIN');
        end
        
        function setDerivativeGain(TC3625, setValue, retryOnBlock)
            CheckParam.isNumeric(setValue, 'TC_36_25_RS232_PeltierController:setDerivativeGain:badInputs');
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('SET DERIVATIVE GAIN',setValue);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('SET DERIVATIVE GAIN',setValue);
            end
            response = TC3625.interpretResponse(response, 'SET DERIVATIVE GAIN');
            if(~strcmp(response, '__BLOCKED_'))
                if round(response*100) ~= round(setValue*100)
                    error('TC_36_25_RS232_PeltierController:setDerivativelGain:unexpectedResponse',...
                        'Unexpected response ("%s") received to command "%s", does not equal setValue ("%s")', ...
                        response, 'SET DERIVATIVE GAIN', setValue)
                end
            end
        end
        
        % Power output
        % Johan and Bojan Oct 2013
        function powerOutput= getOutputPower(TC3625, retryOnBlock)
          if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            response = TC3625.sendSerialCommand('READ OUTPUT POWER',0);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = TC3625.sendSerialCommand('READ OUTPUT POWER',0);
            end
            powerOutput = TC3625.interpretResponse(response, 'READ OUTPUT POWER');
        end
        
        function TF = hasReachedSetTempSpecial(TC3625, args)
          try
            getTemp=TC3625.getCurrentTemp(false);%temp at prism top
            getTemp2=TC3625.getCurrentTemp2(false);%temp at copper plate
            setTemp=TC3625.getSetTemp(false);
            %TC3625.goingUp
            %if (setTemp~=TC3625.temporaryTemp)
                
                %TC3625.temporaryTemp
                %if(setTemp>TC3625.temporaryTemp && getTemp<setTemp && getTemp2>(getTemp+2))
                %'s0'
                %if (0)   
                 %   'did if 0'
                
                    %if ((getTemp-TC3625.temporaryTemp)<0)
                    %    TC3625.setTemp(TC3625.temporaryTemp)
                    %end
                    %if ((setTemp-TC3625.temporaryTemp)<3)
                    %    TC3625.setTemp(TC3625.temporaryTemp)
                    %else
                    %    TC3625.setTemp(TC3625.temporaryTemp+(setTemp-TC3625.temporaryTemp)/2)
                    %end
                        
                   
                %if(abs(getTemp-TC3625.temporaryTemp) < args.tolerance)    
                %    TC3625.setTemp(TC3625.temporaryTemp)
                %    123
                
               % elseif ((setTemp-getTemp-7*(destinationTemperature-15)/45-1)<0 && setTemp>TC3625.temporaryTemp)
               if (TC3625.goingUp==1)%if set temperature (temporaryTemp) is higher than current temp
                   tempDiff=abs(TC3625.temporaryTemp-getTemp);
                   offSet=7/35*(TC3625.temporaryTemp-25);
                   if (tempDiff>2*offSet)%below 53C for target 60C
                        TC3625.setTemp(TC3625.temporaryTemp, false);
                    %elseif (setTemp<(getTemp+6))% && setTemp>TC3625.temporaryTemp) 
                   
                    %elseif (setTemp<(getTemp+6))% && setTemp>TC3625.temporaryTemp)
                   elseif (tempDiff<=2*offSet && tempDiff>3)%53 to 56C; pulls the set temp higher when approaching set temperature to get it closer
                        %TC3625.setTemp(getTemp+7)
                        %TC3625.setIntegralGain(TC3625.temporaryIntegralGain)%+2*tempDiff/5)
                        TC3625.setIntegralGain(TC3625.temporaryIntegralGain*(1-(TC3625.temporaryTemp-3-getTemp)/(2*offSet-3)), false)
                   elseif (tempDiff<=3 && tempDiff>0.2)%58 to 59.8C
                       %TC3625.setTemp(TC3625.temporaryTemp+(offSet-2)/2*tempDiff)
                        %TC3625.setIntegralGain(TC3625.temporaryIntegralGain)%+2*tempDiff/5)
                        TC3625.setIntegralGain(TC3625.temporaryIntegralGain, false)%*(1-(TC3625.temporaryTemp-getTemp)/offSet))
                   elseif (tempDiff<=0.2)%if set temp is really close to current temperature, >59.8C
                        TC3625.setTemp(TC3625.temporaryTemp, false);
                        TC3625.setIntegralGain(TC3625.temporaryIntegralGain, false)%turns on I when close to set temp
                        TC3625.goingUp=2;%sets your I and exits polling loop->starts regulating    
                   else%I guess between 56 and 58; inreases set temp znd integral gain as temp increases within range
                    %if (setTemp==TC3625.temporaryTemp)
                        %TC3625.setTemp(TC3625.temporaryTemp+3+abs(TC3625.temporaryTemp-getTemp))
                        %TC3625.setTemp(TC3625.temporaryTemp+0.5*abs(TC3625.temporaryTemp-getTemp))
                        TC3625.setIntegralGain(TC3625.temporaryIntegralGain*(1-(TC3625.temporaryTemp-getTemp)/offSet), false)
                       %'rrrrfr'
                        %TC3625.setIntegralGain(TC3625.temporaryIntegralGain)
                    %end
                   % 'test2'
                    %TC3625.setTemp(TC3625.temporaryTemp)
                    %123333
                   end
                    %'rrr'
               elseif (TC3625.goingUp==0) %going down
                   tempDiff=abs(TC3625.temporaryTemp-getTemp);
                   temp2Diff=(getTemp2-TC3625.temporaryTemp)
                   offSet=7/35*(TC3625.temporaryTemp-25)
                     if (tempDiff<1)%%BMmod essentially tolerance 1%if temp at prism is close to target temp (and copper plate is hot enough to not trigger first if statement->give large spike, then set to desired temp, I, and exit polling loop
                        %TC3625.setTemp(getTemp+14+14*offSet)
                        'spike 2'
                        %pause(1)
                        %TC3625.setTemp(TC3625.temporaryTemp);
                        TC3625.setIntegralGain(TC3625.temporaryIntegralGain, false)
                        TC3625.goingUp=2;
                 %  if (temp2Diff<(-1))% && tempDiff>=0.2;;;if temp at copper plate is close to target temp, turns on I and spikes->if copper plate is close to set temp, will definitely overcool prism so need to spike
                 %       TC3625.setTemp(TC3625.temporaryTemp+40)%0+3*offSet)%TC3625.temporaryTemp+1+8*abs(TC3625.temporaryTemp-getTemp))
                 %       %TC3625.setIntegralGain(TC3625.temporaryIntegralGain+2*tempDiff/5)
                 %       %TC3625.setIntegralGain(TC3625.temporaryIntegralGain)
                 %       %TC3625.setIntegralGain(TC3625.temporaryIntegralGain*(1-(TC3625.temporaryTemp-getTemp)/offSet))
                 %       TC3625.setIntegralGain(TC3625.temporaryIntegralGain*(1-(tempDiff)/(2*offSet)))
                 %       %elseif (setTemp<(getTemp+6))% && setTemp>TC3625.temporaryTemp)
                 %       'spike 1'
                 %  elseif (tempDiff<0.2)%if temp at prism is close to target temp (and copper plate is hot enough to not trigger first if statement->give large spike, then set to desired temp, I, and exit polling loop
                 %       %TC3625.setTemp(getTemp+14+14*offSet)
                 %       'spike 2'
                 %       pause(1)
                 %       %TC3625.setTemp(TC3625.temporaryTemp);
                 %       TC3625.setIntegralGain(TC3625.temporaryIntegralGain)
                 %       TC3625.goingUp=2;
                   
          %              elseif (tempDiff>=0.2 && tempDiff<(2*offSet))%temp at plate is large & current temp is above target temp by more than 0.2C but less than 6C for 40C target (ie. getting nearer to target but still too hot)
          %         
          %             %elseif (setTemp<(getTemp+6))% && setTemp>TC3625.temporaryTemp)
          %      %  elseif (temp2Diff>(0.5*offSet) && tempDiff>=0.2 && tempDiff>=(2*offSet))%temp at plate is large & current temp is above target temp by more than 0.2C but less than 6C for 40C target (ie. getting nearer to target but still too hot)
          %          %   TC3625.setTemp(TC3625.temporaryTemp+0.5*abs(TC3625.temporaryTemp-getTemp)) 
          %          %   %TC3625.setTemp(TC3625.temporaryTemp);
          %          %   TC3625.setIntegralGain(TC3625.temporaryIntegralGain)
          %         %elseif (temp2Diff>(0.5*offSet) && tempDiff>=0.2 && tempDiff<(2*offSet))%temp at plate is large & current temp is above target temp by more than 0.2C but less than 6C for 40C target (ie. getting nearer to target but still too hot)
          %             %TC3625.setTemp(TC3625.temporaryTemp+0.5*abs(TC3625.temporaryTemp-getTemp)) 
          %             TC3625.setTemp(TC3625.temporaryTemp);
          %        
          %              TC3625.setIntegralGain(TC3625.temporaryIntegralGain*(1-(tempDiff)/(2*offSet)))
          %             %does nothing if prev conditions not satisfied
                     else
                       TC3625.setTemp(TC3625.temporaryTemp, false);
                       %TC3625.setIntegralGain(TC3625.temporaryIntegralGain*(1-(tempDiff)/(2*offSet)))
                   end
                   %'ttt'
               elseif( TC3625.goingUp==2)%goingUp==2 is signal to exit polling loop and just regulate at the target temp
                    TC3625.setIntegralGain(TC3625.temporaryIntegralGain, false)
                    456
                    if(TC3625.pollingLoop.isInPollingList('setTempSpecial'));
                        if (TC3625.getIntegralGain(false)== TC3625.temporaryIntegralGain)
                            TC3625.pollingLoop.removeFromPollingLoop('setTempSpecial');
                            'Stopped'
                        end
                    end
               end
                %789
              %  if (abs(getTemp-setTemp) < args.tolerance)
              %'Within set temp'
               %     if (setTemp~=TC3625.temporaryTemp)
               %         TC3625.setTemp(TC3625.temporaryTemp)
               %         123
                %else
                %    TC3625.setIntegralGain(TC3625.temporaryIntegralGain)
                %    456
                %    if(TC3625.pollingLoop.isInPollingList('setTempSpecial'));
                %        if (TC3625.getIntegralGain()== TC3625.temporaryIntegralGain)
                %            TC3625.pollingLoop.removeFromPollingLoop('setTempSpecial');
                %            'Stopped'
                %        end
                %    end
                %end
                    
                 %   TC3625.setIntegralGain(TC3625.temporaryIntegralGain)
                 %   456
                 %   if(TC3625.pollingLoop.isInPollingList('setTempSpecial'));
                 %       if (TC3625.getIntegralGain()== TC3625.temporaryIntegralGain)
                 %           TC3625.pollingLoop.removeFromPollingLoop('setTempSpecial');
                 %       end
                 %   end
                %end
                
            %else
                %if (setTemp==TC3625.temporaryTemp)
                %    TC3625.setIntegralGain(TC3625.temporaryIntegralGain);
                %end
                % 'Not there yet'
             %end
          catch exception
            'TC_36_25_RS232_PeltierController:hasReachedSetTempSpecial:unexpectedResponse'
          end
        end    
            
        function TF = isCurrentlyRamping(TC3625)
            TF = TC3625.pollingLoop.isInPollingList('updateRampTemperature');
        end
        
        
        function setTempSpecial(TC3625, destinationTemperature)%, tolerance, timeStep)
            if(CheckParam.isNumeric(destinationTemperature, 'TC_36_25_RS232_PeltierController:setTempSpecial:badInputs'))
                CheckParam.isWithinARange(destinationTemperature,0,100,'TC_36_25_RS232_PeltierController:setTempSpecial:badInputs');
            end
                              
            %if another temperature ramp is currently going on, delete it first
            if(TC3625.pollingLoop.isInPollingList('setTempSpecial'));
                TC3625.pollingLoop.removeFromPollingLoop('setTempSpecial');
            end
            timeStep=2;
            TC3625.temporaryIntegralGain=0.5;%TC3625.getIntegralGain();
            getTemp=TC3625.getCurrentTemp();
            TC3625.temporaryTemp=destinationTemperature;
            TC3625.setIntegralGain(0);
            if ((destinationTemperature-getTemp)<0)
            
                %TC3625.setTemp(destinationTemperature+4+5*(destinationTemperature-15)/40)
                TC3625.setTemp(destinationTemperature)%+4+5*(destinationTemperature-15)/40)
                TC3625.goingUp=0;
            else
                TC3625.setTemp(destinationTemperature)%+2+1.5*(destinationTemperature-15)/40 )
                %TC3625.setTemp(destinationTemperature-2-1.5*(destinationTemperature-15)/40 )
                %TC3625.setTemp(destinationTemperature+7*(destinationTemperature-15)/45)
                TC3625.goingUp=1;
            end
            %TC3625.temporaryTemp=destinationTemperature
            
            %TC3625.setTemp(destinationTemperature);
            
            
            %Adjust the tolerance based on final temperature and deltaT
            %tolerance=0.5+max(0, 40/(destinationTemperature-getTemp))+max(0, sign(destinationTemperature-getTemp)*(getTemp-15)/20)
            %tolerance=0.5+abs(40/(destinationTemperature-getTemp))+abs(sign(destinationTemperature-getTemp)*(getTemp-15)/20)
            tolerance=1;
            %args.destinationTemperature=destinationTemperature;
            args.tolerance= tolerance;
            %TC3625.rampDestinationTemperature = destinationTemperature;
            %args.destinationTemperature = destinationTemperature;
            %TC3625.rampRate = rampRate; %update the object property to reflect the current ramp rate
            %args.rampRate = rampRate;
            TC3625.pollingLoop.addToPollingLoop(@TC3625.hasReachedSetTempSpecial, args, 'setTempSpecial', timeStep);
            
        end
    end %END PUBLIC METHODS
    
end %END Class PeltierController
