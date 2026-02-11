#!/usr/bin/env bash
# OpenVPN 安装脚本 - 卸载模块
# OpenVPN Install - Uninstall Module
# 完全移除 OpenVPN 和相关配置
# Complete removal of OpenVPN and related configuration

# 避免重复加载 / Avoid duplicate loading
[[ -n "${_UNINSTALL_MODULE_LOADED:-}" ]] && return 0
readonly _UNINSTALL_MODULE_LOADED=1

# 此模块依赖 / This module depends on:
# - lib/logging.sh
# - lib/config.sh
# - lib/firewall.sh
# - lib/system.sh

# =============================================================================
# 卸载确认 / Uninstall Confirmation
# =============================================================================

# 卸载前确认
# Confirm before uninstall
# 返回 / Returns: 用户确认返回 0，取消返回 1 / 0 if confirmed, 1 if cancelled
uninstall_confirm() {
	log_header "OpenVPN 卸载 / OpenVPN Uninstall"
	
	log_warn "警告：此操作将完全移除 OpenVPN 和所有相关配置！"
	log_warn "Warning: This will completely remove OpenVPN and all related configuration!"
	log_warn ""
	log_warn "这包括 / This includes:"
	log_warn "  - OpenVPN 软件包 / OpenVPN packages"
	log_warn "  - 所有证书和密钥 / All certificates and keys"
	log_warn "  - 服务器和客户端配置 / Server and client configurations"
	log_warn "  - 防火墙规则 / Firewall rules"
	log_warn "  - 系统配置更改 / System configuration changes"
	log_warn ""
	
	echo -n "确认卸载？输入 'yes' 继续 / Confirm uninstall? Type 'yes' to continue: "
	read -r confirmation
	
	if [[ "$confirmation" != "yes" ]]; then
		log_info "卸载已取消 / Uninstall cancelled"
		return 1
	fi
	
	return 0
}

# =============================================================================
# 服务停止 / Service Stop
# =============================================================================

# 停止并禁用 OpenVPN 服务
# Stop and disable OpenVPN service
# 返回 / Returns: 成功返回 0 / 0 on success
uninstall_stop_service() {
	log_info "停止 OpenVPN 服务 / Stopping OpenVPN service"
	
	# 停止服务 / Stop service
	if systemctl is-active --quiet openvpn-server@server; then
		systemctl stop openvpn-server@server >/dev/null 2>&1
		log_success "服务已停止 / Service stopped"
	else
		log_debug "服务未运行 / Service not running"
	fi
	
	# 禁用服务 / Disable service
	if systemctl is-enabled --quiet openvpn-server@server 2>/dev/null; then
		systemctl disable openvpn-server@server >/dev/null 2>&1
		log_success "服务已禁用 / Service disabled"
	else
		log_debug "服务未启用 / Service not enabled"
	fi
	
	return 0
}

# =============================================================================
# 防火墙规则移除 / Firewall Rules Removal
# =============================================================================

# 移除防火墙规则
# Remove firewall rules
# 返回 / Returns: 成功返回 0 / 0 on success
uninstall_remove_firewall() {
	log_info "移除防火墙规则 / Removing firewall rules"
	
	# 获取配置信息 / Get configuration
	local port protocol
	port=$(config_get_port)
	protocol=$(config_get_protocol)
	
	# 移除规则 / Remove rules
	firewall_remove_rules "$port" "$protocol"
	
	log_success "防火墙规则已移除 / Firewall rules removed"
	
	return 0
}

# =============================================================================
# IP 转发禁用 / IP Forwarding Disable
# =============================================================================

# 禁用 IP 转发
# Disable IP forwarding
# 返回 / Returns: 成功返回 0 / 0 on success
uninstall_disable_forwarding() {
	log_info "禁用 IP 转发 / Disabling IP forwarding"
	
	# 移除 sysctl 配置 / Remove sysctl configuration
	local sysctl_file="/etc/sysctl.d/99-openvpn.conf"
	
	if [[ -f "$sysctl_file" ]]; then
		rm -f "$sysctl_file"
		log_success "已移除 IP 转发配置 / IP forwarding configuration removed"
	fi
	
	# 重新加载 sysctl / Reload sysctl
	sysctl -p >/dev/null 2>&1
	
	return 0
}

