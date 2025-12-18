#!/bin/bash
# ******************************************************************************
#
#                                --- WARNING ---
#
#   This work contains trade secrets of DataDirect Networks, Inc.  Any
#   unauthorized use or disclosure of the work, or any part thereof, is
#   strictly prohibited.  Copyright in this work is the property of DataDirect.
#   Networks, Inc. All Rights Reserved. In the event of publication, the.
#   following notice shall apply: (C) 2019, DataDirect Networks, Inc.
#
# ******************************************************************************

# Fix 'ascii' codec can't encode character u'\u25b6'
export LC_ALL="en_US.utf8"

if ! . routines.sh 2>/dev/null ; then
    echo "$(hostname): ✖ Can't load routines.sh"
    echo "$(hostname): ℹ Check that your archive is correct and run the script from its directory"
    exit 1
fi

if ! (echo "None" > file_creation.log) >/dev/null 2>&1 ; then
    echo_error_tips "Can't write logs in directory" \
		    "Fix rights for this directory: sudo chown -R $USER $PWD"
    exit 1
fi


print_usage()
{
    echo "EXA Client Performance Validation v1.1.9"
    echo "$0 [optional options]"
    echo ""
    printf "\t--help|-h\t\tPrint this page\n"
    printf "\t--verbose|-v\t\tverbose\n"
    printf "\t--mountpoint|-m /m\tCustomize EXAScaler mountpoint (default=/exa_filesystem)\n"
    printf "\t\t\t\t(no ' in or around it)\n"
    printf "\t--clients \"IP0 u@IP1#\"\tList of space separated hosts (Add # suffix to become sudo)\n"
    printf "\t--runtime 15 \t\tCustomize runtime in sec (default=30)\n"
    printf "\t--ramptime 5 \t\tCustomize ramptime in sec (default=10)\n"
    printf "\n\t\t\tFIO type options\n\n"
    printf "\t--processes|-p 42 \tCustomize number of processes (default=nproc for each client)\n\t\t\t\t(if --numa-binding-* used, -p is per numa job)\n"
    printf "\t--blocksize 1M \t\tCustomize blocksize used for sequential read/write (default=1M)\n"
    printf "\t--filesize 1g \t\tCustomize filesize (default=1g)\n"
    printf "\t--iodepth 32\t\tCustomize the iodepth (default=8)\n\t\t\t\t(only relevant for async io engines)\n"
    printf "\t--ioengine psync\tSelect the fio ioengine (default=libaio)\n"
    printf "\t--disable-iops \t\tDisable run random iops tests\n"
    printf "\t--disable-bw \t\tDisable run bw tests\n"
    printf "\t--mixed-workloads\tUse mixed workloads (read & write in //)\n"
    printf "\t--mw-iops-mixread\t%% of mixed rand iops workload that should be reads (default: 50)\n"
    printf "\t--mw-bw-mixread\t\t%% of mixed bw workload that should be reads (default: 50)\n"
    printf "\n\t\t\tSystem options\n\n"
    printf "\t--offline|-o\t\tUse pre-built docker image (no internet needed)\n"
    printf "\t--disable-copy-id\tDisable use ssh-copy-id\n"
    printf "\t--disable-docker\tDisable use docker\n"
    printf "\t--disable-src\t\tDisable compile fio from src\n"
    printf "\t--disable-job-check\tDisable check fio_jobs/*.job files\n"
    printf "\t--disable-exa-drop\tDisable drop the EXA VMs cache ⚠\n"
    printf "\t--disable-mount-check\tDisable check path is a lustre mount point ⚠\n"
    printf "\t--disable-set-thp \tDisable set transparent huge pages =always\n\t\t\t\t(if already set to always, won't change its state)\n"
    printf "\t--disable-recompile \tDisable compilation of fio if already compiled\n\t\t\t\t(only with --disable-docker)\n"
    printf "\t--numa-binding-0 6\tSelect a NUMA domain to bind to (default=no binding)\n"
    printf "\t--numa-binding-1 8\tSelect a 2d NUMA domain to bind to (creates one fio job per NUMA domain)\n"
    printf "\t--deploy-path\t\tCustomize mult. clients deployment path(default=/tmp) ⚠\n"
    printf "\t\t\t\t(This directory must be a unique and cleared location per client)\n"
    printf "\t\t\t\t(It shoulnd't be this script directory nor a shared location)\n"
    echo ""
    echo "EXA Client Performance Validation contact: ldouriez@ddn.com"
    echo ""
}
check_is_a_positive_int()
{
    int_regex='^[0-9]+$'
    if ! [[ $1 =~ $int_regex ]] ; then
        echo_error_tips "Wrong $2 argument ($1), should be a positive int" \
			"Check the arguments in the commandline you used"
        exit 1
    fi
}
check_is_a_positive_percentage()
{
    int_regex='^(100|[0-9]?[0-9])$'
    if ! [[ $1 =~ $int_regex ]] ; then
        echo_error_tips "Wrong $2 argument ($1), should be a positive percentage between 0 and 100 (without %)" \
			"Check the arguments in the commandline you used"
        exit 1
    fi
}

