#!/usr/bin/env bash
# OpenVPN 安装脚本 - 安装模块
# OpenVPN Install - Installation Module
# OpenVPN 服务器初始安装和配置
# OpenVPN server initial installation and configuration

# 避免重复加载 / Avoid duplicate loading
[[ -n "${_INSTALL_MODULE_LOADED:-}" ]] && return 0
readonly _INSTALL_MODULE_LOADED=1

# 此模块依赖 / This module depends on:
# - lib/logging.sh
# - lib/validation.sh
# - lib/system.sh
# - lib/config.sh
# - lib/firewall.sh
# - lib/ca.sh
# - lib/ui.sh

# =============================================================================
# 全局配置 / Global Configuration
# =============================================================================

# Easy-RSA 版本 / Easy-RSA version
readonly EASYRSA_VERSION="3.2.5"
readonly EASYRSA_URL="https://github.com/OpenVPN/easy-rsa/releases/download/v${EASYRSA_VERSION}/EasyRSA-${EASYRSA_VERSION}.tgz"

# =============================================================================
# 前置检查 / Pre-installation Checks
# =============================================================================

# 执行安装前检查
# Perform pre-installation checks
# 返回 / Returns: 检查通过返回 0，失败返回 1 / 0 on pass, 1 on fail
install_pre_checks() {
	log_header "安装前检查 / Pre-installation Checks"
	
	# 检查 root 权限 / Check root privileges
	check_root
	
	# 检查操作系统 / Check operating system
	detect_os
	log_success "操作系统检测通过 / Operating system detected: $OS $VER"
	
	# 检查 TUN 模块 / Check TUN module
	if ! check_tun_module; then
		log_fatal "TUN 模块不可用 / TUN module not available"
	fi
	log_success "TUN 模块可用 / TUN module available"
	
	# 检查 systemd / Check systemd
	check_systemd
	log_success "systemd 可用 / systemd available"
	
	# 检查是否已安装 / Check if already installed
	if [[ -d "/etc/openvpn/server" ]]; then
		log_warn "检测到现有 OpenVPN 安装 / Existing OpenVPN installation detected"
		log_warn "请先卸载或备份现有配置 / Please uninstall or backup existing configuration first"
		return 1
	fi
	
	log_success "所有前置检查通过 / All pre-checks passed"
	return 0
}

# =============================================================================
# 软件包安装 / Package Installation
# =============================================================================

# 安装必需的软件包
# Install required packages
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
install_packages() {
	log_header "安装软件包 / Installing Packages"
	
	# 根据操作系统安装包 / Install packages based on OS
	local packages=()
	
	case "$OS" in
		debian|ubuntu)
			packages=("openvpn" "curl" "ca-certificates" "gnupg")
			;;
		fedora|centos|rocky|almalinux|ol|amzn)
			packages=("openvpn" "curl" "ca-certificates")
			;;
		arch|manjaro)
			packages=("openvpn" "curl" "ca-certificates")
			;;
		opensuse*)
			packages=("openvpn" "curl" "ca-certificates")
			;;
		*)
			log_error "不支持的操作系统 / Unsupported operating system: $OS"
			return 1
			;;
	esac
	
	# 安装包 / Install packages
	if ! install_package "${packages[@]}"; then
		log_error "软件包安装失败 / Package installation failed"
		return 1
	fi
	
	log_success "所有软件包安装成功 / All packages installed successfully"
	return 0
}

# =============================================================================
# Easy-RSA 安装 / Easy-RSA Installation
# =============================================================================

# 安装和配置 Easy-RSA
# Install and configure Easy-RSA
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
install_easyrsa() {
	log_header "安装 Easy-RSA / Installing Easy-RSA"
	
	local easyrsa_dir="/etc/openvpn/server/easy-rsa"
	
	# 创建目录 / Create directory
	mkdir -p "$easyrsa_dir"
	
	# 下载 Easy-RSA / Download Easy-RSA
	log_info "下载 Easy-RSA ${EASYRSA_VERSION} / Downloading Easy-RSA ${EASYRSA_VERSION}"
	
	if ! curl -fsSL "$EASYRSA_URL" -o /tmp/easyrsa.tgz; then
		log_error "Easy-RSA 下载失败 / Easy-RSA download failed"
		return 1
	fi
	
	# 解压 / Extract
	tar xzf /tmp/easyrsa.tgz -C "$easyrsa_dir" --strip-components=1
	rm -f /tmp/easyrsa.tgz
	
	# 设置权限 / Set permissions
	chown -R root:root "$easyrsa_dir"
	chmod -R 755 "$easyrsa_dir"
	
	log_success "Easy-RSA 安装成功 / Easy-RSA installed successfully"
	return 0
}

