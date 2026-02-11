#!/bin/bash
# OpenVPN 安装脚本 - 系统库
# OpenVPN Install - System Library
# 系统检测和网络工具
# System detection and network utilities

# =============================================================================
# 操作系统检测 / Operating System Detection
# =============================================================================

# 检测操作系统
# Detect operating system
# 返回 / Returns: 设置全局变量 OS, VER / Sets OS, VER global variables
detect_os() {
	if [[ ! -e /etc/os-release ]]; then
		log_fatal "未找到 /etc/os-release。不支持的操作系统 / /etc/os-release not found. Unsupported operating system."
	fi
	
	# 读取系统信息（不使用 source 以避免只读变量冲突）
	# Read OS information without sourcing to avoid readonly variable conflicts
	OS=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
	VER=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"' || echo "unknown")
	
	log_debug "检测到操作系统 / Detected OS: $OS $VER"
	
	# 验证支持的发行版 / Validate supported distributions
	case "$OS" in
		debian)
			if [[ "$VER" -lt 11 ]]; then
				log_fatal "需要 Debian 11 或更高版本 / Debian 11 or higher is required"
			fi
			;;
		ubuntu)
			if [[ "${VER//./}" -lt 1804 ]]; then
				log_fatal "需要 Ubuntu 18.04 或更高版本 / Ubuntu 18.04 or higher is required"
			fi
			;;
		fedora)
			if [[ "$VER" -lt 40 ]]; then
				log_fatal "需要 Fedora 40 或更高版本 / Fedora 40 or higher is required"
			fi
			;;
		centos|rocky|almalinux|ol)
			if [[ "$VER" -lt 8 ]]; then
				log_fatal "需要版本 8 或更高 / Version 8 or higher is required"
			fi
			;;
		amzn)
			if [[ "$VER" != "2023" ]]; then
				log_fatal "仅支持 Amazon Linux 2023 / Only Amazon Linux 2023 is supported"
			fi
			;;
		arch|manjaro)
			# 滚动发布，无需版本检查 / Rolling release, no version check
			;;
		opensuse-leap|opensuse-tumbleweed)
			# 支持的发行版 / Supported
			;;
		*)
			log_fatal "不支持的操作系统 / Unsupported operating system: $OS"
			;;
	esac
}

# =============================================================================
# 网络工具 / Network Utilities
# =============================================================================

# 解析公网 IP 地址（IPv4 和 IPv6 统一接口）
# Resolve public IP address (unified for IPv4 and IPv6)
# 参数 / Args: $1 - IP 版本 (4 或 6) / IP version (4 or 6)
# 返回 / Returns: IP 地址输出到 stdout，失败时为空 / IP address on stdout, or empty on failure
resolve_public_ip() {
	local ip_version="$1"
	local ip=""
	
	case "$ip_version" in
		4)
			log_debug "解析公网 IPv4 地址 / Resolving public IPv4 address"
			
			# 尝试多个服务 / Try multiple services
			local ipv4_services=(
				"https://api.ipify.org"
				"https://ifconfig.me/ip"
				"https://icanhazip.com"
			)
			
			for service in "${ipv4_services[@]}"; do
				log_debug "尝试 / Trying $service"
				ip=$(curl -4s --max-time 5 "$service" 2>/dev/null)
				
				if validate_ipv4 "$ip"; then
					log_debug "已解析 IPv4 / Resolved IPv4: $ip"
					echo "$ip"
					return 0
				fi
			done
			
			# 回退到 dig 命令 / Fallback to dig
			log_debug "回退到 dig 命令解析 IPv4 / Falling back to dig for IPv4"
			ip=$(dig +short myip.opendns.com @resolver1.opendns.com -4 2>/dev/null | head -n1)
			
			if validate_ipv4 "$ip"; then
				log_debug "通过 dig 解析到 IPv4 / Resolved IPv4 via dig: $ip"
				echo "$ip"
				return 0
			fi
			
			log_warn "无法解析公网 IPv4 地址 / Failed to resolve public IPv4 address"
			return 1
			;;
			
		6)
			log_debug "解析公网 IPv6 地址 / Resolving public IPv6 address"
			
			# 尝试多个服务 / Try multiple services
			local ipv6_services=(
				"https://api6.ipify.org"
				"https://ifconfig.me/ip"
				"https://icanhazip.com"
			)
			
			for service in "${ipv6_services[@]}"; do
				log_debug "尝试 / Trying $service"
				ip=$(curl -6s --max-time 5 "$service" 2>/dev/null)
				
				if validate_ipv6 "$ip"; then
					log_debug "已解析 IPv6 / Resolved IPv6: $ip"
					echo "$ip"
					return 0
				fi
			done
			
			# 回退到 dig 命令 / Fallback to dig
			log_debug "回退到 dig 命令解析 IPv6 / Falling back to dig for IPv6"
			ip=$(dig +short myip.opendns.com @resolver1.opendns.com -6 AAAA 2>/dev/null | head -n1)
			
			if validate_ipv6 "$ip"; then
				log_debug "通过 dig 解析到 IPv6 / Resolved IPv6 via dig: $ip"
				echo "$ip"
				return 0
			fi
			
			log_warn "无法解析公网 IPv6 地址 / Failed to resolve public IPv6 address"
			return 1
			;;
			
		*)
			log_error "无效的 IP 版本 / Invalid IP version: $ip_version (必须是 4 或 6 / must be 4 or 6)"
			return 1
			;;
	esac
}

