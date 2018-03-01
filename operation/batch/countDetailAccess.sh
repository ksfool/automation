#!/bin/sh
# name   : countDetailAccess
# writer : Euncheol Kweon
# mail   : ksfool@gmail.com
# 
# history
# ex. [yyyy/mm/dd] added some function.
# 

current_date="$(date +%Y%m%d)"
target_access_log_file="spring.log"

default_date_durations="90"
default_encodingString="en_US.UTF-8"
default_duration_start="${current_date}"
default_duration_close="${current_date}"
default_logging_prefix="${target_access_log_file}."
default_logs_directory="/home/ubuntu/maca-web/logs"

###############################################################################################################################
# usage
###############################################################################################################################
# ${1} message
usage() {
exec 1>&2
if [ -n "${1}" ] ; then
    echo && echo "${1}"
fi
cat <<EOF

counting Detail ID access
Usage: $(basename ${0}) [-f] [-t] [-d] [-e]] [-h]
  -f                   : [optional] duration from (default:${default_duration_start})
  -t                   : [optional] duration to   (default:${default_duration_close})
  -d                   : [optional] log directory (default:${default_logs_directory})
  -e                   : [optional] encoding type (default:${default_encodingString})
  -s                   : [optional] save result   (default:Printing Only)
  -h                   : show this message.
  01. If duration is not defined, default is today.
  02. If log directory is not defined, default is "${default_logs_directory}".
  03. Maximum collect duration is ${default_date_durations}days.
  04. f option will save CSV file to ${HOME}/access_count_YYYYMMDD_YYYYMMDD_YYYYYMMDD_HHMMSS.csv.(access_count_\$from_\$to_\$exec_time.csv)

Operation: 
  01. Variation
      $(basename ${0})
      $(basename ${0}) -e ${default_encodingString}
      $(basename ${0}) -d ${default_logs_directory}
      $(basename ${0}) -f ${default_duration_start}
      $(basename ${0}) -f ${default_duration_start} -t ${default_duration_close}
      $(basename ${0}) -f ${default_duration_start} -t ${default_duration_close} -d ${default_logs_directory}
      $(basename ${0}) -f ${default_duration_start} -t ${default_duration_close} -d ${default_logs_directory} -s
EOF
}

###############################################################################################################################
# common
###############################################################################################################################

###############################################################################################################################
# local function
###############################################################################################################################

###############################################################################################################################
# main
###############################################################################################################################
# argument variable
csv_file_store=""

logs_directory="${default_logs_directory}"
duration_start="${default_duration_start}"
duration_close="${default_duration_close}"
encodingString="${default_encodingString}"

# arguments
while getopts f:t:d:e:sh OPT ; do
  case ${OPT} in
   "f")
          # duration start
          duration_start="${OPTARG}"
          ;;
   "t")
          # duration close
          duration_close="${OPTARG}"
          ;;
   "d")
          # root directory
          logs_directory="${OPTARG}"
          ;;
   "e")
          # root directory
          # 
          encodingString="${OPTARG}"
          ;;
   "s")
          # 
          csv_file_store="${HOME}/access_count_${duration_start}_${duration_close}_$(date +%Y%m%d_%H%M%S).csv"
          ;;
   "h")
          usage && exit 0
          ;;
   :|\?)
          usage "[ERROR] unknown option : ${OPTARG}" && exit 1
  esac
done

# checking duration_start option
if [ -z "${duration_start}" ] ; then
    
    usage "[ERROR] wrong option[-f] value : not defined." && exit 1
    
elif [ -z "$(date -d "${duration_start}" 2>/dev/null)" ] ; then
    
    usage "[ERROR] wrong option[-f] value : illegal date string. (${duration_start})"  && exit 1
fi
# checking duration_close option
if [ -z "${duration_close}" ] ; then
    
    usage "[ERROR] wrong option[-t] value : not defined." && exit 1
    
elif [ -z "$(date -d "${duration_close}" 2>/dev/null)" ] ; then
    
    usage "[ERROR] wrong option[-t] value : illegal date string. (${duration_close})"  && exit 1
fi
# checking date duration
if [ "${duration_start}" -gt "${duration_close}" ] ; then
    
    usage "[ERROR] wrong option[-f] value : -f value is newer than -t value. (${duration_start} > ${duration_close})" && exit 1
fi
if [ "${duration_close}" -gt "${current_date}" ] ; then
    
    usage "[ERROR] wrong option[-t] value : -t value is newer than today. (${duration_close} > ${current_date})" && exit 1
fi
# checking logs_directory option
if [ -z "${logs_directory}" ] ; then
    
    usage "[ERROR] wrong option[-d] value : not defined." && exit 1

elif [ ! -d "${logs_directory}" ] ; then
    
    usage "[ERROR] wrong option[-d] value : directory is not existing. (${logs_directory})" && exit 1
fi
# checking encodingString option
if [ -z "${encodingString}" ] ; then
    
    encodingString="${default_encodingString}"
fi
export LANG="${encodingString}"

