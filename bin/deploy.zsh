#!/usr/bin/env zsh
# dots - deploy.zsh
# dotfiles をシンボリックリンクとして展開

show_deploy_help() {
    cat << 'EOF'
dots deploy - Deploy dotfiles as symlinks

Usage: dots deploy [options]

Options:
  -h, --help      Show this help message

Description:
  Reads dots.conf and creates symbolic links from target locations
  to the corresponding files in the dotfiles repository.

  When a target file already exists, you will be prompted to:
    [1] Backup target and overwrite with repository file (default)
    [2] Overwrite target with repository file
    [3] Overwrite repository file with current target
    [4] Skip this file
EOF
}

cmd_deploy() {
    # 設定ファイルを解析
    parse_config || return 1
    
    if [[ ${#DOTS_ENTRIES[@]} -eq 0 ]]; then
        dots_warning "No entries found in config file."
        dots_info "Use 'dots join' to add files to management."
        return 0
    fi
    
    local success_count=0
    local skip_count=0
    local error_count=0
    
    dots_info "Deploying dotfiles..."
    echo ""
    
    for entry in "${DOTS_ENTRIES[@]}"; do
        local section=$(get_entry_section "$entry")
        local filename=$(get_entry_filename "$entry")
        local target=$(get_entry_target "$entry")
        
        # パスを展開
        local expanded_target=$(expand_path "$target")
        local repo_file="${DOTS_DIR}/${section}/${filename}"
        
        # リポジトリ内のファイルが存在するか確認
        if [[ ! -e "$repo_file" ]]; then
            dots_error "Source file not found: ${section}/${filename}"
            error_count=$((error_count + 1))
            continue
        fi

        # ターゲットがリポジトリファイルそのものを指す場合は、そのまま管理対象として扱う
        if [[ "${expanded_target:A}" == "${repo_file:A}" ]]; then
            dots_success "${section}/${filename} -> $(shorten_path "$expanded_target") (managed in repository path)"
            success_count=$((success_count + 1))
            continue
        fi
        
        # ターゲットの親ディレクトリを作成
        local target_dir="${expanded_target:h}"
        if [[ ! -d "$target_dir" ]]; then
            dots_folder "Created directory: $(shorten_path "$target_dir")"
            mkdir -p "$target_dir"
        fi
        
        # ターゲットが既に存在する場合
        if [[ -e "$expanded_target" || -L "$expanded_target" ]]; then
            # 既に正しいシンボリックリンクの場合はスキップ
            if [[ -L "$expanded_target" ]]; then
                local current_link=$(readlink "$expanded_target")
                if [[ "$current_link" == "$repo_file" ]]; then
                    dots_success "${section}/${filename} -> $(shorten_path "$expanded_target") (already linked)"
                    success_count=$((success_count + 1))
                    continue
                fi
            fi
            
            # 競合処理
            local choice=$(prompt_conflict "$expanded_target" "$repo_file")
            
            case "$choice" in
                overwrite)
                    rm -rf "$expanded_target"
                    dots_delete "Removed: $(shorten_path "$expanded_target")"
                    ;;
                overwrite_repo)
                    rm -rf "$repo_file"
                    if cp -RL "$expanded_target" "$repo_file"; then
                        dots_edit "Updated repository file: ${section}/${filename} from $(shorten_path "$expanded_target")"
                        rm -rf "$expanded_target"
                        dots_delete "Removed: $(shorten_path "$expanded_target")"
                    else
                        dots_error "Failed to update repository file from: $(shorten_path "$expanded_target")"
                        error_count=$((error_count + 1))
                        continue
                    fi
                    ;;
                skip)
                    dots_warning "Skipped: ${section}/${filename}"
                    skip_count=$((skip_count + 1))
                    continue
                    ;;
                backup_overwrite)
                    local backup_name=$(generate_backup_name "$expanded_target")
                    mv "$expanded_target" "$backup_name"
                    dots_backup "Backup created: $(shorten_path "$backup_name")"
                    ;;
                *)
                    dots_error "Invalid conflict choice for: $(shorten_path "$expanded_target")"
                    error_count=$((error_count + 1))
                    continue
                    ;;
            esac
        fi
        
        # シンボリックリンクを作成
        if ln -s "$repo_file" "$expanded_target"; then
            dots_link "Created symlink: $(shorten_path "$expanded_target") -> ${section}/${filename}"
            success_count=$((success_count + 1))
        else
            dots_error "Failed to create symlink: $(shorten_path "$expanded_target")"
            error_count=$((error_count + 1))
        fi
    done
    
    echo ""
    dots_success "Deploy completed!"
    echo "  Success: ${success_count}, Skipped: ${skip_count}, Errors: ${error_count}"
    
    if [[ $error_count -gt 0 ]]; then
        return 3
    fi
    
    return 0
}
