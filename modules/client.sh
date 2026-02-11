#!/bin/bash
# OpenVPN 安装脚本 - 客户端管理模块
# OpenVPN Install - Client Management Module
# 客户端添加、删除、列表、更新等操作
# Client add, remove, list, renew operations

# 此模块依赖 / This module depends on:
# - lib/logging.sh
# - lib/validation.sh
# - lib/config.sh
# - lib/ca.sh

# =============================================================================
# 客户端添加 / Client Add
# =============================================================================

# 添加新客户端
# Add new client
# 参数 / Args:
#   $1 - 客户端名称 / client name
#   $2 - 密码（可选，用于密钥保护）/ password (optional, for key protection)
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
client_add() {
	local client_name="$1"
	local password="${2:-}"
	
	log_header "添加客户端 / Adding Client: $client_name"
	
	# 验证客户端名称 / Validate client name
	if ! validate_client_name "$client_name"; then
		log_fatal "无效的客户端名称 / Invalid client name"
	fi
	
	# 检查客户端是否已存在 / Check if client already exists
	local cert_file="/etc/openvpn/server/easy-rsa/pki/issued/${client_name}.crt"
	if [[ -f "$cert_file" ]]; then
		log_error "客户端已存在 / Client already exists: $client_name"
		return 1
	fi
	
	# 获取认证模式 / Get authentication mode
	local auth_mode
	auth_mode=$(config_get_auth_mode)
	
	log_info "使用认证模式 / Using authentication mode: $auth_mode"
	
	# 根据认证模式创建证书 / Create certificate based on auth mode
	if [[ "$auth_mode" == "fingerprint" ]]; then
		# 指纹模式 / Fingerprint mode
		if ! ca_create_client_cert_fingerprint "$client_name"; then
			log_error "证书创建失败 / Certificate creation failed"
			return 1
		fi
	else
		# PKI 模式 / PKI mode
		if [[ -n "$password" ]]; then
			# 使用密码保护 / With password protection
			if ! ca_create_client_cert_pki_password "$client_name" "$password"; then
				log_error "证书创建失败 / Certificate creation failed"
				return 1
			fi
		else
			# 无密码保护 / Without password protection
			if ! ca_create_client_cert_pki "$client_name"; then
				log_error "证书创建失败 / Certificate creation failed"
				return 1
			fi
		fi
		
		# 更新 CRL / Update CRL
		ca_generate_crl
	fi
	
	# 生成客户端配置文件 / Generate client configuration file
	if ! client_generate_config "$client_name"; then
		log_error "配置文件生成失败 / Configuration file generation failed"
		return 1
	fi
	
	log_success "客户端添加成功 / Client added successfully: $client_name"
	
	# 显示配置文件位置 / Display configuration file location
	local config_file="${HOME}/${client_name}.ovpn"
	log_info "配置文件位置 / Configuration file location: $config_file"
	
	return 0
}

# =============================================================================
# 客户端列表 / Client List
# =============================================================================

# 列出所有客户端
# List all clients
# 参数 / Args:
#   $1 - 输出格式 (table 或 json) / output format (table or json)
# 返回 / Returns: 成功返回 0 / 0 on success
client_list() {
	local format="${1:-table}"
	
	log_header "客户端列表 / Client List"
	
	# 获取所有客户端证书 / Get all client certificates
	local certs
	certs=$(ca_list_client_certs)
	
	if [[ -z "$certs" ]]; then
		log_info "没有找到客户端 / No clients found"
		return 0
	fi
	
	if [[ "$format" == "json" ]]; then
		# JSON 格式输出 / JSON format output
		echo "["
		local first=true
		while IFS= read -r cert_name; do
			[[ "$first" == "true" ]] && first=false || echo ","
			
			local expiry_date days_remaining status
			expiry_date=$(ca_get_expiry_date "$cert_name" 2>/dev/null || echo "Unknown")
			days_remaining=$(ca_get_days_remaining "$cert_name" 2>/dev/null || echo "N/A")
			
			if ca_is_cert_revoked "$cert_name"; then
				status="revoked"
			else
				status="active"
			fi
			
			echo "  {"
			echo "    \"name\": \"$cert_name\","
			echo "    \"status\": \"$status\","
			echo "    \"expiry\": \"$expiry_date\","
			echo "    \"days_remaining\": \"$days_remaining\""
			echo -n "  }"
		done <<< "$certs"
		echo ""
		echo "]"
	else
		# 表格格式输出 / Table format output
		printf "%-20s %-15s %-15s %-15s\n" "客户端名称/Name" "状态/Status" "过期日期/Expiry" "剩余天数/Days"
		echo "------------------------------------------------------------------------"
		
		while IFS= read -r cert_name; do
			local expiry_date days_remaining status
			expiry_date=$(ca_get_expiry_date "$cert_name" 2>/dev/null || echo "Unknown")
			days_remaining=$(ca_get_days_remaining "$cert_name" 2>/dev/null || echo "N/A")
			
			if ca_is_cert_revoked "$cert_name"; then
				status="已撤销/Revoked"
			else
				status="有效/Active"
			fi
			
			printf "%-20s %-15s %-15s %-15s\n" "$cert_name" "$status" "$expiry_date" "$days_remaining"
		done <<< "$certs"
	fi
	
	return 0
}