# =============================================================================
# 系统权限和环境检查 / System Permissions and Environment Checks
# =============================================================================

# 检查是否以 root 身份运行
# Check if running as root
# 返回 / Returns: root 用户返回 0，否则退出并报错 / 0 if root, exits with error if not
check_root() {
	if [[ $EUID -ne 0 ]]; then
		log_fatal "此脚本必须以 root 身份运行 / This script must be run as root"
	fi
	log_debug "以 root 身份运行 / Running as root: OK"
}

# 检查 TUN 模块是否可用
# Check if TUN module is available
# 返回 / Returns: 可用返回 0，不可用返回 1 / 0 if available, 1 if not
check_tun_module() {
	if [[ ! -e /dev/net/tun ]] || ! (exec 7<>/dev/net/tun) 2>/dev/null; then
		log_error "TUN 模块不可用 / TUN module is not available"
		log_error "请在您的 VPS/内核配置中启用 TUN / Please enable TUN in your VPS/kernel configuration"
		return 1
	fi
	log_debug "TUN 模块 / TUN module: OK"
	return 0
}

# 获取默认网络接口
# Get default network interface
# 返回 / Returns: 接口名称输出到 stdout / interface name on stdout
get_default_interface() {
	local interface
	interface=$(ip route show default | awk '/default/ {print $5}' | head -n1)
	
	if [[ -z "$interface" ]]; then
		log_warn "无法确定默认网络接口 / Could not determine default network interface"
		return 1
	fi
	
	log_debug "默认接口 / Default interface: $interface"
	echo "$interface"
	return 0
}

# 获取默认接口的本地 IP 地址
# Get local IP address of default interface
# 参数 / Args: $1 - IP 版本 (4 或 6) / IP version (4 or 6)
# 返回 / Returns: IP 地址输出到 stdout / IP address on stdout
get_local_ip() {
	local ip_version="$1"
	local interface
	interface=$(get_default_interface)
	
	if [[ -z "$interface" ]]; then
		return 1
	fi
	
	case "$ip_version" in
		4)
			ip -4 addr show "$interface" | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n1
			;;
		6)
			ip -6 addr show "$interface" | grep "inet6.*global" | awk '{print $2}' | cut -d/ -f1 | head -n1
			;;
		*)
			log_error "无效的 IP 版本 / Invalid IP version: $ip_version"
			return 1
			;;
	esac
}

# 检查 IPv6 是否可用
# Check if IPv6 is available
# 返回 / Returns: 可用返回 0，不可用返回 1 / 0 if available, 1 if not
check_ipv6_available() {
	if [[ ! -f /proc/net/if_inet6 ]]; then
		log_debug "IPv6 不可用（没有 /proc/net/if_inet6）/ IPv6 not available (no /proc/net/if_inet6)"
		return 1
	fi
	
	# 检查是否能解析 IPv6 地址 / Check if we can resolve an IPv6 address
	if ! resolve_public_ip 6 >/dev/null 2>&1; then
		log_debug "IPv6 不可用（无法解析公网 IPv6）/ IPv6 not available (cannot resolve public IPv6)"
		return 1
	fi
	
	log_debug "IPv6 可用 / IPv6 available"
	return 0
}

# 检查 systemd 是否可用
# Check if systemd is available
# 返回 / Returns: 可用返回 0，不可用则退出并报错 / 0 if available, exits with error if not
check_systemd() {
	if ! command -v systemctl >/dev/null 2>&1; then
		log_fatal "需要 systemd 但未找到 / systemd is required but not found"
	fi
	
	if ! systemctl --version >/dev/null 2>&1; then
		log_fatal "systemd 工作不正常 / systemd is not working properly"
	fi
	
	log_debug "systemd: OK"
}

