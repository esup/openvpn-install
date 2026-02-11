#!/bin/bash
# OpenVPN 安装脚本 - 用户界面库
# OpenVPN Install - User Interface Library
# 交互式提示和菜单系统
# Interactive prompts and menu system

# =============================================================================
# 通用输入函数 / Generic Input Functions
# =============================================================================

# 通用提示函数（带验证和默认值）
# Generic prompt function with validation and default value
# 参数 / Args:
#   $1 - 提示消息 / prompt message
#   $2 - 默认值 / default value (可选 / optional)
#   $3 - 验证函数名 / validation function name (可选 / optional)
# 返回 / Returns: 用户输入输出到 stdout / user input on stdout
ui_prompt() {
	local prompt="$1"
	local default="$2"
	local validate_fn="${3:-}"
	local input
	
	while true; do
		# 显示提示 / Display prompt
		if [[ -n "$default" ]]; then
			log_prompt "$prompt [默认 / default: $default]:"
		else
			log_prompt "$prompt:"
		fi
		
		# 读取输入 / Read input
		read -r input
		
		# 使用默认值（如果没有输入）/ Use default if no input
		if [[ -z "$input" && -n "$default" ]]; then
			input="$default"
		fi
		
		# 验证输入 / Validate input
		if [[ -n "$validate_fn" ]]; then
			if $validate_fn "$input"; then
				echo "$input"
				return 0
			else
				log_error "输入无效，请重试 / Invalid input, please try again"
				continue
			fi
		else
			echo "$input"
			return 0
		fi
	done
}

# 确认提示（是/否）
# Confirmation prompt (yes/no)
# 参数 / Args:
#   $1 - 提示消息 / prompt message
#   $2 - 默认值 (y 或 n) / default value (y or n) (可选 / optional)
# 返回 / Returns: 是返回 0，否返回 1 / 0 for yes, 1 for no
ui_confirm() {
	local prompt="$1"
	local default="${2:-n}"
	local input
	
	while true; do
		if [[ "$default" == "y" ]]; then
			log_prompt "$prompt [Y/n]:"
		else
			log_prompt "$prompt [y/N]:"
		fi
		
		read -r input
		
		# 使用默认值 / Use default
		if [[ -z "$input" ]]; then
			input="$default"
		fi
		
		case "${input,,}" in  # 转换为小写 / Convert to lowercase
			y|yes|是)
				return 0
				;;
			n|no|否)
				return 1
				;;
			*)
				log_error "请输入 y 或 n / Please enter y or n"
				;;
		esac
	done
}

# =============================================================================
# 选择菜单 / Selection Menus
# =============================================================================

# 单选菜单
# Single selection menu
# 参数 / Args:
#   $1 - 菜单标题 / menu title
#   $@ - 选项列表 / option list
# 返回 / Returns: 所选项目输出到 stdout / selected item on stdout
ui_select() {
	local title="$1"
	shift
	local options=("$@")
	local choice
	
	log_header "$title"
	
	# 显示选项 / Display options
	local i=1
	for option in "${options[@]}"; do
		log_menu "  $i) $option"
		((i++))
	done
	
	# 读取选择 / Read selection
	while true; do
		log_prompt "请选择 / Select [1-${#options[@]}]:"
		read -r choice
		
		# 验证选择 / Validate selection
		if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#options[@]})); then
			echo "${options[$((choice-1))]}"
			return 0
		else
			log_error "无效的选择 / Invalid selection"
		fi
	done
}

