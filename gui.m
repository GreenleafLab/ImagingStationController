% Fluorescence Imaging Machine GUI
% Peter McMahon / pmcmahon@stanford.edu
% Curtis Layton
% October, November 2012

% This code has only been tested with MATLAB R2010b, Version 7.11.0.584
% (32-bit Windows). Many of the GUI functions are MATLAB-version-dependent.


%TODO - call stopPollingLoop() (and other shutdown code) when the gui window
%is closed!, with appropriate 'are you sure, a script is running' messages,
%etc.


classdef gui < handle
    
    properties % PROPERTIES
        
        hardware; %reference to the hardware object
        guiElements;
        script; % holds the script objects (command list, sub list)
        
        pollingLoop;
        
        % the current point (x,y,z) can be stored, so that a partial
        % history of the stage position can be plotted
        stageHistoryX = [];
        stageHistoryY = [];
        stageHistoryZ = [];
        
        fStagePositionHistory; % handle to figure displaying stage position history
        
        defaultImageSavePath; %default path to save images
        defaultFileNameRoot; %default root (descriptive string before the timestamp) of the filename
        
    end % END PROPERTIES
    
    properties (Constant) % CONSTANT PROPERTIES
        
        testMode = 0; % if testMode==1, then the GUI code won't try interact with the hardware (use for testing the GUI code)
        
    end % CONSTANT PROPERTIES
    
    
    methods (Access = private) % PRIVATE METHODS

        function windowClose_callback(guiObj, h, e, varargin)
            disp('CLOSE REQUEST');
            
            %close figure
            if isempty(gcbf)
                if length(dbstack) == 1
                    warning('MATLAB:closereq', ...
                            'Calling closereq from the command line is now obsolete, use close instead');
                end
                close force
            else
                if (isa(gcbf,'ui.figure'))
                    % Convert GBT1.5 figure to a double.
                    delete(double(gcbf));
                else
                    delete(gcbf);
                end
            end
            delete(guiObj);
        end

    end % END PRIVATE METHODS
    
    
    methods % PUBLIC METHODS

        function guiObj = gui() %constructor
            % Startup code
            if (~guiObj.testMode)
                guiObj.hardware = ImagingStationHardware();
                
                guiObj.pollingLoop = PollingLoop();
            end
         
            guiObj.setupGui();

            if (~guiObj.testMode) 
