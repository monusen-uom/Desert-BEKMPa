# UNWiS 2024: First day exercise: wind speed
#
#
# Stack of the nodes
#   +-------------------------+
#   |  7. UW/CBR              |
#   +-------------------------+
#   |  6. UW/UDP              |
#   +-------------------------+
#   |  5. UW/STATICROUTING    |
#   +-------------------------+
#   |  4. UW/IP               |
#   +-------------------------+
#   |  3. UW/MLL              |
#   +-------------------------+
#   |  2. UW/CSMA_ALOHA       |
#   +-------------------------+
#   |  1. UW/PHYSICAL         |
#   +-------------------------+
#           |         |    
#   +-------------------------+
#   |    UnderwaterChannel    |
#   +-------------------------+

# Comments:
# To highlight wind changes effects in the model, we need to use the
# UWPhysical physical layer module (not the UWBPSK as erroneously done).
# Note that also the computation of PDR was meaningless cause packets
# are sent broadcast. The number of received packets is a useful indicator though

######################################
# Flags to enable or disable options #
######################################
set opt(verbose) 		1
set opt(trace_files)		1
set opt(bash_parameters) 	1

#####################
# Library Loading   #
#####################
load libMiracle.so
load libMiracleBasicMovement.so
load libmphy.so
load libmmac.so
load libUwmStd.so
load libuwip.so
load libuwstaticrouting.so
load libuwmll.so
load libuwudp.so
load libuwcbr.so
load libuwcsmaaloha.so
load libuwinterference.so
load libuwphy_clmsgs.so
load libuwstats_utilities.so
load libuwphysical.so

#############################
# NS-Miracle initialization #
#############################
# You always need the following two lines to use the NS-Miracle simulator
set ns [new Simulator]
$ns use-Miracle

##################
# Tcl variables  #
##################
set opt(nn)                 4 ;# Number of Nodes
set opt(pktsize)            125  ;# Pkt sike in byte
set opt(starttime)          1	
set opt(stoptime)           7201
set opt(txduration)         [expr $opt(stoptime) - $opt(starttime)] ;# Duration of the simulation
set opt(txpower)            180.0  ;#Power transmitted in dB re uPa
set opt(maxinterval_)       20.0
set opt(freq)               25000.0 ;#Frequency used in Hz
set opt(bw)                 5000.0  ;#Bandwidth used in Hz
set opt(bitrate)            1800.0  ;#bitrate in bps
set opt(ack_mode)           "setNoAckMode"
set opt(cbr_period)         10
set opt(pktsize)	    125
set opt(propagation_speed)  1500
set opt(rngstream)	    1

if {$opt(bash_parameters)} {

        set opt(rngstream)      10
        set opt(sched_time)     10
        set opt(windspeed_new)  17
}

###########################
# Random number generator #
###########################
global defaultRNG
for {set k 0} {$k < $opt(rngstream)} {incr k} {
	$defaultRNG next-substream
}

##############
# Tracefiles #
##############
if {$opt(trace_files)} {
	set opt(tracefilename) "./ex_wind_speed.tr"
	set opt(tracefile) [open $opt(tracefilename) w]
	set opt(cltracefilename) "./ex_wind_speed.cltr"
	set opt(cltracefile) [open $opt(tracefilename) w]
} else {
	set opt(tracefilename) "/dev/null"
	set opt(tracefile) [open $opt(tracefilename) w]
	set opt(cltracefilename) "/dev/null"
	set opt(cltracefile) [open $opt(cltracefilename) w]
}

#########################
# Module Configuration  #
#########################
## Application
Module/UW/CBR set packetSize_          $opt(pktsize)
Module/UW/CBR set period_              $opt(cbr_period)
Module/UW/CBR set PoissonTraffic_      1
Module/UW/CBR set debug_               0

## Physical
Module/MPhy/BPSK  set TxPower_         $opt(txpower)
Module/UW/PHYSICAL  set BitRate_                    $opt(bitrate)
Module/UW/PHYSICAL  set AcquisitionThreshold_dB_    15.0 
Module/UW/PHYSICAL  set RxSnrPenalty_dB_            0
Module/UW/PHYSICAL  set TxSPLMargin_dB_             0
Module/UW/PHYSICAL  set MaxTxSPL_dB_                $opt(txpower)
Module/UW/PHYSICAL  set MinTxSPL_dB_                10
Module/UW/PHYSICAL  set MaxTxRange_                 200
Module/UW/PHYSICAL  set PER_target_                 0    
Module/UW/PHYSICAL  set CentralFreqOptimization_    0
Module/UW/PHYSICAL  set BandwidthOptimization_      0
Module/UW/PHYSICAL  set SPLOptimization_            0
Module/UW/PHYSICAL  set debug_                      0