# =============================================================================
# 配置收集 / Configuration Collection
# =============================================================================

# 收集用户配置
# Collect user configuration
# 返回 / Returns: 成功返回 0 / 0 on success
install_collect_config() {
	log_header "配置 OpenVPN / Configuring OpenVPN"
	
	# 初始化配置系统 / Initialize configuration system
	config_init
	
	# 端口 / Port
	local port
	port=$(ui_input_port "1194")
	config_set_port "$port"
	log_info "端口 / Port: $port"
	
	# 协议 / Protocol
	local protocol
	protocol=$(ui_select_protocol "udp")
	config_set_protocol "$protocol"
	log_info "协议 / Protocol: $protocol"
	
	# DNS 提供商 / DNS provider
	local dns
	dns=$(ui_select_dns "cloudflare")
	config_set "DNS" "$dns"
	log_info "DNS 提供商 / DNS Provider: $dns"
	
	# 加密算法 / Cipher
	local cipher
	cipher=$(ui_select_cipher "AES-128-GCM")
	config_set "CIPHER" "$cipher"
	log_info "加密算法 / Cipher: $cipher"
	
	# 证书类型 / Certificate type
	local cert_type
	cert_type=$(ui_select_cert_type "ecdsa")
	config_set "CERT_TYPE" "$cert_type"
	log_info "证书类型 / Certificate Type: $cert_type"
	
	# 认证模式 / Authentication mode
	local auth_mode
	auth_mode=$(ui_select_auth_mode "pki")
	config_set_auth_mode "$auth_mode"
	log_info "认证模式 / Authentication Mode: $auth_mode"
	
	# 服务器名称 / Server name
	local server_name
	server_name=$(ui_prompt "输入服务器名称 / Enter server name" "server" "validate_client_name")
	config_set_server_name "$server_name"
	log_info "服务器名称 / Server Name: $server_name"
	
	# 检测公网 IP / Detect public IP
	local endpoint
	endpoint=$(resolve_public_ip 4 2>/dev/null)
	
	if [[ -n "$endpoint" ]]; then
		log_info "检测到公网 IP / Detected public IP: $endpoint"
		if ui_confirm "使用此 IP 作为服务器端点？/ Use this IP as server endpoint?" "y"; then
			config_set "ENDPOINT" "$endpoint"
		else
			endpoint=$(ui_prompt "输入服务器 IP 或域名 / Enter server IP or domain" "" "validate_ipv4")
			config_set "ENDPOINT" "$endpoint"
		fi
	else
		endpoint=$(ui_prompt "输入服务器 IP 或域名 / Enter server IP or domain" "" "validate_ipv4")
		config_set "ENDPOINT" "$endpoint"
	fi
	
	log_info "服务器端点 / Server Endpoint: $endpoint"
	
	log_success "配置收集完成 / Configuration collected"
	return 0
}

# =============================================================================
# PKI 初始化 / PKI Initialization
# =============================================================================

# 初始化 PKI 和生成证书
# Initialize PKI and generate certificates
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
install_init_pki() {
	log_header "初始化 PKI / Initializing PKI"
	
	# 初始化 PKI / Initialize PKI
	if ! ca_init_pki; then
		log_error "PKI 初始化失败 / PKI initialization failed"
		return 1
	fi
	
	# 构建 CA / Build CA
	local server_name
	server_name=$(config_get_server_name)
	local ca_cn="${server_name}_ca"
	
	if ! ca_build_ca "$ca_cn"; then
		log_error "CA 构建失败 / CA build failed"
		return 1
	fi
	
	# 生成服务器证书 / Generate server certificate
	local auth_mode
	auth_mode=$(config_get_auth_mode)
	
	if [[ "$auth_mode" == "fingerprint" ]]; then
		if ! ca_create_server_cert_fingerprint "$server_name"; then
			log_error "服务器证书生成失败 / Server certificate generation failed"
			return 1
		fi
	else
		if ! ca_create_server_cert_pki "$server_name"; then
			log_error "服务器证书生成失败 / Server certificate generation failed"
			return 1
		fi
		
		# 生成 CRL / Generate CRL
		ca_generate_crl
	fi
	
	# 生成 DH 参数（仅 PKI 模式需要）
	# Generate DH parameters (PKI mode only)
	if [[ "$auth_mode" == "pki" ]]; then
		log_info "生成 Diffie-Hellman 参数（可能需要几分钟）/ Generating Diffie-Hellman parameters (may take several minutes)"
		
		local easyrsa_dir="/etc/openvpn/server/easy-rsa"
		cd "$easyrsa_dir" || return 1
		
		./easyrsa gen-dh >/dev/null 2>&1
		
		log_success "DH 参数生成完成 / DH parameters generated"
	fi
	
	# 生成 TLS 认证密钥 / Generate TLS auth key
	openvpn --genkey secret /etc/openvpn/server/tls-crypt.key
	
	log_success "PKI 初始化完成 / PKI initialization complete"
	return 0
}

