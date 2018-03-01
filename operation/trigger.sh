#!/bin/sh
# name   : task manual executer script
# writer : euncheol.kweon
# mail   : ksfool@gmail.com
# 
# history
# ex. [yyyy/mm/dd] added some function.
# [2014/05/16] script created.
# 

# ${1} message : message
usage() {
    
    message="${1}"
    exec 1>&2
    if [ -n "${message}" ] ; then
        
        echo "${message}"
    fi
    cat <<EOF
Usage : release manual executer.

Usage: $(basename ${0}) [-a ${option_string}] [-f] [-h] [-s] manual_file_name
  -a <option_string>     : option string for manual
  -f                     : forced execution.(non-interactive-mode. Default is interactive mode.)
  -h                     : show this message.        
  -s                     : no log message. (silent-mode. Default is log-print mode.)
  manual_file_name       : target manual file name
EOF
}

###############################################################################################################################
# common
###############################################################################################################################
# ${1} script path : base directory path.(ex. /home/weblogic)
# ${2} target path : relative path for base directory path.(ex. work/temp)
# result : /home/weblogic/work/temp (If path is symbolic path, It will be returned absolute path.)
get_path() {
    
    SCRIPT_PATH="${1}"
    TARGET_PATH="${2}"
    
    readlink_command=$(which readlink 2>/dev/null)
    
    if [ -n "${readlink_command}" ] ; then
    	    
        REALPATH="$(${readlink_command} ${SCRIPT_PATH})"
    else
    	    REALPATH="${SCRIPT_PATH}"
    fi
    # It's not symbolic link.
    if [ -z "${REALPATH}" ] ; then
        
        REALPATH="${SCRIPT_PATH}"
    fi
    TARGET_PATH=$(echo "$(pushd $(dirname ${REALPATH}) 1>/dev/null ; pwd)/${TARGET_PATH}")
    
    echo "${TARGET_PATH}"
    
    if [ -e "${TARGET_PATH}" ] ; then
        
        return 0
    fi
    if [ "${is_log_message_mode}" = "true" ] ; then
        
        echo "[WARN] path not exist.(${TARGET_PATH})"
    fi
    return 1
}

# ${1} script path : target directory path for initial script.
initialize() {
    
    SCRIPT_PATH="${1}"
    
    MAINT_PATH="$(get_path "${SCRIPT_PATH}" "maint_timetable/maintenance")"
    if [ -f "${MAINT_PATH}" ] ; then
        
        cat ${MAINT_PATH}
        exit 0
    fi
    
    COMMON_PATH="/rms/envs/env-operation"
    COMMON_PATH="${COMMON_PATH} $(get_path "${SCRIPT_PATH}" "common/options.conf")"
    COMMON_PATH="${COMMON_PATH} $(get_path "${SCRIPT_PATH}" "common/file_control.sh")"
    COMMON_PATH="${COMMON_PATH} $(get_path "${SCRIPT_PATH}" "common/otd_commands.sh")"
    
    for COMMON_FILE in ${COMMON_PATH}
    do
        
        if [ -e "${COMMON_FILE}" ] ; then
            
            . "${COMMON_FILE}"
            result="${?}"
            if [ "${is_log_message_mode}" = "true" ] ; then
                
                echo "[INFO] file(${COMMON_FILE}) executed. [result = ${result}]"
            fi
        else
            
            if [ "${is_log_message_mode}" = "true" ] ; then
                
                echo "[WARN] file(${COMMON_FILE}) not found."
            fi
            return 1
        fi
    done
    return 0
}

###############################################################################################################################
# local function
###############################################################################################################################
# set global variable.
_is_auto="false"
init_var="false"
is_block="false"
stop_exe="false"
tmp_script=""
tmp_script_directory="/tmp"

# 
# ${1} init_properties : option string for manual
init_variables() {
    
    init_properties="${1}"
    
    if [ -z "${init_properties}" ] ; then
        return 1
    fi
    for init_property in ${init_properties}
    do
        if [ -z "${init_property}" ] ; then
        	    continue
        fi
        init_var="$(echo "${init_property}" | awk '{ FS="=" ; split($0, params) ; print params[1]; }')"
        init_val="$(echo "${init_property}" | awk '{ FS="=" ; split($0, params) ; print params[2]; }')"
        
        if [ -z "${init_var}" ] ; then
            continue
        fi
        if [ -z "${init_val}" ] ; then
            init_val="true"
        fi
        eval ${init_var}=${init_val}
    done
}

