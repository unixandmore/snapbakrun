#!/usr/bin/ksh93
################################################################
function usagemsg_create_snap {
  print "
Program: create_snap

Create a snapshot of a logical volume automatically sizing to the 10% available mark.

Usage: ${1##*/} [-?vV] 

  Where:
    -v = Verbose mode - displays create_snap function info
    -V = Very Verbose Mode - debug output displayed
    -k = Output as ksh93 array (default)
    -d = Output as colon (:) delimited data
    -f = Filesystem name
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
function create_snap {
  typeset VERSION="1.0"
  typeset TRUE="0"
  typeset FALSE="1"
  typeset KORNOUT="${FALSE}"
  typeset DATAOUT="${FALSE}"
  typeset -L1 D=":"
  typeset VERBOSE="${FALSE}"
  typeset VERYVERB="${FALSE}"

#### Process the command line options and arguments.

  while getopts ":vVkd:f:" OPTION
  do
      case "${OPTION}" in
          'v') VERBOSE="${TRUE}";;
          'V') VERYVERB="${TRUE}";;
          'k') KORNOUT="${TRUE}";;
          'd') DATAOUT="${TRUE}";;
          'f') FILE_SYSTEM="${OPTARG}";;
          '?') create_snap "${0}" && return 1 ;;
          ':') create_snap "${0}" && return 2 ;;
          '#') NAME "${0}" && return 3 ;;
      esac
  done
   
  shift $(( ${OPTIND} - 1 ))
  
  trap "usagemsg_create_snap ${0}" EXIT

  trap "-" EXIT
  
    if (( KORNOUT == FALSE )) && (( DATAOUT == FALSE ))
      then
        KORNOUT="${TRUE}"
      fi

  unset VFLAG
  (( VERYVERB == TRUE )) && set -x
  (( VERBOSE  == TRUE )) && typeset VFLAG="-v"
  (( VERBOSE  == TRUE )) && print -u 2 "# Program...........: ${0}"
  (( VERBOSE  == TRUE )) && print -u 2 "# Version...........: ${VERSION}"
  (( VERBOSE  == TRUE )) && print -u 2 "# FILE_SYSTEM.......: ${FILE_SYSTEM}"


################################################################


  lvinfo -f ${FILE_SYSTEM} ${VFLAG} 
  (( VERBOSE  == TRUE )) && print -u 2 "# LVINFO............: ${LVINFO[@]}"
  (( VERBOSE  == TRUE )) && print -u 2 "# LVINFO............: ${LVINFO[${FILE_SYSTEM}].lv_pps}"

  ### .Make sure there is enough space to create the snap
  
  (( VERBOSE  == TRUE )) && print -u 2 "# LVINFO[FILE_SYSTEM].lv_snap_mb............: ${LVINFO[${FILE_SYSTEM}].lv_snap_mb}"
  (( VERBOSE  == TRUE )) && print -u 2 "# LVINFO[FILE_SYSTEM].lv_vg_pp_size............: ${LVINFO[${FILE_SYSTEM}].lv_vg_pp_size}"
  (( SNAP_PP = ${LVINFO[${FILE_SYSTEM}].lv_snap_mb} / ${LVINFO[${FILE_SYSTEM}].lv_vg_pp_size} + 1 ))
  (( VERBOSE  == TRUE )) && print -u 2 "# SNAP_PP.......: ${SNAP_PP}"




  trap "-" HUP

  return 0
}
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
  (( VERBOSE  == TRUE )) && typeset VFLAG="-v"
  (( VERBOSE  == TRUE )) && print -u 2 "# Program...........: ${0}"
  (( VERBOSE  == TRUE )) && print -u 2 "# Version...........: ${VERSION}"


