%#########################################################################
% TempCommand
% ImagingStationController command for temperature control
% Written by Curtis Layton 10/2012
%#########################################################################

classdef TempSpecialCommand < ControlCommand
    
    properties % PROPERTIES
        
    end % END PROPERTIES
    
    
    methods (Access = private) % PRIVATE METHODS
        
    end % END PRIVATE METHODS
    
    
    methods % PUBLIC METHODS
        function command = TempSpecialCommand(hardware, setTempSpecial, rampRate, waitTillComplete)
            CheckParam.isNumeric(setTempSpecial, 'TempSpecialCommand:TempSpecialCommand:badInputs');
            if(~exist('rampRate','var'))
                rampRate = 0; %rampRate=0 is a flag not to ramp, but to move to the new temperature as quickly as possible
            else
                CheckParam.isNumeric(rampRate, 'TempSpecialCommand:TempSpecialCommand:badInputs');
            end
            if(~exist('waitTillComplete','var'))
                waitTillComplete = false;
            else
                CheckParam.isBoolean(waitTillComplete, 'TempSpecialCommand:TempSpecialCommand:badInputs');
            end
            
            command = command@ControlCommand(hardware, 'tempSpecial', 'change temperature'); %call parent constructor

            command.parameters.setTempSpecial = setTempSpecial; %new set temperature
            command.parameters.rampRate = rampRate; %ramp rate in °C/min
            command.parameters.waitTillComplete = waitTillComplete; %boolean--wait until set temperature is reached to return control?
        end
        
        function execute(command, scriptDepth, depthIndex)
            if(~exist('depthIndex','var'))
                depthIndex = 1;
            end
            
            rampRate = command.getParameter('rampRate', depthIndex);
            setTempSpecial = command.getParameter('setTempSpecial', depthIndex);
            waitTillComplete = command.getParameter('waitTillComplete', depthIndex);            
            
            if(rampRate == 0)
                %move directly to the new set temp
                command.hardware.peltier.setTempSpecial(setTempSpecial); %set the new setTemp
            else
                %ramp to the target set temp at the specified ramp rate
                command.hardware.peltier.rampTempLinear(setTempSpecial, rampRate)
            end

            if(waitTillComplete)
                command.hardware.peltier.waitUntilTemperatureReached();
            end
        end
     
    end % END PUBLIC METHODS
    
end