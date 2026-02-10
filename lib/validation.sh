#!/bin/bash
# OpenVPN Install - Validation Library
# Input validation and sanitization functions

# Validate client name
# Client names must be alphanumeric with underscores, max 64 characters
# Args: $1 - client name
# Returns: 0 on success, 1 on failure
validate_client_name() {
	local name="$1"
	
	if [[ -z "$name" ]]; then
		log_error "Client name cannot be empty"
		return 1
	fi
	
	if [[ ${#name} -gt 64 ]]; then
		log_error "Client name too long: $name (max 64 characters)"
		return 1
	fi
	
	if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
		log_error "Invalid client name: $name"
		log_error "Client names must contain only letters, numbers, underscores, and hyphens"
		return 1
	fi
	
	# Reserved names
	case "$name" in
		server|ca|crl)
			log_error "Reserved name: $name"
			return 1
			;;
	esac
	
	return 0
}

# Validate IPv4 address
# Args: $1 - IPv4 address
# Returns: 0 on valid, 1 on invalid
validate_ipv4() {
	local ip="$1"
	local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
	
	if [[ ! "$ip" =~ $regex ]]; then
		return 1
	fi
	
	# Validate each octet is 0-255
	IFS='.' read -ra OCTETS <<< "$ip"
	for octet in "${OCTETS[@]}"; do
		if ((octet < 0 || octet > 255)); then
			return 1
		fi
	done
	
	return 0
}

# Validate IPv6 address
# Args: $1 - IPv6 address
# Returns: 0 on valid, 1 on invalid
validate_ipv6() {
	local ip="$1"
	
	# Basic IPv6 regex (simplified, not exhaustive)
	local regex='^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$'
	
	if [[ ! "$ip" =~ $regex ]]; then
		return 1
	fi
	
	# Check for too many segments
	local segment_count
	segment_count=$(echo "$ip" | tr -cd ':' | wc -c)
	if ((segment_count > 7)); then
		return 1
	fi
	
	return 0
}

# Validate port number
# Args: $1 - port number
# Returns: 0 on valid, 1 on invalid
validate_port() {
	local port="$1"
	
	if [[ ! "$port" =~ ^[0-9]+$ ]]; then
		log_error "Invalid port: $port (must be numeric)"
		return 1
	fi
	
	if ((port < 1 || port > 65535)); then
		log_error "Port out of range: $port (must be 1-65535)"
		return 1
	fi
	
	return 0
}

# Validate CIDR notation (IPv4)
# Args: $1 - CIDR (e.g., 10.8.0.0/24)
# Returns: 0 on valid, 1 on invalid
validate_cidr_ipv4() {
	local cidr="$1"
	
	if [[ ! "$cidr" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
		return 1
	fi
	
	local ip prefix
	IFS='/' read -r ip prefix <<< "$cidr"
	
	# Validate IP part
	if ! validate_ipv4 "$ip"; then
		return 1
	fi
	
	# Validate prefix length
	if ((prefix < 0 || prefix > 32)); then
		return 1
	fi
	
	return 0
}

# Validate CIDR notation (IPv6)
# Args: $1 - CIDR (e.g., fd42::/64)
# Returns: 0 on valid, 1 on invalid
validate_cidr_ipv6() {
	local cidr="$1"
	
	if [[ ! "$cidr" =~ ^.*/[0-9]{1,3}$ ]]; then
		return 1
	fi
	
	local ip prefix
	IFS='/' read -r ip prefix <<< "$cidr"
	
	# Validate IP part
	if ! validate_ipv6 "$ip"; then
		return 1
	fi
	
	# Validate prefix length
	if ((prefix < 0 || prefix > 128)); then
		return 1
	fi
	
	return 0
}

# Validate DNS provider
# Args: $1 - DNS provider name
# Returns: 0 on valid, 1 on invalid
validate_dns_provider() {
	local provider="$1"
	local valid_providers=(
		"system"
		"unbound"
		"cloudflare"
		"quad9"
		"quad9-uncensored"
		"fdn"
		"dnswatch"
		"opendns"
		"google"
		"yandex"
		"adguard"
		"nextdns"
		"custom"
	)
	
	for valid in "${valid_providers[@]}"; do
		if [[ "$provider" == "$valid" ]]; then
			return 0
		fi
	done
	
	log_error "Invalid DNS provider: $provider"
	log_error "Valid providers: ${valid_providers[*]}"
	return 1
}

# Validate cipher
# Args: $1 - cipher name
# Returns: 0 on valid, 1 on invalid
validate_cipher() {
	local cipher="$1"
	local valid_ciphers=(
		"AES-128-GCM"
		"AES-192-GCM"
		"AES-256-GCM"
		"AES-128-CBC"
		"AES-192-CBC"
		"AES-256-CBC"
		"CHACHA20-POLY1305"
	)
	
	for valid in "${valid_ciphers[@]}"; do
		if [[ "$cipher" == "$valid" ]]; then
			return 0
		fi
	done
	
	log_error "Invalid cipher: $cipher"
	log_error "Valid ciphers: ${valid_ciphers[*]}"
	return 1
}

# Validate protocol
# Args: $1 - protocol (udp or tcp)
# Returns: 0 on valid, 1 on invalid
validate_protocol() {
	local protocol="$1"
	
	case "$protocol" in
		udp|tcp)
			return 0
			;;
		*)
			log_error "Invalid protocol: $protocol (must be 'udp' or 'tcp')"
			return 1
			;;
	esac
}

# Validate certificate type
# Args: $1 - cert type (ecdsa or rsa)
# Returns: 0 on valid, 1 on invalid
validate_cert_type() {
	local cert_type="$1"
	
	case "$cert_type" in
		ecdsa|rsa)
			return 0
			;;
		*)
			log_error "Invalid certificate type: $cert_type (must be 'ecdsa' or 'rsa')"
			return 1
			;;
	esac
}

