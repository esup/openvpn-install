#!/bin/bash
# OpenVPN 安装脚本 - 服务器管理模块
# OpenVPN Install - Server Management Module
# 服务器状态、证书更新等操作
# Server status, certificate renewal operations

# 此模块依赖 / This module depends on:
# - lib/logging.sh
# - lib/config.sh
# - lib/ca.sh

# =============================================================================
# 服务器状态 / Server Status
# =============================================================================

# 显示服务器状态
# Display server status
# 返回 / Returns: 成功返回 0 / 0 on success
server_status() {
	log_header "OpenVPN 服务器状态 / OpenVPN Server Status"
	
	# 检查服务状态 / Check service status
	local service_status
	if systemctl is-active --quiet openvpn-server@server; then
		service_status="运行中 / Running"
		log_success "服务状态 / Service Status: $service_status"
	else
		service_status="已停止 / Stopped"
		log_warn "服务状态 / Service Status: $service_status"
	fi
	
	# 显示基本信息 / Display basic information
	echo ""
	echo "基本信息 / Basic Information:"
	echo "----------------------------------------"
	
	# 端口和协议 / Port and protocol
	local port protocol
	port=$(config_get_port)
	protocol=$(config_get_protocol)
	echo "端口 / Port: $port"
	echo "协议 / Protocol: $protocol"
	
	# 认证模式 / Authentication mode
	local auth_mode
	auth_mode=$(config_get_auth_mode)
	echo "认证模式 / Auth Mode: $auth_mode"
	
	# 服务器名称 / Server name
	local server_name
	server_name=$(config_get_server_name)
	echo "服务器名称 / Server Name: $server_name"
	
	# 服务器证书信息 / Server certificate information
	echo ""
	echo "证书信息 / Certificate Information:"
	echo "----------------------------------------"
	
	local expiry_date days_remaining
	expiry_date=$(ca_get_expiry_date "$server_name" 2>/dev/null || echo "Unknown")
	days_remaining=$(ca_get_days_remaining "$server_name" 2>/dev/null || echo "N/A")
	
	echo "过期日期 / Expiry Date: $expiry_date"
	echo "剩余天数 / Days Remaining: $days_remaining"
	
	# 如果证书即将过期，显示警告 / Show warning if certificate expiring soon
	if [[ "$days_remaining" =~ ^[0-9]+$ ]] && [[ "$days_remaining" -lt 30 ]]; then
		log_warn "证书即将过期！/ Certificate expiring soon!"
	fi
	
	# 显示连接的客户端 / Display connected clients
	echo ""
	echo "连接的客户端 / Connected Clients:"
	echo "----------------------------------------"
	
	if systemctl is-active --quiet openvpn-server@server; then
		server_show_connections
	else
		echo "服务未运行 / Service not running"
	fi
	
	return 0
}

# =============================================================================
# 服务器连接信息 / Server Connection Information
# =============================================================================

# 显示连接的客户端
# Display connected clients
# 返回 / Returns: 成功返回 0 / 0 on success
server_show_connections() {
	local status_file="/var/run/openvpn-server/server-status.log"
	
	if [[ ! -f "$status_file" ]]; then
		log_info "状态文件不可用 / Status file not available"
		return 0
	fi
	
	# 解析状态文件 / Parse status file
	local client_count=0
	
	# 提取客户端连接信息 / Extract client connection information
	while IFS=',' read -r name real_address virtual_address bytes_received bytes_sent connected_since; do
		# 跳过标题行 / Skip header lines
		[[ "$name" == "Common Name" ]] && continue
		[[ "$name" == "ROUTING TABLE" ]] && break
		
		if [[ -n "$name" && "$name" != "Updated" ]]; then
			printf "%-20s %-25s %-15s\n" "$name" "$real_address" "$virtual_address"
			((client_count++))
		fi
	done < <(sed -n '/CLIENT LIST/,/ROUTING TABLE/p' "$status_file" | tail -n +2)
	
	if [[ $client_count -eq 0 ]]; then
		echo "没有客户端连接 / No clients connected"
	else
		echo ""
		echo "总连接数 / Total Connections: $client_count"
	fi
	
	return 0
}

# =============================================================================
# 服务器证书更新 / Server Certificate Renewal
# =============================================================================

# 更新服务器证书
# Renew server certificate
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
server_renew_cert() {
	log_header "更新服务器证书 / Renewing Server Certificate"
	
	# 获取服务器名称和认证模式 / Get server name and auth mode
	local server_name auth_mode
	server_name=$(config_get_server_name)
	auth_mode=$(config_get_auth_mode)
	
	log_info "服务器名称 / Server Name: $server_name"
	log_info "认证模式 / Auth Mode: $auth_mode"
	
	# 更新证书 / Renew certificate
	if ! ca_renew_server_cert "$server_name" "$auth_mode"; then
		log_error "服务器证书更新失败 / Server certificate renewal failed"
		return 1
	fi
	
	# 更新 CRL（PKI 模式需要）/ Update CRL (needed for PKI mode)
	if [[ "$auth_mode" == "pki" ]]; then
		ca_generate_crl
	fi
	
	log_success "服务器证书更新成功 / Server certificate renewed successfully"
	log_info "请重启 OpenVPN 服务以应用更改 / Please restart OpenVPN service to apply changes"
	
	return 0
}

# =============================================================================
# 服务器控制 / Server Control
# =============================================================================

# 启动 OpenVPN 服务
# Start OpenVPN service
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
server_start() {
	log_info "启动 OpenVPN 服务 / Starting OpenVPN service"
	
	if systemctl start openvpn-server@server; then
		log_success "服务已启动 / Service started"
		return 0
	else
		log_error "服务启动失败 / Service start failed"
		return 1
	fi
}