# checking date duration & collect date string
day_count="1"
next_date="${duration_start}"
day_param="${duration_start}"
while(true)
do
    if [ "${next_date}" -ge "${duration_close}" ] ; then
        
        break
    else
        if [ "${day_count}" -ge ${default_date_durations} ] ; then
            
            usage "[ERROR] wrong option[-f,-t] value : duration is over ${default_date_durations}days. (${duration_start} ~ ${duration_close})" && exit 1
        fi
        day_count="$(expr ${day_count} + 1)"
        next_date="$(date +%Y%m%d -d ${next_date}' +1days')"
        day_param="${day_param}|${next_date}"
    fi
done

# making grep string for collecting log message.
# 
# 20170211|20170212   > ^20170211|^20170212 : date string is the first of the line .
head_grep_param="$(echo ${day_param} | sed "s/^/\^/g" | sed "s/|/|\^/g")"
# ^20170211|^20170212 > ^20170211|^20170212|^2017-02-11|^2017-02-12 : It's covering for both YYYYMMDD and YYYY-MM-DD
head_grep_param="${head_grep_param}|$(echo "${head_grep_param}" | sed "s/\([0-9][0-9][0-9][0-9]\)\([0-9][0-9]\)\([0-9][0-9]\)/\1-\2-\3/g")"

# making grep string for searching log file.
# 
# Is it including current date? If it is, we need to include ${target_access_log_file} as a current log.
includingCurrentDate="$(echo ${day_param} | grep ${current_date})"
# Previous date of ${duration_start} is needed to include the target. because of, It has a possibility to be included log messages in previous log file.
file_grep_param="$(date +%Y-%m-%d -d ${duration_start}' -1days')|${day_param}"

# If current date is existing in target duration, It should be removed from grep string. ${target_access_log_file}.${current_date} never exist under the logs.
# But, If is's not existing in duration, ${duration_close}+1 date string should be added for finding log message at rotated log.
if [ -n "${includingCurrentDate}" ] ; then
    
    file_grep_param="$(echo ${file_grep_param} | sed "s/${current_date}//g" | sed "s/||/|/g" | sed "s/^|//g" | sed "s/|$//g")"
else
	expansionClosingDate="$(date +%Y%m%d -d ${duration_close}' +1days')"
	includingCurrentDate="$(echo ${expansionClosingDate} | grep ${current_date})"
	# If current date is not existing in target expansion, it should added.
	if [ -z "${includingCurrentDate}" ] ; then
		
		file_grep_param="${file_grep_param}|${expansionClosingDate}"
	fi
fi

if [ -n "${file_grep_param}" ] ; then
	
	# 20170211|20170212 > ^spring.log.20170211$|^spring.log.20170212$
	file_grep_param="$(echo ${file_grep_param} | sed "s/^/^${default_logging_prefix}/g" | sed "s/|/$|^${default_logging_prefix}/g" | sed "s/$/$/g")"
	
	# ^spring.log.20170211$|^spring.log.20170212$ > ^spring.log.20170211$|^spring.log.20170212$|^spring.log.2017-02-11$|^spring.log.2017-02-12$
	file_grep_param="${file_grep_param}|$(echo "${file_grep_param}" | sed "s/\([0-9][0-9][0-9][0-9]\)\([0-9][0-9]\)\([0-9][0-9]\)/\1-\2-\3/g")"
fi
# If current date is existing in target duration, ${target_access_log_file} should be added to grep string.
# In case of searching today, Only ${target_access_log_file} is to be grep string.
if [ -n "${includingCurrentDate}" ] ; then
	
	if [ -n "${file_grep_param}" ] ; then
		
		file_grep_param="^${target_access_log_file}$|${file_grep_param}"
	else
		file_grep_param="^${target_access_log_file}$"
	fi
fi

# finding target log files
matched_log_files="$(ls ${logs_directory}/ | grep -E "${file_grep_param}")"

# checking matched log files
if [ -z "${matched_log_files}" ] ; then
    
    echo "[PRINT] execution success : log file not found." && exit 0
fi

# counting access count & storing temporary file
temporary_results="/tmp/$(basename ${0})_$(date +%Y%m%d_%H%M%S)"
(cd ${logs_directory} ; grep -E "${head_grep_param}" ${matched_log_files} | grep -E "\/detail\/[0-9]+" | sed "s/^.*\/detail\/\([0-9]*\) -.*$/\1/g" | sort | uniq -c | sort | sed "s/^[ ]*\([0-9, ]*\)$/\1/g" > ${temporary_results})

if [ -f "${temporary_results}" ] ; then
	
	if [ "$(grep -E "[^0-9,^ ]" ${temporary_results})" ] ; then
		
		rm "${temporary_results}"
		echo "[ERROR] execution failure : it's failed to parse." && exit 1
	fi
	if [ "0" = "$(du -b "${temporary_results}" | cut -f 1)" ] ; then
		
		rm "${temporary_results}"
		echo "[PRINT] execution success : no access log message." && exit 0
	fi
else
	echo "[ERROR] Execution failed." && exit 1
fi
title="id\tcount"
if [ -n "${csv_file_store}" ] ; then
	
	echo "${title}" | tee "${csv_file_store}" && cat "${temporary_results}" | sed "s/\(^[0-9]*\) \([0-9]*\)/\2\t\1/g" | tee -a "${csv_file_store}" && rm "${temporary_results}"
	echo "[PRINT] execution success : ${csv_file_store}"
else
	echo "${title}" && cat ${temporary_results} | sed "s/\(^[0-9]*\) \([0-9]*\)/\2\t\1/g" && rm "${temporary_results}"
fi
