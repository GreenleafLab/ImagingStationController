% Fluorescence Imaging Machine GUI
% Curtis Layton
% October, November 2012
% March 2013

% This code has only been tested with MATLAB R2010b, Version 7.11.0.584
% (32-bit Windows). Many of the GUI functions are MATLAB-version-dependent.


classdef guiPanelRedLaser < handle
    
    properties % PROPERTIES
        hardware; %reference to the hardware object
        guiElements;
        parent; % control that houses this panel
        position; % position of this panel within its parent
        
        pollingLoop; % polling loop object
        guiPanelStatusbarObj; % status bar object, for writing status updates to
        
        testMode; % if testMode = 1, then code won't try interact with the hardware (used for testing GUI code)
        
        %paramaters to be read in from hardware; initialize to default values
        redLaserPowerMin = 0;
        redLaserPowerMax = 450;
        
        panelGreenLaser = []; %reference to the green laser control panel
        panelImage = []; %reference to the image control panel
    end % END PROPERTIES
    
    properties (Constant) % CONSTANT PROPERTIES
        
    end % CONSTANT PROPERTIES
    
    
    methods (Access = private) % PRIVATE METHODS

        %######## BEGIN functions that are called by the polling loop (timer) #######
        
        function updateRedLaserPowerBox(guiPanelRedLaserObj, args)
            try
                redPower = guiPanelRedLaserObj.hardware.lasers.redGetPower(false);
                redStatus = guiPanelRedLaserObj.hardware.lasers.redGetLaserStatus(false);
                if(~strcmp(redPower,'__BLOCKED_') && ~strcmp(redStatus,'__BLOCKED_'))
                    redSetPower = guiPanelRedLaserObj.hardware.lasers.redGetCurrSetPower();
                    guiPanelRedLaserObj.updateSetPowerField(num2str(redSetPower));
                end
            catch err
                if(~strcmp(err.identifier, 'LaserBox:redGetSerialResponse:Timeout'))
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
        function guiPanelRedLaserObj = guiPanelRedLaser(hardware, testMode, parent, position, bgcolor, pollingLoop, guiPanelStatusbarObj) %constructor
            % Startup code
            guiPanelRedLaserObj.testMode = testMode;
            guiPanelRedLaserObj.parent = parent;
            guiPanelRedLaserObj.position = position;
            guiPanelRedLaserObj.guiElements.bgcolor = bgcolor;
            
            if (~guiPanelRedLaserObj.testMode)
                guiPanelRedLaserObj.hardware = hardware;

                guiPanelRedLaserObj.pollingLoop = pollingLoop;
                
                %read in gui parameters from hardware
                
                %red laser
                guiPanelRedLaserObj.redLaserPowerMin = guiPanelRedLaserObj.hardware.lasers.redLaserPowerMin;
                guiPanelRedLaserObj.redLaserPowerMax = guiPanelRedLaserObj.hardware.lasers.redLaserPowerMax;
            end
      
            guiPanelRedLaserObj.setupGui();
            
            guiPanelRedLaserObj.pollingLoop.addToPollingLoop(@guiPanelRedLaserObj.updateRedLaserPowerBox, {}, 'updateRedLaserPowerBox', 2);
        end

        function setupGui(guiPanelRedLaserObj)
            guiPanelRedLaserObj.guiElements.pnlManualObjectLaserRed = uipanel(guiPanelRedLaserObj.parent, 'title', 'Laser (Red)', 'units', 'normalized', 'position', guiPanelRedLaserObj.position);
            guiPanelRedLaserObj.guiElements.lblManualLaserRedSetPower = uicontrol(guiPanelRedLaserObj.guiElements.pnlManualObjectLaserRed, 'style', 'text', 'string', 'Set Power (mW):', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.03 0.1 0.2 0.95 ], 'backgroundcolor', guiPanelRedLaserObj.guiElements.bgcolor);
            guiPanelRedLaserObj.guiElements.txtManualLaserRedSetPower = uicontrol(guiPanelRedLaserObj.guiElements.pnlManualObjectLaserRed, 'style', 'edit', 'string', '100', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.25, 0.1, 0.13, 0.8 ], 'backgroundcolor', [1 1 1]);
            guiPanelRedLaserObj.guiElements.JtxtManualLaserRedSetPower = findjobj(guiPanelRedLaserObj.guiElements.txtManualLaserRedSetPower); % Java handle; can then use h.isFocusOwner to determine if this object has focus
            guiPanelRedLaserObj.guiElements.btnManualLaserRedSet = uicontrol(guiPanelRedLaserObj.guiElements.pnlManualObjectLaserRed, 'String', 'set', 'units', 'normalized', 'position', [ 0.4, 0.1, 0.15, 1 ], 'callback', @(whichLaser, command)guiPanelRedLaserObj.btnManualLaser_callback('set'));
            guiPanelRedLaserObj.guiElements.btnManualLaserRedSwitch = uicontrol(guiPanelRedLaserObj.guiElements.pnlManualObjectLaserRed, 'style', 'togglebutton', 'String', 'off', 'units', 'normalized', 'position', [ 0.57, 0.1, 0.07, 0.5 ], 'backgroundcolor', [0.75 0.75 0.75], 'callback', @(whichLaser, command)guiPanelRedLaserObj.btnManualLaser_callback('switch'));
            guiPanelRedLaserObj.guiElements.btnManualLaserRedOff = uicontrol(guiPanelRedLaserObj.guiElements.pnlManualObjectLaserRed, 'String', '<html><center>power<br>off</center>', 'units', 'normalized', 'position', [ 0.66, 0.1, 0.15, 1 ], 'callback', @(whichLaser, command)guiPanelRedLaserObj.btnManualLaser_callback('off'));
            guiPanelRedLaserObj.guiElements.btnManualLaserRedOn = uicontrol(guiPanelRedLaserObj.guiElements.pnlManualObjectLaserRed, 'String', '<html><center>power<br>on</center>', 'units', 'normalized', 'position', [ 0.83, 0.1, 0.15, 1 ], 'callback', @(whichLaser, command)guiPanelRedLaserObj.btnManualLaser_callback('on'));
            
            set(guiPanelRedLaserObj.guiElements.txtManualLaserRedSetPower, 'KeyPressFcn', {@GuiFun.manualTextboxEnterSet_keypressCallback,guiPanelRedLaserObj.guiElements.btnManualLaserRedSet} );
        end
        
        function disable(guiPanelRedLaserObj)
            children = get(guiPanelRedLaserObj.guiElements.pnlManualObjectLaserRed,'Children');
            set(children,'Enable','off');
        end
        
        function enable(guiPanelRedLaserObj)
            children = get(guiPanelRedLaserObj.guiElements.pnlManualObjectLaserRed,'Children');
            set(children,'Enable','on');
        end
               
        %returns the current value in the set power field
        function redSetPower = getSetPower(guiPanelRedLaserObj)
            redSetPower = get(guiPanelRedLaserObj.guiElements.txtManualLaserRedSetPower, 'String');
        end
        
        %externally update the value in the set power field
        function updateSetPowerField(guiPanelRedLaserObj, value)
            CheckParam.isString(value, 'guiPanelRedLaser:updateSetPowerField:badParam');
            
            %externally update only if the cursor is not currently in the field
            if(~guiPanelRedLaserObj.guiElements.JtxtManualLaserRedSetPower.isFocusOwner())
                set(guiPanelRedLaserObj.guiElements.txtManualLaserRedSetPower, 'String', value)
            end
        end
        
        %returns if the state of the laser toggle switch is on(true) or off(false)
        function state = toggleSwitchStatus(guiPanelRedLaserObj)
            state = get(guiPanelRedLaserObj.guiElements.btnManualLaserRedSwitch, 'Value');
        end
        
        function toggleOn(guiPanelRedLaserObj)
            set(guiPanelRedLaserObj.guiElements.btnManualLaserRedSwitch, 'String', 'on');
            set(guiPanelRedLaserObj.guiElements.btnManualLaserRedSwitch, 'backgroundcolor', [1 0 0]);
            set(guiPanelRedLaserObj.guiElements.btnManualLaserRedSwitch, 'Value', true);
        end
        
        function toggleOff(guiPanelRedLaserObj)
            set(guiPanelRedLaserObj.guiElements.btnManualLaserRedSwitch, 'String', 'off');
            set(guiPanelRedLaserObj.guiElements.btnManualLaserRedSwitch, 'backgroundcolor', [0.75 0.75 0.75]);
            set(guiPanelRedLaserObj.guiElements.btnManualLaserRedSwitch, 'Value', false);
        end  
        
        %Callbacks

        function btnManualLaser_callback(guiPanelRedLaserObj, command)
            try
                if(strcmp(command,'set'))
                    previousRedLaserPower = guiPanelRedLaserObj.hardware.lasers.redGetCurrSetPower();
                    redLaserPower = str2double(guiPanelRedLaserObj.getSetPower());
                    CheckParam.isNumeric(redLaserPower, 'gui:btnManualLaser_callback:notNumeric');
                    CheckParam.isWithinARange(redLaserPower, guiPanelRedLaserObj.hardware.lasers.redLaserPowerMin, guiPanelRedLaserObj.hardware.lasers.redLaserPowerMax, 'gui:btnManualLaser_callback:notInRange');
                    if(redLaserPower ~= previousRedLaserPower)
                        guiPanelRedLaserObj.hardware.lasers.redSetPower(redLaserPower);
                        if(abs(previousRedLaserPower - redLaserPower) > guiPanelRedLaserObj.hardware.lasers.powerTolerance)
                            if(~isempty(guiPanelRedLaserObj.panelImage))
                                guiPanelRedLaserObj.panelImage.disablePanelTillPowerReached();
                            end
                        end
                    end
                elseif(strcmp(command, 'switch'))
                    if(guiPanelRedLaserObj.toggleSwitchStatus())
                        guiPanelRedLaserObj.toggleOn();
                        if(~isempty(guiPanelRedLaserObj.panelGreenLaser))
                            guiPanelRedLaserObj.panelGreenLaser.toggleOff();
                        end
                        guiPanelRedLaserObj.hardware.switchRedLaser();
                    else
                        guiPanelRedLaserObj.toggleOff();
                        if(~isempty(guiPanelRedLaserObj.panelGreenLaser))
                            guiPanelRedLaserObj.panelGreenLaser.toggleOff();
                        end
                        guiPanelRedLaserObj.hardware.switchLaserOff();
                    end
                elseif(strcmp(command,'off'))
                    guiPanelRedLaserObj.hardware.lasers.redPowerOff();
                elseif(strcmp(command,'on'))
                    guiPanelRedLaserObj.hardware.lasers.redPowerOn();
                    if(~isempty(guiPanelRedLaserObj.panelImage))
                        guiPanelRedLaserObj.panelImage.disablePanelTillPowerReached();
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