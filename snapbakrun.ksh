#!/usr/bin/ksh93
#set -x
#set -e

ENV_SETUP="/usr/local/etc/snapbakrun/env_setup"
DATE=$(date +%Y'-'%m'-'%d)
LOG=/tmp/snapbakrun_${DATE}.out
MAILLOG=/tmp/snapbakrun_${DATE}.eml
SNAPDIR=${SNAPDIR:-/snapshot}
BACKUP_DIR=${BACKUP_DIR:-/backup}
DIRLIST=${DIRLIST:-"met page data home"}
MAILTO=${MAILTO}
set -A DIRS $(echo "${DIRLIST}")
sed="/usr/linux/bin/sed"
tar="/usr/linux/bin/tar"
udfcreate="/usr/bin/udfcreate"
lsvg="/usr/sbin/lsvg"
lspv="/usr/sbin/lspv"
lslv="/usr/sbin/lslv"
mksysb="/usr/bin/mksysb"
rsync="/usr/bin/rsync"

VERSION="1.1"

if [[ -e "$ENV_SETUP" ]]
then
	. ${ENV_SETUP}
fi

print_info()
{
	echo  ""
	echo  "# Program..........: ${0}"
	echo  "# Version..........: ${VERSION}"
	echo  "# Log..............: ${LOG}"
	echo  "# Backup Dir.......: ${BACKUP_DIR}"
	echo  "# Snap Dir.........: ${SNAPDIR}"
	echo  "# Directory List...: ${DIRLIST}"
	echo  "# Mail To..........: ${MAILTO}"
	echo  ""
}

mailhdr()
{

	echo "-----------------------------------------\n" | tee ${MAILLOG}
	echo "Backup Report for: $(hostname) on ${DATE}\n" | tee -a ${MAILLOG}
	echo "-----------------------------------------\n" | tee -a ${MAILLOG}
	echo "                                         \n" | tee -a ${MAILLOG}
}

log_info()
{
        LEVEL=INFO
        MSG=$1
        echo "$(date +%Y'/'%m'/'%d' '%T' ') [${LEVEL}]: ${MSG}" | tee -a ${LOG}
}

log_error()
{
        LEVEL=ERROR
        MSG=$1
        echo "$(date +%Y'/'%m'/'%d' '%T' ') [${LEVEL}]: ${MSG}" | tee -a ${LOG}
}

##################################################
# Initialize volume group information
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   Array vginfo
#       vginfo[vgname].pp_size
#       vginfo[vgname].pp_free
##################################################
vginfo()
{
    set -A vginfo
    for vg in $(lsvg)
    do
        pp_size=$(lsvg ${vg} | grep "PP SIZE" | awk 'BEGIN{FS=":"} {print$3}' | awk 'BEGIN{FS=" "} {print $1}')
        pp_free=$(lsvg ${vg} | grep "FREE PP" | awk 'BEGIN{FS=":"} {print $3}'| awk 'BEGIN{FS=" "} {print $1}')
        vginfo+=(
                    ["${vg}"]=(pp_size="${pp_size}" pp_free="${pp_free}")
                )
    done
}

