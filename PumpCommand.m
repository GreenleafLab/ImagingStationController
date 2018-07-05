%#########################################################################
% PumpCommand
% ImagingStationController command for pumping through the fluidics
% interface
% Written by Curtis Layton 10/2012
%#########################################################################

classdef PumpCommand < ControlCommand
    
    properties % PROPERTIES

    end % END PROPERTIES
       
    methods (Access = private) % PRIVATE METHODS
        
    end % END PRIVATE METHODS
    
    methods % PUBLIC METHODS
        function command = PumpCommand(hardware, volume, flowRate, fromPosition, waitTillComplete)
            CheckParam.isNumeric(volume, 'PumpCommand:PumpCommand:badInputs');
            CheckParam.isNumeric(flowRate, 'PumpCommand:PumpCommand:badInputs');
            if(CheckParam.isInteger(fromPosition, 'PumpCommand:PumpCommand:badInputs'))
                errorMessage = sprintf('only selector valve positions %d to %d are valid', 1, hardware.selectorValve.getNumPositions());
                CheckParam.isWithinARange(fromPosition, 1, hardware.selectorValve.getNumPositions(), 'PumpCommand:PumpCommand:badInputs', errorMessage);
            end
            if(~exist('waitTillComplete','var'))
                waitTillComplete = false;
            else
                CheckParam.isBoolean(waitTillComplete, 'PumpCommand:PumpCommand:badInputs');
            end

            command = command@ControlCommand(hardware, 'pump', 'pump liquid through the fluidics interface'); %call parent constructor

            command.parameters.volume = volume; %volume to pump in uL
            command.parameters.flowRate = flowRate; %pump rate in uL/min
            command.parameters.fromPosition = fromPosition; %pump from this position on the selector valve
            command.parameters.waitTillComplete = waitTillComplete; %boolean--wait until pumping is complete to return control?
        end
        
        function execute(command, scriptDepth, depthIndex)
            if(~exist('depthIndex','var'))
                depthIndex = 1;
            end

            %get a local copy of parameters that will be used
            %the 'getParameter' method substitutes any variables (e.g. for
            %the current loop iteration)
            fromPosition = command.getParameter('fromPosition', depthIndex);
            volume = command.getParameter('volume', depthIndex);
            flowRate = command.getParameter('flowRate', depthIndex);
            waitTillComplete = command.getParameter('waitTillComplete', depthIndex);
            
            command.hardware.selectorValve.setPosition(fromPosition); %set the selector valve
            command.hardware.pump.pump(volume, flowRate);
            if(waitTillComplete)
                command.hardware.pump.waitUntilReady();
            end
        end
    end % END PUBLIC METHODS
    
end