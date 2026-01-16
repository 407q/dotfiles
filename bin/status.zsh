#!/usr/bin/env zsh
# dots - status.zsh
# シンボリックリンクの状態を確認

show_status_help() {
    cat << 'EOF'
dots status - Check symlink status

Usage: dots status [options]

Options:
  -h, --help      Show this help message

Description:
  Checks the status of all managed dotfiles and their symlinks.

Status indicators:
  ✅  Linked correctly
  ❌  Missing link or broken link
  ⚠️   Conflict (regular file exists at target)
EOF
}

cmd_status() {
    # 設定ファイルを解析
    parse_config || return 1
    
    if [[ ${#DOTS_ENTRIES[@]} -eq 0 ]]; then
        dots_info "No dotfiles are currently managed."
        dots_info "Use 'dots join' to add files to management."
        return 0
    fi
    
    local ok_count=0
    local missing_count=0
    local conflict_count=0
    
    for section in "${DOTS_SECTIONS[@]}"; do
        echo "[${section}]"
        
        for entry in "${DOTS_ENTRIES[@]}"; do
            local entry_section=$(get_entry_section "$entry")
            
            if [[ "$entry_section" == "$section" ]]; then
                local filename=$(get_entry_filename "$entry")
                local target=$(get_entry_target "$entry")
                local expanded_target=$(expand_path "$target")
                local repo_file="${DOTS_DIR}/${section}/${filename}"
                
                local status_icon=""
                local status_msg=""
                
                if [[ -L "$expanded_target" ]]; then
                    # シンボリックリンクが存在
                    local link_target=$(readlink "$expanded_target")
                    
                    if [[ "$link_target" == "$repo_file" ]]; then
                        # 正しくリンクされている
                        status_icon="✅"
                        ok_count=$((ok_count + 1))
                    elif [[ -e "$expanded_target" ]]; then
                        # 別のファイルにリンクされている
                        status_icon="⚠️"
                        status_msg=" (linked to: ${link_target})"
                        conflict_count=$((conflict_count + 1))
                    else
                        # リンク先が存在しない（壊れたリンク）
                        status_icon="❌"
                        status_msg=" (broken link)"
                        missing_count=$((missing_count + 1))
                    fi
                elif [[ -e "$expanded_target" ]]; then
                    # 通常ファイルが存在（競合）
                    status_icon="⚠️"
                    status_msg=" (conflict: regular file exists)"
                    conflict_count=$((conflict_count + 1))
                else
                    # ファイルが存在しない
                    status_icon="❌"
                    status_msg=" (missing link)"
                    missing_count=$((missing_count + 1))
                fi
                
                # リポジトリ内のファイルも確認
                if [[ ! -e "$repo_file" ]]; then
                    status_icon="❌"
                    status_msg=" (source missing: ${section}/${filename})"
                    missing_count=$((missing_count + 1))
                fi
                
                echo "  ${status_icon} ${filename} -> ${target}${status_msg}"
            fi
        done
        
        echo ""
    done
    
    # サマリー
    echo "---"
    echo "Summary: ✅ ${ok_count} linked, ❌ ${missing_count} missing, ⚠️ ${conflict_count} conflicts"
    
    if [[ $missing_count -gt 0 || $conflict_count -gt 0 ]]; then
        echo ""
        dots_info "Run 'dots deploy' to fix missing links."
    fi
    
    return 0
}