##################################################
# Initialize logical volume information
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   Array lvinfo
#       lvinfo[dir].lv_name - Logical volume name 
#       lvinfo[dir].lv_vg - Volume group this lv belongs to
#       lvinfo[dir].lv_lps - Logical partitions
#       lvinfo[dir].lv_pp - physical partitions
#       lvinfo[dir].lv_mirrored - true/false
#       lvinfo[dir].lv_snap_mb - amount in MB of space needed to create a snap
##################################################
lvinfo()
{
    for dir in "${DIRS[@]}"
    do
        if [[ ! -d ${SNAPDIR}/${dir} ]]
        then
            log_info "${SNAPDIR}/${dir} mount point does not exist - creating"
            mkdir -m 777 -p ${SNAPDIR}/${dir}
        fi

        lv_snap_mb=$(df -tm|grep /"${dir}"|awk '{used=+$2} END {printf "%.0f", used*.01}')
        lv_name=$(lsfs /"${dir}"| awk 'NR>1 {print $1}'| awk ' BEGIN{FS="/"} {print $3}')
        lv_vg=$(lslv ${lv_name} | grep "VOLUME GROUP" | sed 's/  *//g'| awk 'BEGIN{FS=":"} {print $3}')
        lv_lp_pp=$(lslv ${lv_name}|grep "^LPs"|${sed} 's/  *//g'| ${sed} -r 's/(LPs:|PPs:)/ /g' | awk 'BEGIN{FS=" "} {print $1":"$2}')
        lv_lp=$(echo ${lv_lp_pp} | cut -d ':' -f1)
        lv_pp=$(echo ${lv_lp_pp} | cut -d ':' -f2)
        if [[ ${lv_lp} -eq ${lv_pp} ]]
        then
            lv_mirrored="false"
        else
            lv_mirrored="true"
        fi

        lvinfo+=(["${dir}"]=( lv_name="${lv_name}" lv_vg="${lv_vg}" lv_lps="${lv_lp}" lv_pps="${lv_pp}" lv_mirrored="${lv_mirrored}" lv_snap_mb="${lv_snap_mb}"))
    done
}


setup()
{
	vginfo
	lvinfo
}