# 
# return code 0 = execution permitted.
# return code 1 = execution cancelled.
# return code 2 = process exit.
is_permitted() {
    
    if [ "${is_interactive_mode}" != "true" ] ; then
        
        return 0
    fi
    
    do_execute=""
    block_type="command"
    
    trigger_script="${1}"
    
    if [ "${is_block}" = "true" ] ; then
        
        block_type="block"
    fi
    
    while [ "${do_execute}" = "" ] ; do
        
        if [ "${is_log_message_mode}" = "true" ] ; then
            
            option_string="(y/n or exit)"
        else
            
            option_string="(y/n/v[iew] or exit)"
        fi
        read -p "[INFO] Do you want to execute a ${block_type}? ${option_string} : # " do_execute
        
        do_execute="$(echo ${do_execute} | tr '[a-z]' '[A-Z]')"
        
        case ${do_execute} in
            "Y")
                
                return 0
                ;;
            "N")
                
                echo "[INFO] you have selected 'n'. ${block_type} will not be executed."
                return 1
                ;;
            "EXIT")
                
                read -p "[INFO] execution will be stopped. Do you agree? (y/n, illegal answer will be stop this process.) : # " do_exit
                
                do_exit="$(echo ${do_exit} | tr '[a-z]' '[A-Z]')"
                
                case ${do_exit} in
                    
                    "Y")
                        
                        return 2
                        ;;
                    "N")
                        echo "[INFO] exit is cancelled. process will be processed."
                        do_exit=""
                        do_execute=""
                        ;;
                    *)
                        echo "[WARN] Illegal answer selected. process will be stopped."
                        return 2
                esac
                ;;
            *)
                if [ "${do_execute}" = "V" -a "${is_log_message_mode}" != "true" ] ; then
                    
                    if [ "${is_block}" = "true" ] ; then
                        
                        echo "[INFO] scripts : "
                        echo "[INFO] -----------------"
                        sed 's/\(.*\)/[INFO] \1/g' "${trigger_script}"
                        echo "[INFO] -----------------"
                    else
                        
                        echo "[INFO] command : ${trigger_script}"
                    fi
                else
                    
                    echo "[WARN] Illegal answer selected. Please, select correct answer."
                fi
                do_execute=""
        esac
    done
    return 1
}

return_code="${?}"
set_return_code() {
    
    return "${return_code}"
}

# 
# ${1} line_string : command line from release manual
line_executer() {
    
    line_string="${1}"
    
    # if runnable command is echo, It will be executed. because of It is information message for manual writer.
    if [ "$(expr "${line_string}\$" : ' *\(echo \)')" != "echo " ] ; then
        
        if [ "${is_log_message_mode}" = "true" ] ; then
            
            echo "[INFO] command : ${line_string}"
        fi
        
        is_permitted "${line_string}"
        
        is_permitted_result="${?}"
        
        if [ "${is_permitted_result}" != "0" ] ; then
            
            if [ "${is_permitted_result}" = "2" ] ; then
                
                stop_exe="true"
            fi
            return 0
        fi
        if [ "${is_interactive_mode}" = "true" -o "${is_log_message_mode}" = "true" ] ; then
            
            echo "-----------------"
            echo "execute : "
        fi
    fi
    set_return_code
    eval ${line_string}
    #(eval ${line_string} ; echo "returns : "${?}"") | sed 's/\(.*\)/[INFO] \1/g'
    
    return_code="${?}"
    
    if [ "$(expr "${line_string}\$" : ' *\(echo \)')" != "echo " ] ; then
        
        if [ "${is_interactive_mode}" = "true" -o "${is_log_message_mode}" = "true" ] ; then
            
            echo "returns : ${return_code}"
            echo "-----------------"
        fi
    fi
    return "${return_code}"
}

