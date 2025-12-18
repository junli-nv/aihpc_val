# EXA Client Perf Scripts v1.1.9

## exa_client_performance_validation.sh

Output peak throughput and IOPS numbers for client(s) connected to an EXAScaler filesystem using fio.
If performance is bad, you can check the underlying network by using the exa_client_network_validation.sh script (only supports IB for now).

### Dependencies (for each client)
- root access if docker is used (or docker available for user)
- bash,grep,sed,md5sum,ssh,scp,sshpass
- gcc >= 4.9 if neither docker or fio is installed
- An EXA filesystem mounted at the same mountpoint for all clients (/exa_filesystem by default, can be modified with -m option)

### Usage
Extract this archive on one of your clients.
It will rsync/scp files if multiple clients.
```sh
tar xvf exa_client_perf*.tar.gz && cd exa_client*/
```

#### Single client run (~10min)
```sh
./exa_client_performance_validation.sh
```

#### Multiple clients 

```sh
# ⚠  ssh-copy-id is used with multiple clients (use --disable-copy-id to disable)
./exa_client_performance_validation.sh --clients "10.11.12.13 14.15.16.17 18.19.20.21"

# Use '#' to become sudo
# You will be asked for the password if any
./exa_client_performance_validation.sh --clients "myuser@10.11.12.13# myuser@14.15.16.17# 18.19.20.21"
```

#### No internet
```sh
./exa_client_performance_validation.sh --offline
```


#### Short run & custom mountpoint & multiple clients
```sh
./exa_client_performance_validation.sh --ramptime 5 --runtime 5 -m /my/mountpoint --clients "10.11.12.13 14.15.16.17"
```

#### Display options available
```sh
./exa_client_performance_validation.sh --help
```

### Customize
This script use standard fio jobfiles (see fio_job/*).
You can modify them directly.

### Known issues

- The script has to be run from that directory.
- Wrong result printing might happen in rare condition (not reproductible with the fuzzer). This has to be investigated. Check with fio logs if there is a doubt.
- -m with a subdirectory leads to the mount check to fail. Add --disable-mount-check as a workaround.
- numa-binding with 2 sub fio processes can lead to empty results. The exact reason hasn't been determined. Check that the numa nodes you use actually exist.


### Network only archive
If you have the network only archive, you won't
be able to use --offline option out of the box.
If you want to make --offline works, run these commands:

```sh
docker build -t exa_client_performance_validation:latest .
docker save exa_client_performance_validation:latest -o exa_client_performance_validation_docker_image_OFFLINE.tar.gz
```

## exa_client_network_validation.sh

Output peak read/write sequential throughput of the underlying network that EXAScaler leverage.

### Dependencies

- ib_read_bw/ib_write_bw (from MOFED/perftest)
- ibdev2netdev (from MOFED)
- >= 1 IB link(s) up & running with a configured IPoIB IP.
- pkill

### Usage

1. Start ib_read_bw (or ib_write_bw) on the EXAScaler VMs.
You may want to use the "EXAScaler VMs server side script" to achieve that (see below).
2. Using the IPs retrieved from the "EXAScaler VMs server side script", start the client
```sh
./exa_client_network_validation.sh "172.16.240.82 172.16.240.81 172.16.240.83 172.16.240.80" 
# you can also specify which operation. It has to be the same than the server
./exa_client_network_validation.sh "172.16.240.82 172.16.240.81 172.16.240.83 172.16.240.80" ib_write_bw
```

#### EXAScaler VMs server side script
To copy into server.sh on an EXAScaler VM.
The script give you the list of IPs to copy and paste on your client.

You can start the servers with
```sh
./server.sh ib_write_bw # default is ib_read_bw
```

server.sh script:
```sh
#!/bin/bash
# DDN script to run on a single EXAScaler VM in a screen session
# screen -S ibperf
# Start ib_read_bw/ib_write_bw servers

# Trace the commands (-x) and exit on any error
# Also exit if !cmd |& tee  (pipefail, -o)
 set -e
# set -x
#set -o

command="ib_read_bw"

function cleanup()
{
   clush -abS "pkill ${command}" 
}

trap cleanup SIGINT

if [ $# -ge 1 ] ; then
    echo "Using command: ${1}"
    export command="${1}"
fi

if [ $# -eq 2 ] ; then
    echo "Using group: ${2} (clush -g ${2})"
    export target="-g ${2}"
elif [ $# -gt 2 ] ; then
    echo "Too many arguments"
    exit 1
else
    echo "Running on all servers (clush -a)"
    export target="-a"
fi

# Kill trailing processes
clush -abS "pkill $command || true" || exit 1
for i in {0..5} ; do
    if ! clush -abS ps aux |grep $command |grep -v grep |grep -v "server.sh" ; then
        break
    fi
    if [ $i -eq 5 ] ; then
        echo "Can't kill $command on "
        exit 1
    fi
    clush -abS 'pkill $command || true'
    sleep 1
done

# Before running we print the list of IPs for the client to use
clush -S ${target} 'ip a' |grep 'mlxib0' |grep -E -o "([0-9]+\.){3}[0-9]+/" |tr -d '/' |xargs |& tee $command_servers_ips.log


# Run
while true ; do
    clush -S ${target} -b "${command} -d $(ibdev2netdev -v |grep mlxib0|grep -E -o 'mlx5_[0-9]+') -D 10 -R -s 1048576 --port 18515" &
    # clush ${target} -b '$command -d mlx5_0 -D 10 -R -s 1048576 --port 18515' & # if the previous line doesn't work, use that one.
    wait
done
````


