#!/usr/bin/ksh93
################################################################
function usagemsg_lvinfo {
  print "
Program: lvinfo

Place a brief description ( < 255 chars ) of your shell
function here.

Usage: ${1##*/} [-?vV] 

  Where:
    -v = Verbose mode - displays lvinfo function info
    -V = Very Verbose Mode - debug output displayed
    -k = Output as ksh93 array (default)
    -d = Output as colon (:) delimited data
    -f = File System name
    -? = Help - display this message

Author: Raymond L. Cox (rcox@unixandmore.com)

\"AutoContent\" enabled
"
}
################################################################
#### 
#### Description:
#### 
#### Place a full text description of your shell function here.
#### 
#### Assumptions:
#### 
#### Provide a list of assumptions your shell function makes,
#### with a description of each assumption.
#### 
#### Dependencies:
#### 
#### Provide a list of dependencies your shell function has,
#### with a description of each dependency.
#### 
#### Products:
#### 
#### Provide a list of output your shell function produces,
#### with a description of each product.
#### 
#### Configured Usage:
#### 
#### Describe how your shell function should be used.
#### 
#### Details:
#### 
#### Place nothing here, the details are your shell function.
#### 
################################################################
function lvinfo {
  typeset VERSION="1.0"
  typeset TRUE="0"
  typeset FALSE="1"
  typeset KORNOUT="${FALSE}"
  typeset DATAOUT="${FALSE}"
  typeset -L1 D=":"
  typeset FILESYSTEM=""
  typeset sed="/usr/linux/bin/sed"
  typeset VERBOSE="${FALSE}"
  typeset VERYVERB="${FALSE}"

#### Process the command line options and arguments.

  while getopts ":vVkdf:" OPTION
  do
      case "${OPTION}" in
          'v') VERBOSE="${TRUE}";;
          'V') VERYVERB="${TRUE}";;
          'k') KORNOUT="${TRUE}";;
          'd') DATAOUT="${TRUE}";;
          'f') FILESYSTEM="${OPTARG}";;
          '?') lvinfo "${0}" && return 1 ;;
          ':') lvinfo "${0}" && return 2 ;;
          '#') NAME "${0}" && return 3 ;;
      esac
  done
   
  shift $(( ${OPTIND} - 1 ))
  
  trap "usagemsg_lvinfo ${0}" EXIT


  trap "-" EXIT
  
    if (( KORNOUT == FALSE )) && (( DATAOUT == FALSE ))
      then
        KORNOUT="${TRUE}"
      fi

  (( VERYVERB == TRUE )) && set -x
  (( VERBOSE  == TRUE )) && print -u 2 "# Version...........: ${VERSION}"


################################################################

  if [[ ! -d ${FILESYSTEM} ]]
  then
      print -u 2 "Missing Filesystem (-f) option"
      return 1
  fi

  LV_SNAP_MB=$(df -tm|grep "${FILESYSTEM}"|awk '{used=+$2} END {printf "%.0f", used*.01}')
  LV_NAME=$(lsfs "${FILESYSTEM}"| awk 'NR>1 {print $1}'| awk ' BEGIN{FS="/"} {print $3}')
  LV_VG=$(lslv ${LV_NAME} | grep "VOLUME GROUP" | sed 's/  *//g'| awk 'BEGIN{FS=":"} {print $3}')
  LV_LP_PP=$(lslv ${LV_NAME}|grep "^LPs"|${sed} 's/  *//g'| ${sed} -r 's/(LPs:|PPs:)/ /g' | awk 'BEGIN{FS=" "} {print $1":"$2}')
  LV_LP=$(echo ${LV_LP_PP} | cut -d ':' -f1)
  LV_PP=$(echo ${LV_LP_PP} | cut -d ':' -f2)
  if [[ ${LV_LP} -eq ${LV_PP} ]]
  then 
      LV_MIRRORED="${FALSE}"
  else
      LV_MIRRORED="${TRUE}"
  fi
  LVINFO+=( 
            lv_fs_name="${FILESYSTEM}" 
            lv_name="${LV_NAME}" 
            lv_vg="${LV_VG}" 
            lv_lps="${LV_LP}" 
            lv_pps="${LV_PP}" 
            lv_mirrored="${LV_MIRRORED}" 
            lv_snap_mb="${LV_SNAP_MB}"
        )

  (( VERBOSE  == TRUE )) && print -u 2 "# FILESYSTEM........: ${FILESYSTEM}"
  (( VERBOSE  == TRUE )) && print -u 2 "# LV_SNAP_MB........: ${LV_SNAP_MB}"
  (( VERBOSE  == TRUE )) && print -u 2 "# LV_NAME...........: ${LV_NAME}"
  (( VERBOSE  == TRUE )) && print -u 2 "# LV_VG.............: ${LV_VG}"
  (( VERBOSE  == TRUE )) && print -u 2 "# LV_LP.............: ${LV_LP}"
  (( KORNOUT  == TRUE )) && print -- "${LVINFO[*]}"

  trap "-" HUP

  return 0
}
################################################################

lvinfo "${@}"



