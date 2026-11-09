#!/usr/bin/env bash
set -eu
cd "${TEST_SRCDIR}/${TEST_WORKSPACE}/backend"
exec "${DART:-dart}" --suppress-analytics run run_tests.dart "$@"
