#! /bin/env bash
# set -ouex pipefail # disabled since protnvpn installation returns errors

# Global variables
DOWNLOAD_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
JQ_PARSE_RELEASE=".Releases | sort_by(.ReleaseDate) | last"
JQ_PARSE_PACKAGE=".File[] | select(.Identifier | contains(\".deb\")) | .Url"
JQ_PARSE_SHA512=".File[] | select(.Identifier | contains(\".deb\")) | .Sha512CheckSum"
INIT_HOOK_SUCCESS_FILE="/opt/.init-hook-success"

#Check if distrobox init-hook has already run
if test -f "${INIT_HOOK_SUCCESS_FILE}"; then
  echo "distrobox init-hook has already successfully run"
  exit 0
fi

# Install dependencies
sudo apt-get update
sudo apt-get -y install --no-install-recommends jq libasound2-plugins

## Install proton mail
PROTON_MAIL_VERSION_FILE="https://proton.me/download/mail/linux/version.json"
PROTON_MAIL_RELEASE_LATEST=$(curl -s "${PROTON_MAIL_VERSION_FILE}" | jq -r "${JQ_PARSE_RELEASE}")
PROTON_MAIL_PACKAGE_URL=$(echo "${PROTON_MAIL_RELEASE_LATEST}" | jq -r "${JQ_PARSE_PACKAGE}")
PROTON_MAIL_PACKAGE_NAME=$(basename "${PROTON_MAIL_PACKAGE_URL}")
PROTON_MAIL_PACKAGE_SHA512=$(echo "${PROTON_MAIL_RELEASE_LATEST}" | jq -r "${JQ_PARSE_SHA512}")
wget -O "${DOWNLOAD_DIR}/${PROTON_MAIL_PACKAGE_NAME}" "${PROTON_MAIL_PACKAGE_URL}"
if echo "${PROTON_MAIL_PACKAGE_SHA512} ${DOWNLOAD_DIR}/${PROTON_MAIL_PACKAGE_NAME}" | sha512sum --check; then
  echo "SHA512 checksum verification successful."
  sudo apt-get -y install --no-install-recommends "${DOWNLOAD_DIR}/${PROTON_MAIL_PACKAGE_NAME}"
else
  echo "SHA512 checksum verification failed. Aborting installation."
  exit 1
fi

## Install proton pass
PROTON_PASS_VERSION_FILE="https://proton.me/download/PassDesktop/linux/x64/version.json"
PROTON_PASS_RELEASE_LATEST=$(curl -s "${PROTON_PASS_VERSION_FILE}" | jq -r "${JQ_PARSE_RELEASE}")
PROTON_PASS_PACKAGE_URL=$(echo "${PROTON_PASS_RELEASE_LATEST}" | jq -r "${JQ_PARSE_PACKAGE}")
PROTON_PASS_PACKAGE_NAME=$(basename "${PROTON_PASS_PACKAGE_URL}")
PROTON_PASS_PACKAGE_SHA512=$(echo "${PROTON_PASS_RELEASE_LATEST}" | jq -r "${JQ_PARSE_SHA512}")
wget -O "${DOWNLOAD_DIR}/${PROTON_PASS_PACKAGE_NAME}" "${PROTON_PASS_PACKAGE_URL}"
if echo "${PROTON_PASS_PACKAGE_SHA512} ${DOWNLOAD_DIR}/${PROTON_PASS_PACKAGE_NAME}" | sha512sum --check; then
  echo "SHA512 checksum verification successful."
  sudo apt-get -y install --no-install-recommends "${DOWNLOAD_DIR}/${PROTON_PASS_PACKAGE_NAME}"
else
  echo "SHA512 checksum verification failed. Aborting installation."
  exit 1
fi

## Install proton vpn
PROTONVPN_DOWNLOAD_BASE_URL="https://repo.protonvpn.com/debian"
PROTONVPN_PACKAGE_INFO="${PROTONVPN_DOWNLOAD_BASE_URL}/dists/stable/main/binary-all/Packages"
PROTONVPN_PATH_REGEX='(?<=Filename: ).*protonvpn-stable-release.*'
## Get all href's for debian installer
PROTONVPN_DEB_PATHS=$(curl -s "${PROTONVPN_PACKAGE_INFO}" | grep -oP "${PROTONVPN_PATH_REGEX}")
## Sort results in numeric reverse order
readarray -td '' PROTONVPN_DEB_PATHS_SORTED < <(printf '%s\0' "${PROTONVPN_DEB_PATHS[@]}" | sort -rn)
## Download installer
PROTONVPN_DOWNLOAD_URL="${PROTONVPN_DOWNLOAD_BASE_URL}/${PROTONVPN_DEB_PATHS_SORTED[0]}"
PROTONVPN_INSTALLER_NAME=$(basename "${PROTONVPN_DOWNLOAD_URL}")
wget -O "${DOWNLOAD_DIR}/${PROTONVPN_INSTALLER_NAME}" "${PROTONVPN_DOWNLOAD_URL}"
## Install
sudo dpkg -i "${DOWNLOAD_DIR}/${PROTONVPN_INSTALLER_NAME}" && sudo apt-get update
sudo apt-get -y install --no-install-recommends proton-vpn-gnome-desktop &>/dev/null # installation in container will return some errors but usually they can be ignored

# Set installed flag
sudo touch "${INIT_HOOK_SUCCESS_FILE}"
