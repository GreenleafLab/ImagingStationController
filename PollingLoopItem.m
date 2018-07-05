classdef PollingLoopItem < handle
    
    properties
        functionHandle;
        args;
        pollingInterval;
        executionsRemaining;
        intervalTime;
        totalTime;
    end
    
    methods
        function PLI = PollingLoopItem(functionHandle, args, pollingInterval, executionsRemaining)
            PLI.functionHandle = functionHandle;
            PLI.args = args;
            PLI.pollingInterval = pollingInterval;
            if(~exist('executionsRemaining','var'))
                PLI.executionsRemaining = -99; %-99 is a flag to iterate indefinitely
            else
                PLI.executionsRemaining = executionsRemaining;
            end
            PLI.totalTime = tic; %start time
            PLI.intervalTime = tic; %start time
        end
        
        function intervalTime = getIntervalTime(PLI)
            intervalTime = toc(PLI.intervalTime);
        end
        
        function resetIntervalTime(PLI)
            PLI.intervalTime = tic;
        end
        
        function elapsedTime = getElapsedTime(PLI)
            elapsedTime = toc(PLI.totalTime);
        end
    end
end

