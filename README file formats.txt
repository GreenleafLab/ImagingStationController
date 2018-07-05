README
------

** File Formats for the Fluorescence Imaging Control Software **

Original: Peter McMahon (pmcmahon@stanford.edu), March 2013

-------------------------------------------------------------------------------------

The software uses several files to store settings. This file describes the purpose and formats
for some (maybe even all!) of them.

-------------------------------------------------------------------------------------

FILE:    focusmap.txt

PURPOSE: store list of (x,y,z) points where the z has been set such that the image (of the clusters
         on the flow cell) is in focus. These points are fit to a plane, and from this we can determine
         what z stage value is required to produce an in-focus image given any (x,y) position.

FORMAT:  A minimum of three points must be defined in the file (you need three points to fit a plane).
         Each point is defined by an x,y,z truple, and each point appears on a new line (so the number
         of lines in the file tells you how many points are being used). The values are exactly the
         positions that the stage motors are instructed to go to, which are nominally absolute positions
         relative to the home positions of the motors.

         The format is:

           Xstageposition<space>Ystageposition<space>Zstageposition<crlf>
           Xstageposition<space>Ystageposition<space>Zstageposition<crlf>
           ...
           Xstageposition<space>Ystageposition<space>Zstageposition<crlf>

         For example:

           -566449.000000 -349921.000000 -342053.300000
           -567940.000000 -199915.000000 -350028.600000
           -555922.000000 -274911.000000 -357830.100000
           -563437.000000 -274911.000000 -358086.000000

-------------------------------------------------------------------------------------

FILE:    edges.txt

PURPOSE: store list of (x,y) points where the x has been set such that the image is centered on
         the left edge of the part of the flow cell that is imaged. We fit a line to these points
         to determine the angle at which the chip is loaded, so that we can reliably go to the correct
         x position for any given y position. This is used primarily in going to specific tiles,
         where the y positions are assumed to stay constant, but the x positions vary due to changes
         in the angle of the chip each time it is reloaded, or a new chip is loaded.

FORMAT:  A minimum of two points must be defined in the file (you need two points to fit a line).
         Each point is defined by an x,y truple, and each point appears on a new line (so the number
         of lines in the file tells you how many points are being used).

         The format is:

           Xstageposition<space>Ystageposition<crlf>
           Xstageposition<space>Ystageposition<crlf>
           ...
           Xstageposition<space>Ystageposition<crlf>

         For example:

           -566449.000000 -349921.000000
           -563437.000000 -274911.000000
           -567940.000000 -199915.000000

-------------------------------------------------------------------------------------

FILE:    tilemap.txt

PURPOSE: store list of (delta_x,y) points which define which stage positions correspond to the
         locations of the tiles to image on the flow cell (14 tiles for a MiSeq flow cell).

         the goal is to allow the software to go to a specific tile, by looking up the stage positions
         that correspond to it.

         The y points define where the tiles are in the flow cell as absolute stage positions. The
         delta_x positions define where the tiles are in the flow cell *relative* to the left edge of
         the imaging part of the flow cell.

         The way this gets used is that if we want to go to tile 1, we look up the y position of tile 1.
         then we use the edges.txt file to find what the x position of the edge for that particular 
         y position is. Finally, we take the delta_x value from the tilemap.txt file for tile 1, and add
         it to the x position of the edge. This gives us an absolute (x,y) position of the tile, for this
         particular loading of the chip.

FORMAT:  One line per tile.

         The format is:

           deltaXstageposition<space>Ystageposition<crlf>
           deltaXstageposition<space>Ystageposition<crlf>
           ...
           deltaXstageposition<space>Ystageposition<crlf>

         For example (14 tiles):

           -100 -349928
           -100 -340928
           -100 -331928
           -100 -322928
           -100 -313928
           -100 -304928
           -100 -295928
           -100 -286928
           -250 -277928
           -100 -268928
           -300 -259928
           -100 -250928
           -100 -241928
           -100 -232928

-------------------------------------------------------------------------------------

