% Function to compute the least squares error of the temperature controller

function error = temperatureerror(proportional, integralgain, derivativegain, HeatSideMultiplier, CoolSideMultiplier, myGui)
    
    % Specify the following parameters
    recordingPause = 10;
    initialPause1 = 0;
    initialPause2 = 0;
    % Set the desired temperature and time (in minutes) for each of the
    % three tests of the temperature control
    temp1 = 50;
    time1 = 10;
    temp2 = 30;
    time2 = 10;
    
    % Set the parameters
    myGui.guiElements.guiPanelTempObj.hardware.peltier.setProportionalBandwidth(proportional);
    myGui.guiElements.guiPanelTempObj.hardware.peltier.setIntegralGain(integralgain);
    myGui.guiElements.guiPanelTempObj.hardware.peltier.setDerivativeGain(derivativegain);
    myGui.guiElements.guiPanelTempObj.hardware.peltier.setCoolMultiplier(CoolSideMultiplier);
    myGui.guiElements.guiPanelTempObj.hardware.peltier.setHeatMultiplier(HeatSideMultiplier);
    
    % Initialize the number of error measurements made
    error = 0;
    readings = 0;
    
    [error, readings] = tempCycle(time1, temp1, error, recordingPause, initialPause1, myGui, readings);
    [error, readings] = tempCycle(time2, temp2, error, recordingPause, initialPause2, myGui, readings);
    error = error/readings;
end

function [error, readings] = tempCycle(cycleLength, cycleTemp, error, recordingPause, initialPause, myGui, readings)
    myGui.guiElements.guiPanelTempObj.hardware.peltier.setTemp(cycleTemp);
	pause(initialPause)
    record = 0;
    startTimer();
    while getElapsedTime() < cycleLength
        pause(recordingPause);
        if abs(cycleTemp-myGui.guiElements.guiPanelTempObj.hardware.peltier.getCurrentTemp())<1
            record = 1;
        end
        if record == 1
            error = error+(myGui.guiElements.guiPanelTempObj.hardware.peltier.getCurrentTemp()-cycleTemp)^2;
            readings = readings + 1;
        end
    end
    if error == 0
        error = 100000000;
        readings = 1;
    end
end
    
function startTimer()
    tic()
end

%returns the elapsed time since startTimer() was called in minutes
function elapsedTime = getElapsedTime()
    elapsedTime = toc()/60;
end