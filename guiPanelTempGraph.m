% Fluorescence Imaging Machine GUI
% Curtis Layton
% October, November 2012
% March 2013

% This code has only been tested with MATLAB R2010b, Version 7.11.0.584
% (32-bit Windows). Many of the GUI functions are MATLAB-version-dependent.


classdef guiPanelTempGraph < handle
    
    properties % PROPERTIES
        hardware; %reference to the hardware object
        guiElements;
        parent; % control that houses this panel
        position; % position of this panel within its parent

        pollingLoop; % polling loop object
        guiPanelStatusbarObj; % status bar object, for writing status updates to

        testMode; % if testMode = 1, then code won't try interact with the hardware (used for testing GUI code)
        temperatureTimeWindow = 600;
    end % END PROPERTIES
    
    properties (Constant) % CONSTANT PROPERTIES
        
%        temperatureTimeWindow = 600;
        
    end % CONSTANT PROPERTIES
    
    
    methods (Access = private) % PRIVATE METHODS

        %######## BEGIN functions that are called by the polling loop (timer) #######
        
        function updateTemperatureHistory(guiPanelTempGraphObj, args)
            try
                %update the temperature history graph
                guiPanelTempGraphObj.updateGraph();
            catch err
                disp(['guiPanelTempGraph:updateTemperatureHistory::', err.identifier])
                if(~strcmp(err.identifier, 'TC_36_25_RS232_PeltierController:getSerialResponse:Timeout'))
                    rethrow(err);
                end
            end
        end
                        
        %######## END functions that are called by the polling loop (timer) #######
        
    end % END PRIVATE METHODS
    
    
    methods % PUBLIC METHODS

        % hardware: reference to ImagingStationHardware instance
        % testMode: GUI testing mode on/off
        % parent: GUI object that will be the container for this panel
        % position: position to place panel within parent
        % bgcolor: background color of GUI elements
        % pollingLoop: reference to PollingLoop instance in owner GUI, which makes callbacks when particular operations finish
        % guiPanelStatusbarObj: reference to a status bar panel on the GUI to write status updates to
        function guiPanelTempGraphObj = guiPanelTempGraph(hardware, testMode, parent, position, bgcolor, pollingLoop, guiPanelStatusbarObj) %constructor
            % Startup code
            guiPanelTempGraphObj.testMode = testMode;
            guiPanelTempGraphObj.parent = parent;
            guiPanelTempGraphObj.position = position;
            guiPanelTempGraphObj.guiElements.bgcolor = bgcolor;
            guiPanelTempGraphObj.guiPanelStatusbarObj = guiPanelStatusbarObj;
            
            if (~guiPanelTempGraphObj.testMode)
                guiPanelTempGraphObj.hardware = hardware;
                
                guiPanelTempGraphObj.pollingLoop = pollingLoop;
            end
      
            guiPanelTempGraphObj.setupGui();
            
            guiPanelTempGraphObj.pollingLoop.addToPollingLoop(@guiPanelTempGraphObj.updateTemperatureHistory, {}, 'updateTemperatureHistory', 1);
        end
            
        function setupGui(guiPanelTempGraphObj)
            %Display temperature panel
            guiPanelTempGraphObj.guiElements.pnlDisplayTemp = uipanel(guiPanelTempGraphObj.parent, 'title', '', 'units', 'normalized', 'position', guiPanelTempGraphObj.position);

            guiPanelTempGraphObj.guiElements.hDisplayTemp = axes('parent', guiPanelTempGraphObj.guiElements.pnlDisplayTemp);
                set(guiPanelTempGraphObj.guiElements.hDisplayTemp, 'position', [0.08 0.23 0.9 0.73]);
                set(guiPanelTempGraphObj.guiElements.hDisplayTemp, 'FontSize', 8);
                set(guiPanelTempGraphObj.guiElements.hDisplayTemp, 'Xlim', [0 guiPanelTempGraphObj.temperatureTimeWindow]);
                set(guiPanelTempGraphObj.guiElements.hDisplayTemp, 'XlimMode', 'manual');
                xTickInterval = round(guiPanelTempGraphObj.temperatureTimeWindow/20);
                set(guiPanelTempGraphObj.guiElements.hDisplayTemp, 'XTick', GuiFun.getTicks(0, guiPanelTempGraphObj.temperatureTimeWindow, xTickInterval));
                set(guiPanelTempGraphObj.guiElements.hDisplayTemp, 'XMinorTick', 'on');
                xlabel(guiPanelTempGraphObj.guiElements.hDisplayTemp, 'time (s)');
                set(guiPanelTempGraphObj.guiElements.hDisplayTemp, 'Ylim', [20 80]);
                set(guiPanelTempGraphObj.guiElements.hDisplayTemp, 'YlimMode', 'manual');
                set(guiPanelTempGraphObj.guiElements.hDisplayTemp, 'YTick', GuiFun.getTicks(20, 80, 10));
                set(guiPanelTempGraphObj.guiElements.hDisplayTemp, 'YMinorTick', 'on');
                set(guiPanelTempGraphObj.guiElements.hDisplayTemp, 'YGrid', 'on');
                ylabel(guiPanelTempGraphObj.guiElements.hDisplayTemp, '°C');
                set(guiPanelTempGraphObj.guiElements.hDisplayTemp, 'NextPlot', 'replacechildren');
            guiPanelTempGraphObj.guiElements.lblManualTemp = uicontrol(guiPanelTempGraphObj.guiElements.pnlDisplayTemp, 'style', 'text', 'string', '', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.01 0 0.2 0.1 ], 'backgroundcolor', guiPanelTempGraphObj.guiElements.bgcolor);
            guiPanelTempGraphObj.guiElements.lblManualTempCurr = uicontrol(guiPanelTempGraphObj.guiElements.pnlDisplayTemp, 'style', 'text', 'string', '', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.15 0 0.3 0.1 ], 'backgroundcolor', guiPanelTempGraphObj.guiElements.bgcolor);
            guiPanelTempGraphObj.guiElements.lblManualTempCurr2 = uicontrol(guiPanelTempGraphObj.guiElements.pnlDisplayTemp, 'style', 'text', 'string', '', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.30 0 0.45 0.1 ], 'backgroundcolor', guiPanelTempGraphObj.guiElements.bgcolor);
            guiPanelTempGraphObj.guiElements.lblManualTempRamp = uicontrol(guiPanelTempGraphObj.guiElements.pnlDisplayTemp, 'style', 'text', 'string', '', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.73 0 0.35 0.1 ], 'backgroundcolor', guiPanelTempGraphObj.guiElements.bgcolor);
            %figure(2);
            guiPanelTempGraphObj.updateGraph(true);
            
        end
        
        function updateGraph(guiPanelTempGraphObj, retryOnBlock)
            try
            if(~exist('retryOnBlock', 'var'))
                retryOnBlock = false;
            end
           % xlabel(guiPanelTempGraphObj.guiElements.hDisplayTemp, 'time (s)');
            set(guiPanelTempGraphObj.guiElements.hDisplayTemp, 'YTick', GuiFun.getTicks(20, 80, 10));
            set(guiPanelTempGraphObj.guiElements.hDisplayTemp, 'Ylim', [19 80]);
            if (~guiPanelTempGraphObj.testMode)
                currTemp = guiPanelTempGraphObj.hardware.peltier.getCurrentTemp(retryOnBlock);
                
                if(~strcmp(currTemp,'__BLOCKED_'))
                    currTempLabel = sprintf('prism top=%.1f°C', currTemp);
                    set(guiPanelTempGraphObj.guiElements.lblManualTempCurr, 'String', currTempLabel); %update curr temp label
                end
                
                currTemp2 = guiPanelTempGraphObj.hardware.peltier.getCurrentTemp2(retryOnBlock);
                if(~strcmp(currTemp2,'__BLOCKED_'))
                    currTempLabel2 = sprintf('copper plate=%.1f°C', currTemp2);
                    set(guiPanelTempGraphObj.guiElements.lblManualTempCurr2, 'String', currTempLabel2); %update curr temp label
                end
                
                rampLabel = '';
                if(guiPanelTempGraphObj.hardware.peltier.isCurrentlyRamping()) %if ramping
                    currSetTemp = guiPanelTempGraphObj.hardware.peltier.rampDestinationTemperature;
                    rampRate = guiPanelTempGraphObj.hardware.peltier.rampRate;
                    rampLabel = sprintf('ramping at %.4f°C/min', rampRate);
                else %if not ramping
                    currSetTemp = guiPanelTempGraphObj.hardware.peltier.getSetTemp(retryOnBlock);
                end
                set(guiPanelTempGraphObj.guiElements.lblManualTempRamp, 'String',rampLabel); %update ramp rate label
                if(~strcmp(currSetTemp,'__BLOCKED_'))
                    setTempLabel = sprintf('set=%.1f°C', currSetTemp);
                    set(guiPanelTempGraphObj.guiElements.lblManualTemp, 'String', setTempLabel); %update set temp label
                end

                %get temperature history from hardware
                temperatureHistory = guiPanelTempGraphObj.hardware.peltier.temperatureHistory;

                %plot current temperature history in graph
                
                spacer = guiPanelTempGraphObj.temperatureTimeWindow/10;
                lastTime = ceil(temperatureHistory.time(end) + spacer);
                if(lastTime > guiPanelTempGraphObj.temperatureTimeWindow)
                    windowStart = lastTime - guiPanelTempGraphObj.temperatureTimeWindow;
                    set(guiPanelTempGraphObj.guiElements.hDisplayTemp, 'Xlim', [windowStart lastTime]);
                    xTickInterval = round(guiPanelTempGraphObj.temperatureTimeWindow/20);
                    set(guiPanelTempGraphObj.guiElements.hDisplayTemp, 'XTick', GuiFun.getTicks(windowStart, lastTime, xTickInterval));
                end
                plot(guiPanelTempGraphObj.guiElements.hDisplayTemp,...
                    temperatureHistory.time, temperatureHistory.temp,...
                    temperatureHistory.time, temperatureHistory.temp2, 'r',...
                    temperatureHistory.time, 100/5.11*temperatureHistory.outputPower, 'g',...
                    temperatureHistory.time, temperatureHistory.setTemp, 'k');
