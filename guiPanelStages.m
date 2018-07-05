% Fluorescence Imaging Machine GUI
% Peter McMahon / pmcmahon@stanford.edu
% Curtis Layton
% October, November 2012
% March 2013

% This code has only been tested with MATLAB R2010b, Version 7.11.0.584
% (32-bit Windows). Many of the GUI functions are MATLAB-version-dependent.


% Panel for manually controlling stages
classdef guiPanelStages < handle
    
    properties % PROPERTIES
        hardware; %reference to the hardware object
        guiElements;
        parent; % control that houses this panel
        position; % position of this panel within its parent
        
        disableX;
        disableY;
        disableZ;
        disableGoTo;
        disableUseZFocusMap;
        homeStagesOnStartup; % determines whether or not the stages get homed when this control gets created
        panelImage; % reference to the image control panel
        
        testMode; % if testMode = 1, then code won't try interact with the hardware (used for testing GUI code)

        %paramaters to be read in from hardware; initialize to default values
        defaultLargeStepXY = '8000';
        defaultSmallStepXY = '2000';
        defaultLargeStepZ = '120';
        defaultSmallStepZ = '20';
        maxStep = 0.0001;
        minStep = 500000;
        
        stageXLimitMax =  1000000;
        stageXLimitMin = -1200000;
        stageYLimitMax =  1000000;
        stageYLimitMin = -1200000;
        stageZLimitMax =  1000000;
        stageZLimitMin = -1200000;

        stageZSafePosition = -90000; % position of Z stage such that the objective is far away from the flow holder (i.e. position of Z such that XY stages can move without obstruction)
        flowCellXmin = -593891;
        flowCellXmax = -500000;
        flowCellYmin = -364858;
        flowCellYmax = -157885;

    end % END PROPERTIES
    
    properties (Constant) % CONSTANT PROPERTIES
        
    end % CONSTANT PROPERTIES
    
    
    methods (Access = private) % PRIVATE METHODS
        
    end % END PRIVATE METHODS
    
    
    methods % PUBLIC METHODS

        % hardware: reference to ImagingStationHardware instance
        % testMode: GUI testing mode on/off
        % parent: GUI object that will be the container for this panel
        % position: position to place panel within parent
        % bgcolor: background color of GUI elements
        % disableX: if set = 1, then the X stage controls are disabled
        % disableY: if set = 1, then the Y stage controls are disabled
        % disableZ: if set = 1, then the Z stage controls are disabled
        % disableGoTo: if set = 1, then the "go to any XYZ" position control is disabled
        % disableUseZFocusMap: if set = 1, then the "Z use Focus Map" checkbox is disabled
        % homeStagesOnStartup: if set = 1, then the stages get homed when this panel gets created (normally we only want this in the main GUI)
        % panelImage: reference to imaging panel; this is needed so that when autoimage-on-move is enabled, a command to collect an image can be executed
        function guiPanelStagesObj = guiPanelStages(hardware, testMode, parent, position, bgcolor, disableX, disableY, disableZ, disableGoTo, disableUseZFocusMap, homeStagesOnStartup, panelImage) %constructor
            % Startup code
            guiPanelStagesObj.testMode = testMode;
            guiPanelStagesObj.parent = parent;
            guiPanelStagesObj.position = position;
            guiPanelStagesObj.guiElements.bgcolor = bgcolor;
            
            guiPanelStagesObj.disableX = disableX;
            guiPanelStagesObj.disableY = disableY;
            guiPanelStagesObj.disableZ = disableZ;
            guiPanelStagesObj.disableGoTo = disableGoTo;
            guiPanelStagesObj.disableUseZFocusMap = disableUseZFocusMap;
            guiPanelStagesObj.homeStagesOnStartup = homeStagesOnStartup;
            guiPanelStagesObj.panelImage = panelImage;
            
            if (~guiPanelStagesObj.testMode)
                guiPanelStagesObj.hardware = hardware;
                
                %read in gui parameters from hardware
                
                %stage and filter wheel
                guiPanelStagesObj.defaultLargeStepXY = hardware.stageAndFilterWheel.defaultLargeStepXY;
                guiPanelStagesObj.defaultSmallStepXY = hardware.stageAndFilterWheel.defaultSmallStepXY;
                guiPanelStagesObj.defaultLargeStepZ = hardware.stageAndFilterWheel.defaultLargeStepZ;
                guiPanelStagesObj.defaultSmallStepZ = hardware.stageAndFilterWheel.defaultSmallStepZ;
                guiPanelStagesObj.maxStep = hardware.stageAndFilterWheel.maxStep;
                guiPanelStagesObj.minStep = hardware.stageAndFilterWheel.minStep;
                guiPanelStagesObj.stageXLimitMax = hardware.stageAndFilterWheel.stageXLimitMax;
                guiPanelStagesObj.stageXLimitMin = hardware.stageAndFilterWheel.stageXLimitMin;
                guiPanelStagesObj.stageYLimitMax = hardware.stageAndFilterWheel.stageYLimitMax;
                guiPanelStagesObj.stageYLimitMin = hardware.stageAndFilterWheel.stageYLimitMin;
                guiPanelStagesObj.stageZLimitMax = hardware.stageAndFilterWheel.stageZLimitMax;
                guiPanelStagesObj.stageZLimitMin = hardware.stageAndFilterWheel.stageZLimitMin;
                guiPanelStagesObj.stageZSafePosition = hardware.stageAndFilterWheel.stageZSafePosition; % position of Z stage such that the objective is far away from the flow holder (i.e. position of Z such that XY stages can move without obstruction)
                guiPanelStagesObj.flowCellXmin = hardware.stageAndFilterWheel.flowCellXmin;
                guiPanelStagesObj.flowCellXmax = hardware.stageAndFilterWheel.flowCellXmax;
                guiPanelStagesObj.flowCellYmin = hardware.stageAndFilterWheel.flowCellYmin;
                guiPanelStagesObj.flowCellYmax = hardware.stageAndFilterWheel.flowCellYmax;

            end
            
            guiPanelStagesObj.setupGui();
            
            if (~guiPanelStagesObj.testMode)
                try
                    if (guiPanelStagesObj.homeStagesOnStartup)
                        guiPanelStagesObj.hardware.initStage();
                    end
                    guiPanelStagesObj.updateManualStagesAll(); %update stage position in text fields
                catch err
                    guiPanelStagesObj.updateManualStagesAll(); %update stage position in text fields
                    errordlg(err.message, 'Init Stage Error', 'modal');
                end
            end
            % EAB
            guiPanelStagesObj.enable();
        end
        
        function setupGui(guiPanelStagesObj)
            % XYZ Stages
            guiPanelStagesObj.guiElements.pnlManualObjectStages = uipanel(guiPanelStagesObj.parent, 'title', 'Stages', 'units', 'normalized', 'position', guiPanelStagesObj.position);
            % XY Stage Controls
            guiPanelStagesObj.guiElements.lblManualStagesXY = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'style', 'text', 'string', 'X-Y stages:', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.05 0.9 0.3 0.09 ], 'backgroundcolor', guiPanelStagesObj.guiElements.bgcolor);

            guiPanelStagesObj.guiElements.btnManualStagesXYLeftSmallStep = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'String', '<', 'units', 'normalized', 'position', [0.07 0.55 0.05 0.13], 'callback', @(dir,size)guiPanelStagesObj.btnManualStagesXYmove_callback('left', 'small'));
            guiPanelStagesObj.guiElements.btnManualStagesXYRightSmallStep = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'String', '>', 'units', 'normalized', 'position', [0.17 0.55 0.05 0.13], 'callback', @(dir,size)guiPanelStagesObj.btnManualStagesXYmove_callback('right', 'small'));
            guiPanelStagesObj.guiElements.btnManualStagesXYUpSmallStep = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'String', '^', 'units', 'normalized', 'position', [0.12 0.65 0.05 0.13], 'callback', @(dir,size)guiPanelStagesObj.btnManualStagesXYmove_callback('up', 'small'));
            guiPanelStagesObj.guiElements.btnManualStagesXYDownSmallStep = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'String', 'v', 'units', 'normalized', 'position', [0.12 0.45 0.05 0.13], 'callback', @(dir,size)guiPanelStagesObj.btnManualStagesXYmove_callback('down', 'small'));

            guiPanelStagesObj.guiElements.btnManualStagesXYLeftBigStep = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'String', '<<', 'units', 'normalized', 'position', [0.02 0.55 0.05 0.13], 'callback', @(dir,size)guiPanelStagesObj.btnManualStagesXYmove_callback('left', 'large'));
            guiPanelStagesObj.guiElements.btnManualStagesXYRightBigStep = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'String', '>>', 'units', 'normalized', 'position', [0.22 0.55 0.05 0.13], 'callback', @(dir,size)guiPanelStagesObj.btnManualStagesXYmove_callback('right', 'large'));
            guiPanelStagesObj.guiElements.btnManualStagesXYUpBigStep = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'String', '<html>^<br>^', 'units', 'normalized', 'position', [0.12 0.75 0.05 0.13], 'callback', @(dir,size)guiPanelStagesObj.btnManualStagesXYmove_callback('up', 'large'));
            guiPanelStagesObj.guiElements.btnManualStagesXYDownBigStep = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'String', '<html>v<br>v', 'units', 'normalized', 'position', [0.12 0.35 0.05 0.13], 'callback', @(dir,size)guiPanelStagesObj.btnManualStagesXYmove_callback('down', 'large'));

            guiPanelStagesObj.guiElements.lblManualStagesXYSmallStepSize = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'style', 'text', 'string', 'small step:', 'FontSize', 7, 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.3 0.78 0.15 0.09 ], 'backgroundcolor', guiPanelStagesObj.guiElements.bgcolor);
            guiPanelStagesObj.guiElements.txtManualStagesXYSmallStepSize = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'style', 'edit', 'string', guiPanelStagesObj.defaultSmallStepXY, 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.3, 0.75, 0.15, 0.07 ], 'backgroundcolor', [1 1 1]);
            guiPanelStagesObj.guiElements.lblManualStagesXYLargeStepSize = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'style', 'text', 'string', 'large step:', 'FontSize', 7, 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.3 0.63 0.15 0.09 ], 'backgroundcolor', guiPanelStagesObj.guiElements.bgcolor);    
            guiPanelStagesObj.guiElements.txtManualStagesXYLargeStepSize = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'style', 'edit', 'string', guiPanelStagesObj.defaultLargeStepXY, 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.3, 0.6, 0.15, 0.07 ], 'backgroundcolor', [1 1 1]);
            % Z Stage Controls
            guiPanelStagesObj.guiElements.lblManualStagesZ = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'style', 'text', 'string', 'Z stage (focus):', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.5 0.9 0.35 0.09 ], 'backgroundcolor', guiPanelStagesObj.guiElements.bgcolor);

            guiPanelStagesObj.guiElements.btnManualStagesZUpSmallStep = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'String', '^', 'units', 'normalized', 'position', [0.5 0.65 0.05 0.13], 'callback', @(dir,size)guiPanelStagesObj.btnManualStagesZmove_callback('up', 'small'));
            guiPanelStagesObj.guiElements.btnManualStagesZDownSmallStep = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'String', 'v', 'units', 'normalized', 'position', [0.5 0.45 0.05 0.13], 'callback', @(dir,size)guiPanelStagesObj.btnManualStagesZmove_callback('down', 'small'));

            guiPanelStagesObj.guiElements.btnManualStagesZUpBigStep = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'String', '<html>^<br>^', 'units', 'normalized', 'position', [0.5 0.75 0.05 0.13], 'callback', @(dir,size)guiPanelStagesObj.btnManualStagesZmove_callback('up', 'large'));
            guiPanelStagesObj.guiElements.btnManualStagesZDownBigStep = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'String', '<html>v<br>v', 'units', 'normalized', 'position', [0.5 0.35 0.05 0.13], 'callback', @(dir,size)guiPanelStagesObj.btnManualStagesZmove_callback('down', 'large'));

            guiPanelStagesObj.guiElements.btnManualStagesZHome = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'String', '<html><center>^<br>home Z</center>', 'units', 'normalized', 'position', [0.6 0.46 0.15 0.12], 'callback', @(command, varargin)guiPanelStagesObj.btnManualStagesXYZGoto_callback('home Z'));

            guiPanelStagesObj.guiElements.lblManualStagesZSmallStepSize = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'style', 'text', 'string', 'small step:', 'FontSize', 7, 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.6 0.78 0.15 0.09 ], 'backgroundcolor', guiPanelStagesObj.guiElements.bgcolor);
            guiPanelStagesObj.guiElements.txtManualStagesZSmallStepSize = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'style', 'edit', 'string', guiPanelStagesObj.defaultSmallStepZ, 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.6, 0.75, 0.15, 0.07 ], 'backgroundcolor', [1 1 1]);
            guiPanelStagesObj.guiElements.lblManualStagesZLargeStepSize = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'style', 'text', 'string', 'large step:', 'FontSize', 7, 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.6 0.63 0.15 0.09 ], 'backgroundcolor', guiPanelStagesObj.guiElements.bgcolor);    
            guiPanelStagesObj.guiElements.txtManualStagesZLargeStepSize = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'style', 'edit', 'string', guiPanelStagesObj.defaultLargeStepZ, 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.6, 0.6, 0.15, 0.07 ], 'backgroundcolor', [1 1 1]);

            % XYZ Stage Position / Goto
            guiPanelStagesObj.guiElements.lblManualStagesXPosition = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'style', 'text', 'string', 'X', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.02 0.2 0.03 0.09 ], 'backgroundcolor', guiPanelStagesObj.guiElements.bgcolor);
            guiPanelStagesObj.guiElements.txtManualStagesXPosition = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'style', 'edit', 'string', '100', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.06, 0.2, 0.15, 0.09 ], 'backgroundcolor', [1 1 1]);
            guiPanelStagesObj.guiElements.lblManualStagesYPosition = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'style', 'text', 'string', 'Y', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.23 0.2 0.03 0.09 ], 'backgroundcolor', guiPanelStagesObj.guiElements.bgcolor);
            guiPanelStagesObj.guiElements.txtManualStagesYPosition = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'style', 'edit', 'string', '100', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.27, 0.2, 0.15, 0.09 ], 'backgroundcolor', [1 1 1]);
            guiPanelStagesObj.guiElements.lblManualStagesZPosition = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'style', 'text', 'string', 'Z', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.44 0.2 0.03 0.09 ], 'backgroundcolor', guiPanelStagesObj.guiElements.bgcolor);
            guiPanelStagesObj.guiElements.txtManualStagesZPosition = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'style', 'edit', 'string', '100', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.48, 0.2, 0.15, 0.09 ], 'backgroundcolor', [1 1 1]);
            guiPanelStagesObj.guiElements.btnManualStagesXYZGoto = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'String', 'go', 'units', 'normalized', 'position', [ 0.66, 0.2, 0.10, 0.09 ], 'callback', @(command, varargin)guiPanelStagesObj.btnManualStagesXYZGoto_callback('go'));
            
            guiPanelStagesObj.guiElements.btnManualStagesXYZGoHome = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'String', 'home all', 'units', 'normalized', 'position', [ 0.79, 0.2, 0.17, 0.09 ], 'callback', @(command, varargin)guiPanelStagesObj.btnManualStagesXYZGoto_callback('home all'));
            guiPanelStagesObj.guiElements.btnManualStagesLoadFlowcell = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'String', 'load flowcell', 'units', 'normalized', 'position', [ 0.05, 0.1, 0.23, 0.09 ], 'callback', @(command, varargin)guiPanelStagesObj.btnManualStagesXYZGoto_callback('load flowcell'));
            guiPanelStagesObj.guiElements.btnManualStagesImagePosition = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'String', 'image position', 'units', 'normalized', 'position', [ 0.32, 0.1, 0.26, 0.09 ], 'callback', @(command, varargin)guiPanelStagesObj.btnManualStagesXYZGoto_callback('image position'));

            guiPanelStagesObj.guiElements.chkManualStagesImageOnMove = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'style', 'checkbox', 'String', '<html>auto image<br>after move', 'value', false, 'units', 'normalized', 'position', [ 0.58, 0.3, 0.25, 0.16 ]);
            guiPanelStagesObj.guiElements.chkManualStagesObjectiveReferenced = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'style', 'checkbox', 'String', '<html>objective-<br>referenced<br>XY moves', 'value', true, 'units', 'normalized', 'position', [ 0.20, 0.33, 0.28, 0.2 ]);
            guiPanelStagesObj.guiElements.chkManualStagesUseFocusMap = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'style', 'checkbox', 'String', '<html>Z use<br>Focus Map', 'value', false, 'units', 'normalized', 'position', [ 0.83, 0.3, 0.17, 0.16 ]);

            %Halt button
            guiPanelStagesObj.guiElements.btnManualStagesHalt = uicontrol(guiPanelStagesObj.guiElements.pnlManualObjectStages, 'String', '<html><font color="white">STOP ALL MOTION<font>', 'units', 'normalized', 'position', [ 0.05 0.01 0.9 0.08 ], 'backgroundcolor', [1 0 0], 'callback', @guiPanelStagesObj.btnManualStagesHalt_callback);

            % Set position displays to show stage positions
            guiPanelStagesObj.updateManualStagesXPosition();
            guiPanelStagesObj.updateManualStagesYPosition();
            guiPanelStagesObj.updateManualStagesZPosition();
            
            % disable buttons that are supposed to be disabled (e.g. XY
            % controls if disableXY == 1)
            guiPanelStagesObj.disable();
            
        end
        
        function disable(guiPanelStagesObj)
            % disable all controls in the Stages panel
            children = get(guiPanelStagesObj.guiElements.pnlManualObjectStages,'Children');
            set(children,'Enable','off');
            
            % except for the HALT button!
            set(guiPanelStagesObj.guiElements.btnManualStagesHalt,'Enable','on');
        end
        
        function enable(guiPanelStagesObj)
            % enable all controls in the Stages panel
            children = get(guiPanelStagesObj.guiElements.pnlManualObjectStages,'Children');
            set(children,'Enable','on');
            
            % except for the ones we don't want to be enabled
            if (guiPanelStagesObj.disableX)
                set(guiPanelStagesObj.guiElements.btnManualStagesXYLeftSmallStep,'Enable','off');
                set(guiPanelStagesObj.guiElements.btnManualStagesXYRightSmallStep,'Enable','off');
                set(guiPanelStagesObj.guiElements.btnManualStagesXYLeftBigStep,'Enable','off');
                set(guiPanelStagesObj.guiElements.btnManualStagesXYRightBigStep,'Enable','off');
            end
            if (guiPanelStagesObj.disableY)
                set(guiPanelStagesObj.guiElements.btnManualStagesXYUpSmallStep,'Enable','off');
                set(guiPanelStagesObj.guiElements.btnManualStagesXYDownSmallStep,'Enable','off');
                set(guiPanelStagesObj.guiElements.btnManualStagesXYUpBigStep,'Enable','off');
                set(guiPanelStagesObj.guiElements.btnManualStagesXYDownBigStep,'Enable','off');
            end
            if (guiPanelStagesObj.disableZ)
                set(guiPanelStagesObj.guiElements.btnManualStagesZUpSmallStep,'Enable','off');
                set(guiPanelStagesObj.guiElements.btnManualStagesZDownSmallStep,'Enable','off');
                set(guiPanelStagesObj.guiElements.btnManualStagesZUpBigStep,'Enable','off');
                set(guiPanelStagesObj.guiElements.btnManualStagesZDownBigStep,'Enable','off');
                set(guiPanelStagesObj.guiElements.btnManualStagesZHome,'Enable','off');
            end
            if (guiPanelStagesObj.disableGoTo)
                set(guiPanelStagesObj.guiElements.btnManualStagesXYZGoto,'Enable','off');
                set(guiPanelStagesObj.guiElements.btnManualStagesXYZGoHome,'Enable','off');
                set(guiPanelStagesObj.guiElements.btnManualStagesLoadFlowcell,'Enable','off');
                set(guiPanelStagesObj.guiElements.btnManualStagesImagePosition,'Enable','off');
            end
            if (guiPanelStagesObj.disableUseZFocusMap)
                set(guiPanelStagesObj.guiElements.chkManualStagesUseFocusMap,'Enable','off');
            end
        end
        
        function btnManualStagesXYZGoto_callback(guiPanelStagesObj, command)
            % Go to a specified X,Y,Z position
            guiPanelStagesObj.disable();
            try
                switch command
                    case 'go'
                        newPosX = str2num(get(guiPanelStagesObj.guiElements.txtManualStagesXPosition,'string'));
                        newPosY = str2num(get(guiPanelStagesObj.guiElements.txtManualStagesYPosition,'string'));
                        newPosZ = str2num(get(guiPanelStagesObj.guiElements.txtManualStagesZPosition,'string'));
                        guiPanelStagesObj.hardware.stageAndFilterWheel.moveToXYZ(newPosX, newPosY, newPosZ);
                    case 'home all'
                        guiPanelStagesObj.hardware.stageAndFilterWheel.homeStage();
                    case 'home Z'
                        guiPanelStagesObj.hardware.stageAndFilterWheel.homeZ();
                    case 'load flowcell'
                        %guiPanelStagesObj.hardware.stageAndFilterWheel.moveToXYZ(guiPanelStagesObj.stageLoadFlowCellPosX, guiPanelStagesObj.stageLoadFlowCellPosY, guiPanelStagesObj.stageLoadFlowCellPosZ);
                        guiPanelStagesObj.hardware.gotoPreset('load flowcell');
                    case 'image position'
                        %guiPanelStagesObj.hardware.stageAndFilterWheel.moveToXYZ(guiPanelStagesObj.stageImageFlowCellPosX, guiPanelStagesObj.stageImageFlowCellPosY, guiPanelStagesObj.stageImageFlowCellPosZ);
                        guiPanelStagesObj.hardware.gotoPreset('image position', true);
                        if(guiPanelStagesObj.autoImage())
                            % execute image capture button callback
                            guiPanelStagesObj.panelImage.capture();
                        end
                    otherwise
                        error('gui:btnManualStagesXYZGoto_callback:invalidCommand', 'command must be "go" "home all" "home Z" "load flowcell" or "image position" only');
                end
                guiPanelStagesObj.updateManualStagesAll();
            catch err
                guiPanelStagesObj.updateManualStagesAll();
                errordlg(err.message,'Move XYZ error','modal');
            end
            guiPanelStagesObj.enable();
        end

        function btnManualStagesXYmove_callback(guiPanelStagesObj, dir, size)
            guiPanelStagesObj.disable();
            %msg = sprintf('Move stage XY %s %s', dir, size); disp(msg);
            
            try
                switch size
                    case 'small'
                        step = str2num(get(guiPanelStagesObj.guiElements.txtManualStagesXYSmallStepSize,'string'));
                    case 'large'
                        step = str2num(get(guiPanelStagesObj.guiElements.txtManualStagesXYLargeStepSize,'string'));
                    otherwise
                        error('gui:btnManualStagesXYmove_callback:invalidDirection','XY direction must be "small" or "large" only');
                end
                
                CheckParam.isNumeric(step, 'gui:btnManualStagesXYmove_callback:notNumeric');
                CheckParam.isWithinARange(step, guiPanelStagesObj.maxStep, guiPanelStagesObj.minStep, 'gui:btnManualStagesXYmove_callback:stepNotPositive');

                objectiveCentric = get(guiPanelStagesObj.guiElements.chkManualStagesObjectiveReferenced, 'Value');
                if(objectiveCentric)
                    step = (-1*step);             
                end
                
                switch dir
                    case 'left'
                        currXpos = guiPanelStagesObj.hardware.stageAndFilterWheel.whereIsX();
                        newPos = currXpos + step;
                        CheckParam.isWithinARange(newPos, guiPanelStagesObj.stageXLimitMin, guiPanelStagesObj.stageXLimitMax, 'gui:btnManualStagesXYmove_callback:newPosNotInRange');
                        guiPanelStagesObj.hardware.stageAndFilterWheel.moveX(newPos);
                        guiPanelStagesObj.updateManualStagesXPosition();
                    case 'right'
                        currXpos = guiPanelStagesObj.hardware.stageAndFilterWheel.whereIsX();
                        newPos = currXpos - step;
                        CheckParam.isWithinARange(newPos, guiPanelStagesObj.stageXLimitMin, guiPanelStagesObj.stageXLimitMax, 'gui:btnManualStagesXYmove_callback:newPosNotInRange');
                        guiPanelStagesObj.hardware.stageAndFilterWheel.moveX(newPos);
                        guiPanelStagesObj.updateManualStagesXPosition();
                    case 'up'
                        currYpos = guiPanelStagesObj.hardware.stageAndFilterWheel.whereIsY();
                        newPos = currYpos - step;
                        CheckParam.isWithinARange(newPos, guiPanelStagesObj.stageYLimitMin, guiPanelStagesObj.stageYLimitMax, 'gui:btnManualStagesXYmove_callback:newPosNotInRange');
                        guiPanelStagesObj.hardware.stageAndFilterWheel.moveY(newPos);
                        guiPanelStagesObj.updateManualStagesYPosition();
                    case 'down'
                        currYpos = guiPanelStagesObj.hardware.stageAndFilterWheel.whereIsY();
                        newPos = currYpos + step;
                        CheckParam.isWithinARange(newPos, guiPanelStagesObj.stageYLimitMin, guiPanelStagesObj.stageYLimitMax, 'gui:btnManualStagesXYmove_callback:newPosNotInRange');
                        guiPanelStagesObj.hardware.stageAndFilterWheel.moveY(newPos);
                        guiPanelStagesObj.updateManualStagesYPosition();
                    otherwise
                        error('gui:btnManualStagesXYmove_callback:invalidDirection','XY direction must be "left" "right" "up" or "down" only');
                end
                
                if(guiPanelStagesObj.ZuseFocusMap())
                    %if "use focus map for Z position" checkbox is checked
                    guiPanelStagesObj.hardware.focusZ();
                end
                
            catch err
                guiPanelStagesObj.updateManualStagesXPosition();
                guiPanelStagesObj.updateManualStagesYPosition();
                errordlg(err.message,'Move XY error','modal');
            end

            if (guiPanelStagesObj.autoImage())
                % execute image capture button callback
                guiPanelStagesObj.panelImage.capture();
            end
            
            guiPanelStagesObj.enable();
        end   
        
        function TF = ZuseFocusMap(guiPanelStagesObj)
             TF = get(guiPanelStagesObj.guiElements.chkManualStagesUseFocusMap, 'Value');
        end
        
        function updateManualStagesAll(guiPanelStagesObj)
            guiPanelStagesObj.updateManualStagesXPosition();
            guiPanelStagesObj.updateManualStagesYPosition();
            guiPanelStagesObj.updateManualStagesZPosition();
        end
        
        function updateManualStagesXPosition(guiPanelStagesObj)
            if (~guiPanelStagesObj.testMode)
                currXpos = guiPanelStagesObj.hardware.stageAndFilterWheel.whereIsX();
                set(guiPanelStagesObj.guiElements.txtManualStagesXPosition,'string',num2str(currXpos));
            end
        end
        
        function updateManualStagesYPosition(guiPanelStagesObj)
            if (~guiPanelStagesObj.testMode)
                currYpos = guiPanelStagesObj.hardware.stageAndFilterWheel.whereIsY();
                set(guiPanelStagesObj.guiElements.txtManualStagesYPosition,'string',num2str(currYpos));
            end
        end
        
        function updateManualStagesZPosition(guiPanelStagesObj)
            if (~guiPanelStagesObj.testMode)
                currZpos = guiPanelStagesObj.hardware.stageAndFilterWheel.whereIsZ();
                set(guiPanelStagesObj.guiElements.txtManualStagesZPosition,'string',num2str(currZpos));
            end
        end

        function btnManualStagesHalt_callback(guiPanelStagesObj, h, e, varargin)
            guiPanelStagesObj.hardware.stageAndFilterWheel.haltXY();
            guiPanelStagesObj.hardware.stageAndFilterWheel.haltZ();
        end
        
        function btnManualStagesZmove_callback(guiPanelStagesObj, dir, size)
            guiPanelStagesObj.disable();

            try
                switch size
                    case 'small'
                        step = str2num(get(guiPanelStagesObj.guiElements.txtManualStagesZSmallStepSize,'string'));
                    case 'large'
                        step = str2num(get(guiPanelStagesObj.guiElements.txtManualStagesZLargeStepSize,'string'));
                    otherwise
                        error('gui:btnManualStagesZmove_callback:invalidDirection','XY direction must be "small" or "large" only');
                end

                CheckParam.isNumeric(step, 'gui:btnManualStagesZmove_callback:notNumeric');
                CheckParam.isWithinARange(step, guiPanelStagesObj.maxStep, guiPanelStagesObj.minStep, 'gui:btnManualStagesZmove_callback:stepNotPositive');

                switch dir
                    case 'up'
                        currZpos = guiPanelStagesObj.hardware.stageAndFilterWheel.whereIsZ();
                        newPos = currZpos + step;
                        %disp(newPos);
                        CheckParam.isWithinARange(newPos, guiPanelStagesObj.stageZLimitMin, guiPanelStagesObj.stageZLimitMax, 'gui:btnManualStagesZmove_callback:newPosNotInRange');
                        guiPanelStagesObj.hardware.stageAndFilterWheel.moveZ(newPos);
                        guiPanelStagesObj.updateManualStagesZPosition();
                    case 'down'
                        currZpos = guiPanelStagesObj.hardware.stageAndFilterWheel.whereIsZ();
                        newPos = currZpos - step;
                        %disp(newPos);
                        CheckParam.isWithinARange(newPos, guiPanelStagesObj.stageZLimitMin, guiPanelStagesObj.stageZLimitMax, 'gui:btnManualStagesZmove_callback:newPosNotInRange');
                        guiPanelStagesObj.hardware.stageAndFilterWheel.moveZ(newPos);
                        guiPanelStagesObj.updateManualStagesZPosition();
                    otherwise
                        error('gui:btnManualStagesZmove_callback:invalidDirection','XY direction must be "left" "right" "up" or "down" only');
                end
            catch err
                guiPanelStagesObj.updateManualStagesZPosition();
                errordlg(err.message,'Move Z error','modal');
            end

            if (guiPanelStagesObj.autoImage())
                % execute image capture button callback
                guiPanelStagesObj.panelImage.capture();
            end

            guiPanelStagesObj.enable();
        end

        %boolean function to indicate if the 'auto image after move'
        %checkbox is checked
        function TF = autoImage(guiPanelStagesObj)
            TF = get(guiPanelStagesObj.guiElements.chkManualStagesImageOnMove, 'Value');
        end
        
    end % END PUBLIC METHODS
end % END GUI CLASS 