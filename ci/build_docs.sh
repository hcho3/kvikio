#!/bin/bash
# Copyright (c) 2023-2024, NVIDIA CORPORATION.

set -euo pipefail

rapids-logger "Create test conda environment"
. /opt/conda/etc/profile.d/conda.sh

rapids-dependency-file-generator \
  --output conda \
  --file_key docs \
  --matrix "cuda=${RAPIDS_CUDA_VERSION%.*};arch=$(arch);py=${RAPIDS_PY_VERSION}" | tee env.yaml

rapids-mamba-retry env create --yes -f env.yaml -n docs
conda activate docs

rapids-print-env

rapids-logger "Downloading artifacts from previous jobs"
CPP_CHANNEL=$(rapids-download-conda-from-s3 cpp)
PYTHON_CHANNEL=$(rapids-download-conda-from-s3 python)

rapids-mamba-retry install \
  --channel "${CPP_CHANNEL}" \
  --channel "${PYTHON_CHANNEL}" \
  kvikio libkvikio

export RAPIDS_VERSION="$(rapids-version)"
export RAPIDS_VERSION_MAJOR_MINOR="$(rapids-version-major-minor)"
export RAPIDS_VERSION_NUMBER="$RAPIDS_VERSION_MAJOR_MINOR"
export RAPIDS_DOCS_DIR="$(mktemp -d)"

rapids-logger "Build CPP docs"
pushd cpp/doxygen
doxygen Doxyfile
mkdir -p "${RAPIDS_DOCS_DIR}/libkvikio/html"
mv html/* "${RAPIDS_DOCS_DIR}/libkvikio/html"
popd

rapids-logger "Build Python docs"
pushd docs
sphinx-build -b dirhtml source _html -W
sphinx-build -b text source _text -W
mkdir -p "${RAPIDS_DOCS_DIR}/kvikio/"{html,txt}
mv _html/* "${RAPIDS_DOCS_DIR}/kvikio/html"
mv _text/* "${RAPIDS_DOCS_DIR}/kvikio/txt"
popd

rapids-upload-docs
