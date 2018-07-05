%#########################################################################
% UserWaitCommand
% ImagingStationController command to prompt the user with a dialogue box
% Written by Curtis Layton 10/2012
%#########################################################################

classdef UserWaitCommand < ControlCommand
    
    properties % PROPERTIES
        dialogHandle;
    end % END PROPERTIES
    
    
    properties (Access = private) % PRIVATE METHODS
        dialogFlag; %flag to indicate whether dialog is currently open
    end % END PRIVATE METHODS
    
    
    methods % PUBLIC METHODS
        function command = UserWaitCommand(hardware, message, timeout)
            CheckParam.isString(message, 'UserWaitCommand:UserWaitCommand:badInputs');
            if(~exist('timeout','var'))
                timeout = 0; %0 is a flag to never timeout
            else
                CheckParam.isInteger(timeout, 'UserWaitCommand:UserWaitCommand:badInputs');
            end
            
            command = command@ControlCommand(hardware, 'userwait', 'prompt the user with a dialogue box and wait'); %call parent constructor

            command.parameters.message = message; %message to be displayed in the dialogue box
            command.parameters.timeout = timeout; %if provided, the dialogue box will automatically close and continue after this timeout period (in seconds)
            command.dialogFlag = false;
        end
        
        function execute(command, scriptDepth, depthIndex)
            if(~exist('depthIndex','var'))
                depthIndex = 1;
            end
            
            %get a local copy of parameters that will be used
            %the 'getParameter' method substitutes any loop variables for this iteration
            message = command.getParameter('message', depthIndex);
            timeout = command.getParameter('timeout', depthIndex);

            command.dialogFlag = true;
            command.dialogHandle = msgbox(message, 'User Wait', 'modal');
            try
                set(command.dialogHandle, 'DeleteFcn', @command.releaseDialogFlag);

                if(timeout ~= 0)
                    timeoutTimer = timer('ExecutionMode','singleShot','StartDelay',timeout,'TimerFcn',@command.killDialog);
                    start(timeoutTimer);
                end

                uiwait(command.dialogHandle);
                
                if(timeout ~= 0)
                    stop(timeoutTimer);
                    delete(timeoutTimer);
                end
            catch err
                if(~strcmp(err.identifier, 'MATLAB:class:InvalidHandle') && ~strcmp(err.identifier, 'MATLAB:UndefinedFunction')) %errors associated with closing the window
                    rethrow(err);
                end
            end
        end
        
        function killDialog(command, timer, event)
            close(command.dialogHandle);
        end
        
        function releaseDialogFlag(command, dialog, event)
            command.dialogFlag = false;
            delete(dialog);
        end
        
    end % END PUBLIC METHODS
    
end