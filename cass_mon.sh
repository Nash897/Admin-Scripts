 #!/bin/bash

#author - Cass Team - Nahush,..

###############
# Script for Monitoring Cassandra
###############


  MON_PARAMS_FILE_PATH="/opt/monitoring_script/parms/mon_cass_params.sh"
  source ${MON_PARAMS_FILE_PATH}

  NODETOOL_INFO=""
  STATUS_TEMP+=("STATUS")
  DC_TEMP+=("DC")
  LOAD_TEMP+=("LOAD")
  HOST_NAME_TEMP+=("HOST")
  RACK_TEMP+=("RACK")
  HEAP_MEM_TEMP+=("HEAP MEM.")
  COMPACTIONS_TEMP+=("COMPACTIONS PENDING")
  KEYSPACE_TEMP+=("KEYSPACE")
  READCOUNT_TEMP+=("READ COUNT")
  READLATENCY_TEMP+=("READ LATENCY (in ms)")
  WRITECOUNT_TEMP+=("WRITE COUNT")
  WRITELATENCY_TEMP+=("WRITE LATENCY (in ms)")
  THREADPOOL_STATS_TEMP+=("THREADS BLOCKED")
  UPTIME_TEMP+=("UP TIME")
  DROPPED_MSG_STATS_TEMP+=("MESSAGES DROPPED")
  ARR_HOST_DC=()
  ARR_DC=()
  READS_WRITES_TODAY=""

  TEMP_CURR_READ_COUNT=0
  TEMP_CURR_WRITE_COUNT=0
#----------------------------------------------------------------------------
# Compress all old log files
#----------------------------------------------------------------------------

  if [ ! -f $Health_Report_log ]; then
    find $BASEDIR/ -type f -name "Cassandra_nodeinfo.*.log" -exec gzip {} \;
  fi

