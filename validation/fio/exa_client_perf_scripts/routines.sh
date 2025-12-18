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

echo_warning()
{
    printf "\t%2s %10s: %s\n" "⚠" "$(hostname)" "$1"
}
echo_error_tips()
{
    printf "\t%2s %10s: %s\n" "✖" "$(hostname)" "$1"
    printf "\t\t%2s %10s: %s\n" "ℹ" "$(hostname)" "$2"
}
echo_tips()
{
    printf "\t\t%2s %10s: %s\n" "ℹ" "$(hostname)" "$1"
}
echo_fio()
{
   printf "%2s %10s: %s\n" "▶" "$(hostname)" "$1"
}
echo_custom()
{
    if [ "$verbose_mode" = 'y' ] ; then
	printf "\t%1s %10s: %s\n" "" "$(hostname)" "$1"
    fi
}
single_client_mode()
{
    if (( nb_clients == 1 )) && [ "$master_with_mult_client" = 'n' ] ; then
	return 0
    else
	return 1
    fi
}

run_cmd_on_clients()
{
    # Run a command on clients
    # - Input0: list of clients
    # - Input1: command to run
    # - Input3(optional): disable sudo
    # The variable \${user_deploy_path} can be used in Input1
    # Sudo are handled there
    # This function must be used to run cmds on all clients

    local client_list="$1"
    local non_sudo=""
    local sudocmd="sudo"

    # Disable sudo
    if [ $# -ge 3 ] ; then
	sudocmd=""
    fi

    if single_client_mode ; then
	if ! bash -c "$2" ; then
	    echo_warning "$2 failed ($(hostname))"
	    return 1
	fi
	return 0
    fi

    # Run sudo cmds first
    for client in ${client_list} ; do
	if client_is_sudo "$client" ; then
	    export user_deploy_path="$(find_user_deploy_path "$client")"
	    cmd=$(echo "$2" 2>/dev/null|sed 's@\$@\\$@g')
	    if ! ssh $client -t -q \
		 ''"${sudocmd}"' bash -c "export user_deploy_path='"${user_deploy_path}"' ; '"$cmd"'"' ; then
		echo_warning "$2 failed on ($client, sudo)"
		return 1
	    fi
	else
	    non_sudo="$(echo $non_sudo ${client}|sed -E "s@^[[:space:]]+@@g")"
	fi
    done

    # Nothing else to do
    if [ -z "$non_sudo" ] ; then
	return 0
    fi

    # Run with ssh
    if ! command -v clush &> /dev/null ||
	    ! [ "$use_copy_id" = 'y' ] ; then
	for client in ${non_sudo[@]} ; do
	    if ! ssh $client -t -q \
		 "export user_deploy_path=${deployment_path}/exa_client_performance_validation_\${USER} ; $2" ; then
		echo_warning "$2 failed ($client)"
		return 1
	    fi
	done
    else
	# Run with clush
	first_client=$(echo ${client_list} |awk '{print $1}')
	if ! clush -q -w $(echo "$non_sudo"|tr ' ' ',') -S -N \
	     "export user_deploy_path=${deployment_path}/exa_client_performance_validation_\${USER} ; $2" ; then
	    echo_warning "$2 failed (clush, $(echo "$non_sudo"|tr ' ' ','))"
	    return 1
	fi
	   
    fi
    return 0
}
client_is_sudo()
{
    local c=$1
    for s in ${sudo_client[@]} ; do
	if [ "$(echo $c|sed "s/.*@//g"| sed 's/#$//g')" == "$s" ] ; then
	    return 0
	fi
    done
    return 1
}
find_user_deploy_path()
{
    local client="$1"
    local sudo_suffix=""

    if client_is_sudo $client ; then
	sudo_suffix="_sudo"
    fi

    if ! echo "$client" |grep -q "@" ; then
	echo "${deployment_path}/exa_client_performance_validation_${USER}${sudo_suffix}"
    else
	echo "${deployment_path}/exa_client_performance_validation_$(printf "$client" |grep -o -E "^.*@" 2>/dev/null |sed "s/@//g")${sudo_suffix}"
    fi
}
find_mgs_ip()
{
    local client="$1"

    if single_client_mode ; then
	echo $(mount -t lustre \
	    |grep -m1 "[[:space:]]${mountpoint}[[:space:]]" \
	    |grep -E -o "^([0-9]+\.){3}[0-9]+")
    else
    	#Mult. clients mode
	ssh ${client} \
	    "echo $(mount -t lustre|grep -m1 "[[:space:]]${mountpoint}[[:space:]]"|grep -E -o "^([0-9]+\.){3}[0-9]+")"
    fi
}

copy_archive_on_clients()
{
    # Copy scripts and packages to distant clients
    #
    # - Input0: list of clients with ssh prefix and no # suffix
    # e.g: root@dgx1 myuser@dgx2
    # - Output: 0 on success (all files are copied), 1 otherwise
    #
    # Delegate commands to run_cmd_on_clients
    # e.g: run_cmd_on_clients "root@dgx1 myuser@dgx2" "ls"
    #
    # The file are copied at 'user_deploy_path'
    # which is a variable handled and defined by run_cmd_on_clients
    #

    local client_list="$1"
    local copycmd="rsync"

    if [ "$use_docker" = 'y' ]  && [ "$use_offline_docker_image" = 'y' ] ; then
	copycmd="rsync --progress"
    fi

    if [ "$use_copy_id" = 'y' ] ; then
	for c in ${client_list} ; do
	    echo_fio "ssh-copy-id to $c"
	    if ! ssh-copy-id $c &> /dev/null ; then
		echo_error_tips "Unable to use ssh-copy-id on $c" \
				"Make sure you've run ssh-keygen or try with --disable-copy-id"
		return 1
	    fi
	done
    fi
    if ! run_cmd_on_clients "${client_list}" "command -v rsync &> /dev/null" ; then
	echo_warning "rsync not found on at least 1 client, falling back to scp"
	copycmd=scp
    fi

    # Sequentially copy files on each client
    # If anything fail, we stop
    if ! run_cmd_on_clients "${client_list}" \
	 "mkdir -p \${user_deploy_path}/fio_jobs" disable_sudo ; then
	echo_error_tips "Can't create directory" \
			"Make sure you haven't been ssh banned, that you have correct permission and that the directory exist"
	return 1
    fi
    
    for c in ${client_list} ; do
	local user_deploy_path="$(find_user_deploy_path "$c")"
	local dst="$c:${user_deploy_path}/"
	echo_fio "$copycmd to ${dst}"
	if [ "$use_docker" = 'y' ]  && [ "$use_offline_docker_image" = 'y' ] ; then
	    # Docker+offline, we must copy the image, can take time
	    if ! ${copycmd}  {*.tar.gz,Dockerfile,*.sh,README.md} \
		 ${dst} ;
	    then
		echo_error_tips "Can't scp exa_client_performance_validation files to ${dst}" \
			   "Make sure you haven't been ssh banned and that you have correct permission"
		return 1
	    fi
	else
	    # Docker online or no docker, image is not copied
	    if ! ${copycmd} {fio-*.tar.gz,Dockerfile,*.sh,README.md} \
		 ${dst} ;
	    then
		echo_error_tips "Can't scp exa_client_performance_validation files to ${dst}" \
			   "Make sure you haven't been ssh banned and that you have correct permission"
		return 1
	    fi
	fi
    done
}

run_fio_server_on_clients()
{
    # Run fio server on distant servers
    #
    # - Input0: list of clients with ssh prefix and no # suffix
    # e.g: root@dgx1 myuser@dgx2
    # - Output: 0 on success (all servers are started), 1 otherwise
    #
    # Delegate commands to run_cmd_on_clients
    # e.g: run_cmd_on_clients "root@dgx1 myuser@dgx2" "ls"

    local client_list="$1"
    local options="${@:2}"

    echo_fio "Waiting for all clients to start fio server"
    if ! run_cmd_on_clients "${client_list}" \
	 "cd \${user_deploy_path}/ && ./exa_client_performance_validation.sh --start-server $options" ; then
	echo_warning "Can't start fio on at least 1 client"
	return 1
    fi
    return 0
}
cleanup_fio_servers()
{
    local client_list="$1"
    echo_custom "Clean-up fio servers"
    if ! run_cmd_on_clients "${client_list}" \
	 "pkill -9 fio &> /dev/null" ; then
	echo_warning "Can't stop fio server on at least 1 client"
	echo_tips "Make sure to kill fio server manually"
    fi
}

run_fio_server_locally()
{
    # Run fio server locally
    # - Input: no input
    # - Output: 0 on success (fio server is running), 1 on failure

    # Notify the user if a firewall is enabled
    if command -v systemctl &>/dev/null ; then
	echo_custom "Check firewalld"
	if systemctl status firewalld &>/dev/null ; then
	    echo_warning "firewalld seems started and may block fio server"
	    echo_tips "To stop 'systemctl stop firewalld'"
	fi
    else
	echo_custom "Skip firewalld check (no systemctl cmd)"
    fi

    # Docker or not, we have to kill the trailing fio processes (from *all* user)
    # The docker ones where killed in the exa_client_perf*.sh file (TODO: move it to routines)
    # If we don't kill all fio, then we could connect to the wrong fio server that might be configured
    # differently using a different versions of fio and so on.
    # We must be absolutely sure the fio server we connect to is the one we start there
    # If we don't, we're in deep trouble with convoluted error messages.
    echo_custom "Kill fio server"
    pkill -9 fio &> /dev/null
    for i in {0..10} ; do
	sleep 1
	if ! ps aux |grep "fio --server" |grep -v -q grep ; then
	    break
	fi
	if [ $i -eq 10 ] ; then
	    echo_error_tips "Can't kill previous fio --server" \
			    "Make sure you have the privileges to kill it (e.g sudo)"
	    return 1
	fi
    done

    # use_docker == 'n'
    # Start fio server locally
    if [ "$use_docker" = 'n' ]; then
	echo_custom "Run fio server"
	runtime=${runtime} iodepth=${iodepth} blocksize=${blocksize} ramptime=${ramptime} njobs=${njobs} mountpoint=${mountpoint} ioengine=${ioengine} filesize=${filesize} \
         nohup fio --server </dev/null >/dev/null 2>&1 & disown -h

	for i in {0..10} ; do
	    sleep 1
	    if ( ps ux |grep "fio --server" |grep -v -q grep ||
		     ps a |grep "fio --server" |grep -v -q grep  ) ; then
		return 0
	    fi
	done

	return 1
    fi

    # use_docker == 'y'
    # Start docker server locally
    # If something fail, return 1 to notify master I didn't started correctly
    if docker run -e runtime=${runtime} -e blocksize=${blocksize} -e ramptime=${ramptime} -e iodepth=${iodepth} -e njobs=${njobs} -e mountpoint=/fio_output -e ioengine=${ioengine} -e filesize=${filesize} --name fio_server -d --net=host -v "${mountpoint}":/fio_output --rm exa_client_performance_validation bash -c "fio --server"  &>/dev/null ; then
	echo_custom "Wait for the fio server container to start"
	# TODO: Check that a local fio client work against this server before returning
	for i in {0..10} ; do
	    if [ "`docker inspect -f {{.State.Running}} fio_server 2>/dev/null`" == "true" ]; then
		sleep 2 # ~ Avoid fio connection failed
		return 0
	    fi
	    echo_custom "Waiting $i/10"
	    sleep 1
	done
    fi

    return 1
}


update_variable_based_on_manual_changes()
{
    # Update variable in fio_jobs/ if modified in this script
    # - Input0: field to check in fio_jobs/*job
    # - Input1: ENV variable that should match
    #
    # Output: exit 1 if a fio field is different
    # between jobs files
    #
    # Use --disable-job-check to disable

    if [ "$do_job_check" = 'n' ] ; then echo_custom "Skip job check (--disable-job-check)" ; return 1 ; fi

    # TODO: actually do the check with numa mode. For now we return 1 because it's not implemented.
    if [ "$numa_mode" = 'y' ] ; then echo_warning "Skip job check due to --numa-binding-*" ; return 1 ; fi

    # Update variable based on manual changes in fio_jobs/*.job and check for error
    if ! (( $(cat fio_jobs/*.job |grep -E "$1=(\\\$\{$2\}|\\\$$2)" |wc -l ) == 7 )) &> /dev/null ; then
	echo_warning "$1 have been modified in fio_jobs/*.job"
	if ! (( $(cat fio_jobs/*.job |grep -E "$1=.*" |uniq -u |wc -w ) == 0 )) &> /dev/null ; then
	    echo_error_tips "Discrepancy in $1" "Make sure $1 is the same in all fio_jobs/ files"
	    for i in $(grep "$1" fio_jobs/*.job) ; do
		echo_tips $i
	    done
	    echo_tips "OR disable with check with --disable-job-check"
	    exit 1
	fi
	eval "$2=$(cat fio_jobs/file_creation.job |grep "$1=.*"|grep -o "=.*"|sed "s@=@@g")"
	echo_custom "$1 updated to match fio_jobs/*.job"
	return 0
    fi
    return 0
}


drop_cache()
{
    # Drop clients and EXAScaler cache
    # 1. Drop client cache
    # 2. Drop EXA cache
    #
    # - Input0: list of clients with ssh prefix and no # suffix
    # e.g: root@dgx1 myuser@dgx2
    # (if single client mode, no input needed)
    #
    # - Output: return 0 on success, 1 on failure
    #  exacache_${iotype}_status & clientcache_${iotype}_status are set
    #  These variables can be used to determine what worked and what didn't
    #
    # Delegate commands to run_cmd_on_clients
    # e.g: run_cmd_on_clients "root@dgx1 myuser@dgx2" "ls"

    local client_list="$1"

    # Drop the client cache first
    echo_custom "Drop clients cache"
    ## If copy_id we drop
    if [ "$use_copy_id" = 'y' ] ; then
	if ! run_cmd_on_clients "${client_list}" "(echo 3 > /proc/sys/vm/drop_caches) 2>/dev/null" ; then
	    echo_warning "Can't drop cache on at least 1 client"
	    eval "clientcache_${iotype}_status=✖"
	fi
    else
	## If not, we skip
	echo_warning "Drop cache is disabled with option --disable-copy-id"			
	eval "exacache_${iotype}_status=✖"
	eval "clientcache_${iotype}_status=✖"
    fi

    # Drop the EXAScaler cache
    if [ "$drop_exa_cache" = 'y' ] ; then
	echo_custom "Drop exa VMs cache"

	# Find mgs_ip
	local first_client=$(echo ${client_list} |awk '{print $1}')
	mgs_ip=$(find_mgs_ip $first_client)
	if ! echo $mgs_ip  |grep -q -E "^([0-9]+\.){3}[0-9]+" ; then
	    if single_client_mode ; then
		echo_warning "Can't drop EXA VMs cache (can't find mgs ip)"
	    else
		echo_warning "Can't drop EXA VMs cache (can't find mgs ip from ${first_client})"
	    fi
	    eval "exacache_${iotype}_status=✖"
	    return 1
	fi

	# Drop EXA VMs cache
	## Single client mode
	if single_client_mode ; then
	    if ! command -v sshpass &> /dev/null ; then
		echo_warning "Can't drop EXA VMs cache (can't find sshpass command on $(hostname))"
		echo_tips "Install sshpass on $(hostname) to drop EXA VMs cache"
		eval "exacache_${iotype}_status=✖"
	    else
		if ! sshpass -p DDNSolutions4U ssh -o StrictHostKeyChecking=no root@${mgs_ip} \
		     "clush -abS 'sysctl vm.drop_caches=3'" &> /dev/null ; then
		    echo_warning "Can't drop EXA VMs cache from $(hostname)"
		    eval "exacache_${iotype}_status=✖"
		fi
	    fi
	else
	    ## Mult. clients mode
	    if ! ssh ${first_client} "command -v sshpass &> /dev/null" &>/dev/null ; then
		echo_warning "Can't drop EXA VMs cache (can't find sshpass command on ${first_client})"
		echo_tips "Install sshpass on ${first_client} to drop EXA VMs cache"
		eval "exacache_${iotype}_status=✖"
	    else
		if ! ssh ${first_client}  \
		     sshpass -p DDNSolutions4U \
		     ssh -o StrictHostKeyChecking=no root@${mgs_ip} \
		     "clush -abS 'sysctl vm.drop_caches=3'" &>/dev/null ; then
		    echo_warning "Can't drop EXA VMs cache from ${first_client}"
		    eval "exacache_${iotype}_status=✖"
		fi
	    fi
	fi
    fi

}
check_fio_is_available_in_path()
{
    # Check fio is available in PATH.
    # Used if docker is not used
    # exit 1 if there is an issue
    
    # Fix DDN-4211 fio not found/can't start fio server
    # Compiled or not, we have to make sure the fio binary is reachable at this point
    echo_custom  "Verify fio is installed"
    if ! command -v fio &> /dev/null ; then
	if ! [ "$use_src_fio" = 'y' ] ; then
            echo_error_tips "fio executable was not found" \
			    "Install fio OR try without --disable-docker option"
	else
            echo_error_tips "fio executable was not found" \
			    "Install fio OR try with both --disable-docker --disable-src options"
	fi
        exit 1
    else
        echo_custom "fio is $(which fio) $(fio --version 2>/dev/null)"
    fi
}
compile_fio_from_src_locally()
{
    # This routine is called to compile fio from shipped fio src package.
    # exit 1 if there is an error
    echo_custom "Build fio from sources"

    if ! [ -f fio-3.35.tar.gz ] ; then
	echo_error_tips "Missing fio-*.tar.gz" \
			"Check md5sum of this archive"
	exit 1
    fi
    # Compile a local version of fio
    if ! (tar xvf fio-3.35.tar.gz && cd fio-3.35/ && ./configure && make) &> fio_compile.log ; then
        cat fio_compile.log
        echo_error_tips "Unable to compile fio sources" \
			"Try without --disable-docker OR try with both --disable-src --disable-docker"
        exit 1
    fi
    # If numa_node option and we don't have the deps for numa then we must fail
    if [ "$numa_mode" = 'y' ] && [ "$master_with_mult_client" = 'n' ] && grep -q -E '^libnuma[[:space:]]+no$' fio_compile.log &>/dev/null ; then
	echo_error_tips "fio was configured without numa support and --numa-binding-* is used" \
			"Install numactl-devel/libnuma-dev(el) OR remove --numa-binding-* option(s) OR try with --disable-src"
	exit 1
    fi

}
setup_fio_docker_image()
{
    echo_custom "Setup fio docker"
    if ! command -v docker &> /dev/null ; then
        echo_error_tips "Docker executable was not found" \
			"Install Docker OR try with --disable-docker option"
        exit 1
    fi
    echo_custom "Docker executable was found"

    if [ "$use_offline_docker_image" = 'y' ] ; then
        echo_custom "Load offline docker image"
        if ! docker load --input exa_client_performance_validation_docker_image_OFFLINE.tar.gz > /dev/null 2>&1 ; then
            echo_error_tips "Unable to load fio docker pre-built image" "Try without --offline OR --disable-docker OR run as sudo?" ; exit 1
        fi
    else
        echo_custom "Build docker image"
        if ! docker build -t exa_client_performance_validation .  &>/dev/null ; then
            echo_error_tips "Unable to load docker image" "Try --offline OR --disable-docker OR run as sudo?" ; exit 1
        fi
    fi
}
