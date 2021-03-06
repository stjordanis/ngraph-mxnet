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

#!  /bin/bash

# Author:  Lam Nguyen

# Script parameters:
#
# $1 IMAGE_ID    Required: ID of the ngmx_ci docker image to use
# $2 PythonVer  Optional: version of Python to build with (default: 2)

set -e  # Fail on any command with non-zero exit

# Get the python version

if [ -z "${2}" ] ; then
    export PYTHON_VERSION_NUMBER="3"  # Build for Python 3 by default
else
    export PYTHON_VERSION_NUMBER="${2}"
fi

# Note that the docker image must have been previously built using the
# make-docker-mx-ngraph-base.sh script (in the same directory as this script).
D_CMD="docker"
if [ "${MAKE_VARIABLES}" = "USE_CUDA" ]; then
    IMAGE_NAME='ngmx_ci_gpu'
    D_CMD="nvidia-docker"
fi

if [ "${OS_SYSTEM}" = "CENTOS7" ]; then
    IMAGE_NAME='ngmx_ci_centos7'
elif [ "${OS_SYSTEM}" = "UBUNTU16.4" ]; then
    IMAGE_NAME='ngmx_ci_ubuntu16_4'
else
    echo "Missing Input Parameters : MAKE_VARIABLES = ${MAKE_VARIABLES}, and OS_SYSTEM = ${OS_SYSTEM}. Existing .."
    exit 1
fi

IMAGE_ID="${1}"
if [ -z "${IMAGE_ID}" ] ; then
    echo 'Missing an image version as the only argument. Exitting ...'
    exit 1
fi

set -u  # No unset variables after this point

ngraph_mx_dir="$(realpath ../..)"

jenkin_cje_dir="$(realpath ../../..)/jenkins"

docker_mx_dir="/home/dockuser/ng-mx"

docker_jenkin_dir="/home/dockuser/jenkins"

script='run-ng-mx-deepmark-tests.sh'

## deepmark
${D_CMD} run --rm \
      --env RUN_UID="$(id -u)" \
      --env RUN_CMD="${docker_mx_dir}/docker/scripts/${script}" \
      --env PYTHON_VERSION_NUMBER="${PYTHON_VERSION_NUMBER}"\
      --env MX_OMP_NUM_THREADS="${MX_OMP_NUM_THREADS}" \
      --env MX_NG_KMP_BLOCKTIME="${MX_NG_KMP_BLOCKTIME}" \
      --env MX_NG_BATCH_SIZE="${MX_NG_BATCH_SIZE}" \
      --env MX_NG_KMP_AFFINITY="${MX_NG_KMP_AFFINITY}" \
      --env MX_NG_DEEPMARK_TYPE="${MX_NG_DEEPMARK_TYPE}" \
      --env http_proxy=http://proxy-fm.intel.com:911 \
      --env https_proxy=http://proxy-fm.intel.com:912 \
      --env OS_SYSTEM=${OS_SYSTEM} \
      -v "${ngraph_mx_dir}:${docker_mx_dir}" \
      -v "${jenkin_cje_dir}:${docker_jenkin_dir}" \
      -v "/dataset/mxnet_imagenet/:/dataset/mxnet_imagenet/" \
      -v "/dataset/cityscape/maskrcnn-tusimple/data/:/dataset/cityscape/maskrcnn-tusimple/data/" \
      "${IMAGE_NAME}:${IMAGE_ID}" /home/run-as-user.sh
