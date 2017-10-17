#!/usr/bin/python3
"""
Re-write "gps_win.pl" to "GPS.py"
by Qige <qigezhao@gmail.com>
2017.10.10-2017.10.13 compatible with u-blox6 GMOUSE GPS VK-162
2017.10.16 compatible with u-blox7, Stoton GPS+BDS GNSS100B
2017.10.17 final re-format

Done:
    * verify with real GPS Sensor (GMOUSE VK-162, USB Mouse style);
    * Compatible with multi protocol.
"""

import re
import sys
import time

import serial
import serial.tools.list_ports

FLAG_RUN = 1
FLAG_DBG = 0

GPS_SENSOR      = 'gps.txt'


# application
def appVersion():
    print('ARNPerf v7.0 (https://github.com/zhaoqige/arnperf.git')
    print('---- by Qige <qigezhao@gmail.com> v7.0.101017-py ----')
    print('-----------------------------------------------------')

def appHelp():
    print('Usage: GSP.py com8 [gps.txt] # user defined GPS Sensor & output file')
    print('Usage: GSP.py                # find GPS Sensor, then write to "gps.txt"')

def cliParams():
    if sys and sys.argv and len(sys.argv) >= 3:
        return sys.argv[1:3] # 3rd not included
    
    if sys and sys.argv and len(sys.argv) >= 2:
        return sys.argv[1], None
    
    return None, None
    
# serial port handler
def spOpen(serialName):
    # 115200/8/N/1
    try:
        if serialName:
            serialFd = serial.Serial(serialName, timeout = 3)
            serialFd.baudrate       = 115200
            #serialFd.baudrate       = 9600
            serialFd.bytesize       = 8
            serialFd.parity         = serial.PARITY_NONE;
            serialFd.stopbits       = 1
            
            serialFd.timeout        = 1.5
            serialFd.writeTimeout   = 1
            
            if serialFd and serialFd.readable():
                return serialFd
        else:
            return None
        
    except serial.SerialException:
        return None

def spRead(serialFd):
    if serialFd and (serialFd.readable()):
        buffer = serialFd.read(512)
        return buffer
    
    return None

def spWrite(serialFd, data):
    if serialFd and data:
        serialFd.write(data)

def spClose(serialFd):
    if serialFd:
        serialFd.close()

# u-blox 6 chip: GPS, start with $GP*
def GPSUblox6(msg):
    if msg and len(msg) >= 6:
        flagUblox6 = re.search("GPRMC|GPGGA|GPGSA|GPGSV|GPVTG|GPGLL", \
                    str(msg))
        
        if (flagUblox6):
            return 1
    
    return 0

# u-blox 7 chip: GPS+BSD, start with $GN*
def GPSUblox7(msg):
    if msg and len(msg) >= 6:
        flagUblox7 = re.search("GNRMC|GNGGA|GNGSA|GBGSV|GNGSV|GNVTG|GNGLL", \
                    str(msg))
        
        if (flagUblox7):
            return 1
    
    return 0

# find first GPS Sensor, return fd
def GPSSensorFindFd(spDev):
    if spDev:
        spDesc = spDev[0]
        #spDesc = 'com17' # TODO: DEBUG USE ONLY!
        serialFd = spOpen(spDesc)
        if serialFd:
            spData = spRead(serialFd) # read GPS Sensor
            # DEBUG USE ONLY!
            #spData = ",,,,0000*1F$GPGGA,092204.999,4250.5589,S,14718.5084,E,1,04,24.4,19.7,M,,,,0000*1F"
            spDataLength = 0
            if spData:
                spDataLength = len(spData)
            
            if spDataLength >= 6:
                if GPSUblox6(spData) or GPSUblox7(spData):
                    serialName = serialFd.name
                    print("-> GPS sensor found:", serialName, '|', spDataLength, 'bytes')
                    return serialFd
                else:
                    print(spData)
                    spClose(serialFd)

        else:
            print('->', spDesc, '- Device Busy or Not GPS Sensor')
            
    else:
        print('error> Unknown Device')
        
    return None