%            if (~1) 
                %power up lasers
                %disable image panel while lasers power on
                guiObj.guiElements.guiPanelImageObj.disablePanelTillPowerReached();
                guiObj.hardware.lasers.powerUpLasers();
            end
        end
            
        function delete(guiObj)
            guiObj.pollingLoop.stopPollingLoop();
        end
                        
        function setupGui(guiObj)
            
            guiObj.defaultImageSavePath = 'C:\scriptImages\';
            guiObj.defaultFileNameRoot = 'Image_';
            
            %main figure
            guiObj.guiElements.guiFigure = figure('name', 'Fluorescence Imager Control GUI', 'numbertitle', 'off', 'menubar', 'none', 'units', 'normalized', 'position', [0.1 0.1 0.7 0.7], 'CloseRequestFcn', @guiObj.windowClose_callback);
            iptPointerManager(guiObj.guiElements.guiFigure);
            
            %suppress several warnings that arise
            % TODO - actually fix the issues at hand
            warning('off','MATLAB:uitab:DeprecatedFunction');
            warning('off','MATLAB:uitabgroup:DeprecatedFunction');
            warning('off','MATLAB:uitree:DeprecatedFunction');
            warning('off','MATLAB:uitabgroup:OldVersion');
            warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
            warning('off','MATLAB:hg:JavaSetHGProperty');
            
            % divide window into top and bottom; bottom will be the status
            % bar; top will contain everything else
            [guiObj.guiElements.hBottom,guiObj.guiElements.hTop,guiObj.guiElements.hDivTopBottom] = uisplitpane(gcf,'dividercolor','k','dividerwidth',1,'orientation','ver');
            guiObj.guiElements.hDivTopBottom.DividerLocation = 0.05;

            % divide top into left and right
            [guiObj.guiElements.hLeft,guiObj.guiElements.hRight,guiObj.guiElements.hDiv] = uisplitpane(guiObj.guiElements.hTop,'dividercolor','k','dividerwidth',3);
            guiObj.guiElements.hDiv.DividerLocation = 0.4;
            
            guiObj.guiElements.hTabGroup = uitabgroup(guiObj.guiElements.hLeft); drawnow;
            guiObj.guiElements.tbScripted = uitab(guiObj.guiElements.hTabGroup, 'title','Scripted');
            %a = axes('parent', tab1); surf(peaks);
            guiObj.guiElements.tbManual = uitab(guiObj.guiElements.hTabGroup, 'title','Manual');
            %uicontrol(tab2, 'String','Close', 'Callback','close(gcbf)');
            
            %guiObj.guiElements.lbCommandList = uicontrol(guiObj.guiElements.tbScripted, 'style', 'listbox', 'units', 'normalized', 'position', [0.05 0.6 0.8 0.3], 'string', {'cmd1', 'cmd2', 'cmd3'}, 'callback', @lbCommandList_callback);
            %set(guiObj.guiElements.lbCommandList, 'backgroundcolor', [1 1 1]);

            import javax.swing.*
            import javax.swing.tree.*;
            
            [guiObj.guiElements.treeCommandList,guiObj.guiElements.treeCommandList_container] = uitree('v0');
            set(guiObj.guiElements.treeCommandList_container, 'Parent', guiObj.guiElements.tbScripted);
            set(guiObj.guiElements.treeCommandList_container, 'Units','normalized', 'Position',[0.05 0.59 0.8 0.3]);
            
            guiObj.guiElements.btnCommandListMoveUp = uicontrol(guiObj.guiElements.tbScripted, 'String', '^', 'units', 'normalized', 'position', [0.87 0.85 0.1 0.05]);
            guiObj.guiElements.btnCommandListMoveDown = uicontrol(guiObj.guiElements.tbScripted, 'String', 'v', 'units', 'normalized', 'position', [0.87 0.6 0.1 0.05]);

            guiObj.guiElements.bgcolor = get(guiObj.guiElements.btnCommandListMoveUp, 'backgroundcolor'); % store background color here (or set to [1 1 1] when debugging UI layout)
            %guiObj.guiElements.bgcolor = [1 1 1]; % use white for testing purposes, to be able to see box bounds
            
            
            % Put a "status bar" in the bottom panel
            % TODO: completely phase out this lblStatusBar, and use only
            % the StatusBar control
            guiObj.guiElements.lblStatusBar = uicontrol(guiObj.guiElements.hBottom, 'style', 'text', 'string', 'Ready.', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.5, 0.05, 0.4, 0.9 ], 'backgroundcolor', guiObj.guiElements.bgcolor);
            guiObj.guiElements.guiPanelStatusbarObj = guiPanelStatusbar(guiObj.guiElements.hBottom, [ 0.05, 0.05, 0.4, 0.9 ], guiObj.guiElements.bgcolor);        
           
            guiObj.guiElements.pmProcedure = uicontrol(guiObj.guiElements.tbScripted, 'style', 'popupmenu', 'string', {'MAIN'}, 'units', 'normalized', 'position', [ 0.6 0.95 0.35 0.07 ], 'backgroundcolor', [1 1 1], 'callback', @guiObj.pmProcedure_callback);

            guiObj.guiElements.btnStart = uicontrol(guiObj.guiElements.tbScripted, 'String', 'Start', 'units', 'normalized', 'position', [0.6 0.02 0.35 0.07]);

            guiObj.guiElements.btnLoadScript = uicontrol(guiObj.guiElements.tbScripted, 'String', 'Load Script', 'units', 'normalized', 'position', [0.05 0.95 0.25 0.04], 'callback', @guiObj.btnLoadScript_callback);
            guiObj.guiElements.btnSaveScript = uicontrol(guiObj.guiElements.tbScripted, 'String', 'Save Script', 'units', 'normalized', 'position', [0.32 0.95 0.25 0.04]);

            guiObj.guiElements.btnAddCommand = uicontrol(guiObj.guiElements.tbScripted, 'String', 'Add Cmd', 'units', 'normalized', 'position', [0.05 0.9 0.25 0.04]);
            guiObj.guiElements.btnDeleteCommand = uicontrol(guiObj.guiElements.tbScripted, 'String', 'Delete Cmd', 'units', 'normalized', 'position', [0.32 0.9 0.25 0.04], 'callback', @btnDeleteCommand_callback);
            guiObj.guiElements.btnAddLoop = uicontrol(guiObj.guiElements.tbScripted, 'String', 'Add Loop', 'units', 'normalized', 'position', [0.59 0.9 0.15 0.04]);
            guiObj.guiElements.btnEditLoop = uicontrol(guiObj.guiElements.tbScripted, 'String', 'Edit Loop', 'units', 'normalized', 'position', [0.76 0.9 0.15 0.04]);
            
            guiObj.guiElements.pnlCommandEditor = uipanel(guiObj.guiElements.tbScripted, 'title', 'Command Editor', 'units', 'normalized', 'position', [0.05 0.1 0.9 0.5]);
            guiObj.guiElements.lblObject = uicontrol(guiObj.guiElements.pnlCommandEditor, 'style', 'text', 'string', 'Object:', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.05 0.9 0.2 0.07 ], 'backgroundcolor', guiObj.guiElements.bgcolor);
            guiObj.guiElements.pmObject = uicontrol(guiObj.guiElements.pnlCommandEditor, 'style', 'popupmenu', 'string', {'Pump', 'Image', 'Temp Control'}, 'units', 'normalized', 'position', [ 0.3 0.9 0.6 0.1 ], 'backgroundcolor', [1 1 1], 'callback', @guiObj.pmObject_callback);

            guiObj.guiElements.pnlCommandPropertiesPump = uipanel(guiObj.guiElements.pnlCommandEditor, 'title', 'Pump Command Properties', 'units', 'normalized', 'position', [0.05 0.15 0.9 0.7]);
            guiObj.guiElements.pnlCommandPropertiesImage = uipanel(guiObj.guiElements.pnlCommandEditor, 'title', 'Image Command Properties', 'units', 'normalized', 'position', [0.05 0.15 0.9 0.7]);
            guiObj.guiElements.pnlCommandPropertiesTemp = uipanel(guiObj.guiElements.pnlCommandEditor, 'title', 'Temp Command Properties', 'units', 'normalized', 'position', [0.05 0.15 0.9 0.7]);


            % Pump Command
            guiObj.guiElements.lblCmdPumpVolume = uicontrol(guiObj.guiElements.pnlCommandPropertiesPump, 'style', 'text', 'string', 'Volume:', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.05, 0.8, 0.4, 0.15 ], 'backgroundcolor', guiObj.guiElements.bgcolor);
            guiObj.guiElements.lblCmdPumpFlowRate = uicontrol(guiObj.guiElements.pnlCommandPropertiesPump, 'style', 'text', 'string', 'Flow Rate:', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.05, 0.6, 0.4, 0.15 ], 'backgroundcolor', guiObj.guiElements.bgcolor);
            guiObj.guiElements.lblCmdPumpFromPosition = uicontrol(guiObj.guiElements.pnlCommandPropertiesPump, 'style', 'text', 'string', 'From Position:', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.05, 0.4, 0.4, 0.15 ], 'backgroundcolor', guiObj.guiElements.bgcolor);

            %TODO fix the scripted stuff to get appropriate parameters from
            %somewhere proper
            %guiObj.guiElements.txtCmdPumpVolume = uicontrol(guiObj.guiElements.pnlCommandPropertiesPump, 'style', 'edit', 'string', guiObj.defaultPumpVolume, 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.5, 0.8, 0.27, 0.15 ], 'backgroundcolor', [1 1 1]);
            guiObj.guiElements.lblCmdPumpVolumeUnits = uicontrol(guiObj.guiElements.pnlCommandPropertiesPump, 'style', 'text', 'string', 'ul', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.8, 0.8, 0.1, 0.15 ], 'backgroundcolor', guiObj.guiElements.bgcolor);
            %guiObj.guiElements.txtCmdPumpFlowRate = uicontrol(guiObj.guiElements.pnlCommandPropertiesPump, 'style', 'edit', 'string', guiObj.defaultPumpFlowRate, 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.5, 0.6, 0.27, 0.15 ], 'backgroundcolor', [1 1 1]);
            guiObj.guiElements.lblCmdPumpFlowRateUnits = uicontrol(guiObj.guiElements.pnlCommandPropertiesPump, 'style', 'text', 'string', 'ul/min', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.8, 0.6, 0.2, 0.15 ], 'backgroundcolor', guiObj.guiElements.bgcolor);
            %guiObj.guiElements.pmCmdPumpFromPosition = uicontrol(guiObj.guiElements.pnlCommandPropertiesPump, 'style', 'popupmenu', 'string', positionArray, 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.5, 0.4, 0.4, 0.15 ], 'backgroundcolor', [1 1 1]);


            % Image Command
            guiObj.guiElements.lblCmdImageTileNumber = uicontrol(guiObj.guiElements.pnlCommandPropertiesImage, 'style', 'text', 'string', 'Tile number:', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.05, 0.8, 0.4, 0.15 ], 'backgroundcolor', guiObj.guiElements.bgcolor);
            guiObj.guiElements.lblCmdImageLaser = uicontrol(guiObj.guiElements.pnlCommandPropertiesImage, 'style', 'text', 'string', 'Laser:', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.05, 0.6, 0.4, 0.15 ], 'backgroundcolor', guiObj.guiElements.bgcolor);
            guiObj.guiElements.lblCmdImageLaserPower = uicontrol(guiObj.guiElements.pnlCommandPropertiesImage, 'style', 'text', 'string', 'Laser Power:', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.05, 0.4, 0.4, 0.15 ], 'backgroundcolor', guiObj.guiElements.bgcolor);
            guiObj.guiElements.lblCmdImageFilter = uicontrol(guiObj.guiElements.pnlCommandPropertiesImage, 'style', 'text', 'string', 'Filter:', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.05, 0.2, 0.4, 0.15 ], 'backgroundcolor', guiObj.guiElements.bgcolor);
            guiObj.guiElements.lblCmdImageExposureTime = uicontrol(guiObj.guiElements.pnlCommandPropertiesImage, 'style', 'text', 'string', 'Exposure Time:', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.05, 0.0, 0.4, 0.15 ], 'backgroundcolor', guiObj.guiElements.bgcolor);

            guiObj.guiElements.txtCmdImageTileNumber = uicontrol(guiObj.guiElements.pnlCommandPropertiesImage, 'style', 'edit', 'string', '1', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.5, 0.8, 0.4, 0.15 ], 'backgroundcolor', [1 1 1]);
            guiObj.guiElements.pmCmdImageLaser = uicontrol(guiObj.guiElements.pnlCommandPropertiesImage, 'style', 'popupmenu', 'string', {'Red (660nm)', 'Green (532nm)'}, 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.5, 0.6, 0.4, 0.15 ], 'backgroundcolor', [1 1 1]);
            guiObj.guiElements.txtCmdImageLaserPower = uicontrol(guiObj.guiElements.pnlCommandPropertiesImage, 'style', 'edit', 'string', '100', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.5, 0.4, 0.27, 0.15 ], 'backgroundcolor', [1 1 1]);
            guiObj.guiElements.lblCmdImageLaserPowerUnits = uicontrol(guiObj.guiElements.pnlCommandPropertiesImage, 'style', 'text', 'string', 'mW', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.8, 0.4, 0.1, 0.15 ], 'backgroundcolor', guiObj.guiElements.bgcolor);
            guiObj.guiElements.pmCmdImageFilter = uicontrol(guiObj.guiElements.pnlCommandPropertiesImage, 'style', 'popupmenu', 'string', {'Filter 1', 'Filter 2'}, 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.5, 0.2, 0.4, 0.15 ], 'backgroundcolor', [1 1 1]);
            guiObj.guiElements.txtCmdImageExposureTime = uicontrol(guiObj.guiElements.pnlCommandPropertiesImage, 'style', 'edit', 'string', '100', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.5, 0.0, 0.27, 0.15 ], 'backgroundcolor', [1 1 1]);
            guiObj.guiElements.lblCmdImageExposureTimeUnits = uicontrol(guiObj.guiElements.pnlCommandPropertiesImage, 'style', 'text', 'string', 'ms', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.8, 0.0, 0.1, 0.15 ], 'backgroundcolor', guiObj.guiElements.bgcolor);

            
            % Temperature Command
            guiObj.guiElements.lblCmdTempSetTemp = uicontrol(guiObj.guiElements.pnlCommandPropertiesTemp, 'style', 'text', 'string', 'Set Temp:', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.05, 0.8, 0.4, 0.15 ], 'backgroundcolor', guiObj.guiElements.bgcolor);
            guiObj.guiElements.lblCmdTempRampRate = uicontrol(guiObj.guiElements.pnlCommandPropertiesTemp, 'style', 'text', 'string', 'Ramp Rate:', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.05, 0.6, 0.4, 0.15 ], 'backgroundcolor', guiObj.guiElements.bgcolor);

            guiObj.guiElements.txtCmdTempSetTemp = uicontrol(guiObj.guiElements.pnlCommandPropertiesTemp, 'style', 'edit', 'string', '30', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.5, 0.8, 0.27, 0.15 ], 'backgroundcolor', [1 1 1]);
            guiObj.guiElements.lblCmdTempSetTempUnits = uicontrol(guiObj.guiElements.pnlCommandPropertiesTemp, 'style', 'text', 'string', '°C', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.8, 0.8, 0.1, 0.15 ], 'backgroundcolor', guiObj.guiElements.bgcolor);
            guiObj.guiElements.txtCmdTempRampRate = uicontrol(guiObj.guiElements.pnlCommandPropertiesTemp, 'style', 'edit', 'string', '0.1', 'HorizontalAlignment', 'right', 'units', 'normalized', 'position', [ 0.5, 0.6, 0.27, 0.15 ], 'backgroundcolor', [1 1 1]);
            guiObj.guiElements.lblCmdTempRampRateUnits = uicontrol(guiObj.guiElements.pnlCommandPropertiesTemp, 'style', 'text', 'string', '°C/min', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.8, 0.6, 0.15, 0.15 ], 'backgroundcolor', guiObj.guiElements.bgcolor);


            % Update command
            guiObj.guiElements.btnCommandEditorUpdate = uicontrol(guiObj.guiElements.pnlCommandEditor, 'String', 'Update', 'units', 'normalized', 'position', [0.05 0.03 0.35 0.1]);

            
            % show pump panel only
            set(guiObj.guiElements.pnlCommandPropertiesPump,'visible','on');
            set(guiObj.guiElements.pnlCommandPropertiesImage,'visible','off');
            set(guiObj.guiElements.pnlCommandPropertiesTemp,'visible','off');

   
            % Manual tab

            % Stage Control
            guiObj.guiElements.guiPanelStagesObj = guiPanelStages(guiObj.hardware, guiObj.testMode, guiObj.guiElements.tbManual, [0.05 0.57 0.9 0.44], guiObj.guiElements.bgcolor, 0, 0, 0, 0, 0, 1, []);
            
            
