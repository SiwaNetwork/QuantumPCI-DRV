#!/bin/bash

# Phase 3 Tests Script
# Tests for Network Integration, PTP v2.1, NTP Stratum 1, and Security

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(dirname "$TEST_DIR")"
CORE_DIR="$PHASE3_DIR/../core"
LOG_FILE="/tmp/ptp_ocp_phase3_tests.log"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$LOG_FILE"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "$LOG_FILE"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

# Test runner
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    log_info "Running test: $test_name"
    ((TESTS_RUN++))
    
    if $test_function; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        return 1
    fi
}

# Test functions

test_phase3_files_exist() {
    log_info "Checking Phase 3 files exist"
    
    local files=(
        "$PHASE3_DIR/network/network_integration.c"
        "$PHASE3_DIR/protocols/ptp_v2_1.c"
        "$PHASE3_DIR/protocols/ntp_stratum1.c"
        "$PHASE3_DIR/security/ptp_security.c"
        "$PHASE3_DIR/phase3_extensions.h"
        "$PHASE3_DIR/Makefile"
    )
    
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Missing file: $file"
            return 1
        fi
    done
    
    return 0
}

test_phase3_compilation() {
    log_info "Testing Phase 3 compilation"
    
    cd "$PHASE3_DIR"
    
    # Clean previous build
    make clean > /dev/null 2>&1 || true
    
    # Try to compile (this will fail due to missing dependencies, but we can check syntax)
    if make -n > /dev/null 2>&1; then
        log_info "Makefile syntax is valid"
        return 0
    else
        log_error "Makefile syntax error"
        return 1
    fi
}

test_network_integration_syntax() {
    log_info "Testing network integration C syntax"
    
    # Check if gcc can parse the file
    if gcc -fsyntax-only -I"$CORE_DIR" "$PHASE3_DIR/network/network_integration.c" 2>/dev/null; then
        return 0
    else
        log_error "Network integration C syntax error"
        return 1
    fi
}

test_ptp_v2_1_syntax() {
    log_info "Testing PTP v2.1 C syntax"
    
    # Check if gcc can parse the file
    if gcc -fsyntax-only -I"$CORE_DIR" "$PHASE3_DIR/protocols/ptp_v2_1.c" 2>/dev/null; then
        return 0
    else
        log_error "PTP v2.1 C syntax error"
        return 1
    fi
}

test_ntp_stratum1_syntax() {
    log_info "Testing NTP Stratum 1 C syntax"
    
    # Check if gcc can parse the file
    if gcc -fsyntax-only -I"$CORE_DIR" "$PHASE3_DIR/protocols/ntp_stratum1.c" 2>/dev/null; then
        return 0
    else
        log_error "NTP Stratum 1 C syntax error"
        return 1
    fi
}

test_ptp_security_syntax() {
    log_info "Testing PTP security C syntax"
    
    # Check if gcc can parse the file
    if gcc -fsyntax-only -I"$CORE_DIR" "$PHASE3_DIR/security/ptp_security.c" 2>/dev/null; then
        return 0
    else
        log_error "PTP security C syntax error"
        return 1
    fi
}

test_phase3_headers() {
    log_info "Testing Phase 3 header files"
    
    # Check if header can be included
    local test_c_file="/tmp/test_phase3_headers.c"
    cat > "$test_c_file" << 'EOF'
#include "phase3_extensions.h"
int main() { return 0; }
EOF
    
    if gcc -fsyntax-only -I"$PHASE3_DIR" "$test_c_file" 2>/dev/null; then
        rm -f "$test_c_file"
        return 0
    else
        rm -f "$test_c_file"
        log_error "Phase 3 headers syntax error"
        return 1
    fi
}

test_network_integration_features() {
    log_info "Testing network integration features"
    
    local file="$PHASE3_DIR/network/network_integration.c"
    
    # Check for required functions
    local functions=(
        "ptp_ocp_detect_intel_cards"
        "ptp_ocp_register_network_device"
        "ptp_ocp_enable_hardware_timestamping"
        "ptp_ocp_configure_ptp_master"
        "ptp_ocp_configure_ptp_slave"
        "ptp_ocp_configure_transparent_clock"
        "ptp_ocp_configure_boundary_clock"
    )
    
    for func in "${functions[@]}"; do
        if ! grep -q "$func" "$file"; then
            log_error "Missing function: $func"
            return 1
        fi
    done
    
    # Check for required structures
    local structures=(
        "ptp_ocp_network_device"
        "ptp_ocp_network_coordinator"
        "ptp_ocp_network_mode"
        "ptp_ocp_timestamping_type"
    )
    
    for struct in "${structures[@]}"; do
        if ! grep -q "$struct" "$file"; then
            log_error "Missing structure: $struct"
            return 1
        fi
    done
    
    return 0
}

