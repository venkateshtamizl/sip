#!/bin/bash
set -e

# Paths inside container
ASTERISK_ETC="/etc/asterisk"
#ASTERISK_LIB="/var/lib/asterisk"
ASTERISK_SPOOL="/var/spool/asterisk"
##ASTERISK_LOG="/var/log/asterisk"

# Where you will mount your local config files on the host (recommended)
HOST_CONFIG_MOUNT="/config_local"

# If user mounted real etc/lib/spool/log directly to container paths (common),
# copying isn't necessary — the mount overrides container contents.
# To support both behaviors:
# - If /config_local exists and is non-empty, copy files into target paths (replace).
# - Else, if target paths are empty and sample files exist in container, create hostdir content (useful when using named volumes).
# This script always ensures ownership/permissions are reasonable.

echo "ENTRYPOINT: starting pre-start config sync..."

# helper to copy if source exists
copy_if_present() {
  local src="$1"
  local dest="$2"
  if [ -d "$src" ] && [ "$(ls -A "$src")" ]; then
    echo "Copying from $src -> $dest (replacing)"
    # ensure dest exists
    mkdir -p "$dest"
    # copy (preserve ownership/mode)
    cp -aT "$src" "$dest"
  else
    echo "No files at $src, skipping copy to $dest"
  fi
}

# If user mounted /config_local (recommended) use it to overwrite asterisk dirs
if [ -d "${HOST_CONFIG_MOUNT}" ] && [ "$(ls -A ${HOST_CONFIG_MOUNT} 2>/dev/null)" ]; then
  echo "Found mounted config dir ${HOST_CONFIG_MOUNT}, using to replace Asterisk configs."
  copy_if_present "${HOST_CONFIG_MOUNT}/etc" "${ASTERISK_ETC}"
  #copy_if_present "${HOST_CONFIG_MOUNT}/lib" "${ASTERISK_LIB}"
  copy_if_present "${HOST_CONFIG_MOUNT}/spool" "${ASTERISK_SPOOL}"
  #copy_if_present "${HOST_CONFIG_MOUNT}/log" "${ASTERISK_LOG}"
else
  echo "No /config_local mount with config detected."

  # If user bound host directories directly to asterisk dirs (e.g. -v ./etc:/etc/asterisk),
  # those mounts already override the container content, so nothing to copy.

  # If using docker named volumes and they are empty, optionally populate them with sample files:
  # (only copy container default files into empty mounted volumes)
  if [ -d "${ASTERISK_ETC}" ] && [ -z "$(ls -A ${ASTERISK_ETC} 2>/dev/null)" ]; then
    echo "${ASTERISK_ETC} is empty, populating with sample config from container."
    cp -a /usr/src/asterisk/configs/* "${ASTERISK_ETC}" 2>/dev/null || true
  fi
fi

# Ensure permissions are writable
chown -R root:root "${ASTERISK_ETC}" "${ASTERISK_SPOOL}"  2>/dev/null || true
chmod -R u+rw "${ASTERISK_ETC}" "${ASTERISK_SPOOL}" 2>/dev/null || true

echo "Pre-start config sync done."

# Exec Asterisk (CMD appended as args)
echo "Starting Asterisk..."
exec "$@"
