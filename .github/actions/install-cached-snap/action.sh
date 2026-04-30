#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Canonical Ltd.

set -e

SNAP_NAME="${SNAP_NAME:?SNAP_NAME not set}"
CHANNEL="${CHANNEL:?CHANNEL not set}"
CLASSIC="${CLASSIC:?CLASSIC not set}"
CACHE_DIR="${CACHE_DIR:?CACHE_DIR not set}"

mkdir -p "$CACHE_DIR"

# Look for cached snap file
SNAP_FILE=""
for snap in "$CACHE_DIR"/"${SNAP_NAME}"_*.snap; do
  if [ -f "$snap" ]; then
    SNAP_FILE="$snap"
    break
  fi
done

# Download if not cached
if [ -z "$SNAP_FILE" ]; then
  if [ -n "$CHANNEL" ]; then
    snap download --target-directory "$CACHE_DIR" --channel "$CHANNEL" "$SNAP_NAME"
  else
    snap download --target-directory "$CACHE_DIR" "$SNAP_NAME"
  fi
  for snap in "$CACHE_DIR"/"${SNAP_NAME}"_*.snap; do
    if [ -f "$snap" ]; then
      SNAP_FILE="$snap"
      break
    fi
  done
fi

if [ -z "$SNAP_FILE" ]; then
  echo "::error::Unable to locate or download snap for $SNAP_NAME"
  exit 1
fi

# Acknowledge assertion if present
ASSERT_FILE="${SNAP_FILE%.snap}.assert"
if [ -f "$ASSERT_FILE" ]; then
  sudo snap ack "$ASSERT_FILE"
fi

# Install the snap
if [ "$CLASSIC" = "true" ]; then
  sudo snap install --classic "$SNAP_FILE"
else
  sudo snap install "$SNAP_FILE"
fi
