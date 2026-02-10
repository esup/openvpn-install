#!/bin/bash
# OpenVPN Install - System Library
# System detection and network utilities

# Detect operating system
# Returns: Sets OS, VER, and ID global variables
detect_os() {
	if [[ ! -e /etc/os-release ]]; then
		log_fatal "/etc/os-release not found. Unsupported operating system."
	fi
	
	# Read OS information without sourcing to avoid readonly variable conflicts
	OS=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
	VER=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"' || echo "unknown")
	
	log_debug "Detected OS: $OS $VER"
	
	# Validate supported distributions
	case "$OS" in
		debian)
			if [[ "$VER" -lt 11 ]]; then
				log_fatal "Debian 11 or higher is required"
			fi
			;;
		ubuntu)
			if [[ "${VER//./}" -lt 1804 ]]; then
				log_fatal "Ubuntu 18.04 or higher is required"
			fi
			;;
		fedora)
			if [[ "$VER" -lt 40 ]]; then
				log_fatal "Fedora 40 or higher is required"
			fi
			;;
		centos|rocky|almalinux|ol)
			if [[ "$VER" -lt 8 ]]; then
				log_fatal "Version 8 or higher is required"
			fi
			;;
		amzn)
			if [[ "$VER" != "2023" ]]; then
				log_fatal "Only Amazon Linux 2023 is supported"
			fi
			;;
		arch|manjaro)
			# Rolling release, no version check
			;;
		opensuse-leap|opensuse-tumbleweed)
			# Supported
			;;
		*)
			log_fatal "Unsupported operating system: $OS"
			;;
	esac
}

# Resolve public IP address (unified for IPv4 and IPv6)
# Args: $1 - IP version (4 or 6)
# Returns: IP address on stdout, or empty on failure
resolve_public_ip() {
	local ip_version="$1"
	local ip=""
	
	case "$ip_version" in
		4)
			log_debug "Resolving public IPv4 address"
			
			# Try multiple services
			local ipv4_services=(
				"https://api.ipify.org"
				"https://ifconfig.me/ip"
				"https://icanhazip.com"
			)
			
			for service in "${ipv4_services[@]}"; do
				log_debug "Trying $service"
				ip=$(curl -4s --max-time 5 "$service" 2>/dev/null)
				
				if validate_ipv4 "$ip"; then
					log_debug "Resolved IPv4: $ip"
					echo "$ip"
					return 0
				fi
			done
			
			# Fallback to dig
			log_debug "Falling back to dig for IPv4"
			ip=$(dig +short myip.opendns.com @resolver1.opendns.com -4 2>/dev/null | head -n1)
			
			if validate_ipv4 "$ip"; then
				log_debug "Resolved IPv4 via dig: $ip"
				echo "$ip"
				return 0
			fi
			
			log_warn "Failed to resolve public IPv4 address"
			return 1
			;;
			
		6)
			log_debug "Resolving public IPv6 address"
			
			# Try multiple services
			local ipv6_services=(
				"https://api6.ipify.org"
				"https://ifconfig.me/ip"
				"https://icanhazip.com"
			)
			
			for service in "${ipv6_services[@]}"; do
				log_debug "Trying $service"
				ip=$(curl -6s --max-time 5 "$service" 2>/dev/null)
				
				if validate_ipv6 "$ip"; then
					log_debug "Resolved IPv6: $ip"
					echo "$ip"
					return 0
				fi
			done
			
			# Fallback to dig
			log_debug "Falling back to dig for IPv6"
			ip=$(dig +short myip.opendns.com @resolver1.opendns.com -6 AAAA 2>/dev/null | head -n1)
			
			if validate_ipv6 "$ip"; then
				log_debug "Resolved IPv6 via dig: $ip"
				echo "$ip"
				return 0
			fi
			
			log_warn "Failed to resolve public IPv6 address"
			return 1
			;;
			
		*)
			log_error "Invalid IP version: $ip_version (must be 4 or 6)"
			return 1
			;;
	esac
}

# Check if running as root
# Returns: 0 if root, exits with error if not
check_root() {
	if [[ $EUID -ne 0 ]]; then
		log_fatal "This script must be run as root"
	fi
	log_debug "Running as root: OK"
}

