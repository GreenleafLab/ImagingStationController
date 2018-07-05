
%TODO - test with another program connected to one of the ports


function ImagingStationController
    instrreset;
    delete(timerfind);
    
    hardware = ImagingStationHardware();

%     units = hardware.peltier.getUnits()
%     setTemp = hardware.peltier.getSetTemp()
%     temp = hardware.peltier.getCurrentTemp()
%     
%     hardware.peltier.setProportionalBandwidth(15);
%     hardware.peltier.setIntegralGain(6);
%     hardware.peltier.setDerivativeGain(.1);
%        
%     close(findobj('type','figure'));
%     fig99 = figure(99);
%     set(fig99, 'Position', [50 250 1200 600]);
     
%     hardware.stageAndFilterWheel.moveX(-600000);
%     hardware.stageAndFilterWheel.moveY(-600000);
%     hardware.stageAndFilterWheel.moveZ(-350000);
%     hardware.stageAndFilterWheel.moveFilterWheel('1','1'); pause on; pause(0.5);
%     hardware.stageAndFilterWheel.moveFilterWheel('1','2'); pause on; pause(0.5);
%     hardware.stageAndFilterWheel.moveFilterWheel('1','3'); pause on; pause(0.5);
%     hardware.stageAndFilterWheel.moveFilterWheel('1','6'); pause on; pause(0.5);
%     hardware.stageAndFilterWheel.moveFilterWheel('0','4'); pause on; pause(0.5);
%     hardware.stageAndFilterWheel.moveFilterWheel('0','2'); pause on; pause(0.5);
%     hardware.stageAndFilterWheel.moveFilterWheel('0','3'); pause on; pause(0.5);
%     hardware.stageAndFilterWheel.moveFilterWheel('0','6'); pause on; pause(0.5);
%     hardware.stageAndFilterWheel.moveFilterWheel('0','4'); pause on; pause(0.5);
%     
%     pos = hardware.selectorValve.getPosition()
%     rotDir = hardware.selectorValve.getRotationalDirection()
%     pos = hardware.selectorValve.getPosition()
%     hardware.selectorValve.setPosition(1);
%     pos = hardware.selectorValve.getPosition()
%     hardware.selectorValve.setPosition(7);
%     pos = hardware.selectorValve.getPosition()
%     hardware.selectorValve.setPosition(5);
%     pos = hardware.selectorValve.getPosition()
%     hardware.selectorValve.setPosition(6);
%     pos = hardware.selectorValve.getPosition()
%     hardware.selectorValve.setPosition(1);
%     pos = hardware.selectorValve.getPosition()
%     np = hardware.selectorValve.getNumPositions()
%     
%     hardware.pump.pump(750, hardware.pump.maxFlowRate);
%     
%     pause on; pause(5);
%     for i=1:10
%         hardware.lasers.switchRed();
%         redPower = hardware.lasers.redGetPower()
%         
%         exposure = 15 * i;
%         hardware.camera.setExposure(exposure);
%         hardware.camera.acquireImage();
% 
%         subplot(1,2,2);
%         imshow(hardware.camera.img, [hardware.camera.minValue hardware.camera.maxValue]);
%         
%         pause on; pause(0.5);
%         
%         hardware.lasers.switchGreen();
%         greenPower = hardware.lasers.greenGetPower()
%         pause on; pause(0.5);
%         
%         hardware.lasers.switchOff();
%         pause on; pause(0.5);
%     end
%     
      
    
%     commandList = CommandList(); %the commandList is the main list of commands
%     
%     subList = containers.Map(); % map of subroutines
%     
%     
%     
%     
%     
%     % create a sub
%     sub1 = SubCommand(hardware, 'testSub');
%     
%     sub1.addVariable('firstVolume', 'num');
% 
%     
%     %create an outer loop with 4 iterations
%     loop1 = LoopCommand(hardware, 1);
%         
%         %create some loop variables for the outer loop
%         loop1.addVariable('aspirationRate', 'num');
%         loop1.assignVariableValues('aspirationRate', {300});
% 
%         loop1.addVariable('temperature', 'num');
%         loop1.assignVariableValues('temperature', {35});
%         
%         %add a commmand to the outer loop
% %        command = TempCommand(hardware, loop1.getVariable('temperature'), 0, true);
% %        loop1.commandList.addCommand(command);
%         
%         command = PumpCommand(hardware, sub1.getVariable('firstVolume'), 450, 1, true);  
%         loop1.commandList.addCommand(command);
%         
%         %create an inner loop with 2 iterations
%         loop2 = LoopCommand(hardware, 1);
%         
%             %create some loop variables for the inner loop
%             loop2.addVariable('volume', 'num');
%             loop2.assignVariableValues('volume', {100});
%             
%             loop2.addVariable('position', 'num');
%             loop2.assignVariableValues('position', {1});
%         
%             %add a command to the inner loop
%             command = UserWaitCommand(hardware, 'mid-loop pause', 20);
%             loop2.commandList.addCommand(command);
%             
%             command = PumpCommand(hardware, loop2.getVariable('volume'), loop1.getVariable('aspirationRate'), loop2.getVariable('position'), true);  
%             loop2.commandList.addCommand(command);
%             
%         %add the inner loop to the outer loop
%         loop1.commandList.addCommand(loop2);
%         
%         command = WaitCommand(hardware, 10);
%         loop1.commandList.addCommand(command);
%         
%     %add the outer loop to the sub  
%     sub1.commandList.addCommand(loop1);
%     
%     
%     subList('testSub') = sub1;
%     
%     
%     
%     %create a command and add it to the list
%     command = UserWaitCommand(hardware, 'mid-loop pause', 20);
%     commandList.addCommand(command);
% 
%     command = PumpCommand(hardware, 100, 300, 1, true);  
%     commandList.addCommand(command);
% 
%     command = WaitCommand(hardware, 10);
%     commandList.addCommand(command);
%     
%     command = UserWaitCommand(hardware, 'mid-loop pause', 20);
%     commandList.addCommand(command);
% 
%     command = PumpCommand(hardware, 100, 300, 1, true);  
%     commandList.addCommand(command);
% 
%     command = WaitCommand(hardware, 10);
%     commandList.addCommand(command);
%     
% 
%     
%     %now add the sub to the main commandList  
%     subCC = SubCallCommand(hardware, sub1);
%     subCC.assignVariableValues('firstVolume',{111});
%     commandList.addCommand(subCC);
%     
%     %add another command to the commandList   
%     command = PumpCommand(hardware, 66, 666, 1, true); 
%     commandList.addCommand(command);
% 
%     %now add the sub to the main commandList  
%     subCC = SubCallCommand(hardware, sub1);
%     subCC.assignVariableValues('firstVolume',{222});
%     commandList.addCommand(subCC);
%     
%     
%     %hit the 'run' button and watch it go
%     %commandList.execute();
%     
%     script = getXMLScript(subList, commandList)
%     
%     outFilename = 'c:\testOut.dat';
%     
%     outFile = fopen(outFilename, 'w');
%     fprintf(outFile, '%s', script);
%     fclose(outFile);
    
    [commandList, subList] = xml2struct('c:\testOut.dat', hardware);
    
    script = getXMLScript(commandList, subList)
    
    commandList.execute()
    
    %ensure we don't leave the temperature set hot
    %hardware.peltier.setTemp(25);


    
    hardware.disconnect();
end

function script = getXMLScript(commandList, subList)

    CR = sprintf('\n');
    
    script = sprintf('<ImagingStationScript>\n');
    
    keyList = keys(subList);
    for i = 1:length(subList)
        currSub = subList(keyList{i})
        script = [script currSub.getScript() CR];
    end
    
    close = sprintf('</ImagingStationScript>\n');
    script = [script commandList.getScript() close];
end
