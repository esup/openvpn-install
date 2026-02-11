#!/usr/bin/env bash
# OpenVPN 安装脚本 - 日志库
# OpenVPN Install - Logging Library
# 提取的可重用日志功能模块
# Extracted logging functions for reusability

# 避免重复加载 / Avoid duplicate loading
[[ -n "${_LOGGING_LIB_LOADED:-}" ]] && return 0
readonly _LOGGING_LIB_LOADED=1

# =============================================================================
# 日志配置 / Logging Configuration
# =============================================================================
# 设置 VERBOSE=1 显示命令输出，VERBOSE=0（默认）为静默模式
# Set VERBOSE=1 to see command output, VERBOSE=0 (default) for quiet mode
# 设置 LOG_FILE 自定义日志位置（默认：当前目录的 openvpn-install.log）
# Set LOG_FILE to customize log location (default: openvpn-install.log in current dir)
# 设置 LOG_FILE="" 禁用文件日志
# Set LOG_FILE="" to disable file logging
VERBOSE=${VERBOSE:-0}
LOG_FILE=${LOG_FILE:-openvpn-install.log}
OUTPUT_FORMAT=${OUTPUT_FORMAT:-table} # table 或 json - json 模式抑制日志输出

# 颜色定义（如果不是终端则禁用，除非设置 FORCE_COLOR=1）
# Color definitions (disabled if not a terminal, unless FORCE_COLOR=1)
if [[ -t 1 ]] || [[ "${FORCE_COLOR:-0}" == "1" ]]; then
	readonly COLOR_RESET='\033[0m'      # 重置颜色 / Reset
	readonly COLOR_RED='\033[0;31m'     # 红色（错误）/ Red (errors)
	readonly COLOR_GREEN='\033[0;32m'   # 绿色（成功）/ Green (success)
	readonly COLOR_YELLOW='\033[0;33m'  # 黄色（警告）/ Yellow (warnings)
	readonly COLOR_BLUE='\033[0;34m'    # 蓝色（信息）/ Blue (info)
	readonly COLOR_CYAN='\033[0;36m'    # 青色（提示）/ Cyan (prompts)
	readonly COLOR_DIM='\033[0;90m'     # 暗色（调试）/ Dim (debug)
	readonly COLOR_BOLD='\033[1m'       # 粗体（标题）/ Bold (headers)
else
	# 非终端环境，禁用所有颜色 / Non-terminal, disable all colors
	readonly COLOR_RESET=''
	readonly COLOR_RED=''
	readonly COLOR_GREEN=''
	readonly COLOR_YELLOW=''
	readonly COLOR_BLUE=''
	readonly COLOR_CYAN=''
	readonly COLOR_DIM=''
	readonly COLOR_BOLD=''
fi

# 写入日志文件（无颜色，带时间戳）
# Write to log file (no colors, with timestamp)
# 参数 / Args: $* - 日志消息 / log message
_log_to_file() {
	if [[ -n "$LOG_FILE" ]]; then
		echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >>"$LOG_FILE"
	fi
}

# =============================================================================
# 日志函数 / Logging Functions
# =============================================================================

# 信息日志（蓝色）
# Info log (blue)
# 参数 / Args: $* - 消息内容 / message
log_info() {
	[[ $OUTPUT_FORMAT == "json" ]] && return
	echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
	_log_to_file "[INFO] $*"
}

# 警告日志（黄色）
# Warning log (yellow)
# 参数 / Args: $* - 警告消息 / warning message
log_warn() {
	[[ $OUTPUT_FORMAT == "json" ]] && return
	echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*"
	_log_to_file "[WARN] $*"
}

# 错误日志（红色，输出到 stderr）
# Error log (red, output to stderr)
# 参数 / Args: $* - 错误消息 / error message
log_error() {
	echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
	_log_to_file "[ERROR] $*"
	if [[ -n "$LOG_FILE" ]]; then
		echo -e "${COLOR_YELLOW}        查看日志文件获取详情 / Check the log file for details: ${LOG_FILE}${COLOR_RESET}" >&2
	fi
}