%                 set(0,'CurrentFigure',2)
%                  plot(...
%                     temperatureHistory.time, temperatureHistory.temp,...
%                     temperatureHistory.time, temperatureHistory.temp2, 'r',...
%                     temperatureHistory.time, 10*temperatureHistory.outputPower, 'g',...
%                     temperatureHistory.time, temperatureHistory.setTemp, 'k');
%                 axis([0 lastTime 15 75]);
            else
                setTempLabel = sprintf('set=XXX.X°C');
                set(guiPanelTempGraphObj.guiElements.lblManualTemp, 'String', setTempLabel); %update set temp label
                currTempLabel = sprintf('curr=XXX.X°C');
                set(guiPanelTempGraphObj.guiElements.lblManualTempCurr, 'String', currTempLabel); %update curr temp label
                rampLabel = sprintf('ramping at XXX.XXXX°C/min');
                set(guiPanelTempGraphObj.guiElements.lblManualTempRamp, 'String',rampLabel); %update ramp rate label
            end
            catch err
                disp(['Error: guiPanelTempGraph:updateGraph: ', err.identifier])
            end
        end
        
        %function guiPanelTempGraph=set.temperatureTimeWindow(guiPanelTempGraph,value)
        %        guiPanelTempGraph.temperatureTimeWindow=value;
        %end
    end % END PUBLIC METHODS
end % END GUI CLASS 