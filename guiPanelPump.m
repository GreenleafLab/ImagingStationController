% Fluorescence Imaging Machine GUI
% Peter McMahon / pmcmahon@stanford.edu
% Curtis Layton
% October, November 2012
% March 2013

% This code has only been tested with MATLAB R2010b, Version 7.11.0.584
% (32-bit Windows). Many of the GUI functions are MATLAB-version-dependent.


classdef guiPanelPump < handle
    
    properties % PROPERTIES
        hardware; %reference to the hardware object
        guiElements;
        parent; % control that houses this panel
        position; % position of this panel within its parent
        
        pollingLoop; % polling loop object, to be used for updating panel when pump finishes
        guiPanelStatusbarObj; % status bar object, for writing pump status updates to
        
        testMode; % if testMode = 1, then code won't try interact with the hardware (used for testing GUI code)
        
        %paramaters to be read in from hardware; initialize to default values
        defaultPumpVolume = '100';
        defaultPumpFlowRate = '60';
        minPumpFlowRate = 1; %無/min
        maxPumpFlowRate = 2000; %無/min
        minPumpVolume = 1; %1無
        maxPumpVolume = 1000000; %1L
        positionSelectorExclusionList = [16,17,18]; % which positions of the selector valve are blocked off, and so should not be displayed
        defaultPumpPosition = 7; % note: don't use a value that is excluded!
    end % END PROPERTIES
    
    properties (Constant) % CONSTANT PROPERTIES
        
    end % CONSTANT PROPERTIES
    
    
    methods (Access = private) % PRIVATE METHODS

        function positionArray = getPositionArray(guiPanelPumpObj)
            %returns labels for the gui selector valve dropdown box 
            %based on the number of positions and the exclusion list
            numPositions = guiPanelPumpObj.hardware.selectorValve.getNumPositions();
            numExcludedPositions = sum(guiPanelPumpObj.positionSelectorExclusionList <= numPositions); % count the number of entries in the exclusion list that are possible with the current selector (e.g. if the current selector has 7 positions, and the exclusion list is [3,4,10], this calculation will find that 2 of the excluded positions are relevant)
            positionArray = cell(1, numPositions - numExcludedPositions);

            for i = 1:numPositions
                if(~ismember(i, guiPanelPumpObj.positionSelectorExclusionList))
                    currLabel = sprintf('position %d', i);
                else
                    currLabel = sprintf('<html><font color="red">position %d</font></html>', i);
                end
                positionArray{i} = currLabel;
            end
        end
        
        %######## BEGIN functions that are called by the polling loop (timer) #######
        
        function waitForPump(guiPanelPumpObj, args) %update loop function to 
            try
                status = guiPanelPumpObj.hardware.pump.queryStatus(false);
                if(strcmp(status,'ready'))
                    %remove waitForPump from update loop
                    guiPanelPumpObj.pollingLoop.removeFromPollingLoop('waitForPump');
                    %re-enable the pump panel
                    guiPanelPumpObj.enable();

                    if ~isempty(guiPanelPumpObj.guiPanelStatusbarObj)
                        %set(guiPanelPumpObj.guiElements.lblStatusBar, 'string', 'Pumping finished.');
                        guiPanelPumpObj.guiPanelStatusbarObj.setStatus('Pumping');
                    end
                end
            catch err
                if(~strcmp(err.identifier, 'Kloehn_PN24741_V6SyringePump:getSerialResponse:Timeout'))
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
        % guiPanelStatusbarObj: reference to a status bar panel on the GUI (if null, just gets ignored; otherwise write pump status updates to it)
        function guiPanelPumpObj = guiPanelPump(hardware, testMode, parent, position, bgcolor, pollingLoop, guiPanelStatusbarObj) %constructor
            % Startup code
            guiPanelPumpObj.testMode = testMode;
            guiPanelPumpObj.parent = parent;
            guiPanelPumpObj.position = position;
            guiPanelPumpObj.guiElements.bgcolor = bgcolor;

            guiPanelPumpObj.guiPanelStatusbarObj = guiPanelStatusbarObj;
            if (~guiPanelPumpObj.testMode)
                guiPanelPumpObj.hardware = hardware;
     
                guiPanelPumpObj.pollingLoop = pollingLoop;
                
                %read in gui parameters from hardware
                
                %pump
                guiPanelPumpObj.defaultPumpVolume = guiPanelPumpObj.hardware.pump.defaultPumpVolume;
                guiPanelPumpObj.defaultPumpFlowRate = guiPanelPumpObj.hardware.pump.defaultPumpFlowRate;
                guiPanelPumpObj.minPumpFlowRate = guiPanelPumpObj.hardware.pump.minPumpFlowRate;
                guiPanelPumpObj.maxPumpFlowRate = guiPanelPumpObj.hardware.pump.maxPumpFlowRate;
                guiPanelPumpObj.minPumpVolume = guiPanelPumpObj.hardware.pump.minVolume;
                guiPanelPumpObj.maxPumpVolume = guiPanelPumpObj.hardware.pump.maxVolume;
                guiPanelPumpObj.positionSelectorExclusionList = guiPanelPumpObj.hardware.selectorValve.positionSelectorExclusionList; % which positions of the selector valve are blocked off, and so should not be displayed
                guiPanelPumpObj.defaultPumpPosition = guiPanelPumpObj.hardware.pump.defaultPumpPosition;
            end
      
            guiPanelPumpObj.setupGui();
        end
            
        function setupGui(guiPanelPumpObj)
            % load available pump positions
            positionArray = {'position 1', 'position 2'};
            if (~guiPanelPumpObj.testMode)
                positionArray = guiPanelPumpObj.getPositionArray();
            end
            
             % Pump Control
            guiPanelPumpObj.guiElements.pnlManualObjectPump = uipanel(guiPanelPumpObj.parent, 'title', 'Pump', 'units', 'normalized', 'position', guiPanelPumpObj.position);
            guiPanelPumpObj.guiElements.lblManualPumpVolume = uicontrol(guiPanelPumpObj.guiElements.pnlManualObjectPump, 'style', 'text', 'string', 'Volume:', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.05, 0.62, 0.42, 0.28 ], 'backgroundcolor', guiPanelPumpObj.guiElements.bgcolor);
            guiPanelPumpObj.guiElements.lblManualPumpFlowRate = uicontrol(guiPanelPumpObj.guiElements.pnlManualObjectPump, 'style', 'text', 'string', 'Flow Rate:', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.05, 0.32, 0.42, 0.28 ], 'backgroundcolor', guiPanelPumpObj.guiElements.bgcolor);
            guiPanelPumpObj.guiElements.lblManualPumpFromPosition = uicontrol(guiPanelPumpObj.guiElements.pnlManualObjectPump, 'style', 'text', 'string', 'From Position:', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.05, 0, 0.32, 0.28 ], 'backgroundcolor', guiPanelPumpObj.guiElements.bgcolor);

            guiPanelPumpObj.guiElements.txtManualPumpVolume = uicontrol(guiPanelPumpObj.guiElements.pnlManualObjectPump, 'style', 'edit', 'string', guiPanelPumpObj.defaultPumpVolume, 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.5, 0.7, 0.1, 0.28 ], 'backgroundcolor', [1 1 1]);
            guiPanelPumpObj.guiElements.lblManualPumpVolumeUnits = uicontrol(guiPanelPumpObj.guiElements.pnlManualObjectPump, 'style', 'text', 'string', '痞', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.62, 0.7, 0.1, 0.28 ], 'backgroundcolor', guiPanelPumpObj.guiElements.bgcolor);
            guiPanelPumpObj.guiElements.txtManualPumpFlowRate = uicontrol(guiPanelPumpObj.guiElements.pnlManualObjectPump, 'style', 'edit', 'string', guiPanelPumpObj.defaultPumpFlowRate, 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.5, 0.4, 0.1, 0.28 ], 'backgroundcolor', [1 1 1]);
            guiPanelPumpObj.guiElements.lblManualPumpFlowRateUnits = uicontrol(guiPanelPumpObj.guiElements.pnlManualObjectPump, 'style', 'text', 'string', '痞/min', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.62, 0.4, 0.2, 0.28 ], 'backgroundcolor', guiPanelPumpObj.guiElements.bgcolor);

            guiPanelPumpObj.guiElements.pmManualPumpFromPosition = uicontrol(guiPanelPumpObj.guiElements.pnlManualObjectPump, 'style', 'popupmenu', 'string', positionArray, 'value', guiPanelPumpObj.defaultPumpPosition, 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.5, 0.05, 0.25, 0.28 ], 'backgroundcolor', [1 1 1]);

            guiPanelPumpObj.guiElements.btnManualPumpPump = uicontrol(guiPanelPumpObj.guiElements.pnlManualObjectPump, 'String', 'pump', 'units', 'normalized', 'position', [ 0.77, 0.05, 0.2, 0.28 ], 'callback', @(command, varargin)guiPanelPumpObj.btnManualPump_callback('pump'));
            
            % if you press <ENTER> in either of the pump textboxes, the "pump" button callback will be fired
            set(guiPanelPumpObj.guiElements.txtManualPumpVolume, 'KeyPressFcn', {@GuiFun.manualTextboxEnterSet_keypressCallback,guiPanelPumpObj.guiElements.btnManualPumpPump} );
            set(guiPanelPumpObj.guiElements.txtManualPumpFlowRate, 'KeyPressFcn', {@GuiFun.manualTextboxEnterSet_keypressCallback,guiPanelPumpObj.guiElements.btnManualPumpPump} );
            
            guiPanelPumpObj.guiElements.btnManualPumpStop = uicontrol(guiPanelPumpObj.guiElements.pnlManualObjectPump, 'String', 'stop pump', 'units', 'normalized', 'position', [ 0.77, 0.4, 0.2, 0.28 ], 'callback', @(command, varargin)guiPanelPumpObj.btnManualPump_callback('stop'));
            guiPanelPumpObj.guiElements.btnManualPumpSwitch = uicontrol(guiPanelPumpObj.guiElements.pnlManualObjectPump, 'String', 'switch', 'FontSize', 7, 'units', 'normalized', 'position', [ 0.39, 0.05, 0.1, 0.28 ], 'callback', @(command, varargin)guiPanelPumpObj.btnManualPump_callback('switch'));
        end
        
        function disable(guiPanelPumpObj)
            children = get(guiPanelPumpObj.guiElements.pnlManualObjectPump,'Children');
            set(children,'Enable','off');
            set(guiPanelPumpObj.guiElements.btnManualPumpStop,'Enable','on');
        end
        
        function enable(guiPanelPumpObj)
            children = get(guiPanelPumpObj.guiElements.pnlManualObjectPump,'Children');
            set(children,'Enable','on');
        end
        
        % Callbacks

        function btnManualPump_callback(guiPanelPumpObj, command)
            switch command
                case 'pump'
                    fromPosition = get(guiPanelPumpObj.guiElements.pmManualPumpFromPosition, 'Value'); %ignore if an excluded position is selected
                    if(~ismember(fromPosition, guiPanelPumpObj.positionSelectorExclusionList))

                        if ~isempty(guiPanelPumpObj.guiPanelStatusbarObj)
                            %set(guiPanelPumpObj.guiElements.lblStatusBar, 'string', 'Pumping.');
                            guiPanelPumpObj.guiPanelStatusbarObj.setStatus('Pumping');
                        end

                        guiPanelPumpObj.disable();
                        try
                            volume = str2num(get(guiPanelPumpObj.guiElements.txtManualPumpVolume, 'String'));
                            CheckParam.isNumeric(volume, 'gui:btnManualPump_callback:notNumeric');
                            errorMessage = sprintf('Pump volume must be between %f and %f 無', guiPanelPumpObj.minPumpVolume, guiPanelPumpObj.maxPumpVolume);
                            CheckParam.isWithinARange(volume, guiPanelPumpObj.minPumpFlowRate, guiPanelPumpObj.maxPumpFlowRate, 'gui:btnManualLaser_callback:notInRange', errorMessage);

                            flowRate = str2num(get(guiPanelPumpObj.guiElements.txtManualPumpFlowRate, 'String'));
                            CheckParam.isNumeric(flowRate, 'gui:btnManualPump_callback:notNumeric');
                            errorMessage = sprintf('Pump flow rate must be between %f and %f 無/min', guiPanelPumpObj.minPumpFlowRate, guiPanelPumpObj.maxPumpFlowRate);
                            CheckParam.isWithinARange(flowRate, guiPanelPumpObj.minPumpFlowRate, guiPanelPumpObj.maxPumpFlowRate, 'gui:btnManualLaser_callback:notInRange', errorMessage);

                            guiPanelPumpObj.hardware.pumpFromPosition(fromPosition, volume, flowRate);
                        catch err
                            errordlg(err.message,'Pump error','modal');
                        end

                        %Put 'waitForPump' into the update loop.  The panel will
                        %remain greyed out until the pump command is complete
                        guiPanelPumpObj.pollingLoop.addToPollingLoop(@guiPanelPumpObj.waitForPump, {}, 'waitForPump', 2);
                    end
                case 'stop'
                    % issue command to stop pumping, and reset syringe
                    set(guiPanelPumpObj.guiElements.btnManualPumpStop,'Enable','off');
                    guiPanelPumpObj.hardware.pump.haltSyringe();
                    if(guiPanelPumpObj.pollingLoop.isInPollingList('waitForPump')) %if it was in the process of pumping...
                        %...reset the pump
                        guiPanelPumpObj.hardware.pump.resetSyringe();
                    end
                    set(guiPanelPumpObj.guiElements.btnManualPumpStop,'Enable','on');
                case 'switch'
                    set(guiPanelPumpObj.guiElements.btnManualPumpSwitch,'Enable','off');
                    fromPosition = get(guiPanelPumpObj.guiElements.pmManualPumpFromPosition, 'Value');
                    guiPanelPumpObj.hardware.selectorValve.setPosition(fromPosition);
                    set(guiPanelPumpObj.guiElements.btnManualPumpSwitch,'Enable','on');
                otherwise
                    error('gui:btnManualPump_callback:invalidCommand','command must be "pump" "stop" or "switch" only');
            end
        end
    end % END PUBLIC METHODS
end % END GUI CLASS 