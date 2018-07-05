%#########################################################################
% WaitCommand
% ImagingStationController command to wait for a specified amount of time
% Written by Curtis Layton 10/2012
%#########################################################################

classdef WaitCommand < ControlCommand
    
    properties % PROPERTIES

    end % END PROPERTIES  
    
    methods (Access = private) % PRIVATE METHODS
        
    end % END PRIVATE METHODS
    
    
    methods % PUBLIC METHODS
        function command = WaitCommand(hardware, time)
            CheckParam.isInteger(time, 'WaitCommand:WaitCommand:badInputs');
         
            command = command@ControlCommand(hardware, 'wait', 'wait for a specified amount of time'); %call parent constructor

            command.parameters.time = time; %wait time (in seconds)
        end
        
        function execute(command, scriptDepth, depthIndex)
            if(~exist('depthIndex','var'))
                depthIndex = 1;
            end
            
            %get a local copy of parameters that will be used
            %the 'getParameter' method substitutes any loop variables for this iteration
            time = command.getParameter('time', depthIndex);

            pause on; pause(time);
        end
       
    end % END PUBLIC METHODS
    
end