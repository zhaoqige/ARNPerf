#!/usr/bin/python3
"""
Re-write "perf_win.pl" to "Perf.py"
by Qige <qigezhao@gmail.com>
v7.0 2017.10.10-2017.10.12  Basic ARNPerf function: GPS + Query + GPSFence
v7.1 2017.10.13             Collecting 3x ifname throughput (eth0, br-lan, wlan0); unknown gps lat/lng
v7.1.1 2017.10.17           Handle no "gps.txt"

2017.10.17 final re-format
"""

import re
import os
import sys
import time

import paramiko

FLAG_RUN = 1
FLAG_DBG = 0

# pre define
GPS_SENSOR      = 'gps.txt'
PERF_CONF       = 'ARNPerf.conf'

KPI_CACHE       = '/tmp/.perf.wls'
KPI_IFNAME      = 'wlan0'
THRPT_CACHE     = '/tmp/.perf.thrpt'
THRPT_IFNAME    = 'eth0'

THRPT_IFNAME1   = 'br-lan' # v7.1
THRPT_IFNAME2   = 'wlan0'  # v7.1

# WMAC, SSID, BSSID, Signal, Noise, Bitrate
CMD_KPI_FMT = 'ifconfig %s | grep %s -A0 | awk \'{print $5}\'; ' + \
'iwinfo %s i | tr -s "\n" "|" > %s; ' + \
'cat %s | cut -d "|" -f 1 | awk \'{print $3}\'; ' + \
'cat %s | cut -d "|" -f 2 | awk \'{print $3}\'; ' + \
'cat %s | cut -d "|" -f 5 | awk \'{print $2}\'; ' + \
'cat %s | cut -d "|" -f 5 | awk \'{print $4}\'; ' + \
'cat %s | cut -d "|" -f 5 | awk \'{print $5}\'; ' + \
'cat %s | cut -d "|" -f 6 | awk \'{print $3}\'; '
CMD_KPI = CMD_KPI_FMT % (KPI_IFNAME, KPI_IFNAME, KPI_IFNAME, KPI_CACHE, 
                         KPI_CACHE, KPI_CACHE, KPI_CACHE, KPI_CACHE, KPI_CACHE, KPI_CACHE)

CMD_THRPT_FMT = "cat /proc/net/dev | grep %s | awk '{print $2,$10}'; " + \
"cat /proc/net/dev | grep %s | awk '{print $2,$10}'; "+ \
"cat /proc/net/dev | grep %s | awk '{print $2,$10}'\n"
CMD_THRPT = CMD_THRPT_FMT % (THRPT_IFNAME, THRPT_IFNAME1, THRPT_IFNAME2)


# file read/write/close
def fileRead(conffile):
    try:
        fd = open(conffile, 'r')
        if fd:
            data = fd.readline()
            return data
        
        fd.close()
    
    except:
        return None

# application
def appVersion():
    print('ARNPerf v7.1 (https://github.com/zhaoqige/arnperf.git')
    print('---- by Qige <qigezhao@gmail.com> v7.0.101017-py ----')
    print('-----------------------------------------------------')

def appHelp():
    print('Usage: Perf.py [hostip [logfile [note [locations]]]] # with ARNPerf.conf')
    print('Usage: Perf.py hostip [logfile [note [locations]]]   # without ARNPerf.conf')


# priority: user cli assigned 
def appConfigLoad(host, logfile, note, location):
    print('-> loading config file ...')
    #return '192.168.1.24','d24fast.log','demo','BJOffice'
    noneArray = [ None, None, None, None, None, None, None ]
    rHost, rPort, rUser, rPasswd, rLogfile, rNote, rLocation = noneArray
    conf = fileRead(PERF_CONF)
    if conf:
        confList = conf.split(',')
        rHost, rPort, rUser, rPasswd = confList[0:4]
        rLogfile, rNote, rLocation = confList[4:7] # 0-6, but 7th not included
    
    # replace and decide right params
    if host:
        rHost = host
        
    if logfile:
        rLogfile = logfile
        
    if note:
        rNote = note
        
    if location:
        rLocation = location
    
    # default value with no ARNPerf.conf & no cli
    if (not rHost):
        rHost = '192.168.1.24'
    if (not rPort):
        rPort = 22
    if (not rUser):
        rUser = 'root'
    if (not rPasswd):
        rPasswd = 'root'
    if (not rLogfile):
        rLogfile = 'd24fast.log'
    if (not rNote):
        rNote = 'demo'
    if (not rLocation):
        rLocation = 'BJDev'
        
    return [ rHost, rPort, rUser, rPasswd, rLogfile, rNote, rLocation ]