# protocol: NEMA-0138
# $GPRMC sample data
# "$GPRMC,024813.640,A,3158.4608,N,11848.3737,E,10.05,324.27,150706,,,A*50"
def ProtoNEMA0183FindGPRMC(data):
    gprmcRaw = None
    if data:
        gpList = re.split(r'[\n\r\\\n\\\r]', str(data))
        if gpList and len(gpList) >= 1:
            for line in gpList:
                if line and re.search('GPRMC|GNRMC', line):
                    if (FLAG_DBG > 0): print('dbg> line:', line)
                    gprmcRaw = line
                    break
    
    return gprmcRaw

def ProtoNEMA0183DegreeConvert(degreeRaw, isSW):
    vi = int(float(degreeRaw) / 100)
    val = vi + ((float(degreeRaw) - vi * 100) / 60)
    
    if (isSW == 'S') or (isSW == 'W'):
        val = 0 - val
    
    return val

#return "A,39.0005,119.0005,0,0"
def ProtoNEMA0183ParseRecord(gprmc_raw):
    if (FLAG_DBG > 0): print('dbg> $G*RMC:', gprmc_raw) # $GPRMC or $GNRMC
    try:
        gprmcList = gprmc_raw.split(',')
        if gprmcList and len(gprmcList) >= 9:
            gpsFlag     = 'A' if re.search('A', gprmcList[2]) \
                            else 'V'
            
            gpsLat      = ProtoNEMA0183DegreeConvert(gprmcList[3], gprmcList[4]) \
                            if (gprmcList[3] != '' and (gprmcList[4] != '')) \
                            else 0
            gpsLng      = ProtoNEMA0183DegreeConvert(gprmcList[5], gprmcList[6]) \
                            if (gprmcList[6] != '' and (gprmcList[6] != '')) \
                            else 0
            # knots to km/h
            gpsSpeed    = (float(gprmcList[7]) * 1.852) if (gprmcList[8] != '') \
                            else 0
            gpsHdg      = float(gprmcList[8]) if (gprmcList[8] != '') \
                            else 0
            
            gpsLatlng = '%s,%.8f,%.8f,%.2f,%.1f' \
                        % (gpsFlag, gpsLat, gpsLng, gpsSpeed, gpsHdg)
                        
            return gpsLatlng

    except:    
        return 'V,,,,'

# GPS sync
def GPSSensorSyncLatlng(serialFd, gpsFile):
    outFile = GPS_SENSOR # default gps file
    if gpsFile:
        outFile = gpsFile
        
    if serialFd:
        print("-> reading GPS location from", serialFd.name, ">", outFile)
        while FLAG_RUN > 0:
            data = spRead(serialFd)
            if data:
                gprmc_raw = ProtoNEMA0183FindGPRMC(data)
                data = ProtoNEMA0183ParseRecord(gprmc_raw)
                GPSLatlngSave(outFile, data)
                time.sleep(0.9)
    else:
        print("error> invalid GPS sensor > ", serialFd)
        appHelp()

# save parsed data+ts to file
def GPSLatlngSave(gpsFile, data):
    if gpsFile and data:
        ts = time.strftime("%Y-%m-%d %H:%M:%S")
        print('==> GCJ-02:', data)
        
        fd = open(gpsFile, 'w')
        if fd:
            fd.write(data + ',' + ts)
            fd.flush()
            print('---- saved at', ts)
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
def GPSRecorder():
    appVersion()
    
    print('> reading input ...')
    gpsCom, gpsFile = cliParams()
    
    serialFd = None
    if gpsCom:
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
                if serialFd:
                    break
    
    if serialFd:
        print('> read & save GPS location ...')
        GPSSensorSyncLatlng(serialFd, gpsFile)
    else:
        print('error> NO GPS Sensor valid!')
        appHelp()


# start GPS Recorder
GPSRecorder()
