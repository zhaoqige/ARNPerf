#!/usr/bin/python3
"""
Re-write "gps_win.pl" to "GPS.py"
by Qige <qigezhao@gmail.com>, 2017.10.10

TODO: 
    1. verify with real GPS Sensor (USB Mouse style);
    2. Compatible with multi protocol.
"""

import re
import sys
import time

import serial
import serial.tools.list_ports


# application
def appVersion():
    print('ARNPerf v7.0 (https://github.com/zhaoqige/arnperf.git')
    print('---- by Qige <qigezhao@gmail.com> v7.0.101017-py ----')
    print('-----------------------------------------------------')

def appHelp():
    print('Usage: GSP.py com8 [gps.txt] # user defined GPS Sensor & output file')
    print('Usage: GSP.py                # find GPS Sensor automatically, write to "gps.txt"')

def cliParams():
    if len(sys.argv) >= 3:
        return sys.argv[1:3] # 3rd not included
    return None, None
    
# serial port handler
def spOpen(serialName):
    # 115200/8/N/1
    serialFd = serial.Serial(serialName, 115200, timeout = 3)
    serialFd.bytesize       = 8
    serialFd.parity         = serial.PARITY_NONE;
    serialFd.stopbits       = 1
    
    serialFd.timeout        = 1.5
    serialFd.writeTimeout   = 1
    if serialFd and serialFd.readable():
        return serialFd
    return None

def spRead(serialFd):
    if (not serialFd is None) and (serialFd.readable()):
        #buffer = serialFd.read(512) # TODO: use GPS Sensor
        buffer = "$GPRMC,024813.640,A,3158.4608,N,11848.3737,W,10.05,324.27,150706,,,A*50"+"\n"+"$GPGGA,092204.999,4250.5589,S,14718.5084,E,1,04,24.4,19.7,M,,,,0000*1F"
        return buffer
    return None

def spWrite(serialFd, data):
    if (not serialFd is None) and (not data is None):
        serialFd.write(data)

def spClose(serialFd):
    if (not serialFd is None):
        serialFd.close()

# find first GPS Sensor, return fd
def GPSSensorFindFd(spDev):
    spDesc = spDev[0]
    serialFd = spOpen(spDesc)
    if (not serialFd is None):
        spData = spRead(serialFd) # TODO: replace string with GPS Sensor output
        #spData = ",,,,0000*1F$GPGGA,092204.999,4250.5589,S,14718.5084,E,1,04,24.4,19.7,M,,,,0000*1F" # DEBUG USE ONLY!
        spDataLength = len(spData)
        gpsMatch = re.search("GPRMC|GPGGA|GPGSA|GPGSV|GPVTG|GPGLL", spData)
        if gpsMatch:
            serialName = serialFd.name
            print("-> GPS sensor found:", serialName, '|', spDataLength, 'bytes')
            return serialFd
        else:
            print(spData)
            spClose(serialFd)
    return None

# protocol: NEMA-0138
def ProtoNEMA0183FindGPRMC(data):
    gprmcRaw = None
    gpList = data.split('\n')
    if len(gpList) >= 1:
        for line in gpList:
            if re.search('GPRMC', line):
                gprmcRaw = line
                break
    #gprmcRaw = "$GPRMC,024813.640,A,3158.4608,N,11848.3737,E,10.05,324.27,150706,,,A*50" # DEBUG USE ONLY!
    return gprmcRaw

def ProtoNEMA0183DegreeConvert(degreeRaw, isSW):
    vi = int(float(degreeRaw) / 100)
    val = vi + ((float(degreeRaw) - vi * 100) / 60)
    if (isSW == 'S') or (isSW == 'W'):
        val = 0 - val
    return val

#return "A,39.0005,119.0005,0,0"
def ProtoNEMA0183ParseRecord(gprmc_raw):
    gprmcList = gprmc_raw.split(',')
    if len(gprmcList) >= 7:
        gpsFlag     = 'A' if re.search('A', gprmcList[2]) else 'V'
        gpsLat      = ProtoNEMA0183DegreeConvert(gprmcList[3], gprmcList[4])
        gpsLng      = ProtoNEMA0183DegreeConvert(gprmcList[5], gprmcList[6])
        gpsSpeed    = float(gprmcList[7]) * 1.852 # knots to km/h
        gpsHdg      = float(gprmcList[8])
        gpsLatlng   = '%s,%.6f,%.6f,%.2f,%.1f' % (gpsFlag, gpsLat, gpsLng, gpsSpeed, gpsHdg)
        return gpsLatlng
    return 'V,,,,'

# GPS sync
def GPSSensorSyncLatlng(serialFd, gpsFile):
    outFile = 'gps.txt'
    if (not gpsFile is None):
        outFile = gpsFile
        
    if (not serialFd is None):
        print("-> updating GPS location from", serialFd.name, ">", outFile)
        while 1:
            data = spRead(serialFd)
            if (not data is None):
                gprmc_raw = ProtoNEMA0183FindGPRMC(data)
                data = ProtoNEMA0183ParseRecord(gprmc_raw)
                GPSLatlngSave(outFile, data)
                time.sleep(1)
    else:
        print("error> invalid GPS sensor > ", serialFd)
        appHelp()

# save parsed data+ts to file
def GPSLatlngSave(gpsFile, data):
    if (not gpsFile is None) and (not data is None):
        ts = time.strftime("%Y-%m-%d %H:%M:%S")
        print('==> GCJ-02:', data, '@', ts)
        fd = open(gpsFile, 'w')
        if fd:
            fd.write(data + ',' + ts)
            fd.flush()
        else:
            print('error> failed to save & exchange GPS location')
        
        fd.close()
    else:
        print('error> NO data to save')

"""
GPS Sensor Handler
------------------
Usage: "GPS.py com8 gps.txt"
------------------
by Qige <qigezhao@gmail.com>
2017.10.10
"""
appVersion()

print('> reading input ...')
gpsCom, gpsFile = cliParams()

serialFd = None
if (not gpsCom is None):
    print('> opening GPS Sensor:', gpsCom)
    serialFd = spOpen(gpsCom)
else:
    print('> finding GPS Sensor ...')
    spDevList = list(serial.tools.list_ports.comports())
    if len(spDevList) <= 0:
        print("error: NO GPS Sensor found!")
    else:
        for spDev in spDevList:
            serialFd = GPSSensorFindFd(spDev)
            if (not serialFd is None):
                break

if (not serialFd is None):
    print('> reading GPS location ...')
    GPSSensorSyncLatlng(serialFd, gpsFile)
else:
    print('error> NO GPS Sensor valid!')
    appHelp()