# 多选菜单
# Multiple selection menu
# 参数 / Args:
#   $1 - 菜单标题 / menu title
#   $@ - 选项列表 / option list
# 返回 / Returns: 所选项目（空格分隔）输出到 stdout / selected items (space-separated) on stdout
ui_multiselect() {
	local title="$1"
	shift
	local options=("$@")
	local selections=()
	local choice
	
	log_header "$title"
	log_info "输入多个编号（用空格分隔）或输入 'done' 完成选择"
	log_info "Enter multiple numbers (space-separated) or 'done' when finished"
	
	# 显示选项 / Display options
	local i=1
	for option in "${options[@]}"; do
		log_menu "  $i) $option"
		((i++))
	done
	
	# 读取选择 / Read selections
	while true; do
		log_prompt "请选择 / Select [1-${#options[@]}] 或 / or 'done':"
		read -r choice
		
		if [[ "$choice" == "done" || "$choice" == "完成" ]]; then
			if [[ ${#selections[@]} -eq 0 ]]; then
				log_error "请至少选择一项 / Please select at least one item"
				continue
			fi
			break
		fi
		
		# 处理多个选择 / Process multiple selections
		for num in $choice; do
			if [[ "$num" =~ ^[0-9]+$ ]] && ((num >= 1 && num <= ${#options[@]})); then
				selections+=("${options[$((num-1))]}")
			else
				log_error "无效的选择 / Invalid selection: $num"
			fi
		done
	done
	
	# 输出选择的项目 / Output selected items
	echo "${selections[@]}"
	return 0
}

# =============================================================================
# 网络配置输入 / Network Configuration Input
# =============================================================================

# 输入端口号
# Input port number
# 参数 / Args:
#   $1 - 默认端口 / default port (可选 / optional)
# 返回 / Returns: 端口号输出到 stdout / port number on stdout
ui_input_port() {
	local default="${1:-1194}"
	
	ui_prompt "输入 OpenVPN 端口号 / Enter OpenVPN port" "$default" "validate_port"
}

# 选择协议
# Select protocol
# 参数 / Args:
#   $1 - 默认协议 / default protocol (可选 / optional)
# 返回 / Returns: 协议输出到 stdout (udp 或 tcp) / protocol on stdout (udp or tcp)
ui_select_protocol() {
	local default="${1:-udp}"
	
	local protocols=("UDP（推荐，速度更快）/ UDP (recommended, faster)" "TCP（在受限网络中更可靠）/ TCP (more reliable in restricted networks)")
	local selection
	selection=$(ui_select "选择协议 / Select protocol" "${protocols[@]}")
	
	if [[ "$selection" == "${protocols[0]}" ]]; then
		echo "udp"
	else
		echo "tcp"
	fi
}

# 选择 DNS 提供商
# Select DNS provider
# 参数 / Args:
#   $1 - 默认 DNS / default DNS (可选 / optional)
# 返回 / Returns: DNS 提供商输出到 stdout / DNS provider on stdout
ui_select_dns() {
	local default="${1:-cloudflare}"
	
	local dns_options=(
		"Cloudflare (1.1.1.1)"
		"Google (8.8.8.8)"
		"Quad9 (9.9.9.9)"
		"AdGuard DNS"
		"OpenDNS"
		"系统默认 / System default"
		"自定义 / Custom"
	)
	
	local selection
	selection=$(ui_select "选择 DNS 提供商 / Select DNS provider" "${dns_options[@]}")
	
	case "$selection" in
		*"Cloudflare"*)
			echo "cloudflare"
			;;
		*"Google"*)
			echo "google"
			;;
		*"Quad9"*)
			echo "quad9"
			;;
		*"AdGuard"*)
			echo "adguard"
			;;
		*"OpenDNS"*)
			echo "opendns"
			;;
		*"System"*|*"系统"*)
			echo "system"
			;;
		*"Custom"*|*"自定义"*)
			echo "custom"
			;;
		*)
			echo "$default"
			;;
	esac
}

# =============================================================================
# 安全配置输入 / Security Configuration Input
# =============================================================================

# 选择加密算法
# Select cipher
# 参数 / Args:
#   $1 - 默认加密算法 / default cipher (可选 / optional)
# 返回 / Returns: 加密算法输出到 stdout / cipher on stdout
ui_select_cipher() {
	local default="${1:-AES-128-GCM}"
	
	local ciphers=(
		"AES-128-GCM（推荐，平衡性能和安全）/ AES-128-GCM (recommended, balanced)"
		"AES-256-GCM（最高安全性）/ AES-256-GCM (highest security)"
		"AES-192-GCM（中等安全性）/ AES-192-GCM (medium security)"
		"CHACHA20-POLY1305（适用于无硬件加速）/ CHACHA20-POLY1305 (for devices without AES-NI)"
	)
	
	local selection
	selection=$(ui_select "选择数据通道加密算法 / Select data channel cipher" "${ciphers[@]}")
	
	case "$selection" in
		*"128"*)
			echo "AES-128-GCM"
			;;
		*"256"*)
			echo "AES-256-GCM"
			;;
		*"192"*)
			echo "AES-192-GCM"
			;;
		*"CHACHA"*)
			echo "CHACHA20-POLY1305"
			;;
		*)
			echo "$default"
			;;
	esac
}

# 选择证书类型
# Select certificate type
# 参数 / Args:
#   $1 - 默认类型 / default type (可选 / optional)
# 返回 / Returns: 证书类型输出到 stdout / certificate type on stdout
ui_select_cert_type() {
	local default="${1:-ecdsa}"
	
	local types=(
		"ECDSA（推荐，更快更安全）/ ECDSA (recommended, faster and more secure)"
		"RSA（传统，更广泛兼容）/ RSA (traditional, broader compatibility)"
	)
	
	local selection
	selection=$(ui_select "选择证书类型 / Select certificate type" "${types[@]}")
	
	if [[ "$selection" == "${types[0]}" ]]; then
		echo "ecdsa"
	else
		echo "rsa"
	fi
}