check_is_a_positive_iosize()
{
    iosize_regex='^[0-9]+(K|M|G|k|m|g)*$'
    if ! [[ $1 =~ $iosize_regex ]] ; then
        echo_error_tips "Wrong $2 argument ($1), should be a positive iosize" \
			"Check the arguments in the commandline you used"
        exit 1
    fi
}

sighdl ()
{
    echo_fio "Exiting EXA Client Performance Validation..."
    if [ "$use_docker" = 'y' ] ; then
        docker container kill \
        $(docker ps -a -q --filter="ancestor=exa_client_performance_validation") \
        > /dev/null 2>&1 || true
        docker container rm \
        $(docker ps -a -q --filter="ancestor=exa_client_performance_validation") \
        > /dev/null 2>&1 || true
        docker container kill $(docker ps  |grep fio_server |awk '{print $1}'|xargs) >  /dev/null  2>&1 || true
        docker container rm $(docker ps  |grep fio_server |awk '{print $1}'|xargs) > /dev/null 2>&1 || true
    fi
    exit 0
}
trap sighdl SIGINT

# Process arguments if there is any
date=`date +%d-%m-%y-%H-%M-%S`
mountpoint=/exa_filesystem
use_copy_id=y
use_docker=y
use_src_fio=y
drop_exa_cache=y
use_offline_docker_image=n
master_with_mult_client=n
njobs=$(nproc)
do_iops=y
do_job_check=y
do_bw=y
fio_always_recompile=y
ioengine=libaio
iodepth=8
ioengine_checked=n
do_set_thp=y
do_mount_check=y
nb_clients=1
numa_count=0
runtime=30s
ramptime=10s
filesize=1g
blocksize=1M
start_server=n
verbose_mode=n
multiple_clients_mode=n
all_clients="JOB"
sudo_client=""
deployment_path=/tmp
custom_deployment_path='n'
perf_valid_checksum='✔'
actions_status='✔'
numa_mode=n
fio_job_folder="fio_jobs"
mixed_workloads=n
mwbwmixread=50
mwiopsmixread=50

for action in clientcache exacache exatuning ; do
    for iotype in read write randread randwrite mixed_workload mixed_workload_rand ; do
        eval "${action}_${iotype}_status='✔'"
    done
done

