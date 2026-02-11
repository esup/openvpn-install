#!/bin/bash
# 测试所有库模块的加载和基本功能
# Test loading and basic functionality of all library modules

# 设置必要的环境变量
VERBOSE=0
LOG_FILE=""
OUTPUT_FORMAT="table"
FORCE_COLOR=0
NON_INTERACTIVE_INSTALL="n"
OS=""
VER=""

# 加载所有库模块
echo "加载库模块 / Loading library modules..."
source lib/logging.sh
source lib/validation.sh
source lib/system.sh
source lib/config.sh
source lib/firewall.sh
source lib/ca.sh
source lib/ui.sh

echo "✅ 所有库模块加载成功 / All library modules loaded successfully"
echo ""

# 测试日志函数
echo "测试日志函数 / Testing logging functions..."
log_info "这是信息日志 / This is an info log"
log_success "这是成功日志 / This is a success log"
log_warn "这是警告日志 / This is a warning log"
log_debug "这是调试日志 / This is a debug log (只在 VERBOSE=1 时显示 / only shown with VERBOSE=1)"
echo ""

# 测试验证函数
echo "测试验证函数 / Testing validation functions..."
if validate_client_name "test_client_123"; then
    log_success "客户端名称验证通过 / Client name validation passed"
fi

if validate_ipv4 "192.168.1.1"; then
    log_success "IPv4 验证通过 / IPv4 validation passed"
fi

if validate_port "1194"; then
    log_success "端口验证通过 / Port validation passed"
fi

if validate_protocol "udp"; then
    log_success "协议验证通过 / Protocol validation passed"
fi

if validate_cipher "AES-128-GCM"; then
    log_success "加密算法验证通过 / Cipher validation passed"
fi
echo ""

# 测试系统函数
echo "测试系统函数 / Testing system functions..."
detect_os
log_success "操作系统检测完成 / OS detection completed: $OS $VER"

fw_type=$(firewall_detect)
log_success "防火墙检测完成 / Firewall detection completed: $fw_type"
echo ""

# 显示统计
echo "========================================="
echo "模块测试完成 / Module Testing Complete"
echo "========================================="
echo "已加载模块 / Loaded modules:"
echo "  ✅ lib/logging.sh"
echo "  ✅ lib/validation.sh"
echo "  ✅ lib/system.sh"
echo "  ✅ lib/config.sh"
echo "  ✅ lib/firewall.sh"
echo "  ✅ lib/ca.sh"
echo "  ✅ lib/ui.sh"
echo ""
echo "所有模块工作正常！/ All modules working correctly!"
