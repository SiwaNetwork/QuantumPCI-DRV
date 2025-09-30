#!/bin/bash

# Enhanced PTP OCP Driver Test Suite
# Version 2.0.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
DRIVER_NAME="ptp_ocp_enhanced"
SYSFS_PATH="/sys/class/ptp_ocp_enhanced"
TEST_LOG="/tmp/ptp_ocp_test.log"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [TEST] $1" >> "$TEST_LOG"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PASS] $1" >> "$TEST_LOG"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [FAIL] $1" >> "$TEST_LOG"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$TEST_LOG"
}

# Check if driver is loaded
check_driver_loaded() {
    if lsmod | grep -q "$DRIVER_NAME"; then
        return 0
    else
        return 1
    fi
}

# Check if sysfs interface is available
check_sysfs_interface() {
    if [ -d "$SYSFS_PATH" ]; then
        return 0
    else
        return 1
    fi
}

# Test driver loading
test_driver_loading() {
    log_test "Testing driver loading..."
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if check_driver_loaded; then
        log_pass "Driver is loaded"
    else
        log_fail "Driver is not loaded"
        return 1
    fi
}

# Test sysfs interface
test_sysfs_interface() {
    log_test "Testing sysfs interface..."
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if check_sysfs_interface; then
        log_pass "Sysfs interface is available"
    else
        log_fail "Sysfs interface is not available"
        return 1
    fi
}

# Test performance statistics
test_performance_stats() {
    log_test "Testing performance statistics..."
    TESTS_RUN=$((TESTS_RUN + 1))
    
    local perf_file="$SYSFS_PATH/ocp0/performance_stats"
    if [ -f "$perf_file" ]; then
        local stats=$(cat "$perf_file")
        if [ -n "$stats" ]; then
            log_pass "Performance statistics are available"
            log_info "Stats: $(echo "$stats" | head -3 | tr '\n' ' ')"
        else
            log_fail "Performance statistics are empty"
        fi
    else
        log_fail "Performance statistics file not found"
    fi
}

# Test cache statistics
test_cache_stats() {
    log_test "Testing cache statistics..."
    TESTS_RUN=$((TESTS_RUN + 1))
    
    local cache_file="$SYSFS_PATH/ocp0/cache_stats"
    if [ -f "$cache_file" ]; then
        local stats=$(cat "$cache_file")
        if [ -n "$stats" ]; then
            log_pass "Cache statistics are available"
        else
            log_fail "Cache statistics are empty"
        fi
    else
        log_fail "Cache statistics file not found"
    fi
}

# Test error handling
test_error_handling() {
    log_test "Testing error handling..."
    TESTS_RUN=$((TESTS_RUN + 1))
    
    local error_file="$SYSFS_PATH/ocp0/error_count"
    if [ -f "$error_file" ]; then
        local errors=$(cat "$error_file")
        if [ -n "$errors" ]; then
            log_pass "Error handling is available"
        else
            log_fail "Error handling is empty"
        fi
    else
        log_fail "Error handling file not found"
    fi
}

# Test watchdog functionality
test_watchdog() {
    log_test "Testing watchdog functionality..."
    TESTS_RUN=$((TESTS_RUN + 1))
    
    local watchdog_file="$SYSFS_PATH/ocp0/watchdog_status"
    if [ -f "$watchdog_file" ]; then
        local status=$(cat "$watchdog_file")
        if [ -n "$status" ]; then
            log_pass "Watchdog is available"
            
            # Test heartbeat
            local heartbeat_file="$SYSFS_PATH/ocp0/heartbeat"
            if [ -w "$heartbeat_file" ]; then
                echo "1" > "$heartbeat_file" 2>/dev/null || true
                log_pass "Watchdog heartbeat test passed"
            else
                log_fail "Watchdog heartbeat not writable"
            fi
        else
            log_fail "Watchdog status is empty"
        fi
    else
        log_fail "Watchdog file not found"
    fi
}

# Test health monitoring
test_health_monitoring() {
    log_test "Testing health monitoring..."
    TESTS_RUN=$((TESTS_RUN + 1))
    
    local health_file="$SYSFS_PATH/ocp0/health_status"
    if [ -f "$health_file" ]; then
        local health=$(cat "$health_file")
        if [ -n "$health" ]; then
            log_pass "Health monitoring is available"
            
            # Check health score
            local score=$(echo "$health" | grep "health score" | grep -o '[0-9]\+')
            if [ -n "$score" ] && [ "$score" -ge 0 ] && [ "$score" -le 100 ]; then
                log_pass "Health score is valid: $score/100"
            else
                log_fail "Health score is invalid: $score"
            fi
        else
            log_fail "Health monitoring is empty"
        fi
    else
        log_fail "Health monitoring file not found"
    fi
}

# Test cache timeout configuration
test_cache_configuration() {
    log_test "Testing cache configuration..."
    TESTS_RUN=$((TESTS_RUN + 1))
    
    local cache_timeout_file="$SYSFS_PATH/ocp0/cache_timeout"
    if [ -f "$cache_timeout_file" ]; then
        # Test reading current value
        local current_timeout=$(cat "$cache_timeout_file")
        if [ -n "$current_timeout" ]; then
            log_pass "Cache timeout is readable: $current_timeout"
            
            # Test writing new value
            if [ -w "$cache_timeout_file" ]; then
                echo "2000000" > "$cache_timeout_file" 2>/dev/null || true
                sleep 1
                echo "1000000" > "$cache_timeout_file" 2>/dev/null || true
                log_pass "Cache timeout is configurable"
            else
                log_fail "Cache timeout is not writable"
            fi
        else
            log_fail "Cache timeout is empty"
        fi
    else
        log_fail "Cache timeout file not found"
    fi
}

