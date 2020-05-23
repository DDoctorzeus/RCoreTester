#!/bin/bash

#STATICVALS
REQBINARIES=('lscpu' 'grep' 'sed' 'taskset' 'stress');
SPACERSTR="\n------------------------------\n";
TESTTIMEPERCORE_SEC=60;

#Vals
CPUDETAILS=();
THREADSPERCORE=0;
CORESPERSOCKET=0;
NUMSOCKETS=0;
NUMTHREADS=0;
TIMEESTIMATE=0;
CPUFREQS=();
USERINPUT="";

#Test-specific Vals
STARTPOS=0;
ENDPOS=1;
COUNT_SOCKETS=0;
COUNT=0;



#Get Number of Actual Cores and sockets as well as work out a time estimate for the script to complete
CPUDETAILS=($(lscpu | grep -E 'Thread|socket|Socket' | sed 's/^.* //g'));
THREADSPERCORE=${CPUDETAILS[0]};
CORESPERSOCKET=${CPUDETAILS[1]};
NUMSOCKETS=${CPUDETAILS[2]};
NUMTHREADS=$(( ($CORESPERSOCKET*$NUMSOCKETS)*$THREADSPERCORE ));
TIMEESTIMATE=$(( $TESTTIMEPERCORE_SEC*($NUMSOCKETS*$CORESPERSOCKET) ));
TIMEESTIMATE_MINUTES=$(( $TIMEESTIMATE/60 )); #Yes I know its not precise due to truncation, its only an estimate..

echo "Found $NUMSOCKETS socket/s with $CORESPERSOCKET core/s per socket and $NUMTHREADS thread/s.";

#Announce some stuff and ask if ok to proceed
echo -e $SPACERSTR;
echo "Welcome to RCoreTester!";
echo "This script will now test each of your core/s boost clock capacity." \
    "Please note that if you do not have frequency boost/hyperthreading enabled (or indeed a cpu that can boost per-core) this script is rather pointless - so make sure it is enabled in bios.";
echo "Please also avoid running any additional stress tests while this script is running as it may cause strange results.";

echo -e "\nBased on the number of cores you have this script will take around $TIMEESTIMATE_MINUTES minutes to run.";
echo -e "Ok to proceed (y/n)?";
read USERINPUT;

if [ "$USERINPUT" != "y" ]; then
    exit 0;
fi

echo -e $SPACERSTR;
echo "Running test..";

COUNT_SOCKETS=0;

#Loop for each socket
while [ $COUNT_SOCKETS -lt $NUMSOCKETS ]; do

    #Work out start pos and end pos to test
    STARTPOS=$(( $COUNT_SOCKETS*($THREADSPERCORE) ));
    ENDPOS=$(( $STARTPOS+$CORESPERSOCKET ));

    #Loop Through this sockets cores
    COUNT=$STARTPOS;
    while [ $COUNT -lt $ENDPOS ]; do
        echo "Testing socket $COUNT_SOCKETS, core $COUNT";

        #Start detatched stresstest pinned to specific core/thread
        taskset -c $COUNT stress -c 1 -t $TESTTIMEPERCORE_SEC >/dev/null &

        #Monitor stress test and check core while still alive
        while [ "$(ps -A | grep stress)" != "" ]; do

            #Sleep 1 second
            sleep 1;
        done

        COUNT=$(( $COUNT+1 ));
    done

    COUNT_SOCKETS=$(( $COUNT_SOCKETS+1 ));
done

#cat /proc/cpuinfo | grep MHz | sed 's/^.*: //g'