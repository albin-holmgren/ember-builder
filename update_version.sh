#!/usr/bin/env bash
# shellcheck disable=SC1091
set -e

if [[ "${SHOULD_BUILD}" != "yes" && "${FORCE_UPDATE}" != "true" ]]; then
  echo "Will not update version JSON because we did not build"
  exit 0
fi

if [[ -z "${GH_TOKEN}" ]] && [[ -z "${GITHUB_TOKEN}" ]] && [[ -z "${GH_ENTERPRISE_TOKEN}" ]] && [[ -z "${GITHUB_ENTERPRISE_TOKEN}" ]]; then
  echo "Will not update version JSON because no GITHUB_TOKEN defined"
  exit 0
else
  GITHUB_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-${GH_ENTERPRISE_TOKEN:-${GITHUB_ENTERPRISE_TOKEN}}}}"
fi

GH_HOST="${GH_HOST:-github.com}"

if [[ "${FORCE_UPDATE}" == "true" ]]; then
  . version.sh
fi

if [[ -z "${BUILD_SOURCEVERSION}" ]]; then
  echo "Will not update version JSON because no BUILD_SOURCEVERSION defined"
  exit 0
fi

REPOSITORY_NAME="${VERSIONS_REPOSITORY/*\//}"
URL_BASE="https://${GH_HOST}/${ASSETS_REPOSITORY}/releases/download/${RELEASE_VERSION}"

generateJson() {
  local url name version productVersion sha1hash sha256hash timestamp
  JSON_DATA="{}"

  url="${URL_BASE}/${ASSET_NAME}"
  name="${RELEASE_VERSION}"
  version="${BUILD_SOURCEVERSION}"
  productVersion="$( transformVersion "${RELEASE_VERSION}" )"
  timestamp=$( node -e 'console.log(Date.now())' )

  if [[ ! -f "assets/${ASSET_NAME}" ]]; then
    echo "Downloading asset '${ASSET_NAME}'"
    gh release download --repo "${ASSETS_REPOSITORY}" "${RELEASE_VERSION}" --dir "assets" --pattern "${ASSET_NAME}*"
  fi

  sha1hash=$( awk '{ print $1 }' "assets/${ASSET_NAME}.sha1" )
  sha256hash=$( awk '{ print $1 }' "assets/${ASSET_NAME}.sha256" )

  for key in url name version productVersion sha1hash timestamp sha256hash; do
    if [[ -z "${key}" ]]; then
      echo "Variable '${key}' is empty; exiting..."
      exit 1
    fi
  done

  JSON_DATA=$( jq \
    --arg url             "${url}" \
    --arg name            "${name}" \
    --arg version         "${version}" \
    --arg productVersion  "${productVersion}" \
    --arg hash            "${sha1hash}" \
    --arg timestamp       "${timestamp}" \
    --arg sha256hash      "${sha256hash}" \
    '. | .url=$url | .name=$name | .version=$version | .productVersion=$productVersion | .hash=$hash | .timestamp=$timestamp | .sha256hash=$sha256hash' \
    <<<'{}' )
}

transformVersion() {
  local version parts
  version="${1%-insider}"
  IFS='.' read -r -a parts <<< "${version}"
  parts[2]="$((10#${parts[2]}))"
  version="${parts[0]}.${parts[1]}.${parts[2]}.0"
  if [[ "${1}" == *-insider ]]; then
    version="${version}-insider"
  fi
  echo "${version}"
}

updateLatestVersion() {
  echo "Updating ${VERSION_PATH}/latest.json"

  if [[ -f "${REPOSITORY_NAME}/${VERSION_PATH}/latest.json" ]]; then
    CURRENT_VERSION=$( jq -r '.name' "${REPOSITORY_NAME}/${VERSION_PATH}/latest.json" )
    echo "CURRENT_VERSION: ${CURRENT_VERSION}"
    if [[ "${CURRENT_VERSION}" == "${RELEASE_VERSION}" && "${FORCE_UPDATE}" != "true" ]]; then
      return 0
    fi
  fi

  echo "Generating ${VERSION_PATH}/latest.json"
  mkdir -p "${REPOSITORY_NAME}/${VERSION_PATH}"
  generateJson
  echo "${JSON_DATA}" > "${REPOSITORY_NAME}/${VERSION_PATH}/latest.json"
  echo "${JSON_DATA}"
}

git clone "https://${GH_HOST}/${VERSIONS_REPOSITORY}.git"
cd "${REPOSITORY_NAME}" || { echo "'${REPOSITORY_NAME}' dir not found"; exit 1; }
git config user.email "$( echo "${GITHUB_USERNAME}" | awk '{print tolower($0)}' )-ci@not-real.com"
git config user.name "${GITHUB_USERNAME} CI"
git remote rm origin
git remote add origin "https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@${GH_HOST}/${VERSIONS_REPOSITORY}.git" &> /dev/null
cd ..

if [[ "${OS_NAME}" == "osx" ]]; then
  ASSET_NAME="${APP_NAME}-darwin-${VSCODE_ARCH}-${RELEASE_VERSION}.zip"
  VERSION_PATH="${VSCODE_QUALITY}/darwin/${VSCODE_ARCH}"
  updateLatestVersion
elif [[ "${OS_NAME}" == "windows" ]]; then
  ASSET_NAME="${APP_NAME}Setup-${VSCODE_ARCH}-${RELEASE_VERSION}.exe"
  VERSION_PATH="${VSCODE_QUALITY}/win32/${VSCODE_ARCH}/system"
  updateLatestVersion

  ASSET_NAME="${APP_NAME}UserSetup-${VSCODE_ARCH}-${RELEASE_VERSION}.exe"
  VERSION_PATH="${VSCODE_QUALITY}/win32/${VSCODE_ARCH}/user"
  updateLatestVersion

  ASSET_NAME="${APP_NAME}-win32-${VSCODE_ARCH}-${RELEASE_VERSION}.zip"
  VERSION_PATH="${VSCODE_QUALITY}/win32/${VSCODE_ARCH}/archive"
  updateLatestVersion

  if [[ "${VSCODE_ARCH}" == "ia32" || "${VSCODE_ARCH}" == "x64" ]]; then
    ASSET_NAME="${APP_NAME}-${VSCODE_ARCH}-${RELEASE_VERSION}.msi"
    VERSION_PATH="${VSCODE_QUALITY}/win32/${VSCODE_ARCH}/msi"
    updateLatestVersion

    ASSET_NAME="${APP_NAME}-${VSCODE_ARCH}-updates-disabled-${RELEASE_VERSION}.msi"
    VERSION_PATH="${VSCODE_QUALITY}/win32/${VSCODE_ARCH}/msi-updates-disabled"
    updateLatestVersion
  fi
else
  ASSET_NAME="${APP_NAME}-linux-${VSCODE_ARCH}-${RELEASE_VERSION}.tar.gz"
  VERSION_PATH="${VSCODE_QUALITY}/linux/${VSCODE_ARCH}"
  updateLatestVersion
fi

cd "${REPOSITORY_NAME}" || { echo "'${REPOSITORY_NAME}' dir not found"; exit 1; }

git pull origin main
git add .

CHANGES=$( git status --porcelain )

if [[ -n "${CHANGES}" ]]; then
  echo "Some changes have been found, pushing them"
  dateAndMonth=$( date "+%D %T" )
  git commit -m "CI update: ${dateAndMonth} (Build ${GITHUB_RUN_NUMBER})"
  if ! git push origin main --quiet; then
    git pull origin main
    git push origin main --quiet
  fi
else
  echo "No changes"
fi

cd ..