set data_mask [new MSpectralMask/Rect]
$data_mask setFreq              $opt(freq)
$data_mask setBandwidth         $opt(bw)
$data_mask setPropagationSpeed  $opt(propagation_speed)

## Channel
MPropagation/Underwater set practicalSpreading_ 2
MPropagation/Underwater set debug_              0
MPropagation/Underwater set windspeed_          10 ; #m/s
MPropagation/Underwater set shipping_           0

set channel [new Module/UnderwaterChannel]
set propagation [new MPropagation/Underwater]

################################
# Procedure(s) to create nodes #
################################
proc createNode { id } {

    global channel propagation data_mask ns cbr position node udp portnum ipr ipif channel_estimator
    global phy posdb opt rvposx rvposy rvposz mhrouting mll mac woss_utilities woss_creator db_manager
    global node_coordinates
    
    set node($id) [$ns create-M_Node $opt(tracefile) $opt(cltracefile)] 
    for {set cnt 0} {$cnt < $opt(nn)} {incr cnt} {
        set cbr($id,$cnt)  [new Module/UW/CBR] 
        set udp($id,$cnt)  [new Module/UW/UDP]
    }
    set ipr($id)  [new Module/UW/StaticRouting]
    set ipif($id) [new Module/UW/IP]
    set mll($id)  [new Module/UW/MLL] 
    set mac($id)  [new Module/UW/CSMA_ALOHA] 
    # set phy($id)  [new Module/MPhy/BPSK]
    set phy($id)  [new Module/UW/PHYSICAL]
	
    for {set cnt 0} {$cnt < $opt(nn)} {incr cnt} {
        $node($id) addModule 7 $cbr($id,$cnt)   1  "CBR"
        $node($id) addModule 6 $udp($id,$cnt)   1  "UDP"
    }
    $node($id) addModule 5 $ipr($id)   1  "IPR"
    $node($id) addModule 4 $ipif($id)  1  "IPF"   
    $node($id) addModule 3 $mll($id)   1  "MLL"
    $node($id) addModule 2 $mac($id)   1  "MAC"
    $node($id) addModule 1 $phy($id)   1  "PHY"

    for {set cnt 0} {$cnt < $opt(nn)} {incr cnt} {
        $node($id) setConnection $cbr($id,$cnt)   $udp($id,$cnt)   0
        $node($id) setConnection $udp($id,$cnt)   $ipr($id)   0
        set portnum($id,$cnt) [$udp($id,$cnt) assignPort $cbr($id,$cnt) ]
    }
    $node($id) setConnection $ipr($id)   $ipif($id)  1
    $node($id) setConnection $ipif($id)  $mll($id)   1
    $node($id) setConnection $mll($id)   $mac($id)   1
    $node($id) setConnection $mac($id)   $phy($id)   1
    $node($id) addToChannel  $channel    $phy($id)   1

    if {$id > 254} {
        puts "hostnum > 254!!! exiting"
        exit
    }
    #Set the IP address of the node
    set ip_value [expr $id + 1]
    $ipif($id) addr $ip_value
    
    set position($id) [new "Position/BM"]
    $node($id) addPosition $position($id)
    set posdb($id) [new "PlugIn/PositionDB"]
    $node($id) addPlugin $posdb($id) 20 "PDB"
    $posdb($id) addpos [$ipif($id) addr] $position($id)
    
    #Setup positions
    $position($id) setX_ [expr $id*200]
    $position($id) setY_ [expr $id*200]
    $position($id) setZ_ -100
    
    #Interference model
    set interf_data($id) [new "Module/UW/INTERFERENCE"]
    $interf_data($id) set maxinterval_ $opt(maxinterval_)
    $interf_data($id) set debug_       0

    #Propagation model
    $phy($id) setPropagation $propagation
    
    $phy($id) setSpectralMask $data_mask
    $phy($id) setInterference $interf_data($id)
    $mac($id) $opt(ack_mode)
    $mac($id) initialize
}

#################
# Node Creation #
#################
# Create here all the nodes you want to network together
for {set id 0} {$id < $opt(nn)} {incr id}  {
    createNode $id
}

################################
# Inter-node module connection #
################################
proc connectNodes {id1 des1} {
    global ipif ipr portnum cbr cbr_sink ipif_sink ipr_sink opt 

    $cbr($id1,$des1) set destAddr_ [$ipif($des1) addr]
    $cbr($id1,$des1) set destPort_ $portnum($des1,$id1)

    $cbr($des1,$id1) set destAddr_ [$ipif($id1) addr]
    $cbr($des1,$id1) set destPort_ $portnum($id1,$des1) 

}

