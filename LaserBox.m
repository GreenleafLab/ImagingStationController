%#########################################################################
% LaserBox.m
% Serial and analog (through a NI USB-6009 interface) hardware interface
% with a gem 532 + smd 6000 controller (green laser) and a
% CVI Melles Griot 660nm + universal laser controller (red laser)
% Written by Curtis Layton 09/2012
%#########################################################################

%note that the NI USB-6009 DAQ must be installed and recognized by MATLAB.
%Development was done with the NI-DAQmx driver package installed on Windows XP

classdef LaserBox < handle
    
    properties % GENERAL PROPERTIES
        %green laser
        greenSerialCom;
        greenSerialCommands = containers.Map(); %create an associative array to contain all serial commands
        greenExpectedSerialResponses = containers.Map(); %create an associative array to contain all expected responses to those commands
    
        greenCurrSetPower = 50; %currently set power for the green laser (mW)

        %red laser
        redSerialCom;
        redSerialCommands = containers.Map(); %create an associative array to contain all serial commands
        redExpectedSerialResponses = containers.Map(); %create an associative array to contain all expected responses to those commands
        
        redCurrSetPower = 50; %currently set power for the red laser (mW)
        
        %NI DAQ board
        dIO; %digital output object
        dChannels; %individual channels of digital output
        
        redMutex;
        greenMutex;
        
        redOn; %boolean to keep track of on/off state of red laser
        greenOn; %boolean to keep track of on/off state of green laser
    end % END GENERAL PROPERTIES
    
    properties (Constant) % CONSTANT PROPERTIES
        redDefaultPower = 50;
        greenDefaultPower = 50;
        redLaserPowerMin = 0;
        redLaserPowerMax = 450;
        greenLaserPowerMin = 0;
        greenLaserPowerMax = 450;   
        powerTolerance = 3.0;
        
        laserIndices = {'0', '1'};
        laserDescriptions = {'Red (660nm)', 'Green (532nm)'};
        numSerialRetries = 3; %number of times to attempt to read from a serial device.  (Hiccups occur from time to time, and re-reading is necessary.)
        serialHiccupPause = 0.3; %seconds to pause after a serial hiccup to reattempt communication
    end % END CONSTANT PROPERTIES
    
    methods (Access = private) % PRIVATE METHODS
        
        function response = greenGetSerialResponse(LB)
            response = ''; %init
            responseByte = 0; %init
            while(responseByte ~= 13) %read until we get to the 'carriage return' line terminator character
                numSerialTries = 0;
                responseByte = []; %init
                while((isempty(responseByte)) && (numSerialTries < LB.numSerialRetries))
                    lastwarn(''); %clear lastwarn so if we get a timeout warning we can throw a real error
                    responseByte = fread(LB.greenSerialCom, 1, 'int8');
                    [warningMessage warningID] = lastwarn;
                    if(strcmp(warningID, 'MATLAB:serial:fread:unsuccessfulRead'))
                        pause on; pause(LB.serialHiccupPause);
                    end
                    numSerialTries = numSerialTries + 1;
                end
                
                [warningMessage warningID] = lastwarn;
                if(strcmp(warningID, 'MATLAB:serial:fread:unsuccessfulRead'))
                    error('LaserBox:greenGetSerialResponse:Timeout', 'More than the timeout limit (%f sec) passed waiting for a response from the laser box on port "%s".', LB.greenSerialCom.Timeout, LB.greenSerialCom.Port);
                elseif(isempty(responseByte))
                    error('LaserBox:greenGetSerialResponse:comError', 'Trouble communicating with the laser box on port "%s".', LB.greenSerialCom.Port);
                end
                
                switch responseByte
                    case 13 % 'carriage return' terminator character
                        break;
                    case 3 % 'end of text'
                        %do not add to the response
                    case 10 %line feed
                        %do not add to the response
                    case 32 %space
                        if(~isempty(response)) %only if it is not a leading space
                            response = [response char(responseByte)]; %add to the response
                        end
                    otherwise
                        response = [response char(responseByte)]; %otherwise add to the response
                end
            end
        end
        
        
        function response = greenSendSerialCommand(LB, command)
            CheckParam.isString(command, 'LaserBox:greenSendSerialCommand:badInput');
            
            if(LB.greenMutex.tryAcquire() == true)
                try
                    fprintf(LB.greenSerialCom, command);
                catch err
                    error('LB:greenSendSerialCommand:cannotSend','Cannot send to the laser box through serial communication on port "%s".', LB.greenSerialCom.Port);
                end
                response = LB.greenGetSerialResponse();
                LB.greenMutex.release(); %release mutex lock
            else
                response = '__BLOCKED_';
            end
        end
        
       function response = redGetSerialResponse(LB)
            response = ''; %init
            responseByte = 0; %init
            while(responseByte ~= 62) %read until we get to the '>' prompt
                numSerialTries = 0;
                responseByte = []; %init
                while((isempty(responseByte)) && (numSerialTries < LB.numSerialRetries))
                    lastwarn(''); %clear lastwarn so if we get a timeout warning we can throw a real error
                    responseByte = fread(LB.redSerialCom, 1, 'int8');
                    [warningMessage warningID] = lastwarn;
                    if(strcmp(warningID, 'MATLAB:serial:fread:unsuccessfulRead'))
                        pause on; pause(LB.serialHiccupPause);
                    end
                    numSerialTries = numSerialTries + 1;
                end

                [warningMessage warningID] = lastwarn;
                if(strcmp(warningID, 'MATLAB:serial:fread:unsuccessfulRead'))
                    error('LaserBox:redGetSerialResponse:Timeout', 'More than the timeout limit (%f sec) passed waiting for a response from the laser box on port "%s".', LB.redSerialCom.Timeout, LB.redSerialCom.Port);
                elseif(isempty(responseByte))
                    error('LaserBox:redGetSerialResponse:comError', 'Trouble communicating with the laser box on port "%s".', LB.redSerialCom.Port);
                end
                
                switch responseByte
                    case 62 % '>' prompt character
                        break;
                    case 13 % 'carriage return' terminator character
                        %do not add to the response
                    case 3 % 'end of text'
                        %do not add to the response
                    case 10 %line feed
                        %do not add to the response
                    case 32 %space
                        if(~isempty(response)) %only if it is not a leading space
                            response = [response char(responseByte)]; %add to the response
                        end
                    otherwise
                        response = [response char(responseByte)]; %otherwise add to the response
                end
            end
        end
        
        
        function response = redSendSerialCommand(LB, command)
            CheckParam.isString(command, 'LaserBox:sendSerialCommand:badInput');

            if(LB.redMutex.tryAcquire() == true)
                try
                    fprintf(LB.redSerialCom, command);
                catch err
                    error('LB:redSendSerialCommand:cannotSend','Cannot send to the laser box through serial communication on port "%s".', redSerialCom.Port);
                end
                response = LB.redGetSerialResponse();
                LB.redMutex.release(); %release mutex lock
            else
                response = '__BLOCKED_';
            end            
        end
        
        function confirm = checkResponse(LB, response, command, errorIdentifier, expectedSerialResponses, commandPlusArgs)
            CheckParam.isString(response, 'LaserBox:checkResponse:badInput');
            CheckParam.isString(command, 'LaserBox:checkResponse:badInput');
            
            if(~exist('commandPlusArgs','var'))
                commandPlusArgs = command;
            else
                try
                    CheckParam.isString(commandPlusArgs, 'LaserBox:checkResponse:badInput');
                catch err
                    throwAsCaller(err);
                end
            end
            
            if(strcmp(response, '__BLOCKED_'))
                confirm = '__BLOCKED_';
            else
                errorMessage = sprintf('Unexpected response ("%s") received to command "%s"', response, commandPlusArgs);
                try
                    CheckParam.isInList(response,expectedSerialResponses(command),errorIdentifier,errorMessage);
                catch err
                    throwAsCaller(err);
                end
                confirm = true;
            end
        end
        
        function params = scanResponse(LX4000, response, command, format, numExpectedParams, errorIdentifier, commandPlusArgs)
            CheckParam.isString(response, 'LaserBox:scanResponse:badInput');
            CheckParam.isString(command, 'LaserBox:scanResponse:badInput');
            CheckParam.isString(format, 'LaserBox:scanResponse:badInput');
            CheckParam.isInteger(numExpectedParams, 'LaserBox:scanResponse:badInput');
            
            if(~exist('commandPlusArgs','var'))
                commandPlusArgs = command;
            else
                CheckParam.isString(commandPlusArgs, 'ASI_LX4000_StageAndFilterWheelController:scanResponse:badInput');
            end
            
            if(strcmp(response, '__BLOCKED_'))
                params = '__BLOCKED_';
            else
                errorMessage = sprintf('Unexpected response ("%s") received to command "%s"', response, commandPlusArgs);
                params = CheckParam.scanFormattedInput(response, format, numExpectedParams, errorIdentifier, errorMessage);
            end
       end
        

    end % END PRIVATE METHODS
    
    
    
    
    methods   % PUBLIC METHODS
        
        % Constructor
        function LB = LaserBox()
            
            %green laser serial commands
            LB.greenSerialCommands('GET GREEN LASER POWER') = 'POWER?';
            LB.greenExpectedSerialResponses(LB.greenSerialCommands('GET GREEN LASER POWER')) = {'%fmW'};  %returns current laser power
            
            LB.greenSerialCommands('SET GREEN LASER POWER') = 'POWER=';
            LB.greenExpectedSerialResponses(LB.greenSerialCommands('SET GREEN LASER POWER')) = {''};
            
            LB.greenSerialCommands('GET GREEN LASER HEAD TEMP') = 'LASTEMP?';
            LB.greenExpectedSerialResponses(LB.greenSerialCommands('GET GREEN LASER HEAD TEMP')) = {'%fC'};
            
            LB.greenSerialCommands('GET GREEN LASER PSU TEMP') = 'PSUTEMP?';
            LB.greenExpectedSerialResponses(LB.greenSerialCommands('GET GREEN LASER PSU TEMP')) = {'%fC'};
            
            LB.greenSerialCommands('GET GREEN LASER STATUS') = 'STAT?';
            LB.greenExpectedSerialResponses(LB.greenSerialCommands('GET GREEN LASER STATUS')) = {'ENABLED' 'DISABLED'};
            
            LB.greenSerialCommands('POWER ON GREEN LASER') = 'ON';
            LB.greenExpectedSerialResponses(LB.greenSerialCommands('POWER ON GREEN LASER')) = {''};
            
            LB.greenSerialCommands('POWER OFF GREEN LASER') = 'OFF';
            LB.greenExpectedSerialResponses(LB.greenSerialCommands('POWER OFF GREEN LASER')) = {''};

            
            
            %red laser serial commands
            LB.redSerialCommands('GET RED LASER POWER') = 'READ:LAS:POW?';
            LB.redExpectedSerialResponses(LB.redSerialCommands('GET RED LASER POWER')) = {'%f'};

            LB.redSerialCommands('SET RED LASER POWER') = 'LAS:POW:REF ';
            LB.redExpectedSerialResponses(LB.redSerialCommands('SET RED LASER POWER')) = {''};
            
            LB.redSerialCommands('GET RED LASER STATUS') = 'LAS:STAT?';
            LB.redExpectedSerialResponses(LB.redSerialCommands('GET RED LASER STATUS')) = {'0,OFF' '1,RAMP' '2,ON'};
            
            %these commands give back the temp in ohms - resistance reading
            %of the temperature probe.  Until the proper conversion to temperature is
            %found, they are omitted
            
                %LB.redSerialCommands('GET RED LASER DIODE TEMP') = 'READ:LTEC:TEMP?';
                %LB.redExpectedSerialResponses(LB.redSerialCommands('GET RED LASER DIODE TEMP')) = {'%f'};

                %LB.redSerialCommands('GET RED LASER CRYSTAL TEMP') = 'READ:XTEC:TEMP?';
                %LB.redExpectedSerialResponses(LB.redSerialCommands('GET RED LASER CRYSTAL TEMP')) = {'%f'};

            
            %setup NI USB-6009 DAQ board for digital output
            LB.dIO = digitalio('nidaq','Dev1'); %Original NI USB-6008 DAQ board
            
            %LB.dIO = digitalio('nidaq','Dev2'); %New NI USB-6009 DAQ. Changed by Johan 12/23/2014 to account for new laser board.
            
            addline(LB.dIO,0:2,0,'Out'); %add 3 channels on port 0 for communication with the laser
                        
            %Nandita D- 24/7/13 
            addline(LB.dIO,0:2,1,'Out'); %add 3 channels on port 1 for switching the fiber optic switch and enabling circuit
            
            % Digital Channel Index to the custom laser control board
            % Line 1 = port 0, channel 0 - power switch, low = on, high = red laser off 
            % Line 2 = port 0, channel 1 - normally low, momentary high = red laser on
            % Line 3 = port 0, channel 2 - normally low, momentary high = green laser reset
            
            %Nandita D- 24/7/13 
            %Line 4 = port 1, channel 0 - RED/GREEN Laser, 0 for red laser,
            %1 for green laser
            %Line 5 = port 1, channel 1 - Input for pin 5 on the circuit
            %board (leading to SSR1)
            %Line 6 = port 1, channel 2 - Input for pin 4 on the circuit
            %board (leading to SSR2)
            
            %The following are the correct io combinations if Line 5 on the DAQ is
            %connected to pin 5 on circiuit board, if line 6 on the DAQ is
            %connected to pin 4 on the circuit board, and if line 4 on the
            %DAQ is connected to pin 6 on the circuit board.
            %[Line 4, Line 5, Line 6] = [0 0 0] = switch off
            %[Line 4, Line 5, Line 6] = [0 1 1] = switch red laser on
            %[Line 4, Line 5, Line 6] = [1 1 1] = switch green laser on
            %[Line 4, Line 5, Line 6] = [0/1 1 0] = get input from the camera
            %about when to turn laser on
            putvalue(LB.dIO,[0 0 0 0 0 0]); %explicitly initialize to 0 (maybe not really necessary since this is the default)
        
            LB.redMutex = java.util.concurrent.Semaphore(1);
            LB.greenMutex = java.util.concurrent.Semaphore(1);
            
            LB.redOn = false;
            LB.greenOn = false;
            warning('off', 'MATLAB:serial:fread:unsuccessfulRead');
        end
        
        function powerUpLasers(LB)
            greenSetPower = LB.greenGetCurrSetPower();
            greenCurrPower = LB.greenGetPower();
            redSetPower = LB.redGetCurrSetPower();
            redCurrPower = LB.redGetPower();
            first = true;
            maxStartupAttempts = 3;
            startupTries = 0;
            while(~LB.isAtSetPower() || first)

                if (startupTries > maxStartupAttempts)
                    disp('WARNING: max startup attempts failed to power up lasers. Continuing, but laser(s) may not be operational.');
                    break;
                end
                
                pause on; pause(5);
                greenCurrPower = LB.greenGetPower();
                redCurrPower = LB.redGetPower();

                greenStatus = LB.greenGetLaserStatus();
                if(~strcmp(greenStatus,'ENABLED'))
                    %disp('green laser not enabled.  Attempting to re-power on.');
                    LB.greenPowerOn();
                end
                LB.greenOn = true;
                
                redStatus = LB.redGetLaserStatus();
                if(~strcmp(redStatus,'ENABLED'))
                    %disp('red laser not enabled.  Attempting to re-power on.');
                    LB.redPowerOn();
                end
                LB.redOn = true;
                %msg = sprintf('powering on lasers...current power: [green = %f (%f)], [red = %f (%f)]\n', greenCurrPower,greenSetPower,redCurrPower,redSetPower);  disp(msg);

                first = false;
                startupTries = startupTries + 1;
            end
        end
        
        function TF = isAtSetPower(LB, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            
            greenSetPower = LB.greenGetCurrSetPower();
            greenCurrPower = LB.greenGetPower(retryOnBlock);
            while(strcmp(greenCurrPower, '__BLOCKED_') && retryOnBlock)
                greenCurrPower = LB.greenGetPower(retryOnBlock);
            end
            
            redSetPower = LB.redGetCurrSetPower();
            redCurrPower = LB.redGetPower(retryOnBlock);
            while(strcmp(redCurrPower, '__BLOCKED_') && retryOnBlock)
                redCurrPower = LB.redGetPower(retryOnBlock);
            end
            
            if(strcmp(greenCurrPower, '__BLOCKED_') || strcmp(redCurrPower, '__BLOCKED_'))
                TF = '__BLOCKED_';
            elseif(abs(redCurrPower - redSetPower) > LB.powerTolerance) || (abs(greenCurrPower - greenSetPower) > LB.powerTolerance)
                TF = false;
            else
                TF = true;
            end
        end
        
        % GREEN LASER PUBLIC METHODS
        
        function greenSetupSerialCommunication(LB, serialPort, baudRate, dataBits, parityBit, stopBits, flowControl, lineTerminator)
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
            
            LB.greenSerialCom = serial(serialPort);
            set(LB.greenSerialCom, 'BaudRate', baudRate);
            set(LB.greenSerialCom, 'DataBits', dataBits);
            set(LB.greenSerialCom, 'Parity', parityBit);
            set(LB.greenSerialCom, 'StopBits', stopBits);
            set(LB.greenSerialCom, 'FlowControl', flowControl);
            set(LB.greenSerialCom, 'Terminator', lineTerminator);
            set(LB.greenSerialCom, 'Timeout', 2);
        end
        
        
        function greenSerialConnect(LB)
            try
                fopen(LB.greenSerialCom);
            catch err
                error('LaserBox:greenSerialConnect:comError',...
                    'Cannot open the serial port "%s" to communicate with the green laser.', LB.greenSerialCom.Port);
            end
        end
        
        function greenSerialDisconnect(LB)
            try
                fclose(LB.greenSerialCom);
            catch err
                error('LaserBox:greenSerialDisconnect:comError',...
                    'Cannot close the serial port "%s" to terminate communication with the green laser.', LB.greenSerialCom.Port);
            end
        end
        
        function greenLaserReset(LB) %uses the NI DAQ output to cycle the reset switch on the green laser--necessary to turn the laser on
            putvalue(LB.dIO.Line(3),1); %send high to the green laser reset switch
            pause on; pause(0.5); %short pause
            putvalue(LB.dIO.Line(3),0); %back to low
        end
        
        function greenPowerOn(LB, initialPower, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            if(~exist('initialPower','var'))
                initialPower = LB.greenCurrSetPower; %initialize power to last used value, if not specified
            elseif(CheckParam.isNumeric(initialPower))
                CheckParam.isWithinARange(initialPower, 0, 450, 'LaserBox:greenPowerOn:badInput');
            end

            %send 'power on' command
            command = LB.greenSerialCommands('POWER ON GREEN LASER');
            response = LB.greenSendSerialCommand(command);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = LB.greenSendSerialCommand(command);
            end
            LB.checkResponse(response, command, 'LaserBox:greenPowerOn:unexpectedResponse', LB.greenExpectedSerialResponses);
            
            %set initial power
            LB.greenSetPower(initialPower);
            
            %hardware reset to turn on
            LB.greenLaserReset();
            
            LB.greenOn = true;
        end
        
        function greenPowerOff(LB, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            %send 'power off' command
            command = LB.greenSerialCommands('POWER OFF GREEN LASER');
            response = LB.greenSendSerialCommand(command);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = LB.greenSendSerialCommand(command);
            end
            LB.checkResponse(response, command, 'LaserBox:greenPowerOff:unexpectedResponse', LB.greenExpectedSerialResponses);
            
            LB.greenOn = false;
        end
        
        function power = greenGetPower(LB, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            command = LB.greenSerialCommands('GET GREEN LASER POWER');
            response = LB.greenSendSerialCommand(command);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = LB.greenSendSerialCommand(command);
            end
            expectedResponses = LB.greenExpectedSerialResponses(command);
            format = char(expectedResponses(1));
            params = LB.scanResponse(response, command, format, 1, 'LaserBox:greenPowerOff:unexpectedResponse');
            power = params(1);
        end
        
        function greenSetPower(LB, power, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            if(CheckParam.isNumeric(power, 'LaserBox:greenSetPower:badInput'))
                CheckParam.isWithinARange(power, 0, 450, 'LaserBox:greenSetPower:badInput');
            end
            command = LB.greenSerialCommands('SET GREEN LASER POWER');
            commandPlusArgs = [command num2str(power)];
            response = LB.greenSendSerialCommand(commandPlusArgs);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = LB.greenSendSerialCommand(commandPlusArgs);
            end
            LB.checkResponse(response, command, 'LaserBox:greenSetPower:unexpectedResponse', LB.greenExpectedSerialResponses, commandPlusArgs);
            LB.greenCurrSetPower = power;
        end
        
        function currSetPower = greenGetCurrSetPower(LB)
            if(LB.greenOn)
                currSetPower = LB.greenCurrSetPower;
            else
                currSetPower = 0;
            end
        end
        
        function laserTemp = greenGetLaserTemp(LB, retryOnBlock) %in degrees C
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            command = LB.greenSerialCommands('GET GREEN LASER HEAD TEMP');
            response = LB.greenSendSerialCommand(command);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = LB.greenSendSerialCommand(command);
            end
            expectedResponses = LB.greenExpectedSerialResponses(command);
            format = char(expectedResponses(1));
            params = LB.scanResponse(response, command, format, 1, 'LaserBox:greenGetLaserTemp:unexpectedResponse');
            laserTemp = num2str(params(1)); 
        end
        
        function psuTemp = greenGetPSUTemp(LB, retryOnBlock) %in degrees C
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            command = LB.greenSerialCommands('GET GREEN LASER PSU TEMP');
            response = LB.greenSendSerialCommand(command);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = LB.greenSendSerialCommand(command);
            end
            expectedResponses = LB.greenExpectedSerialResponses(command);
            format = char(expectedResponses(1));
            params = LB.scanResponse(response, command, format, 1, 'LaserBox:greenGetPSUTemp:unexpectedResponse');
            psuTemp = num2str(params(1));
        end
        
        function status = greenGetLaserStatus(LB, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            command = LB.greenSerialCommands('GET GREEN LASER STATUS');
            response = LB.greenSendSerialCommand(command);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = LB.greenSendSerialCommand(command);
            end
            LB.checkResponse(response, command, 'LaserBox:greenGetInterlockStatus:unexpectedResponse', LB.greenExpectedSerialResponses);
            status = response;
        end
        
        % RED LASER PUBLIC METHODS
        
            function redSetupSerialCommunication(LB, serialPort, baudRate, dataBits, parityBit, stopBits, flowControl, lineTerminator)
            %default values
            if(~exist('baudRate','var'))
                baudRate = 19200;
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
            
            LB.redSerialCom = serial(serialPort);
            set(LB.redSerialCom, 'BaudRate', baudRate);
            set(LB.redSerialCom, 'DataBits', dataBits);
            set(LB.redSerialCom, 'Parity', parityBit);
            set(LB.redSerialCom, 'StopBits', stopBits);
            set(LB.redSerialCom, 'FlowControl', flowControl);
            set(LB.redSerialCom, 'Terminator', lineTerminator);
            set(LB.redSerialCom, 'Timeout', 2);
        end
        
        
        function redSerialConnect(LB)
            try
                fopen(LB.redSerialCom);
            catch err
                error('LaserBox:redSerialConnect:comError',...
                    'Cannot open the serial port "%s" to communicate with the red laser.', LB.redSerialCom.Port);
            end
        end
        
        function redSerialDisconnect(LB)
            try
                fclose(LB.redSerialCom);
            catch err
                error('LaserBox:redSerialDisconnect:comError',...
                    'Cannot close the serial port "%s" to terminate communication with the red laser.', LB.redSerialCom.Port);
            end
        end
        
        function redPowerOn(LB, initialPower)
            if(~exist('initialPower','var'))
                initialPower = LB.redCurrSetPower; %initialize power to last used value, if not specified
            elseif(CheckParam.isNumeric(initialPower))
                CheckParam.isWithinARange(initialPower, 0, 450, 'LaserBox:redPowerOn:badInput');
            end

            %send 'power on' signal
            %putvalue(LB.dIO.Line(1),1); %setting this channel high disconnects pin 11 from pin 6, and connects 11 to 5 turn on
            %pause on;pause(0.2); %200ms pause
            %putvalue(LB.dIO.Line(1),0); %setting this channel back low reconnects pin 11 to pin 5
            
            %Johan, 01/22/2015, for new laser board
            putvalue(LB.dIO.Line(2),1); %setting this channel high disconnects pin 11 from pin 6, and connects 11 to 5 turn on
            pause on;pause(0.2); %200ms pause
            putvalue(LB.dIO.Line(2),0); %setting this channel back low reconnects pin 11 to pin 5
            
            %set initial power
            LB.redSetPower(initialPower);
            
            LB.redOn = true;
        end
        
        function redPowerOff(LB)         
            %send 'power off' signal
            putvalue(LB.dIO.Line(2),1); %setting this channel high connects pin 12 to pin 7 to turn off
            pause on;pause(0.2); %200ms pause
            putvalue(LB.dIO.Line(2),0); %setting this channel back low disconnects pin 12 from pin 7
            
            %Johan, 01/22/2015, for new laser board
            %putvalue(LB.dIO.Line(1),1); %setting this channel high connects pin 12 to pin 7 to turn off
            %pause on;pause(0.2); %200ms pause
            %putvalue(LB.dIO.Line(1),0); %setting this channel back low disconnects pin 12 from pin 7
            
            
            LB.redOn = false;
        end
        
       function power = redGetPower(LB, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            command = LB.redSerialCommands('GET RED LASER POWER');
            response = LB.redSendSerialCommand(command);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = LB.redSendSerialCommand(command);
            end
            expectedResponses = LB.redExpectedSerialResponses(command);
            format = char(expectedResponses(1));
            params = LB.scanResponse(response, command, format, 1, 'LaserBox:redGetPower:unexpectedResponse');
            power = params(1);
       end
        
       function status = redGetLaserStatus(LB, retryOnBlock)
           if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            command = LB.redSerialCommands('GET RED LASER STATUS');
            response = LB.redSendSerialCommand(command);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = LB.redSendSerialCommand(command);
            end
            LB.checkResponse(response, command, 'LaserBox:redGetLaserStatus:unexpectedResponse', LB.redExpectedSerialResponses);
            if(strcmp(response,'2,ON') || strcmp(response,'1,RAMP'))
                status = 'ENABLED';
            else
                status = 'DISABLED';
            end
        end
        
        function redSetPower(LB, power, retryOnBlock)
            if(~exist('retryOnBlock','var'))
                retryOnBlock = true;
            end
            if(CheckParam.isNumeric(power, 'LaserBox:redSetPower:badInput'))
                CheckParam.isWithinARange(power, 0, 450, 'LaserBox:redSetPower:badInput');
            end
            command = LB.redSerialCommands('SET RED LASER POWER');
            commandPlusArgs = [command num2str(power)];
            response = LB.redSendSerialCommand(commandPlusArgs);
            while(strcmp(response, '__BLOCKED_') && retryOnBlock)
                response = LB.redSendSerialCommand(commandPlusArgs);
            end
            LB.checkResponse(response, command, 'LaserBox:redSetPower:unexpectedResponse', LB.redExpectedSerialResponses, commandPlusArgs);
            LB.redCurrSetPower = power;
        end
        
        function currSetPower = redGetCurrSetPower(LB)
            if(LB.redOn)
                currSetPower = LB.redCurrSetPower;
            else
                currSetPower = 0;
            end
        end
                
        % FIBER OPTIC SWITCH PUBLIC METHODS
        
        % To switch off the laser set the values for pins 4-6 to 0. This
        % turn off the input to SSR1 and SSR2.
        function switchOff(LB)
            
            %putvalue(LB.dIO.Line(4:5),[0 0]);
            %Nandita D- 24/7/13
            putvalue(LB.dIO.Line(4:6),[0 0 0]);
            %$Nandita D- 24/7/13
        
        end
        
        function switchGreen(LB)
            
            %putvalue(LB.dIO.Line(4:5),[1 0]);
            %Nandita D- 24/7/13
            putvalue(LB.dIO.Line(4),1);
            %%Nandita D- 24/7/13
        
        end
        
        function switchRed(LB)
            
            %putvalue(LB.dIO.Line(4:5),[0 1]);
            %Nandita D- 24/7/13
            putvalue(LB.dIO.Line(4),0);
            %%Nandita D- 24/7/13
    
        
        end
        
        %Nandita D- 24/7/13
        %%To get input from camera pin 8 to the logic circuit
        % For this to work channel 5 must be linked to pin 5 on the circuit
        % board (leading to SSR1) and channel 6 must be linked to pin 4 
        % (leading to SSR2) on the circuit board.
        function laserEnable(LB)
            putvalue(LB.dIO.Line(5),1);
            putvalue(LB.dIO.Line(6),0);
        end
        
        % Channels 5 and 6 (DAQ Port 1, channels 1 and 2) must both be set
        % to 1 to manually control the laser. Note that channel 5
        % corresponds to entry point 5 on the circuit board  (leads to 
        % SSR1)and channel 6 corresponds to entry point 4 on the circuit 
        % board (leads to SSR2).
        function manualLaserEnable(LB)
            putvalue(LB.dIO.Line(5),1);
            putvalue(LB.dIO.Line(6),1);
        end
        
        %Nandita D- 24/7/13
        % To disable the laser set channels 5 and 6 on the DAQ to 0, which 
        % will remove the input to SSR1 and SSR2.
        function laserDisable(LB)
            putvalue(LB.dIO.Line(6),0);
            putvalue(LB.dIO.Line(5),0);
        end
        
        
    end % END PUBLIC METHODS
end % END CLASSDEF LaserBox