if [ $# -gt 0 ] ; then
    ! getopt --test > /dev/null
    if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
        echo_warning '`getopt --test` failed in this environment. Cannot process arguments'
        exit 1
    fi
    OPTIONS=hm:op:v
    LONGOPTS=numa-binding-0:,numa-binding-1:,offline,help,mountpoint:,processes:,disable-iops,disable-bw,runtime:,ramptime:,disable-set-thp,disable-mount-check,clients:,start-server,disable-docker,deploy-path:,verbose,disable-copy-id,ioengine:,disable-job-check,disable-src,disable-exa-drop,blocksize:,filesize:,mixed-workloads,mw-iops-mixread:,mw-bw-mixread:,disable-recompile,iodepth:
    RAWPARAMS="$@"
    ! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit 2
    fi
    eval set -- "$PARSED"
    while true; do
        case "$1" in
            -h|--help)
                print_usage
                exit 0
            ;;
            -v|--verbose)
                verbose_mode=y
                shift
            ;;
            -o| --offline)
                use_offline_docker_image=y
                shift
            ;;
            -m| --mountpoint)
                mountpoint="$2"
                # Remove last / characters except if mountpoint is /
                mountpoint="$(echo "$mountpoint" |sed 's@\(.\)/\+$@\1@g')"
                shift 2
	    ;;
	    --mixed-workloads)
		mixed_workloads=y
		shift
		;;
	    --mw-bw-mixread)
		check_is_a_positive_percentage $2 --mw-bw-mixread
		mwbwmixread="${2}"
		shift 2
		;;
	    --mw-iops-mixread)
		check_is_a_positive_percentage $2 --mw-iops-mixread
		mwiopsmixread="${2}"
		shift 2
	    ;;
            --ioengine)
                ioengine="${2}"
                shift 2
		;;
            --iodepth)
                iodepth="${2}"
                shift 2
		;;	    
            --runtime)
                check_is_a_positive_int $2 --runtime
                runtime="${2}s"
                shift 2
            ;;
            --ramptime)
                check_is_a_positive_int $2 --ramptime
                ramptime="${2}s"
                shift 2
            ;;
            --disable-src)
                use_src_fio=n
                shift
            ;;
            --disable-iops)
                do_iops=n
                shift
            ;;
            --disable-bw)
                do_bw=n
                shift
            ;;
            --disable-job-check)
                do_job_check=n
                shift
            ;;
            --disable-copy-id)
                use_copy_id=n
                shift
            ;;
            --disable-exa-drop)
                drop_exa_cache=n
                shift
            ;;
            --disable-mount-check)
                do_mount_check=n
                shift
            ;;
            --disable-docker)
                use_docker=n
                shift
            ;;
            --disable-set-thp)
                do_set_thp=n
                shift
		;;
            --disable-recompile)
                fio_always_recompile=n
                shift
		;; 
            --deploy-path)
		custom_deployment_path='y'
                deployment_path="${2}"
                shift 2
            ;;
            -p| --processes)
                check_is_a_positive_int $2 --processes
                njobs="${2}"
                shift 2
            ;;
            --clients)
                clients="${2}"
                if [ "x$clients" = "x" ]; then
                    echo_error_tips "Client list empty" "Remove --clients OR add client(s)"
                    echo_tips "e.g: --clients \"localhost DGXA100-01 DGXA100-02\""
                    exit 1
                fi
                nb_clients=0
                multiple_clients_mode=y
                # Delete 'root@' and keep only IP for fio cmd
                for c in $clients ; do
                    all_clients="$all_clients --client $(echo $c|sed "s/.*@//g"| sed 's/#$//g')"
                    if echo "$c" |grep -q '#$' ; then
                        sudo_client="$sudo_client $(echo $c|sed "s/.*@//g"| sed 's/#$//g')"
                    fi
                    nb_clients=$((nb_clients+1))
                done
                # Delete '#' (sudo)
                length=${#clients[@]}
                clients=$(echo $clients |sed -E 's@([^ ]+)#([[:space:]]|$)@\1\2@g')
                shift 2
            ;;
             --filesize)
                check_is_a_positive_iosize "$2" --filesize
                filesize="${2}"
                shift 2
            ;;
             --blocksize)
                check_is_a_positive_iosize "$2" --blocksize
                blocksize="${2}"
                shift 2
            ;;
            --start-server)
                start_server=y
                shift
            ;;
            --numa-binding-0)
                check_is_a_positive_int $2 --numa-binding-0
                numa_mode=y
                numa_binding_0="${2}"
                shift 2
            ;;
            --numa-binding-1)
                check_is_a_positive_int $2 --numa-binding-1
                numa_mode=y
                numa_binding_1="${2}"
                shift 2
            ;;
            --)
                shift
                break
            ;;
            *)
                echo "Programming error"
                exit 3
            ;;
        esac
    done
fi

# Fix DDN-4211 misuse of the script where the propagated/deployed version of the script is used manually
# If we didn't use --start-server option and there is no file_creation, chances are high that we're running the propagated archive manually
if [ "$start_server" = 'n' ] ; then
    if ! [ -f fio_jobs/file_creation.job ] ; then
	echo_error_tips "No fio_jobs/file_creation.job" \
			"The archive you're using seems to have been propagated. The propagated archive can't be used manually"
	echo_tips "NEVER use the propagated archive manually"
	echo_tips "If the archive wasn't propagated there are missing file(s) that makes it unusable. You have to find a new one."
	exit 1
    fi
    if [ "${multiple_clients_mode}" = 'y' ] && [ '${custom_deployment_path}' = 'y' ] ; then
	echo_fio "Deploy path option set"
	echo_warning "You used the --deploy-path option: ${deployment_path}"
	echo_warning "Please make sure:"
	echo_warning "DON'T use a shared location"
	echo_warning "DON'T use this script location"
	echo_warning "DON'T use this option if you are unsure"
	echo_tips "This option is not mandatory!"
	echo_tips "You might consider removing it (default is /tmp)"
    fi
fi

if [ -n "${numa_binding_1}" ] && [ -z "${numa_binding_0}" ]; then
    echo_error_tips "'--numa-binding-0' is mandatory when used with '--numa-binding-1'" \
		    "Add --numa-binding-0 <numanode> OR remove --numa-binding-1"
    exit 1
fi

if [ "$numa_mode" = 'y' ] && [ "$use_docker" = 'y' ] ; then
    echo_error_tips "docker must be disabled with NUMA binding" \
		    "Try with --disable-docker OR remove --numa-binding-*"
    exit 1
fi

if [ "$numa_mode" = 'y' ] && [ "$mixed_worloads" = 'y' ] ; then
    echo_error_tips "mixed workloads with NUMA binding is not supported" \
		    "Remove --mixed-workloads OR remove --numa-binding-*"
    exit 1