##################
# Setup flows    #
##################
for {set id1 0} {$id1 < $opt(nn)} {incr id1}  {
    for {set id2 0} {$id2 < $opt(nn)} {incr id2}  {
        connectNodes $id1 $id2
    }
}

##################
# ARP tables     #
##################
for {set id1 0} {$id1 < $opt(nn)} {incr id1}  {
    for {set id2 0} {$id2 < $opt(nn)} {incr id2}  {
        $mll($id1) addentry [$ipif($id2) addr] [$mac($id2) addr]
    }
}

##################
# Routing tables #
##################
for {set id1 0} {$id1 < $opt(nn)} {incr id1}  {
    for {set id2 0} {$id2 < $opt(nn)} {incr id2}  {
        $ipr($id1) addRoute [$ipif($id2) addr] [$ipif($id2) addr]
    }
}

#####################
# Start/Stop Timers #
#####################
# Set here the timers to start and/or stop modules (optional)
# e.g., 
for {set id1 0} {$id1 < $opt(nn)} {incr id1}  {
    for {set id2 0} {$id2 < $opt(nn)} {incr id2} {
        if {$id1 != $id2} {
            $ns at $opt(starttime)    "$cbr($id1,$id2) start"
            $ns at $opt(stoptime)     "$cbr($id1,$id2) stop"
        }
    }
}


###################
# Final Procedure #
###################
# Define here the procedure to call at the end of the simulation
proc finish {} {
    global ns opt outfile
    global mac propagation cbr_sink mac_sink phy_data phy_data_sink channel db_manager propagation
    global node_coordinates
    global ipr_sink ipr ipif udp cbr phy phy_data_sink
    global node_stats tmp_node_stats sink_stats tmp_sink_stats

    if ($opt(verbose)) {
        puts "----------------------------------------------"
        puts "Simulation summary"
        puts "number of nodes   : $opt(nn)"
        puts "packet size       : $opt(pktsize) byte"
        puts "cbr period        : $opt(cbr_period) s"
        puts "simulation length : $opt(txduration) s"
        puts "tx power          : $opt(txpower) dB"
        puts "tx frequency      : $opt(freq) Hz"
        puts "tx bandwidth      : $opt(bw) Hz"
        puts "bitrate           : $opt(bitrate) bps"
        puts "----------------------------------------------"
    }

    set sum_cbr_throughput     0
    set sum_per                0
    set sum_cbr_sent_pkts      0.0
    set sum_cbr_rcv_pkts       0.0    

    for {set i 0} {$i < $opt(nn)} {incr i}  {
        for {set j 0} {$j < $opt(nn)} {incr j} {
            if {$i != $j} {
                set cbr_throughput [$cbr($i,$j) getthr]
                set cbr_sent_pkts  [$cbr($i,$j) getsentpkts]
                set cbr_rcv_pkts   [$cbr($i,$j) getrecvpkts]
                if ($opt(verbose)) {
                    puts "cbr($i,$j) throughput      : $cbr_throughput"
                }
            }
        }
        set sum_cbr_throughput [expr $sum_cbr_throughput + $cbr_throughput]
        set sum_cbr_sent_pkts [expr $sum_cbr_sent_pkts + $cbr_sent_pkts]
        set sum_cbr_rcv_pkts  [expr $sum_cbr_rcv_pkts + $cbr_rcv_pkts]
    }
    
    set ipheadersize        [$ipif(1) getipheadersize]
    set udpheadersize       [$udp(1,0) getudpheadersize]
    set cbrheadersize       [$cbr(1,0) getcbrheadersize]
    
    if ($opt(verbose)) {
        puts "----------------------------------------------"
        puts "IP Pkt Header Size       : $ipheadersize"
        puts "UDP Header Size          : $udpheadersize"
        puts "CBR Header Size          : $cbrheadersize"
        puts "Mean Throughput          : [expr ($sum_cbr_throughput/(($opt(nn))*($opt(nn)-1)))]"
        puts "Sent Packets             : $sum_cbr_sent_pkts"
        puts "Received Packets         : $sum_cbr_rcv_pkts"
        puts "...done!"
    }
    
    $ns flush-trace
    close $opt(tracefile)
}

###################
# start simulation
###################
if ($opt(verbose)) {
    puts "\nStarting Simulation\n"
}

###############################
# Schedule wind speed changes #
###############################
if {$opt(bash_parameters)} {
    $ns at $opt(sched_time) "$propagation set windspeed_ $opt(windspeed_new)"
}


$ns at [expr $opt(stoptime) + 120.0]  "finish; $ns halt" 

$ns run