# =============================================================================
# 客户端撤销 / Client Revoke
# =============================================================================

# 撤销客户端证书
# Revoke client certificate
# 参数 / Args:
#   $1 - 客户端名称 / client name
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
client_revoke() {
	local client_name="$1"
	
	log_header "撤销客户端 / Revoking Client: $client_name"
	
	# 验证客户端名称 / Validate client name
	if ! validate_client_name "$client_name"; then
		log_fatal "无效的客户端名称 / Invalid client name"
	fi
	
	# 检查证书是否存在 / Check if certificate exists
	local cert_file="/etc/openvpn/server/easy-rsa/pki/issued/${client_name}.crt"
	if [[ ! -f "$cert_file" ]]; then
		log_error "客户端不存在 / Client does not exist: $client_name"
		return 1
	fi
	
	# 检查是否已撤销 / Check if already revoked
	if ca_is_cert_revoked "$client_name"; then
		log_warn "客户端已被撤销 / Client already revoked: $client_name"
		return 0
	fi
	
	# 撤销证书 / Revoke certificate
	if ! ca_revoke_client_cert "$client_name"; then
		log_error "证书撤销失败 / Certificate revocation failed"
		return 1
	fi
	
	# 更新 CRL / Update CRL
	ca_generate_crl
	
	# 删除配置文件 / Remove configuration file
	local config_file="${HOME}/${client_name}.ovpn"
	if [[ -f "$config_file" ]]; then
		rm -f "$config_file"
		log_info "已删除配置文件 / Configuration file removed: $config_file"
	fi
	
	log_success "客户端已撤销 / Client revoked successfully: $client_name"
	
	return 0
}

# =============================================================================
# 客户端证书更新 / Client Certificate Renewal
# =============================================================================

# 更新客户端证书
# Renew client certificate
# 参数 / Args:
#   $1 - 客户端名称 / client name
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
client_renew() {
	local client_name="$1"
	
	log_header "更新客户端证书 / Renewing Client Certificate: $client_name"
	
	# 验证客户端名称 / Validate client name
	if ! validate_client_name "$client_name"; then
		log_fatal "无效的客户端名称 / Invalid client name"
	fi
	
	# 检查证书是否存在 / Check if certificate exists
	local cert_file="/etc/openvpn/server/easy-rsa/pki/issued/${client_name}.crt"
	if [[ ! -f "$cert_file" ]]; then
		log_error "客户端不存在 / Client does not exist: $client_name"
		return 1
	fi
	
	# 检查是否已撤销 / Check if revoked
	if ca_is_cert_revoked "$client_name"; then
		log_error "无法更新已撤销的证书 / Cannot renew revoked certificate"
		return 1
	fi
	
	# 获取认证模式 / Get authentication mode
	local auth_mode
	auth_mode=$(config_get_auth_mode)
	
	# 更新证书 / Renew certificate
	if ! ca_renew_client_cert "$client_name" "$auth_mode"; then
		log_error "证书更新失败 / Certificate renewal failed"
		return 1
	fi
	
	# 更新 CRL（PKI 模式需要）/ Update CRL (needed for PKI mode)
	if [[ "$auth_mode" == "pki" ]]; then
		ca_generate_crl
	fi
	
	# 重新生成配置文件 / Regenerate configuration file
	if ! client_generate_config "$client_name"; then
		log_warn "配置文件生成失败 / Configuration file generation failed"
	fi
	
	log_success "客户端证书更新成功 / Client certificate renewed successfully: $client_name"
	
	return 0
}