fi

if [ -n "${numa_binding_0}" ]; then
    numa_count=1
    if [ -n "${numa_binding_1}" ]; then
        numa_count=2
    fi
fi

if [ "$numa_mode" = 'y' ]  ; then
    fio_job_folder="fio_jobs/numa_count_${numa_count}"
fi

if ! [ "$start_server" = 'y' ] ; then
    echo_fio "Setup..."
    echo_custom "Check archive checksum"
    if ! command -v md5sum &> /dev/null ; then
        echo_warning "Can't find md5sum to verify checksum"
        echo_tips "Install md5sum"
        perf_valid_checksum='⚠'
        elif ! md5sum -c checksums &>/dev/null ; then
        echo_warning "Archive checksum is invalid"
        perf_valid_checksum='✖'
    fi


    echo_custom "Create log directory on master"
    if ! mkdir -p results ; then
        echo_error_tips "Can't create $PWD/results directory" "Make sure you have the correct rights"
        exit 1
    fi
fi

echo_custom "Kill fio server"
pkill -9 fio &> /dev/null
if command -v docker &> /dev/null ; then
    echo_custom "Cleanup fio containers"
    docker container kill $(docker ps -a -q --filter="ancestor=exa_client_performance_validation" 2>/dev/null) >  /dev/null  2>&1 || true
    docker container rm $(docker ps -a -q --filter="ancestor=exa_client_performance_validation" 2>/dev/null) > /dev/null 2>&1 || true
    docker container kill $(docker ps 2>/dev/null |grep fio_server |awk '{print $1}'|xargs) >  /dev/null  2>&1 || true
    docker container rm $(docker ps 2>/dev/null |grep fio_server |awk '{print $1}'|xargs) >  /dev/null  2>&1 || true
fi

# 1. Try with docker
# 2. Try with sources src-compile (if --disable-docker)
# 3. Try with path  (if --disabled-docker && --disabled-src-compile-fio)
if [ "$use_docker" = 'y' ]  ; then
    setup_fio_docker_image
else
    # If we don't use docker, we might compile fio or use the one in PATH
    if [ "$use_src_fio" = 'y' ] ; then
	if [ "$fio_always_recompile" = 'y' ] || { [ "$fio_always_recompile" = 'n' ] && ! [ -f $PWD/fio-3.35/fio ]; } ; then
		compile_fio_from_src_locally
	fi
	# Use fio bin
	export PATH=$PWD/fio-3.35/:$PATH	
    fi
    # If we use PATH or compiled fio, check binary is there
    check_fio_is_available_in_path
fi


# Master only
# 1) master copy files to other clients
# 2) master ask other clients to start fio server
# 3) If every client was able to start its server, master continue
if [ "$multiple_clients_mode" = 'y' ] ; then
    if ! [ "$start_server" = 'y' ] ; then
        master_with_mult_client=y
        if ! copy_archive_on_clients "$clients" ; then
            echo_error_tips "Can't copy archive to other clients" \
			    "Check clients messages"
            exit 1
        fi
        if ! run_fio_server_on_clients "$clients" "$RAWPARAMS" ; then
            echo_error_tips "Can't run fio --server on other clients" \
		       "Check clients messages"
            exit 1
        fi
        echo_fio "All clients ready!"
    fi
fi

if [ "$master_with_mult_client" = 'n' ] ; then
    if [ "$do_mount_check" = 'y' ]  ; then
        echo_custom  "Verify mountpoint"
        if ! mount -t lustre |grep -q "[[:space:]]${mountpoint}[[:space:]]" ; then
            echo_error_tips "Please mount exa filesystem at ${mountpoint}" \
			    "You can try with -m /my/exa/filesystem OR --disable-mount-check"
            exit 1
        fi
    fi
fi


