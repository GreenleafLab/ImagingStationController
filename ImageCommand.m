%#########################################################################
% ImageCommand
% ImagingStationController command for acquiring images
% Written by Curtis Layton 02/2013
%#########################################################################

classdef ImageCommand < ControlCommand
    
    properties (Constant) % STATIC PROPERTIES
        powerTolerance = 3; %mW
    end % END STATIC PROPERTIES
    
    properties % PROPERTIES
        displayImagePanel; %optional handle to a gui image panel in which to display the image as it is taken
    end % END PROPERTIES
     
    methods (Access = private) % PRIVATE STATIC METHODS
               
    end % END PRIVATE METHODS
        
    methods % PUBLIC METHODS
        
        function command = ImageCommand(hardware, laser, laserPower, filter, exposureTime, filename, displayImagePanel)
            if(~exist('displayImagePanel', 'var'))
                displayImagePanel = 'null';
            end
            
            CheckParam.isString(laser, 'ImageCommand:ImageCommand:badInputs'); 
            CheckParam.isNumeric(laserPower, 'ImageCommand:ImageCommand:badInputs');
            
            command = command@ControlCommand(hardware, 'image', 'acquire an image'); %call parent constructor
            
            switch laser
                case 'green'
                    CheckParam.isWithinARange(laserPower, command.hardware.lasers.greenLaserPowerMin, command.hardware.lasers.greenLaserPowerMax, 'ImageCommand:ImageCommand:notInRange');
                case 'red'
                    CheckParam.isWithinARange(laserPower, command.hardware.lasers.redLaserPowerMin, command.hardware.lasers.redLaserPowerMax, 'ImageCommand:ImageCommand:notInRange');
                otherwise
                    error('ImageCommand:execute:badParameter', '"%s" is an invalid laser in the image command.  Valid lasers are "green" and "red"', command.parameters.laser);
            end
                    
            CheckParam.isString(filter, 'ImageCommand:ImageCommand:badInputs');
            CheckParam.isInList(filter, command.hardware.stageAndFilterWheel.filterPositions, 'ImageCommand:ImageCommand:badInputs');
            
            CheckParam.isNumeric(exposureTime, 'ImageCommand:ImageCommand:badInputs');
            CheckParam.isWithinARange(exposureTime, command.hardware.camera.minExposure, command.hardware.camera.maxExposure, 'ImageCommand:ImageCommand:notInRange');

            CheckParam.isString(filename, 'ImageCommand:ImageCommand:badInputs'); 
            
            command.parameters.laser = laser; %'green' or 'red'
            command.parameters.laserPower = laserPower; % in mW
            command.parameters.filter = filter;% emission filter position (0-7)
            command.parameters.exposureTime = exposureTime; % in ms
            command.parameters.filename = filename; % filename to save image
            command.displayImagePanel = displayImagePanel; % gui image panel handle
        end
        
        
        function execute(command, scriptDepth, depthIndex)
            if(~exist('depthIndex','var'))
                depthIndex = 1;
            end
            
            %get a local copy of parameters that will be used
            %the 'getParameter' method substitutes any variables (e.g. for
            %the current loop iteration)
            laser = command.getParameter('laser', depthIndex);
            laserPower = command.getParameter('laserPower', depthIndex);
            filter = command.getParameter('filter', depthIndex);
            exposureTime = command.getParameter('exposureTime', depthIndex);
            filename = command.getParameter('filename', depthIndex)

            %set the emission filter
            command.hardware.stageAndFilterWheel.moveFilterWheel('0', filter);
            
            %set the exposure time
            command.hardware.camera.setExposure(exposureTime);

            switch laser
                case 'green'
                    %set the laser power
                    command.hardware.lasers.greenSetPower(laserPower);
                    
                    %ensure laser power has reached its set value before proceeding
                    while(~command.hardware.lasers.isAtSetPower())
                        pause on; pause(1);
                    end
                    
                    %switch the excitation filter
                    
                    %commented out by Johan, 12/20/2013. There is no
                    %excitation wheel
                    %command.hardware.stageAndFilterWheel.moveFilterWheel('1','0');
                    
                    %acquire image                   
                    t = tic();
                    command.hardware.lasers.switchGreen(); 
                    command.hardware.lasers.laserEnable();
                    command.hardware.camera.acquireImage();
                    command.hardware.lasers.switchOff();
                    elapsedTime = toc(t)
                    
                case 'red'
                    %set the laser power
                    command.hardware.lasers.redSetPower(command.parameters.laserPower);
                    
                    %ensure laser power has reached its set value before proceeding
                    while(~command.hardware.lasers.isAtSetPower())
                        pause on; pause(1);
                    end
                    
                    %switch the excitation filter
                     %commented out by Johan, 12/20/2013. There is no
                    %excitation wheel
                    %command.hardware.stageAndFilterWheel.moveFilterWheel('1','1');

                    %acquire image                   
                    t = tic();
                    command.hardware.lasers.switchRed();
                    command.hardware.lasers.laserEnable();
                    command.hardware.camera.acquireImage();
                    command.hardware.lasers.switchOff();
                    elapsedTime = toc(t)
                    
                otherwise
                    error('ImageCommand:execute:badParameter', '"%s" is an invalid laser in the image command.  Valid lasers are "green" and "red"', command.parameters.laser);
            end
            
            %if a gui image update function handle was passed in, update
            %the gui to display the acquired image
            if(isa(command.displayImagePanel,'handle'))
                command.displayImagePanel.updateDisplayImageSettingsPixelValueReset();
            end
            
            %save the file
            try
                command.hardware.camera.saveImage(filename);
            catch err
                disp(err.identifier)
            end
            
         end
        
    end % END PUBLIC METHODS
    
end