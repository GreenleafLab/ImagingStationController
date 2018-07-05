
serialCom = serial('COM7');
fopen(serialCom);
fprintf(serialCom,'on');
fclose(serialCom);

ao = analogoutput('nidaq','Dev1');
chans = addchannel(ao,0:1);
putsample(ao,[0 5])
pause on; pause(0.5)
putsample(ao,[0 0])

if 0
daq.getVendors
dIO=digitalio('nidaq','Dev1')

addline(dIO,0:7,0,'Out')
addline(dIO,0:3,1,'Out')

putvalue(dIO.Line(9),1)
putvalue(dIO.Line(9),0)



ao = analogoutput('nidaq','Dev1');
chans = addchannel(ao,0:1);
putsample(ao,[0 0])
putsample(ao,[0 5])
putsample(ao,[5 0])
putsample(ao,[0 0])
end % if 0