% Fluorescence Imaging Machine GUI
% Peter McMahon / pmcmahon@stanford.edu
% Curtis Layton
% October, November 2012
% March 2013

% This code has only been tested with MATLAB R2010b, Version 7.11.0.584
% (32-bit Windows). Many of the GUI functions are MATLAB-version-dependent.

classdef guiPanelStatusbar < handle
    
    properties % PROPERTIES
        guiElements;
        parent; % control that houses this panel
        position; % position of this panel within its parent
    end % END PROPERTIES
    
    properties (Constant) % CONSTANT PROPERTIES
        
    end % CONSTANT PROPERTIES
    
    
    methods (Access = private) % PRIVATE METHODS

    end % END PRIVATE METHODS
    
    
    methods % PUBLIC METHODS

        % parent: GUI object that will be the container for this panel
        % position: position to place panel within parent
        % bgcolor: background color of GUI elements
        function guiPanelStatusbarObj = guiPanelStatusbar(parent, position, bgcolor) %constructor
            % Startup code
            guiPanelStatusbarObj.parent = parent;
            guiPanelStatusbarObj.position = position;
            guiPanelStatusbarObj.guiElements.bgcolor = bgcolor;
                       
            guiPanelStatusbarObj.setupGui();
        end
        
        function setStatus(guiPanelStatusbarObj, str)
            set(guiPanelStatusbarObj.guiElements.lblStatusBar, 'string', str);
        end
            
        function setupGui(guiPanelStatusbarObj)
           guiPanelStatusbarObj.guiElements.lblStatusBar = uicontrol(guiPanelStatusbarObj.parent, 'style', 'text', 'string', 'Ready.', 'HorizontalAlignment', 'left', 'units', 'normalized', 'position', guiPanelStatusbarObj.position, 'backgroundcolor', guiPanelStatusbarObj.guiElements.bgcolor);
        end

    end % END PUBLIC METHODS
end % END GUI CLASS 