def cliParams():
    print('-> reading user input ...')
    if len(sys.argv) >= 5:
        return sys.argv[1:5] # 1-4, but 5th not included

    if len(sys.argv) >= 4:
        return [ sys.argv[1:4], None ]

    if len(sys.argv) >= 3:
        return [ sys.argv[1:3], None, None ]

    if len(sys.argv) >= 2:
        return [ sys.argv[1], None, None, None ]
    
    return [ None, None, None, None ]


# Secure SHell
def SSHConnect(host, user, passwd, port):
    ssh = paramiko.SSHClient()
    try:
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy()) # any remote (~/.ssh/known_hosts)    
        ssh.connect(host, port = int(port), 
                    username = user, password = passwd, 
                    allow_agent=False, look_for_keys=False)
        
    except:
    #except paramiko.SSHException:
        ssh.close()
        ssh = None
        print('error> failed to connect', host, 
                '(please check your input: ip, port, user, password)')

    return ssh


def SSHExec(ssh, cmd):
    # FIXME: if error?
    reply = None
    try:
        #stdin, stdout, stderr = ssh.exec_command(cmd)
        _, stdout, _ = ssh.exec_command(cmd)
        reply = stdout.readlines()
        
    except:
        stdout = None
    
    return reply

def SSHClose(ssh):
    ssh.close()


def thrptFormat(val):
    return int(val) * 8

def thrptUnitMbps(bits):
    return "%.3f" % (bits / 1024 / 1024)

def thrptUnit(bits):
    if (bits > 1024 * 1024):
        return "%.3f Mbps" % (bits / 1024 / 1024)
    
    if (bits > 1024):
        return "%.3f Kbps" % (bits / 1024)
    
    if (bits < 1024):
        return "%.3f bps" % (bits)

# query & parse result
def ARNPerfQuery(ssh):
    kpi = None
    if (FLAG_DBG > 0):
        print('dbg> thrpt cmd: ', CMD_THRPT) # FIXME: DEBUG USE ONLY
    
    try:
        rxtxBytesReply = SSHExec(ssh, CMD_THRPT)
        rxtxBytes = []
        for Bps in rxtxBytesReply:
            rxtxBytesRaw = re.split(r'[,\s\n\r\\\n\\\r]', Bps \
                                      if Bps and len(Bps) >= 1 \
                                      else '0,0')
            rxtxBytes.extend(rxtxBytesRaw[0:2])
        
        if len(rxtxBytes) >= 6:
            eth = rxtxBytes[0:2]
            brlan = rxtxBytes[2:4]
            wls = rxtxBytes[4:6]
            kpi = [ int(eth[0])+int(brlan[0])+int(wls[0]), int(eth[1])+int(brlan[1])+int(wls[1]) ]
            
            if (FLAG_DBG > 0):
                print('dbg> rx/tx eth bytes:', eth[0], eth[1]) # FIXME: DEBUG USE ONLY
                print('dbg> rx/tx brlan bytes:', brlan[0], brlan[1]) # FIXME: DEBUG USE ONLY
                print('dbg> rx/tx wls bytes:', wls[0], wls[1]) # FIXME: DEBUG USE ONLY

        elif len(rxtxBytes) >= 4:
            eth = rxtxBytes[0:2]
            brlan = rxtxBytes[2:4]
            kpi = [ int(eth[0])+int(brlan[0]), int(eth[1])+int(brlan[1]) ]

            if (FLAG_DBG > 0):
                print('dbg> rx/tx eth bytes:', eth[0], eth[1]) # FIXME: DEBUG USE ONLY
                print('dbg> rx/tx brlan bytes:', brlan[0], brlan[1]) # FIXME: DEBUG USE ONLY
                
        elif len(rxtxBytes) >= 2:
            eth = rxtxBytes[0:2]
            kpi = [ int(eth[0]), int(eth[1]) ]

            if (FLAG_DBG > 0):
                print('dbg> rx/tx eth bytes:', eth[0], eth[1]) # FIXME: DEBUG USE ONLY
            
    except:
        print('error> Device Query FAILED')

    # re-check        
    if not kpi:
        kpi = [ 0, 0 ]
    
    try:
        #print(CMD_KPI)
        wlsRaw = ["00:00:00:00:00:00", "00:00:00:00:00:00", '-', 0, 0, 0]
        wlsRawReply = SSHExec(ssh, CMD_KPI)
        if wlsRawReply and len(wlsRawReply) >= 1:
            del wlsRaw[:]
            for val in wlsRawReply:
                wlsRaw.extend([ str(val).strip() ])
        
        if len(wlsRaw) >= 7:
            kpi.extend(wlsRaw[0:7])
    
    except:
        kpi.extend("00:00:00:00:00:00", "00:00:00:00:00:00", '-', 0, 0, 0)
    
    return kpi