# =============================================================================
# 文件和目录移除 / Files and Directories Removal
# =============================================================================

# 移除配置文件和目录
# Remove configuration files and directories
# 返回 / Returns: 成功返回 0 / 0 on success
uninstall_remove_files() {
	log_info "移除配置文件和证书 / Removing configuration files and certificates"
	
	# OpenVPN 配置目录 / OpenVPN configuration directory
	if [[ -d "/etc/openvpn" ]]; then
		rm -rf /etc/openvpn
		log_success "已移除 /etc/openvpn"
	fi
	
	# 客户端配置文件 / Client configuration files
	local home_ovpn_files
	home_ovpn_files=$(find "${HOME}" -maxdepth 1 -name "*.ovpn" 2>/dev/null)
	
	if [[ -n "$home_ovpn_files" ]]; then
		while IFS= read -r file; do
			rm -f "$file"
			log_debug "已删除 / Removed: $file"
		done <<< "$home_ovpn_files"
		log_success "已移除客户端配置文件 / Client configuration files removed"
	fi
	
	# systemd 服务文件（如果是自定义的）
	# systemd service files (if custom)
	local custom_service="/etc/systemd/system/iptables-openvpn.service"
	if [[ -f "$custom_service" ]]; then
		rm -f "$custom_service"
		systemctl daemon-reload
		log_success "已移除自定义 systemd 服务 / Custom systemd service removed"
	fi
	
	return 0
}

# =============================================================================
# 软件包移除 / Package Removal
# =============================================================================

# 卸载 OpenVPN 软件包
# Uninstall OpenVPN packages
# 返回 / Returns: 成功返回 0 / 0 on success
uninstall_remove_packages() {
	log_info "卸载 OpenVPN 软件包 / Uninstalling OpenVPN packages"
	
	# 获取包管理器 / Get package manager
	local pm
	pm=$(get_package_manager)
	
	# 根据包管理器卸载 / Uninstall based on package manager
	case "$pm" in
		apt-get)
			apt-get remove --purge -y openvpn easy-rsa >/dev/null 2>&1
			apt-get autoremove -y >/dev/null 2>&1
			;;
		dnf|yum)
			"$pm" remove -y openvpn easy-rsa >/dev/null 2>&1
			;;
		pacman)
			pacman -Rns --noconfirm openvpn easy-rsa >/dev/null 2>&1
			;;
		zypper)
			zypper remove -y openvpn easy-rsa >/dev/null 2>&1
			;;
		*)
			log_warn "未知的包管理器，请手动卸载 / Unknown package manager, please uninstall manually"
			return 1
			;;
	esac
	
	log_success "OpenVPN 软件包已卸载 / OpenVPN packages uninstalled"
	
	return 0
}

# =============================================================================
# 完整卸载 / Complete Uninstall
# =============================================================================

# 执行完整卸载
# Perform complete uninstall
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
uninstall_execute() {
	log_header "开始卸载 / Starting Uninstall"
	
	# 确认 / Confirm
	if ! uninstall_confirm; then
		return 1
	fi
	
	log_info ""
	log_info "执行卸载步骤 / Executing uninstall steps..."
	log_info ""
	
	# 步骤 1: 停止服务 / Step 1: Stop service
	uninstall_stop_service
	
	# 步骤 2: 移除防火墙规则 / Step 2: Remove firewall rules
	uninstall_remove_firewall
	
	# 步骤 3: 禁用 IP 转发 / Step 3: Disable IP forwarding
	uninstall_disable_forwarding
	
	# 步骤 4: 移除文件 / Step 4: Remove files
	uninstall_remove_files
	
	# 步骤 5: 卸载软件包 / Step 5: Remove packages
	uninstall_remove_packages
	
	log_info ""
	log_success "========================================="
	log_success "卸载完成 / Uninstall Complete"
	log_success "========================================="
	log_info ""
	log_info "OpenVPN 已从系统中完全移除"
	log_info "OpenVPN has been completely removed from the system"
	
	return 0
}