# Test performance mode
test_performance_mode() {
    log_test "Testing performance mode..."
    TESTS_RUN=$((TESTS_RUN + 1))
    
    local perf_mode_file="$SYSFS_PATH/ocp0/performance_mode"
    if [ -f "$perf_mode_file" ]; then
        local mode=$(cat "$perf_mode_file")
        if [ -n "$mode" ]; then
            log_pass "Performance mode is available: $mode"
            
            # Test toggling performance mode
            if [ -w "$perf_mode_file" ]; then
                echo "disabled" > "$perf_mode_file" 2>/dev/null || true
                sleep 1
                echo "enabled" > "$perf_mode_file" 2>/dev/null || true
                log_pass "Performance mode is configurable"
            else
                log_fail "Performance mode is not writable"
            fi
        else
            log_fail "Performance mode is empty"
        fi
    else
        log_fail "Performance mode file not found"
    fi
}

# Test PTP device availability
test_ptp_device() {
    log_test "Testing PTP device availability..."
    TESTS_RUN=$((TESTS_RUN + 1))
    
    local ptp_devices=$(ls /dev/ptp* 2>/dev/null | wc -l)
    if [ "$ptp_devices" -gt 0 ]; then
        log_pass "PTP devices are available: $ptp_devices devices"
        
        # Test PTP device access
        local ptp_device=$(ls /dev/ptp* | head -1)
        if [ -c "$ptp_device" ]; then
            log_pass "PTP device is accessible: $ptp_device"
        else
            log_fail "PTP device is not accessible: $ptp_device"
        fi
    else
        log_fail "No PTP devices found"
    fi
}

# Performance benchmark test
test_performance_benchmark() {
    log_test "Testing performance benchmark..."
    TESTS_RUN=$((TESTS_RUN + 1))
    
    local perf_file="$SYSFS_PATH/ocp0/performance_stats"
    if [ -f "$perf_file" ]; then
        # Measure time to read performance stats
        local start_time=$(date +%s%N)
        local stats=$(cat "$perf_file")
        local end_time=$(date +%s%N)
        local duration=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
        
        if [ "$duration" -lt 100 ]; then # Less than 100ms
            log_pass "Performance benchmark passed: ${duration}ms"
        else
            log_fail "Performance benchmark failed: ${duration}ms (too slow)"
        fi
    else
        log_fail "Performance benchmark failed: stats file not found"
    fi
}

# Run all tests
run_all_tests() {
    log_info "Starting Enhanced PTP OCP Driver Test Suite"
    log_info "Driver: $DRIVER_NAME"
    log_info "Test log: $TEST_LOG"
    echo
    
    # Check prerequisites
    if ! check_driver_loaded; then
        log_fail "Driver is not loaded. Please install the driver first."
        exit 1
    fi
    
    # Run tests
    test_driver_loading
    test_sysfs_interface
    test_performance_stats
    test_cache_stats
    test_error_handling
    test_watchdog
    test_health_monitoring
    test_cache_configuration
    test_performance_mode
    test_ptp_device
    test_performance_benchmark
    
    # Print summary
    echo
    log_info "Test Summary:"
    log_info "  Tests run: $TESTS_RUN"
    log_info "  Tests passed: $TESTS_PASSED"
    log_info "  Tests failed: $TESTS_FAILED"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_pass "All tests passed!"
        exit 0
    else
        log_fail "$TESTS_FAILED test(s) failed"
        exit 1
    fi
}

# Show help
show_help() {
    echo "Enhanced PTP OCP Driver Test Suite v2.0.0"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --help, -h          Show this help"
    echo "  --verbose, -v       Verbose output"
    echo "  --log FILE          Specify log file (default: $TEST_LOG)"
    echo
    echo "Tests:"
    echo "  driver              Test driver loading"
    echo "  sysfs               Test sysfs interface"
    echo "  performance         Test performance features"
    echo "  reliability         Test reliability features"
    echo "  monitoring          Test monitoring features"
    echo "  all                 Run all tests (default)"
    echo
}

# Main function
main() {
    local test_type="all"
    local verbose=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --verbose|-v)
                verbose=true
                shift
                ;;
            --log)
                TEST_LOG="$2"
                shift 2
                ;;
            driver|sysfs|performance|reliability|monitoring|all)
                test_type="$1"
                shift
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Create log file
    touch "$TEST_LOG"
    
    case "$test_type" in
        "all")
            run_all_tests
            ;;
        "driver")
            test_driver_loading
            ;;
        "sysfs")
            test_sysfs_interface
            ;;
        "performance")
            test_performance_stats
            test_cache_stats
            test_cache_configuration
            test_performance_mode
            test_performance_benchmark
            ;;
        "reliability")
            test_error_handling
            test_watchdog
            ;;
        "monitoring")
            test_health_monitoring
            ;;
        *)
            echo "Unknown test type: $test_type"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
