#!/bin/bash

#STATICVALS
REQBINS=('lscpu' 'grep' 'sed' 'taskset' 'stress' 'bc');
SPACERSTR="\n------------------------------\n";
HELPSTR="
    Usage: ./command args
	none: Operate in default test mode.
    --help: Show this dialog.
    -s: Silent mode - do not show intro, ask to start test and only output results.
    -vc: Virtual Core Mode - Output all results as their virtual core/thread value on the system.
    -csv: CSV Mode - Output final results on one line seperated by commas.
";
TESTTIMEPERCORE_SEC=60;

#Arg Vals
SILENTMODE=0;
VIRTCOREMODE=0;
CSVMODE=0;

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
CORES_FREQS=();
CORE_FREQS=();
CORE_CURRENTFREQ=0;
CORE_MAXFREQ=0;
CORE_AVERAGEFREQ=0;
FINAL_RESULTSPOS=();
FINAL_AVERAGEFREQS=();
FINAL_HIGHESTFREQS=();
FINAL_RESULTSSTR="";
TEMPVAL="";

#Check all required binaries are present
for bin in "${REQBINS[@]}"; do
	if ! hash $bin 2>/dev/null; then
		echo "Missing required executable $bin! Please ensure the application is installed before running this script.";
		exit 1;
	fi
done

#Loop Through Arguments
for arg in "${@}"; do

    case $arg in
        "-s")
            SILENTMODE=1;;
        "-vc")
            VIRTCOREMODE=1;;
        "-csv")
            CSVMODE=1;;
        "--help")
            echo -e "$HELPSTR";
            exit 0;;
        *)
            echo -e "Unknown Argument: $arg.";
            echo -e "$HELPSTR";
            exit 1;;
    esac

done

#Get Number of Actual Cores and sockets as well as work out a time estimate for the script to complete
CPUDETAILS=($(lscpu | grep -E 'Thread|socket|Socket' | sed 's/^.* //g'));
THREADSPERCORE=${CPUDETAILS[0]};
CORESPERSOCKET=${CPUDETAILS[1]};
NUMSOCKETS=${CPUDETAILS[2]};
NUMTHREADS=$(( ($CORESPERSOCKET*$NUMSOCKETS)*$THREADSPERCORE ));
TIMEESTIMATE=$(( $TESTTIMEPERCORE_SEC*($NUMSOCKETS*$CORESPERSOCKET) ));
TIMEESTIMATE_MINUTES=$(( $TIMEESTIMATE/60 )); #Yes I know its not precise due to truncation, its only an estimate..


#If silent mode running skip intro+confirm
if [ "$SILENTMODE" -ne 1 ]; then
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
fi

COUNT_SOCKETS=0;

#Loop for each socket
while [ $COUNT_SOCKETS -lt $NUMSOCKETS ]; do

    #Work out start pos and end pos to test
    STARTPOS=$(( COUNT_SOCKETS*CORESPERSOCKET*THREADSPERCORE ));
    ENDPOS=$(( STARTPOS+CORESPERSOCKET ));

    #Loop Through this sockets cores
    COUNT=$STARTPOS;
    while [ $COUNT -lt $ENDPOS ]; do
        if [ "$SILENTMODE" -ne 1 ]; then
            echo "Testing socket $COUNT_SOCKETS, core $((COUNT-STARTPOS))";
        fi

        #Reset corefreq array and maxFreq
        unset CORE_FREQS;
        CORE_FREQS=();
        CORE_MAXFREQ="0";

        #Start detatched stresstest pinned to specific core/thread
        taskset -c $COUNT stress -c 1 -t $TESTTIMEPERCORE_SEC >/dev/null &

        #Monitor stress test and check core while still alive
        while [ "$(ps -A | grep stress)" != "" ]; do

            #Get core freqs
            CORES_FREQS=($(cat /proc/cpuinfo | grep MHz | sed 's/^.*: //g'));

            #Get current core frequency
            CORE_CURRENTFREQ=${CORES_FREQS[$COUNT]};
            CORE_FREQS+=($CORE_CURRENTFREQ);

            #Check largest
            if (( $(echo "$CORE_CURRENTFREQ > $CORE_MAXFREQ" | bc -l) )); then
                CORE_MAXFREQ="$CORE_CURRENTFREQ";
            fi

            #Sleep 1 second
            sleep 1;
        done

        #Calculate average core frequency
        CORE_AVERAGEFREQ=$(echo "${CORE_FREQS[@]}" | sed 's/ /+/g' | bc);
        CORE_AVERAGEFREQ=$(echo "$CORE_AVERAGEFREQ/${#CORE_FREQS[@]}" | bc);

        #If virtual core mode add virtual core, otherwise socket:core
        if [ "$VIRTCOREMODE" -eq 1 ]; then
            FINAL_RESULTSPOS+=("$COUNT");
        else
            FINAL_RESULTSPOS+=("$COUNT_SOCKETS:$((COUNT-STARTPOS))");
        fi

        #Add to results array
        FINAL_AVERAGEFREQS+=($CORE_AVERAGEFREQ);
        FINAL_HIGHESTFREQS+=($CORE_MAXFREQ);

        COUNT=$(( $COUNT+1 ));
    done

    COUNT_SOCKETS=$(( $COUNT_SOCKETS+1 ));
done

#Bubble Sort (very inefficent so may change later)
ENDPOS=${#FINAL_AVERAGEFREQS[@]};
ENDPOS=$((ENDPOS-1));
for ((i=0; i<ENDPOS; i++)); do
    for ((j=0; j<ENDPOS; j++)); do
        if (( $(echo "${FINAL_AVERAGEFREQS[$((j+1))]} > ${FINAL_AVERAGEFREQS[$j]}" | bc -l) )); then

            #Average Freqs:
            TEMPVAL="${FINAL_AVERAGEFREQS[$((j+1))]}";
            FINAL_AVERAGEFREQS[$((j+1))]="${FINAL_AVERAGEFREQS[$j]}";
            FINAL_AVERAGEFREQS[$j]="$TEMPVAL";

            #Result Pos
            TEMPVAL="${FINAL_RESULTSPOS[$((j+1))]}";
            FINAL_RESULTSPOS[$((j+1))]="${FINAL_RESULTSPOS[$j]}";
            FINAL_RESULTSPOS[$j]="$TEMPVAL";
        fi
    done
done

#If csv mode set output as csv, otherwise 
if [ "$CSVMODE" -eq 1 ]; then
    FINAL_RESULTSSTR=$(echo "${FINAL_RESULTSPOS[@]}" | sed 's/ /,/g');
else
    FINAL_RESULTSSTR="Best cores in order (Socket:Core): ${FINAL_RESULTSPOS[@]}";
fi

#If not silent mode output more details
if [ "$SILENTMODE" -ne 1 ]; then
    echo -e "\nFinal Results (Socket:Core): ";
    COUNT=0;
    ENDPOS="${#FINAL_AVERAGEFREQS[@]}";
    while [ $COUNT -lt $ENDPOS ]; do

        echo "${FINAL_RESULTSPOS[$COUNT]} - High of ${FINAL_HIGHESTFREQS[$COUNT]} Mhz, ${FINAL_AVERAGEFREQS[$COUNT]} Mhz average";

        COUNT=$(( $COUNT+1 ));
    done
fi

echo $FINAL_RESULTSSTR;
