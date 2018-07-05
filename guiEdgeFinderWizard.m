% Fluorescence Imaging Machine GUI: Edge Finder Wizard
% Peter McMahon / pmcmahon@stanford.edu
% Curtis Layton
% March 2013

% The purpose of the Edge Finder Wizard is to let the user manually find and
% set the x-stage positions that correspond to the left edge of the imaged
% part of the flow cell (i.e. the right part, in MiSeq flow cells).

% A set of two points should be sufficient to find the angle at which the
% chip is mounted. By finding the edge at the two ends of the flow cell, we
% should be able to reliably go to any tile on the flow cell.

% This Edge Finder Wizard GUI, when called, takes in a list of (y)
% positions that the user should find edges for (the z positions come from
% the Focus Map).

% This code has only been tested with MATLAB R2010b, Version 7.11.0.584
% (32-bit Windows). Many of the GUI functions are MATLAB-version-dependent.



classdef guiEdgeFinderWizard < handle
    
    properties % PROPERTIES
        hardware; % reference to ImagingStationHardware
        guiElements; % elements of this wizard's GUI
        
        pollingLoop;
        
        testMode;
        
        % these properties determine which laser controls are shown in the wizard
        allowRedLaser;
        allowGreenLaser;
        
        % defines which laser and filter are selected in the "image" panel
        defaultImageLaserSelection;
        defaultImageFilterSelection;

        currentEdgePoint = 1; % which edge point are we currently setting?
        % these properties will be set by the caller
        totalEdgePoints = -1; % how many edge points are we collecting in total?
        
        % the Y points are supplied, and the X points are found by the user
        Xpoints = [];
        Ypoints = [];
    end % END PROPERTIES
    
    methods (Access = private) % PRIVATE METHODS
        
        function windowClose_callback(guiEdgeFinderWizardObj, h, e, varargin)
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
            delete(guiEdgeFinderWizardObj);
        end
        
    end % END PRIVATE METHODS
    
    
    methods % PUBLIC METHODS

        function guiEdgeFinderWizardObj = guiEdgeFinderWizard(hardware, testMode, allowRedLaser, allowGreenLaser, defaultImageLaserSelection, defaultImageFilterSelection) %constructor
            try
                % Startup code
                guiEdgeFinderWizardObj.hardware = hardware;
                guiEdgeFinderWizardObj.pollingLoop = PollingLoop();

                guiEdgeFinderWizardObj.testMode = testMode;

                guiEdgeFinderWizardObj.allowRedLaser = allowRedLaser;
                guiEdgeFinderWizardObj.allowGreenLaser = allowGreenLaser;

                guiEdgeFinderWizardObj.defaultImageLaserSelection = defaultImageLaserSelection;
                guiEdgeFinderWizardObj.defaultImageFilterSelection = defaultImageFilterSelection;

                guiEdgeFinderWizardObj.totalEdgePoints = guiEdgeFinderWizardObj.hardware.tileMap.getNumEdgePoints(); % how many edge points are we collecting in total?
                guiEdgeFinderWizardObj.Xpoints = guiEdgeFinderWizardObj.hardware.tileMap.getXedgepoints();
                guiEdgeFinderWizardObj.Ypoints = guiEdgeFinderWizardObj.hardware.tileMap.getYedgepoints();

                guiEdgeFinderWizardObj.setupGui();

                guiEdgeFinderWizardObj.goToEdgePoint(guiEdgeFinderWizardObj.currentEdgePoint);
            catch err
                if(~strcmp(err.identifier,'MATLAB:class:InvalidHandle') && ~strcmp(err.identifier, 'YMA:findjobj:IllegalContainer')) %this will be true if the window has been closed, cancelling the wizard
                    rethrow(err);
                end
            end
        end        
        
        function delete(guiEdgeFinderWizardObj)
            guiEdgeFinderWizardObj.pollingLoop.stopPollingLoop();
        end
        
        function moveToXYZ(guiEdgeFinderWizardObj, newPosX, newPosY, newPosZ)
            try
                guiEdgeFinderWizardObj.hardware.stageAndFilterWheel.moveToXYZ(newPosX, newPosY, newPosZ);
                guiEdgeFinderWizardObj.guiElements.guiPanelStagesObj.updateManualStagesXPosition();
            catch err
                if(~strcmp(err.identifier,'MATLAB:class:InvalidHandle')) %this will be true if the window has been closed, cancelling the wizard
                    rethrow(err);
                end
            end
        end
        
        function goToEdgePoint(guiEdgeFinderWizardObj, edgePointNumber)
            try
                newPosX = guiEdgeFinderWizardObj.Xpoints(edgePointNumber);
                newPosY = guiEdgeFinderWizardObj.Ypoints(edgePointNumber);
                %JOHAN Added or modified 12/27/2013 of temperature
                temperature = guiEdgeFinderWizardObj.hardware.peltier.getCurrentTemp();
                newPosZ = guiEdgeFinderWizardObj.hardware.focusMap.getZ(newPosX, newPosY, temperature);
                %END JOHAN
                 
                guiEdgeFinderWizardObj.guiElements.guiPanelStagesObj.disable();
                guiEdgeFinderWizardObj.moveToXYZ(newPosX, newPosY, newPosZ);
                guiEdgeFinderWizardObj.guiElements.guiPanelImageObj.btnManualImage_callback('image');
                guiEdgeFinderWizardObj.guiElements.guiPanelStagesObj.enable();
            catch err
                if(~strcmp(err.identifier,'MATLAB:class:InvalidHandle')) %this will be true if the window has been closed, cancelling the wizard
                    rethrow(err);
                end
            end
        end
            
        function setupGui(guiEdgeFinderWizardObj)
            try
                guiEdgeFinderWizardObj.guiElements.guiFigure = figure('name', 'Fluorescence Imager Edge Finder Wizard', 'numbertitle', 'off', 'menubar', 'none', 'units', 'normalized', 'position', [0.2 0.2 0.7 0.7], 'CloseRequestFcn', @guiEdgeFinderWizardObj.windowClose_callback);

                % divide window into top and bottom; bottom will be the status
                % bar; top will contain everything else
                [guiEdgeFinderWizardObj.guiElements.hBottom,guiEdgeFinderWizardObj.guiElements.hTop,guiEdgeFinderWizardObj.guiElements.hDivTopBottom] = uisplitpane(gcf,'dividercolor','k','dividerwidth',1,'orientation','ver');
                guiEdgeFinderWizardObj.guiElements.hDivTopBottom.DividerLocation = 0.9;
                % divide bottom into left and right
                [guiEdgeFinderWizardObj.guiElements.hLeft,guiEdgeFinderWizardObj.guiElements.hRight,guiEdgeFinderWizardObj.guiElements.hDiv] = uisplitpane(guiEdgeFinderWizardObj.guiElements.hBottom,'dividercolor','k','dividerwidth',3);
                guiEdgeFinderWizardObj.guiElements.hDiv.DividerLocation = 0.4;

                guiEdgeFinderWizardObj.guiElements.bgcolor = [0.9255    0.9137    0.8471];

                % X,Z Stage Controls
                guiEdgeFinderWizardObj.guiElements.guiPanelStagesObj = guiPanelStages(guiEdgeFinderWizardObj.hardware, guiEdgeFinderWizardObj.testMode, guiEdgeFinderWizardObj.guiElements.hLeft, [0.05 0.5 0.9 0.45], guiEdgeFinderWizardObj.guiElements.bgcolor, 0, 1, 0, 1, 0, 0, []);

                % Laser Control (Red)
                guiEdgeFinderWizardObj.guiElements.guiPanelRedLaserObj = guiPanelRedLaser(guiEdgeFinderWizardObj.hardware, guiEdgeFinderWizardObj.testMode, guiEdgeFinderWizardObj.guiElements.hLeft, [0.05 0.4 0.9 0.08], guiEdgeFinderWizardObj.guiElements.bgcolor, guiEdgeFinderWizardObj.pollingLoop, []);
                if (~guiEdgeFinderWizardObj.allowRedLaser)
                    set(guiEdgeFinderWizardObj.guiElements.guiPanelRedLaserObj.guiElements.pnlManualObjectLaserRed,'visible','off');
                end

                % Laser Control (Green)
                guiEdgeFinderWizardObj.guiElements.guiPanelGreenLaserObj = guiPanelGreenLaser(guiEdgeFinderWizardObj.hardware, guiEdgeFinderWizardObj.testMode, guiEdgeFinderWizardObj.guiElements.hLeft, [0.05 0.3 0.9 0.08], guiEdgeFinderWizardObj.guiElements.bgcolor, guiEdgeFinderWizardObj.pollingLoop, []);
                if (~guiEdgeFinderWizardObj.allowGreenLaser)
                    set(guiEdgeFinderWizardObj.guiElements.guiPanelGreenLaserObj.guiElements.pnlManualObjectLaserGreen,'visible','off');
                end

                %assign references to the respective laser panels
                guiEdgeFinderWizardObj.guiElements.guiPanelRedLaserObj.panelGreenLaser = guiEdgeFinderWizardObj.guiElements.guiPanelGreenLaserObj;
                guiEdgeFinderWizardObj.guiElements.guiPanelGreenLaserObj.panelRedLaser = guiEdgeFinderWizardObj.guiElements.guiPanelRedLaserObj;

                % Image Control
                guiEdgeFinderWizardObj.guiElements.guiPanelImageObj = guiPanelImage(guiEdgeFinderWizardObj.hardware, guiEdgeFinderWizardObj.testMode, guiEdgeFinderWizardObj.guiElements.hLeft, [0.05 0.05 0.9 0.24], guiEdgeFinderWizardObj.guiElements.bgcolor, @guiEdgeFinderWizardObj.updateDisplayImageSettingsPixelValueReset, guiEdgeFinderWizardObj.pollingLoop, []);
                guiEdgeFinderWizardObj.guiElements.guiPanelStagesObj.panelImage = guiEdgeFinderWizardObj.guiElements.guiPanelImageObj;

                % set default laser and filter in image panel
                set(guiEdgeFinderWizardObj.guiElements.guiPanelImageObj.guiElements.pmManualImageLaser,'value',guiEdgeFinderWizardObj.defaultImageLaserSelection);
                set(guiEdgeFinderWizardObj.guiElements.guiPanelImageObj.guiElements.pmManualImageFilter,'value',guiEdgeFinderWizardObj.defaultImageFilterSelection);

                % if only one laser is allowed, don't allow the user to mess
                % with the laser or filter setting
                if (~((guiEdgeFinderWizardObj.allowGreenLaser) && (guiEdgeFinderWizardObj.allowRedLaser)))
                    set(guiEdgeFinderWizardObj.guiElements.guiPanelImageObj.guiElements.pmManualImageLaser,'visible','off');
                    set(guiEdgeFinderWizardObj.guiElements.guiPanelImageObj.guiElements.pmManualImageFilter,'visible','off');
                end

                % Image Navigation Panel
                guiEdgeFinderWizardObj.guiElements.pnlImageNavigation = guiPanelDisplayImage(guiEdgeFinderWizardObj.hardware, guiEdgeFinderWizardObj.testMode, guiEdgeFinderWizardObj.guiElements.hRight, [0.0 0.0 1.0 1.0], guiEdgeFinderWizardObj.guiElements.bgcolor, [], true);
                set(guiEdgeFinderWizardObj.guiElements.guiFigure, 'ResizeFcn', @guiEdgeFinderWizardObj.figureResize_callback);

                % Edge Point Control
                guiEdgeFinderWizardObj.guiElements.pnlEdgePoint = uipanel(guiEdgeFinderWizardObj.guiElements.hTop, 'title', '', 'units', 'normalized', 'position', [0.0 0.0 1 1]);
                guiEdgeFinderWizardObj.guiElements.lblEdgePoint = uicontrol(guiEdgeFinderWizardObj.guiElements.pnlEdgePoint, 'style', 'text', 'string', 'Edge Point:', 'FontSize', 20, 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.05 0.05 0.3 0.9 ], 'backgroundcolor', guiEdgeFinderWizardObj.guiElements.bgcolor);
                guiEdgeFinderWizardObj.guiElements.lblEdgePointNumber = uicontrol(guiEdgeFinderWizardObj.guiElements.pnlEdgePoint, 'style', 'text', 'string', '1', 'FontSize', 20, 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.40 0.05 0.1 0.9 ], 'backgroundcolor', guiEdgeFinderWizardObj.guiElements.bgcolor);
                guiEdgeFinderWizardObj.guiElements.lblEdgePointOf = uicontrol(guiEdgeFinderWizardObj.guiElements.pnlEdgePoint, 'style', 'text', 'string', ['of ' num2str(guiEdgeFinderWizardObj.totalEdgePoints)], 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.52 0.3 0.1 0.4 ], 'backgroundcolor', guiEdgeFinderWizardObj.guiElements.bgcolor);
                guiEdgeFinderWizardObj.guiElements.btnEdgePointNext = uicontrol(guiEdgeFinderWizardObj.guiElements.pnlEdgePoint, 'String', 'Next Point', 'units', 'normalized', 'position', [ 0.65 0.1 0.15 0.8 ], 'callback', @guiEdgeFinderWizardObj.btnEdgePointNext_callback);
                guiEdgeFinderWizardObj.guiElements.btnSaveAndClose = uicontrol(guiEdgeFinderWizardObj.guiElements.pnlEdgePoint, 'String', 'Save and Close', 'Enable', 'off', 'units', 'normalized', 'position', [ 0.81 0.1 0.15 0.8 ], 'callback', @guiEdgeFinderWizardObj.btnSaveAndClose_callback);
            catch err
                if(~strcmp(err.identifier,'MATLAB:class:InvalidHandle') && ~strcmp(err.identifier,'YMA:findjobj:IllegalContainer')) %this will be true if the window has been closed, cancelling the wizard
                    rethrow(err);
                end
            end
        end
        
        % callback for when the figure (i.e. GUI) is resized
        function figureResize_callback(guiEdgeFinderWizardObj, h, e, varargin)
        	guiEdgeFinderWizardObj.updateDisplayImageSettingsPixelValueReset();
        end
        
        function updateDisplayImageSettingsPixelValueReset(guiEdgeFinderWizardObj, autoScale)
            if(~exist('autoScale', 'var'))
                autoScale = false;
            end
            if (~guiEdgeFinderWizardObj.testMode)
                guiEdgeFinderWizardObj.guiElements.pnlImageNavigation.updateDisplayImageSettingsPixelValueReset(autoScale);
            end
        end
        
        function btnEdgePointNext_callback(guiEdgeFinderWizardObj, h, e, varargin)
            try
                % save current edge point
                guiEdgeFinderWizardObj.Xpoints(guiEdgeFinderWizardObj.currentEdgePoint) = guiEdgeFinderWizardObj.hardware.stageAndFilterWheel.whereIsX();

                guiEdgeFinderWizardObj.currentEdgePoint = guiEdgeFinderWizardObj.currentEdgePoint + 1;

                % disable the "next" button and enable the "save" button when we get to the final point
                if (guiEdgeFinderWizardObj.currentEdgePoint == guiEdgeFinderWizardObj.totalEdgePoints)
                    set(guiEdgeFinderWizardObj.guiElements.btnEdgePointNext,'Enable','off');
                    set(guiEdgeFinderWizardObj.guiElements.btnSaveAndClose,'Enable','on');
                end

                % update display
                set(guiEdgeFinderWizardObj.guiElements.lblEdgePointNumber, 'string', num2str(guiEdgeFinderWizardObj.currentEdgePoint));

                % go to next (x,y,z) position
                guiEdgeFinderWizardObj.goToEdgePoint(guiEdgeFinderWizardObj.currentEdgePoint);
            catch err
                if(~strcmp(err.identifier,'MATLAB:class:InvalidHandle')) %this will be true if the window has been closed, cancelling the wizard
                    rethrow(err);
                end
            end
        end
        
        function btnSaveAndClose_callback(guiEdgeFinderWizardObj, h, e, varargin)
            try
                % save current edge point
                guiEdgeFinderWizardObj.Xpoints(guiEdgeFinderWizardObj.currentEdgePoint) = guiEdgeFinderWizardObj.hardware.stageAndFilterWheel.whereIsX();

                % save edge points to file and update edge line fit
                guiEdgeFinderWizardObj.hardware.tileMap.setEdgePoints(guiEdgeFinderWizardObj.Xpoints, guiEdgeFinderWizardObj.Ypoints);

                % display the new fit
                figure
                L=plot(guiEdgeFinderWizardObj.Xpoints,guiEdgeFinderWizardObj.Ypoints,'ro'); % Plot the original data points
                set(L,'Markersize',2*get(L,'Markersize')) % Making the circle markers larger
                set(L,'Markerfacecolor','r') % Filling in the markers
                hold on
                minY = min(guiEdgeFinderWizardObj.Ypoints);
                maxY = max(guiEdgeFinderWizardObj.Ypoints);
                spacingY = (maxY - minY)/100;
                yy = minY:spacingY:maxY;
                xx = guiEdgeFinderWizardObj.hardware.tileMap.getEdgePos(yy);
                plot(xx,yy) % Plot the line
                xlabel('x');
                ylabel('y');
                title('Edge Points and Line Fit');
            catch err
                if(~strcmp(err.identifier,'MATLAB:class:InvalidHandle')) %this will be true if the window has been closed, cancelling the wizard
                    rethrow(err);
                end
            end
            
            % close window
            close(guiEdgeFinderWizardObj.guiElements.guiFigure);
            %delete(guiEdgeFinderWizardObj);
        end

        function figureHandle = getFigureHandle(guiEdgeFinderWizardObj)
            figureHandle = guiEdgeFinderWizardObj.guiElements.guiFigure;
        end
        
    end % END PUBLIC METHODS
end % END GUI CLASS 