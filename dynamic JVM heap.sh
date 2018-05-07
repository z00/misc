
#!/bin/bash

LOGFILE="/TivoData/Log/run-java.log"

echolog()
(
echo $1
echo $1 >> $LOGFILE
)

echolog "environment name is $ENVIRONMENT_NAME"

declare -A MYMAP



MYMAP["production"]="SHARED"
MYMAP["staging"]="SHARED"
MYMAP["usqe3"]="NOT_SHARED"
#MYMAP["usqe1"]="SHARED" --> having llc as well as non llc containers hence setting them to default
#MYMAP["usqe2"]="SHARED"
#MYMAP["ono_qe1"]="SHARED"
#MYMAP["bclab1"]="SHARED" --> commented intentionally to ensure default jvm settings are given to dev environments

shared_less_ram_percent=50
non_shared_less_ram_percent=50

shared_more_ram_percent=65
non_shared_more_ram_percent=50





hostMBTotal=""
hostKBTotal=$(cat /proc/meminfo | grep MemTotal | egrep -o "[0-9]{7,}")
if [[ -z ${hostKBTotal} ]]; then
    echolog "Couldn't get the memory of this instance. Using the java defaults"
else
    # convert to MB
    hostMBTotal=$(( $hostKBTotal / 1024 ))
    echolog "This host has ${hostMBTotal} MB of total RAM"
fi


mx=""

if [[ ! -z ${hostMBTotal} ]]; then
    # using our algorithm based on total instance RAM of ${hostMBTotal} MB"
    if [[ ${hostMBTotal} -le 4096 ]]; then
        echolog "less than 4gb ram"
        echolog "env is ${ENVIRONMENT_NAME}"
        
        if [[ -z ${MYMAP[${ENVIRONMENT_NAME}]} ]]; then
            echolog "in default mode using default jvm settings"

        elif [[ "${MYMAP[${ENVIRONMENT_NAME}]}" = "SHARED" ]]; then
            #sharing mode with less than 4gb ram
            echolog "in shared mode"
            mx="$(( ${hostMBTotal} * ${shared_less_ram_percent} / 100 ))"
        else
            #non sharing mode with less than 4gb ram 
            echolog "in non shared mode"
             mx="$(( ${hostMBTotal} * ${non_shared_less_ram_percent} / 100 ))"
        fi
    else
        echolog "inside else block means greater than 4gb ram"

        if [[ -z ${MYMAP[${ENVIRONMENT_NAME}]} ]]; then
            echolog "in default mode using default jvm settings"
        
        elif [[ "${MYMAP[${ENVIRONMENT_NAME}]}" = "SHARED" ]]; then
            #sharing mode with greater than 4gb ram
            mx="$(( ${hostMBTotal} * ${shared_more_ram_percent} / 100 ))"
        else
            #non sharing mode with greater than 4gb ram
            echolog "not shared env"
            mx="$(( ${hostMBTotal} * ${non_shared_more_ram_percent} / 100 ))"
            echolog ${mx}
        fi
    fi
else
    echolog "Using java defaults for heap size by not passing in -mx"
fi

if [[ ! -z ${mx} ]]; then
    JAVA_OPTS="-Xms${mx}m -Xmx${mx}m -XX:+UseParallelGC  -XX:NewRatio=2"
    echolog "Using JAVA_OPTS: \"${JAVA_OPTS}\""
    JAVA_OPTS="$JAVA_OPTS"
    exec java $JAVA_OPTS -jar /TivoData/livelogcooker-kstream.jar
else
    echolog "Not specifying JAVA_OPTS explicitly"
    JAVA_OPTS="-Xms64m -Xmx1024m"
    exec java -jar /TivoData/livelogcooker-kstream.jar
fi