if [ "$master_with_mult_client" = 'n' ] ; then
    echo_custom "Create fio output directory ${mountpoint}"
    # Create output directory for both fio and logs
    if ! mkdir -p results ; then  echo_error_tips "Can't create $PWD/results/" "Check that you have the correct permissions" ; exit 1 ; fi
    if ! [ -d ${mountpoint}/client_validation ] ; then
        if ! mkdir -p -m 777 ${mountpoint}/client_validation ; then
            echo_error_tips "Can't create ${mountpoint}/client_validation/" "Check that you have the correct permissions" ;  exit 1
        fi
    fi

    echo_custom "Set aio-max-nr=$((2**17))"
    # Tune client
    if ! (echo $((2**17)) > /proc/sys/fs/aio-max-nr) > /dev/null 2>&1 &&
    ! (( $(cat /proc/sys/fs/aio-max-nr 2>/dev/null) == 2**17 )) &> /dev/null ; then
        echo_warning "Unable to set aio-max-nr=$((2**17)) (current val: $(cat /proc/sys/fs/aio-max-nr 2>/dev/null))"
        echo_tips "Try to run with sudo?"
    fi

    if [ "$do_set_thp" = 'y' ]  ; then
        echo_custom "Enable transparent huge pages"
        if [ -f /sys/kernel/mm/transparent_hugepage/enabled ] ; then
            if !  (echo always > /sys/kernel/mm/transparent_hugepage/enabled) > /dev/null 2>&1 &&
            ! $(cat /sys/kernel/mm/transparent_hugepage/enabled |grep -q '\[always\]') ; then
                echo_warning "Unable to set THP=always (current val: $(cat /sys/kernel/mm/transparent_hugepage/enabled))"
                echo_tips "Try to run with sudo?"
            fi
        else
            echo_warning "Unable to set THP=always (file doesn't exit)"
        fi
    fi

    if [ "$start_server" = 'y' ] ; then
        echo_custom "Start fio servers (remote clients only)"
        if ! run_fio_server_locally ; then
            echo_error_tips "Can't run fio server" \
			    "Check client logs"
            exit 1
        else
            exit 0
        fi
    fi
fi

echo_custom "Remote clients stop there"
echo_custom "Below is only running on master"
echo_custom "Check fio_jobs/*.job files for discrepancy"
update_variable_based_on_manual_changes size "filesize"
update_variable_based_on_manual_changes numjobs "njobs"
update_variable_based_on_manual_changes iodepth "iodepth"
if ! update_variable_based_on_manual_changes ioengine "ioengine" ; then
    echo_warning "ioengine wasn't verified (set to unknown)"
else
    ioengine_checked=y
fi

# Create files
echo_fio "Creating files..."
if [ "$use_docker" = 'y' ]  ; then
    docker run -e runtime=${runtime} -e ramptime=${ramptime} \
    -e njobs=${njobs} -e mountpoint=/fio_output -e ioengine=${ioengine} -e iodepth=${iodepth} -e filesize=${filesize}\
    --net=host --name fio_create -v "${PWD}/fio_jobs":/fio_jobs -v "${mountpoint}":/fio_output exa_client_performance_validation \
    bash -c "fio $(echo ${all_clients}|sed 's@JOB@/fio_jobs/file_creation.job@g') " > file_creation.log 2>&1
    exitcode=$?
else
    runtime=${runtime} ramptime=${ramptime} njobs=${njobs} mountpoint=${mountpoint} ioengine=${ioengine} iodepth=${iodepth} filesize=${filesize} \
    fio $(echo ${all_clients}|sed 's@JOB@fio_jobs/file_creation.job@g') > file_creation.log  2>&1
    exitcode=$?
fi

if cat file_creation.log |grep -q -E "engine.*not[[:space:]]+loadable" ; then
    echo_warning "File creation may have failed! fio engine not loadable"
    if cat file_creation.log |grep -q -E "engine.*libaio.*not[[:space:]]+loadable" ; then
        echo_tips "Make sure fio has support for libaio (see libaio-devel package) OR use --ioengine psync"
    else
        echo_tips "Try with --ioengine? (list of engine: https://fio.readthedocs.io/en/latest/fio_doc.html#i-o-engine)"
    fi
fi

if cat file_creation.log | grep -q -E "bad server cmd version" ; then
    echo_error_tips "fio version mismatch between server and some clients" \
		    "try without --disable-docker --disable-src"
    exit 1
fi

if ! [ $exitcode -eq 0 ] ; then
    echo_error_tips "File creation exited abnormally" "see $PWD/file_creation.log"
    exit 1
fi

