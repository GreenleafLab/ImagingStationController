% Fluorescence Imaging Machine GUI
% Curtis Layton
% October, November 2012
% March 2013

% This code has only been tested with MATLAB R2010b, Version 7.11.0.584
% (32-bit Windows). Many of the GUI functions are MATLAB-version-dependent.


classdef guiPanelLaserPower < handle
    
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
        greenLaserPowerMin = 0;
        greenLaserPowerMax = 450;  
    end % END PROPERTIES
    
    
    properties (Constant) % CONSTANT PROPERTIES
        
    end % CONSTANT PROPERTIES
    
    
    methods (Access = private) % PRIVATE METHODS
        
        %######## BEGIN functions that are called by the polling loop (timer) #######
        
        function updateLaserPower(guiPanelLaserPowerObj, args)
            try
                greenPower = guiPanelLaserPowerObj.hardware.lasers.greenGetPower(false);
                greenStatus = guiPanelLaserPowerObj.hardware.lasers.greenGetLaserStatus(false);
                if(~strcmp(greenPower,'__BLOCKED_') && ~strcmp(greenStatus,'__BLOCKED_'))
                    greenSetPower = guiPanelLaserPowerObj.hardware.lasers.greenGetCurrSetPower();
                    guiPanelLaserPowerObj.setPowerGreen(greenPower, greenSetPower, greenStatus);
                end
            catch err
                if(~strcmp(err.identifier, 'LaserBox:greenGetSerialResponse:Timeout'))
                    rethrow(err);
                end
            end
            
            try
                redPower = guiPanelLaserPowerObj.hardware.lasers.redGetPower(false);
                redStatus = guiPanelLaserPowerObj.hardware.lasers.redGetLaserStatus(false);
                if(~strcmp(redPower,'__BLOCKED_') && ~strcmp(redStatus,'__BLOCKED_'))
                    redSetPower = guiPanelLaserPowerObj.hardware.lasers.redGetCurrSetPower();
                    guiPanelLaserPowerObj.setPowerRed(redPower, redSetPower, redStatus);
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
        % pollingLoop: reference to PollingLoop instance in owner GUI, which makes callbacks when particular operations finish
        % guiPanelStatusbarObj: reference to a status bar panel on the GUI (if null, just gets ignored; otherwise write status updates to it)
        function guiPanelLaserPowerObj = guiPanelLaserPower(hardware, testMode, parent, position, bgcolor, pollingLoop, guiPanelStatusbarObj) %constructor
            % Startup code
            guiPanelLaserPowerObj.testMode = testMode;
            guiPanelLaserPowerObj.parent = parent;
            guiPanelLaserPowerObj.position = position;
            guiPanelLaserPowerObj.guiElements.bgcolor = bgcolor;

            guiPanelLaserPowerObj.guiPanelStatusbarObj = guiPanelStatusbarObj;
            
            if (~guiPanelLaserPowerObj.testMode)
                guiPanelLaserPowerObj.hardware = hardware;
                
                guiPanelLaserPowerObj.pollingLoop = pollingLoop;
                
                %read in gui parameters from hardware
                guiPanelLaserPowerObj.redLaserPowerMin = guiPanelLaserPowerObj.hardware.lasers.redLaserPowerMin;
                guiPanelLaserPowerObj.redLaserPowerMax = guiPanelLaserPowerObj.hardware.lasers.redLaserPowerMax;
                guiPanelLaserPowerObj.greenLaserPowerMin = guiPanelLaserPowerObj.hardware.lasers.greenLaserPowerMin;
                guiPanelLaserPowerObj.greenLaserPowerMax = guiPanelLaserPowerObj.hardware.lasers.greenLaserPowerMax;    
            end
      
            guiPanelLaserPowerObj.setupGui();
            
            guiPanelLaserPowerObj.pollingLoop.addToPollingLoop(@guiPanelLaserPowerObj.updateLaserPower, {}, 'updateLaserPower', 2);
        end
            
        function setupGui(guiPanelLaserPowerObj)
            guiPanelLaserPowerObj.guiElements.pnlDisplayLasers = uipanel(guiPanelLaserPowerObj.parent, 'title', '', 'units', 'normalized', 'position', guiPanelLaserPowerObj.position);
            
            guiPanelLaserPowerObj.guiElements.lblDisplayLasersRed = uicontrol(guiPanelLaserPowerObj.guiElements.pnlDisplayLasers, 'style', 'text', 'string', 'Red(OFF):', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0 0.65 0.2 0.2 ], 'backgroundcolor', guiPanelLaserPowerObj.guiElements.bgcolor);
            guiPanelLaserPowerObj.guiElements.lblDisplayLasersGreen = uicontrol(guiPanelLaserPowerObj.guiElements.pnlDisplayLasers, 'style', 'text', 'string', 'Green(OFF):', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0 0.35 0.2 0.2 ], 'backgroundcolor', guiPanelLaserPowerObj.guiElements.bgcolor);
            guiPanelLaserPowerObj.guiElements.lblDisplayLasersAxis = uicontrol(guiPanelLaserPowerObj.guiElements.pnlDisplayLasers, 'style', 'text', 'string', 'mW   ', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0 0.1 0.2 0.2 ], 'backgroundcolor', guiPanelLaserPowerObj.guiElements.bgcolor);

            [guiPanelLaserPowerObj.guiElements.JpbDisplayLasersRedLaserPower, guiPanelLaserPowerObj.guiElements.pbDisplayLasersRedLaserPower] = javacomponent('javax.swing.JProgressBar');
            set(guiPanelLaserPowerObj.guiElements.pbDisplayLasersRedLaserPower, 'parent', guiPanelLaserPowerObj.guiElements.pnlDisplayLasers);
            set(guiPanelLaserPowerObj.guiElements.pbDisplayLasersRedLaserPower, 'units', 'normalized');
            set(guiPanelLaserPowerObj.guiElements.pbDisplayLasersRedLaserPower, 'position', [ 0.2 0.65 0.75 0.3 ]);
            guiPanelLaserPowerObj.guiElements.JpbDisplayLasersRedLaserPower.setMinimum(guiPanelLaserPowerObj.redLaserPowerMin);
            guiPanelLaserPowerObj.guiElements.JpbDisplayLasersRedLaserPower.setMaximum(guiPanelLaserPowerObj.redLaserPowerMax);

            [guiPanelLaserPowerObj.guiElements.JpbDisplayLasersGreenLaserPower, guiPanelLaserPowerObj.guiElements.pbDisplayLasersGreenLaserPower] = javacomponent('javax.swing.JProgressBar');
            set(guiPanelLaserPowerObj.guiElements.pbDisplayLasersGreenLaserPower, 'parent', guiPanelLaserPowerObj.guiElements.pnlDisplayLasers);
            set(guiPanelLaserPowerObj.guiElements.pbDisplayLasersGreenLaserPower, 'units', 'normalized');
            set(guiPanelLaserPowerObj.guiElements.pbDisplayLasersGreenLaserPower, 'position', [ 0.2 0.35 0.75 0.3 ]);
            guiPanelLaserPowerObj.guiElements.JpbDisplayLasersGreenLaserPower.setMinimum(guiPanelLaserPowerObj.greenLaserPowerMin);
            guiPanelLaserPowerObj.guiElements.JpbDisplayLasersGreenLaserPower.setMaximum(guiPanelLaserPowerObj.greenLaserPowerMax);

            guiPanelLaserPowerObj.guiElements.lblDisplayLasersAxis = axes('parent', guiPanelLaserPowerObj.guiElements.pnlDisplayLasers);
                set(guiPanelLaserPowerObj.guiElements.lblDisplayLasersAxis, 'position', [ 0.2 0.2 0.75 0.01 ])
                set(guiPanelLaserPowerObj.guiElements.lblDisplayLasersAxis, 'Xlim', [guiPanelLaserPowerObj.greenLaserPowerMin guiPanelLaserPowerObj.greenLaserPowerMax]);
                set(guiPanelLaserPowerObj.guiElements.lblDisplayLasersAxis, 'XTick', GuiFun.getTicks(guiPanelLaserPowerObj.greenLaserPowerMin, guiPanelLaserPowerObj.greenLaserPowerMax, 50));
                set(guiPanelLaserPowerObj.guiElements.lblDisplayLasersAxis, 'XMinorTick', 'on');
                set(guiPanelLaserPowerObj.guiElements.lblDisplayLasersAxis, 'FontSize', 6); 
        end
               
        function setPowerRed(guiPanelLaserPowerObj, redPower, redSetPower, redStatus)
            CheckParam.isString(redStatus, 'guiPanelLaserPower:setPowerGreen:badParam');          
            
            if(strcmp(redStatus,'ENABLED'))
                CheckParam.isNumeric(redPower, 'guiPanelLaserPower:setPowerRed:badParam');
                CheckParam.isWithinARange(redPower, guiPanelLaserPowerObj.redLaserPowerMin, guiPanelLaserPowerObj.redLaserPowerMax, 'guiPanelLaserPower:setPowerRed:outOfRange');
                CheckParam.isNumeric(redSetPower, 'guiPanelLaserPower:setPowerRed:badParam');
                CheckParam.isWithinARange(redSetPower, guiPanelLaserPowerObj.redLaserPowerMin, guiPanelLaserPowerObj.redLaserPowerMax, 'guiPanelLaserPower:setPowerRed:outOfRange');

                guiPanelLaserPowerObj.guiElements.JpbDisplayLasersRedLaserPower.setValue(redPower);
                redLabel = sprintf('Red(%3.0f/%3.0fmW)', redPower, redSetPower);
            else
                guiPanelLaserPowerObj.guiElements.JpbDisplayLasersRedLaserPower.setValue(0);
                redLabel = sprintf('Red(OFF)');
            end
            
            set(guiPanelLaserPowerObj.guiElements.lblDisplayLasersRed, 'String', redLabel);
        end
        
        function setPowerGreen(guiPanelLaserPowerObj, greenPower, greenSetPower, greenStatus)
            CheckParam.isString(greenStatus, 'guiPanelLaserPower:setPowerGreen:badParam');

            if(strcmp(greenStatus,'ENABLED'))
                CheckParam.isNumeric(greenPower, 'guiPanelLaserPower:setPowerGreen:badParam');
                CheckParam.isWithinARange(greenPower, guiPanelLaserPowerObj.greenLaserPowerMin, guiPanelLaserPowerObj.greenLaserPowerMax, 'guiPanelLaserPower:setPowerGreen:outOfRange');
                CheckParam.isNumeric(greenSetPower, 'guiPanelLaserPower:setPowerGreen:badParam');
                CheckParam.isWithinARange(greenSetPower, guiPanelLaserPowerObj.greenLaserPowerMin, guiPanelLaserPowerObj.greenLaserPowerMax, 'guiPanelLaserPower:setPowerGreen:outOfRange');

                guiPanelLaserPowerObj.guiElements.JpbDisplayLasersGreenLaserPower.setValue(greenPower);
                greenLabel = sprintf('Green(%3.0f/%3.0fmW)', greenPower, greenSetPower);
            else
                guiPanelLaserPowerObj.guiElements.JpbDisplayLasersGreenLaserPower.setValue(0);
                greenLabel = sprintf('Green(OFF)');
            end
            
            set(guiPanelLaserPowerObj.guiElements.lblDisplayLasersGreen, 'String', greenLabel);
        end
        
    end % END PUBLIC METHODS
end % END GUI CLASS 