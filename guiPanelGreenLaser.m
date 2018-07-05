% Fluorescence Imaging Machine GUI
% Curtis Layton
% October, November 2012
% March 2013

% This code has only been tested with MATLAB R2010b, Version 7.11.0.584
% (32-bit Windows). Many of the GUI functions are MATLAB-version-dependent.


classdef guiPanelGreenLaser < handle
    
    properties % PROPERTIES
        hardware; %reference to the hardware object
        guiElements;
        parent; % control that houses this panel
        position; % position of this panel within its parent
        
        pollingLoop; % polling loop object
        guiPanelStatusbarObj; % status bar object, for writing status updates to
        
        testMode; % if testMode = 1, then code won't try interact with the hardware (used for testing GUI code)
        
        %paramaters to be read in from hardware; initialize to default values
        greenLaserPowerMin = 0;
        greenLaserPowerMax = 450;
        
        panelRedLaser = []; %reference to the red laser control panel
        panelImage = []; %reference to the image control panel
    end % END PROPERTIES
    
    properties (Constant) % CONSTANT PROPERTIES
        
    end % CONSTANT PROPERTIES
    
    
    methods (Access = private) % PRIVATE METHODS

        %######## BEGIN functions that are called by the polling loop (timer) #######
        
        function updateGreenLaserPowerBox(guiPanelGreenLaserObj, args)
            try
                greenPower = guiPanelGreenLaserObj.hardware.lasers.greenGetPower(false);
                greenStatus = guiPanelGreenLaserObj.hardware.lasers.greenGetLaserStatus(false);
                if(~strcmp(greenPower,'__BLOCKED_') && ~strcmp(greenStatus,'__BLOCKED_'))
                    greenSetPower = guiPanelGreenLaserObj.hardware.lasers.greenGetCurrSetPower();
                    guiPanelGreenLaserObj.updateSetPowerField(num2str(greenSetPower));
                end
            catch err
                if(~strcmp(err.identifier, 'LaserBox:greenGetSerialResponse:Timeout'))
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
        % guiPanelStatusbarObj: reference to a status bar panel on the GUI to write status updates to
        function guiPanelGreenLaserObj = guiPanelGreenLaser(hardware, testMode, parent, position, bgcolor, pollingLoop, guiPanelStatusbarObj) %constructor
            % Startup code
            guiPanelGreenLaserObj.testMode = testMode;
            guiPanelGreenLaserObj.parent = parent;
            guiPanelGreenLaserObj.position = position;
            guiPanelGreenLaserObj.guiElements.bgcolor = bgcolor;
            
            if (~guiPanelGreenLaserObj.testMode)
                guiPanelGreenLaserObj.hardware = hardware;

                guiPanelGreenLaserObj.pollingLoop = pollingLoop;
                
                %read in gui parameters from hardware
                
                %green laser
                guiPanelGreenLaserObj.greenLaserPowerMin = guiPanelGreenLaserObj.hardware.lasers.greenLaserPowerMin;
                guiPanelGreenLaserObj.greenLaserPowerMax = guiPanelGreenLaserObj.hardware.lasers.greenLaserPowerMax;
            end
      
            guiPanelGreenLaserObj.setupGui();

            guiPanelGreenLaserObj.pollingLoop.addToPollingLoop(@guiPanelGreenLaserObj.updateGreenLaserPowerBox, {}, 'updateGreenLaserPowerBox', 2);
        end
            
        function setupGui(guiPanelGreenLaserObj)
            guiPanelGreenLaserObj.guiElements.pnlManualObjectLaserGreen = uipanel(guiPanelGreenLaserObj.parent, 'title', 'Laser (Green)', 'units', 'normalized', 'position', guiPanelGreenLaserObj.position);
            guiPanelGreenLaserObj.guiElements.lblManualLaserGreenSetPower = uicontrol(guiPanelGreenLaserObj.guiElements.pnlManualObjectLaserGreen, 'style', 'text', 'string', 'Set Power (mW):', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.03 0.1 0.2 0.95 ], 'backgroundcolor', guiPanelGreenLaserObj.guiElements.bgcolor);
            guiPanelGreenLaserObj.guiElements.txtManualLaserGreenSetPower = uicontrol(guiPanelGreenLaserObj.guiElements.pnlManualObjectLaserGreen, 'style', 'edit', 'string', '100', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.25, 0.1, 0.13, 0.8 ], 'backgroundcolor', [1 1 1]);
            guiPanelGreenLaserObj.guiElements.JtxtManualLaserGreenSetPower = findjobj(guiPanelGreenLaserObj.guiElements.txtManualLaserGreenSetPower); % Java handle; can then use h.isFocusOwner to determine if this object has focus
            guiPanelGreenLaserObj.guiElements.btnManualLaserGreenSet = uicontrol(guiPanelGreenLaserObj.guiElements.pnlManualObjectLaserGreen, 'String', 'set', 'units', 'normalized', 'position', [ 0.4, 0.1, 0.15, 1 ], 'callback', @(whichLaser, command)guiPanelGreenLaserObj.btnManualLaser_callback('set'));
            guiPanelGreenLaserObj.guiElements.btnManualLaserGreenSwitch = uicontrol(guiPanelGreenLaserObj.guiElements.pnlManualObjectLaserGreen, 'style', 'togglebutton', 'String', 'off', 'units', 'normalized', 'position', [ 0.57, 0.1, 0.07, 0.5 ], 'backgroundcolor', [0.75 0.75 0.75], 'callback', @(whichLaser, command)guiPanelGreenLaserObj.btnManualLaser_callback('switch'));
            guiPanelGreenLaserObj.guiElements.btnManualLaserGreenOff = uicontrol(guiPanelGreenLaserObj.guiElements.pnlManualObjectLaserGreen, 'String', '<html><center>power<br>off</center>', 'units', 'normalized', 'position', [ 0.66, 0.1, 0.15, 1 ], 'callback', @(whichLaser, command)guiPanelGreenLaserObj.btnManualLaser_callback('off'));
            guiPanelGreenLaserObj.guiElements.btnManualLaserGreenOn = uicontrol(guiPanelGreenLaserObj.guiElements.pnlManualObjectLaserGreen, 'String', '<html><center>power<br>on</center>', 'units', 'normalized', 'position', [ 0.83, 0.1, 0.15, 1 ], 'callback', @(whichLaser, command)guiPanelGreenLaserObj.btnManualLaser_callback('on'));
            
            set(guiPanelGreenLaserObj.guiElements.txtManualLaserGreenSetPower, 'KeyPressFcn', {@GuiFun.manualTextboxEnterSet_keypressCallback,guiPanelGreenLaserObj.guiElements.btnManualLaserGreenSet} );
        end
        
        function disable(guiPanelGreenLaserObj)
            children = get(guiPanelGreenLaserObj.guiElements.pnlManualObjectLaserGreen,'Children');
            set(children,'Enable','off');
        end
        
        function enable(guiPanelGreenLaserObj)
            children = get(guiPanelGreenLaserObj.guiElements.pnlManualObjectLaserGreen,'Children');
            set(children,'Enable','on');
        end
        
        %returns the current value in the set power field
        function greenSetPower = getSetPower(guiPanelGreenLaserObj)
            greenSetPower = get(guiPanelGreenLaserObj.guiElements.txtManualLaserGreenSetPower, 'String');
        end
        
        %externally update the value in the set power field
        function updateSetPowerField(guiPanelGreenLaserObj, value)
            CheckParam.isString(value, 'guiPanelGreenLaser:updateSetPowerField:badParam');
            
            %externally update only if the cursor is not currently in the field
            if(~guiPanelGreenLaserObj.guiElements.JtxtManualLaserGreenSetPower.isFocusOwner())
                set(guiPanelGreenLaserObj.guiElements.txtManualLaserGreenSetPower, 'String', value)
            end
        end
        
        %returns if the state of the laser toggle switch is on(true) or off(false)
        function state = toggleSwitchStatus(guiPanelGreenLaserObj)
            state = get(guiPanelGreenLaserObj.guiElements.btnManualLaserGreenSwitch, 'Value');
        end
        
        function toggleOn(guiPanelGreenLaserObj)
            set(guiPanelGreenLaserObj.guiElements.btnManualLaserGreenSwitch, 'String', 'on');
            set(guiPanelGreenLaserObj.guiElements.btnManualLaserGreenSwitch, 'backgroundcolor', [1 0 0]);
            set(guiPanelGreenLaserObj.guiElements.btnManualLaserGreenSwitch, 'Value', true);
        end
        
        function toggleOff(guiPanelGreenLaserObj)
            set(guiPanelGreenLaserObj.guiElements.btnManualLaserGreenSwitch, 'String', 'off');
            set(guiPanelGreenLaserObj.guiElements.btnManualLaserGreenSwitch, 'backgroundcolor', [0.75 0.75 0.75]);
            set(guiPanelGreenLaserObj.guiElements.btnManualLaserGreenSwitch, 'Value', false);
        end  
        
        %Callbacks
        
        function btnManualLaser_callback(guiPanelGreenLaserObj, command)
            try
                if(strcmp(command,'set'))
                    previousGreenLaserPower = guiPanelGreenLaserObj.hardware.lasers.greenGetCurrSetPower();
                    greenLaserPower = str2double(guiPanelGreenLaserObj.getSetPower());
                    CheckParam.isNumeric(greenLaserPower, 'gui:btnManualLaser_callback:notNumeric');
                    CheckParam.isWithinARange(greenLaserPower, guiPanelGreenLaserObj.hardware.lasers.greenLaserPowerMin, guiPanelGreenLaserObj.hardware.lasers.greenLaserPowerMax, 'gui:btnManualLaser_callback:notInRange');
                    if(greenLaserPower ~= previousGreenLaserPower)
                        guiPanelGreenLaserObj.hardware.lasers.greenSetPower(greenLaserPower);
                        if(abs(previousGreenLaserPower - greenLaserPower) > guiPanelGreenLaserObj.hardware.lasers.powerTolerance)
                            if(~isempty(guiPanelGreenLaserObj.panelImage))
                                guiPanelGreenLaserObj.panelImage.disablePanelTillPowerReached();
                            end
                        end
                    end
                elseif(strcmp(command, 'switch'))
                    if(guiPanelGreenLaserObj.toggleSwitchStatus())
                        guiPanelGreenLaserObj.toggleOn();
                        if(~isempty(guiPanelGreenLaserObj.panelRedLaser))
                            guiPanelGreenLaserObj.panelRedLaser.toggleOff();
                        end
                        guiPanelGreenLaserObj.hardware.switchGreenLaser();
                    else
                        if(~isempty(guiPanelGreenLaserObj.panelRedLaser))
                            guiPanelGreenLaserObj.panelRedLaser.toggleOff();
                        end
                        guiPanelGreenLaserObj.toggleOff();
                        guiPanelGreenLaserObj.hardware.switchLaserOff();
                    end
                elseif(strcmp(command,'off'))
                    guiPanelGreenLaserObj.hardware.lasers.greenPowerOff();
                elseif(strcmp(command,'on'))
                    guiPanelGreenLaserObj.hardware.lasers.greenPowerOn();
                    if(~isempty(guiPanelGreenLaserObj.panelImage))
                        guiPanelGreenLaserObj.panelImage.disablePanelTillPowerReached();
                    end
                else
                    error('gui:btnManualLaser_callback:badCommand','the only valid values for "command" are "set" "off" and "on"');
                end                        
            catch err
                errordlg(err.message, 'Laser Error', 'modal');
            end
        end
        
    end % END PUBLIC METHODS
end % END GUI CLASS 