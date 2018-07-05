%#########################################################################
% ImagingStationHardware
% Container object to hold references to all hardware
% Written by Curtis Layton 10/2012
%#########################################################################

classdef ImagingStationHardware < handle
    
    properties % PROPERTIES
        lasers;
        stageAndFilterWheel;
        pump;
        selectorValve;
        peltier;
        autosamplerPeltier;
        camera;
    
        focusMap;
        tileMap;
        
        presetPositions;  %map to hold preset stage positions
        
        lastImageAcquiredMetadata; %metadata about the last image acquired
        
            
    end % END PROPERTIES

    
    methods (Access = private) % PRIVATE METHODS

    end % END PRIVATE METHODS
    
    
    methods % PUBLIC METHODS
        function hw = ImagingStationHardware()
            instrreset; % close any serial ports that MATLAB already has open 

            %setup camera
            hw.camera = Photometrics_PVCam_CameraController('C:\Program Files\Micro-Manager-1.4\ImagingStation.cfg');
            
            %connect to lasers and power on
            hw.lasers = LaserBox();
            hw.lasers.greenSetupSerialCommunication('COM22');
            hw.lasers.greenSerialConnect();
                %power on green
                hw.lasers.greenPowerOn();
                hw.lasers.greenSetPower(hw.lasers.greenDefaultPower);

            hw.lasers.redSetupSerialCommunication('COM23');
            hw.lasers.redSerialConnect();
                %power on red
                hw.lasers.redPowerOn();
                hw.lasers.redSetPower(hw.lasers.redDefaultPower);
         
            %connect to stage and filter wheel controller
            hw.stageAndFilterWheel = ASI_LX4000_StageAndFilterWheelController();
            hw.stageAndFilterWheel.setupSerialCommunication('COM20');
            hw.stageAndFilterWheel.serialConnect();

            %connect to syringe pump and initialize
            hw.pump = Kloehn_PN24741_V6SyringePump();
            hw.pump.setupSerialCommunication('COM21');
            hw.pump.serialConnect();
                %initialize
                hw.pump.initializeSyringe();
                hw.pump.waitUntilReady();
                
            %connect to selector valve
            hw.selectorValve = VICI_EMHMA_CE_SelectorValveController();
            hw.selectorValve.setupSerialCommunication('COM19');
            hw.selectorValve.serialConnect();
            
            %connect to peltier controller and read current values
            hw.peltier = TC_36_25_RS232_PeltierController(); 
            hw.peltier.setupSerialCommunication('COM24');
            
            hw.peltier.serialConnect();
            %setup emprically tuned parameters
            
            
            
            hw.peltier.PIDControl();
            % 24 V Power Supply
%             hw.peltier.setProportionalBandwidth(70);
%             hw.peltier.setDerivativeGain(0);
%             hw.peltier.setIntegralGain(0.25);
%             hw.peltier.setCoolMultiplier(2);
%             hw.peltier.setHeatMultiplier(1);
            
            %12V Power Supply
            hw.peltier.setProportionalBandwidth(70);
            hw.peltier.setDerivativeGain(0);
            hw.peltier.setIntegralGain(0.34);
            hw.peltier.setCoolMultiplier(2);
            hw.peltier.setHeatMultiplier(1.5);
            
            hw.peltier.setTemp(37);
            %setup safety alarm power cutoff for over/under temperature
            %hw.peltier.setAlarmSensor(0);
            hw.peltier.setAlarmType(2); %fixed value
            hw.peltier.setHighAlarm(80);
            hw.peltier.setLowAlarm(5);
            hw.peltier.setAlarmDeadband(1);
            hw.peltier.shutdownIfAlarmOn();
            hw.peltier.alarmLatchOff();
            hw.peltier.resetAlarm();   
                       
            %Setup Autosampler Peltier
