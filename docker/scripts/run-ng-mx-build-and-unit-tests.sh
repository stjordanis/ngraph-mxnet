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
#Author:  Lam Nguyen

# This script is designed to be called from within a docker container.
# It is installed into a docker image.  It will not run outside the container.

set -e  # Make sure we exit on any command that returns non-zero

# For now we simply build ng-mx for python 2.  Later, python 3 builds will
# be added.
if [ ! -z "${PYTHON_VERSION_NUMBER}" ]; then
	export PYTHON_VERSION_NUMBER=""
else
	if [ "${OS_SYSTEM}" = "CENTOS7" ] ; then
		export PYTHON_VERSION_NUMBER=3.6
	else
		export PYTHON_VERSION_NUMBER=3
	fi
fi

export PYTHON_BIN_PATH="/usr/bin/python$PYTHON_VERSION_NUMBER"
export venv_dir="/tmp/venv_python${PYTHON_VERSION_NUMBER}"

# We don't need ccache because we are building in a (fresh) docker container
export BUILD_MX_WITH_CCACHE=0

# This path is dependent on where host dir-tree is mounted into docker run
# See script docker-run-mx-ng-build-as-user.sh
# HOME is expected to be /home/dockuser.  See script run-as-user.sh, which
# sets this up.
cd "$HOME/ng-mx"

echo "In $(basename ${0}):"
echo "  HOME=${HOME}"
echo "  PYTHON_VERSION_NUMBER=${PYTHON_VERSION_NUMBER}"
echo "  PYTHON_BIN_PATH=${PYTHON_BIN_PATH}"

# Make sure the Bazel cache is in /tmp, as docker images have too little space
# in the root filesystem, where /home (and $HOME/.cache) is.  Even though we
# may not be using the Bazel cache in the builds (in docker), we do this anyway
# in case we decide to turn the Bazel cache back on.
echo "Adjusting bazel cache to be located in /tmp/bazel-cache"
rm -fr "$HOME/.cache"
mkdir /tmp/bazel-cache
ln -s /tmp/bazel-cache "$HOME/.cache"

cd "$HOME/ng-mx/docker/scripts/"

xtime="$(date)"
echo  ' '
echo  "===== Building and Installing Mxnet at ${xtime} ====="
echo  ' '

if [ "${OS_SYSTEM}" = "CENTOS7" ]; then
    export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/local/lib/pkgconfig/
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib/
fi

# Make sure pip install uses sudo, for installing into system
# In addition, pip seems to ignore http_proxy env vars, so
# explicitly set them here
export PIP_INSTALL_FROM_SUDO=1
export PIP_INSTALL_EXTRA_ARGS="--proxy=$http_proxy --proxy=$https_proxy"
export MAKE_VARIABLES="${MAKE_VARIABLES}"
./build-install-mx.sh 2>&1 | tee ../mx-build.log
echo "===== Build & Install Pipeline Exited with $? and endtime ${xtime} ===="

xtime="$(date)"
echo  ' '
echo  "===== Running unit test  at ${xtime} ====="
echo  ' '
cd "$HOME/ng-mx/"
PS1='prompt> '
PS2='prompt-more> '
virtualenv -p "${PYTHON_BIN_PATH}" "${venv_dir}"
source "${venv_dir}/bin/activate"
cd "$HOME/ng-mx/docker/scripts/"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib/
./run-ng-mx-unit-tests.sh 2>&1 | tee ../mx-tests.log
echo "===== Unit Tests Pipeline Exited with $? ====="
xtime="$(date)"
echo ' '
echo "===== Completed MXnet-NGraph-Unittes Build and Test at ${xtime} ====="
echo ' '