# 致命错误日志（红色，记录后退出脚本）
# Fatal error log (red, exits script after logging)
# 参数 / Args: $* - 致命错误消息 / fatal error message
# 返回 / Returns: 退出脚本，返回码 1 / exits script with code 1
log_fatal() {
	echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
	_log_to_file "[FATAL] $*"
	if [[ -n "$LOG_FILE" ]]; then
		echo -e "${COLOR_YELLOW}        查看日志文件获取详情 / Check the log file for details: ${LOG_FILE}${COLOR_RESET}" >&2
		_log_to_file "Script exited with error"
	fi
	exit 1
}

# 成功日志（绿色）
# Success log (green)
# 参数 / Args: $* - 成功消息 / success message
log_success() {
	[[ $OUTPUT_FORMAT == "json" ]] && return
	echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} $*"
	_log_to_file "[OK] $*"
}

# 调试日志（暗色，仅在 VERBOSE=1 时显示）
# Debug log (dim, only shown when VERBOSE=1)
# 参数 / Args: $* - 调试消息 / debug message
log_debug() {
	if [[ $VERBOSE -eq 1 && $OUTPUT_FORMAT != "json" ]]; then
		echo -e "${COLOR_DIM}[DEBUG]${COLOR_RESET} $*"
	fi
	_log_to_file "[DEBUG] $*"
}

# 用户提示（青色，无前缀）
# User prompt (cyan, no prefix)
# 参数 / Args: $* - 提示内容 / prompt message
# 注意 / Note: 在非交互模式下跳过显示 / Skip display in non-interactive mode
log_prompt() {
	if [[ $NON_INTERACTIVE_INSTALL != "y" ]]; then
		echo -e "${COLOR_CYAN}$*${COLOR_RESET}"
	fi
	_log_to_file "[PROMPT] $*"
}

# 节标题（粗体蓝色）
# Section header (bold blue)
# 参数 / Args: $* - 标题内容 / header text
# 注意 / Note: 在非交互模式下跳过显示 / Skip display in non-interactive mode
log_header() {
	if [[ $NON_INTERACTIVE_INSTALL != "y" ]]; then
		echo ""
		echo -e "${COLOR_BOLD}${COLOR_BLUE}=== $* ===${COLOR_RESET}"
		echo ""
	fi
	_log_to_file "=== $* ==="
}

# 菜单选项（仅在交互模式显示）
# Menu options (only show in interactive mode)
# 参数 / Args: $@ - 菜单内容 / menu content
log_menu() {
	if [[ $NON_INTERACTIVE_INSTALL != "y" ]]; then
		echo "$@"
	fi
}

# =============================================================================
# 命令执行函数 / Command Execution Functions
# =============================================================================

# 运行命令（可选的输出抑制）
# Run a command with optional output suppression
# 用法 / Usage: run_cmd "描述 / description" command [args...]
# 参数 / Args:
#   $1 - 命令描述 / command description
#   $@ - 要执行的命令及参数 / command and arguments to execute
# 返回 / Returns: 命令的退出码 / command exit code
run_cmd() {
	local desc="$1"
	shift
	# 显示正在运行的命令 / Display the command being run
	echo -e "${COLOR_DIM}> $*${COLOR_RESET}"
	_log_to_file "[CMD] $*"
	if [[ $VERBOSE -eq 1 ]]; then
		# 详细模式：显示输出并记录到文件
		# Verbose mode: show output and log to file
		if [[ -n "$LOG_FILE" ]]; then
			"$@" 2>&1 | tee -a "$LOG_FILE"
		else
			"$@"
		fi
	else
		# 静默模式：隐藏输出
		# Quiet mode: suppress output
		if [[ -n "$LOG_FILE" ]]; then
			"$@" >>"$LOG_FILE" 2>&1
		else
			"$@" >/dev/null 2>&1
		fi
	fi
	local ret=$?
	if [[ $ret -eq 0 ]]; then
		log_debug "$desc 成功完成 / completed successfully"
	else
		log_error "$desc 失败，退出码 / failed with exit code $ret"
	fi
	return $ret
}

# 运行必须成功的命令（失败时退出）
# Run a command that must succeed, exit on failure
# 用法 / Usage: run_cmd_fatal "描述 / description" command [args...]
# 参数 / Args:
#   $1 - 命令描述 / command description
#   $@ - 要执行的命令及参数 / command and arguments to execute
# 返回 / Returns: 成功时返回 0，失败时退出脚本 / 0 on success, exits script on failure
run_cmd_fatal() {
	local desc="$1"
	shift
	if ! run_cmd "$desc" "$@"; then
		log_fatal "$desc 失败 / failed"
	fi
}
