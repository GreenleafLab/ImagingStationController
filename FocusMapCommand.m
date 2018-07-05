%#########################################################################
% FocusMapCommand
% ImagingStationController command for creating a focus map
% Written by Curtis Layton 02/2013
%#########################################################################

classdef FocusMapCommand < ControlCommand
    
    properties % PROPERTIES

    end % END PROPERTIES
    
    
    methods (Access = private) % PRIVATE METHODS
        
    end % END PRIVATE METHODS
    
    
    methods % PUBLIC METHODS
        function command = FocusMapCommand(hardware, selectedLaser, selectedFilter)
            CheckParam.isString(selectedLaser, 'FocusMapCommand:FocusMapCommand:badInputs');
            CheckParam.isInteger(selectedFilter, 'FocusMapCommand:FocusMapCommand:badInputs');
            
            command = command@ControlCommand(hardware, 'focusmap', 'update the focusmap'); %call parent constructor
            %find the index of the selected laser
            switch lower(selectedLaser)
                case 'red'
                    selectedLaserIndex = 1;
                case 'green'
                    selectedLaserIndex = 2;
                otherwise
                    error('FocusMapCommand:FocusMapCommand:badInputs', 'the value for the selectedLaser parameter of the FocusMap command should be "red" or "green"');
            end
            CheckParam.isInList(num2str(selectedFilter), command.hardware.stageAndFilterWheel.filterPositions, 'FocusMapCommand:FocusMapCommand:badInputs');

            command.parameters.selectedLaserIndex = selectedLaserIndex;
            command.parameters.selectedFilter = selectedFilter;
        end
        
        
        function execute(command, scriptDepth, depthIndex)
            if(~exist('depthIndex','var'))
                depthIndex = 1;
            end
            
            %get a local copy of parameters that will be used
            %the 'getParameter' method substitutes any variables (e.g. for
            %the current loop iteration)
            selectedLaserIndex = command.getParameter('selectedLaserIndex', depthIndex);
            selectedFilter = command.getParameter('selectedFilter', depthIndex);

            try
                guiFocusMapWizardObj = guiFocusMapWizard(command.hardware, false, true, true, selectedLaserIndex, selectedFilter);
                
                %wait until the wizard is closed to proceed
                if(isvalid(guiFocusMapWizardObj))
                    uiwait(guiFocusMapWizardObj.getFigureHandle());
                end
            catch err
                if(~strcmp(err.identifier, 'MATLAB:timer:badcallback')) %errors associated with closing the window, cancelling the wizard
                    disp(err.identifier);
                    rethrow(err);
                end
            end
        end
        
    end % END PUBLIC METHODS
    
end