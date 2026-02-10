# OpenVPN Install Script - Refactoring Project

This directory contains the refactored architecture for the OpenVPN installation script, demonstrating best practices in Bash scripting, modular design, and maintainability.

## 📋 Project Status

**Current Phase:** Architecture Design & Proof of Concept  
**Production Script:** `openvpn-install.sh` (original 4,549-line monolithic script)  
**Demo Script:** `openvpn-install-refactored.sh` (proof-of-concept showing modular architecture)

## 🎯 Goals

The refactoring project aims to:

1. **Improve Maintainability** - Break down the 4,549-line monolithic script into focused modules
2. **Enhance Security** - Add comprehensive input validation and sanitization
3. **Enable Testing** - Create unit-testable functions with clear interfaces
4. **Reduce Duplication** - Consolidate duplicate code (IPv4/IPv6 resolution, validation, etc.)
5. **Maintain Compatibility** - Preserve all existing functionality and CLI interface

## 📁 New Directory Structure

```
openvpn-install/
├── openvpn-install.sh              # Original production script (DO NOT MODIFY)
├── openvpn-install-refactored.sh   # Refactored demo script
├── lib/                            # Reusable library modules
│   ├── logging.sh                  # ✅ Logging functions
│   ├── validation.sh               # ✅ Input validation
│   ├── system.sh                   # ✅ System detection
│   ├── config.sh                   # 🔜 Configuration management
│   ├── ca.sh                       # 🔜 Certificate authority
│   ├── firewall.sh                 # 🔜 Firewall rules
│   └── ui.sh                       # 🔜 Interactive prompts
├── modules/                        # 🔜 Command modules
│   ├── install.sh
│   ├── uninstall.sh
│   ├── client.sh
│   └── server.sh
├── ARCHITECTURE.md                 # ✅ Detailed architecture analysis
└── REFACTORING.md                  # This file
```

Legend: ✅ Completed | 🔜 Planned

## 🚀 Quick Start - Try the Demo

```bash
# Run the refactored demo to see the modular architecture in action
sudo ./openvpn-install-refactored.sh demo
```

This demonstrates:
- Modular logging system
- Unified IP resolution (no code duplication)
- Input validation functions
- System detection utilities
- Clean separation of concerns

## 📚 Library Modules

### `lib/logging.sh`

Provides consistent logging across the entire codebase.

**Functions:**
```bash
log_info "message"      # Blue [INFO] message
log_warn "message"      # Yellow [WARN] message
log_error "message"     # Red [ERROR] message
log_fatal "message"     # Red [ERROR] and exit
log_success "message"   # Green [OK] message
log_debug "message"     # Dim [DEBUG] (if VERBOSE=1)
log_header "Section"    # Bold blue section header
run_cmd "desc" command  # Run command with logging
```

**Features:**
- Color-coded output (auto-detects TTY)
- File logging with timestamps
- JSON output mode for automation
- Verbose mode support

### `lib/validation.sh`

Comprehensive input validation and sanitization.

**Functions:**
```bash
validate_client_name "name"     # Alphanumeric + underscore/hyphen
validate_ipv4 "1.2.3.4"         # IPv4 address
validate_ipv6 "::1"             # IPv6 address
validate_port "1194"            # Port 1-65535
validate_cidr_ipv4 "10.8.0.0/24"    # CIDR notation
validate_cidr_ipv6 "fd42::/64"      # IPv6 CIDR
validate_dns_provider "cloudflare"  # DNS provider
validate_cipher "AES-128-GCM"       # Cipher name
validate_protocol "udp"             # Protocol (udp/tcp)
validate_cert_type "ecdsa"          # Certificate type
validate_ecdsa_curve "prime256v1"   # ECDSA curve
validate_rsa_bits "2048"            # RSA key size
validate_tls_version "1.2"          # TLS version
sanitize_input "string"             # Remove special chars
validate_file_path "/path"          # Prevent traversal
validate_number_range 5 1 10        # Number in range
```

**Security Features:**
- Prevents command injection
- Blocks directory traversal
- Validates all external input
- Sanitizes user-provided data

### `lib/system.sh`

System detection and network utilities.

