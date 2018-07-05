% Fluorescence Imaging Machine GUI
% Curtis Layton
% October, November 2013
% March 2013
% Updated from guiPanelTemp.m by Johan Andreasson, January 2015

% This code has only been tested with MATLAB R2010b, Version 7.11.0.584
% (32-bit Windows). Many of the GUI functions are MATLAB-version-dependent.


classdef guiPanelAutosamplerTemp < handle
    
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
        
        function updateTemperatureBox(guiPanelAutosamplerTempObj, args)
            try
                %externally update the fields to keep them current
                if(guiPanelAutosamplerTempObj.hardware.autosamplerPeltier.isCurrentlyRamping()) %if ramping
                    currSetTemp = guiPanelAutosamplerTempObj.hardware.autosamplerPeltier.rampDestinationTemperature;
                else %if not ramping
                    currSetTemp = guiPanelAutosamplerTempObj.hardware.autosamplerPeltier.getSetTemp(false);
                end
                if(~strcmp(currSetTemp,'__BLOCKED_'))
                    guiPanelAutosamplerTempObj.updateSetTempField(num2str(currSetTemp));
                    %guiPanelAutosamplerTempObj.updateRampRateField(num2str(guiPanelAutosamplerTempObj.hardware.peltier.rampRate));
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
        function guiPanelAutosamplerTempObj = guiPanelAutosamplerTemp(hardware, testMode, parent, position, bgcolor, pollingLoop, guiPanelStatusbarObj) %constructor
            % Startup code
            guiPanelAutosamplerTempObj.testMode = testMode;
            guiPanelAutosamplerTempObj.parent = parent;
            guiPanelAutosamplerTempObj.position = position;
            guiPanelAutosamplerTempObj.guiElements.bgcolor = bgcolor;
            guiPanelAutosamplerTempObj.guiPanelStatusbarObj = guiPanelStatusbarObj;
            
            if (~guiPanelAutosamplerTempObj.testMode)
                guiPanelAutosamplerTempObj.hardware = hardware;
                
                guiPanelAutosamplerTempObj.pollingLoop = pollingLoop;
            end
            
            guiPanelAutosamplerTempObj.setupGui();
            
            guiPanelAutosamplerTempObj.pollingLoop.addToPollingLoop(@guiPanelAutosamplerTempObj.updateTemperatureBox, {}, 'updateTemperatureBox', 2);
        end
            
        function setupGui(guiPanelAutosamplerTempObj)
            
            guiPanelAutosamplerTempObj.guiElements.pnlManualObjectTemp = uipanel(guiPanelAutosamplerTempObj.parent, 'title', 'Autosampler Temp', 'units', 'normalized', 'position', guiPanelAutosamplerTempObj.position);
            guiPanelAutosamplerTempObj.guiElements.lblManualTempSetTemp = uicontrol(guiPanelAutosamplerTempObj.guiElements.pnlManualObjectTemp, 'style', 'text', 'string', 'Set Temp (°C):', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0 0.1 0.36 0.8 ], 'backgroundcolor', guiPanelAutosamplerTempObj.guiElements.bgcolor);
            if (~guiPanelAutosamplerTempObj.testMode)
                currSetTemp = guiPanelAutosamplerTempObj.hardware.autosamplerPeltier.getSetTemp();
            else
                currSetTemp = 3;
            end
            guiPanelAutosamplerTempObj.guiElements.txtManualTempSetTemp = uicontrol(guiPanelAutosamplerTempObj.guiElements.pnlManualObjectTemp, 'style', 'edit', 'string', num2str(currSetTemp), 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.38, 0.1, 0.24, 0.8 ], 'backgroundcolor', [1 1 1]);
            guiPanelAutosamplerTempObj.guiElements.JtxtManualTempSetTemp = findjobj(guiPanelAutosamplerTempObj.guiElements.txtManualTempSetTemp); % Java handle; can then use h.isFocusOwner to determine if this object has focus
            %guiPanelAutosamplerTempObj.guiElements.lblManualTempRampRate = uicontrol(guiPanelAutosamplerTempObj.guiElements.pnlManualObjectTemp, 'style', 'text', 'string', 'Ramp Rate (°C/min):', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.45 0.1 0.2 0.8 ], 'backgroundcolor', guiPanelAutosamplerTempObj.guiElements.bgcolor);
            %guiPanelAutosamplerTempObj.guiElements.txtManualTempRampRate = uicontrol(guiPanelAutosamplerTempObj.guiElements.pnlManualObjectTemp, 'style', 'edit', 'string', '0', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.66, 0.1, 0.15, 0.8 ], 'backgroundcolor', [1 1 1]);
            %guiPanelAutosamplerTempObj.guiElements.JtxtManualTempRampRate = findjobj(guiPanelAutosamplerTempObj.guiElements.txtManualTempRampRate); % Java handle; can then use h.isFocusOwner to determine if this object has focus            
            %set(guiPanelAutosamplerTempObj.guiElements.txtManualTempRampRate,'Enable','off');
            %guiPanelAutosamplerTempObj.guiElements.btnManualTempRampToggle = uicontrol(guiPanelAutosamplerTempObj.guiElements.pnlManualObjectTemp, 'style', 'togglebutton', 'String', '<html><center>ramp<br>off<center>', 'units', 'normalized', 'FontSize', 7, 'position', [ 0.35, 0.1, 0.1, 0.67 ], 'backgroundcolor', [0.75 0.75 0.75], 'callback', @(command, varargin)guiPanelAutosamplerTempObj.btnManualTemp_callback('ramp'));
            guiPanelAutosamplerTempObj.guiElements.btnManualTempSet = uicontrol(guiPanelAutosamplerTempObj.guiElements.pnlManualObjectTemp, 'String', 'set', 'units', 'normalized', 'position', [ 0.64, 0.1, 0.31, 0.8 ], 'callback', @(command, varargin)guiPanelAutosamplerTempObj.btnManualTemp_callback('set'));
            
            set(guiPanelAutosamplerTempObj.guiElements.txtManualTempSetTemp, 'KeyPressFcn', {@GuiFun.manualTextboxEnterSet_keypressCallback,guiPanelAutosamplerTempObj.guiElements.btnManualTempSet} );
            %set(guiPanelAutosamplerTempObj.guiElements.txtManualTempRampRate, 'KeyPressFcn', {@GuiFun.manualTextboxEnterSet_keypressCallback,guiPanelAutosamplerTempObj.guiElements.btnManualTempSet} );
        end
        
        function disable(guiPanelAutosamplerTempObj)
            children = get(guiPanelAutosamplerTempObj.guiElements.pnlManualObjectTemp,'Children');
            set(children,'Enable','off');
        end
        
        function enable(guiPanelAutosamplerTempObj)
            %JA: These were duplicated for some reason.
            %children = get(guiPanelAutosamplerTempObj.guiElements.pnlManualObjectTemp,'Children');
            %set(children,'Enable','on');
            
            children = get(guiPanelAutosamplerTempObj.guiElements.pnlManualObjectTemp,'Children');
            set(children,'Enable','on');
            %JA: Disabling ramp functions
            %toggle = get(guiPanelAutosamplerTempObj.guiElements.btnManualTempRampToggle, 'Value'); %get ramp toggle value
            %if (~toggle)
            %    set(guiPanelAutosamplerTempObj.guiElements.txtManualTempRampRate,'Enable','off');
            %end
        end
                
        % Callbacks

        function btnManualTemp_callback(guiPanelAutosamplerTempObj, command)
            try
                tempLabel = '';
                %rampLabel = '';
                %toggle = get(guiPanelAutosamplerTempObj.guiElements.btnManualTempRampToggle, 'Value'); %get ramp toggle value
                        
                switch command
                    case 'set'
                        setTemp = str2num(get(guiPanelAutosamplerTempObj.guiElements.txtManualTempSetTemp, 'String'));
                        %if(toggle)
                        %    rampRate = str2num(get(guiPanelAutosamplerTempObj.guiElements.txtManualTempRampRate, 'String'));
                        %    guiPanelAutosamplerTempObj.hardware.autosamplerPeltier.rampTempLinear(setTemp, rampRate);
                        %else
                            guiPanelAutosamplerTempObj.hardware.autosamplerPeltier.setTemp(setTemp);
                        %end
                    %case 'ramp'
                    %    if(toggle) %ramp on
                    %        setTemp = guiPanelAutosamplerTempObj.hardware.peltier.getSetTemp();
                    %        set(guiPanelAutosamplerTempObj.guiElements.btnManualTempRampToggle, 'String', '<html><center>ramp<br>on<center>');
                    %        set(guiPanelAutosamplerTempObj.guiElements.btnManualTempRampToggle, 'backgroundcolor', [1 0.6 0.2]);
                    %        set(guiPanelAutosamplerTempObj.guiElements.txtManualTempRampRate, 'String',num2str(guiPanelAutosamplerTempObj.hardware.peltier.rampRate));
                    %        set(guiPanelAutosamplerTempObj.guiElements.txtManualTempRampRate, 'Enable','on');
                    %        guiPanelAutosamplerTempObj.hardware.peltier.rampTempLinear(setTemp, guiPanelAutosamplerTempObj.hardware.peltier.rampRate);
                    %    else %ramp off
                    %        setTemp = guiPanelAutosamplerTempObj.hardware.peltier.rampDestinationTemperature;
                    %        set(guiPanelAutosamplerTempObj.guiElements.btnManualTempRampToggle, 'String', '<html><center>ramp<br>off<center>');
                    %        set(guiPanelAutosamplerTempObj.guiElements.btnManualTempRampToggle, 'backgroundcolor', [0.75 0.75 0.75]);
                    %        set(guiPanelAutosamplerTempObj.guiElements.txtManualTempRampRate, 'Enable','off');
                    %        guiPanelAutosamplerTempObj.hardware.peltier.setTemp(setTemp);
                    %    end    
                    otherwise
                        error('gui:btnManualTemp_callback:badCommand','the only valid values for "command" are "set"');%and "ramp"');
                end

            catch err
                errordlg(err.message, 'Temperature Control Error', 'modal');
            end
        end
        
        %externally update the "set temp" field
        function updateSetTempField(guiPanelAutosamplerTempObj, value)
            CheckParam.isString(value, 'guiPanelTemp:updateSetTempField:badParam');

            %externally update only if the cursor is not currently in the field
            if(~guiPanelAutosamplerTempObj.guiElements.JtxtManualTempSetTemp.isFocusOwner())% && ~guiPanelAutosamplerTempObj.guiElements.JtxtManualTempRampRate.isFocusOwner())
                set(guiPanelAutosamplerTempObj.guiElements.txtManualTempSetTemp, 'String', value);
            end
        end

        %%externally update the "ramp rate" field
        %function updateRampRateField(guiPanelAutosamplerTempObj, value)
        %    CheckParam.isString(value, 'guiPanelTemp:updateSetTempField:badParam');
        %    
        %    %externally update only if the cursor is not currently in the field
        %    if(~guiPanelAutosamplerTempObj.guiElements.JtxtManualTempRampRate.isFocusOwner() && ~guiPanelAutosamplerTempObj.guiElements.JtxtManualTempSetTemp.isFocusOwner())
        %        set(guiPanelAutosamplerTempObj.guiElements.txtManualTempRampRate, 'String', value);
        %    end
        %end
        
    end % END PUBLIC METHODS
end % END GUI CLASS 