# =============================================================================
# 客户端配置文件生成 / Client Configuration File Generation
# =============================================================================

# 生成客户端配置文件
# Generate client configuration file
# 参数 / Args:
#   $1 - 客户端名称 / client name
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
client_generate_config() {
	local client_name="$1"
	local output_file="${HOME}/${client_name}.ovpn"
	
	log_info "生成客户端配置文件 / Generating client configuration file"
	
	# 获取服务器配置 / Get server configuration
	local port protocol
	port=$(config_get_port)
	protocol=$(config_get_protocol)
	
	# 获取服务器端点 / Get server endpoint
	local endpoint
	endpoint=$(config_get "ENDPOINT" "")
	
	if [[ -z "$endpoint" ]]; then
		# 尝试自动检测 / Try to auto-detect
		endpoint=$(resolve_public_ip 4 2>/dev/null || echo "YOUR_SERVER_IP")
	fi
	
	# 获取认证模式 / Get authentication mode
	local auth_mode
	auth_mode=$(config_get_auth_mode)
	
	# 读取证书和密钥 / Read certificates and keys
	local ca_cert client_cert client_key
	ca_cert="/etc/openvpn/server/easy-rsa/pki/ca.crt"
	client_cert="/etc/openvpn/server/easy-rsa/pki/issued/${client_name}.crt"
	client_key="/etc/openvpn/server/easy-rsa/pki/private/${client_name}.key"
	
	# 检查文件是否存在 / Check if files exist
	if [[ ! -f "$ca_cert" ]] || [[ ! -f "$client_cert" ]] || [[ ! -f "$client_key" ]]; then
		log_error "证书文件不完整 / Certificate files incomplete"
		return 1
	fi
	
	# 生成配置文件 / Generate configuration file
	cat > "$output_file" <<-EOF
	# OpenVPN 客户端配置 / OpenVPN Client Configuration
	# 客户端 / Client: $client_name
	# 生成时间 / Generated: $(date '+%Y-%m-%d %H:%M:%S')
	
	client
	dev tun
	proto ${protocol}
	remote ${endpoint} ${port}
	resolv-retry infinite
	nobind
	persist-key
	persist-tun
	remote-cert-tls server
	verb 3
	
	<ca>
	$(cat "$ca_cert")
	</ca>
	
	<cert>
	$(cat "$client_cert")
	</cert>
	
	<key>
	$(cat "$client_key")
	</key>
	EOF
	
	# 设置文件权限 / Set file permissions
	chmod 600 "$output_file"
	
	log_success "配置文件已生成 / Configuration file generated: $output_file"
	
	return 0
}

# =============================================================================
# 客户端断开连接 / Client Disconnect
# =============================================================================

# 断开指定客户端的连接
# Disconnect specific client
# 参数 / Args:
#   $1 - 客户端名称 / client name
# 返回 / Returns: 成功返回 0 / 0 on success
client_disconnect() {
	local client_name="$1"
	
	log_info "断开客户端连接 / Disconnecting client: $client_name"
	
	# 检查管理接口是否可用 / Check if management interface is available
	local mgmt_socket="/var/run/openvpn-server/server.sock"
	
	if [[ ! -S "$mgmt_socket" ]]; then
		log_warn "管理接口不可用 / Management interface not available"
		log_info "可能需要重启 OpenVPN 服务 / May need to restart OpenVPN service"
		return 1
	fi
	
	# 通过管理接口断开客户端 / Disconnect client via management interface
	echo "kill $client_name" | nc -U "$mgmt_socket" >/dev/null 2>&1
	
	log_success "已发送断开连接命令 / Disconnect command sent"
	
	return 0
}
