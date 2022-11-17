#! /bin/bash

# Symlink python directories
sudo ln -s /usr/bin/python3 /usr/bin/python

# Ensure the current working directory
wkdir=/usr/local/SU2
cd $wkdir

# Set the initial environmental variables
export MPICC=/usr/bin/mpicc
export MPICXX=/usr/bin/mpicxx
export CC=$MPICC
export CXX=$MPICXX
export CXXFLAGS="-O3 -funroll-loops -march=native -mtune=native"

# Set the appropriate flags for the desired install options
flags="-Dcustom-mpi=true -Denable-pywrapper=true -Denable-autodiff=true -Denable-directdiff=true -Denable-mixedprec=true"

# Compile and verify the above flags compiled correctly
verified=false
build_counter=0

while [ "$build_counter" -le 3 ] || [ "$verified" = false ]; do

	# Keep track of the build attempts to prevent an infinite loop
	((build_counter++))
			
	# Create a directory for meson
	sudo mkdir -p $wkdir/nimbix_build
	sudo chown -R root:root $wkdir
	sudo chmod -R 0777 $wkdir
	
	# Compile with meson
	# (note that meson adds 'bin' to the --prefix directory during build)
	./meson.py nimbix_build $flags --prefix=$wkdir/install |& tee -a build_log.txt
	
	# Verify CC env var
	if grep -q "Using 'CC' from environment with value:" build_log.txt; then
		verified=true
	else
		verified=false
	fi
	# Verify CXX env var
	if grep -q "Using 'CXX' from environment with value:" build_log.txt; then
		verified=true
	else
		verified=false
	fi
	# Verify C compiler
	if grep -q "C compiler for the host machine:" build_log.txt; then
		verified=true
	else
		verified=false
	fi
	# Verify C linker
	if grep -q "C linker for the host machine:" build_log.txt; then
		verified=true
	else
		verified=false
	fi
	# Verify C++ compiler
	if grep -q "C++ compiler for the host machine:" build_log.txt; then
		verified=true
	else
		verified=false
	fi
	# Verify C++ linker
	if grep -q "C++ linker for the host machine:" build_log.txt; then
		verified=true
	else
		verified=false
	fi
	# Verify python3
	if grep -q "Program python3 found: YES" build_log.txt; then
		verified=true
	else
		verified=false
	fi
	# Verify swig
	if grep -q "Program swig found: YES" build_log.txt; then
		verified=true
	else
		verified=false
	fi
	# Verify mpi4py
	if grep -q "Using mpi4py from" build_log.txt; then
		verified=true
	else
		verified=false
	fi
	# Verify pkg-config
	if grep -q "Found pkg-config:" build_log.txt; then
		verified=true
	else
		verified=false
	fi
	# Verify python
	if grep -q "Dependency python found: YES" build_log.txt; then
		verified=true
	else
		verified=false
	fi
	# Verify install.sh
	if grep -q "Program install.sh found: YES" build_log.txt; then
		verified=true
	else
		verified=false
	fi	

	# Re-run meson if compile not verified
	if [ "$verified" = false ]; then
	
		# Remove the nimbix_build directory 
		echo "Meson build unverified. Removing nimbix_build directory."
		sudo rm -R $wkdir/nimbix_build
		
	elif [ "$verified" = true ]; then
	
		echo "Meson build verified."
	
	    # Set environmental variables from meson build
	    export SU2_DATA=/data/SU2
	    export SU2_HOME=/usr/local/SU2
        export SU2_RUN=/usr/local/SU2/install/bin
        export PATH=$PATH:$SU2_RUN
        export PYTHONPATH=$PYTHONPATH:$SU2_RUN
        # Set environmental variable to allow multi-node use
        export SU2_MPI_COMMAND="mpirun --hostfile /etc/JARVICE/nodes -np %i %s"

		# Install with ninja
		./ninja -C nimbix_build install
		
		build_counter=10
		
		break
		
	fi	
	
done

if [ $build_counter -eq 4 ]; then

	# Exit the script if build unsuccessful
	echo "Unable to correctly compile SU2 after 3 attempts."
	exit 1

elif [ $build_counter -eq 10 ]; then

    echo "SU2 successfully compiled."
	
fi

# Record a ready status
touch /tmp/node_ready_status.txt