**Functions:**
```bash
detect_os()                     # Detect Linux distribution
resolve_public_ip 4             # Get public IPv4
resolve_public_ip 6             # Get public IPv6
check_root()                    # Verify root privileges
check_tun_module()              # Verify TUN availability
check_systemd()                 # Verify systemd
get_default_interface()         # Get network interface
get_local_ip 4                  # Get local IPv4
get_local_ip 6                  # Get local IPv6
check_ipv6_available()          # Check IPv6 support
get_openvpn_version()           # Get OpenVPN version
check_openvpn_version "2.6"     # Version requirement check
get_package_manager()           # Detect apt/dnf/yum/pacman
install_package package1 pkg2   # Install packages
is_package_installed package    # Check if installed
```

**Supported Systems:**
- Debian 11+
- Ubuntu 18.04+
- Fedora 40+
- CentOS/Rocky/AlmaLinux 8+
- Amazon Linux 2023
- Arch Linux
- openSUSE Leap/Tumbleweed
- Oracle Linux 8+

## 🏗️ Architecture Improvements

### Before: Monolithic Design

```
openvpn-install.sh (4,549 lines)
├── Logging code (100 lines)
├── Help text (300 lines)
├── Utilities (700 lines)
├── installQuestions() (1,400 lines) ⚠️ Too large!
├── Core operations (1,500 lines)
└── Main entry (500 lines)
```

**Problems:**
- 1,400-line `installQuestions()` function
- 150+ global variables
- 15% code duplication
- Hard to test
- Mixed concerns

### After: Modular Design

```
Main Script (300 lines)
├── Sources lib/logging.sh
├── Sources lib/validation.sh
├── Sources lib/system.sh
├── Sources lib/config.sh
├── Sources lib/ca.sh
├── Sources lib/firewall.sh
├── Sources lib/ui.sh
└── Routes to command modules

Each module: 150-300 lines, focused responsibility
```

**Benefits:**
- Functions < 200 lines
- < 50 global variables
- < 5% code duplication
- Unit testable
- Clear separation

## 🔒 Security Improvements

### Input Validation

**Before:**
```bash
CLIENT="$1"  # No validation
```

**After:**
```bash
if ! validate_client_name "$1"; then
    log_fatal "Invalid client name"
fi
CLIENT=$(sanitize_input "$1")
```

### Config File Safety

**Before:**
```bash
sed -i "s/port.*/port $PORT/" server.conf  # Unsafe
```

**After:**
```bash
# Template-based with atomic writes
generate_config_from_template > /tmp/server.conf.$$
mv /tmp/server.conf.$$ /etc/openvpn/server/server.conf
```

### Command Injection Prevention

**Before:**
```bash
IP=$(curl https://api.ipify.org)  # Not validated
```

**After:**
```bash
IP=$(resolve_public_ip 4)
if ! validate_ipv4 "$IP"; then
    log_fatal "Invalid IP resolution"
fi
```

## 📊 Code Quality Metrics

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Total Lines | 4,549 | ~4,000 | ↓ 12% |
| Longest Function | 1,400 | < 200 | ↓ 86% |
| Global Variables | 150+ | < 50 | ↓ 67% |
| Code Duplication | 15% | < 5% | ↓ 67% |
| Functions | ~50 | ~120 | ↑ 140% |
| Testable Functions | ~10% | ~80% | ↑ 700% |

## 🧪 Testing Strategy

### Unit Tests (Planned)

```bash
test/unit/
├── test_logging.sh      # Test logging functions
├── test_validation.sh   # Test validation functions
├── test_system.sh       # Test system detection
├── test_config.sh       # Test config management
└── test_ca.sh           # Test CA operations
```