# 选择认证模式
# Select authentication mode
# 参数 / Args:
#   $1 - 默认模式 / default mode (可选 / optional)
# 返回 / Returns: 认证模式输出到 stdout / authentication mode on stdout
ui_select_auth_mode() {
	local default="${1:-pki}"
	
	local modes=(
		"PKI（传统 CA 模式，推荐用于大规模部署）/ PKI (traditional CA mode, recommended for large deployments)"
		"Fingerprint（简化的指纹模式，类似 WireGuard，需要 OpenVPN 2.6+）/ Fingerprint (simplified mode like WireGuard, requires OpenVPN 2.6+)"
	)
	
	local selection
	selection=$(ui_select "选择认证模式 / Select authentication mode" "${modes[@]}")
	
	if [[ "$selection" == "${modes[0]}" ]]; then
		echo "pki"
	else
		echo "fingerprint"
	fi
}

# =============================================================================
# 客户端配置输入 / Client Configuration Input
# =============================================================================

# 输入客户端名称
# Input client name
# 参数 / Args:
#   $1 - 默认名称 / default name (可选 / optional)
# 返回 / Returns: 客户端名称输出到 stdout / client name on stdout
ui_input_client_name() {
	local default="${1:-client}"
	
	ui_prompt "输入客户端名称 / Enter client name" "$default" "validate_client_name"
}

# 询问是否为客户端密钥设置密码
# Ask if password should be set for client key
# 返回 / Returns: 需要密码返回 0，不需要返回 1 / 0 if password needed, 1 if not
ui_ask_client_password() {
	ui_confirm "是否为客户端私钥设置密码保护？/ Protect client private key with password?" "n"
}

# 输入密码（带确认）
# Input password (with confirmation)
# 参数 / Args:
#   $1 - 提示消息 / prompt message
# 返回 / Returns: 密码输出到 stdout / password on stdout
ui_input_password() {
	local prompt="${1:-输入密码 / Enter password}"
	local password1
	local password2
	
	while true; do
		log_prompt "$prompt:"
		read -rs password1
		echo
		
		log_prompt "确认密码 / Confirm password:"
		read -rs password2
		echo
		
		if [[ "$password1" == "$password2" ]]; then
			if [[ -z "$password1" ]]; then
				log_error "密码不能为空 / Password cannot be empty"
				continue
			fi
			echo "$password1"
			return 0
		else
			log_error "密码不匹配，请重试 / Passwords do not match, please try again"
		fi
	done
}

# =============================================================================
# 信息显示 / Information Display
# =============================================================================

# 显示进度条
# Display progress bar
# 参数 / Args:
#   $1 - 当前进度 (0-100) / current progress (0-100)
#   $2 - 描述文本 / description text (可选 / optional)
ui_progress() {
	local progress="$1"
	local desc="${2:-}"
	local width=50
	local filled=$((progress * width / 100))
	local empty=$((width - filled))
	
	printf "\r["
	printf "%${filled}s" | tr ' ' '='
	printf "%${empty}s" | tr ' ' ' '
	printf "] %3d%%" "$progress"
	
	if [[ -n "$desc" ]]; then
		printf " - %s" "$desc"
	fi
}

# 显示表格
# Display table
# 参数 / Args:
#   $1 - 表头（用 '|' 分隔）/ header (separated by '|')
#   $@ - 数据行（用 '|' 分隔）/ data rows (separated by '|')
ui_table() {
	local header="$1"
	shift
	local rows=("$@")
	
	# 打印表头 / Print header
	log_header "$(echo "$header" | tr '|' '\t')"
	
	# 打印分隔线 / Print separator
	echo "----------------------------------------"
	
	# 打印数据行 / Print data rows
	for row in "${rows[@]}"; do
		echo "$row" | tr '|' '\t'
	done
}

# =============================================================================
# 等待和动画 / Waiting and Animation
# =============================================================================

# 显示旋转加载动画
# Display spinning loader animation
# 参数 / Args:
#   $1 - PID（要等待的进程）/ PID (process to wait for)
#   $2 - 描述文本 / description text (可选 / optional)
ui_spinner() {
	local pid="$1"
	local desc="${2:-加载中 / Loading}"
	local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
	local i=0
	
	while kill -0 "$pid" 2>/dev/null; do
		i=$(( (i+1) % ${#spin} ))
		printf "\r${COLOR_CYAN}${spin:$i:1}${COLOR_RESET} %s" "$desc"
		sleep 0.1
	done
	
	printf "\r${COLOR_GREEN}✓${COLOR_RESET} %s\n" "$desc"
}

# 等待用户按键继续
# Wait for user to press a key to continue
# 参数 / Args:
#   $1 - 提示消息 / prompt message (可选 / optional)
ui_wait_key() {
	local prompt="${1:-按任意键继续 / Press any key to continue}"
	
	log_prompt "$prompt"
	read -n 1 -s -r
	echo
}
