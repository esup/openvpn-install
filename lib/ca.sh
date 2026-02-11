#!/bin/bash
# OpenVPN 安装脚本 - 证书管理库
# OpenVPN Install - Certificate Authority Library
# PKI 和证书管理（基于 Easy-RSA）
# PKI and certificate management (based on Easy-RSA)

# =============================================================================
# Easy-RSA 配置 / Easy-RSA Configuration
# =============================================================================

# Easy-RSA 目录
# Easy-RSA directory
readonly EASYRSA_DIR="/etc/openvpn/server/easy-rsa"

# Easy-RSA 版本（在主脚本中定义）
# Easy-RSA version (defined in main script)
# readonly EASYRSA_VERSION="3.2.5"

# =============================================================================
# PKI 初始化 / PKI Initialization
# =============================================================================

# 初始化 PKI（公钥基础设施）
# Initialize PKI (Public Key Infrastructure)
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
ca_init_pki() {
	log_info "初始化 PKI / Initializing PKI"
	
	if [[ ! -d "$EASYRSA_DIR" ]]; then
		log_error "Easy-RSA 目录不存在 / Easy-RSA directory does not exist: $EASYRSA_DIR"
		return 1
	fi
	
	cd "$EASYRSA_DIR" || {
		log_error "无法进入 Easy-RSA 目录 / Cannot enter Easy-RSA directory"
		return 1
	}
	
	# 初始化 PKI
	# Initialize PKI
	if ! ./easyrsa init-pki >/dev/null 2>&1; then
		log_error "PKI 初始化失败 / PKI initialization failed"
		return 1
	fi
	
	log_success "PKI 初始化成功 / PKI initialized successfully"
	return 0
}

# =============================================================================
# CA（证书颁发机构）管理 / CA (Certificate Authority) Management
# =============================================================================

# 构建 CA
# Build CA
# 参数 / Args:
#   $1 - CA 通用名称 / CA Common Name
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
ca_build_ca() {
	local ca_cn="$1"
	
	log_info "构建 CA / Building CA: $ca_cn"
	
	cd "$EASYRSA_DIR" || return 1
	
	# 构建 CA（无密码）
	# Build CA (no password)
	if ! ./easyrsa --batch --req-cn="$ca_cn" build-ca nopass >/dev/null 2>&1; then
		log_error "CA 构建失败 / CA build failed"
		return 1
	fi
	
	log_success "CA 构建成功 / CA built successfully"
	return 0
}

# =============================================================================
# 服务器证书管理 / Server Certificate Management
# =============================================================================

# 创建服务器证书（PKI 模式）
# Create server certificate (PKI mode)
# 参数 / Args:
#   $1 - 服务器名称 / server name
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
ca_create_server_cert_pki() {
	local server_name="$1"
	
	log_info "创建服务器证书（PKI 模式）/ Creating server certificate (PKI mode): $server_name"
	
	cd "$EASYRSA_DIR" || return 1
	
	# 构建服务器证书（无密码）
	# Build server certificate (no password)
	if ! ./easyrsa --batch build-server-full "$server_name" nopass >/dev/null 2>&1; then
		log_error "服务器证书创建失败 / Server certificate creation failed"
		return 1
	fi
	
	log_success "服务器证书创建成功 / Server certificate created successfully"
	return 0
}

# 创建自签名服务器证书（指纹模式）
# Create self-signed server certificate (fingerprint mode)
# 参数 / Args:
#   $1 - 服务器名称 / server name
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
ca_create_server_cert_fingerprint() {
	local server_name="$1"
	
	log_info "创建自签名服务器证书（指纹模式）/ Creating self-signed server certificate (fingerprint mode): $server_name"
	
	cd "$EASYRSA_DIR" || return 1
	
	# 构建自签名服务器证书
	# Build self-signed server certificate
	if ! ./easyrsa --batch self-sign-server "$server_name" nopass >/dev/null 2>&1; then
		log_error "自签名服务器证书创建失败 / Self-signed server certificate creation failed"
		return 1
	fi
	
	log_success "自签名服务器证书创建成功 / Self-signed server certificate created successfully"
	return 0
}

# 更新服务器证书
# Renew server certificate
# 参数 / Args:
#   $1 - 服务器名称 / server name
#   $2 - 认证模式 (pki 或 fingerprint) / auth mode (pki or fingerprint)
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
ca_renew_server_cert() {
	local server_name="$1"
	local auth_mode="${2:-pki}"
	
	log_info "更新服务器证书 / Renewing server certificate: $server_name (mode: $auth_mode)"
	
	cd "$EASYRSA_DIR" || return 1
	
	if [[ "$auth_mode" == "fingerprint" ]]; then
		# 指纹模式：重新生成自签名证书
		# Fingerprint mode: regenerate self-signed certificate
		if ! ./easyrsa --batch self-sign-server "$server_name" nopass >/dev/null 2>&1; then
			log_error "服务器证书更新失败 / Server certificate renewal failed"
			return 1
		fi
	else
		# PKI 模式：使用 renew 命令
		# PKI mode: use renew command
		if ! ./easyrsa --batch renew "$server_name" >/dev/null 2>&1; then
			log_error "服务器证书更新失败 / Server certificate renewal failed"
			return 1
		fi
		
		# 撤销旧证书 / Revoke old certificate
		./easyrsa --batch revoke-renewed "$server_name" >/dev/null 2>&1
	fi
	
	log_success "服务器证书更新成功 / Server certificate renewed successfully"
	return 0
}

