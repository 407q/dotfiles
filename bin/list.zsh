#!/usr/bin/env zsh
# dots - list.zsh
# 管理対象の dotfiles を一覧表示

show_list_help() {
    cat << 'EOF'
dots list - List managed dotfiles

Usage: dots list [options]

Options:
  -h, --help      Show this help message

Description:
  Lists all dotfiles currently managed by dots, grouped by section.

Output format:
  [section]
    filename -> target_path
EOF
}

cmd_list() {
    # 設定ファイルを解析
    parse_config || return 1
    
    if [[ ${#DOTS_ENTRIES[@]} -eq 0 ]]; then
        dots_info "No dotfiles are currently managed."
        dots_info "Use 'dots join' to add files to management."
        return 0
    fi
    
    local current_section=""
    
    for section in "${DOTS_SECTIONS[@]}"; do
        echo "[${section}]"
        
        for entry in "${DOTS_ENTRIES[@]}"; do
            local entry_section=$(get_entry_section "$entry")
            
            if [[ "$entry_section" == "$section" ]]; then
                local filename=$(get_entry_filename "$entry")
                local target=$(get_entry_target "$entry")
                echo "  ${filename} -> ${target}"
            fi
        done
        
        echo ""
    done
    
    return 0
}
