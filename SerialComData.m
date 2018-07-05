classdef SerialComData
    properties
        serialPort;
        baudRate;
        dataBits;
        parityBit;
        stopBits;
        flowControl;
        lineTerminator;
    end %properties
    methods
        function SCD = SerialComData(l_serialPort, l_baudRate, l_dataBits, l_)
    end %methods
end