# =============================================================================
# 客户端证书管理 / Client Certificate Management
# =============================================================================

# 创建客户端证书（PKI 模式，无密码）
# Create client certificate (PKI mode, no password)
# 参数 / Args:
#   $1 - 客户端名称 / client name
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
ca_create_client_cert_pki() {
	local client_name="$1"
	
	log_info "创建客户端证书（PKI 模式）/ Creating client certificate (PKI mode): $client_name"
	
	cd "$EASYRSA_DIR" || return 1
	
	# 构建客户端证书（无密码）
	# Build client certificate (no password)
	if ! ./easyrsa --batch build-client-full "$client_name" nopass >/dev/null 2>&1; then
		log_error "客户端证书创建失败 / Client certificate creation failed"
		return 1
	fi
	
	log_success "客户端证书创建成功 / Client certificate created successfully"
	return 0
}

# 创建客户端证书（PKI 模式，带密码）
# Create client certificate (PKI mode, with password)
# 参数 / Args:
#   $1 - 客户端名称 / client name
#   $2 - 密码 / password
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
ca_create_client_cert_pki_password() {
	local client_name="$1"
	local password="$2"
	
	log_info "创建客户端证书（PKI 模式，带密码）/ Creating client certificate (PKI mode, with password): $client_name"
	
	cd "$EASYRSA_DIR" || return 1
	
	# 设置密码环境变量 / Set password environment variable
	export EASYRSA_PASSPHRASE="$password"
	
	# 构建客户端证书（带密码）
	# Build client certificate (with password)
	if ! ./easyrsa --batch --passin=env:EASYRSA_PASSPHRASE --passout=env:EASYRSA_PASSPHRASE build-client-full "$client_name" >/dev/null 2>&1; then
		unset EASYRSA_PASSPHRASE
		log_error "客户端证书创建失败 / Client certificate creation failed"
		return 1
	fi
	
	unset EASYRSA_PASSPHRASE
	log_success "客户端证书创建成功 / Client certificate created successfully"
	return 0
}

# 创建自签名客户端证书（指纹模式）
# Create self-signed client certificate (fingerprint mode)
# 参数 / Args:
#   $1 - 客户端名称 / client name
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
ca_create_client_cert_fingerprint() {
	local client_name="$1"
	
	log_info "创建自签名客户端证书（指纹模式）/ Creating self-signed client certificate (fingerprint mode): $client_name"
	
	cd "$EASYRSA_DIR" || return 1
	
	# 构建自签名客户端证书
	# Build self-signed client certificate
	if ! ./easyrsa --batch self-sign-client "$client_name" nopass >/dev/null 2>&1; then
		log_error "自签名客户端证书创建失败 / Self-signed client certificate creation failed"
		return 1
	fi
	
	log_success "自签名客户端证书创建成功 / Self-signed client certificate created successfully"
	return 0
}

# 撤销客户端证书
# Revoke client certificate
# 参数 / Args:
#   $1 - 客户端名称 / client name
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
ca_revoke_client_cert() {
	local client_name="$1"
	
	log_info "撤销客户端证书 / Revoking client certificate: $client_name"
	
	cd "$EASYRSA_DIR" || return 1
	
	# 撤销证书 / Revoke certificate
	if ! ./easyrsa --batch revoke-issued "$client_name" >/dev/null 2>&1; then
		log_error "证书撤销失败 / Certificate revocation failed"
		return 1
	fi
	
	log_success "客户端证书已撤销 / Client certificate revoked successfully"
	return 0
}

# 更新客户端证书
# Renew client certificate
# 参数 / Args:
#   $1 - 客户端名称 / client name
#   $2 - 认证模式 (pki 或 fingerprint) / auth mode (pki or fingerprint)
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
ca_renew_client_cert() {
	local client_name="$1"
	local auth_mode="${2:-pki}"
	
	log_info "更新客户端证书 / Renewing client certificate: $client_name (mode: $auth_mode)"
	
	cd "$EASYRSA_DIR" || return 1
	
	if [[ "$auth_mode" == "fingerprint" ]]; then
		# 指纹模式：重新生成自签名证书
		# Fingerprint mode: regenerate self-signed certificate
		if ! ./easyrsa --batch self-sign-client "$client_name" nopass >/dev/null 2>&1; then
			log_error "客户端证书更新失败 / Client certificate renewal failed"
			return 1
		fi
	else
		# PKI 模式：使用 renew 命令
		# PKI mode: use renew command
		if ! ./easyrsa --batch renew "$client_name" >/dev/null 2>&1; then
			log_error "客户端证书更新失败 / Client certificate renewal failed"
			return 1
		fi
		
		# 撤销旧证书 / Revoke old certificate
		./easyrsa --batch revoke-renewed "$client_name" >/dev/null 2>&1
	fi
	
	log_success "客户端证书更新成功 / Client certificate renewed successfully"
	return 0
}

