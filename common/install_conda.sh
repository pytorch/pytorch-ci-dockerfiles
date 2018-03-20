#!/bin/bash

set -ex

# Optionally install conda
if [ -n "$ANACONDA_VERSION" ]; then
  BASE_URL="https://repo.continuum.io/miniconda"

  case "$ANACONDA_VERSION" in
    2)
      CONDA_FILE="Miniconda2-latest-Linux-x86_64.sh"
    ;;
    3)
      CONDA_FILE="Miniconda3-latest-Linux-x86_64.sh"
    ;;
    *)
      echo "Unsupported ANACONDA_VERSION: $ANACONDA_VERSION"
      exit 1
      ;;
  esac

  mkdir /opt/conda
  chown jenkins:jenkins /opt/conda

  as_jenkins() {
    # NB: unsetting the environment variables works around a conda bug
    # https://github.com/conda/conda/issues/6576
    sudo -H -u jenkins env -u SUDO_UID -u SUDO_GID -u SUDO_COMMAND -u SUDO_USER $*
  }

  pushd /tmp
  wget -q "${BASE_URL}/${CONDA_FILE}"
  chmod +x "${CONDA_FILE}"
  as_jenkins ./"${CONDA_FILE}" -b -f -p "/opt/conda"
  popd

  # TODO: Consider using an ENV to set the PATH in the Dockerfile instead
  # Don't forget to register this in ld.so.  The benefit of this style,
  # however, is that it more closely tracks how normal users use conda
  echo "source /opt/conda/bin/activate" | as_jenkins tee ~jenkins/.bashrc
  source /opt/conda/bin/activate

  # Install our favorite conda packages
  as_jenkins conda install -q -y mkl mkl-include numpy pyyaml pillow
  as_jenkins conda install -q -y nnpack -c killeent

  if [[ "$CUDA_VERSION" == 8.0* ]]; then
    as_jenkins conda install -q -y magma-cuda80 -c soumith
  elif [[ "$CUDA_VERSION" == 9.0* ]]; then
    as_jenkins conda install -q -y magma-cuda90 -c soumith
  fi

  # Install some other packages
  # TODO: Why is scipy pinned
  as_jenkins pip install -q pytest scipy==0.19.1 scikit-image

  # Cleanup package manager
  apt-get autoclean && apt-get clean
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
fi