# 停止 OpenVPN 服务
# Stop OpenVPN service
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
server_stop() {
	log_info "停止 OpenVPN 服务 / Stopping OpenVPN service"
	
	if systemctl stop openvpn-server@server; then
		log_success "服务已停止 / Service stopped"
		return 0
	else
		log_error "服务停止失败 / Service stop failed"
		return 1
	fi
}

# 重启 OpenVPN 服务
# Restart OpenVPN service
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
server_restart() {
	log_info "重启 OpenVPN 服务 / Restarting OpenVPN service"
	
	if systemctl restart openvpn-server@server; then
		log_success "服务已重启 / Service restarted"
		return 0
	else
		log_error "服务重启失败 / Service restart failed"
		return 1
	fi
}

# 重新加载 OpenVPN 服务配置
# Reload OpenVPN service configuration
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
server_reload() {
	log_info "重新加载服务配置 / Reloading service configuration"
	
	if systemctl reload openvpn-server@server; then
		log_success "配置已重新加载 / Configuration reloaded"
		return 0
	else
		log_warn "重新加载失败，尝试重启 / Reload failed, trying restart"
		server_restart
	fi
}

# =============================================================================
# 服务器日志 / Server Logs
# =============================================================================

# 显示服务器日志
# Display server logs
# 参数 / Args:
#   $1 - 行数（可选，默认50）/ number of lines (optional, default 50)
# 返回 / Returns: 成功返回 0 / 0 on success
server_logs() {
	local lines="${1:-50}"
	
	log_header "OpenVPN 服务器日志 / OpenVPN Server Logs (最后 / Last $lines 行 / lines)"
	
	journalctl -u openvpn-server@server -n "$lines" --no-pager
	
	return 0
}

# 实时查看服务器日志
# Follow server logs in real-time
# 返回 / Returns: 成功返回 0 / 0 on success
server_logs_follow() {
	log_header "实时服务器日志 / Real-time Server Logs (按 Ctrl+C 退出 / Press Ctrl+C to exit)"
	
	journalctl -u openvpn-server@server -f
	
	return 0
}

# =============================================================================
# 服务器配置 / Server Configuration
# =============================================================================

# 显示服务器配置
# Display server configuration
# 返回 / Returns: 成功返回 0 / 0 on success
server_show_config() {
	log_header "服务器配置 / Server Configuration"
	
	local config_file="/etc/openvpn/server/server.conf"
	
	if [[ ! -f "$config_file" ]]; then
		log_error "配置文件不存在 / Configuration file does not exist"
		return 1
	fi
	
	# 显示配置文件（排除注释和空行）
	# Display configuration file (excluding comments and empty lines)
	grep -v "^#" "$config_file" | grep -v "^$"
	
	return 0
}

# =============================================================================
# 服务器统计 / Server Statistics
# =============================================================================

# 显示服务器统计信息
# Display server statistics
# 返回 / Returns: 成功返回 0 / 0 on success
server_statistics() {
	log_header "服务器统计 / Server Statistics"
	
	# 服务运行时间 / Service uptime
	local service_start
	service_start=$(systemctl show openvpn-server@server --property=ActiveEnterTimestamp --value)
	
	if [[ -n "$service_start" && "$service_start" != "n/a" ]]; then
		echo "服务启动时间 / Service Start Time: $service_start"
		
		# 计算运行时间 / Calculate uptime
		local start_epoch current_epoch uptime_seconds
		start_epoch=$(date -d "$service_start" +%s 2>/dev/null)
		current_epoch=$(date +%s)
		
		if [[ -n "$start_epoch" ]]; then
			uptime_seconds=$((current_epoch - start_epoch))
			local days=$((uptime_seconds / 86400))
			local hours=$(((uptime_seconds % 86400) / 3600))
			local minutes=$(((uptime_seconds % 3600) / 60))
			
			echo "运行时间 / Uptime: ${days}天 / days ${hours}小时 / hours ${minutes}分钟 / minutes"
		fi
	else
		echo "服务未运行 / Service not running"
	fi
	
	echo ""
	
	# 连接统计 / Connection statistics
	local status_file="/var/run/openvpn-server/server-status.log"
	
	if [[ -f "$status_file" ]]; then
		# 统计客户端连接数 / Count client connections
		local total_clients
		total_clients=$(sed -n '/CLIENT LIST/,/ROUTING TABLE/p' "$status_file" | grep -v "^Common Name" | grep -v "^Updated" | grep -v "^ROUTING" | grep -c "^")
		
		echo "当前连接客户端数 / Current Connected Clients: $((total_clients - 1))"
		
		# 统计总字节数 / Count total bytes
		local total_bytes_in=0
		local total_bytes_out=0
		
		while IFS=',' read -r name addr vaddr bytes_in bytes_out time; do
			[[ "$name" == "Common Name" ]] && continue
			[[ "$name" == "ROUTING TABLE" ]] && break
			
			if [[ "$bytes_in" =~ ^[0-9]+$ ]]; then
				total_bytes_in=$((total_bytes_in + bytes_in))
			fi
			if [[ "$bytes_out" =~ ^[0-9]+$ ]]; then
				total_bytes_out=$((total_bytes_out + bytes_out))
			fi
		done < <(sed -n '/CLIENT LIST/,/ROUTING TABLE/p' "$status_file" | tail -n +2)
		
		# 转换为人类可读格式 / Convert to human readable format
		local bytes_in_mb=$((total_bytes_in / 1048576))
		local bytes_out_mb=$((total_bytes_out / 1048576))
		
		echo "总接收流量 / Total Bytes Received: ${bytes_in_mb} MB"
		echo "总发送流量 / Total Bytes Sent: ${bytes_out_mb} MB"
	fi
	
	return 0
}