%             hw.autosamplerPeltier = TC_36_25_RS232_PeltierController();
%             hw.autosamplerPeltier.setupSerialCommunication('COM1'); 
%             hw.autosamplerPeltier.serialConnect();
                      
            %setup focus map       
            hw.focusMap = FocusMap(hw.stageAndFilterWheel); % load last saved focus map
            
            %setup tile map       
            hw.tileMap = TileMap(hw.stageAndFilterWheel); % load last saved tile map
            
            %setup preset stage positions
            hw.presetPositions = containers.Map();
            % preset stage positions                   X          Y         Z
            %hw.presetPositions('load flowcell')  = [-336338   -289910  -70845.7];
            hw.presetPositions('load flowcell')  = [-335000   -50000  -70000]; % modified for TIRF setup (PLM 16-Dec-2013)
            %hw.presetPositions('image position') = [-736347   -489913 -240077.4];
            %hw.presetPositions('image position') = [-741292   -521382 -271323.8];
            %hw.presetPositions('image position') = [-741292   -521382 -302541.6]; % AHH 7/29/2014
            %hw.presetPositions('image position') = [-741292   -521382 -271879.5]; % AHH 8/5/2014
            %hw.presetPositions('image position') = [-741292   -521382 -270281.9]; % AHH 12/8/2014
            hw.presetPositions('image position') = [-750600   -347200 -290427.6]; % WRB 8/19/2015
            
