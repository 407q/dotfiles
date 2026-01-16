#!/usr/bin/env zsh
# dots - leave.zsh
# dotfile を管理対象から除外

show_leave_help() {
    cat << 'EOF'
dots leave - Remove a file from management

Usage: dots leave <name> <file>

Arguments:
  name            Group name (directory name in repository)
  file            Filename in repository

Options:
  -h, --help      Show this help message

Description:
  Removes the file from dotfiles management.
  The symlink at the target location is removed and the file
  from the repository is moved back to the original location.

Examples:
  dots leave zsh .zshrc
EOF
}

cmd_leave() {
    local group_name=""
    local filename=""
    
    # 引数解析
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -*)
                dots_error "Unknown option: $1"
                show_leave_help
                return 2
                ;;
            *)
                if [[ -z "$group_name" ]]; then
                    group_name="$1"
                elif [[ -z "$filename" ]]; then
                    filename="$1"
                else
                    dots_error "Too many arguments."
                    show_leave_help
                    return 2
                fi
                shift
                ;;
        esac
    done
    
    # 必須引数の確認
    if [[ -z "$group_name" ]]; then
        dots_error "Missing required argument: name"
        show_leave_help
        return 2
    fi
    
    if [[ -z "$filename" ]]; then
        dots_error "Missing required argument: file"
        show_leave_help
        return 2
    fi
    
    # 設定ファイルを解析
    parse_config || return 1
    
    # エントリを検索
    local found_entry=""
    local target_path=""
    
    for entry in "${DOTS_ENTRIES[@]}"; do
        local entry_section=$(get_entry_section "$entry")
        local entry_filename=$(get_entry_filename "$entry")
        
        if [[ "$entry_section" == "$group_name" && "$entry_filename" == "$filename" ]]; then
            found_entry="$entry"
            target_path=$(get_entry_target "$entry")
            break
        fi
    done
    
    if [[ -z "$found_entry" ]]; then
        dots_error "Entry not found: [${group_name}] ${filename}"
        return 1
    fi
    
    # リポジトリ内のファイルパス
    local repo_file="${DOTS_DIR}/${group_name}/${filename}"
    local expanded_target=$(expand_path "$target_path")
    
    # リポジトリ内のファイルが存在するか確認
    if [[ ! -e "$repo_file" ]]; then
        dots_error "Repository file not found: ${group_name}/${filename}"
        return 3
    fi
    
    # 確認プロンプト
    echo ""
    echo "Remove '${group_name}/${filename}' from management?"
    echo "The file will be restored to: $(shorten_path "$expanded_target")"
    echo ""
    
    if ! confirm "Continue?"; then
        dots_info "Cancelled."
        return 0
    fi
    
    # ターゲットがシンボリックリンクの場合は削除
    if [[ -L "$expanded_target" ]]; then
        rm "$expanded_target"
        dots_delete "Removed symlink: $(shorten_path "$expanded_target")"
    elif [[ -e "$expanded_target" ]]; then
        # ターゲットに別のファイルがある場合
        dots_warning "Target already exists and is not a symlink: $(shorten_path "$expanded_target")"
        
        if confirm "Overwrite?"; then
            rm -rf "$expanded_target"
            dots_delete "Removed: $(shorten_path "$expanded_target")"
        else
            dots_info "Cancelled."
            return 0
        fi
    fi
    
    # ターゲットの親ディレクトリを作成
    local target_dir="${expanded_target:h}"
    if [[ ! -d "$target_dir" ]]; then
        dots_folder "Created directory: $(shorten_path "$target_dir")"
        mkdir -p "$target_dir"
    fi
    
    # リポジトリのファイルをターゲットに移動
    mv "$repo_file" "$expanded_target"
    dots_success "Restored: ${group_name}/${filename} -> $(shorten_path "$expanded_target")"
    
    # 設定ファイルからエントリを削除
    remove_config_entry "$group_name" "$filename"
    dots_edit "Removed from config: [${group_name}] ${filename}"
    
    # グループディレクトリが空になった場合は削除
    local group_dir="${DOTS_DIR}/${group_name}"
    if [[ -d "$group_dir" ]] && [[ -z "$(ls -A "$group_dir")" ]]; then
        rmdir "$group_dir"
        dots_delete "Removed empty directory: ${group_name}/"
    fi
    
    dots_success "File removed from management!"
    
    return 0
}
