#! /bin/bash

sleep 10

# Check connection to each node
node_count=$(wc -l < "/etc/JARVICE/nodes")
echo "$node_count node(s) in session."
nodes_connected=1
SECONDS=0
while [ "$nodes_connected" -lt "$node_count" ]; do
	if [ "$SECONDS" -gt 60 ]; then
	    echo "At least one node has not connected."
		echo "Exiting..."
		exit 1
	fi
	sleep 5s
    for node in $(cat /etc/JARVICE/nodes); do   
        if [ "$node" != "$HOSTNAME" ]; then
            echo "Checking connection to $node"
            status=$(ssh -o BatchMode=yes -o ConnectTimeout=5 "$node" echo ok 2>&1)
			if [ "$status" == ok ]; then
			    echo "$node connection established."
				((nodes_connected++))
			else
				echo "$node not connected. Retrying..."
			fi
        fi
    done
done

# Compile SU2 on each node in session
echo "Compiling SU2 on compute nodes"
for node in $(cat /etc/JARVICE/nodes); do   
    if [ "$node" != "$HOSTNAME" ]; then
        echo "Initializing $node"
        ssh $node "/usr/local/SU2/init/compile_SU2.sh" &
    fi
done

# Compile SU2 on the main node in the session
echo "Compiling SU2 on main node"
/usr/local/SU2/init/compile_SU2.sh

# Ensure key environmental variables are set
export SU2_DATA=/data/SU2
export SU2_HOME=/usr/local/SU2
export SU2_RUN=/usr/local/SU2/install/bin
export PATH=$PATH:$SU2_RUN
export PYTHONPATH=$PYTHONPATH:$SU2_RUN
# Set environmental variable to allow multi-node use
export SU2_MPI_COMMAND="mpirun --hostfile /etc/JARVICE/nodes -np %i %s"

# Wait for all nodes to complete compilation
nodes_ready=1
SECONDS=0
while [ "$nodes_ready" -lt "$node_count" ]; do  
	if [ "$SECONDS" -gt 60 ]; then
	    echo "At least one node has not initialized SU2."
		echo "Exiting..."
		exit 1
	fi
	sleep 5s
	for node in $(cat /etc/JARVICE/nodes); do
        if [ "$node" != "$HOSTNAME" ]; then
            echo "Checking $node status"
            ssh $node "test -e /tmp/node_ready_status.txt"
		    if [ $? -eq 0 ]; then
			    ((nodes_ready++))
			fi
        fi
    done
done

echo "All nodes initialized."
echo "Changing to /data/SU2 directory to begin data processing."

cd /data/SU2

# Provide permission to run bash file in /data directory
sudo chmod -R 0777 /data/SU2

# Get bash filename from session initialization
while [[ -n "$1" ]]; do
    case "$1" in
	-file)
	    shift
        BASH_FILE="$1"
		;;
	esac
    shift
done

# Call the bash file
source "$BASH_FILE"
