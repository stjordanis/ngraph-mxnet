# *******************************************************************************
# * Copyright 2018 Intel Corporation
# *
# * Licensed under the Apache License, Version 2.0 (the "License");
# * you may not use this file except in compliance with the License.
# * You may obtain a copy of the License at
# *
# *     http://www.apache.org/licenses/LICENSE-2.0
# *
# * Unless required by applicable law or agreed to in writing, software
# * distributed under the License is distributed on an "AS IS" BASIS,
# * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# * See the License for the specific language governing permissions and
# * limitations under the License.
# ********************************************************************************

#!/bin/bash
#Author:  Lam Nguyen
set -u
set -e

declare SCRIPT_NAME="$(basename "${0}")"
declare THIS_SCRIPT_DIR="$( cd $(dirname "${BASH_SOURCE[0]}") && pwd )"
declare MX_DIR="$(cd "${THIS_SCRIPT_DIR}/../.." && pwd)"

echo "****************************************************************************************"
echo "Build and install Ngraph_MXnet..."
echo "****************************************************************************************"

cd "${MX_DIR}"
git submodule update --init --recursive

if [ ! -z "${NGRAPH_BRANCH}" ] && [ "${NGRAPH_BRANCH}" != "default" ] ; then
    echo "NGRAPH_BRANCH == ${NGRAPH_BRANCH}"
    cd "3rdparty/ngraph-mxnet-bridge/cmake"
    sed -e "/GIT_TAG/s/.*/        GIT_TAG ${NGRAPH_BRANCH}/" ngraph.cmake > ngraph.cmake.test
    cp ngraph.cmake.test ngraph.cmake
    rm -rf ngraph.cmake.test
else
    echo "ngraphBranch === ${NGRAPH_BRANCH}"
fi

cd "${MX_DIR}"

case "${MAKE_VARIABLES}" in
	USE_NGRAPH)
		echo "Building MXnet with experimental nGraph integration enabled. Engine: CPU + MKLDNN"
		make USE_NGRAPH=1 USE_GPERFTOOLS=0 USE_JEMALLOC=0  USE_CUDA=0 DEBUG=0 -j $(nproc)
		;;
	USE_NGRAPH_DISTRIBUTED)
		echo "Building MXnet with experimental nGraph distributed support enabled. Engine: CPU + MKLDNN"
		make USE_NGRAPH=1 USE_GPERFTOOLS=0 USE_JEMALLOC=0  USE_CUDA=0 DEBUG=0 USE_NGRAPH_DISTRIBUTED=1 NGRAPH_EXTRA_CMAKE_FLAGS=-DNGRAPH_DISTRIBUTED_ENABLE=1 -j $(nproc)
		;;
	USE_CUDA)
		echo "CUDA Version"
		cat /usr/local/cuda/version.txt
		echo "Print the nvidia-smi"
		echo `cat /proc/driver/nvidia/version | head -n1 | awk '{ print $8 }'`
		echo `lspci | grep -i nvidia`
		echo "Building MXnet with experimental nGraph distributed support enabled. Engine: GPU"
		make USE_NGRAPH=1 USE_GPERFTOOLS=0 USE_JEMALLOC=0 USE_CUDA=1 DEBUG=0 USE_NGRAPH_GPU=1 USE_CUDNN=1 USE_CUDA_PATH=/usr/local/cuda -j $(nproc)
		;;
	USE_MKLDNN)
		echo "Building MXnet with MKLDNN, and non-nGraph. Engine: CPU + MKLDNN"
		make USE_NGRAPH=0 USE_MKLDNN=1 DEBUG=0 -j $(nproc)
		;;
	*)
		echo "Building MXnet with non-MKLDNN, and non-nGraph. Engine: CPU"
		make USE_NGRAPH=0 USE_MKLDNN=0 DEBUG=0 -j $(nproc)
		;;
esac

if [ -d "${MX_DIR}/3rdparty/ngraph-mxnet-bridge/build/lib" ]; then
	export LD_LIBRARY_PATH="${MX_DIR}/3rdparty/ngraph-mxnet-bridge/build/lib"
fi

if [ -d "${MX_DIR}/3rdparty/ngraph-mxnet-bridge/build/lib64" ]; then
	export LD_LIBRARY_PATH="${MX_DIR}/3rdparty/ngraph-mxnet-bridge/build/lib64"
fi

export MKLDNN_LIB_PATH="${MX_DIR}/lib"

echo ${LD_LIBRARY_PATH}
echo "Verify the installation of Mxnet"

if [ ! -f "./lib/libmxnet.so" ] ; then
  ( >&2 echo "FATAL ERROR: Can not found libmxnet.so. Exiting ...." )
  exit 1
else
   echo "Success to install ngraph-mxnet."
fi

echo "Verify the installation of 3rdparty Ngraph"

if [ "${MAKE_VARIABLES}" == "USE_NGRAPH" ] || [ "${MAKE_VARIABLES}" == "USE_NGRAPH_DISTRIBUTED" ]; then
	if [ ! -f "$LD_LIBRARY_PATH/libngraph.so" ] ; then
		( >&2 echo "FATAL ERROR: Can not found libngraph.so. Exiting ...." )
  		exit  
	else
		echo "Success to install 3rdparty Ngraph."
	fi	

	if [ ! -f "$MKLDNN_LIB_PATH/libmkldnn.so" ] ; then
  		( >&2 echo "FATAL ERROR: libmkldnn.so not found in MKLDNN_LIB_PATH [$MKLDNN_LIB_PATH]" )
  		exit 1
	fi
elif [ "${MAKE_VARIABLES}" == "USE_MKLDNN" ]; then
	if [ ! -f "$MKLDNN_LIB_PATH/libmkldnn.so" ] ; then
		( >&2 echo "FATAL ERROR: libmkldnn.so not found in MKLDNN_LIB_PATH [$MKLDNN_LIB_PATH]" )
  		exit 1
  	else
  		echo "Success to install MKLDNN."
  	fi

  	if [ -d "${MX_DIR}/3rdparty/ngraph-mxnet-bridge/install" ]; then
  		( >&2 echo "FATAL ERROR: the directory 3rdparty/ngraph-mxnet-bridge/install found in ${MX_DIR}/3rdparty/ngraph-mxnet-bridge" )
  		exit 1
  	else
  		echo "PASS. Directory 3rdparty/ngraph-mxnet-bridge/install is not existed!"
  	fi
elif [ "${MAKE_VARIABLES}" == "USE_CUDA" ]; then
	if [ ! -f "./lib/libgpu_backend.so" ] ; then
		( >&2 echo "FATAL ERROR: libgpu_backend.so not found in LD_LIBRARY_PATH [$LD_LIBRARY_PATH]" )
		exit 1
	else
		echo "Success to install with CUDA."
	fi
else
	if [ ! -f "./lib/libngraph.so" ] ; then
		( >&2 echo "FATAL ERROR: libngraph.so should not found in LD_LIBRARY_PATH [$LD_LIBRARY_PATH]" )
	fi

  	if [ -d "${MX_DIR}/3rdparty/ngraph-mxnet-bridge/install" ]; then
  		( >&2 echo "FATAL ERROR: the directory 3rdparty/ngraph-mxnet-bridge/install found in ${MX_DIR}/3rdparty/ngraph-mxnet-bridge" )
  		exit 1
  	fi

fi
