#!/usr/bin/env bash
# OpenVPN 安装脚本 - 验证库
# OpenVPN Install - Validation Library
# 输入验证和消毒函数
# Input validation and sanitization functions

# 避免重复加载 / Avoid duplicate loading
[[ -n "${_VALIDATION_LIB_LOADED:-}" ]] && return 0
readonly _VALIDATION_LIB_LOADED=1

# =============================================================================
# 客户端和用户输入验证 / Client and User Input Validation
# =============================================================================

# 验证客户端名称
# Validate client name
# 客户端名称必须是字母数字加下划线和连字符，最多64个字符
# Client names must be alphanumeric with underscores and hyphens, max 64 characters
# 参数 / Args: $1 - 客户端名称 / client name
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
validate_client_name() {
	local name="$1"
	
	if [[ -z "$name" ]]; then
		log_error "客户端名称不能为空 / Client name cannot be empty"
		return 1
	fi
	
	if [[ ${#name} -gt 64 ]]; then
		log_error "客户端名称过长 / Client name too long: $name (max 64 characters)"
		return 1
	fi
	
	if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
		log_error "无效的客户端名称 / Invalid client name: $name"
		log_error "客户端名称只能包含字母、数字、下划线和连字符 / Client names must contain only letters, numbers, underscores, and hyphens"
		return 1
	fi
	
	# 保留名称检查 / Reserved names
	case "$name" in
		server|ca|crl)
			log_error "保留名称 / Reserved name: $name"
			return 1
			;;
	esac
	
	return 0
}

# =============================================================================
# IP 地址验证 / IP Address Validation
# =============================================================================

# 验证 IPv4 地址
# Validate IPv4 address
# 参数 / Args: $1 - IPv4 地址 / IPv4 address
# 返回 / Returns: 有效返回 0，无效返回 1 / 0 on valid, 1 on invalid
validate_ipv4() {
	local ip="$1"
	local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
	
	# 检查基本格式 / Check basic format
	if [[ ! "$ip" =~ $regex ]]; then
		return 1
	fi
	
	# 验证每个八位组是否在 0-255 范围内
	# Validate each octet is 0-255
	IFS='.' read -ra OCTETS <<< "$ip"
	for octet in "${OCTETS[@]}"; do
		if ((octet < 0 || octet > 255)); then
			return 1
		fi
	done
	
	return 0
}

# 验证 IPv6 地址
# Validate IPv6 address
# 参数 / Args: $1 - IPv6 地址 / IPv6 address
# 返回 / Returns: 有效返回 0，无效返回 1 / 0 on valid, 1 on invalid
validate_ipv6() {
	local ip="$1"
	
	# 基本 IPv6 正则表达式（简化版，非详尽）
	# Basic IPv6 regex (simplified, not exhaustive)
	local regex='^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$'
	
	if [[ ! "$ip" =~ $regex ]]; then
		return 1
	fi
	
	# 检查段数是否过多 / Check for too many segments
	local segment_count
	segment_count=$(echo "$ip" | tr -cd ':' | wc -c)
	if ((segment_count > 7)); then
		return 1
	fi
	
	return 0
}

# =============================================================================
# 网络配置验证 / Network Configuration Validation
# =============================================================================

# 验证端口号
# Validate port number
# 参数 / Args: $1 - 端口号 / port number
# 返回 / Returns: 有效返回 0，无效返回 1 / 0 on valid, 1 on invalid
validate_port() {
	local port="$1"
	
	if [[ ! "$port" =~ ^[0-9]+$ ]]; then
		log_error "无效的端口 / Invalid port: $port (必须是数字 / must be numeric)"
		return 1
	fi
	
	if ((port < 1 || port > 65535)); then
		log_error "端口超出范围 / Port out of range: $port (必须是 1-65535 / must be 1-65535)"
		return 1
	fi
	
	return 0
}

# 验证 CIDR 表示法（IPv4）
# Validate CIDR notation (IPv4)
# 参数 / Args: $1 - CIDR (例如 / e.g., 10.8.0.0/24)
# 返回 / Returns: 有效返回 0，无效返回 1 / 0 on valid, 1 on invalid
validate_cidr_ipv4() {
	local cidr="$1"
	
	if [[ ! "$cidr" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
		return 1
	fi
	
	local ip prefix
	IFS='/' read -r ip prefix <<< "$cidr"
	
	# 验证 IP 部分 / Validate IP part
	if ! validate_ipv4 "$ip"; then
		return 1
	fi
	
	# 验证前缀长度 / Validate prefix length
	if ((prefix < 0 || prefix > 32)); then
		return 1
	fi
	
	return 0
}

# 验证 CIDR 表示法（IPv6）
# Validate CIDR notation (IPv6)
# 参数 / Args: $1 - CIDR (例如 / e.g., fd42::/64)
# 返回 / Returns: 有效返回 0，无效返回 1 / 0 on valid, 1 on invalid
validate_cidr_ipv6() {
	local cidr="$1"
	
	if [[ ! "$cidr" =~ ^.*/[0-9]{1,3}$ ]]; then
		return 1
	fi
	
	local ip prefix
	IFS='/' read -r ip prefix <<< "$cidr"
	
	# 验证 IP 部分 / Validate IP part
	if ! validate_ipv6 "$ip"; then
		return 1
	fi
	
	# 验证前缀长度 / Validate prefix length
	if ((prefix < 0 || prefix > 128)); then
		return 1
	fi
	
	return 0
}

# =============================================================================
# OpenVPN 配置验证 / OpenVPN Configuration Validation
# =============================================================================

# 验证 DNS 提供商
# Validate DNS provider
# 参数 / Args: $1 - DNS 提供商名称 / DNS provider name
# 返回 / Returns: 有效返回 0，无效返回 1 / 0 on valid, 1 on invalid
validate_dns_provider() {
	local provider="$1"
	local valid_providers=(
		"system"              # 系统默认 / System default
		"unbound"             # 本地 Unbound / Local Unbound
		"cloudflare"          # Cloudflare (1.1.1.1)
		"quad9"               # Quad9 (9.9.9.9)
		"quad9-uncensored"    # Quad9 无审查 / Quad9 uncensored
		"fdn"                 # FDN (法国 / France)
		"dnswatch"            # DNS.WATCH
		"opendns"             # OpenDNS
		"google"              # Google (8.8.8.8)
		"yandex"              # Yandex (俄罗斯 / Russia)
		"adguard"             # AdGuard DNS
		"nextdns"             # NextDNS
		"custom"              # 自定义 / Custom
	)
	
	for valid in "${valid_providers[@]}"; do
		if [[ "$provider" == "$valid" ]]; then
			return 0
		fi
	done
	
	log_error "无效的 DNS 提供商 / Invalid DNS provider: $provider"
	log_error "有效的提供商 / Valid providers: ${valid_providers[*]}"
	return 1
}

# 验证加密算法
# Validate cipher
# 参数 / Args: $1 - 加密算法名称 / cipher name
# 返回 / Returns: 有效返回 0，无效返回 1 / 0 on valid, 1 on invalid
validate_cipher() {
	local cipher="$1"
	local valid_ciphers=(
		"AES-128-GCM"         # AES 128位 GCM模式 / AES 128-bit GCM mode
		"AES-192-GCM"         # AES 192位 GCM模式 / AES 192-bit GCM mode
		"AES-256-GCM"         # AES 256位 GCM模式 / AES 256-bit GCM mode
		"AES-128-CBC"         # AES 128位 CBC模式 / AES 128-bit CBC mode
		"AES-192-CBC"         # AES 192位 CBC模式 / AES 192-bit CBC mode
		"AES-256-CBC"         # AES 256位 CBC模式 / AES 256-bit CBC mode
		"CHACHA20-POLY1305"   # ChaCha20-Poly1305 (需要 OpenVPN 2.5+ / requires OpenVPN 2.5+)
	)
	
	for valid in "${valid_ciphers[@]}"; do
		if [[ "$cipher" == "$valid" ]]; then
			return 0
		fi
	done
	
	log_error "无效的加密算法 / Invalid cipher: $cipher"
	log_error "有效的加密算法 / Valid ciphers: ${valid_ciphers[*]}"
	return 1
}

# 验证协议
# Validate protocol
# 参数 / Args: $1 - 协议 (udp 或 tcp) / protocol (udp or tcp)
# 返回 / Returns: 有效返回 0，无效返回 1 / 0 on valid, 1 on invalid
validate_protocol() {
	local protocol="$1"
	
	case "$protocol" in
		udp|tcp)
			return 0
			;;
		*)
			log_error "无效的协议 / Invalid protocol: $protocol (必须是 'udp' 或 'tcp' / must be 'udp' or 'tcp')"
			return 1
			;;
	esac
}

# =============================================================================
# 加密和证书验证 / Cryptography and Certificate Validation
# =============================================================================

# 验证证书类型
# Validate certificate type
# 参数 / Args: $1 - 证书类型 (ecdsa 或 rsa) / cert type (ecdsa or rsa)
# 返回 / Returns: 有效返回 0，无效返回 1 / 0 on valid, 1 on invalid
validate_cert_type() {
	local cert_type="$1"
	
	case "$cert_type" in
		ecdsa|rsa)
			return 0
			;;
		*)
			log_error "无效的证书类型 / Invalid certificate type: $cert_type (必须是 'ecdsa' 或 'rsa' / must be 'ecdsa' or 'rsa')"
			return 1
			;;
	esac
}

