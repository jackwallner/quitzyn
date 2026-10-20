#!/bin/bash
# Run the Android instrumented smoke tests on the remote Pro's temporary AVD.
#
# Builds the debug app and test APKs on the Pro with fm-gradle (outputs copy
# back here), installs them on the Pro emulator over SSH, and runs each test in
# a fresh process with cleared app data (the test orchestrator cannot reach its
# service on the API 36.1 image). Prints a per-test result and exits non-zero
# on any failure or a zero executed count.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
host="${ANDROID_TEST_HOST:-jackwallner@192.168.4.25}"
serial="${ANDROID_SERIAL:-emulator-5560}"
ssh_opts=(-o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=yes)
adb="$HOME/Library/Android/sdk/platform-tools/adb -s $serial"
runner="com.jackwallner.quitzyn.test/androidx.test.runner.AndroidJUnitRunner"
test_class="com.jackwallner.quitzyn.SmokeTest"

# ANDROID_TEST_HOST=local runs on this machine (the fleet Pro itself) with the
# checked-in Gradle wrapper and JDK 17.
if [[ "$host" == local ]]; then
  remote() { bash -c "$*"; }
  copy() { cp "$@"; }
  (cd "$repo/android" && JAVA_HOME="${JAVA_HOME:-$HOME/jdks/temurin-17/Contents/Home}" ./gradlew --no-daemon -q assembleDebug assembleDebugAndroidTest)
else
  remote() { ssh "${ssh_opts[@]}" "$host" "$@"; }
  copy() { scp -q "${ssh_opts[@]}" "${@:1:$#-1}" "$host:${@: -1}"; }
  fm-gradle -p "$repo/android" -q assembleDebug assembleDebugAndroidTest
fi
apk="$repo/android/app/build/outputs/apk/debug/app-debug.apk"
test_apk="$repo/android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk"

boot="$(remote "$adb shell getprop sys.boot_completed" | tr -d '\r')"
if [[ "$boot" != "1" ]]; then
  echo "$serial on $host is not booted; start the temporary AVD first (.claude/rules/android.md)." >&2
  exit 1
fi

remote_dir="$(remote 'mktemp -d /tmp/quitzyn-android-test.XXXXXX')"
trap 'remote "rm -rf $remote_dir"' EXIT
copy "$apk" "$test_apk" "$remote_dir/"
remote "$adb install -r -t $remote_dir/app-debug.apk >/dev/null && $adb install -r -t $remote_dir/app-debug-androidTest.apk >/dev/null"

tests="$(grep -oE '@Test fun [A-Za-z0-9_]+' "$repo/android/app/src/androidTest/java/com/jackwallner/quitzyn/SmokeTest.kt" | awk '{print $3}')"
passed=0
failed=0
raw_dir="$(mktemp -d)"
for t in $tests; do
  remote "$adb shell pm clear com.jackwallner.quitzyn >/dev/null"
  out="$(remote "$adb shell am instrument -r -w -e class $test_class#$t $runner")"
  printf '%s\n' "$out" > "$raw_dir/$t.txt"
  if grep -q 'OK (1 test)' <<<"$out"; then
    echo "PASS $t"
    passed=$((passed + 1))
  else
    echo "FAIL $t"
    grep -m1 'stack=' <<<"$out" || true
    failed=$((failed + 1))
  fi
done

report="$repo/android/app/build/outputs/androidTest-results/connected/TEST-quitzyn-smoke.xml"
mkdir -p "$(dirname "$report")"
python3 "$repo/scripts/android-instrument-junit.py" "$report" "$raw_dir"/*.txt || true
echo "Executed $((passed + failed)) instrumented tests on $serial: $passed passed, $failed failed."
[[ $failed -eq 0 && $passed -gt 0 ]]