%Nandita D 25/7/13
%             % Temp Control
             guiObj.guiElements.guiPanelTempObj =  guiPanelTemp(guiObj.hardware, guiObj.testMode, guiObj.guiElements.tbManual, [0.05 0.48 0.6 0.08], guiObj.guiElements.bgcolor, guiObj.pollingLoop, guiObj.guiElements.guiPanelStatusbarObj);
%%Nandita D 25/7/13

% %Johan 1/13/2015
%              % Autosampler Temp Control
%              guiObj.guiElements.guiPanelAutosamplerTempObj  =  guiPanelAutosamplerTemp(guiObj.hardware, guiObj.testMode, guiObj.guiElements.tbManual, [0.65 0.48 0.3 0.08], guiObj.guiElements.bgcolor, guiObj.pollingLoop, guiObj.guiElements.guiPanelStatusbarObj);
% %Johan 1/13/2015

% Pump Control
            guiObj.guiElements.guiPanelPumpObj = guiPanelPump(guiObj.hardware, guiObj.testMode, guiObj.guiElements.tbManual, [0.05 0.33 0.9 0.15], guiObj.guiElements.bgcolor, guiObj.pollingLoop, guiObj.guiElements.guiPanelStatusbarObj);

            % Laser Control (Red)
            guiObj.guiElements.guiPanelRedLaserObj = guiPanelRedLaser(guiObj.hardware, guiObj.testMode, guiObj.guiElements.tbManual, [0.05 0.26 0.9 0.07], guiObj.guiElements.bgcolor, guiObj.pollingLoop, guiObj.guiElements.guiPanelStatusbarObj);

            % Laser Control (Green)
            guiObj.guiElements.guiPanelGreenLaserObj = guiPanelGreenLaser(guiObj.hardware, guiObj.testMode, guiObj.guiElements.tbManual, [0.05 0.19 0.9 0.07], guiObj.guiElements.bgcolor, guiObj.pollingLoop, guiObj.guiElements.guiPanelStatusbarObj);

            %assign references to the respective laser panels
            guiObj.guiElements.guiPanelRedLaserObj.panelGreenLaser = guiObj.guiElements.guiPanelGreenLaserObj;
            guiObj.guiElements.guiPanelGreenLaserObj.panelRedLaser = guiObj.guiElements.guiPanelRedLaserObj;

            % Image Control
            guiObj.guiElements.guiPanelImageObj = guiPanelImage(guiObj.hardware, guiObj.testMode, guiObj.guiElements.tbManual, [0.05 0 0.9 0.19], guiObj.guiElements.bgcolor, @guiObj.updateDisplayImageSettingsPixelValueReset, guiObj.pollingLoop, guiObj.guiElements.guiPanelStatusbarObj);
            guiObj.guiElements.guiPanelStagesObj.panelImage = guiObj.guiElements.guiPanelImageObj;
            
            %assign references to the image panel
            guiObj.guiElements.guiPanelRedLaserObj.panelImage = guiObj.guiElements.guiPanelImageObj;
            guiObj.guiElements.guiPanelGreenLaserObj.panelImage = guiObj.guiElements.guiPanelImageObj;

            % Manual more options
            guiObj.guiElements.btnManualMoreOptions = uicontrol(guiObj.guiElements.tbManual, 'String', 'Menu', 'units', 'normalized', 'position', [ 0.85, 0.95, 0.15, 0.05 ]);
            guiObj.guiElements.mnuManualMoreOptions = uicontextmenu;
            set(guiObj.guiElements.btnManualMoreOptions,'uicontextmenu',guiObj.guiElements.mnuManualMoreOptions);
            guiObj.guiElements.mnuManualMoreOptionsSaveImage = uimenu(guiObj.guiElements.mnuManualMoreOptions, 'Label', 'Save Image', 'callback', @guiObj.mnuManualMoreOptionsSaveImage_callback);
            guiObj.guiElements.mnuManualMoreOptionsFocusMapWizard = uimenu(guiObj.guiElements.mnuManualMoreOptions, 'Label', 'Focus Map Wizard', 'callback', @guiObj.mnuManualMoreOptionsFocusMapWizard_callback);
            guiObj.guiElements.mnuManualMoreOptionsEdgeFinderWizard = uimenu(guiObj.guiElements.mnuManualMoreOptions, 'Label', 'Edge Finder Wizard', 'callback', @guiObj.mnuManualMoreOptionsEdgeFinderWizard_callback);
            guiObj.guiElements.mnuManualMoreOptionsGoToTile = uimenu(guiObj.guiElements.mnuManualMoreOptions, 'Label', 'Go To Tile', 'callback', @guiObj.mnuManualMoreOptionsGoToTile_callback);
            guiObj.guiElements.mnuManualMoreOptionsAddCurrentStagePositionToHistory = uimenu(guiObj.guiElements.mnuManualMoreOptions, 'Label', 'Add current stage position to history', 'callback', @guiObj.mnuManualMoreOptionsAddCurrentStagePositionToHistory_callback);
            guiObj.guiElements.mnuManualMoreOptionsClearStagePositionHistory = uimenu(guiObj.guiElements.mnuManualMoreOptions, 'Label', 'Clear stage position history', 'callback', @guiObj.mnuManualMoreOptionsClearStagePositionHistory_callback);
            

            % Image Navigation Panel
            guiObj.guiElements.pnlImageNavigation = guiPanelDisplayImage      (guiObj.hardware, guiObj.testMode, guiObj.guiElements.hRight, [0.0 0.4 1.0 0.6], guiObj.guiElements.bgcolor, guiObj.guiElements.guiPanelStatusbarObj, false);
            set(guiObj.guiElements.guiFigure, 'ResizeFcn', @guiObj.figureResize_callback);
            
            % Display Laser Powers panel
            guiObj.guiElements.pnlDisplayLasers = guiPanelLaserPower          (guiObj.hardware, guiObj.testMode, guiObj.guiElements.hRight, [0.0 0.3 1.0 0.1], guiObj.guiElements.bgcolor, guiObj.pollingLoop, guiObj.guiElements.guiPanelStatusbarObj);