# 验证 ECDSA 曲线
# Validate ECDSA curve
# 参数 / Args: $1 - 曲线名称 / curve name
# 返回 / Returns: 有效返回 0，无效返回 1 / 0 on valid, 1 on invalid
validate_ecdsa_curve() {
	local curve="$1"
	local valid_curves=(
		"prime256v1"  # NIST P-256 (推荐 / recommended)
		"secp384r1"   # NIST P-384
		"secp521r1"   # NIST P-521
	)
	
	for valid in "${valid_curves[@]}"; do
		if [[ "$curve" == "$valid" ]]; then
			return 0
		fi
	done
	
	log_error "无效的 ECDSA 曲线 / Invalid ECDSA curve: $curve"
	log_error "有效的曲线 / Valid curves: ${valid_curves[*]}"
	return 1
}

# 验证 RSA 密钥大小
# Validate RSA key size
# 参数 / Args: $1 - 密钥大小（位）/ key size in bits
# 返回 / Returns: 有效返回 0，无效返回 1 / 0 on valid, 1 on invalid
validate_rsa_bits() {
	local bits="$1"
	local valid_sizes=(
		"2048"  # 标准强度 / Standard strength
		"3072"  # 高强度 / High strength
		"4096"  # 最高强度 / Maximum strength
	)
	
	for valid in "${valid_sizes[@]}"; do
		if [[ "$bits" == "$valid" ]]; then
			return 0
		fi
	done
	
	log_error "无效的 RSA 密钥大小 / Invalid RSA key size: $bits"
	log_error "有效的大小 / Valid sizes: ${valid_sizes[*]}"
	return 1
}