# =============================================================================
# 部分卸载 / Partial Uninstall
# =============================================================================

# 仅移除客户端配置（保留服务器）
# Remove only client configurations (keep server)
# 返回 / Returns: 成功返回 0 / 0 on success
uninstall_clients_only() {
	log_header "移除所有客户端 / Removing All Clients"
	
	log_warn "这将移除所有客户端证书和配置文件"
	log_warn "This will remove all client certificates and configuration files"
	log_warn ""
	
	echo -n "确认？输入 'yes' 继续 / Confirm? Type 'yes' to continue: "
	read -r confirmation
	
	if [[ "$confirmation" != "yes" ]]; then
		log_info "操作已取消 / Operation cancelled"
		return 1
	fi
	
	# 移除所有客户端证书 / Remove all client certificates
	local easyrsa_dir="/etc/openvpn/server/easy-rsa"
	local issued_dir="${easyrsa_dir}/pki/issued"
	
	if [[ -d "$issued_dir" ]]; then
		# 获取所有客户端证书 / Get all client certificates
		local certs
		certs=$(ca_list_client_certs)
		
		if [[ -n "$certs" ]]; then
			while IFS= read -r cert_name; do
				log_info "撤销 / Revoking: $cert_name"
				ca_revoke_client_cert "$cert_name" 2>/dev/null
				
				# 删除配置文件 / Remove configuration file
				rm -f "${HOME}/${cert_name}.ovpn" 2>/dev/null
			done <<< "$certs"
			
			# 更新 CRL / Update CRL
			ca_generate_crl
			
			log_success "所有客户端已移除 / All clients removed"
		else
			log_info "没有找到客户端 / No clients found"
		fi
	else
		log_error "Easy-RSA 目录不存在 / Easy-RSA directory does not exist"
		return 1
	fi
	
	return 0
}

# =============================================================================
# 备份功能 / Backup Function
# =============================================================================

# 备份配置（卸载前）
# Backup configuration (before uninstall)
# 参数 / Args:
#   $1 - 备份目录 / backup directory (可选 / optional)
# 返回 / Returns: 成功返回 0，失败返回 1 / 0 on success, 1 on failure
uninstall_backup() {
	local backup_dir="${1:-${HOME}/openvpn-backup-$(date +%Y%m%d-%H%M%S)}"
	
	log_header "备份配置 / Backing Up Configuration"
	log_info "备份目录 / Backup Directory: $backup_dir"
	
	# 创建备份目录 / Create backup directory
	mkdir -p "$backup_dir"
	
	# 备份配置 / Backup configuration
	if [[ -d "/etc/openvpn" ]]; then
		cp -r /etc/openvpn "$backup_dir/" 2>/dev/null
		log_success "已备份 /etc/openvpn"
	fi
	
	# 备份客户端配置文件 / Backup client configuration files
	find "${HOME}" -maxdepth 1 -name "*.ovpn" -exec cp {} "$backup_dir/" \; 2>/dev/null
	
	# 备份防火墙脚本 / Backup firewall scripts
	if [[ -d "/etc/iptables" ]]; then
		cp -r /etc/iptables "$backup_dir/" 2>/dev/null
	fi
	
	# 创建备份信息文件 / Create backup info file
	cat > "$backup_dir/backup-info.txt" <<-EOF
	备份时间 / Backup Time: $(date)
	服务器名称 / Server Name: $(config_get_server_name 2>/dev/null || echo "Unknown")
	端口 / Port: $(config_get_port 2>/dev/null || echo "Unknown")
	协议 / Protocol: $(config_get_protocol 2>/dev/null || echo "Unknown")
	认证模式 / Auth Mode: $(config_get_auth_mode 2>/dev/null || echo "Unknown")
	EOF
	
	log_success "备份完成 / Backup completed: $backup_dir"
	
	return 0
}