# BW
if [ "$do_bw" = 'y' ] ; then
    echo_custom "Run bandwidth test"
    if [ "$mixed_workloads" = 'y' ] ; then
	iotypelist=("mixed_workload")
    else
	iotypelist=("read" "write")	
    fi
    for iotype in ${iotypelist[@]} ; do
        echo_fio "Running ${iotype} throughtput test (runtime ${runtime}, ramptime ${ramptime})..."
        drop_cache "$clients"
        echo_custom "Run bandwidth ${iotype} test"
        eval "start_bw_${iotype}=\$(date +%s)"
        if [ "$use_docker" = 'y' ]  ; then
            docker run -e runtime=${runtime} -e ramptime=${ramptime} \
            -e njobs=${njobs} -e mountpoint=/fio_output -e ioengine=${ioengine} -e iodepth=${iodepth} -e filesize=${filesize} -e blocksize=${blocksize} \
            -e numa_binding_0=${numa_binding_0} -e numa_binding_1=${numa_binding_1} -e mwiopsmixread=${mwiopsmixread} -e mwbwmixread=${mwbwmixread} \
            --net=host \
            --name fio_${iotype} -v "${PWD}/${fio_job_folder}":/fio_jobs -v "${mountpoint}":/fio_output --rm exa_client_performance_validation \
            bash -c "fio $(echo ${all_clients}|sed "s@JOB@/fio_jobs/${iotype}_BW.job@g")" \
            &> results/fiobw_test_${njobs}jobs-${blocksize}_${iodepth}_${ioengine}_${filesize}_${iotype}_${date}.log
            exitcode=$?
        else
            runtime=${runtime} ramptime=${ramptime} njobs=${njobs} mountpoint=${mountpoint} ioengine=${ioengine} iodepth=${iodepth} filesize=${filesize} blocksize=${blocksize} \
            numa_binding_0=${numa_binding_0} numa_binding_1=${numa_binding_1} mwbwmixread=${mwbwmixread} mwiopsmixread=${mwiopsmixread} \
            fio $(echo ${all_clients}|sed "s@JOB@${fio_job_folder}/${iotype}_BW.job@g") \
            &> results/fiobw_test_${njobs}jobs-${blocksize}_${iodepth}_${ioengine}_${filesize}_${iotype}_${date}.log
            exitcode=$?
        fi
        eval "stop_bw_${iotype}=\$(date +%s)"
        if ! [ $exitcode -eq 0 ]  ; then
            echo_error_tips "BW ${iotype} exited abnormally" \
			    "See $PWD/results/fiobw_test_*_${iotype}_${date}.log"
            exit 1
        fi

        if cat results/fiobw_*_${iotype}_${date}.log \
        |& grep -q -E -i "failed[[:space:]]+to[[:space:]]+connect[[:space:]]+to" ; then
            echo_warning "fio may have failed (failed to connect to)"
            echo_tips "Make sure firewall is disabled on each client"
        fi
        if cat results/fiobw_*_${iotype}_${date}.log \
        |& grep -q -E -i "Build fio with libnuma-dev(el) to enable this option" ; then
            echo_error_tips "fio may have failed due to missing numactl-devel/libnuma-dev(el) lib" \
		       "Make sure fio was compiled with numactl-devel/libnuma-dev(el) OR remove --numa-binding-* option(s)"
	    exit 1
        fi
        if cat results/fiobw_*_${iotype}_${date}.log \
        |& grep -q -E -i "numa_parse_nodestring failed" ; then
            echo_error_tips "fio may have failed due to wrong numa node selected" \
		       "Check the numa node used OR remove --numa-binding-* option(s)"
	    exit 1
        fi

    done
fi

# IOPS
if [ "$do_iops" = 'y' ] ; then
    echo_custom "Run IOPS test"
    if [ "$mixed_workloads" = 'y' ] ; then
	iotypelist=("mixed_workload_rand")
    else
	iotypelist=("randread" "randwrite")	
    fi    
    for iotype in ${iotypelist[@]} ; do
        echo_fio "Running ${iotype} IOPS test (runtime ${runtime}, ramptime ${ramptime})..."
        drop_cache "$clients"
        echo_custom "Run IOPS ${iotype} test"
        eval "start_iops_${iotype}=\$(date +%s)"
        if [ "$use_docker" = 'y' ]  ; then
            docker run -e runtime=${runtime} -e ramptime=${ramptime} \
            -e njobs=${njobs} -e mountpoint=/fio_output -e ioengine=${ioengine} -e iodepth=${iodepth} -e filesize=${filesize} \
            -e numa_binding_0=${numa_binding_0} -e numa_binding_1=${numa_binding_1} -e mwiopsmixread=${mwiopsmixread} -e mwbwmixread=${mwbwmixread} \
            --net=host --name fio_${iotype} \
            -v "${PWD}/${fio_job_folder}":/fio_jobs -v "${mountpoint}":/fio_output --rm exa_client_performance_validation \
            bash -c "fio $(echo ${all_clients}|sed "s@JOB@/fio_jobs/${iotype}_iops.job@g")" \
            &> results/fioiops_test_${njobs}jobs-4k_${iodepth}_${ioengine}_${filesize}_${iotype}_${date}.log
            exitcode=$?
        else
            runtime=${runtime} ramptime=${ramptime} njobs=${njobs} mountpoint=${mountpoint} ioengine=${ioengine} iodepth=${iodepth} filesize=${filesize} \
            numa_binding_0=${numa_binding_0} numa_binding_1=${numa_binding_1} mwbwmixread=${mwbwmixread} mwiopsmixread=${mwiopsmixread} \
            fio $(echo ${all_clients}|sed "s@JOB@${fio_job_folder}/${iotype}_iops.job@g") \
            &> results/fioiops_test_${njobs}jobs-4k_${iodepth}_${ioengine}_${filesize}_${iotype}_${date}.log
            exitcode=$?
        fi
        eval "stop_iops_${iotype}=\$(date +%s)"
        if ! [ $exitcode -eq 0 ] ; then
            echo_error_tips "IOPS ${iotype} exited abnormally" \
			    "See $PWDresults/fioiops_test_*_${iotype}_${date}.log"
            exit 1
        fi

        if cat results/fioiops_*_${iotype}_${date}.log \
        |& grep -q -E -i "failed[[:space:]]+to[[:space:]]+connect[[:space:]]+to" ; then
            echo_warning "fio may have failed (failed to connect to)"
            echo_tips "Make sure firewall is disabled on each client"
        fi
        if cat results/fioiops_*_${iotype}_${date}.log \
        |& grep -q -E -i "Build fio with libnuma-dev(el) to enable this option" ; then
            echo_error_tips "fio may have failed due to missing numactl-devel/libnuma-dev(el) lib" \
			    "Make sure fio was compiled with numactl-devel/libnuma-dev(el) OR remove --numa-binding-* option(s)"
	    exit 1
        fi
        if cat results/fioiops_*_${iotype}_${date}.log \
        |& grep -q -E -i "numa_parse_nodestring failed" ; then
            echo_error_tips "fio may have failed due to wrong numa node selected" \
			    "Check the numa node used OR remove --numa-binding-* option(s)"
	    exit 1
        fi	
    done