# 验证 TLS 版本
# Validate TLS version
# 参数 / Args: $1 - TLS 版本 (1.2 或 1.3) / TLS version (1.2 or 1.3)
# 返回 / Returns: 有效返回 0，无效返回 1 / 0 on valid, 1 on invalid
validate_tls_version() {
	local version="$1"
	
	case "$version" in
		1.2|1.3)
			return 0
			;;
		*)
			log_error "无效的 TLS 版本 / Invalid TLS version: $version (必须是 '1.2' 或 '1.3' / must be '1.2' or '1.3')"
			return 1
			;;
	esac
}

# =============================================================================
# 输入消毒和安全验证 / Input Sanitization and Security Validation
# =============================================================================

# 消毒输入（移除特殊字符）
# Sanitize input by removing special characters
# 参数 / Args: $1 - 输入字符串 / input string
# 返回 / Returns: 消毒后的字符串输出到 stdout / sanitized string on stdout
sanitize_input() {
	local input="$1"
	# 移除除字母数字、下划线、连字符和点之外的所有内容
	# Remove everything except alphanumeric, underscore, hyphen, and dot
	echo "$input" | tr -cd '[:alnum:]_.-'
}

# 验证文件路径（防止目录遍历）
# Validate file path (prevent directory traversal)
# 参数 / Args: $1 - 文件路径 / file path
# 返回 / Returns: 有效返回 0，无效返回 1 / 0 on valid, 1 on invalid
validate_file_path() {
	local path="$1"
	
	# 检查目录遍历尝试 / Check for directory traversal attempts
	if [[ "$path" == *".."* ]]; then
		log_error "无效的路径：检测到目录遍历 / Invalid path: directory traversal detected"
		return 1
	fi
	
	# 检查空字节 / Check for null bytes
	if [[ "$path" == *$'\0'* ]]; then
		log_error "无效的路径：检测到空字节 / Invalid path: null byte detected"
		return 1
	fi
	
	return 0
}

# 验证数字范围
# Validate number within range
# 参数 / Args: $1 - 数字 / number, $2 - 最小值 / min, $3 - 最大值 / max
# 返回 / Returns: 有效返回 0，无效返回 1 / 0 on valid, 1 on invalid
validate_number_range() {
	local num="$1"
	local min="$2"
	local max="$3"
	
	if [[ ! "$num" =~ ^[0-9]+$ ]]; then
		log_error "无效的数字 / Invalid number: $num"
		return 1
	fi
	
	if ((num < min || num > max)); then
		log_error "数字超出范围 / Number out of range: $num (必须是 / must be $min-$max)"
		return 1
	fi
	
	return 0
}
