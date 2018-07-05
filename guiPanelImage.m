% Fluorescence Imaging Machine GUI
% Curtis Layton
% October, November 2012
% March 2013

% This code has only been tested with MATLAB R2010b, Version 7.11.0.584
% (32-bit Windows). Many of the GUI functions are MATLAB-version-dependent.


classdef guiPanelImage < handle
    
    properties % PROPERTIES
        hardware; %reference to the hardware object
        guiElements;
        parent; % control that houses this panel
        position; % position of this panel within its parent
        
        pollingLoop; % polling loop object
        guiPanelStatusbarObj; % status bar object, for writing status updates to
        
        testMode; % if testMode = 1, then code won't try interact with the hardware (used for testing GUI code)
        
        %paramaters to be read in from hardware; initialize to default values
        filterPositions = {'0' '1', '2', '3', '4', '5', '6', '7'};
        filterDescriptions =   {'0-filter 1',...
                                '1-filter 2',...
                                '2-filter 3',...
                                '3-filter 4',...
                                '4-closed',...
                                '5-closed',...
                                '6-open',...
                                '7-open'};
        laserDescriptions = {'Red (660nm)', 'Green (532nm)'};
                            
        updateDisplayImageSettingsPixelValueReset; %function handle for resetting the pixel bar when an image is taken
    end % END PROPERTIES
    
    
    properties (Constant) % CONSTANT PROPERTIES
        
    end % CONSTANT PROPERTIES
    
    
    methods (Access = private) % PRIVATE METHODS
        
        %######## BEGIN functions that are called by the polling loop (timer) #######
        
        function waitForPower(guiPanelImageObj, args) %update loop function to 
            try
                atPower = guiPanelImageObj.hardware.lasers.isAtSetPower(false);
                if(~strcmp(atPower,'__BLOCKED_'))
                    if(atPower)
                        %remove from polling loop
                        guiPanelImageObj.pollingLoop.removeFromPollingLoop('waitForPower');

                        %reset message
                        guiPanelImageObj.updateMessagePanel('');

                        %enable image panel after lasers are powered up
                        guiPanelImageObj.enable();
                    end
                end
            catch err
                if(~strcmp(err.identifier, 'LaserBox:redGetSerialResponse:Timeout') && ~strcmp(err.identifier, 'LaserBox:greenGetSerialResponse:Timeout'))
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
        % guiPanelStatusbarObj: reference to a status bar panel on the GUI to write status updates to)
        function guiPanelImageObj = guiPanelImage(hardware, testMode, parent, position, bgcolor, updateDisplayImageSettingsPixelValueReset, pollingLoop, guiPanelStatusbarObj) %constructor
            % Startup code
            guiPanelImageObj.testMode = testMode;
            guiPanelImageObj.parent = parent;
            guiPanelImageObj.position = position;
            guiPanelImageObj.guiElements.bgcolor = bgcolor;
            
            guiPanelImageObj.updateDisplayImageSettingsPixelValueReset = updateDisplayImageSettingsPixelValueReset;

            guiPanelImageObj.guiPanelStatusbarObj = guiPanelStatusbarObj;
            if (~guiPanelImageObj.testMode)
                guiPanelImageObj.hardware = hardware;
                
                guiPanelImageObj.pollingLoop = pollingLoop;
                
                %read in gui parameters from hardware
                guiPanelImageObj.filterPositions = guiPanelImageObj.hardware.stageAndFilterWheel.filterPositions;
                guiPanelImageObj.filterDescriptions = guiPanelImageObj.hardware.stageAndFilterWheel.filterDescriptions;
                guiPanelImageObj.laserDescriptions = guiPanelImageObj.hardware.lasers.laserDescriptions;
            end

            guiPanelImageObj.setupGui();
        end
            
        function setupGui(guiPanelImageObj)
            guiPanelImageObj.guiElements.pnlManualObjectImage = uipanel(guiPanelImageObj.parent, 'title', 'Image', 'units', 'normalized', 'position', guiPanelImageObj.position);

            guiPanelImageObj.guiElements.lblManualImageLaser = uicontrol(guiPanelImageObj.guiElements.pnlManualObjectImage, 'style', 'text', 'string', 'laser:', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.05, 0.52, 0.42, 0.15 ], 'backgroundcolor', guiPanelImageObj.guiElements.bgcolor);
            guiPanelImageObj.guiElements.lblManualImageFilter = uicontrol(guiPanelImageObj.guiElements.pnlManualObjectImage, 'style', 'text', 'string', 'filter:', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.05, 0.27, 0.32, 0.15 ], 'backgroundcolor', guiPanelImageObj.guiElements.bgcolor);
            guiPanelImageObj.guiElements.lblManualImageExposureTime = uicontrol(guiPanelImageObj.guiElements.pnlManualObjectImage, 'style', 'text', 'string', 'exposure time:', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.05, 0, 0.42, 0.2 ], 'backgroundcolor', guiPanelImageObj.guiElements.bgcolor);
            guiPanelImageObj.guiElements.lblManualImageMessage = uicontrol(guiPanelImageObj.guiElements.pnlManualObjectImage, 'style', 'text', 'string', '', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.05, 0, 0.52, 0.2 ], 'backgroundcolor', guiPanelImageObj.guiElements.bgcolor);
            guiPanelImageObj.guiElements.pmManualImageLaser = uicontrol(guiPanelImageObj.guiElements.pnlManualObjectImage, 'style', 'popupmenu', 'string', guiPanelImageObj.laserDescriptions, 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.5, 0.55, 0.4, 0.15 ], 'backgroundcolor', [1 1 1]);
            guiPanelImageObj.guiElements.pmManualImageFilter = uicontrol(guiPanelImageObj.guiElements.pnlManualObjectImage, 'style', 'popupmenu', 'string', guiPanelImageObj.filterDescriptions, 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.5, 0.3, 0.4, 0.15 ], 'backgroundcolor', [1 1 1]);
            guiPanelImageObj.guiElements.btnManualImageFilterSwitch = uicontrol(guiPanelImageObj.guiElements.pnlManualObjectImage, 'String', 'switch', 'FontSize', 7, 'units', 'normalized', 'position', [ 0.39, 0.24, 0.1, 0.20 ], 'callback', @(command, varargin)guiPanelImageObj.btnManualImage_callback('switch'));
            guiPanelImageObj.guiElements.txtManualImageExposureTime = uicontrol(guiPanelImageObj.guiElements.pnlManualObjectImage, 'style', 'edit', 'string', '100', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.5, 0.02, 0.27, 0.17 ], 'backgroundcolor', [1 1 1]);
            guiPanelImageObj.guiElements.lblManualImageExposureTimeUnits = uicontrol(guiPanelImageObj.guiElements.pnlManualObjectImage, 'style', 'text', 'string', 'ms', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.8, 0.0, 0.1, 0.15 ], 'backgroundcolor', guiPanelImageObj.guiElements.bgcolor);
            guiPanelImageObj.guiElements.chkManualImageAutoscale = uicontrol(guiPanelImageObj.guiElements.pnlManualObjectImage, 'style', 'checkbox', 'String', 'Autoscale', 'value', false, 'units', 'normalized', 'position', [ 0.05, 0.52, 0.25, 0.15 ]);
            
            guiPanelImageObj.guiElements.btnManualImageCapture = uicontrol(guiPanelImageObj.guiElements.pnlManualObjectImage, 'String', 'Capture', 'units', 'normalized', 'position', [ 0.05, 0.75, 0.9, 0.25 ], 'callback', @(command, varargin)guiPanelImageObj.btnManualImage_callback('image'));
        end
        
        function disable(guiPanelImageObj)
            children = get(guiPanelImageObj.guiElements.pnlManualObjectImage,'Children');
            set(children,'Enable','off');
            set(guiPanelImageObj.guiElements.lblManualImageMessage,'Enable','on');
        end
        
        function enable(guiPanelImageObj)
            children = get(guiPanelImageObj.guiElements.pnlManualObjectImage,'Children');
            set(children,'Enable','on');
        end
        
        function updateMessagePanel(guiPanelImageObj, message, color)
            CheckParam.isString(message, 'guiPanelImage:updateMessagePanel:badParam');
            if(~exist('color', 'var'))
                color = 'red';
            else
                CheckParam.isString(message, 'guiPanelImage:updateMessagePanel:badParam');
            end
            
            set(guiPanelImageObj.guiElements.lblManualImageMessage, 'string', message, 'ForegroundColor', color);
        end
        
        function message = getMessagePanelMessage(guiPanelImageObj)
            message = get(guiPanelImageObj.guiElements.lblManualImageMessage, 'string');
        end
        
        function manualTextboxEnterSet_keypressCallback(guiPanelImageObj, h, e, hButton)
            % this callback gets used to automatically call the "set"
            % button callback for the button in the panel that the textbox
            % resides in
            
            % the callback gets passed a handle to the button that it
            % should "click"
            
            if isequal(e.Key, 'return') % if the key that was pressed was <ENTER>, then manually call Set button callback
                drawnow;
                cb = get(hButton, 'callback'); % get the callback for the button
                hgfeval(cb); % call the callback function
            end
        end
        
        %disable the image panel while we wait for the laser power to reach
        %the set power
        function disablePanelTillPowerReached(guiPanelImageObj)
                
            %disable image panel while lasers power on
            guiPanelImageObj.disable();

            %display "powering  up" message
            guiPanelImageObj.updateMessagePanel('setting laser power...');

            %wait in the polling loop to re-enable panel
            if(~guiPanelImageObj.pollingLoop.isInPollingList('waitForPower'))
                guiPanelImageObj.pollingLoop.addToPollingLoop(@guiPanelImageObj.waitForPower, {}, 'waitForPower', 2);
            end
        end
        
        % Callbacks
        function btnManualImage_callback(guiPanelImageObj, command)
            switch command
                case 'image'
                    try
                        currExposureString = get(guiPanelImageObj.guiElements.txtManualImageExposureTime, 'String');
                        currExposureTime = str2double(currExposureString);

                        currEmissionFilterIndex = get(guiPanelImageObj.guiElements.pmManualImageFilter, 'Value');             
                        currEmissionFilter = guiPanelImageObj.filterPositions{currEmissionFilterIndex};

                        currLaserIndex = get(guiPanelImageObj.guiElements.pmManualImageLaser, 'Value');
                        laserList = {'red','green'};
                        currLaser = laserList{currLaserIndex};
                        
                        elapsedTime = guiPanelImageObj.hardware.acquireImage(currExposureTime, currEmissionFilter, currLaser)
                    catch err
                        errordlg(err.message, 'Imaging Error', 'modal');
                    end
                   
                    % if "autoscale" checkbox is checked, then automatically 
                    % rescale pixel values to show full dynamic range
                    if (get(guiPanelImageObj.guiElements.chkManualImageAutoscale, 'Value')) % if autoscale checkbox is checked then
                         guiPanelImageObj.updateDisplayImageSettingsPixelValueReset(true); % autoscale
                    else
                         guiPanelImageObj.updateDisplayImageSettingsPixelValueReset();
                    end
                case 'switch'
                    currFilter = get(guiPanelImageObj.guiElements.pmManualImageFilter, 'Value');                
                    guiPanelImageObj.hardware.stageAndFilterWheel.moveFilterWheel('0', guiPanelImageObj.filterPositions{currFilter});                    
                otherwise
                    error('gui:btnManualImage_callback:badCommand','the only valid values for command are "image" and "switch"');
            end
        end
        
        %externally executes the image callback just as if the user had
        %pressed the "Capture" button.  For 'auto-image after move' calls,
        %etc.
        function capture(guiPanelImageObj)
            guiPanelImageObj.btnManualImage_callback('image');
        end
        
    end % END PUBLIC METHODS
end % END GUI CLASS 