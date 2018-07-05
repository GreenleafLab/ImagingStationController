% static helper functions for gui

classdef GuiFun
    methods (Static)

        %returns an array at even intervals between min and max, for
        %setting the ticks on a graph axis
        function ticks = getTicks(min, max, interval)
            curr = min;
            len = ceil(abs(max-min)/interval) + 1;
            ticks = zeros(1, len);
            i = 1;
            while curr <= max
                ticks(i) = curr;
                curr = curr + interval;
                i = i + 1;
            end
        end
        
        
        % this callback gets used to automatically call the "set"
        % button callback for the button in the panel that the textbox
        % resides in
        function manualTextboxEnterSet_keypressCallback(h, e, hButton)
            % the callback gets passed a handle to the button that it
            % should "click"
            
            if isequal(e.Key, 'return') % if the key that was pressed was <ENTER>, then manually call Set button callback
                drawnow;
                cb = get(hButton, 'callback'); % get the callback for the button
                hgfeval(cb); % call the callback function
            end
        end
        
    end %END STATIC METHODS
end %END CLASS GraphFun