def ARNPerfFormat(perfRaw, gpsCrt, msTsLast, thrptLast):
    msTsNow = time.time()
    msElapsed = round(abs(msTsNow - msTsLast), 3)
    
    if perfRaw and len(perfRaw) >= 9:
        wmac, ssid, bssid, signal, noise1, noise2, br = perfRaw[2:9]
        
        if (signal != 'unknown'):
            intNoise = int(noise2)
            intSignal = int(signal)
        else:
            intNoise = int(noise1)
            intSignal = intNoise

        snr = intSignal - intNoise
        
        # default 20MHz, not 8MHz
        br8m = 0.00
        if (br != 'unknown'):
            br8m = float(br)/20*8
    
    if perfRaw and len(perfRaw) >= 2:
        rxBytes, txBytes = perfRaw[0:2]
        intThrptLastRx = int(thrptLast[0])
        intThrptLastTx = int(thrptLast[1])
        if (intThrptLastRx + intThrptLastTx > 0):
            rxThrpt = (int(rxBytes) - int(thrptLast[0])) / msElapsed
            txThrpt = (int(txBytes) - int(thrptLast[1])) / msElapsed
        else:
            rxThrpt = 0
            txThrpt = 0
        
        fmtRxThrpt = thrptFormat(rxThrpt)
        fmtTxThrpt = thrptFormat(txThrpt)

    data = gpsCrt
    data.extend([ fmtRxThrpt, fmtTxThrpt ])
    data.extend([ wmac, ssid, bssid, intSignal, intNoise, snr, br8m, msElapsed ])
    return data

# display KPI
def ARNPerfPrint(arnData):
    if arnData and len(arnData) >= 16:
        gpsValid, gpsLat, gpsLng, gpsSpeed, gpsHdg, ts = arnData[0:6]
        rxThrpt, txThrpt = arnData[6:8]
        wmac, ssid, bssid, signal, noise, snr, br, msElapsed = arnData[8:16]
        
        # clear screen
        if (FLAG_DBG == 0):
            os.system("cls"); # FIXME: DEBUG USE ONLY

        print()
        print("                     ARNPerf CLI")
        print("        https://github.com/zhaoqige/arnperf.git")
        print(" -------- -------- -------- -------- -------- --------")        
        print("             MAC:", wmac if (wmac != '') else '00:00:00:00:00:00')
        print("            SSID:", ssid.strip('"') if (ssid != '') else '-')
        print("           BSSID:", bssid if (bssid != '') else '00:00:00:00:00:00')
        print("    Signal/Noise: %d/%d dBm, SNR = %d" % (signal, noise, snr))
        print("         Bitrate: %.3f Mbit/s" % (br));
        print()
        print("      Throughput: Rx = %s, Tx = %s" % (thrptUnit(rxThrpt), thrptUnit(txThrpt)))
        print()
        print(" ->", msElapsed, 'second(s) passed,', ts)
        
        if (gpsValid == 'A'):
            print(' -> GCJ-02: %.8f,%.8f, speed %.3f km/h, hdg %.1f' \
                  % (float(gpsLat), float(gpsLng), float(gpsSpeed), float(gpsHdg)))
        else:
            print(' -> ==== UNKNOWN GPS POSITION ====')


def ARNPerfLogEnvSave(confHost, confLogfile, confNote, confLocation):
    try:
        line = "+6w,config,%s,%s,%s" % (confHost, confNote, confLocation)
        fd = open(confLogfile, 'w')
        fd.write(line)
        fd.flush()
        
        print('-> save {LogEnv} to', confLogfile, ' <', confHost, confNote, confLocation)
        fd.close
        
    except:
        print('error> failed to save {LogEnv}')
    
def ARNPerfLogSave(logfile, arnData):
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    print(' ====> log saved at', ts, '-', logfile)
    try:
        if arnData and len(arnData) >= 15:
            gpsLat, gpsLng, gpsSpeed, gpsHdg = arnData[1:5]
            rxThrpt, txThrpt = arnData[6:8]
            #wmac, ssid, bssid, signal, noise, snr, br = arnData[8:15]
            _, _, bssid, signal, noise, _, _ = arnData[8:15]
            
            fd = open(logfile, 'a')
            if fd:
                # +6w,ts,wmac,lat,lng,signal,noise,rxthrpt,rxmcs,txthrpt,txmcs,speed,hdg
                record = "+6w,%s,%s,%.8f,%.8f,%d,%d,%s,%s,%s,%s,%.3f,%.1f\n" \
                            % (ts, bssid, float(gpsLat), float(gpsLng), int(signal), int(noise), \
                               thrptUnitMbps(rxThrpt), 'MCS -1', thrptUnitMbps(txThrpt), 'MCS -1', \
                               float(gpsSpeed), float(gpsHdg))
                fd.write(record)
                fd.flush()
            
            fd.close()
    except:
        print('error> save log failed at', ts, '-', logfile)