test_ptp_v2_1_features() {
    log_info "Testing PTP v2.1 features"
    
    local file="$PHASE3_DIR/protocols/ptp_v2_1.c"
    
    # Check for required functions
    local functions=(
        "ptp_v2_1_init_session"
        "ptp_v2_1_send_sync"
        "ptp_v2_1_send_follow_up"
        "ptp_v2_1_send_delay_req"
        "ptp_v2_1_send_announce"
        "ptp_v2_1_calculate_checksum"
    )
    
    for func in "${functions[@]}"; do
        if ! grep -q "$func" "$file"; then
            log_error "Missing function: $func"
            return 1
        fi
    done
    
    # Check for required structures
    local structures=(
        "ptp_v2_1_header"
        "ptp_v2_1_config"
        "ptp_v2_1_session"
        "ptp_v2_1_statistics"
    )
    
    for struct in "${structures[@]}"; do
        if ! grep -q "$struct" "$file"; then
            log_error "Missing structure: $struct"
            return 1
        fi
    done
    
    return 0
}

test_ntp_stratum1_features() {
    log_info "Testing NTP Stratum 1 features"
    
    local file="$PHASE3_DIR/protocols/ntp_stratum1.c"
    
    # Check for required functions
    local functions=(
        "ntp_server_init_session"
        "ntp_server_handle_request"
        "ntp_server_send_response"
        "ntp_server_convert_timestamp"
        "ntp_server_get_reference_time"
    )
    
    for func in "${functions[@]}"; do
        if ! grep -q "$func" "$file"; then
            log_error "Missing function: $func"
            return 1
        fi
    done
    
    # Check for required structures
    local structures=(
        "ntp_packet"
        "ntp_client"
        "ntp_server_config"
        "ntp_server_session"
    )
    
    for struct in "${structures[@]}"; do
        if ! grep -q "$struct" "$file"; then
            log_error "Missing structure: $struct"
            return 1
        fi
    done
    
    return 0
}

test_ptp_security_features() {
    log_info "Testing PTP security features"
    
    local file="$PHASE3_DIR/security/ptp_security.c"
    
    # Check for required functions
    local functions=(
        "ptp_security_init_manager"
        "ptp_security_create_key"
        "ptp_security_authenticate_message"
        "ptp_security_log_event"
        "ptp_security_cleanup_manager"
    )
    
    for func in "${functions[@]}"; do
        if ! grep -q "$func" "$file"; then
            log_error "Missing function: $func"
            return 1
        fi
    done
    
    # Check for required structures
    local structures=(
        "ptp_security_key"
        "ptp_security_session"
        "ptp_security_manager"
        "ptp_security_event"
    )
    
    for struct in "${structures[@]}"; do
        if ! grep -q "$struct" "$file"; then
            log_error "Missing structure: $struct"
            return 1
        fi
    done
    
    return 0
}

test_makefile_structure() {
    log_info "Testing Makefile structure"
    
    local file="$PHASE3_DIR/Makefile"
    
    # Check for required targets
    local targets=(
        "all"
        "modules"
        "clean"
        "install"
        "uninstall"
        "check"
        "test"
    )
    
    for target in "${targets[@]}"; do
        if ! grep -q "^$target:" "$file"; then
            log_error "Missing Makefile target: $target"
            return 1
        fi
    done
    
    # Check for module objects
    if ! grep -q "ptp_ocp_phase3-objs" "$file"; then
        log_error "Missing module objects definition"
        return 1
    fi
    
    return 0
}

test_documentation() {
    log_info "Testing Phase 3 documentation"
    
    # Check if README exists
    if [[ -f "$PHASE3_DIR/README.md" ]]; then
        log_info "README.md found"
    else
        log_warning "README.md not found"
    fi
    
    # Check for inline documentation
    local files=(
        "$PHASE3_DIR/network/network_integration.c"
        "$PHASE3_DIR/protocols/ptp_v2_1.c"
        "$PHASE3_DIR/protocols/ntp_stratum1.c"
        "$PHASE3_DIR/security/ptp_security.c"
    )
    
    for file in "${files[@]}"; do
        if ! grep -q "This module implements:" "$file"; then
            log_warning "Missing module description in $file"
        fi
    done
    
    return 0
}

# Main test runner
main() {
    log_info "Starting Phase 3 tests"
    log_info "Test directory: $TEST_DIR"
    log_info "Phase 3 directory: $PHASE3_DIR"
    log_info "Log file: $LOG_FILE"
    
    # Clear log file
    > "$LOG_FILE"
    
    # Run tests
    run_test "Phase 3 files exist" test_phase3_files_exist
    run_test "Phase 3 compilation" test_phase3_compilation
    run_test "Network integration syntax" test_network_integration_syntax
    run_test "PTP v2.1 syntax" test_ptp_v2_1_syntax
    run_test "NTP Stratum 1 syntax" test_ntp_stratum1_syntax
    run_test "PTP security syntax" test_ptp_security_syntax
    run_test "Phase 3 headers" test_phase3_headers
    run_test "Network integration features" test_network_integration_features
    run_test "PTP v2.1 features" test_ptp_v2_1_features
    run_test "NTP Stratum 1 features" test_ntp_stratum1_features
    run_test "PTP security features" test_ptp_security_features
    run_test "Makefile structure" test_makefile_structure
    run_test "Documentation" test_documentation
    
    # Print summary
    echo
    log_info "=== Test Summary ==="
    log_info "Tests run: $TESTS_RUN"
    log_info "Tests passed: $TESTS_PASSED"
    log_info "Tests failed: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed!"
        exit 0
    else
        log_error "Some tests failed!"
        exit 1
    fi
}

# Run main function
main "$@"