# Check if TUN module is available
# Returns: 0 if available, 1 if not
check_tun_module() {
	if [[ ! -e /dev/net/tun ]] || ! (exec 7<>/dev/net/tun) 2>/dev/null; then
		log_error "TUN module is not available"
		log_error "Please enable TUN in your VPS/kernel configuration"
		return 1
	fi
	log_debug "TUN module: OK"
	return 0
}

# Get default network interface
# Returns: interface name on stdout
get_default_interface() {
	local interface
	interface=$(ip route show default | awk '/default/ {print $5}' | head -n1)
	
	if [[ -z "$interface" ]]; then
		log_warn "Could not determine default network interface"
		return 1
	fi
	
	log_debug "Default interface: $interface"
	echo "$interface"
	return 0
}

# Get local IP address of default interface
# Args: $1 - IP version (4 or 6)
# Returns: IP address on stdout
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
			log_error "Invalid IP version: $ip_version"
			return 1
			;;
	esac
}

# Check if IPv6 is available
# Returns: 0 if available, 1 if not
check_ipv6_available() {
	if [[ ! -f /proc/net/if_inet6 ]]; then
		log_debug "IPv6 not available (no /proc/net/if_inet6)"
		return 1
	fi
	
	# Check if we can resolve an IPv6 address
	if ! resolve_public_ip 6 >/dev/null 2>&1; then
		log_debug "IPv6 not available (cannot resolve public IPv6)"
		return 1
	fi
	
	log_debug "IPv6 available"
	return 0
}

# Check if systemd is available
# Returns: 0 if available, exits with error if not
check_systemd() {
	if ! command -v systemctl >/dev/null 2>&1; then
		log_fatal "systemd is required but not found"
	fi
	
	if ! systemctl --version >/dev/null 2>&1; then
		log_fatal "systemd is not working properly"
	fi
	
	log_debug "systemd: OK"
}

# Get OpenVPN version
# Returns: version string on stdout (e.g., "2.6.8")
get_openvpn_version() {
	if ! command -v openvpn >/dev/null 2>&1; then
		return 1
	fi
	
	openvpn --version 2>&1 | head -n1 | awk '{print $2}'
}

# Check if OpenVPN version supports a feature
# Args: $1 - minimum version required (e.g., "2.6")
# Returns: 0 if supported, 1 if not
check_openvpn_version() {
	local min_version="$1"
	local current_version
	
	current_version=$(get_openvpn_version)
	
	if [[ -z "$current_version" ]]; then
		log_warn "OpenVPN not installed, cannot check version"
		return 1
	fi
	
	# Simple version comparison (works for major.minor)
	if [[ "$(printf '%s\n' "$min_version" "$current_version" | sort -V | head -n1)" == "$min_version" ]]; then
		log_debug "OpenVPN version $current_version >= $min_version"
		return 0
	else
		log_debug "OpenVPN version $current_version < $min_version"
		return 1
	fi
}

# Get package manager command
# Returns: package manager command on stdout (apt-get, dnf, yum, pacman, zypper)
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
			log_error "Unknown package manager for OS: $OS"
			return 1
			;;
	esac
}

# Install package(s)
# Args: $@ - package names
# Returns: 0 on success, 1 on failure
install_package() {
	local packages=("$@")
	local pm
	pm=$(get_package_manager)
	
	log_info "Installing packages: ${packages[*]}"
	
	case "$pm" in
		apt-get)
			run_cmd "Update package cache" apt-get update || return 1
			run_cmd "Install packages" apt-get install -y "${packages[@]}" || return 1
			;;
		dnf|yum)
			run_cmd "Install packages" "$pm" install -y "${packages[@]}" || return 1
			;;
		pacman)
			run_cmd "Install packages" pacman -Sy --noconfirm "${packages[@]}" || return 1
			;;
		zypper)
			run_cmd "Install packages" zypper install -y "${packages[@]}" || return 1
			;;
		*)
			log_error "Cannot install packages: unknown package manager"
			return 1
			;;
	esac
	
	log_success "Packages installed successfully"
	return 0
}

# Check if a package is installed
# Args: $1 - package name
# Returns: 0 if installed, 1 if not
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
