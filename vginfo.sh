#!/usr/bin/ksh93
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

#### Process the command line options and arguments.

  while getopts ":vV" OPTION
  do
      case "${OPTION}" in
          'v') VERBOSE="${TRUE}";;
          'V') VERYVERB="${TRUE}";;
          '?') vginfo "${0}" && return 1 ;;
          ':') vginfo "${0}" && return 2 ;;
          '#') NAME "${0}" && return 3 ;;
      esac
  done
   
  shift $(( ${OPTIND} - 1 ))
  
  trap "usagemsg_vginfo ${0}" EXIT

  trap "-" EXIT
  
  (( VERYVERB == TRUE )) && set -x
  (( VERBOSE  == TRUE )) && print -u 2 "# Version...........: ${VERSION}"

  MSG="${@}"

################################################################


  (( VERBOSE  == TRUE )) && print -u 2 "# MSG Variable Value: ${MSG}"
  print -- "${MSG}"

  for vg in $( lsvg )
  do
      pp_size=$(lsvg ${vg} | grep "PP SIZE" | awk 'BEGIN{FS=":"} {print$3}' | awk 'BEGIN{FS=" "} {print $1}')
      pp_free=$(lsvg ${vg} | grep "FREE PP" | awk 'BEGIN{FS=":"} {print $3}'| awk 'BEGIN{FS=" "} {print $1}')
      vginfo+=( ["${vg}"]=(pp_size="${pp_size}" pp_free="${pp_free}"))
  done

  eval ARY="( \${!vginfo[@]} )"
  for IDX in "${ARY[@]}"
  do
      (( VERBOSE  == TRUE )) && print -u 2 "# VG:pp_size........: ${IDX}:${vginfo[$IDX].pp_size}"
      (( VERBOSE  == TRUE )) && print -u 2 "# VG:pp_free...........: ${IDX}:${vginfo[$IDX].pp_free}"
  done

  trap "-" HUP

  return 0
}
################################################################

vginfo "${@}"


