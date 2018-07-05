%#########################################################################
% FindEdgeCommand
% ImagingStationController command for creating a focus map
% Written by Curtis Layton 02/2013
%#########################################################################

classdef FindEdgeCommand < ControlCommand
    
    properties % PROPERTIES

    end % END PROPERTIES
    
    
    methods (Access = private) % PRIVATE METHODS
        
    end % END PRIVATE METHODS
    
    
    methods % PUBLIC METHODS
        function command = FindEdgeCommand(hardware, selectedLaser, selectedFilter)
            CheckParam.isString(selectedLaser, 'FindEdgeCommand:FindEdgeCommand:badInputs');
            CheckParam.isInteger(selectedFilter, 'FindEdgeCommand:FindEdgeCommand:badInputs');
            
            command = command@ControlCommand(hardware, 'findedge', 'update the edge map'); %call parent constructor
            %find the index of the selected laser
            switch lower(selectedLaser)
                case 'red'
                    selectedLaserIndex = 0;
                case 'green'
                    selectedLaserIndex = 1;
                otherwise
                    error('FindEdgeCommand:FindEdgeCommand:badInputs', 'the value for the selectedLaser parameter of the FocusMap command should be "red" or "green"');
            end
            CheckParam.isInList(num2str(selectedFilter), command.hardware.stageAndFilterWheel.filterPositions, 'FindEdgeCommand:FindEdgeCommand:badInputs');

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
                guiEdgeFinderWizardObj = guiEdgeFinderWizard(command.hardware, false, true, true, selectedLaserIndex, selectedFilter);

                %wait until the wizard is closedto proceed
                if(isvalid(guiEdgeFinderWizardObj))
                    uiwait(guiEdgeFinderWizardObj.getFigureHandle());
                end
            catch err
                if(~strcmp(err.identifier, 'MATLAB:timer:badcallback')) %errors associated with closing the window, cancelling the wizard
                    rethrow(err);
                end
            end
        end
        
    end % END PUBLIC METHODS
    
end