################################################################

  if [[ ! -d ${FILESYSTEM} ]]
  then
      print -u 2 "Missing Filesystem (-f) option"
      return 1
  fi

  LV_NAME=$(lsfs "${FILESYSTEM}"| awk 'NR>1 {print $1}'| awk ' BEGIN{FS="/"} {print $3}')
  LV_SNAP_MB=$(df -tm|grep "${LV_NAME}"|awk '{used=+$2} END {printf "%.0f", used*.01}')
  LV_VG=$(lslv ${LV_NAME} | grep "VOLUME GROUP" | sed 's/  *//g'| awk 'BEGIN{FS=":"} {print $3}')
  LV_VG_PP_FREE=$(lsvg ${LV_VG} | grep "FREE PP" | awk 'BEGIN{FS=":"} {print $3}'| awk 'BEGIN{FS=" "} {print $1}')
  LV_VG_PP_SIZE=$(lslv ${LV_NAME} | grep "PP SIZE" | awk 'BEGIN{FS=":"} {print$3}' | awk 'BEGIN{FS=" "} {print $1}')
  LV_LP_PP=$(lslv ${LV_NAME}|grep "^LPs"|${sed} 's/  *//g'| ${sed} -r 's/(LPs:|PPs:)/ /g' | awk 'BEGIN{FS=" "} {print $1":"$2}')
  LV_LP=$(echo ${LV_LP_PP} | cut -d ':' -f1)
  LV_PP=$(echo ${LV_LP_PP} | cut -d ':' -f2)
  if [[ ${LV_LP} -eq ${LV_PP} ]]
  then 
      LV_MIRRORED="${FALSE}"
  else
      LV_MIRRORED="${TRUE}"
  fi
  (( VERBOSE  == TRUE )) && print -u 2 "# FILESYSTEM........: ${FILESYSTEM}"
  (( VERBOSE  == TRUE )) && print -u 2 "# LV_SNAP_MB........: ${LV_SNAP_MB}"
  (( VERBOSE  == TRUE )) && print -u 2 "# LV_NAME...........: ${LV_NAME}"
  (( VERBOSE  == TRUE )) && print -u 2 "# LV_VG.............: ${LV_VG}"
  (( VERBOSE  == TRUE )) && print -u 2 "# LV_VG_PP_FREE.....: ${LV_VG_PP_FREE}"
  (( VERBOSE  == TRUE )) && print -u 2 "# LV_VG_PP_SIZE.....: ${LV_VG_PP_SIZE}"
  (( VERBOSE  == TRUE )) && print -u 2 "# LV_PP.............: ${LV_PP}"
  (( VERBOSE  == TRUE )) && print -u 2 "# LV_LP.............: ${LV_LP}"
  
  LVINFO+=(["${FILESYSTEM}"]= 
            (lv_fs_name="${FILESYSTEM}" 
            lv_name="${LV_NAME}" 
            lv_vg="${LV_VG}" 
            lv_vg_pp_free="${LV_VG_PP_FREE}" 
            lv_vg_pp_size="${LV_VG_PP_SIZE}" 
            lv_lps="${LV_LP}" 
            lv_pps="${LV_PP}" 
            lv_mirrored="${LV_MIRRORED}" 
            lv_snap_mb="${LV_SNAP_MB}")
        )

  #(( SNAP_PP = ${LV_SNAP_MB} / ${VGINFO[1]} + 1 ))
  #(( VERBOSE  == TRUE )) && print -u 2 "# SNAP_PP...........: ${SNAP_PP}"

  #LVINFO+=( lv_snap_pp="${SNAP_PP}" vg_avail_pp="${VGINFO.pp_free}" )

  (( KORNOUT  == TRUE )) && print -- "${LVINFO[*]}"

  trap "-" HUP

  return 0
}
################################################################
function usagemsg_vginfo {
  print "
Program: vginfo

Place a brief description ( < 255 chars ) of your shell
function here.

Usage: ${1##*/} [-?vV] 

  Where:
    -v = Verbose mode - displays vginfo function info
    -V = Very Verbose Mode - debug output displayed
    -d = Output colon delimited records
    -k = Output ksh93 array
    -? = Help - display this message

Author: Raymond L. Cox (rcox@unixandmore.com)

\"AutoContent\" enabled
"
}
################################################################
#### 
#### Description:
#### 
#### Initialize Volume Group Information
#### 
#### Assumptions:
#### 
#### None
#### 
#### Dependencies:
#### 
#### None
#### 
#### Products:
#### 
#### Array vginfo
####    vginfo[vgname].pp_size
####    vginfo[vgname].pp_free 
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
function vginfo {
  typeset VERSION="1.0"
  typeset TRUE="0"
  typeset FALSE="1"
  typeset VERBOSE="${FALSE}"
  typeset VERYVERB="${FALSE}"
  typeset KORNOUT="${FALSE}"
  typeset DATAOUT="${FALSE}"
  typeset -L1 D=":"
  #typeset -A VGINF

#### Process the command line options and arguments.

  while getopts ":vVg:" OPTION
  do
      case "${OPTION}" in
          'v') VERBOSE="${TRUE}";;
          'V') VERYVERB="${TRUE}";;
          'd') DATAOUT="${TRUE}";;
          'k') KORNOUT="${TRUE}";;
          'g') VG="${OPTARG}";;
          '?') vginfo "${0}" && return 1 ;;
          ':') vginfo "${0}" && return 2 ;;
          '#') NAME "${0}" && return 3 ;;
      esac
  done
   
  shift $(( ${OPTIND} - 1 ))
  
  trap "usagemsg_vginfo ${0}" EXIT

  if (( KORNOUT == FALSE )) && (( DATAOUT == FALSE ))
  then
      KORNOUT="${TRUE}"
  fi


  trap "-" EXIT
  
  (( VERYVERB == TRUE )) && set -x
  (( VERBOSE  == TRUE )) && print -u 2 "# Program...........: ${0}"
  (( VERBOSE  == TRUE )) && print -u 2 "# Version...........: ${VERSION}"

  pp_size=$(lsvg ${VG} | grep "PP SIZE" | awk 'BEGIN{FS=":"} {print$3}' | awk 'BEGIN{FS=" "} {print $1}')
  pp_free=$(lsvg ${VG} | grep "FREE PP" | awk 'BEGIN{FS=":"} {print $3}'| awk 'BEGIN{FS=" "} {print $1}')
  VGINF=(size="${pp_size}" free="${pp_free}")
  #VGINF[size]="${pp_size}#"
  #VGINF[free]="${pp_free}"

  (( VERBOSE == TRUE )) && print -u 2 "# pp_size...........: ${VGINF.size}"
  (( VERBOSE == TRUE )) && print -u 2 "# pp_free...........: ${VGINF.free}"

  (( KORNOUT == TRUE )) && print -- "${VGINF[*]}"

  trap "-" HUP

  return 0
}
################################################################

create_snap "${@}"



