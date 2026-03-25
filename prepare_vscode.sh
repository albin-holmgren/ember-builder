#!/usr/bin/env bash
# shellcheck disable=SC1091,2154
set -e

# include common functions
. ./utils.sh

cd vscode || { echo "'vscode' dir not found"; exit 1; }

../update_settings.sh

# apply patches
{ set +x; } 2>/dev/null

echo "APP_NAME=\"${APP_NAME}\""
echo "APP_NAME_LC=\"${APP_NAME_LC}\""
echo "BINARY_NAME=\"${BINARY_NAME}\""
echo "GH_REPO_PATH=\"${GH_REPO_PATH}\""
echo "ORG_NAME=\"${ORG_NAME}\""

echo "Applying patches at ../patches/*.patch..."
for file in ../patches/*.patch; do
  if [[ -f "${file}" ]]; then
    apply_patch "${file}"
  fi
done

if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
  echo "Applying insider patches..."
  for file in ../patches/insider/*.patch; do
    if [[ -f "${file}" ]]; then
      apply_patch "${file}"
    fi
  done
fi

if [[ -d "../patches/${OS_NAME}/" ]]; then
  echo "Applying OS patches (${OS_NAME})..."
  for file in "../patches/${OS_NAME}/"*.patch; do
    if [[ -f "${file}" ]]; then
      apply_patch "${file}"
    fi
  done
fi

echo "Applying user patches..."
for file in ../patches/user/*.patch; do
  if [[ -f "${file}" ]]; then
    apply_patch "${file}"
  fi
done

set -x

export ELECTRON_SKIP_BINARY_DOWNLOAD=1
export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

if [[ "${OS_NAME}" == "linux" ]]; then
  export VSCODE_SKIP_NODE_VERSION_CHECK=1
  if [[ "${npm_config_arch}" == "arm" ]]; then
    export npm_config_arm_version=7
  fi
elif [[ "${OS_NAME}" == "windows" ]]; then
  if [[ "${npm_config_arch}" == "arm" ]]; then
    export npm_config_arm_version=7
  fi
else
  if [[ "${CI_BUILD}" != "no" ]]; then
    clang++ --version
  fi
fi

mv .npmrc .npmrc.bak
cp ../npmrc .npmrc

for i in {1..5}; do
  if [[ "${CI_BUILD}" != "no" && "${OS_NAME}" == "osx" ]]; then
    CXX=clang++ npm ci && break
  else
    npm ci && break
  fi
  if [[ $i == 3 ]]; then
    echo "Npm install failed too many times" >&2
    exit 1
  fi
  echo "Npm install failed $i, trying again..."
  sleep $(( 15 * (i + 1)))
done

mv .npmrc.bak .npmrc

setpath() {
  local jsonTmp
  { set +x; } 2>/dev/null
  jsonTmp=$( jq --arg 'path' "${2}" --arg 'value' "${3}" 'setpath([$path]; $value)' "${1}.json" )
  echo "${jsonTmp}" > "${1}.json"
  set -x
}

setpath_json() {
  local jsonTmp
  { set +x; } 2>/dev/null
  jsonTmp=$( jq --arg 'path' "${2}" --argjson 'value' "${3}" 'setpath([$path]; $value)' "${1}.json" )
  echo "${jsonTmp}" > "${1}.json"
  set -x
}

# product.json
cp product.json{,.bak}

setpath "product" "checksumFailMoreInfoUrl" "https://go.microsoft.com/fwlink/?LinkId=828886"
setpath "product" "documentationUrl" "https://aventir.ai"
setpath "product" "introductoryVideosUrl" "https://go.microsoft.com/fwlink/?linkid=832146"
setpath "product" "keyboardShortcutsUrlLinux" "https://go.microsoft.com/fwlink/?linkid=832144"
setpath "product" "keyboardShortcutsUrlMac" "https://go.microsoft.com/fwlink/?linkid=832143"
setpath "product" "keyboardShortcutsUrlWin" "https://go.microsoft.com/fwlink/?linkid=832145"
setpath "product" "licenseUrl" "https://github.com/albin-holmgren/Aventir-Ember/blob/main/LICENSE.txt"
setpath "product" "reportIssueUrl" "https://github.com/albin-holmgren/Aventir-Ember/issues/new"
setpath "product" "requestFeatureUrl" "https://github.com/albin-holmgren/Aventir-Ember/issues/new"
setpath "product" "tipsAndTricksUrl" "https://go.microsoft.com/fwlink/?linkid=852118"
setpath "product" "twitterUrl" "https://x.com/aventirai"

if [[ "${DISABLE_UPDATE}" != "yes" ]]; then
  setpath "product" "updateUrl" "https://raw.githubusercontent.com/albin-holmgren/ember-versions/refs/heads/main"
  setpath "product" "downloadUrl" "https://github.com/albin-holmgren/ember-binaries/releases"
fi

setpath "product" "nameShort" "Ember"
setpath "product" "nameLong" "Ember - AI Code Editor"
setpath "product" "applicationName" "ember"
setpath "product" "linuxIconName" "ember"
setpath "product" "quality" "stable"
setpath "product" "urlProtocol" "ember"
setpath "product" "serverApplicationName" "ember-server"
setpath "product" "serverDataFolderName" ".ember-server"
setpath "product" "darwinBundleIdentifier" "ai.aventir.ember"
setpath "product" "win32AppUserModelId" "Aventir.Ember"
setpath "product" "win32DirName" "Aventir Ember"
setpath "product" "win32MutexName" "ember"
setpath "product" "win32NameVersion" "Aventir Ember"
setpath "product" "win32RegValueName" "Ember"
setpath "product" "win32ShellNameShort" "Ember"

jsonTmp=$( jq -s '.[0] * .[1]' product.json ../product.json )
echo "${jsonTmp}" > product.json && unset jsonTmp

cat product.json

# package.json
cp package.json{,.bak}

setpath "package" "version" "${RELEASE_VERSION%-insider}"

replace 's|Microsoft Corporation|Aventir|' package.json

cp resources/server/manifest.json{,.bak}
setpath "resources/server/manifest" "name" "Ember"
setpath "resources/server/manifest" "short_name" "Ember"

../undo_telemetry.sh

replace 's|Microsoft Corporation|Aventir|' build/lib/electron.js
replace 's|Microsoft Corporation|Aventir|' build/lib/electron.ts
replace 's|([0-9]) Microsoft|\1 Aventir|' build/lib/electron.js
replace 's|([0-9]) Microsoft|\1 Aventir|' build/lib/electron.ts

if [[ "${OS_NAME}" == "linux" ]]; then
  if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
    sed -i "s/code-oss/ember-insiders/" resources/linux/debian/postinst.template
  else
    sed -i "s/code-oss/ember/" resources/linux/debian/postinst.template
  fi

  sed -i 's|Visual Studio Code|Ember|g' resources/linux/code.appdata.xml
  sed -i 's|https://code.visualstudio.com/docs/setup/linux|https://aventir.ai|' resources/linux/code.appdata.xml
  sed -i 's|https://code.visualstudio.com/home/home-screenshot-linux-lg.png|https://aventir.ai/img/ember.png|' resources/linux/code.appdata.xml
  sed -i 's|https://code.visualstudio.com|https://aventir.ai|' resources/linux/code.appdata.xml

  sed -i 's|Microsoft Corporation <vscode-linux@microsoft.com>|Aventir <hello@aventir.ai>|' resources/linux/debian/control.template
  sed -i 's|Visual Studio Code|Ember|g' resources/linux/debian/control.template
  sed -i 's|https://code.visualstudio.com/docs/setup/linux|https://aventir.ai|' resources/linux/debian/control.template
  sed -i 's|https://code.visualstudio.com|https://aventir.ai|' resources/linux/debian/control.template

  sed -i 's|Microsoft Corporation|Aventir|' resources/linux/rpm/code.spec.template
  sed -i 's|Visual Studio Code Team <vscode-linux@microsoft.com>|Aventir <hello@aventir.ai>|' resources/linux/rpm/code.spec.template
  sed -i 's|Visual Studio Code|Ember|' resources/linux/rpm/code.spec.template
  sed -i 's|https://code.visualstudio.com/docs/setup/linux|https://aventir.ai|' resources/linux/rpm/code.spec.template
  sed -i 's|https://code.visualstudio.com|https://aventir.ai|' resources/linux/rpm/code.spec.template
elif [[ "${OS_NAME}" == "windows" ]]; then
  sed -i 's|https://code.visualstudio.com|https://aventir.ai|' build/win32/code.iss
  sed -i 's|Microsoft Corporation|Aventir|' build/win32/code.iss
fi

cd ..
