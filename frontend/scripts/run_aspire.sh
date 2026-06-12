#!/bin/bash
# Wrapper to run `flutter run` with injected env variables turned into --dart-define flags.
# Usage: ./run_flutter.sh <platform> [extra flutter args]
set -euo pipefail

PLATFORM=${1:-web}
shift || true

# Build dart-define from environment variables
DART_DEFINES=()
for kv in $(env); do
  name=$(echo "$kv" | sed -E 's/=.*//' )
  value=$(echo "$kv" | sed -E 's/^[^=]*=//')
  DART_DEFINES+=("--dart-define=${name}=${value}")
done

case "$PLATFORM" in
  web)
    # Use web-server so we can control hostname/port. Let Aspire provide external endpoint.
    echo flutter run -d web-server --web-hostname 0.0.0.0 --web-port ${PORT-0} "${DART_DEFINES[@]}" "$@"
    exec flutter run -d web-server --hot --web-hostname 0.0.0.0 --web-port ${PORT-0} "${DART_DEFINES[@]}" "$@"
    ;;
  android)
    # For Android, assume a connected device / emulator is available. Pass dart defines.
    exec flutter run "${DART_DEFINES[@]}" "$@"
    ;;
  ios)
    exec flutter run -d ios "${DART_DEFINES[@]}" "$@"
    ;;
  *)
    echo "Unknown platform: $PLATFORM" >&2
    exit 2
    ;;
esac