# =============================================================================
# 服务器配置文件生成 / Server Configuration File Generation
# =============================================================================

# 生成服务器配置文件
# Generate server configuration file
# 返回 / Returns: 成功返回 0 / 0 on success
install_generate_server_config() {
	log_header "生成服务器配置 / Generating Server Configuration"
	
	local config_file="/etc/openvpn/server/server.conf"
	local server_name port protocol cipher auth_mode
	
	server_name=$(config_get_server_name)
	port=$(config_get_port)
	protocol=$(config_get_protocol)
	cipher=$(config_get "CIPHER")
	auth_mode=$(config_get_auth_mode)
	
	# 创建配置文件 / Create configuration file
	cat > "$config_file" <<-EOF
	# OpenVPN 服务器配置 / OpenVPN Server Configuration
	# 生成时间 / Generated: $(date '+%Y-%m-%d %H:%M:%S')
	
	# 网络配置 / Network Configuration
	port $port
	proto $protocol
	dev tun
	
	# 证书和密钥 / Certificates and Keys
	ca /etc/openvpn/server/easy-rsa/pki/ca.crt
	cert /etc/openvpn/server/easy-rsa/pki/issued/${server_name}.crt
	key /etc/openvpn/server/easy-rsa/pki/private/${server_name}.key
	EOF
	
	# PKI 模式添加 DH 和 CRL / Add DH and CRL for PKI mode
	if [[ "$auth_mode" == "pki" ]]; then
		cat >> "$config_file" <<-EOF
		dh /etc/openvpn/server/easy-rsa/pki/dh.pem
		crl-verify /etc/openvpn/server/crl.pem
		EOF
	fi
	
	# 继续添加配置 / Continue adding configuration
	cat >> "$config_file" <<-EOF
	tls-crypt /etc/openvpn/server/tls-crypt.key
	
	# 网络设置 / Network Settings
	topology subnet
	server 10.8.0.0 255.255.255.0
	ifconfig-pool-persist /var/run/openvpn-server/ipp.txt
	
	# 路由 / Routing
	push "redirect-gateway def1 bypass-dhcp"
	EOF
	
	# 添加 DNS 配置 / Add DNS configuration
	local dns
	dns=$(config_get "DNS")
	
	case "$dns" in
		cloudflare)
			echo 'push "dhcp-option DNS 1.1.1.1"' >> "$config_file"
			echo 'push "dhcp-option DNS 1.0.0.1"' >> "$config_file"
			;;
		google)
			echo 'push "dhcp-option DNS 8.8.8.8"' >> "$config_file"
			echo 'push "dhcp-option DNS 8.8.4.4"' >> "$config_file"
			;;
		quad9)
			echo 'push "dhcp-option DNS 9.9.9.9"' >> "$config_file"
			echo 'push "dhcp-option DNS 149.112.112.112"' >> "$config_file"
			;;
		*)
			# 使用当前系统 DNS / Use current system DNS
			local sys_dns
			sys_dns=$(grep "^nameserver" /etc/resolv.conf | head -n1 | awk '{print $2}')
			if [[ -n "$sys_dns" ]]; then
				echo "push \"dhcp-option DNS $sys_dns\"" >> "$config_file"
			fi
			;;
	esac
	
	# 添加其余配置 / Add remaining configuration
	cat >> "$config_file" <<-EOF
	
	# 安全设置 / Security Settings
	cipher $cipher
	auth SHA256
	
	# 连接设置 / Connection Settings
	keepalive 10 120
	persist-key
	persist-tun
	
	# 用户和组 / User and Group
	user nobody
	group $(getent group nogroup >/dev/null 2>&1 && echo "nogroup" || echo "nobody")
	
	# 日志 / Logging
	status /var/run/openvpn-server/server-status.log
	verb 3
	explicit-exit-notify 1
	EOF
	
	# 设置权限 / Set permissions
	chmod 600 "$config_file"
	
	log_success "服务器配置文件已生成 / Server configuration file generated"
	return 0
}

