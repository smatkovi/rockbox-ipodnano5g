#!/usr/bin/env bash
set -u

cd "$(dirname "$0")"
arm-none-eabi-as -mcpu=arm1176jzf-s -o OSOS_iTunes_prefix_reachability_20261031.o OSOS_iTunes_prefix_reachability_20261031.S || exit 1
arm-none-eabi-ld -T OSOS_iTunes_prefix_reachability_20261031.ld -e success_start -o success.elf OSOS_iTunes_prefix_reachability_20261031.o || exit 1
arm-none-eabi-ld -T OSOS_iTunes_prefix_reachability_20261031.ld -e error_store_start -o error-store.elf OSOS_iTunes_prefix_reachability_20261031.o || exit 1
arm-none-eabi-ld -T OSOS_iTunes_prefix_reachability_20261031.ld -e error_branch_start -o error-branch.elf OSOS_iTunes_prefix_reachability_20261031.o || exit 1
arm-none-eabi-ld -T OSOS_iTunes_prefix_reachability_20261031.ld -e error_branch_back_start -o error-branch-back.elf OSOS_iTunes_prefix_reachability_20261031.o || exit 1
arm-none-eabi-ld -T OSOS_iTunes_prefix_reachability_20261031.ld -e error_branch_epoch_start -o error-branch-epoch.elf OSOS_iTunes_prefix_reachability_20261031.o || exit 1
arm-none-eabi-ld -T OSOS_iTunes_prefix_reachability_20261031.ld -e error_branch_zero_time_start -o error-branch-zero-time.elf OSOS_iTunes_prefix_reachability_20261031.o || exit 1

run_case() {
    local label="$1"
    local elf="$2"
    local logfile="$3"
    local rc
    timeout 10s qemu-system-arm \
        -M versatilepb -cpu arm1176 -m 192M -nographic \
        -monitor none -serial none \
        -semihosting-config enable=on,target=native \
        -kernel "$elf" >"$logfile" 2>&1
    rc=$?
    printf '%s exit=%s log=%s\n' "$label" "$rc" "$logfile"
    cat "$logfile"
    return "$rc"
}

run_status=0
run_case success_flags success.elf success_flags.log || run_status=1
run_case error_store error-store.elf error_store.log || run_status=1
run_case error_branch error-branch.elf error_branch.log || run_status=1
run_case error_branch_back error-branch-back.elf error_branch_back.log || run_status=1
run_case error_branch_epoch error-branch-epoch.elf error_branch_epoch.log || run_status=1
run_case error_branch_zero_time error-branch-zero-time.elf error_branch_zero_time.log || run_status=1
exit "$run_status"