# 
# ${1} line_string : line string from release manual
is_runnable() {
    
    line_string="${1}"
    
    trim_string="$(echo ${line_string//^[[:blank:]|[:tab:]]/})"
    
    if [ "${trim_string}" = "" -a "${is_block}" = "false" ] ; then
        
        return 1
    fi
    if [ "$(expr "${line_string}\$" : ' *\(#\)')" = "#" ] ; then
        
        if [ "$(expr "${line_string}\$" : ' *\(#@block\)')" = "#@block" ] ; then
            
            if [ "$(expr "${line_string}\$" : '.*( *\(auto\) *)')" = "auto" ] ; then
                
                _is_auto="true"
            fi
            if [ "$(expr "${line_string}\$" : '.*( *\(init\) *)')" = "init" ] ; then
                
                _is_auto="true"
                init_var="true"
            fi
            
            if [ "${is_block}" = "true" ] ; then
                
                if [ -e "${tmp_script}" ] ; then
                    
                    if [ "${is_log_message_mode}" = "true" ] ; then
                        
                        echo "[INFO] scripts : "
                        echo "[INFO] -----------------"
                        sed 's/\(.*\)/[INFO] \1/g' "${tmp_script}"
                        echo "[INFO] -----------------"
                    fi
                    
                    if [ "${_is_auto}" = "true" ] ; then
                        
                        is_permitted_result="0"
                    else
                        is_permitted "${tmp_script}"
                        
                        is_permitted_result="${?}"
                    fi
                    
                    if [ "${is_permitted_result}" = "0" ] ; then
                        
                        if [ "${is_interactive_mode}" = "true" -o "${is_log_message_mode}" = "true" ] ; then
                            
                            if [ "${_is_auto}" != "true" ] ; then
                            	   echo "-----------------"
                                echo "execute : "
                            fi
                        fi
                        set_return_code
                        . ${tmp_script}
                        return_code="${?}"
                        
                        if [ "${is_interactive_mode}" = "true" -o "${is_log_message_mode}" = "true" ] ; then
                            
                            if [ "${_is_auto}" != "true" ] ; then
                            	   echo "returns : ${return_code}"
                                echo "-----------------"
                            fi
                        fi
                        if [ "${init_var}" = "true" ] ; then
                            
                            init_variables "${manual_arguments}"
                        fi
                    fi
                    if [ "${is_permitted_result}" = "2" ] ; then
                        
                        stop_exe="true"
                    fi
                fi
                _is_auto="false"
                init_var="false"
                is_block="false"
                return 1
            else
                
                is_block="true"
                
                tmp_script="${tmp_script_directory}/$(basename ${0}).$(date +%Y%m%d%H%M%S%N).tmp"
                return 1
            fi
        fi
        return 1
    fi
    
    if [ "${is_block}" = "true" ] ; then
        
        echo "${line_string}" >> "${tmp_script}"
        return 1
    else
        
        line_string="${trim_string}"
        return 0
    fi
    return 1
}

###############################################################################################################################
# main
###############################################################################################################################
export LANG="ja_JP.eucJP"

# variable for option f
is_interactive_mode="true"
# variable for option s
is_log_message_mode="true"

manual_arguments=""

# arguments
while getopts :a:fhs OPT; do
  case ${OPT} in
   "a")
          # manual_arguments
          manual_arguments="${OPTARG}"
          ;;
   "f")
          # is_interactive_mode
          is_interactive_mode="false"
          ;;
   "h")
          usage && exit 1
          ;;
   "s")
          # is_log_message_mode
          is_log_message_mode="false"
          ;;
   :|\?)
          usage "unknown option ${OPTARG}" && exit 1
  esac
done

shift $((${OPTIND} - 1))

# setting manual arguments
manual_arguments="$(echo $manual_arguments | sed "s/,/ /g")"
init_variables "${manual_arguments}"

manual_file_name="${1}"
if [ -z "${manual_file_name}" ] ; then
    
    usage "Argument(manual_file_name) is not defined." && exit 1
fi

if [ -n "${JAVA_HOME}" ] ; then
    
    usage "JAVA_HOME is already existing. Please, try again after clearing environment." && exit 1
fi

target_manual_file="$(get_path "${0}" "${manual_file_name}")"

if [ "${?}" != "0" ] ; then
    
    usage "$(basename "${0}") can't find ${manual_file_name}." && exit 1
fi

if [ "${is_log_message_mode}" = "true" ] ; then
    
    echo "[INFO] initialize start."
fi
initialize "${0}"
if [ "${is_log_message_mode}" = "true" ] ; then
    
    echo "[INFO] initialize close."
fi

line_count="$(cat "${target_manual_file}" | wc -l)"
for ((index = 1; index <= ${line_count}; index++))
do
    line_string="$(sed -n "${index}p" "${target_manual_file}")"
    
    is_runnable "${line_string}"
    
    is_runnable_return_code="${?}"
    
    if [ "${is_runnable_return_code}" = "0" ] ; then
        
        line_executer "${line_string}"
    fi
    if [ "${stop_exe}" = "true" ] ; then
        
        exit 2
    fi
done

