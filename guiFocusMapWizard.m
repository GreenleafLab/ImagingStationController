% Fluorescence Imaging Machine GUI: Focus Map Wizard
% Peter McMahon / pmcmahon@stanford.edu
% Curtis Layton
% February, March 2013

% The purpose of the Focus Map Wizard is to let the user manually find and
% set the z-stage positions that give in-focus images for a set of (x,y)
% stage positions.

% A set of 3 points could be used to define a focus plane. This would be
% appropriate if we model the flow cell as being perfectly flat, but 
% tilted. With more points, one could fit more complicated functions, 
% for example to take into account parabolic warping of the flow cell
% due to stress.

% This Focus Map Wizard GUI, when called, takes in a list of (x,y)
% positions that the user should find focus for.

% This code has only been tested with MATLAB R2010b, Version 7.11.0.584
% (32-bit Windows). Many of the GUI functions are MATLAB-version-dependent.



classdef guiFocusMapWizard < handle
    
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

        currentFocusPoint = 1; % which focus point are we currently setting?
        % these properties will be set by the caller
        totalFocusPoints = -1; % how many focus points are we collecting in total?
        % the wizard uses a set of (x,y,z) points: the (x,y)
        % points are the positions that we want to find focus for, and the
        % corresponding z points are the last set focus points
        Xpoints = [];
        Ypoints = [];
        Zpoints = [];     
    end % END PROPERTIES
    
    
    methods (Access = private) % PRIVATE METHODS
        
        function windowClose_callback(guiFocusMapWizardObj, h, e, varargin)
        	disp('CLOSE REQUEST');
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
            delete(guiFocusMapWizardObj);
        end
        
    end % END PRIVATE METHODS
    
    
    methods % PUBLIC METHODS

        function guiFocusMapWizardObj = guiFocusMapWizard(hardware, testMode, allowRedLaser, allowGreenLaser, defaultImageLaserSelection, defaultImageFilterSelection) %constructor
            % Startup code
            try
                guiFocusMapWizardObj.hardware = hardware;
                guiFocusMapWizardObj.pollingLoop = PollingLoop();

                guiFocusMapWizardObj.testMode = testMode;

                guiFocusMapWizardObj.allowRedLaser = allowRedLaser;
                guiFocusMapWizardObj.allowGreenLaser = allowGreenLaser;

                guiFocusMapWizardObj.defaultImageLaserSelection = defaultImageLaserSelection;
                guiFocusMapWizardObj.defaultImageFilterSelection = defaultImageFilterSelection;

                guiFocusMapWizardObj.totalFocusPoints = guiFocusMapWizardObj.hardware.focusMap.getNumPoints(); % how many focus points are we collecting in total?
                guiFocusMapWizardObj.Xpoints = guiFocusMapWizardObj.hardware.focusMap.getXpoints();
                guiFocusMapWizardObj.Ypoints = guiFocusMapWizardObj.hardware.focusMap.getYpoints();
                guiFocusMapWizardObj.Zpoints = guiFocusMapWizardObj.hardware.focusMap.getZpoints();

                guiFocusMapWizardObj.setupGui();

                guiFocusMapWizardObj.goToFocusPoint(guiFocusMapWizardObj.currentFocusPoint);
            catch err
                if(~strcmp(err.identifier,'MATLAB:class:InvalidHandle') && ~strcmp(err.identifier, 'YMA:findjobj:IllegalContainer')) %this will be true if the window has been closed, cancelling the wizard
                    rethrow(err);
                end
            end
        end
        
        function delete(guiFocusMapWizardObj)
            guiFocusMapWizardObj.pollingLoop.stopPollingLoop();
        end
        
        function moveToXYZ(guiFocusMapWizardObj, newPosX, newPosY, newPosZ)
            try
                guiFocusMapWizardObj.hardware.stageAndFilterWheel.moveToXYZ(newPosX, newPosY, newPosZ);
                guiFocusMapWizardObj.guiElements.guiPanelStagesObj.updateManualStagesAll();
            catch err
                if(~strcmp(err.identifier,'MATLAB:class:InvalidHandle')) %this will be true if the window has been closed, cancelling the wizard
                    rethrow(err);
                end
            end
        end
        
        function goToFocusPoint(guiFocusMapWizardObj, focusPointNumber)
            try
                lastwarn('')
                newPosX = guiFocusMapWizardObj.Xpoints(focusPointNumber);
                newPosY = guiFocusMapWizardObj.Ypoints(focusPointNumber);
                newPosZ = guiFocusMapWizardObj.Zpoints(focusPointNumber);
                guiFocusMapWizardObj.guiElements.guiPanelStagesObj.disable();
                guiFocusMapWizardObj.moveToXYZ(newPosX, newPosY, newPosZ);
                guiFocusMapWizardObj.guiElements.guiPanelImageObj.btnManualImage_callback('image');
                guiFocusMapWizardObj.guiElements.guiPanelStagesObj.enable();
            catch err
                if(~strcmp(err.identifier,'MATLAB:class:InvalidHandle')) %this will be true if the window has been closed, cancelling the wizard
                    rethrow(err);
                end
            end
        end
            
        function setupGui(guiFocusMapWizardObj)
            try
                guiFocusMapWizardObj.guiElements.guiFigure = figure('name', 'Fluorescence Imager Focus Map Wizard', 'numbertitle', 'off', 'menubar', 'none', 'units', 'normalized', 'position', [0.2 0.2 0.7 0.7], 'CloseRequestFcn', @guiFocusMapWizardObj.windowClose_callback);

                % divide window into top and bottom; bottom will be the status
                % bar; top will contain everything else
                [guiFocusMapWizardObj.guiElements.hBottom,guiFocusMapWizardObj.guiElements.hTop,guiFocusMapWizardObj.guiElements.hDivTopBottom] = uisplitpane(gcf,'dividercolor','k','dividerwidth',1,'orientation','ver');
                guiFocusMapWizardObj.guiElements.hDivTopBottom.DividerLocation = 0.9;
                % divide bottom into left and right
                [guiFocusMapWizardObj.guiElements.hLeft,guiFocusMapWizardObj.guiElements.hRight,guiFocusMapWizardObj.guiElements.hDiv] = uisplitpane(guiFocusMapWizardObj.guiElements.hBottom,'dividercolor','k','dividerwidth',3);
                guiFocusMapWizardObj.guiElements.hDiv.DividerLocation = 0.4;

                guiFocusMapWizardObj.guiElements.bgcolor = [0.9255    0.9137    0.8471];

                % Z Stage Controls
                guiFocusMapWizardObj.guiElements.guiPanelStagesObj = guiPanelStages(guiFocusMapWizardObj.hardware, guiFocusMapWizardObj.testMode, guiFocusMapWizardObj.guiElements.hLeft, [0.05 0.5 0.9 0.45], guiFocusMapWizardObj.guiElements.bgcolor, 1, 1, 0, 1, 1, 0, []);

                % Laser Control (Red)
                guiFocusMapWizardObj.guiElements.guiPanelRedLaserObj = guiPanelRedLaser(guiFocusMapWizardObj.hardware, guiFocusMapWizardObj.testMode, guiFocusMapWizardObj.guiElements.hLeft, [0.05 0.4 0.9 0.08], guiFocusMapWizardObj.guiElements.bgcolor, guiFocusMapWizardObj.pollingLoop, []);
                if (~guiFocusMapWizardObj.allowRedLaser)
                    set(guiFocusMapWizardObj.guiElements.guiPanelRedLaserObj.guiElements.pnlManualObjectLaserRed,'visible','off');
                end

                % Laser Control (Green)
                guiFocusMapWizardObj.guiElements.guiPanelGreenLaserObj = guiPanelGreenLaser(guiFocusMapWizardObj.hardware, guiFocusMapWizardObj.testMode, guiFocusMapWizardObj.guiElements.hLeft, [0.05 0.3 0.9 0.08], guiFocusMapWizardObj.guiElements.bgcolor, guiFocusMapWizardObj.pollingLoop, []);
                if (~guiFocusMapWizardObj.allowGreenLaser)
                    set(guiFocusMapWizardObj.guiElements.guiPanelGreenLaserObj.guiElements.pnlManualObjectLaserGreen,'visible','off');
                end

                %assign references to the respective laser panels
                guiFocusMapWizardObj.guiElements.guiPanelRedLaserObj.panelGreenLaser = guiFocusMapWizardObj.guiElements.guiPanelGreenLaserObj;
                guiFocusMapWizardObj.guiElements.guiPanelGreenLaserObj.panelRedLaser = guiFocusMapWizardObj.guiElements.guiPanelRedLaserObj;

                % Image Control
                guiFocusMapWizardObj.guiElements.guiPanelImageObj = guiPanelImage(guiFocusMapWizardObj.hardware, guiFocusMapWizardObj.testMode, guiFocusMapWizardObj.guiElements.hLeft, [0.05 0.05 0.9 0.24], guiFocusMapWizardObj.guiElements.bgcolor, @guiFocusMapWizardObj.updateDisplayImageSettingsPixelValueReset, guiFocusMapWizardObj.pollingLoop, []);
                guiFocusMapWizardObj.guiElements.guiPanelStagesObj.panelImage = guiFocusMapWizardObj.guiElements.guiPanelImageObj;

                % set default laser and filter in image panel
                set(guiFocusMapWizardObj.guiElements.guiPanelImageObj.guiElements.pmManualImageLaser,'value',guiFocusMapWizardObj.defaultImageLaserSelection);
                set(guiFocusMapWizardObj.guiElements.guiPanelImageObj.guiElements.pmManualImageFilter,'value',guiFocusMapWizardObj.defaultImageFilterSelection);

                % if only one laser is allowed, don't allow the user to mess
                % with the laser or filter setting
                if (~guiFocusMapWizardObj.allowGreenLaser || ~guiFocusMapWizardObj.allowRedLaser)
                    set(guiFocusMapWizardObj.guiElements.guiPanelImageObj.guiElements.pmManualImageLaser,'visible','off');
                    set(guiFocusMapWizardObj.guiElements.guiPanelImageObj.guiElements.pmManualImageFilter,'visible','off');
                end

                % Image Navigation Panel
                guiFocusMapWizardObj.guiElements.pnlImageNavigation = guiPanelDisplayImage(guiFocusMapWizardObj.hardware, guiFocusMapWizardObj.testMode, guiFocusMapWizardObj.guiElements.hRight, [0.0 0.0 1.0 1.0], guiFocusMapWizardObj.guiElements.bgcolor, []);
                set(guiFocusMapWizardObj.guiElements.guiFigure, 'ResizeFcn', @guiFocusMapWizardObj.figureResize_callback);

                % Focus Point Control
                guiFocusMapWizardObj.guiElements.pnlFocusPoint = uipanel(guiFocusMapWizardObj.guiElements.hTop, 'title', '', 'units', 'normalized', 'position', [0.0 0.0 1 1]);
                guiFocusMapWizardObj.guiElements.lblFocusPoint = uicontrol(guiFocusMapWizardObj.guiElements.pnlFocusPoint, 'style', 'text', 'string', 'Focus Point:', 'FontSize', 20, 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.05 0.05 0.3 0.9 ], 'backgroundcolor', guiFocusMapWizardObj.guiElements.bgcolor);
                guiFocusMapWizardObj.guiElements.lblFocusPointNumber = uicontrol(guiFocusMapWizardObj.guiElements.pnlFocusPoint, 'style', 'text', 'string', '1', 'FontSize', 20, 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.40 0.05 0.1 0.9 ], 'backgroundcolor', guiFocusMapWizardObj.guiElements.bgcolor);
                guiFocusMapWizardObj.guiElements.lblFocusPointOf = uicontrol(guiFocusMapWizardObj.guiElements.pnlFocusPoint, 'style', 'text', 'string', ['of ' num2str(guiFocusMapWizardObj.totalFocusPoints)], 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.52 0.3 0.1 0.4 ], 'backgroundcolor', guiFocusMapWizardObj.guiElements.bgcolor);
                guiFocusMapWizardObj.guiElements.btnFocusPointNext = uicontrol(guiFocusMapWizardObj.guiElements.pnlFocusPoint, 'String', 'Next Point', 'units', 'normalized', 'position', [ 0.65 0.1 0.15 0.8 ], 'callback', @guiFocusMapWizardObj.btnFocusPointNext_callback);
                guiFocusMapWizardObj.guiElements.btnSaveAndClose = uicontrol(guiFocusMapWizardObj.guiElements.pnlFocusPoint, 'String', 'Save and Close', 'Enable', 'off', 'units', 'normalized', 'position', [ 0.81 0.1 0.15 0.8 ], 'callback', @guiFocusMapWizardObj.btnSaveAndClose_callback);
            catch err
                if(~strcmp(err.identifier,'MATLAB:class:InvalidHandle') && ~strcmp(err.identifier,'YMA:findjobj:IllegalContainer')) %this will be true if the window has been closed, cancelling the wizard
                    rethrow(err);
                end
            end    
        end
        
        % callback for when the figure (i.e. GUI) is resized
        function figureResize_callback(guiFocusMapWizardObj, h, e, varargin)
        	guiFocusMapWizardObj.updateDisplayImageSettingsPixelValueReset();
        end
        
        function updateDisplayImageSettingsPixelValueReset(guiFocusMapWizardObj, autoScale)
            if(~exist('autoScale', 'var'))
                autoScale = false;
            end
            if (~guiFocusMapWizardObj.testMode)
                guiFocusMapWizardObj.guiElements.pnlImageNavigation.updateDisplayImageSettingsPixelValueReset(autoScale);
            end
        end
        
        function btnFocusPointNext_callback(guiFocusMapWizardObj, h, e, varargin)
            try
                % save current focus point
                guiFocusMapWizardObj.Zpoints(guiFocusMapWizardObj.currentFocusPoint) = guiFocusMapWizardObj.hardware.stageAndFilterWheel.whereIsZ();

                guiFocusMapWizardObj.currentFocusPoint = guiFocusMapWizardObj.currentFocusPoint + 1;

                % disable the "next" button and enable the "save" button when we get to the final point
                if (guiFocusMapWizardObj.currentFocusPoint == guiFocusMapWizardObj.totalFocusPoints)
                    set(guiFocusMapWizardObj.guiElements.btnFocusPointNext,'Enable','off');
                    set(guiFocusMapWizardObj.guiElements.btnSaveAndClose,'Enable','on');
                end

                % update display
                set(guiFocusMapWizardObj.guiElements.lblFocusPointNumber, 'string', num2str(guiFocusMapWizardObj.currentFocusPoint));

                % go to next (x,y,z) position
                guiFocusMapWizardObj.goToFocusPoint(guiFocusMapWizardObj.currentFocusPoint);
            catch err
                if(~strcmp(err.identifier,'MATLAB:class:InvalidHandle')) %this will be true if the window has been closed, cancelling the wizard
                    rethrow(err);
                end
            end
        end
        
        function btnSaveAndClose_callback(guiFocusMapWizardObj, h, e, varargin)
            try
                % save current focus point
                guiFocusMapWizardObj.Zpoints(guiFocusMapWizardObj.currentFocusPoint) = guiFocusMapWizardObj.hardware.stageAndFilterWheel.whereIsZ();
                temperature=guiFocusMapWizardObj.hardware.peltier.getCurrentTemp();
                
                %JOHAN
                CheckParam.isNumeric(temperature, 'guiFocusMapWizard:btnSaveAndClose_callback:Temperature', 'Temperature is not numeric');
                if ~((temperature > 15) && (temperature < 75))
                    %error('guiFocusMapWizard:btnSaveAndClose_callback:badTemperature', 'in a focusmap the temperature must be between 15 and 75 degrees');
                    
                    guiFocusMapWizardObj.hardware.focusMap.setPoints(guiFocusMapWizardObj.Xpoints, guiFocusMapWizardObj.Ypoints, guiFocusMapWizardObj.Zpoints);
                else
                    guiFocusMapWizardObj.hardware.focusMap.setPoints(guiFocusMapWizardObj.Xpoints, guiFocusMapWizardObj.Ypoints, guiFocusMapWizardObj.Zpoints, temperature);
                end
                
                % save focus points to file and update focus map
                %guiFocusMapWizardObj.hardware.focusMap.setPoints(guiFocusMapWizardObj.Xpoints, guiFocusMapWizardObj.Ypoints, guiFocusMapWizardObj.Zpoints);

                % display the new fit
                figure
                L=plot3(guiFocusMapWizardObj.Xpoints,guiFocusMapWizardObj.Ypoints,guiFocusMapWizardObj.Zpoints,'ro'); % Plot the original data points
                set(L,'Markersize',2*get(L,'Markersize')) % Making the circle markers larger
                set(L,'Markerfacecolor','r') % Filling in the markers
                hold on
                minX = min(guiFocusMapWizardObj.Xpoints);
                maxX = max(guiFocusMapWizardObj.Xpoints);
                spacingX = (maxX - minX)/100;
                minY = min(guiFocusMapWizardObj.Ypoints);
                maxY = max(guiFocusMapWizardObj.Ypoints);
                spacingY = (maxY - minY)/100;
                [xx, yy]=meshgrid( minX:spacingX:maxX  , minY:spacingY:maxY ); % Generating a regular grid for plotting
                 %JOHAN Added or modified 12/27/2013 for temperature
                zz = guiFocusMapWizardObj.hardware.focusMap.getZ(xx, yy, temperature);
                %END JOHAN
                surf(xx,yy,zz) % Plotting the surface
                xlabel('x');
                ylabel('y');

                title('Focus Map Points and Plane Fit');
            catch err
                if(~strcmp(err.identifier,'MATLAB:class:InvalidHandle')) %this will be true if the window has been closed, cancelling the wizard
                    rethrow(err);
                end
            end
            
            % close window
            close(guiFocusMapWizardObj.guiElements.guiFigure);
            %delete(guiFocusMapWizardObj);
        end

        function figureHandle = getFigureHandle(guiFocusMapWizardObj)
            figureHandle = guiFocusMapWizardObj.guiElements.guiFigure;
        end
        
    end % END PUBLIC METHODS
end % END GUI CLASS 