# =============================================================================
# OpenVPN 版本检测 / OpenVPN Version Detection
# =============================================================================

# 获取 OpenVPN 版本
# Get OpenVPN version
# 返回 / Returns: 版本字符串输出到 stdout（例如 "2.6.8"）/ version string on stdout (e.g., "2.6.8")
get_openvpn_version() {
	if ! command -v openvpn >/dev/null 2>&1; then
		return 1
	fi
	
	openvpn --version 2>&1 | head -n1 | awk '{print $2}'
}

# 检查 OpenVPN 版本是否支持某个功能
# Check if OpenVPN version supports a feature
# 参数 / Args: $1 - 所需的最低版本（例如 "2.6"）/ minimum version required (e.g., "2.6")
# 返回 / Returns: 支持返回 0，不支持返回 1 / 0 if supported, 1 if not
check_openvpn_version() {
	local min_version="$1"
	local current_version
	
	current_version=$(get_openvpn_version)
	
	if [[ -z "$current_version" ]]; then
		log_warn "OpenVPN 未安装，无法检查版本 / OpenVPN not installed, cannot check version"
		return 1
	fi
	
	# 简单的版本比较（适用于 major.minor）
	# Simple version comparison (works for major.minor)
	if [[ "$(printf '%s\n' "$min_version" "$current_version" | sort -V | head -n1)" == "$min_version" ]]; then
		log_debug "OpenVPN 版本 / version $current_version >= $min_version"
		return 0
	else
		log_debug "OpenVPN 版本 / version $current_version < $min_version"
		return 1
	fi
}

# =============================================================================
# 包管理器操作 / Package Manager Operations
# =============================================================================

# 获取包管理器命令
# Get package manager command
# 返回 / Returns: 包管理器命令输出到 stdout / package manager command on stdout
#                 (apt-get, dnf, yum, pacman, zypper)
get_package_manager() {
	case "$OS" in
		debian|ubuntu)
			echo "apt-get"
			;;
		fedora|centos|rocky|almalinux|ol|amzn)
			if command -v dnf >/dev/null 2>&1; then
				echo "dnf"
			else
				echo "yum"
			fi
			;;
		arch|manjaro)
			echo "pacman"
			;;
		opensuse*)
			echo "zypper"
			;;
		*)
			log_error "未知的操作系统包管理器 / Unknown package manager for OS: $OS"
			return 1
			;;
	esac
}

# 安装软件包
# Install package(s)
# 参数 / Args: $@ - 软件包名称列表 / package names
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
install_package() {
	local packages=("$@")
	local pm
	pm=$(get_package_manager)
	
	log_info "正在安装软件包 / Installing packages: ${packages[*]}"
	
	case "$pm" in
		apt-get)
			run_cmd "更新软件包缓存 / Update package cache" apt-get update || return 1
			run_cmd "安装软件包 / Install packages" apt-get install -y "${packages[@]}" || return 1
			;;
		dnf|yum)
			run_cmd "安装软件包 / Install packages" "$pm" install -y "${packages[@]}" || return 1
			;;
		pacman)
			run_cmd "安装软件包 / Install packages" pacman -Sy --noconfirm "${packages[@]}" || return 1
			;;
		zypper)
			run_cmd "安装软件包 / Install packages" zypper install -y "${packages[@]}" || return 1
			;;
		*)
			log_error "无法安装软件包：未知的包管理器 / Cannot install packages: unknown package manager"
			return 1
			;;
	esac
	
	log_success "软件包安装成功 / Packages installed successfully"
	return 0
}

# 检查软件包是否已安装
# Check if a package is installed
# 参数 / Args: $1 - 软件包名称 / package name
# 返回 / Returns: 已安装返回 0，未安装返回 1 / 0 if installed, 1 if not
is_package_installed() {
	local package="$1"
	local pm
	pm=$(get_package_manager)
	
	case "$pm" in
		apt-get)
			dpkg -l "$package" 2>/dev/null | grep -q "^ii"
			;;
		dnf|yum)
			"$pm" list installed "$package" >/dev/null 2>&1
			;;
		pacman)
			pacman -Qi "$package" >/dev/null 2>&1
			;;
		zypper)
			zypper se -i "$package" | grep -q "^i"
			;;
		*)
			return 1
			;;
	esac
}