# read from exchange file
def GPSLocationRtRaw():
    gpsRaw = None
    gpsFile = GPS_SENSOR;
    
    try:
        fd = open(gpsFile, 'r')
        if (fd):
            gpsRawStr = fd.read(64)
            gpsRaw = str(gpsRawStr).split(',')
        
        fd.close()
        
    except:
        print('error> NO GPS Sensor connected')
        
    return gpsRaw

# return & validate GPS lat,lng
def GPSLocationRt():
    gpsRaw = GPSLocationRtRaw()
    if gpsRaw and len(gpsRaw) >= 6:
        gpsValid = gpsRaw[0]
        if (gpsValid == 'A'):
            return gpsRaw[:6]
        
    return [ 'V', 0, 0, 0, 0 ]

# GPS fence
def GPSFenceBreach(pos1, pos2):
    #gpsFenceDistance = 0.0002 # about 10 meters
    #gpsFenceDistance = 0.0001 # about 5 meters
    gpsFenceDistance = 0 # DEBUG USE ONLY!
    if (pos1 and pos2):
        p1lat, p1lng = pos1
        p2lat, p2lng = pos2
        
        gapLat = abs(float(p1lat) - float(p2lat))
        gapLng = abs(float(p1lng) - float(p2lng))
        if (gapLat + gapLng >= gpsFenceDistance):
            return 1
        
    return 0


"""
Tasks:
    1. Query GPS;
    2. Setup GPS Fence;
        2.1. Query Device Performance;
        2.2. Parse into ARNPerf7 format;
        2.3. Save to log.
"""
def ARNPerfRecord(ssh, configPerfArray):
    msTsLast = time.time()
    thrptLast = [0, 0]
    gpsLast = [0, 0]

    if len(configPerfArray) >= 4:
        confHost, confLogfile, confNote, confLocation = configPerfArray[0:4]
    else:
        confHost        = '192.168.1.24'
        confLogfile     = 'default.log'
        confNote        = 'demo'
        confLocation    = 'BJDevQZ'
    
    # save environment
    ARNPerfLogEnvSave(confHost, confLogfile, confNote, confLocation)
    
    # query device performance, setup GPS fence
    while FLAG_RUN > 0:
        perfRaw = ARNPerfQuery(ssh)
        gpsCrt = GPSLocationRt()
        arnData = ARNPerfFormat(perfRaw, gpsCrt, msTsLast, thrptLast)
        ARNPerfPrint(arnData)
        msTsLast = time.time()

        if (GPSFenceBreach(gpsCrt[1:3], gpsLast) > 0):
            ARNPerfLogSave(confLogfile, arnData)
        
        # save for next time
        gpsLast = gpsCrt[1:3]
        if perfRaw and len(perfRaw) >= 2:
            thrptLast = perfRaw[0:2]
        
        time.sleep(0.85)
    

"""
ARNPerf (GPS Fence triggered)
------------------
Usage: "Perf.py [hostip] [logfile] [note] [locations]"
------------------
by Qige <qigezhao@gmail.com>
2017.10.10-2017.10.11
"""
def ARNPerfRecorder():
    appVersion()
    
    print('> reading config (user input, config file) ...')
    host, logfile, note, location = cliParams()
    print('dbg>', host, logfile, note, location)
    configArray = appConfigLoad(host, logfile, note, location)
    print('dbg>', configArray)
    if len(configArray) >= 4:
        confHost, confPort, confUser, confPasswd = configArray[0:4]
        
    configPerfArray = None
    if len(configArray) >= 7:
        configPerfArray = [confHost]
        configPerfArray.extend(configArray[4:7])
    
    #confHost = '192.168.1.24' # DEBUG USE ONLY!
    connParam = '%s:%s@%s:%s' % (confUser, confPasswd, confHost, confPort)
    print('> connecting to', connParam, '...')
    ssh = SSHConnect(confHost, confUser, confPasswd, confPort)
    if ssh:
        ARNPerfRecord(ssh, configPerfArray)
        SSHClose(ssh)
    else:
        if confHost:
            print('error> Device [%s] unreachable!'% (confHost))
        else:
            print('error> Unknown device!')
        
        appHelp()


# start ARN Performance Recorder
ARNPerfRecorder()
