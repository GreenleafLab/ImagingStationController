% Fluorescence Imaging Machine GUI
% Curtis Layton
% October, November 2012
% March 2013

% This code has only been tested with MATLAB R2010b, Version 7.11.0.584
% (32-bit Windows). Many of the GUI functions are MATLAB-version-dependent.


classdef guiPanelDisplayImage < handle
    
    properties % PROPERTIES
        hardware; %reference to the hardware object
        guiElements;
        parent; % control that houses this panel
        position; % position of this panel within its parent
        
        guiPanelStatusbarObj; % status bar object, for writing status updates to
        
        testMode; % if testMode = 1, then code won't try interact with the hardware (used for testing GUI code)
        
        imageDisplayProperties;

        %paramaters to be read in from hardware; initialize to default values
        
        %image parameters (12-bit image)
        minPixelValue = 0;
        maxPixelValue = 4095;
        imageWidth = 2048;
        imageHeight = 2048;
        
        crosshairs; %boolean - display the image with crosshairs?
    end % END PROPERTIES
    
    properties (Constant) % CONSTANT PROPERTIES
        zoomFactor = 1.5;
        minZoomWidth = 20; %in pixels
        minZoomHeight = 20; %in pixels
        
        smallSliderStep = 1;
        largeSliderStep = 50;
        
        crosshairWidth = 0.04; % percent total image width
        lineWidth = 0.003; % percent total image width
    end % CONSTANT PROPERTIES
    
    
    methods (Access = private) % PRIVATE METHODS
        
        function imageMouseEnter_callback(guiPanelDisplayImageObj, h, e, varargin)
            setptr(gcf,'glass'); %TODO FIXME - doesn't work
            %disp('MOUSE IN');
        end
        
        function imageMouseExit_callback(guiPanelDisplayImageObj, h, e, varargin)
            setptr(gcf,'arrow'); %TODO FIXME - doesn't work
            %disp('MOUSE OUT');
        end
        
        function btnDisplayImageSettingsPixelValueReset_callback(guiPanelDisplayImageObj, h, e, varargin)
            if (~guiPanelDisplayImageObj.testMode)
                guiPanelDisplayImageObj.updateDisplayImageSettingsPixelValueReset(true);
            end
        end
        
        function imageClick_callback(guiPanelDisplayImageObj, h, e, varargin)
            hParentAxes = ancestor(h,'axes');
            pos = get(hParentAxes, 'CurrentPoint');
            selectionType = get(gcf, 'SelectionType');
            if(strcmp(selectionType,'normal') || strcmp(selectionType,'open')) %left click or double click
                guiPanelDisplayImageObj.zoom(pos);
            else %right click (also shift-click, etc)
                guiPanelDisplayImageObj.zoomOutAll();
            end
        end
        
        function newImage = addCrosshairs(guiPanelDisplayImageObj, originalImage)
            newImage = originalImage;
            
            [imgWidth, imgHeight] = size(originalImage);
            
            line1 = [floor((0.5-guiPanelDisplayImageObj.crosshairWidth)*imgWidth) floor((0.5-guiPanelDisplayImageObj.lineWidth)*imgHeight) ceil((0.5+guiPanelDisplayImageObj.crosshairWidth)*imgWidth) ceil((0.5+guiPanelDisplayImageObj.lineWidth)*imgHeight)];
            
            for x = line1(1):line1(3)
                for y = line1(2):line1(4)
                    %overwrite pixel with white
                    newImage(x,y) = guiPanelDisplayImageObj.maxPixelValue;
                end
            end
            
            line2 = [floor((0.5-guiPanelDisplayImageObj.lineWidth)*imgWidth) floor((0.5-guiPanelDisplayImageObj.crosshairWidth)*imgHeight) ceil((0.5+guiPanelDisplayImageObj.lineWidth)*imgWidth) ceil((0.5+guiPanelDisplayImageObj.crosshairWidth)*imgHeight)];

            for x = line2(1):line2(3)
                for y = line2(2):line2(4)
                    %overwrite pixel with white
                    newImage(x,y) = guiPanelDisplayImageObj.maxPixelValue;
                end
            end
        end
        
        function updateDisplayImageColormap(guiPanelDisplayImageObj)
            minSliderValue = get(guiPanelDisplayImageObj.guiElements.sldDisplayImageSettingsMinPixelValue, 'Value');
            maxSliderValue = get(guiPanelDisplayImageObj.guiElements.sldDisplayImageSettingsMaxPixelValue, 'Value');
            zX = guiPanelDisplayImageObj.imageDisplayProperties.zoom.X;
            zY = guiPanelDisplayImageObj.imageDisplayProperties.zoom.Y;
            %flippedImage = flipdim(flipdim(guiPanelDisplayImageObj.hardware.camera.img, 2), 1);
            if(guiPanelDisplayImageObj.crosshairs)
                newImage = guiPanelDisplayImageObj.addCrosshairs(guiPanelDisplayImageObj.hardware.camera.img);
                guiPanelDisplayImageObj.guiElements.hDisplayImage = imshow(newImage(zX(1):zX(2), zY(1):zY(2)), [minSliderValue maxSliderValue], 'parent', guiPanelDisplayImageObj.guiElements.hDisplayImageAxes);
            else
                guiPanelDisplayImageObj.guiElements.hDisplayImage = imshow(guiPanelDisplayImageObj.hardware.camera.img(zX(1):zX(2), zY(1):zY(2)), [minSliderValue maxSliderValue], 'parent', guiPanelDisplayImageObj.guiElements.hDisplayImageAxes);
            end
            set(guiPanelDisplayImageObj.guiElements.hDisplayImage, 'ButtonDownFcn', @guiPanelDisplayImageObj.imageClick_callback);
        end
        
        function sldDisplayImageSettingsPixelValue_callback(guiPanelDisplayImageObj, whichMoved)
            minSliderValue = get(guiPanelDisplayImageObj.guiElements.sldDisplayImageSettingsMinPixelValue, 'Value');
            maxSliderValue = get(guiPanelDisplayImageObj.guiElements.sldDisplayImageSettingsMaxPixelValue, 'Value');  

            switch whichMoved %ensure min is never moved above max, and vice-versa
                case 'min'
                    if(minSliderValue > maxSliderValue)
                        set(guiPanelDisplayImageObj.guiElements.sldDisplayImageSettingsMinPixelValue, 'Value', maxSliderValue)
                    end
                case 'max'
                    if(maxSliderValue < minSliderValue)
                        set(guiPanelDisplayImageObj.guiElements.sldDisplayImageSettingsMaxPixelValue, 'Value', minSliderValue)
                    end                    
                otherwise
                    error('gui:sldDisplayImageSettingsPixelValue_callback:badInput','Invalid call to image pixel value slider callback.');
            end
            
            if (~guiPanelDisplayImageObj.testMode)
                guiPanelDisplayImageObj.updateDisplayImageColormap();
            end
        end        

        function zoom(guiPanelDisplayImageObj, requestPos, direction)
            if(~exist('direction', 'var'))
                direction = 'in';
            end
                        
            hwImageWidth = guiPanelDisplayImageObj.hardware.camera.width; %image width in pixels
            hwImageHeight = guiPanelDisplayImageObj.hardware.camera.height; %image height in pixels  
            
            currImageWidth = abs(guiPanelDisplayImageObj.imageDisplayProperties.zoom.X(2) - guiPanelDisplayImageObj.imageDisplayProperties.zoom.X(1));
            currImageHeight = abs(guiPanelDisplayImageObj.imageDisplayProperties.zoom.Y(2) - guiPanelDisplayImageObj.imageDisplayProperties.zoom.Y(1));
            
            rpX = guiPanelDisplayImageObj.imageDisplayProperties.zoom.X(1) + requestPos(1,2);
            rpY = guiPanelDisplayImageObj.imageDisplayProperties.zoom.Y(1) + requestPos(1,1);
            
            switch direction
                case 'in'
                    newImageWidth = round(currImageWidth / guiPanelDisplayImageObj.zoomFactor); 
                    newImageHeight = round(currImageHeight / guiPanelDisplayImageObj.zoomFactor);
                case 'out'
                    newImageWidth = round(currImageWidth * guiPanelDisplayImageObj.zoomFactor); 
                    newImageHeight = round(currImageHeight * guiPanelDisplayImageObj.zoomFactor);                                       
                otherwise
                    error('gui:zoom:invalidDirection','direction must be "in" or "out" only');
            end

            %enforce width/height limits
            if(newImageWidth < guiPanelDisplayImageObj.minZoomWidth)
                newImageWidth = guiPanelDisplayImageObj.minZoomWidth;
            elseif(newImageWidth > guiPanelDisplayImageObj.hardware.camera.width)
                newImageWidth = guiPanelDisplayImageObj.hardware.camera.width;
            end

            if(newImageHeight < guiPanelDisplayImageObj.minZoomHeight)
                newImageHeight = guiPanelDisplayImageObj.minZoomHeight;
            elseif(newImageHeight > guiPanelDisplayImageObj.hardware.camera.height)
                newImageHeight = guiPanelDisplayImageObj.hardware.camera.height;
            end           
            
            newPosX(1) = round(rpX - (newImageWidth/2));
            newPosX(2) = round(rpX + (newImageWidth/2));
            newPosY(1) = round(rpY - (newImageHeight/2));
            newPosY(2) = round(rpY + (newImageHeight/2));
                       
            if(newPosX(1) < 1)
                offset = ceil(abs(1 - newPosX(1)));
                newPosX(1) = round(newPosX(1) + offset);
                newPosX(2) = round(newPosX(2) + offset);
            elseif(newPosX(2) > hwImageWidth)
                offset = ceil(abs(newPosX(2) - hwImageWidth));
                newPosX(1) = round(newPosX(1) - offset);
                newPosX(2) = round(newPosX(2) - offset);                    
            end

            if(newPosY(1) < 1)
                offset = ceil(abs(1 - newPosY(1)));
                newPosY(1) = round(newPosY(1) + offset);
                newPosY(2) = round(newPosY(2) + offset);
            elseif(newPosY(2) > hwImageHeight)
                offset = ceil(abs(newPosY(2) - hwImageHeight));
                newPosY(1) = round(newPosY(1) - offset);
                newPosY(2) = round(newPosY(2) - offset);                    
            end             
            
            guiPanelDisplayImageObj.imageDisplayProperties.zoom.X = newPosX;
            guiPanelDisplayImageObj.imageDisplayProperties.zoom.Y = newPosY;
            
            guiPanelDisplayImageObj.updateDisplayImageSettingsPixelValueReset();
        end
        
        function zoomOutAll(guiPanelDisplayImageObj)
            newImageWidth = guiPanelDisplayImageObj.hardware.camera.width; %image width in pixels
            newImageHeight = guiPanelDisplayImageObj.hardware.camera.height; %image height in pixels 
            guiPanelDisplayImageObj.imageDisplayProperties.zoom.X = [1 newImageWidth];
            guiPanelDisplayImageObj.imageDisplayProperties.zoom.Y = [1 newImageHeight];
            
            guiPanelDisplayImageObj.updateDisplayImageSettingsPixelValueReset();
        end
        
    end % END PRIVATE METHODS
    
    
    methods % PUBLIC METHODS

        % hardware: reference to ImagingStationHardware instance
        % testMode: GUI testing mode on/off
        % parent: GUI object that will be the container for this panel
        % position: position to place panel within parent
        % bgcolor: background color of GUI elements
        % pollingLoop: reference to PollingLoop instance in owner GUI, which makes callbacks when particular operations finish
        % guiPanelStatusbarObj: reference to a status bar panel on the GUI to write status updates to
        function guiPanelDisplayImageObj = guiPanelDisplayImage(hardware, testMode, parent, position, bgcolor, guiPanelStatusbarObj, crosshairs) %constructor
            if(~exist('crosshairs', 'var'))
                crosshairs = false;
            else
                CheckParam.isBoolean(crosshairs, 'guiPanelDisplayImage:guiPanelDisplayImage:badParam');
            end
            
            % Startup code
            guiPanelDisplayImageObj.testMode = testMode;
            guiPanelDisplayImageObj.parent = parent;
            guiPanelDisplayImageObj.position = position;
            guiPanelDisplayImageObj.guiElements.bgcolor = bgcolor;
            guiPanelDisplayImageObj.crosshairs = crosshairs;
            
            guiPanelDisplayImageObj.guiPanelStatusbarObj = guiPanelStatusbarObj;
            if (~guiPanelDisplayImageObj.testMode)
                guiPanelDisplayImageObj.hardware = hardware;
                
                %read in gui parameters from hardware
                
                %camera
                guiPanelDisplayImageObj.minPixelValue = 0;
                guiPanelDisplayImageObj.maxPixelValue = (2^guiPanelDisplayImageObj.hardware.camera.bitDepth)-1;
                guiPanelDisplayImageObj.imageWidth = guiPanelDisplayImageObj.hardware.camera.width;
                guiPanelDisplayImageObj.imageHeight = guiPanelDisplayImageObj.hardware.camera.height;
            end
      
            guiPanelDisplayImageObj.imageDisplayProperties.currPixelMax = guiPanelDisplayImageObj.maxPixelValue;
            guiPanelDisplayImageObj.imageDisplayProperties.currPixelMin = guiPanelDisplayImageObj.minPixelValue;
            guiPanelDisplayImageObj.imageDisplayProperties.zoom.X = [1 guiPanelDisplayImageObj.imageWidth];
            guiPanelDisplayImageObj.imageDisplayProperties.zoom.Y = [1 guiPanelDisplayImageObj.imageHeight];
            
            guiPanelDisplayImageObj.setupGui();
        end
            
        function setupGui(guiPanelDisplayImageObj)
            
            guiPanelDisplayImageObj.guiElements.pnlImageNavigation = uipanel(guiPanelDisplayImageObj.parent, 'title', '', 'units', 'normalized', 'position', guiPanelDisplayImageObj.position);

            
            % Display Image panel
            guiPanelDisplayImageObj.guiElements.pnlDisplayImage = uipanel(guiPanelDisplayImageObj.guiElements.pnlImageNavigation, 'title', '', 'units', 'normalized', 'position', [0.0 0.0 0.9 1.0]);
            
            guiPanelDisplayImageObj.guiElements.hDisplayImageAxes = axes('parent', guiPanelDisplayImageObj.guiElements.pnlDisplayImage);
                set(guiPanelDisplayImageObj.guiElements.hDisplayImageAxes, 'XDir', 'reverse');
                set(guiPanelDisplayImageObj.guiElements.hDisplayImageAxes, 'YDir', 'reverse');
                set(guiPanelDisplayImageObj.guiElements.hDisplayImageAxes, 'position', [0.1 0.1 0.8 0.8]);
            
            guiPanelDisplayImageObj.guiElements.hDisplayImage = image('parent', guiPanelDisplayImageObj.guiElements.hDisplayImageAxes, 'ButtonDownFcn', @guiPanelDisplayImageObj.imageClick_callback);

            pointerBehavior.enterFcn = @guiPanelDisplayImageObj.imageMouseEnter_callback;
            pointerBehavior.exitFcn = @guiPanelDisplayImageObj.imageMouseExit_callback;
            pointerBehavior.traverseFcn = [];
            iptSetPointerBehavior(guiPanelDisplayImageObj.guiElements.hDisplayImageAxes, pointerBehavior);

            % Display Image Settings panel    
            guiPanelDisplayImageObj.guiElements.pnlDisplayImageSettings = uipanel(guiPanelDisplayImageObj.guiElements.pnlImageNavigation, 'title', '', 'units', 'normalized', 'position', [0.9 0.0 0.1 1.0]);

            guiPanelDisplayImageObj.guiElements.lblDisplayImageSettingsMinPixelValue = uicontrol(guiPanelDisplayImageObj.guiElements.pnlDisplayImageSettings, 'style', 'text', 'string', 'Min Pixel:', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0 0.95 0.4 0.05 ], 'backgroundcolor', guiPanelDisplayImageObj.guiElements.bgcolor);
            guiPanelDisplayImageObj.guiElements.sldDisplayImageSettingsMinPixelValue = uicontrol(guiPanelDisplayImageObj.guiElements.pnlDisplayImageSettings, 'style', 'slider', 'Min', guiPanelDisplayImageObj.minPixelValue, 'Max', guiPanelDisplayImageObj.maxPixelValue, 'Value', guiPanelDisplayImageObj.minPixelValue, 'SliderStep', [guiPanelDisplayImageObj.smallSliderStep/guiPanelDisplayImageObj.maxPixelValue guiPanelDisplayImageObj.largeSliderStep/guiPanelDisplayImageObj.maxPixelValue], 'units', 'normalized', 'position', [ 0, 0, 0.4, 0.95 ], 'callback', @(whichMoved, varargin)guiPanelDisplayImageObj.sldDisplayImageSettingsPixelValue_callback('min'));
            guiPanelDisplayImageObj.guiElements.lblDisplayImageSettingsMaxPixelValue = uicontrol(guiPanelDisplayImageObj.guiElements.pnlDisplayImageSettings, 'style', 'text', 'string', 'Max Pixel:', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', [ 0.4 0.95 0.4 0.05 ], 'backgroundcolor', guiPanelDisplayImageObj.guiElements.bgcolor);
            guiPanelDisplayImageObj.guiElements.sldDisplayImageSettingsMaxPixelValue = uicontrol(guiPanelDisplayImageObj.guiElements.pnlDisplayImageSettings, 'style', 'slider', 'Min', guiPanelDisplayImageObj.minPixelValue, 'Max', guiPanelDisplayImageObj.maxPixelValue, 'Value', guiPanelDisplayImageObj.maxPixelValue, 'SliderStep', [guiPanelDisplayImageObj.smallSliderStep/guiPanelDisplayImageObj.maxPixelValue guiPanelDisplayImageObj.largeSliderStep/guiPanelDisplayImageObj.maxPixelValue], 'units', 'normalized', 'position', [ 0.4, 0, 0.4, 0.95 ], 'callback', @(whichMoved, varargin)guiPanelDisplayImageObj.sldDisplayImageSettingsPixelValue_callback('max'));
            guiPanelDisplayImageObj.guiElements.btnDisplayImageSettingsPixelValueReset = uicontrol(guiPanelDisplayImageObj.guiElements.pnlDisplayImageSettings, 'units', 'normalized', 'position', [ 0.8, 0.05, 0.2, 0.85 ], 'callback', @guiPanelDisplayImageObj.btnDisplayImageSettingsPixelValueReset_callback);
            if (~guiPanelDisplayImageObj.testMode)
                guiPanelDisplayImageObj.updateDisplayImageSettingsPixelValueReset();
            end
        end
        
        function updateDisplayImageSettingsPixelValueReset(guiPanelDisplayImageObj, autoScale)
            if(~exist('autoScale', 'var'))
                autoScale = false;
            end

            zoomX = guiPanelDisplayImageObj.imageDisplayProperties.zoom.X;
            zoomY = guiPanelDisplayImageObj.imageDisplayProperties.zoom.Y;
            
            % Get current size of button in pixels
            if(isfield(guiPanelDisplayImageObj.guiElements, 'btnDisplayImageSettingsPixelValueReset')) %don't run resize code until gui element has been created
                set(guiPanelDisplayImageObj.guiElements.btnDisplayImageSettingsPixelValueReset, 'units', 'pixels');
                pos = get(guiPanelDisplayImageObj.guiElements.btnDisplayImageSettingsPixelValueReset, 'position');
                ht = round(pos(4));
                wd = round(pos(3));
                set(guiPanelDisplayImageObj.guiElements.btnDisplayImageSettingsPixelValueReset, 'units', 'normalized');

                % Make image that is the size of the button
                tmp = uint8(zeros(ht, wd, 3));

                % Colour in the image so that the range of pixel values from
                % the camera are in white, and the rest is in black

                % e.g. suppose the camera image has lowest pixel value 1000 and
                % highest pixel value 3700. Then we scale these relative to the
                % min of 0 and max of 4095, and then scale them relative to the
                % height of the image we're making

                subimg = guiPanelDisplayImageObj.hardware.camera.img(zoomX(1):zoomX(2), zoomY(1):zoomY(2));
                minHWPixelValue = min(subimg(:));
                maxHWPixelValue = max(subimg(:));
                
                if(autoScale)
                    set(guiPanelDisplayImageObj.guiElements.sldDisplayImageSettingsMinPixelValue,'Value',minHWPixelValue);
                    set(guiPanelDisplayImageObj.guiElements.sldDisplayImageSettingsMaxPixelValue,'Value',maxHWPixelValue);
                end
                
                displayMinPixel = round(ht * double(minHWPixelValue) / guiPanelDisplayImageObj.maxPixelValue);
                displayMaxPixel = round(ht * double(maxHWPixelValue) / guiPanelDisplayImageObj.maxPixelValue);
                guiPanelDisplayImageObj.imageDisplayProperties.currPixelMin = displayMinPixel;
                guiPanelDisplayImageObj.imageDisplayProperties.currPixelMax = displayMaxPixel;
                
                tmp(1:displayMinPixel,:,:) = 0;
                tmp(displayMinPixel+1:displayMaxPixel,:,:) = 255;
                tmp(displayMaxPixel+1:ht,:,:) = 0;

                tmp(ht:-1:1,:,:) = tmp(:,:,:); % reverse image
                set(guiPanelDisplayImageObj.guiElements.btnDisplayImageSettingsPixelValueReset, 'CData', tmp);
                
                guiPanelDisplayImageObj.updateDisplayImageColormap();
            end
        end

    end % END PUBLIC METHODS
end % END GUI CLASS 