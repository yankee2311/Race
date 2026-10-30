#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
if test -e build/debug.keystore; then
  echo 'La clave de pruebas ya existe; se conserva.'
  exit 0
fi
keytool -genkeypair -keystore build/debug.keystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname 'CN=Android Debug,O=Android,C=US'