Using [bats](https://github.com/bats-core/bats-core):

```bash
#!/usr/bin/env bats

@test "validate_ipv4 accepts valid IP" {
    run validate_ipv4 "192.168.1.1"
    [ "$status" -eq 0 ]
}

@test "validate_ipv4 rejects invalid IP" {
    run validate_ipv4 "999.999.999.999"
    [ "$status" -eq 1 ]
}
```

### Integration Tests (Planned)

```bash
test/integration/
├── test_install_flow.sh    # Full installation flow
├── test_client_mgmt.sh     # Client management
└── test_firewall.sh        # Firewall configuration
```

### E2E Tests (Existing)

```bash
test/
├── Dockerfile.server
├── Dockerfile.client
├── server-entrypoint.sh
├── client-entrypoint.sh
└── validate-output.sh
```

Run with: `make test`

## 📅 Implementation Roadmap

### Phase 1: Foundation (Completed) ✅

- [x] Create `lib/` directory structure
- [x] Extract logging to `lib/logging.sh`
- [x] Create `lib/validation.sh` with comprehensive validation
- [x] Create `lib/system.sh` with unified utilities
- [x] Build proof-of-concept demo script
- [x] Document architecture in `ARCHITECTURE.md`

### Phase 2: Core Refactoring (2-3 weeks)

- [ ] Create `lib/config.sh` for configuration management
- [ ] Create `lib/ca.sh` for certificate operations
- [ ] Create `lib/firewall.sh` for firewall rules
- [ ] Create `lib/ui.sh` for interactive prompts
- [ ] Split `installQuestions()` into focused modules
- [ ] Consolidate duplicate IP resolution code

### Phase 3: Command Modules (2 weeks)

- [ ] Create `modules/install.sh`
- [ ] Create `modules/uninstall.sh`
- [ ] Create `modules/client.sh`
- [ ] Create `modules/server.sh`
- [ ] Update main script to use modules

### Phase 4: Testing (2 weeks)

- [ ] Set up bats testing framework
- [ ] Write unit tests for all library functions
- [ ] Create integration tests
- [ ] Achieve 60%+ test coverage
- [ ] Set up CI/CD for automated testing

### Phase 5: Migration (1 week)

- [ ] Create config migration tools
- [ ] Add backward compatibility layer
- [ ] Write migration guide
- [ ] Test with existing installations

### Phase 6: Release (1 week)

- [ ] Comprehensive testing on all supported distributions
- [ ] Update documentation
- [ ] Create release notes
- [ ] Merge to main branch

**Total Timeline:** ~8-10 weeks

## 🤝 Contributing

### For Library Development

1. **Keep functions focused** - Single responsibility principle
2. **Document parameters** - Use comments to describe args and return values
3. **Validate all inputs** - Never trust external data
4. **Log appropriately** - Use log_debug for verbose info
5. **Return status codes** - 0 for success, 1 for failure
6. **Avoid global state** - Pass arguments explicitly

### Example Function Template

```bash
# Brief description of what this function does
# Args: $1 - description of first argument
#       $2 - description of second argument (optional)
# Returns: 0 on success, 1 on failure
# Outputs: description of what's written to stdout
function_name() {
    local arg1="$1"
    local arg2="${2:-default}"
    
    # Validate inputs
    if [[ -z "$arg1" ]]; then
        log_error "arg1 is required"
        return 1
    fi
    
    # Function logic
    log_debug "Processing $arg1"
    
    # Return result
    echo "result"
    return 0
}
```

### Code Review Checklist

- [ ] Function has single responsibility
- [ ] All inputs are validated
- [ ] Error cases are handled
- [ ] Appropriate logging is used
- [ ] No global variables (except constants)
- [ ] Documentation is clear
- [ ] Unit tests are added/updated

## 📖 References

- [Original OpenVPN Install Script](../openvpn-install.sh)
- [Architecture Analysis](ARCHITECTURE.md)
- [FAQ](../FAQ.md)
- [README](../README.md)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Bash Best Practices](https://github.com/anordal/shellharden/blob/master/how_to_do_things_safely_in_bash.md)
- [ShellCheck](https://www.shellcheck.net/)

## ❓ FAQ

**Q: Why refactor a working script?**  
A: While functional, the current script is hard to maintain, extend, and test. The refactoring improves code quality without changing functionality.

**Q: Will existing installations break?**  
A: No. The refactored version will maintain full backward compatibility. Existing installations will continue to work.

**Q: When will the refactored version be ready?**  
A: The phased rollout plan targets 8-10 weeks for completion. Phase 1 (foundation) is already complete.

**Q: Can I use the refactored version now?**  
A: The demo script demonstrates the architecture but is not production-ready. Continue using `openvpn-install.sh` for real installations.

**Q: How can I help?**  
A: Contributions welcome! Check the roadmap for areas needing work. Follow the contribution guidelines above.

## 📝 License

This refactoring project follows the same MIT license as the original openvpn-install script.

---

**Last Updated:** 2026-02-10  
**Status:** Phase 1 Complete, Phase 2 In Planning
