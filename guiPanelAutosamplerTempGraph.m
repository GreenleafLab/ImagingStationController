% Fluorescence Imaging Machine GUI
% Curtis Layton
% October, November 2012
% March 2013

% This code has only been tested with MATLAB R2010b, Version 7.11.0.584
% (32-bit Windows). Many of the GUI functions are MATLAB-version-dependent.


classdef guiPanelAutosamplerTempGraph < handle
    
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
        
        function updateTemperatureHistory(guiPanelAutosamplerTempGraphObj, args)
            try
                %update the temperature history graph
                guiPanelAutosamplerTempGraphObj.updateGraph();
            catch err
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
        function guiPanelAutosamplerTempGraphObj = guiPanelAutosamplerTempGraph(hardware, testMode, parent, position, bgcolor, pollingLoop, guiPanelStatusbarObj) %constructor
            % Startup code
            guiPanelAutosamplerTempGraphObj.testMode = testMode;
            guiPanelAutosamplerTempGraphObj.parent = parent;
            guiPanelAutosamplerTempGraphObj.position = position;
            guiPanelAutosamplerTempGraphObj.guiElements.bgcolor = bgcolor;
            guiPanelAutosamplerTempGraphObj.guiPanelStatusbarObj = guiPanelStatusbarObj;
            
            if (~guiPanelAutosamplerTempGraphObj.testMode)
                guiPanelAutosamplerTempGraphObj.hardware = hardware;
                
                guiPanelAutosamplerTempGraphObj.pollingLoop = pollingLoop;
            end
      
            guiPanelAutosamplerTempGraphObj.setupGui();
            
            guiPanelAutosamplerTempGraphObj.pollingLoop.addToPollingLoop(@guiPanelAutosamplerTempGraphObj.updateTemperatureHistory, {}, 'updateAutosamplerTemperatureHistory', 0.5);
        end
            
        function setupGui(guiPanelAutosamplerTempGraphObj)
            %Display temperature panel
            guiPanelAutosamplerTempGraphObj.guiElements.pnlDisplayTemp = uipanel(guiPanelAutosamplerTempGraphObj.parent, 'title', '', 'units', 'normalized', 'position', guiPanelAutosamplerTempGraphObj.position);

            guiPanelAutosamplerTempGraphObj.guiElements.hDisplayTemp = axes('parent', guiPanelAutosamplerTempGraphObj.guiElements.pnlDisplayTemp);
                set(guiPanelAutosamplerTempGraphObj.guiElements.hDisplayTemp, 'position', [0.08 0.23 0.9 0.73]);
                set(guiPanelAutosamplerTempGraphObj.guiElements.hDisplayTemp, 'FontSize', 8);
                set(guiPanelAutosamplerTempGraphObj.guiElements.hDisplayTemp, 'Xlim', [0 guiPanelAutosamplerTempGraphObj.temperatureTimeWindow]);
                set(guiPanelAutosamplerTempGraphObj.guiElements.hDisplayTemp, 'XlimMode', 'manual');
                xTickInterval = round(guiPanelAutosamplerTempGraphObj.temperatureTimeWindow/20);
                set(guiPanelAutosamplerTempGraphObj.guiElements.hDisplayTemp, 'XTick', GuiFun.getTicks(0, guiPanelAutosamplerTempGraphObj.temperatureTimeWindow, xTickInterval));
                set(guiPanelAutosamplerTempGraphObj.guiElements.hDisplayTemp, 'XMinorTick', 'on');
                xlabel(guiPanelAutosamplerTempGraphObj.guiElements.hDisplayTemp, 'time (s)');
                set(guiPanelAutosamplerTempGraphObj.guiElements.hDisplayTemp, 'Ylim', [-1 11]);
                set(guiPanelAutosamplerTempGraphObj.guiElements.hDisplayTemp, 'YlimMode', 'manual');
                set(guiPanelAutosamplerTempGraphObj.guiElements.hDisplayTemp, 'YTick', GuiFun.getTicks(0, 10, 2));
                set(guiPanelAutosamplerTempGraphObj.guiElements.hDisplayTemp, 'YMinorTick', 'on');
                set(guiPanelAutosamplerTempGraphObj.guiElements.hDisplayTemp, 'YGrid', 'on');
                ylabel(guiPanelAutosamplerTempGraphObj.guiElements.hDisplayTemp, '°C');
                set(guiPanelAutosamplerTempGraphObj.guiElements.hDisplayTemp, 'NextPlot', 'replacechildren');
            guiPanelAutosamplerTempGraphObj.guiElements.lblManualTemp = uicontrol(guiPanelAutosamplerTempGraphObj.guiElements.pnlDisplayTemp, 'style', 'text', 'string', '', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.01 0 0.2 0.1 ], 'backgroundcolor', guiPanelAutosamplerTempGraphObj.guiElements.bgcolor);
            guiPanelAutosamplerTempGraphObj.guiElements.lblManualTempCurr = uicontrol(guiPanelAutosamplerTempGraphObj.guiElements.pnlDisplayTemp, 'style', 'text', 'string', '', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.15 0 0.3 0.1 ], 'backgroundcolor', guiPanelAutosamplerTempGraphObj.guiElements.bgcolor);
            guiPanelAutosamplerTempGraphObj.guiElements.lblManualTempCurr2 = uicontrol(guiPanelAutosamplerTempGraphObj.guiElements.pnlDisplayTemp, 'style', 'text', 'string', '', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.30 0 0.45 0.1 ], 'backgroundcolor', guiPanelAutosamplerTempGraphObj.guiElements.bgcolor);
            %guiPanelAutosamplerTempGraphObj.guiElements.lblManualTempRamp = uicontrol(guiPanelAutosamplerTempGraphObj.guiElements.pnlDisplayTemp, 'style', 'text', 'string', '', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.73 0 0.35 0.1 ], 'backgroundcolor', guiPanelAutosamplerTempGraphObj.guiElements.bgcolor);
            %figure(2);
            guiPanelAutosamplerTempGraphObj.updateGraph(true);
            
        end
        
        function updateGraph(guiPanelAutosamplerTempGraphObj, retryOnBlock)
            if(~exist('retryOnBlock', 'var'))
                retryOnBlock = false;
            end
           % xlabel(guiPanelAutosamplerTempGraphObj.guiElements.hDisplayTemp, 'time (s)');
            set(guiPanelAutosamplerTempGraphObj.guiElements.hDisplayTemp, 'YTick', GuiFun.getTicks(0, 10, 2));
            set(guiPanelAutosamplerTempGraphObj.guiElements.hDisplayTemp, 'Ylim', [-0.2 10.2]);
            if (~guiPanelAutosamplerTempGraphObj.testMode)
                
                currTemp = guiPanelAutosamplerTempGraphObj.hardware.autosamplerPeltier.getCurrentTemp(retryOnBlock);
                if(~strcmp(currTemp,'__BLOCKED_'))
                    currTempLabel = sprintf('Base plate =%.1f°C', currTemp);
                    set(guiPanelAutosamplerTempGraphObj.guiElements.lblManualTempCurr, 'String', currTempLabel); %update curr temp label
                end
                
                currTemp2 = guiPanelAutosamplerTempGraphObj.hardware.autosamplerPeltier.getCurrentTemp2(retryOnBlock);
                if(~strcmp(currTemp2,'__BLOCKED_'))
                    currTempLabel2 = sprintf('Side, bad thermistor=%.1f°C', currTemp2);
                    set(guiPanelAutosamplerTempGraphObj.guiElements.lblManualTempCurr2, 'String', currTempLabel2); %update curr temp label
                end
                
                %rampLabel = '';
                %if(guiPanelAutosamplerTempGraphObj.hardware.peltier.isCurrentlyRamping()) %if ramping
                %    currSetTemp = guiPanelAutosamplerTempGraphObj.hardware.peltier.rampDestinationTemperature;
                %    rampRate = guiPanelAutosamplerTempGraphObj.hardware.peltier.rampRate;
                %    rampLabel = sprintf('ramping at %.4f°C/min', rampRate);
                %else %if not ramping
                    
                %end
                %set(guiPanelAutosamplerTempGraphObj.guiElements.lblManualTempRamp, 'String',rampLabel); %update ramp rate label
                currSetTemp = guiPanelAutosamplerTempGraphObj.hardware.autosamplerPeltier.getSetTemp(retryOnBlock);
                if(~strcmp(currSetTemp,'__BLOCKED_'))
                    setTempLabel = sprintf('set=%.1f°C', currSetTemp);
                    set(guiPanelAutosamplerTempGraphObj.guiElements.lblManualTemp, 'String', setTempLabel); %update set temp label
                end

                %get temperature history from hardware
                temperatureHistory = guiPanelAutosamplerTempGraphObj.hardware.autosamplerPeltier.temperatureHistory;

                %plot current temperature history in graph
                
                spacer = guiPanelAutosamplerTempGraphObj.temperatureTimeWindow/10;
                lastTime = ceil(temperatureHistory.time(end) + spacer);
                if(lastTime > guiPanelAutosamplerTempGraphObj.temperatureTimeWindow)
                    windowStart = lastTime - guiPanelAutosamplerTempGraphObj.temperatureTimeWindow;
                    set(guiPanelAutosamplerTempGraphObj.guiElements.hDisplayTemp, 'Xlim', [windowStart lastTime]);
                    xTickInterval = round(guiPanelAutosamplerTempGraphObj.temperatureTimeWindow/20);
                    set(guiPanelAutosamplerTempGraphObj.guiElements.hDisplayTemp, 'XTick', GuiFun.getTicks(windowStart, lastTime, xTickInterval));
                end
                plot(guiPanelAutosamplerTempGraphObj.guiElements.hDisplayTemp,...
                    temperatureHistory.time, temperatureHistory.setTemp, 'k',...
                    temperatureHistory.time, temperatureHistory.temp,...
                    temperatureHistory.time, temperatureHistory.temp2, 'r',...
                    temperatureHistory.time, 5+0.05*100/5.11*temperatureHistory.outputPower, 'g');
                %JA: No separate plot window.
                %set(0,'CurrentFigure',2)
                % plot(...
                %    temperatureHistory.time, temperatureHistory.temp,...
                %    temperatureHistory.time, temperatureHistory.temp2, 'r',...
                %    temperatureHistory.time, 10*temperatureHistory.outputPower, 'g',...
                %    temperatureHistory.time, temperatureHistory.setTemp, 'k');
               %axis([0 lastTime 30 75]);
            else
                setTempLabel = sprintf('set=XXX.X°C');
                set(guiPanelAutosamplerTempGraphObj.guiElements.lblManualTemp, 'String', setTempLabel); %update set temp label
                currTempLabel = sprintf('curr=XXX.X°C');
                set(guiPanelAutosamplerTempGraphObj.guiElements.lblManualTempCurr, 'String', currTempLabel); %update curr temp label
                %rampLabel = sprintf('ramping at XXX.XXXX°C/min');
                %set(guiPanelAutosamplerTempGraphObj.guiElements.lblManualTempRamp, 'String',rampLabel); %update ramp rate label
            end

        end
        
        %function guiPanelTempGraph=set.temperatureTimeWindow(guiPanelTempGraph,value)
        %        guiPanelTempGraph.temperatureTimeWindow=value;
        %end
    end % END PUBLIC METHODS
end % END GUI CLASS 