#----------------------------------------------------------------------------
# Functions
#----------------------------------------------------------------------------

  # DESC: Create the TEMP variables based on the order of the hosts given
  # DELIMITER: #
  function create_temp_vars () {
    INCR=0

    for HOST_WITH_NAME in ${HOST[@]}; do
      INCR=$(( ${INCR}+1 ))
      if [[ ${#INCR} -eq 1  ]]; then
        TEMP_INCR="0${INCR}"
      else
        TEMP_INCR=${INCR}
      fi

      STATUS_TEMP="${STATUS_TEMP}#${TEMP_INCR}z"
      DC_TEMP="${DC_TEMP}#${TEMP_INCR}z"
      LOAD_TEMP="${LOAD_TEMP}#${TEMP_INCR}z"
      HOST_NAME_TEMP="${HOST_NAME_TEMP}#${TEMP_INCR}z"
      RACK_TEMP="${RACK_TEMP}#${TEMP_INCR}z"
    done
  }

  # Returns the host name and order number as mentioned in the config file for the given ipaddress
  # PARAM 1: IPAddress
  # RETURN VALUE: Array with first item Hostname and second Order number
  function get_host_name_order_num () {
    IPADDR=${1}
    ORDERED_STATUS=0
    TEMP_ORDERED_STATUS="00"
    HOST_FULLNAME=""
    RESULT_ARR=()
    FOUND=0

    #Change the IPADDR to HOSTNAME
    for HOST_WITH_NAME in ${HOST[@]}; do
      # Get the order number of the host as configured in the config file
      ORDERED_STATUS=$(( ${ORDERED_STATUS}+1 ))
      if [[ ${#ORDERED_STATUS} -eq 1  ]]; then
        TEMP_ORDERED_STATUS="0${ORDERED_STATUS}"
      else
        TEMP_ORDERED_STATUS=${ORDERED_STATUS}
      fi

      # Get the hostname, given ipaddress
      if [[ "${HOST_WITH_NAME}" == "${IPADDR}"* ]]; then
        OLD_IFS_INNER=${IFS}
        IFS=' '
        HOST_NAME=(${HOST_WITH_NAME//#/ })
        HOST_FULLNAME=${HOST_NAME[1]}
        IFS=${OLD_IFS_INNER}
        FOUND=1
        break
      fi
    done

    if [[ ${FOUND} == 1 ]]; then
      RESULT_ARR+=(${HOST_FULLNAME})
      RESULT_ARR+=(${TEMP_ORDERED_STATUS})
    else
      RESULT_ARR=()
    fi
    
    echo ${RESULT_ARR[@]}
  }


  # DESC: Monitor faulty C* Nodes info
  # PARAM 1: Hostname
  function check_node_status () {
    HOSTIP=${1}

    OLD_IFS=$IFS
    IFS=$'\n'
    STATS="`nodetool -h ${HOSTIP} -u ${JMX_USERNAME} -pw ${JMX_PASSWORD} status | sed '$d'`"
    SKIP=0
    ORDERED_STATUS=0
    RESULT_ARR=()

    # Create the temporary variables
    create_temp_vars
 
    for NODE in ${STATS}; do
      if [[ ${SKIP} > 0  ]]; then
        let SKIP=SKIP-1
      elif [[ "${NODE}" = "Data"* ]]; then
        DC="`printf ${NODE} | awk {'printf $2'}`"
        SKIP=4;
      else
        IPADDR="`echo ${NODE} | awk {'printf $2'}`"

        # Get hostnam and ordered status number
        O_IFS=$IFS
        IFS=' '
        RESULT_ARR=($( get_host_name_order_num ${IPADDR} ))
        if [ ${#RESULT_ARR[@]} -gt 0 ]; then
          HOST_FULLNAME=${RESULT_ARR[0]}
          ORDERED_STATUS=${RESULT_ARR[1]}

          HOST_NAME_TEMP=${HOST_NAME_TEMP//"${ORDERED_STATUS}z"/"${HOST_FULLNAME}"}
          
          STATUS="`echo $NODE | awk {'printf $1'}`"
          STATUS_TEMP=${STATUS_TEMP//"${ORDERED_STATUS}z"/"${STATUS}"}

          LOAD="`echo $NODE | awk {'printf $3 $4'}`"
          LOAD_TEMP=${LOAD_TEMP//"${ORDERED_STATUS}z"/"${LOAD}"}

          RACK="`echo $NODE | awk {'printf $8'}`"
          RACK_TEMP=${RACK_TEMP//"${ORDERED_STATUS}z"/"${RACK}"}
          
          DC_TEMP=${DC_TEMP//"${ORDERED_STATUS}z"/"${DC}"}
  
          HOST_DC="${HOST_FULLNAME}#${DC}"
          ARR_HOST_DC+=(${HOST_DC})
          ARR_DC+=(${DC})
        fi
        IFS=${O_IFS}
      fi
    done

    #echo ${ARR_HOST_DC[*]}
    #echo ${HOST_NAME_TEMP}

    IFS=${OLD_IFS}
  }

  # DESC: Monitor blocked threads in C*
  # PARAM 1: Hostname
  function check_blocked_threadpool () {
    HOSTIP=${1}

    #STATS="`nodetool -u ${JMX_USERNAME} -pw ${JMX_PASSWORD} -h ${HOSTIP} tpstats | awk '$5>0' | sed -n '2,$p' | awk {'printf $1":" $5"\n"'}`" 
    STATS="`nodetool -u ${JMX_USERNAME} -pw ${JMX_PASSWORD} -h ${HOSTIP} tpstats | awk '{ if(NR>1 && NR<=22 && $5>0) {print $1,$5}}'`"
 
    if [[ $STATS = "" ]]; then
      THREADPOOL_STATS_TEMP="${THREADPOOL_STATS_TEMP}#0"
    else
      THREADPOOL_STATS_TEMP="${THREADPOOL_STATS_TEMP}#${STATS}"
    fi
  }

  # DESC: Monitor dropped messages in C*
  # PARAM 1: Hostname
  function check_dropped_messages () {
    HOSTIP=${1}

    #STATS="`nodetool -u ${JMX_USERNAME} -pw ${JMX_PASSWORD} -h ${HOSTIP} tpstats | awk '$5>0' | sed -n '2,$p' | awk {'printf $1":" $5"\n"'}`"
    STATS="`nodetool -u ${JMX_USERNAME} -pw ${JMX_PASSWORD} -h ${HOSTIP} tpstats | awk '{ if(NR>23 && $2>0) {print $1,$2}}'`"
    if [[ $STATS = "" ]]; then
      DROPPED_MSG_STATS_TEMP="${DROPPED_MSG_STATS_TEMP}#0"
    else
      DROPPED_MSG_STATS_TEMP="${DROPPED_MSG_STATS_TEMP}#${STATS}"
    fi
  }
 
  # DESC: Calculate HEAP memory of the node
  # PARAM 1: Nodetool info
  function heap_mem_stats () {
    PERCENTAGE=100
    HOSTIP=${1}

    HEAP_MEM="`nodetool -u ${JMX_USERNAME} -pw ${JMX_PASSWORD} -h ${HOSTIP} info  | grep 'Heap Memory' | sed -n '1p'`"

    HEAP_USED_MEM="`echo $HEAP_MEM | awk {'printf $5'}`"
    HEAP_TOT_MEM="`echo $HEAP_MEM | awk {'printf $7'}`"

    HEAP_USED_MEM=`printf "%.0f" $HEAP_USED_MEM`
    HEAP_TOT_MEM=`printf "%.0f" $HEAP_TOT_MEM`

    HEAP_MEM_UTIL=$(( ( HEAP_USED_MEM * PERCENTAGE ) / HEAP_TOT_MEM ))

    HEAP_MEM_UTIL=`echo $HEAP_MEM_UTIL | tr -s ""`
  
    HEAP_MEM_TEMP="${HEAP_MEM_TEMP}#${HEAP_MEM_UTIL}%"
  }

  # DESC: Monitor compaction stats
  # PARAM 1: Hostname
  function check_pending_compactions () {
    HOSTIP=${1}

    STATS="`nodetool -u ${JMX_USERNAME} -pw ${JMX_PASSWORD} -h ${HOSTIP} compactionstats`"
    NUMCOMPACTIONS="`echo $STATS | sed -n '1p' | awk {'print $3'}`"

      if [[ ${NUMCOMPACTIONS} = 0 ]]; then
        COMPACTIONS_TEMP="${COMPACTIONS_TEMP}#0"
      else
        COMPACTIONS_TEMP="${COMPACTIONS_TEMP}#${NUMCOMPACTIONS}"
      fi
  }

  #DESC: Get the DC Name
  #PARM 1: HOSTNAME
  function find_DC () {
    HOST_NAME=${1}

    O_IFS=$IFS
    IFS=' '
    for HOST_WITH_NAME in ${ARR_HOST_DC[@]}; do    
       HOST_DETAILS=(${HOST_WITH_NAME//#/ })
       
       if [[ "${HOST_DETAILS[0]}"  == "${HOST_NAME}" ]]; then
         DC_NAME=${HOST_DETAILS[1]}
         break;
       fi
    done
    IFS=${O_IFS}
 
    echo "${DC_NAME}"
  }

  # DESC: Calculates the number of reads and writes from day start till now and stores the same in params file
  # PARAM 1: Current read and write counts for the last hour
  function calc_daily_requests_count_till_now() {
    HOST_NAME=${1}
    CURR_HR_WRITES=${2}
    CURR_HR_READS=${3}

    source ${MON_PARAMS_FILE_PATH}

    # Get the DC Name
    DC_NAME=($( find_DC "${HOST_NAME}" ))
    DC_NAME=${DC_NAME//-/_}
    #DC_NAME=${DC_NAME//" " /_}

    # Get the reads and writes values till now today from config file
    READS_TILL_NOW_TODAY=$(eval "echo \${READS_TILL_NOW_TODAY_${DC_NAME}}")
    WRITES_TILL_NOW_TODAY=$(eval "echo \${WRITES_TILL_NOW_TODAY_${DC_NAME}}")

    # If the value of current reads is not available in the config file set it
    if [[ "${READS_TILL_NOW_TODAY}" = "" ]]; then
      echo "READS_TILL_NOW_TODAY_${DC_NAME}=0" >> ${MON_PARAMS_FILE_PATH}
      READS_TILL_NOW_TODAY="0"
    fi

    # If the value of current reads is not available in the config file set it
    if [[ "${WRITES_TILL_NOW_TODAY}" = "" ]]; then
      echo "WRITES_TILL_NOW_TODAY_${DC_NAME}=0" >> ${MON_PARAMS_FILE_PATH}
      WRITES_TILL_NOW_TODAY="0"
    fi

    WRITES_TILL_NOW_TODAY=$(( ${WRITES_TILL_NOW_TODAY}+${CURR_HR_WRITES} ))
    READS_TILL_NOW_TODAY=$(( ${READS_TILL_NOW_TODAY}+${CURR_HR_READS} ))

    sed -i "/^WRITES_TILL_NOW_TODAY_${DC_NAME}=/s/=.*/=${WRITES_TILL_NOW_TODAY}/" ${MON_PARAMS_FILE_PATH}
    sed -i "/^READS_TILL_NOW_TODAY_${DC_NAME}=/s/=.*/=${READS_TILL_NOW_TODAY}/" ${MON_PARAMS_FILE_PATH}

    #echo " ${HOST_NAME} ${READS_TILL_NOW_TODAY} ${WRITES_TILL_NOW_TODAY} ${CURR_HR_WRITES} ${CURR_HR_READS}"

  }

  # DESC: Get Keysapce name, Read Count, Read Latency, Write Count and Write Latency
  # PARAM 1: Write Count from last hour
  # PARAM 2: Read Count from last hour
  function check_cfstats () {
    HOSTIP=${1}
 
    CFSTATS="`nodetool -u ${JMX_USERNAME} -pw ${JMX_PASSWORD} -h ${HOSTIP} cfstats ${_KEYSPACE}  | head -5`"

    OLD_IFS=${IFS}
    IFS=$'\r\n'

    CFSTATS_VALUES=(${CFSTATS})

    KEYSPACE=`echo ${CFSTATS_VALUES[0]} | grep 'Keyspace' | awk {'print $2'} | xargs `
    READCOUNT_NEW=`echo ${CFSTATS_VALUES[1]} | grep 'Read Count' | awk {'print $3'} | xargs `
    READLATENCY=`echo ${CFSTATS_VALUES[2]} | grep 'Read Latency' | awk {'print $3'} | xargs `
    WRITECOUNT_NEW=`echo ${CFSTATS_VALUES[3]} | grep 'Write Count' | awk {'print $3'} | xargs `
    WRITELATENCY=`echo ${CFSTATS_VALUES[4]} | grep 'Write Latency' | awk {'print $3'} | xargs `
    #READLATENCY_UNIT=`echo ${CFSTATS_VALUES[2]} | grep 'Read Latency' | awk {'print $4'} | xargs `
    #WRITELATENCY_UNIT=`echo ${CFSTATS_VALUES[4]} | grep 'Write Latency' | awk {'print $4'} | xargs `
 
    # Get hostname and ordered status number
    O_IFS=$IFS
    IFS=' '
      RESULT_ARR=($( get_host_name_order_num ${HOSTIP} ))
      HOST_FULLNAME=${RESULT_ARR[0]}
    IFS=${O_IFS}

    # Get the current reads and writes values from config file
    CURR_READS=$(eval "echo \$CURR_READS_${HOST_FULLNAME}")
    CURR_WRITES=$(eval "echo \$CURR_WRITES_${HOST_FULLNAME}")

    # If the value of current reads is not available in the config file set it
    if [[ "${CURR_READS}" = "" ]]; then
      echo "CURR_READS_$HOST_FULLNAME=0" >> ${MON_PARAMS_FILE_PATH}
      CURR_READS=0
    fi

    # If the value of current reads is not available in the config file set it
    if [[ "${CURR_WRITES}" = "" ]]; then
      echo "CURR_WRITES_$HOST_FULLNAME=0" >> ${MON_PARAMS_FILE_PATH}
      #CURR_WRITES=$(eval "echo \$CURR_WRITES_${HOST_FULLNAME}")
      CURR_WRITES=0
    fi

    sed -i "/^CURR_READS_$HOST_FULLNAME=/s/=.*/=${READCOUNT_NEW}/" ${MON_PARAMS_FILE_PATH}
    sed -i "/^CURR_WRITES_$HOST_FULLNAME=/s/=.*/=${WRITECOUNT_NEW}/" ${MON_PARAMS_FILE_PATH}

    # Modify the following based on the values from the configuration file or as required
    READCOUNT=$(( ${READCOUNT_NEW}-${CURR_READS} ))
    READLATENCY=`printf %.2f ${READLATENCY}`
    WRITECOUNT=$(( ${WRITECOUNT_NEW}-${CURR_WRITES} ))
    WRITELATENCY=`printf %.2f ${WRITELATENCY}`
    
    if [ ${READCOUNT} -lt 0 ]; then
      READCOUNT=${READCOUNT_NEW}
    fi

    if [ ${WRITECOUNT} -lt 0 ]; then
      WRITECOUNT=${WRITECOUNT_NEW}
    fi

    calc_daily_requests_count_till_now "${HOST_FULLNAME}" "${WRITECOUNT}" "${READCOUNT}"

    KEYSPACE_TEMP="${KEYSPACE_TEMP}#${KEYSPACE}"
    READCOUNT_TEMP="${READCOUNT_TEMP}#${READCOUNT}"
    READLATENCY_TEMP="${READLATENCY_TEMP}#${READLATENCY}" #${READLATENCY_UNIT}"
    WRITECOUNT_TEMP="${WRITECOUNT_TEMP}#${WRITECOUNT}"
    WRITELATENCY_TEMP="${WRITELATENCY_TEMP}#${WRITELATENCY}" #${WRITELATENCY_UNIT}"
    IFS=${OLD_IFS}
  }

  #DESC: Write the data from parameters in table format to a file
  #PARAM 1: Array of values with delimiter
  #PARAM 2: Temp file to which the table row html formated value to be inserted
  #PARAM 3: Table row color
  #PARAM 4: Table column color
  function write_to_file_in_html () {
    FILE_TEMP=${2}
    TR_COLOR=${3}
    TD_COLOR=${4}  
 
    OLD_IFS=${IFS}
    IFS="#"
    TEMP_ARRAY=${1}
    FIRST_COLUMN=0

    echo "<tr bgcolor=\"${TR_COLOR}\">" >> "${FILE_TEMP}"
    for VALUE in ${TEMP_ARRAY}; do
      if [ ${FIRST_COLUMN} -gt 0 ] ; then
        # to convert value to upper case use ^^
        echo "<td>`echo \"${VALUE^^}\"`</td>" >> "${FILE_TEMP}"
      else
        echo "<td bgcolor=\"${TD_COLOR}\">`echo \"${VALUE}\"`</td>" >> "${FILE_TEMP}"
        FIRST_COLUMN=1
      fi
    done
    echo "</tr>" >> "${FILE_TEMP}"

    IFS=${OLD_IFS}
  }

  # DESC: generate HTML table
  # PARAM 1: HTML file to be generated
  # PARAM 2: HEADER CONTENT TO BE WRITTEN TO TABLE
  # PARAM 3: ARRAY OR VALUES TO BE WRITTEN IN TABLE, DELIMITER IS ","(COMMA)
  function generate_html_table () {
    TEMP_FILE=$1
    HEADER=$2
    CURR_VALUES=$3

    #touch "${TEMP_FILE}"

    if [[ ${CURR_VALUES} == ""  ]]; then
      CURR_VALUES="No DATA ,"
    fi

    write_to_file_in_html "${HEADER}" "${TEMP_FILE}" "GREEN" "TEAL"

    OLD_IFS=${IFS}
    IFS=','
    for VALUE in ${CURR_VALUES}; do
      VALUE=`echo ${VALUE} | xargs`
      if [[ ${VALUE} != "" ]]; then
        write_to_file_in_html "${VALUE}" "${TEMP_FILE}" "WHITE" "TEAL"
      fi
    done
    IFS=${OLD_IFS}
  }

  # DESC: Gets the uptime of the cassandra dse service
  # Param 1: HOST IP ADDRESS of the host for which the uptime should be measured
  function uptime_service_dse () {
    HOSTIP=${1}

    UPTIME_SECS="`nodetool -u ${JMX_USERNAME} -pw ${JMX_PASSWORD} -h ${HOSTIP} info  | grep 'Uptime' | sed -n '1p'`"

    UPTIME_SECS="`echo $UPTIME_SECS | awk {'printf $4'}`"

    UPTIME_TEMP="${UPTIME_TEMP}#$((${UPTIME_SECS}/86400))days $((${UPTIME_SECS}/3600%24)):$((${UPTIME_SECS}%3600/60)):$((${UPTIME_SECS}%60))hrs" 
  }

  # DESC: Checks if the node is working or not
  # PARAM 1: HOST IP ADDRESS of the host for which the connectivity should be checked
  function check_the_connectivity () {
    HOST_IP_ADDR=${1}

    nodetool -u ${JMX_USERNAME} -pw ${JMX_PASSWORD} -h ${HOST_IP_ADDR} info &> /dev/null

    if [ $? -eq 0 ]; then
      RES="TRUE"
    else
      RES="FALSE"
    fi

    echo ${RES}
  }

  # DESC: Checks the connectivity of the host and node status
  function nodestatus () {
    for HOST_WITH_NAME in ${HOST[@]}; do
      HOST_DETAILS=(${HOST_WITH_NAME//#/ })
      HOST_IP=${HOST_IN_CLUSTER}

      RESULT=($( check_the_connectivity "${HOST_IP}" ))

      # If successful conectivity then only collect info of the cluster from node
      if [[ "${RESULT}" = "TRUE"  ]]; then
        check_node_status ${HOST_DETAILS[0]}
        break
      fi
    done
  }

  # DESC: Gets the location of the current script
  # RETURN VALUE: Location of the script with the name 
  function get_script_location_msg () {
    RESULT_LOC=""
    if [[ "${SCRIPT_LOCATION}" != "" ]]; then
      RESULT_LOC="${SCRIPT_LOCATION}/mon_cass_fs.sh"
    else
      RESULT_LOC="`pwd`/mon_cass_fs.sh"
    fi
   
    echo "${RESULT_LOC}"
  }

  # DESC: Gets the reads and writes count for today
  function get_reads_writes_count_today () {
    O_IFS=$IFS

    source ${MON_PARAMS_FILE_PATH}

    IFS=' '

    UNIQUE_DCS=($(echo "${ARR_DC[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
 
    for DC_NAME in ${UNIQUE_DCS[@]}; do
      DC_NAME=${DC_NAME//-/_}
      #DC_NAME=${DC_NAME//" "/_}

      READS_TILL_NOW_TODAY=""
      WRITES_TILL_NOW_TODAY=""

      # Get the reads and writes values till now today from config file
      READS_TILL_NOW_TODAY=$(eval "echo \$READS_TILL_NOW_TODAY_${DC_NAME}")
      WRITES_TILL_NOW_TODAY=$(eval "echo \$WRITES_TILL_NOW_TODAY_${DC_NAME}")
    
      TEMP_VALUES="${DC_NAME}"
      
      if [[ ${READS_TILL_NOW_TODAY} != "" ]]; then
        TEMP_VALUES="${TEMP_VALUES}#${READS_TILL_NOW_TODAY}"
      fi      

      if [[ ${WRITES_TILL_NOW_TODAY} != "" ]]; then
        TEMP_VALUES="${TEMP_VALUES}#${WRITES_TILL_NOW_TODAY}"
      fi

      READS_WRITES_TODAY="${READS_WRITES_TODAY},${TEMP_VALUES}"
    done
    IFS=${O_IFS} 
  }

  #DESC: Reset the reads and write count for the past day
  function reset_today_read_write_count () {
    UNIQUE_DCS=($(echo "${ARR_DC[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    for DC_NAME in ${UNIQUE_DCS[@]}; do
      DC_NAME=${DC_NAME//-/_}
      TEMP_RESET="0"
      sed -i "/^WRITES_TILL_NOW_TODAY_${DC_NAME}=/s/=.*/=${TEMP_RESET}/" ${MON_PARAMS_FILE_PATH}
      sed -i "/^READS_TILL_NOW_TODAY_${DC_NAME}=/s/=.*/=${TEMP_RESET}/" ${MON_PARAMS_FILE_PATH}
    done
  }

  # DESC: Get the nodelist for the cluster
  # PARAMS: HOSTIP of the seeds
  # RETURN VALUE: Array of the nodes ip's in the cluster
  function getnodelist() {
    HOSTIP=${1}

    HOST_IP_TEMP=()
    HOST_NAME_TEMP=()

    # Get the node ips of the cluster
    HOST_IP_TEMP=(`nodetool -u ${JMX_USERNAME} -pw ${JMX_PASSWORD} -h ${HOSTIP} status |  sed '/[UD][NLJM]/!d ; s/..  \([0-9\.]*\) .*/\1/'`)

    # Get the node hostnames of the cluster
    HOST_NAME_TEMP=(`nodetool -u ${JMX_USERNAME} -pw ${JMX_PASSWORD} -h ${HOSTIP} status -r |  sed '/[UD][NLJM]/!d ; s/..  \([0-9 a-z\.]*\) .*/\1/' | awk '{printf $1 " "}'`)

    # Reset host arrays
    HOST=()

    for i in ${!HOST_IP_TEMP[@]}; do
      if [[ "${HOST_NAME_TEMP[i]}" =~ ^[0-9\.]*$  ]]; then
        HOST+=( ${HOST_IP_TEMP[i]}#${HOST_NAME_TEMP[i]//./_} )
      else
        HOST+=( ${HOST_IP_TEMP[i]}#$( cut -d '.' -f 1 <<< "${HOST_NAME_TEMP[i]}" ) )
      fi
    done

    echo ${HOST[@]}
  }

  # DESC: Convert the global values to array
  function convert_to_array () {
    
    OLIFS=${IFS}   
    IFS='#' 
      read -r -a HOST_NAME_TEMP <<< "$HOST_NAME_TEMP"
      read -r -a STATUS_TEMP <<< "$STATUS_TEMP"
      read -r -a DC_TEMP <<< "$DC_TEMP"
      read -r -a LOAD_TEMP <<< "$LOAD_TEMP"
      read -r -a RACK_TEMP <<< "$RACK_TEMP"
      read -r -a HEAP_MEM_TEMP <<< "$HEAP_MEM_TEMP"
      read -r -a COMPACTIONS_TEMP <<< "$COMPACTIONS_TEMP"
      read -r -a KEYSPACE_TEMP <<< "$KEYSPACE_TEMP"
      read -r -a READCOUNT_TEMP <<< "$READCOUNT_TEMP"
      read -r -a READLATENCY_TEMP <<< "$READLATENCY_TEMP"
      read -r -a WRITECOUNT_TEMP <<< "$WRITECOUNT_TEMP"
      read -r -a WRITELATENCY_TEMP <<< "$WRITELATENCY_TEMP"
      read -r -a THREADPOOL_STATS_TEMP <<< "$THREADPOOL_STATS_TEMP"
      read -r -a UPTIME_TEMP <<< "$UPTIME_TEMP"
      read -r -a DROPPED_MSG_STATS_TEMP <<< "$DROPPED_MSG_STATS_TEMP"
    IFS=${OLD_IFS}
  }

  # DESC: Covert the array values to html 
  function write_to_file_default () {
    FILE_TEMP=${1}
    TR_COLOR="WHITE"
    TD_COLOR="TEAL"

    for i in ${!HOST_NAME_TEMP[@]}; do
      if [[ ${i} -eq 0 ]]; then
        TR_COLOR="GREEN"
      else
        TR_COLOR="WHITE"
      fi

      echo "<tr bgcolor=\"${TR_COLOR}\">" >> "${FILE_TEMP}"
        echo "<td bgcolor=\"${TD_COLOR}\">`echo \"${HOST_NAME_TEMP[i]^^}\"`</td>" >> "${FILE_TEMP}"
        echo "<td><center>`echo \"${DC_TEMP[i]^^}\"`</center></td>" >> "${FILE_TEMP}"
        echo "<td><center>`echo \"${RACK_TEMP[i]^^}\"`</center></td>" >> "${FILE_TEMP}"
        echo "<td><center>`echo \"${LOAD_TEMP[i]^^}\"`</center></td>" >> "${FILE_TEMP}"
        echo "<td><center>`echo \"${STATUS_TEMP[i]^^}\"`</center></td>" >> "${FILE_TEMP}"
        echo "<td><center>`echo \"${HEAP_MEM_TEMP[i]^^}\"`</center></td>" >> "${FILE_TEMP}"
        echo "<td><center>`echo \"${READCOUNT_TEMP[i]^^}\"`</center></td>" >> "${FILE_TEMP}"
        echo "<td><center>`echo \"${READLATENCY_TEMP[i]^^}\"`</center></td>" >> "${FILE_TEMP}"
        echo "<td><center>`echo \"${WRITECOUNT_TEMP[i]^^}\"`</center></td>" >> "${FILE_TEMP}"
        echo "<td><center>`echo \"${WRITELATENCY_TEMP[i]^^}\"`</center></td>" >> "${FILE_TEMP}"
        echo "<td><center>`echo \"${UPTIME_TEMP[i]^^}\"`</center></td>" >> "${FILE_TEMP}"
        echo "<td><center>`echo \"${COMPACTIONS_TEMP[i]^^}\"`</center></td>" >> "${FILE_TEMP}"
        echo "<td><center>`echo \"${THREADPOOL_STATS_TEMP[i]^^}\"`</center></td>" >> "${FILE_TEMP}"
      echo "</tr>" >> "${FILE_TEMP}"
    done
  }

#######################################
# Collect Statistics 
#######################################
  #touch $Health_Report_log

  MSG_START="`date +'%a %D %T %Z'` - Begin of Cassandra Node Monitoring ."

  _TEMP_FILE="${SCRIPT_LOCATION}/.cassfs"
  touch ${_TEMP_FILE}
 
  _TEMP_FILE_RWCOUNT="${SCRIPT_LOCATION}/.rwvalues"
  touch ${_TEMP_FILE_RWCOUNT}

# Check if cassandra is running and monitor cassandra
  STATS="`netstat -plten | grep 7199`"
  if [[ $STATS != "" ]]; then
    
    # Get the node list 
    HOST=($( getnodelist "${HOST_IN_CLUSTER}" ))  

    # Get the status metrics for each node
    nodestatus

    if [[ -f "/tmp/monitor_cas_fs.log"  ]]; then
      touch "/tmp/monitor_cas_fs.log"
    fi

    if [[ "${CURR_HOUR}" == "01" ]]; then
      reset_today_read_write_count
    fi

    # Collect all the metrics
    for HOST_WITH_NAME in ${HOST[@]}; do
      HOST_DETAILS=(${HOST_WITH_NAME//#/ })

      HOST_FULLNAME=${HOST_DETAILS[1]}
      HOST_IP=${HOST_DETAILS[0]}

      RESULT=($( check_the_connectivity "${HOST_IP}" ))

      # If successful conectivity then only collect metrics
      if [[ "${RESULT}" = "TRUE"  ]]; then
        heap_mem_stats ${HOST_IP}
        check_pending_compactions ${HOST_IP}
        check_cfstats ${HOST_IP}
        check_blocked_threadpool ${HOST_IP}
        uptime_service_dse ${HOST_IP}
      else
        HEAP_MEM_TEMP="${HEAP_MEM_TEMP}#"
        COMPACTIONS_TEMP="${COMPACTIONS_TEMP}#"
        READCOUNT_TEMP="${READCOUNT_TEMP}#"
        READLATENCY_TEMP="${READLATENCY_TEMP}#"
        WRITECOUNT_TEMP="${WRITECOUNT_TEMP}#"
        WRITELATENCY_TEMP="${WRITELATENCY_TEMP}#"
        THREADPOOL_STATS_TEMP="${THREADPOOL_STATS_TEMP}#"
        UPTIME_TEMP="${UPTIME_TEMP}#"
      fi
    done
  fi

  convert_to_array
  write_to_file_default "${_TEMP_FILE}"

  # Get the read and writes count for today
  get_reads_writes_count_today
  generate_html_table "${_TEMP_FILE_RWCOUNT}" "DC#READS TODAY FROM 12:00 AM#WRITES TODAY FROM 12:00 AM" "${READS_WRITES_TODAY}"  

#  get_script_location_msg
  MSG_SCRIPT_LOC="Script located at $( get_script_location_msg )"

  MSG_END="`date +'%a %D %T %Z'` - End of Cassandra Node Monitoring ."

  MSG_HOST="Sent from `hostname`"

/usr/sbin/sendmail -t <<EOF
Content-type: text/html
TO: ${EMAIL_LIST}
FROM: cassandra
SUBJECT: ${MON_ENV} Cassandra Hourly Health Check - $(date)
<html>
  <body>
    <h4 style="font-family:calibri;">
      Hi, <br>
      Please find below ${MON_ENV} Cassandra Hourly Health Check Status<br>
      ${MSG_START}</br> </br>
      KEYSPACE: ${_KEYSPACE} </br>
    </h4>
    <table border="1" cellspacing="0" cellpadding="2" style="font-family:Calibri">
      $(cat ${_TEMP_FILE})
    </table>
    <br>
    <table border="1" cellspacing="0" cellpadding="2" style="font-family:Calibri">
      $(cat ${_TEMP_FILE_RWCOUNT})
    </table>
    <h4 style="font-family:calibri;">
      ${MSG_END}<br>
      ${MSG_HOST}</br>
      ${MSG_SCRIPT_LOC}</br>
      <br>
      Thank You,<br>
      Cassandra DBA Support.
    </h4>
  </body>
</html>
EOF

  rm -rf ${_TEMP_FILE}
  rm -rf ${_TEMP_FILE_RWCOUNT}
 
#----------------------------------------------------------------------------
# END OF SCRIPT
#----------------------------------------------------------------------------
  exit 0