%Nandita D 25/7/13
%             % Display temperature panel
            guiObj.guiElements.pnlDisplayTemp = guiPanelTempGraph(guiObj.hardware, guiObj.testMode, guiObj.guiElements.hRight, [0.0 0.0 1.0 0.3], guiObj.guiElements.bgcolor, guiObj.pollingLoop, guiObj.guiElements.guiPanelStatusbarObj);
% %Nandita D 25/7/13

% %Johan 1/13/2015
%              % Display temperature panel
%               guiObj.guiElements.pnlDisplayAutosamplerTemp = guiPanelAutosamplerTempGraph(guiObj.hardware, guiObj.testMode, guiObj.guiElements.hRight, [0.0 0.0 1.0 0.15], guiObj.guiElements.bgcolor, guiObj.pollingLoop, guiObj.guiElements.guiPanelStatusbarObj);
% %Johan 1/13/2015
        end
        
        
        function disableManual(guiObj)
            % disable all controls in the Manual tab
            
            % disable all controls in the Stages panel
            guiObj.guiElements.pnlManualObjectStages.disable();
            
            % disable all controls in the Temp panel
            guiObj.guiElements.pnlManualObjectTemp.disable();
            
            % disable all controls in the Autosampler Temp panel
            guiObj.guiElements.pnlManualObjectAutosamplerTemp.disable();

            % disable all controls in the Laser Red panel
            guiObj.guiElements.guiPanelRedLaserObj.disable();
            
            % disable all controls in the Laser Green panel
            guiObj.guiElements.guiPanelGreenLaserObj.disable();
            
            % disable all controls in the Pump panel
            guiObj.guiElements.guiPanelPumpObj.disable();
            
            % disable all controls in the Image panel
            guiObj.guiElements.guiPanelImageObj.disable();
        end
        
        function enableManual(guiObj)
            % enable all controls in the Manual tab
            
            % enable all controls in the Stages panel
            guiObj.guiElements.pnlManualObjectStages.enable();
            
            % enable all controls in the Temp panel
            guiObj.guiElements.pnlManualObjectTemp.enable();
            
            % enable all controls in the Autosampler Temp panel
            guiObj.guiElements.pnlManualObjectAutosamplerTemp.enable();
            
            % enable all controls in the Laser Red panel
            guiObj.guiElements.guiPanelRedLaserObj.enable();
            
            % enable all controls in the Laser Green panel
            guiObj.guiElements.guiPanelGreenLaserObj.enable();
            
            % enable all controls in the Pump panel
            guiObj.guiElements.guiPanelPumpObj.enable();
            
            % enable all controls in the Image panel
            guiObj.guiElements.guiPanelImageObj.enable();
        end

        
        function reloadCommandTree(guiObj, procedure)
            guiObj.guiElements.treeCommandList.setVisible(1); % for whatever reason, MATLAB hides the treeview when tabs are switched, so just in case, make it visible again
            
            greenArrowIcon = fullfile(matlabroot,'/toolbox/matlab/icons/greenarrowicon.gif'); % use this to customize tree icon (use this for variables)

            import javax.swing.*
            import javax.swing.tree.*;
            
            globalvarroot = uitreenode('v0','globvarroot','GLOBALS',greenArrowIcon,false);
            
            global globalVarList; % get global variable list from xml2struct call
            
            
            root = uitreenode('v0','root',procedure,[],false);

            if strcmp(procedure,'MAIN')==1 % we must load the MAIN procedure
                commandList = guiObj.script.commandList;
            else % load one of the script's subroutines
                commandList = guiObj.script.subList(procedure).commandList;
            end
            
            % loop through each command and add it to the tree
            for cmdIdx = 1:commandList.getNumCommands()
                currCommand = commandList.getCommand(cmdIdx);
                %currCommand.commandName
                
                if (strcmp(currCommand.commandName,'userwait'))
                    % user message can either be a string or a variable; if
                    % a variable, write the name
                    if isa(currCommand.parameters.message,'char')
                        msg = guiObj.strTrunc(currCommand.parameters.message,50);
                    elseif isa(currCommand.parameters.message,'ScriptVariable')
                        msg = strcat('VAR[',currCommand.parameters.message.name,']'); 
                    end
                    node = uitreenode('v0',strcat('node-cmd-',int2str(cmdIdx)),strcat('UserWait: ',msg),[],true);
                elseif (strcmp(currCommand.commandName,'sub call'))
                    node = uitreenode('v0',strcat('node-cmd-',int2str(cmdIdx)),strcat('SubCall: ',currCommand.mySubroutine.name),[],true);
                elseif (strcmp(currCommand.commandName,'temp'))
                    node = uitreenode('v0',strcat('node-cmd-',int2str(cmdIdx)),strcat('Temp: '),[],true);
                elseif (strcmp(currCommand.commandName,'pump'))
                    node = uitreenode('v0',strcat('node-cmd-',int2str(cmdIdx)),strcat('Pump: '),[],true);
                elseif (strcmp(currCommand.commandName,'image'))
                    node = uitreenode('v0',strcat('node-cmd-',int2str(cmdIdx)),strcat('Image: '),[],true);
                elseif (strcmp(currCommand.commandName,'wait'))
                    node = uitreenode('v0',strcat('node-cmd-',int2str(cmdIdx)),strcat('Wait: '),[],true);
                elseif (strcmp(currCommand.commandName,'loop'))
                    node = uitreenode('v0',strcat('node-cmd-',int2str(cmdIdx)),strcat('Loop: '),[],true);
                end
                
                root.add(node);
            end
            
            treeModel = DefaultTreeModel(root);
            guiObj.guiElements.treeCommandList.setModel(treeModel);
            guiObj.guiElements.treeCommandList.setSelectedNode(root);
        end
        
        function reloadProcedureList(guiObj)
            subroutines = guiObj.script.subList.keys;
            procedureList = transpose(cat(2,{'MAIN'},subroutines));
           
            set(guiObj.guiElements.pmProcedure,'string',procedureList);
        end
        
        % automatic mode load script button
        function btnLoadScript_callback(guiObj, h, e, varargin)
            % let the user select a file
            scriptFilename = uigetfile({'*.xml'},'Load script file');
            if ~isequal(scriptFilename,0) % the user didn't click cancel
                [guiObj.script.commandList, guiObj.script.subList] = xml2struct(scriptFilename,0);
            end
            
            % change command list window to reflect new script
            guiObj.reloadCommandTree('MAIN');
            
            % update procedure list with list of subroutines that this
            % script has
            guiObj.reloadProcedureList();
            
        end
        
        % outputs the first numChars characters of a string, or the entire
        % string, if the length of the string is <= numChars
        function outputString = strTrunc(guiObj, inputString, numChars)
            if length(inputString) > numChars
                outputString = strcat(inputString(1:numChars), '...');
            else
                outputString = inputString;
            end
        end
        
        % callback for when the figure (i.e. GUI) is resized
        function figureResize_callback(guiObj, h, e, varargin)
        	guiObj.updateDisplayImageSettingsPixelValueReset();
        end
        
        function updateDisplayImageSettingsPixelValueReset(guiObj, autoScale)
            if(~exist('autoScale', 'var'))
                autoScale = false;
            end
            if (~guiObj.testMode)
                guiObj.guiElements.pnlImageNavigation.updateDisplayImageSettingsPixelValueReset(autoScale);
            end
        end

        function pmProcedure_callback(guiObj, h, e, varargin)
            selectedItem = get(guiObj.guiElements.pmProcedure, 'Value');
            values = get(guiObj.guiElements.pmProcedure, 'String');
            selectedValue = values{selectedItem}; % text of selection in dropdown box
            guiObj.reloadCommandTree(selectedValue);
        end

        function pmObject_callback(guiObj, h, e, varargin)
            selectedItem = get(guiObj.guiElements.pmObject, 'Value');
            if selectedItem == 1 %Pump
                set(guiObj.guiElements.pnlCommandPropertiesPump,'visible','on');
                set(guiObj.guiElements.pnlCommandPropertiesImage,'visible','off');
                set(guiObj.guiElements.pnlCommandPropertiesTemp,'visible','off');
            elseif selectedItem == 2 %Image
                set(guiObj.guiElements.pnlCommandPropertiesPump,'visible','off');
                set(guiObj.guiElements.pnlCommandPropertiesImage,'visible','on');
                set(guiObj.guiElements.pnlCommandPropertiesTemp,'visible','off');
            elseif selectedItem == 3 %Temperature
                set(guiObj.guiElements.pnlCommandPropertiesPump,'visible','off');
                set(guiObj.guiElements.pnlCommandPropertiesImage,'visible','off');
                set(guiObj.guiElements.pnlCommandPropertiesTemp,'visible','on');
            end    
        end

        function btnDeleteCommand_callback(guiObj, h, e, varargin)
            contents = get(lbCommandList,'String');
            if length(contents)<1; return; end; %if already empty, do nothing

            Index=get(lbCommandList,'Value');
            contents(Index)=[]; %remove the item

            Value=Index-1;
            if Value<1; Value=1; end %take care of exception

            set(lbCommandList,'String',contents,'Value',Value);
        end

        function mnuManualMoreOptionsSaveImage_callback(guiObj, h, e, varargin)
            rootFilename = guiObj.defaultFileNameRoot;
            suggestedFilename = [rootFilename StringFun.getTimestampString() '.tif'];
            
            suggestedPathAndFilename = [guiObj.defaultImageSavePath suggestedFilename];
            
            [currFileName,currPath,currFilterIndex] = uiputfile('*.tif','Save Image',suggestedPathAndFilename);
            currPathAndFileName = [currPath currFileName];
            
            %set path memory
            if(currPath ~= 0)
                guiObj.defaultImageSavePath = currPath;
            end
            
            %save file
            if(currFileName ~= 0)
                try
                    guiObj.hardware.camera.saveImage(currPathAndFileName);
                    guiObj.hardware.saveImageMetadata([currPathAndFileName '.txt']);
                    fnRoot = StringFun.getFilenameRoot(currPathAndFileName);
                    if(~strcmp(fnRoot, ''))
                        guiObj.defaultFileNameRoot = StringFun.getFilenameRoot(currPathAndFileName);
                    end
                catch err
                    disp(err.identifier)
                    
                    switch err.identifier
                        case 'Photometrics_PVCam_CameraController:saveImage:noImage'
                            errordlg('No image has been acquired. File was not saved.', 'File Error', 'modal');
                        case 'Photometrics_PVCam_CameraController:saveImage:invalidFilename'
                            errordlg('Invalid Filename. File was not saved.', 'File Error', 'modal');
                        otherwise
                            rethrow(err);
                            %errordlg([err.identifier ' : ' err.message], 'File Error', 'modal');
                    end
                end
            end
        end
        
        function mnuManualMoreOptionsFocusMapWizard_callback(guiObj, h, e, varargin)
            selectedLaser = get(guiObj.guiElements.guiPanelImageObj.guiElements.pmManualImageLaser,'value');
            selectedFilter = get(guiObj.guiElements.guiPanelImageObj.guiElements.pmManualImageFilter,'value');
            guiFocusMapWizardObj = guiFocusMapWizard(guiObj.hardware, guiObj.testMode,true,true,selectedLaser,selectedFilter);
        end
        
        function mnuManualMoreOptionsEdgeFinderWizard_callback(guiObj, h, e, varargin)
            selectedLaser = get(guiObj.guiElements.guiPanelImageObj.guiElements.pmManualImageLaser,'value');
            selectedFilter = get(guiObj.guiElements.guiPanelImageObj.guiElements.pmManualImageFilter,'value');
            guiEdgeFinderWizardObj = guiEdgeFinderWizard(guiObj.hardware, guiObj.testMode,true,true,selectedLaser,selectedFilter);
        end
        
        function mnuManualMoreOptionsGoToTile_callback(guiObj, h, e, varargin)
            numTiles = guiObj.hardware.tileMap.getNumTiles();
            tilePrompt = sprintf('Enter tile number (1-%d): ', numTiles);
            tileNumber = input(tilePrompt);
            
            validatedTile = guiObj.hardware.tileMap.validateTile(tileNumber);
            focus = guiObj.guiElements.guiPanelStagesObj.ZuseFocusMap();
            guiObj.hardware.gotoTile(validatedTile, focus);
            if(guiObj.guiElements.guiPanelStagesObj.autoImage())
                % execute image capture button callback
                guiObj.guiElements.guiPanelImageObj.capture();
            end
        end
        
        function mnuManualMoreOptionsAddCurrentStagePositionToHistory_callback(guiObj, h, e, varargin)
            % add the current stage position to the history list
            guiObj.stageHistoryX = [ guiObj.stageHistoryX guiObj.hardware.stageAndFilterWheel.whereIsX(); ];
            guiObj.stageHistoryY = [ guiObj.stageHistoryY guiObj.hardware.stageAndFilterWheel.whereIsY(); ];
            guiObj.stageHistoryZ = [ guiObj.stageHistoryZ guiObj.hardware.stageAndFilterWheel.whereIsZ(); ];
            
            % replot focus map points and history
            if ishandle(guiObj.fStagePositionHistory)
                close(guiObj.fStagePositionHistory);
            end
            guiObj.fStagePositionHistory = figure;
            L=plot3(guiObj.hardware.focusMap.getXpoints(),guiObj.hardware.focusMap.getYpoints(),guiObj.hardware.focusMap.getZpoints(),'ro'); % Plot the focus map points
            set(L,'Markersize',2*get(L,'Markersize')) % Making the circle markers larger
            set(L,'Markerfacecolor','r') % Filling in the markers
            hold on
            L=plot3(guiObj.stageHistoryX,guiObj.stageHistoryY,guiObj.stageHistoryZ,'bo'); % Plot the stage history points
            set(L,'Markersize',2*get(L,'Markersize')) % Making the circle markers larger
            set(L,'Markerfacecolor','b') % Filling in the markers
            hold on
            minX = min(guiObj.hardware.focusMap.getXpoints());
            maxX = max(guiObj.hardware.focusMap.getXpoints());
            spacingX = (maxX - minX)/100;
            minY = min(guiObj.hardware.focusMap.getYpoints());
            maxY = max(guiObj.hardware.focusMap.getYpoints());
            spacingY = (maxY - minY)/100;
            [xx, yy]=meshgrid( minX:spacingX:maxX  , minY:spacingY:maxY ); % Generating a regular grid for plotting
            %JOHAN Added or modified 12/27/2013 for temperature
            tt=guiObj.hardware.peltier.getCurrentTemp();
            zz = guiObj.hardware.focusMap.getZ(xx, yy, tt);
            %END JOHAN
            surf(xx,yy,zz) % Plotting the surface
            xlabel('x');
            ylabel('y');
            
            title('Focus Map Points (red), Plane Fit and History Points (blue)');
        end
        
        function mnuManualMoreOptionsClearStagePositionHistory_callback(guiObj, h, e, varargin)
            guiObj.stageHistoryX = [];
            guiObj.stageHistoryY = [];
            guiObj.stageHistoryZ = [];
        end
        
    end % END PUBLIC METHODS
end % END GUI CLASS 