%             %init metadata that gets set with every image that is acquired
            hw.lastImageAcquiredMetadata = struct();
            hw.lastImageAcquiredMetadata.laser = '';
            hw.lastImageAcquiredMetadata.laserPower = 0;
            hw.lastImageAcquiredMetadata.exposureTime = 0;
            hw.lastImageAcquiredMetadata.filter = '';
            hw.lastImageAcquiredMetadata.Xpos = 0;
            hw.lastImageAcquiredMetadata.Ypos = 0;
            hw.lastImageAcquiredMetadata.Zpos = 0;
            hw.lastImageAcquiredMetadata.timestamp = '';
            hw.lastImageAcquiredMetadata.temperature = 0;
        end
        
        function delete(hw) %destructor
            hw.disconnect();
        end
        
        function disconnect(hw)
            %stop the peltier polling loop
            hw.peltier.stopPollingLoop();
            
            %disconnect from peltier controllers
            hw.peltier.serialDisconnect();
            hw.autosamplerPeltier.serialDisconnect();
            
            %disconnect from selector valve
            hw.selectorValve.serialDisconnect();

            %disconnect from syringe pump
            hw.pump.serialDisconnect();

            %disconnect from stage and filter wheel controller
            hw.stageAndFilterWheel.serialDisconnect();

            %power off lasers
            hw.lasers.greenPowerOff();
            hw.lasers.redPowerOff();

            %disconnect from lasers
            hw.lasers.greenSerialDisconnect();
            hw.lasers.redSerialDisconnect();
        end
        
        
        %########### COMMAND AND CONTROL FUNCTIONS ############
        %functions that integrate more than one hardware component or
        %multiple steps

        function pumpFromPosition(hw, fromPosition, volume, flowRate)
            %TODO check fromPosition
            hw.selectorValve.setPosition(fromPosition);
            
            %TODO check volume, flowRate
            hw.pump.pump(volume, flowRate);
        end
        
        function elapsedTime = acquireImage(hw, exposureTime, emissionFilter, laser)
             
            
            
            %set exposure time
            CheckParam.isNumeric(exposureTime, 'ImagingStationHardware:acquireImage:notNumeric');
            CheckParam.isWithinARange(exposureTime, hw.camera.minExposure, hw.camera.maxExposure, 'ImagingStationHardware:acquireImage:outOfRange');
            hw.camera.setExposure(exposureTime);

            %set emission filter wheel
            if(CheckParam.isChar(emissionFilter, 'ImagingStationHardware:acquireImage:badInputs')) %char input
            	CheckParam.isInList(emissionFilter, hw.stageAndFilterWheel.filterPositions, 'ImagingStationHardware:acquireImage:badInputs', 'Invalid filter wheel position');
            end
            hw.stageAndFilterWheel.moveFilterWheel('0', emissionFilter);

            %set laser and excitation filter
            CheckParam.isString(laser, 'ImagingStationHardware:acquireImage:invalidLaser', 'the only valid lasers for imaging are "red" and "green"');
            t = 0;
            switch lower(laser)
                case 'red' %660nm laser
                    %hw.stageAndFilterWheel.moveFilterWheel('1','1');
                    hw.lasers.switchRed();
                    t = tic();
                case 'green' %532nm laser
                    %hw.stageAndFilterWheel.moveFilterWheel('1','0');
                    hw.lasers.switchGreen();
                    t = tic();
                otherwise
                   error('ImagingStationHardware:acquireImage:invalidLaser', 'the only valid lasers for imaging are "red" and "green"');
            end         
            hw.lasers.laserDisable();  
            hw.camera.acquireImage();
            hw.lasers.switchOff();
            elapsedTime = toc(t);
            hw.lastImageAcquiredMetadata.laser = lower(laser);
            switch lower(laser)
                case 'red'
                    hw.lastImageAcquiredMetadata.laserPower = hw.lasers.redGetPower();
                case 'green'
                    hw.lastImageAcquiredMetadata.laserPower = hw.lasers.greenGetPower();
                otherwise
                   error('ImagingStationHardware:acquireImage:invalidLaser', 'the only valid lasers for imaging are "red" and "green"');
            end
            
            hw.lasers.laserDisable();
            
            hw.lastImageAcquiredMetadata.exposureTime = exposureTime;
            hw.lastImageAcquiredMetadata.filter = emissionFilter;
            hw.lastImageAcquiredMetadata.Xpos = hw.stageAndFilterWheel.whereIsX();
            hw.lastImageAcquiredMetadata.Ypos = hw.stageAndFilterWheel.whereIsY();
            hw.lastImageAcquiredMetadata.Zpos = hw.stageAndFilterWheel.whereIsZ();
            hw.lastImageAcquiredMetadata.timestamp = StringFun.getTimestampString();
            hw.lastImageAcquiredMetadata.temperature = hw.peltier.getCurrentTemp();
        end
        
        %go to the in-focus Z for the current XY position, based on the focus map
        function focusZ(hw)
            currXpos = hw.stageAndFilterWheel.whereIsX();
            currYpos = hw.stageAndFilterWheel.whereIsY();
            % JOHAN Modified for temperature by Johan 12/27/2013
            currTemp = hw.peltier.getCurrentTemp();
            % END JOHAN 
            
            % the focus map is only valid within the flowcell, so
            % only do an automatic Z move if the X,Y is within the
            % flowcell region
            if hw.stageAndFilterWheel.isAboveFlowCell(currXpos, currYpos)
                % JOHAN Modified for temperature by Johan 12/27/2013
                newZpos = hw.focusMap.getZ(currXpos, currYpos, currTemp);
                % END JOHAN 
                CheckParam.isWithinARange(newZpos, hw.stageAndFilterWheel.stageZLimitMin, hw.stageAndFilterWheel.stageZLimitMax, 'gui:btnManualStagesXYmove_callback:newZposNotInRange');
                hw.stageAndFilterWheel.moveZ(newZpos);
            else
                error('ImagingStationHardware:focusZ:outOfBounds','auto-Z based on focus map requested from an out-of-bounds XY position.');
            end
        end
        
        %switches to the appropriate excitation (clean-up) filter and switches the optical switch to the green laser channel
        function switchGreenLaser(hw)
            %hw.stageAndFilterWheel.moveFilterWheel('1','0');
            hw.lasers.manualLaserEnable()
            hw.lasers.switchGreen();
        end
        
        %switches to the appropriate excitation (clean-up) filter and switches the optical switch to the red laser channel
        function switchRedLaser(hw)
            %hw.stageAndFilterWheel.moveFilterWheel('1','1');
            hw.lasers.manualLaserEnable()
            hw.lasers.switchRed();
        end
        
        %optical switch off--wrapper here for completeness 
        function switchLaserOff(hw)
            hw.lasers.switchOff();
        end
        
        %send stage to a tile on the tileMap
        function gotoTile(hw, tile, focus)
            if(~exist('focus', 'var'))
                focus = true;
            end
            validatedTile = hw.tileMap.validateTile(tile);
            
            [tileX, tileY] = hw.tileMap.getTilePos(validatedTile); % get (x,y) position of tile from tile map
            
            if(focus)
                % JOHAN Modified for temperature by Johan 12/27/2013
                currTemp = hw.peltier.getCurrentTemp();
                % END JOHAN 
                tileZ = hw.focusMap.getZ(tileX, tileY, currTemp); % get (z) position for imaging tile from focus map
            else
                tileZ = hw.stageAndFilterWheel.whereIsZ(); %use current position
            end
            
            hw.stageAndFilterWheel.moveToXYZ(tileX, tileY, tileZ); %move
        end
        
        %send stage to a preset position
        function gotoPreset(hw, presetName, focus)
            if(~exist('focus', 'var'))
                focus = false;
            else
                CheckParam.isBoolean(focus, 'ImagingStationHardware:gotoPreset:badParam');
            end
            
            CheckParam.isString(presetName, 'ImagingStationHardware:gotoPreset:badPreset');
            if(isKey(hw.presetPositions, presetName))
                currCoords = hw.presetPositions(presetName);
                hw.stageAndFilterWheel.moveToXYZ(currCoords(1), currCoords(2), currCoords(3));
            else
                error('ImagingStationHardware:gotoPreset:badPreset', '"%s" is not a valid preset position', presetName);
            end
            
            if(focus)
                hw.focusZ();
            end
        end
        
        %home and zero stage to initialize the coordinate system, then move
        %to 'image position' as an initial stage position
        function initStage(hw)
            try
                %home and zero stage
                hw.stageAndFilterWheel.homeStage();
                hw.stageAndFilterWheel.zeroStage();

                try
                    %move stage into initial position
                    hw.gotoPreset('image position');
                catch err2
                    error('ImagingStationHardware:gotoPreset:moveFail', 'Did not reach initial stage position');
                end

            catch err
                if(strcmp(err.identifier, 'ImagingStationHardware:gotoPreset:moveFail'))
                    throw(err)
                else
                    error('ImagingStationHardware:gotoPreset:homeFail', 'Stage did not reach the home position--the stage was not re-zeroed!  Coordinates in uninitialized stage may be significanlty off, leading to crashes.');
                end
            end
        end
        
        %gather metadata about the last image taken and save
        function saveImageMetadata(hw, pathAndFilename)
            fid = fopen(pathAndFilename, 'wt');
            fprintf(fid, 'laser: %s\n', hw.lastImageAcquiredMetadata.laser);
            fprintf(fid, 'laser_power: %.3f\n', hw.lastImageAcquiredMetadata.laserPower);
            fprintf(fid, 'exposure_time: %.3f\n', hw.lastImageAcquiredMetadata.exposureTime);
            fprintf(fid, 'emission_filter: %s\n', hw.lastImageAcquiredMetadata.filter);
            fprintf(fid, 'X_pos: %.1f\n', hw.lastImageAcquiredMetadata.Xpos);
            fprintf(fid, 'Y_pos: %.1f\n', hw.lastImageAcquiredMetadata.Ypos);
            fprintf(fid, 'Z_pos: %.1f\n', hw.lastImageAcquiredMetadata.Zpos);
            fprintf(fid, 'timestamp: %s\n', hw.lastImageAcquiredMetadata.timestamp);
            fprintf(fid, 'temperature: %.2f\n', hw.lastImageAcquiredMetadata.temperature);
            fclose(fid);
        end
        
    end % END PUBLIC METHODS
    
end