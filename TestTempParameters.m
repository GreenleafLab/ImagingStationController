% Script to test temperature parameters--the three parameters will be
% randomly set within their range of values


% Initialize alarms
myGui.guiElements.guiPanelTempObj.hardware.peltier.shutdownIfAlarmOn();
myGui.guiElements.guiPanelTempObj.hardware.peltier.alarmLatchOn();
myGui.guiElements.guiPanelTempObj.hardware.peltier.setHighAlarm(75);
% Initialize an array to store the results
parameters = zeros(24,3);


for n = 1:24
    
    % Randomly choose the parameters
    proportional = 100*rand;
    integralgain = 10*rand;
    derivativegain = 10*rand;
    
    % Save the parameters to a matrix
    parameters(n,1:3) = [proportional, integralgain, derivativegain]
    
    % Set the parameters
    myGui.guiElements.guiPanelTempObj.hardware.peltier.setProportionalBandwidth(proportional);
    myGui.guiElements.guiPanelTempObj.hardware.peltier.setIntegralGain(integralgain);
    myGui.guiElements.guiPanelTempObj.hardware.peltier.setDerivativeGain(derivativegain);
    
    % Set the temperature to 30 and wait for 20 minutes
    myGui.guiElements.guiPanelTempObj.hardware.peltier.setTemp(30);
    pause(20*60);
    
    % Set the temperature to 50 and wait for 20 minutes
    myGui.guiElements.guiPanelTempObj.hardware.peltier.setTemp(50);
    pause(20*60);
end