# Validate ECDSA curve
# Args: $1 - curve name
# Returns: 0 on valid, 1 on invalid
validate_ecdsa_curve() {
	local curve="$1"
	local valid_curves=("prime256v1" "secp384r1" "secp521r1")
	
	for valid in "${valid_curves[@]}"; do
		if [[ "$curve" == "$valid" ]]; then
			return 0
		fi
	done
	
	log_error "Invalid ECDSA curve: $curve"
	log_error "Valid curves: ${valid_curves[*]}"
	return 1
}

# Validate RSA key size
# Args: $1 - key size in bits
# Returns: 0 on valid, 1 on invalid
validate_rsa_bits() {
	local bits="$1"
	local valid_sizes=("2048" "3072" "4096")
	
	for valid in "${valid_sizes[@]}"; do
		if [[ "$bits" == "$valid" ]]; then
			return 0
		fi
	done
	
	log_error "Invalid RSA key size: $bits"
	log_error "Valid sizes: ${valid_sizes[*]}"
	return 1
}

# Validate TLS version
# Args: $1 - TLS version (1.2 or 1.3)
# Returns: 0 on valid, 1 on invalid
validate_tls_version() {
	local version="$1"
	
	case "$version" in
		1.2|1.3)
			return 0
			;;
		*)
			log_error "Invalid TLS version: $version (must be '1.2' or '1.3')"
			return 1
			;;
	esac
}

# Sanitize input by removing special characters
# Args: $1 - input string
# Returns: sanitized string on stdout
sanitize_input() {
	local input="$1"
	# Remove everything except alphanumeric, underscore, hyphen, and dot
	echo "$input" | tr -cd '[:alnum:]_.-'
}

# Validate file path (prevent directory traversal)
# Args: $1 - file path
# Returns: 0 on valid, 1 on invalid
validate_file_path() {
	local path="$1"
	
	# Check for directory traversal attempts
	if [[ "$path" == *".."* ]]; then
		log_error "Invalid path: directory traversal detected"
		return 1
	fi
	
	# Check for null bytes
	if [[ "$path" == *$'\0'* ]]; then
		log_error "Invalid path: null byte detected"
		return 1
	fi
	
	return 0
}

# Validate number within range
# Args: $1 - number, $2 - min, $3 - max
# Returns: 0 on valid, 1 on invalid
validate_number_range() {
	local num="$1"
	local min="$2"
	local max="$3"
	
	if [[ ! "$num" =~ ^[0-9]+$ ]]; then
		log_error "Invalid number: $num"
		return 1
	fi
	
	if ((num < min || num > max)); then
		log_error "Number out of range: $num (must be $min-$max)"
		return 1
	fi
	
	return 0
}