fi

if [ "$multiple_clients_mode" = 'y' ] ; then
    cleanup_fio_servers "${clients}"
fi

printf "\n"

# Print results
resREAD="NA"
resWRITE="NA"
resRANDREAD="NA"
resRANDWRITE="NA"
resREAD_WALLCLOCK="NA"
resWRITE_WALLCLOCK="NA"
resRANDREAD_WALLCLOCK="NA"
resRANDWRITE_WALLCLOCK="NA"

if [ "$do_bw" = 'y' ] ; then
    # Check BW results
    if (( nb_clients > 1 )) ; then
	if [ "$mixed_workloads" = 'n' ] ; then
            resREAD=$(cat results/fio*_read*${date}.log |grep -A 1 "All clients" |grep "read" | grep -E -o '\([0-9]+\.?[0-9]*[a-zA-Z]+/?s?\)' | sed -E 's@(\(|\))@@g')
            resWRITE=$(cat results/fio*_write*${date}.log | grep -A 1 "All clients" |grep "write" | grep -E -o '\([0-9]+\.?[0-9]*[a-zA-Z]+/?s?\)' | sed -E 's@(\(|\))@@g')
	else
            resREAD=$(cat results/fio*_mixed_workload_${date}.log |grep -A 1 "All clients" |grep "read" | grep -E -o '\([0-9]+\.?[0-9]*[a-zA-Z]+/?s?\)' | sed -E 's@(\(|\))@@g')
            resWRITE=$(cat results/fio*_mixed_workload_${date}.log |grep -A 10 "All clients" |grep "write" | grep -E -o '\([0-9]+\.?[0-9]*[a-zA-Z]+/?s?\)' | sed -E 's@(\(|\))@@g')
	fi
    else
	if [ "$mixed_workloads" = 'n' ] ; then
            resREAD=$(tail -n 8 results/fio*_read*${date}.log | grep READ | grep -E -o '\([0-9]+\.?[0-9]*[a-zA-Z]+/s\)' | sed -E 's@(\(|\))@@g')
            resWRITE=$(tail -n 8 results/fio*_write*${date}.log | grep WRITE | grep -E -o '\([0-9]+\.?[0-9]*[a-zA-Z]+/s\)' | sed -E 's@(\(|\))@@g')
	else
            resREAD=$(tail -n 12 results/fio*_mixed_workload_${date}.log | grep READ | grep -E -o '\([0-9]+\.?[0-9]*[a-zA-Z]+/s\)' | sed -E 's@(\(|\))@@g')
            resWRITE=$(tail -n 12 results/fio*_mixed_workload_${date}.log | grep WRITE | grep -E -o '\([0-9]+\.?[0-9]*[a-zA-Z]+/s\)' | sed -E 's@(\(|\))@@g')
	fi
    fi
    if [ "$mixed_workloads" = 'n' ] ; then
	resREAD_WALLCLOCK=$(echo "$stop_bw_read $start_bw_read" | awk '{ printf "%ds", $1-$2}')
	resWRITE_WALLCLOCK=$(echo "$stop_bw_write $start_bw_write" | awk '{ printf "%ds", $1-$2}')
    else
	resREAD_WALLCLOCK=$(echo "$stop_bw_mixed_workload $start_bw_mixed_workload" | awk '{ printf "%ds", $1-$2}')
	resWRITE_WALLCLOCK=${resREAD_WALLCLOCK}
    fi