# =============================================================================
# CRL（证书撤销列表）管理 / CRL (Certificate Revocation List) Management
# =============================================================================

# 生成 CRL
# Generate CRL
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
ca_generate_crl() {
	log_info "生成证书撤销列表 / Generating Certificate Revocation List"
	
	cd "$EASYRSA_DIR" || return 1
	
	# 生成 CRL / Generate CRL
	if ! ./easyrsa gen-crl >/dev/null 2>&1; then
		log_error "CRL 生成失败 / CRL generation failed"
		return 1
	fi
	
	# 复制 CRL 到 OpenVPN 目录并设置权限
	# Copy CRL to OpenVPN directory and set permissions
	if [[ -f pki/crl.pem ]]; then
		cp pki/crl.pem /etc/openvpn/server/crl.pem
		chmod 644 /etc/openvpn/server/crl.pem
	fi
	
	log_success "CRL 生成成功 / CRL generated successfully"
	return 0
}

# =============================================================================
# 证书信息查询 / Certificate Information Query
# =============================================================================

# 获取证书指纹
# Get certificate fingerprint
# 参数 / Args:
#   $1 - 证书名称 / certificate name
# 返回 / Returns: 指纹输出到 stdout / fingerprint on stdout
ca_get_fingerprint() {
	local cert_name="$1"
	
	local cert_file="${EASYRSA_DIR}/pki/issued/${cert_name}.crt"
	
	if [[ ! -f "$cert_file" ]]; then
		log_error "证书文件不存在 / Certificate file does not exist: $cert_file"
		return 1
	fi
	
	# 获取 SHA256 指纹 / Get SHA256 fingerprint
	openssl x509 -noout -fingerprint -sha256 -in "$cert_file" 2>/dev/null | \
		sed 's/SHA256 Fingerprint=//' | tr -d ':'
}

# 获取证书过期日期
# Get certificate expiry date
# 参数 / Args:
#   $1 - 证书名称 / certificate name
# 返回 / Returns: 过期日期输出到 stdout（YYYY-MM-DD 格式）/ expiry date on stdout (YYYY-MM-DD format)
ca_get_expiry_date() {
	local cert_name="$1"
	
	local cert_file="${EASYRSA_DIR}/pki/issued/${cert_name}.crt"
	
	if [[ ! -f "$cert_file" ]]; then
		log_error "证书文件不存在 / Certificate file does not exist: $cert_file"
		return 1
	fi
	
	# 获取过期日期 / Get expiry date
	openssl x509 -noout -enddate -in "$cert_file" 2>/dev/null | \
		cut -d= -f2 | xargs -I {} date -d {} '+%Y-%m-%d' 2>/dev/null
}

# 获取证书剩余天数
# Get days until certificate expires
# 参数 / Args:
#   $1 - 证书名称 / certificate name
# 返回 / Returns: 剩余天数输出到 stdout / days remaining on stdout
ca_get_days_remaining() {
	local cert_name="$1"
	
	local expiry_date
	expiry_date=$(ca_get_expiry_date "$cert_name")
	
	if [[ -z "$expiry_date" ]]; then
		return 1
	fi
	
	# 计算剩余天数 / Calculate days remaining
	local expiry_epoch now_epoch
	expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null)
	now_epoch=$(date +%s)
	
	if [[ -n "$expiry_epoch" && -n "$now_epoch" ]]; then
		echo $(( (expiry_epoch - now_epoch) / 86400 ))
	else
		return 1
	fi
}

# 检查证书是否已撤销
# Check if certificate is revoked
# 参数 / Args:
#   $1 - 证书名称 / certificate name
# 返回 / Returns: 已撤销返回 0，未撤销返回 1 / 0 if revoked, 1 if not
ca_is_cert_revoked() {
	local cert_name="$1"
	
	local revoked_file="${EASYRSA_DIR}/pki/revoked/certs_by_serial/${cert_name}.crt"
	
	if [[ -f "$revoked_file" ]]; then
		return 0  # 已撤销 / Revoked
	else
		return 1  # 未撤销 / Not revoked
	fi
}

# =============================================================================
# 证书列表 / Certificate Listing
# =============================================================================

# 列出所有客户端证书
# List all client certificates
# 返回 / Returns: 证书列表输出到 stdout / certificate list on stdout
ca_list_client_certs() {
	local issued_dir="${EASYRSA_DIR}/pki/issued"
	
	if [[ ! -d "$issued_dir" ]]; then
		log_warn "证书目录不存在 / Certificate directory does not exist"
		return 1
	fi
	
	# 列出所有 .crt 文件（排除 ca.crt 和 server.crt）
	# List all .crt files (excluding ca.crt and server.crt)
	find "$issued_dir" -name "*.crt" -type f ! -name "ca.crt" ! -name "server*.crt" -exec basename {} .crt \;
}
