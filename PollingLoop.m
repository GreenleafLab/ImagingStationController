%#########################################################################
% PollingLoop
% Object to manage a timer loop to execute commands on a regular interval.
% This is a frequently necessary workaround of the single-threaded nature
% of MATLAB when multiple threads of execution would normally be employed.
% Written by Curtis Layton 03/2013
%#########################################################################

classdef PollingLoop < handle
    
    properties
        pollingLoopList;
    end %END PROPERTIES
    
    properties %(Access = private)
        pollingLoopTimer;
        pollingLoopIndex;
    end %END PRIVATE PROPERTIES
    
    methods
        
        function pollingLoopObj = PollingLoop()
            pollingLoopObj.pollingLoopTimer = timer();
            pollingLoopObj.pollingLoopList = containers.Map();
            pollingLoopObj.pollingLoopIndex = 1;
            
            set(pollingLoopObj.pollingLoopTimer, 'StartDelay', 0);
            set(pollingLoopObj.pollingLoopTimer, 'TimerFcn', @pollingLoopObj.mainPollingLoop);
            set(pollingLoopObj.pollingLoopTimer, 'ExecutionMode', 'FixedRate');
            set(pollingLoopObj.pollingLoopTimer, 'Period', 0.1);
            start(pollingLoopObj.pollingLoopTimer);
        end
               
        function mainPollingLoop(pollingLoopObj, timer, event)
            keyset = keys(pollingLoopObj.pollingLoopList);
            listLength = length(keyset);
            
            if(listLength > 0) %if there are tasks in the update list
                if(pollingLoopObj.pollingLoopIndex > listLength)
                    pollingLoopObj.pollingLoopIndex = 1;
                end
                currKey = keyset(pollingLoopObj.pollingLoopIndex);
                currKey = currKey{1};
                currPollingLoopItem = pollingLoopObj.pollingLoopList(currKey);
                currElapsedTime = currPollingLoopItem.getIntervalTime();
                if(currElapsedTime > currPollingLoopItem.pollingInterval)
                    %execute the function
                    currFunctionHandle = currPollingLoopItem.functionHandle;
                    currArgs = currPollingLoopItem.args;
                    currFunctionHandle(currArgs);
                    %reset the timer
                    currPollingLoopItem.resetIntervalTime();
                end
                pollingLoopObj.pollingLoopIndex = pollingLoopObj.pollingLoopIndex + 1;
            end
        end
                
        function stopPollingLoop(pollingLoopObj)
            stop(pollingLoopObj.pollingLoopTimer);
            delete(pollingLoopObj.pollingLoopTimer);
        end
        
        function addToPollingLoop(pollingLoopObj, functionHandle, args, key, pollingInterval, executionsRemaining)
            if(~exist('executionsRemaining','var'))
                executionsRemaining = -99; %-99 is a flag to iterate indefinitely until removed
            end
            newPollingLoopItem = PollingLoopItem(functionHandle, args, pollingInterval, executionsRemaining);
            pollingLoopObj.pollingLoopList(key) = newPollingLoopItem;
        end
        
        function removeFromPollingLoop(pollingLoopObj, key)
            remove(pollingLoopObj.pollingLoopList, key);
        end

        function TF = isInPollingList(pollingLoopObj, queryKey)
            TF = isKey(pollingLoopObj.pollingLoopList, queryKey);
        end
        
    end % END METHODS
    
end %END CLASS PollingLoop