cleanup()
{
    trap '' 1 2 15
    typeset dir
    if [[ $# -eq 1 ]]
    then
        dir=$1
        cleanall ${dir}
    else
        for dir in ${!lvinfo[*]}
        do
            cleanall ${dir}
        done
    fi
}

cleanall()
{
    trap '' 1 2 15
    typeset dir=$1
    typeset SNAP_RC
    snapshot -q /"${dir}"| grep -q "has no snapshots"
    SNAP_RC=$(echo $?)
    if [[ ${SNAP_RC} -eq 0 ]]
    then
        log_info "Nothing to clean up for ${dir}"
    else
        snaplv=$(snapshot -q /${dir} | grep "^*" |awk '{print $2}')
        typeset -i DF_RC=0
        df | grep "${snaplv}" > /dev/null 2>&1
        DF_RC=$(echo $?)
        if [[ ${DF_RC} -eq 0 ]]
        then
            typeset snap_mount=$(df | grep ${snaplv}| awk '{print $7}')
            unmount ${snap_mount}
        fi
        if [[ $(snapshot -d ${snaplv} > /dev/null 2>&1) -ne 0 ]]
        then
            log_error "Error removing the snapshot for /${dir} - Manual intervention required"
        else
           log_info "Removed the snapshot for /${dir}" 
        fi
    fi
}

###################################################
## Create the snapshot lv
## Globals:
##   None
## Arguments:
##   Expects the file system path: 
## Returns:
##   The name of the logical volume snapshot
###################################################
##       vginfo[vgname].pp_size
##       vginfo[vgname].pp_free
##       lvinfo[dir].lv_name - Logical volume name 
##       lvinfo[dir].lv_lps - Logical partitions
##       lvinfo[dir].lv_pps - physical partitions
##       lvinfo[dir].lv_mirrored - true/false
##       lvinfo[dir].lv_snap_mb - amount in MB of space needed to create a snap
create_snap()
{
    trap 'cleanup' 1 2 15
    typeset dir=$1
    typeset snap_fs="/${dir}"
    typeset -i snap_size="${lvinfo[${dir}].lv_snap_mb}"
    typeset snap_vg="${lvinfo[${dir}].lv_vg}"
    typeset -i snap_vg_pp_size="${vginfo[${snap_vg}].pp_size}"
    typeset -i snap_vg_pp_free="${vginfo[${snap_vg}].pp_free}"
    #Check available space
    #log_info "snap_fs: ${snap_fs} snap_size: ${snap_size} snap_pp: ${snap_pp} snap_vg: ${snap_vg} snap_vg_pp_size: ${snap_vg_pp_size} snap_vg_pp_free: ${snap_vg_pp_free} snap_size_mb: ${snap_size}" 
    (( snap_pp = ${snap_size} / ${vginfo[${lv_vg}].pp_size} + 1  ))

    if [[ ${snap_pp} -lt ${snap_vg_pp_free} ]]
    then
        #log_info "There are enough free PPs in ${snap_vg} to create snapshot"
        snap_lv=$(snapshot -o snapfrom=${snap_fs} -o size=${snap_size}M)
        if [[ -n ${snap_lv} ]]
        then
            snap_lv=$(echo ${snap_lv} | awk '{print $8}')
            log_info "Created snap logical volume ${snap_lv} for filesystem ${snap_fs}"
            if [[ $(mount -v jfs2 -o snapshot ${snap_lv} ${SNAPDIR}${snap_fs}) -ne 0 ]]
            then
                log_error "Failed to mount ${SNAPDIR}${snap_fs} on ${snap_lv}"
                exit 1
            else
                log_info "Mounted ${SNAPDIR}${snap_fs} on ${snap_lv}"
                return 0
            fi
        else
            log_error "Failed to create snapshot for ${snap_fs}"
            exit 1
        fi
    else
        log_error "Not enough free PPs in ${snap_vg} to create snapshot of ${snap_fs} snap_pp: ${snap_pp} snap_vg_pp_free: ${snap_vg_pp_free}"
        exit 1
    fi
}


remove_snap()
{
    trap '' 1 2 15
    typeset dir=$1
    typeset SNAP_RC
    snapshot -q /"${dir}"| grep -q "has no snapshots"
    SNAP_RC=$(echo $?)
    if [[ ${SNAP_RC} -eq 0 ]]
    then
        log_info "Nothing to clean up for ${dir}"
    else
        snaplv=$(snapshot -q /${dir} | grep "^*" |awk '{print $2}')
        typeset -i DF_RC=0
        df | grep "${snaplv}" > /dev/null 2>&1
        DF_RC=$(echo $?)
        if [[ ${DF_RC} -eq 0 ]]
        then
            typeset snap_mount=$(df | grep ${snaplv}| awk '{print $7}')
            unmount ${snap_mount}
        fi
        if [[ $(snapshot -d ${snaplv} > /dev/null 2>&1) -ne 0 ]]
        then
            log_error "Error removing the snapshot for /${dir} - Manual intervention required"
        else
           log_info "Removed the snapshot for /${dir}" 
        fi
    fi
}


usage()
{
    echo "snapbakrun.ksh -c -s"

}


main()
{


}



while [ $# -gt 0 ]
do
    case "$1" in 
        -s) 
            print_info > ${MAILLOG}
            setup
            typeset snap
            for dir in ${!lvinfo[*]}
            do
                echo "\nStarting backup of /${dir}\n"
                create_snap ${dir}
                num_files=$( ${rsync} -aru --delete --stats --log-file=${LOG} ${SNAPDIR}/${dir}/ ${BACKUP_DIR}/${dir}/| awk '/Number of regular files transferred:/{print $NF}')
                echo "\nCompleted backup of /${dir}\n"
                echo "Completed backup of ${dir}, backed up: ${num_files} files\n" | tee -a ${MAILLOG}
            done
            echo "\nStarting cleanup of snapshots\n"
            cleanup
            echo "Backup copmpleted\n"| tee -a ${MAILLOG}
            if [[ -n ${MAILTO} ]]
            then
                mail -s "Backup Report for $(hostname) on $(date)" ${MAILTO} < ${MAILLOG}
            fi
            ;;
        -c)
            setup
            cleanup
            ;;
	-v)
	    print_info
	    ;;
        -*)
            usage
            exit 1
            ;;
        *)
            break
            ;;
    esac
    shift
done

