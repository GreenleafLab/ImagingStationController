% Fluorescence Imaging Machine GUI
% Curtis Layton
% October, November 2013
% March 2013

% This code has only been tested with MATLAB R2010b, Version 7.11.0.584
% (32-bit Windows). Many of the GUI functions are MATLAB-version-dependent.


classdef guiPanelTemp < handle
    
    properties % PROPERTIES
        hardware; %reference to the hardware object
        guiElements;
        parent; % control that houses this panel
        position; % position of this panel within its parent
        
        pollingLoop; % polling loop object
        guiPanelStatusbarObj; % status bar object, for writing status updates to
        
        testMode; % if testMode = 1, then code won't try interact with the hardware (used for testing GUI code)

    end % END PROPERTIES
    
    
    properties (Constant) % CONSTANT PROPERTIES
        
    end % CONSTANT PROPERTIES
    
    
    methods (Access = private) % PRIVATE METHODS
        
        %######## BEGIN functions that are called by the polling loop (timer) #######
        
        function updateTemperatureBox(guiPanelTempObj, args)
            try
                %externally update the fields to keep them current
                if(guiPanelTempObj.hardware.peltier.isCurrentlyRamping()) %if ramping
                    currSetTemp = guiPanelTempObj.hardware.peltier.rampDestinationTemperature;
                else %if not ramping
                    currSetTemp = guiPanelTempObj.hardware.peltier.getSetTemp(false);
                end
                if(~strcmp(currSetTemp,'__BLOCKED_'))
                    guiPanelTempObj.updateSetTempField(num2str(currSetTemp));
                    guiPanelTempObj.updateRampRateField(num2str(guiPanelTempObj.hardware.peltier.rampRate));
                end
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
        % guiPanelStatusbarObj: reference to a status bar panel on the GUI (if null, just gets ignored; otherwise write status updates to it)
        function guiPanelTempObj = guiPanelTemp(hardware, testMode, parent, position, bgcolor, pollingLoop, guiPanelStatusbarObj) %constructor
            % Startup code
            guiPanelTempObj.testMode = testMode;
            guiPanelTempObj.parent = parent;
            guiPanelTempObj.position = position;
            guiPanelTempObj.guiElements.bgcolor = bgcolor;
            guiPanelTempObj.guiPanelStatusbarObj = guiPanelStatusbarObj;
            
            if (~guiPanelTempObj.testMode)
                guiPanelTempObj.hardware = hardware;
                
                guiPanelTempObj.pollingLoop = pollingLoop;
            end
            
            guiPanelTempObj.setupGui();
            
            guiPanelTempObj.pollingLoop.addToPollingLoop(@guiPanelTempObj.updateTemperatureBox, {}, 'updateTemperatureBox', 2);
        end
            
        function setupGui(guiPanelTempObj)
            
            guiPanelTempObj.guiElements.pnlManualObjectTemp = uipanel(guiPanelTempObj.parent, 'title', 'Temp', 'units', 'normalized', 'position', guiPanelTempObj.position);
            guiPanelTempObj.guiElements.lblManualTempSetTemp = uicontrol(guiPanelTempObj.guiElements.pnlManualObjectTemp, 'style', 'text', 'string', 'Set Temp (°C):', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0 0.1 0.18 0.8 ], 'backgroundcolor', guiPanelTempObj.guiElements.bgcolor);
            if (~guiPanelTempObj.testMode)
                currSetTemp = guiPanelTempObj.hardware.peltier.getSetTemp();
            else
                currSetTemp = 25;
            end
            guiPanelTempObj.guiElements.txtManualTempSetTemp = uicontrol(guiPanelTempObj.guiElements.pnlManualObjectTemp, 'style', 'edit', 'string', num2str(currSetTemp), 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.19, 0.1, 0.12, 0.8 ], 'backgroundcolor', [1 1 1]);
            guiPanelTempObj.guiElements.JtxtManualTempSetTemp = findjobj(guiPanelTempObj.guiElements.txtManualTempSetTemp); % Java handle; can then use h.isFocusOwner to determine if this object has focus
            guiPanelTempObj.guiElements.lblManualTempRampRate = uicontrol(guiPanelTempObj.guiElements.pnlManualObjectTemp, 'style', 'text', 'string', 'Ramp Rate (°C/min):', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.45 0.1 0.2 0.8 ], 'backgroundcolor', guiPanelTempObj.guiElements.bgcolor);
            guiPanelTempObj.guiElements.txtManualTempRampRate = uicontrol(guiPanelTempObj.guiElements.pnlManualObjectTemp, 'style', 'edit', 'string', '0', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.66, 0.1, 0.15, 0.8 ], 'backgroundcolor', [1 1 1]);
            guiPanelTempObj.guiElements.JtxtManualTempRampRate = findjobj(guiPanelTempObj.guiElements.txtManualTempRampRate); % Java handle; can then use h.isFocusOwner to determine if this object has focus            
            set(guiPanelTempObj.guiElements.txtManualTempRampRate,'Enable','off');
            guiPanelTempObj.guiElements.btnManualTempRampToggle = uicontrol(guiPanelTempObj.guiElements.pnlManualObjectTemp, 'style', 'togglebutton', 'String', '<html><center>ramp<br>off<center>', 'units', 'normalized', 'FontSize', 7, 'position', [ 0.35, 0.1, 0.1, 0.67 ], 'backgroundcolor', [0.75 0.75 0.75], 'callback', @(command, varargin)guiPanelTempObj.btnManualTemp_callback('ramp'));
            guiPanelTempObj.guiElements.btnManualTempSet = uicontrol(guiPanelTempObj.guiElements.pnlManualObjectTemp, 'String', 'set', 'units', 'normalized', 'position', [ 0.83, 0.1, 0.15, 0.8 ], 'callback', @(command, varargin)guiPanelTempObj.btnManualTemp_callback('set'));
            
            set(guiPanelTempObj.guiElements.txtManualTempSetTemp, 'KeyPressFcn', {@GuiFun.manualTextboxEnterSet_keypressCallback,guiPanelTempObj.guiElements.btnManualTempSet} );
            set(guiPanelTempObj.guiElements.txtManualTempRampRate, 'KeyPressFcn', {@GuiFun.manualTextboxEnterSet_keypressCallback,guiPanelTempObj.guiElements.btnManualTempSet} );
        end
        
        function disable(guiPanelTempObj)
            children = get(guiPanelTempObj.guiElements.pnlManualObjectTemp,'Children');
            set(children,'Enable','off');
        end
        
        function enable(guiPanelTempObj)
            children = get(guiPanelTempObj.guiElements.pnlManualObjectTemp,'Children');
            set(children,'Enable','on');
            
            children = get(guiPanelTempObj.guiElements.pnlManualObjectTemp,'Children');
            set(children,'Enable','on');
            toggle = get(guiPanelTempObj.guiElements.btnManualTempRampToggle, 'Value'); %get ramp toggle value
            if (~toggle)
                set(guiPanelTempObj.guiElements.txtManualTempRampRate,'Enable','off');
            end
        end
                
        % Callbacks

        function btnManualTemp_callback(guiPanelTempObj, command)
            try
                tempLabel = '';
                rampLabel = '';
                toggle = get(guiPanelTempObj.guiElements.btnManualTempRampToggle, 'Value'); %get ramp toggle value
                        
                switch command
                    case 'set'
                        setTemp = str2num(get(guiPanelTempObj.guiElements.txtManualTempSetTemp, 'String'));
                        if(toggle)
                            rampRate = str2num(get(guiPanelTempObj.guiElements.txtManualTempRampRate, 'String'));
                            guiPanelTempObj.hardware.peltier.rampTempLinear(setTemp, rampRate);
                        else
                            guiPanelTempObj.hardware.peltier.setTemp(setTemp);
                        end
                    case 'ramp'
                        if(toggle) %ramp on
                            setTemp = guiPanelTempObj.hardware.peltier.getSetTemp();
                            set(guiPanelTempObj.guiElements.btnManualTempRampToggle, 'String', '<html><center>ramp<br>on<center>');
                            set(guiPanelTempObj.guiElements.btnManualTempRampToggle, 'backgroundcolor', [1 0.6 0.2]);
                            set(guiPanelTempObj.guiElements.txtManualTempRampRate, 'String',num2str(guiPanelTempObj.hardware.peltier.rampRate));
                            set(guiPanelTempObj.guiElements.txtManualTempRampRate, 'Enable','on');
                            guiPanelTempObj.hardware.peltier.rampTempLinear(setTemp, guiPanelTempObj.hardware.peltier.rampRate);
                        else %ramp off
                            setTemp = guiPanelTempObj.hardware.peltier.rampDestinationTemperature;
                            set(guiPanelTempObj.guiElements.btnManualTempRampToggle, 'String', '<html><center>ramp<br>off<center>');
                            set(guiPanelTempObj.guiElements.btnManualTempRampToggle, 'backgroundcolor', [0.75 0.75 0.75]);
                            set(guiPanelTempObj.guiElements.txtManualTempRampRate, 'Enable','off');
                            guiPanelTempObj.hardware.peltier.setTemp(setTemp);
                        end    
                    otherwise
                        error('gui:btnManualTemp_callback:badCommand','the only valid values for "command" are "set" and "ramp"');
                end

            catch err
                errordlg(err.message, 'Temperature Control Error', 'modal');
            end
        end
        
        %externally update the "set temp" field
        function updateSetTempField(guiPanelTempObj, value)
            CheckParam.isString(value, 'guiPanelTemp:updateSetTempField:badParam');

            %externally update only if the cursor is not currently in the field
            if(~guiPanelTempObj.guiElements.JtxtManualTempSetTemp.isFocusOwner() && ~guiPanelTempObj.guiElements.JtxtManualTempRampRate.isFocusOwner())
                set(guiPanelTempObj.guiElements.txtManualTempSetTemp, 'String', value);
            end
        end

        %externally update the "ramp rate" field
        function updateRampRateField(guiPanelTempObj, value)
            CheckParam.isString(value, 'guiPanelTemp:updateSetTempField:badParam');
            
            %externally update only if the cursor is not currently in the field
            if(~guiPanelTempObj.guiElements.JtxtManualTempRampRate.isFocusOwner() && ~guiPanelTempObj.guiElements.JtxtManualTempSetTemp.isFocusOwner())
                set(guiPanelTempObj.guiElements.txtManualTempRampRate, 'String', value);
            end
        end
        
    end % END PUBLIC METHODS
end % END GUI CLASS 