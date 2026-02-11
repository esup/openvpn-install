#!/bin/bash
# OpenVPN 安装脚本 - 完整演示
# OpenVPN Install - Complete Demo
# 展示如何使用所有模块进行完整的 OpenVPN 管理
# Demonstrates how to use all modules for complete OpenVPN management

# 设置脚本目录 / Set script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# 加载所有库模块 / Load All Library Modules
# =============================================================================

echo "加载库模块 / Loading library modules..."

# 必需的环境变量 / Required environment variables
export VERBOSE=${VERBOSE:-0}
export LOG_FILE=${LOG_FILE:-""}
export OUTPUT_FORMAT=${OUTPUT_FORMAT:-"table"}
export FORCE_COLOR=${FORCE_COLOR:-0}
export NON_INTERACTIVE_INSTALL=${NON_INTERACTIVE_INSTALL:-"n"}

# 加载库 / Load libraries
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/validation.sh"
source "${SCRIPT_DIR}/lib/system.sh"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/firewall.sh"
source "${SCRIPT_DIR}/lib/ca.sh"
source "${SCRIPT_DIR}/lib/ui.sh"

# 加载命令模块 / Load command modules
source "${SCRIPT_DIR}/modules/install.sh"
source "${SCRIPT_DIR}/modules/client.sh"
source "${SCRIPT_DIR}/modules/server.sh"
source "${SCRIPT_DIR}/modules/uninstall.sh"

echo "✅ 所有模块加载成功 / All modules loaded successfully"
echo ""

# =============================================================================
# 主菜单 / Main Menu
# =============================================================================

# 显示主菜单
# Display main menu
show_main_menu() {
	clear
	log_header "OpenVPN 管理系统 / OpenVPN Management System"
	
	echo "请选择操作 / Please select an option:"
	echo ""
	echo "  安装 / Installation:"
	echo "    1) 安装 OpenVPN 服务器 / Install OpenVPN Server"
	echo ""
	echo "  客户端管理 / Client Management:"
	echo "    2) 添加客户端 / Add Client"
	echo "    3) 列出所有客户端 / List All Clients"
	echo "    4) 撤销客户端 / Revoke Client"
	echo "    5) 更新客户端证书 / Renew Client Certificate"
	echo ""
	echo "  服务器管理 / Server Management:"
	echo "    6) 查看服务器状态 / View Server Status"
	echo "    7) 查看服务器统计 / View Server Statistics"
	echo "    8) 重启服务器 / Restart Server"
	echo "    9) 查看服务器日志 / View Server Logs"
	echo ""
	echo "  其他 / Other:"
	echo "    10) 卸载 OpenVPN / Uninstall OpenVPN"
	echo "    11) 备份配置 / Backup Configuration"
	echo ""
	echo "    0) 退出 / Exit"
	echo ""
	echo -n "选择 / Choice: "
}

# =============================================================================
# 菜单处理 / Menu Handlers
# =============================================================================

# 处理安装
# Handle installation
handle_install() {
	log_header "安装 OpenVPN 服务器 / Installing OpenVPN Server"
	
	if ui_confirm "开始安装？/ Start installation?" "y"; then
		install_execute
		ui_wait_key "按任意键返回主菜单 / Press any key to return to main menu"
	fi
}

# 处理添加客户端
# Handle add client
handle_add_client() {
	log_header "添加客户端 / Add Client"
	
	local client_name
	client_name=$(ui_input_client_name)
	
	if ui_ask_client_password; then
		local password
		password=$(ui_input_password "输入客户端密钥密码 / Enter client key password")
		client_add "$client_name" "$password"
	else
		client_add "$client_name"
	fi
	
	ui_wait_key
}

# 处理列出客户端
# Handle list clients
handle_list_clients() {
	client_list "table"
	ui_wait_key
}

# 处理撤销客户端
# Handle revoke client
handle_revoke_client() {
	# 先显示列表 / Show list first
	client_list "table"
	echo ""
	
	local client_name
	client_name=$(ui_input_client_name)
	
	if ui_confirm "确认撤销客户端 '$client_name'？/ Confirm revoke client '$client_name'?" "n"; then
		client_revoke "$client_name"
	fi
	
	ui_wait_key
}

# 处理更新客户端证书
# Handle renew client certificate
handle_renew_client() {
	# 先显示列表 / Show list first
	client_list "table"
	echo ""
	
	local client_name
	client_name=$(ui_input_client_name)
	
	client_renew "$client_name"
	ui_wait_key
}

# 处理服务器状态
# Handle server status
handle_server_status() {
	server_status
	ui_wait_key
}

# 处理服务器统计
# Handle server statistics
handle_server_stats() {
	server_statistics
	ui_wait_key
}

# 处理重启服务器
# Handle restart server
handle_restart_server() {
	if ui_confirm "确认重启 OpenVPN 服务？/ Confirm restart OpenVPN service?" "n"; then
		server_restart
	fi
	ui_wait_key
}

# 处理查看日志
# Handle view logs
handle_view_logs() {
	server_logs 100
	ui_wait_key
}

# 处理卸载
# Handle uninstall
handle_uninstall() {
	uninstall_execute
	ui_wait_key
}

# 处理备份
# Handle backup
handle_backup() {
	local backup_dir
	backup_dir="${HOME}/openvpn-backup-$(date +%Y%m%d-%H%M%S)"
	
	uninstall_backup "$backup_dir"
	ui_wait_key
}

# =============================================================================
# 主循环 / Main Loop
# =============================================================================

# 主程序
# Main program
main() {
	# 检查是否以 root 身份运行 / Check if running as root
	if [[ $EUID -ne 0 ]]; then
		log_error "此脚本必须以 root 身份运行 / This script must be run as root"
		log_info "请使用：sudo $0 / Please use: sudo $0"
		exit 1
	fi
	
	# 检测操作系统 / Detect operating system
	detect_os
	
	# 主循环 / Main loop
	while true; do
		show_main_menu
		read -r choice
		
		case "$choice" in
			1)
				handle_install
				;;
			2)
				handle_add_client
				;;
			3)
				handle_list_clients
				;;
			4)
				handle_revoke_client
				;;
			5)
				handle_renew_client
				;;
			6)
				handle_server_status
				;;
			7)
				handle_server_stats
				;;
			8)
				handle_restart_server
				;;
			9)
				handle_view_logs
				;;
			10)
				handle_uninstall
				;;
			11)
				handle_backup
				;;
			0)
				log_info "退出 / Exiting..."
				exit 0
				;;
			*)
				log_error "无效的选择 / Invalid choice"
				sleep 2
				;;
		esac
	done
}

# 如果直接运行此脚本 / If running this script directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