fi

if [ "$do_iops" = 'y' ] ; then
    # Check IOPS results
    if (( nb_clients > 1 )) ; then
	if [ "$mixed_workloads" = 'n' ] ; then	
            resRANDREAD=$(cat  results/fioiops_*randread*${date}.log | grep -A 1 "All clients" |grep -o "read: IOPS=.*" |grep -o -E "[0-9]+\.?[0-9]*[a-zA-Z]*," |tr -d ',')
            resRANDWRITE=$(cat results/fioiops_*randwrite*${date}.log |grep -A 1 "All clients" |grep -o "write: IOPS=.*" |grep -o -E "[0-9]+\.?[0-9]*[a-zA-Z]*," |tr -d ',')
	else
	    resRANDREAD=$(cat  results/fioiops_*mixed_workload_rand_${date}.log | grep -A 1 "All clients" |grep -o "read: IOPS=.*" |grep -o -E "[0-9]+\.?[0-9]*[a-zA-Z]*," |tr -d ',')
            resRANDWRITE=$(cat  results/fioiops_*mixed_workload_rand_${date}.log | grep -A 10 "All clients" |grep -o "write: IOPS=.*" |grep -o -E "[0-9]+\.?[0-9]*[a-zA-Z]*," |tr -d ',')
	fi
    else
	if [ "$mixed_workloads" = 'n' ] ; then	
            resRANDREAD=$(cat results/fioiops_*randread*${date}.log |grep -o "read: IOPS=.*" |grep -o -E "[0-9]+\.?[0-9]*[a-zA-Z]*," |tr -d ',')
            resRANDWRITE=$(cat results/fioiops_*randwrite*${date}.log |grep -o "write: IOPS=.*" |grep -o -E "[0-9]+\.?[0-9]*[a-zA-Z]*," |tr -d ',')
	else
	    resRANDREAD=$(cat results/fioiops_*mixed_workload_rand_${date}.log |grep -o "read: IOPS=.*" |grep -o -E "[0-9]+\.?[0-9]*[a-zA-Z]*," |tr -d ',')
	    resRANDWRITE=$(cat results/fioiops_*mixed_workload_rand_${date}.log |grep -o "write: IOPS=.*" |grep -o -E "[0-9]+\.?[0-9]*[a-zA-Z]*," |tr -d ',')
	fi
    fi
    if [ "$mixed_workloads" = 'n' ] ; then    
	resRANDREAD_WALLCLOCK=$(echo "$stop_iops_randread $start_iops_randread" | awk '{ printf "%ds", $1-$2}')
	resRANDWRITE_WALLCLOCK=$(echo "$stop_iops_randwrite $start_iops_randwrite" | awk '{ printf "%ds", $1-$2}')
    else	
	resRANDREAD_WALLCLOCK=$(echo "$stop_iops_mixed_workload_rand $start_iops_mixed_workload_rand" | awk '{ printf "%ds", $1-$2}')
	resRANDWRITE_WALLCLOCK=${resRANDREAD_WALLCLOCK}
    fi
fi

for action in clientcache exacache exatuning ; do
    for iotype in read write randread randwrite mixed_workload mixed_workload_rand ; do
        if !  [ "$(eval "echo \$${action}_${iotype}_status")" = '✔' ] ; then
            actions_status='⚠'
            break
        fi
    done
    if [ "$actions_status" = '⚠' ] ; then break ; fi
done

echo "------------------------------------------------------------------"
printf "|%40s %24s\n" "Results summary" "|"
printf "|%54s %14s\n" "actions ${actions_status} ,  archive checksum ${perf_valid_checksum}" "|"
echo "------------------------------------------------------------------"
printf "|%12s|%12s|%12s|%12s|%12s|\n" "v1.1.9   " "Read BW  " "Write BW  " "Read IOPS  " "Write IOPS "
printf "|%12s|%12s|%12s|%12s|%12s|\n" "Performance " " $resREAD" "$resWRITE" "$resRANDREAD" "$resRANDWRITE"
printf "|%12s|%12s|%12s|%12s|%12s|\n" "Total time  " " ${resREAD_WALLCLOCK}" "${resWRITE_WALLCLOCK}" \
"${resRANDREAD_WALLCLOCK}" "${resRANDWRITE_WALLCLOCK}"
echo "------------------------------------------------------------------"
printf " %s \n" "Logs: results/fio*${date}"
printf " %s \n" "Hostname: $(hostname)"
printf " %s \n" "Fio ioengine: $(if [ $ioengine_checked = 'y' ] ; then echo ${ioengine} ; else echo unknown ; fi)"
printf " %s \n" "Options used: $PARSED"
printf "\n"
