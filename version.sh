#!/usr/bin/env bash

if [[ -z "${BUILD_SOURCEVERSION}" ]]; then
    echo "running version.sh"
    if [[ -d "./vscode" ]]; then
        echo "getting vscode source version..."
        CURRENT_DIR=$(pwd)
        cd ./vscode
        BUILD_SOURCEVERSION=$(git rev-parse HEAD)
        cd ..
    else
      npm install -g checksum
      BUILD_SOURCEVERSION=$( echo "${RELEASE_VERSION/-*/}" | checksum )
    fi

    echo "BUILD_SOURCEVERSION=\"${BUILD_SOURCEVERSION}\""

    if [[ "${GITHUB_ENV}" ]]; then
        echo "BUILD_SOURCEVERSION=${BUILD_SOURCEVERSION}" >> "${GITHUB_ENV}"
    fi
fi

export BUILD_SOURCEVERSION