# =============================================================================
# 防火墙配置 / Firewall Configuration
# =============================================================================

# 配置防火墙规则
# Configure firewall rules
# 返回 / Returns: 成功返回 0 / 0 on success
install_configure_firewall() {
	log_header "配置防火墙 / Configuring Firewall"
	
	# 启用 IP 转发 / Enable IP forwarding
	firewall_enable_forwarding "both"
	
	# 添加防火墙规则 / Add firewall rules
	local port protocol interface
	port=$(config_get_port)
	protocol=$(config_get_protocol)
	interface=$(get_default_interface)
	
	if ! firewall_add_rules "$port" "$protocol" "10.8.0.0/24" "$interface"; then
		log_warn "防火墙规则添加可能失败 / Firewall rules may have failed"
	fi
	
	log_success "防火墙配置完成 / Firewall configured"
	return 0
}

# =============================================================================
# 服务启动 / Service Startup
# =============================================================================

# 启用并启动 OpenVPN 服务
# Enable and start OpenVPN service
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
install_start_service() {
	log_header "启动服务 / Starting Service"
	
	# 创建运行时目录 / Create runtime directory
	mkdir -p /var/run/openvpn-server
	
	# 启用服务 / Enable service
	systemctl enable openvpn-server@server >/dev/null 2>&1
	
	# 启动服务 / Start service
	if systemctl start openvpn-server@server; then
		log_success "OpenVPN 服务已启动 / OpenVPN service started"
		return 0
	else
		log_error "服务启动失败 / Service start failed"
		log_info "检查日志 / Check logs: journalctl -u openvpn-server@server"
		return 1
	fi
}

# =============================================================================
# 完整安装流程 / Complete Installation Process
# =============================================================================

# 执行完整安装
# Perform complete installation
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
install_execute() {
	log_header "OpenVPN 服务器安装 / OpenVPN Server Installation"
	
	# 前置检查 / Pre-checks
	if ! install_pre_checks; then
		return 1
	fi
	
	# 安装软件包 / Install packages
	if ! install_packages; then
		return 1
	fi
	
	# 安装 Easy-RSA / Install Easy-RSA
	if ! install_easyrsa; then
		return 1
	fi
	
	# 收集配置 / Collect configuration
	if ! install_collect_config; then
		return 1
	fi
	
	# 初始化 PKI / Initialize PKI
	if ! install_init_pki; then
		return 1
	fi
	
	# 生成服务器配置 / Generate server configuration
	if ! install_generate_server_config; then
		return 1
	fi
	
	# 配置防火墙 / Configure firewall
	if ! install_configure_firewall; then
		return 1
	fi
	
	# 启动服务 / Start service
	if ! install_start_service; then
		return 1
	fi
	
	# 安装完成 / Installation complete
	log_info ""
	log_success "========================================="
	log_success "安装完成 / Installation Complete"
	log_success "========================================="
	log_info ""
	log_info "OpenVPN 服务器已成功安装并启动"
	log_info "OpenVPN server successfully installed and started"
	log_info ""
	
	# 显示配置摘要 / Display configuration summary
	local endpoint port protocol
	endpoint=$(config_get "ENDPOINT")
	port=$(config_get_port)
	protocol=$(config_get_protocol)
	
	log_info "服务器配置 / Server Configuration:"
	log_info "  端点 / Endpoint: $endpoint"
	log_info "  端口 / Port: $port"
	log_info "  协议 / Protocol: $protocol"
	log_info ""
	log_info "下一步 / Next Steps:"
	log_info "  1. 添加客户端 / Add client: client_add <name>"
	log_info "  2. 查看状态 / View status: server_status"
	log_info "  3. 查看日志 / View logs: server_logs"
	
	return 0
}
