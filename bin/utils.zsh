#!/usr/bin/env zsh
# dots - utils.zsh
# 共通ユーティリティ関数

# バージョン
DOTS_VERSION="260116"

# Emoji定義
EMOJI_SUCCESS="✅"
EMOJI_ERROR="❌"
EMOJI_WARNING="⚠️"
EMOJI_FOLDER="📁"
EMOJI_LINK="🔗"
EMOJI_EDIT="📝"
EMOJI_BACKUP="💾"
EMOJI_DELETE="🗑️"
EMOJI_INFO="ℹ️"

# DOTS_DIR の設定（未設定の場合はスクリプトの親ディレクトリ）
if [[ -z "$DOTS_DIR" ]]; then
    DOTS_DIR="${0:A:h:h}"
fi

# 設定ファイルのパス
DOTS_CONFIG="${DOTS_CONFIG:-$DOTS_DIR/dots.conf}"

# --- メッセージ出力関数 ---

dots_info() {
    echo "${EMOJI_INFO} $1"
}

dots_success() {
    echo "${EMOJI_SUCCESS} $1"
}

dots_error() {
    echo "${EMOJI_ERROR} $1" >&2
}

dots_warning() {
    echo "${EMOJI_WARNING} $1"
}

dots_link() {
    echo "${EMOJI_LINK} $1"
}

dots_folder() {
    echo "${EMOJI_FOLDER} $1"
}

dots_edit() {
    echo "${EMOJI_EDIT} $1"
}

dots_backup() {
    echo "${EMOJI_BACKUP} $1"
}

dots_delete() {
    echo "${EMOJI_DELETE} $1"
}

# --- パス展開関数 ---

# ~ と環境変数を展開
expand_path() {
    local path="$1"
    # ~ をホームディレクトリに展開
    path="${path/#\~/$HOME}"
    # 環境変数を展開（グロブ展開を無効化し、スペースを保持）
    setopt local_options noglob
    eval "print -r -- \"$path\""
}

# パスを正規化（表示用）
# ホームディレクトリ以下は ~/... 形式、それ以外は絶対パス
shorten_path() {
    local path="$1"
    # 絶対パスに変換
    if [[ "$path" != /* ]]; then
        path="${path:A}"
    fi
    # ホームディレクトリ以下なら ~ 表記に置き換え
    echo "${path/#$HOME/~}"
}

# --- 設定ファイルパーサー ---

# dots.conf が存在するか確認
check_config_exists() {
    if [[ ! -f "$DOTS_CONFIG" ]]; then
        dots_error "Config file not found: $DOTS_CONFIG"
        dots_info "Run 'dots init' to create a new configuration file."
        return 1
    fi
    return 0
}

# dots.conf を解析して配列に格納
# 使用法: parse_config を呼び出すと、以下のグローバル配列が設定される
#   DOTS_SECTIONS: セクション名の配列
#   DOTS_ENTRIES: "section|filename|target" 形式のエントリ配列
parse_config() {
    check_config_exists || return 1
    
    DOTS_SECTIONS=()
    DOTS_ENTRIES=()
    
    local current_section=""
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # 空行とコメントをスキップ
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # 前後の空白を除去
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        
        # セクションヘッダー [name]
        if [[ "$line" == \[*\] ]]; then
            # [ と ] を除去してセクション名を取得
            current_section="${line#\[}"
            current_section="${current_section%\]}"
            # セクションが未登録なら追加
            if [[ ! " ${DOTS_SECTIONS[*]} " =~ " ${current_section} " ]]; then
                DOTS_SECTIONS+=("$current_section")
            fi
            continue
        fi
        
        # エントリ: filename = target
        if [[ "$line" == *=* ]]; then
            local filename="${line%%=*}"
            local target="${line#*=}"
            
            # 前後の空白を除去
            filename="${filename#"${filename%%[![:space:]]*}"}"
            filename="${filename%"${filename##*[![:space:]]}"}"
            target="${target#"${target%%[![:space:]]*}"}"
            target="${target%"${target##*[![:space:]]}"}"
            
            if [[ -n "$current_section" ]]; then
                DOTS_ENTRIES+=("${current_section}|${filename}|${target}")
            fi
        fi
    done < "$DOTS_CONFIG"
    
    return 0
}

# 特定セクションのエントリを取得
get_section_entries() {
    local section="$1"
    local entries=()
    
    for entry in "${DOTS_ENTRIES[@]}"; do
        if [[ "$entry" == "${section}|"* ]]; then
            entries+=("$entry")
        fi
    done
    
    echo "${entries[@]}"
}

# エントリからファイル名を取得
get_entry_filename() {
    local entry="$1"
    echo "${entry#*|}" | cut -d'|' -f1
}

# エントリからターゲットパスを取得
get_entry_target() {
    local entry="$1"
    echo "${entry##*|}"
}

# エントリからセクション名を取得
get_entry_section() {
    local entry="$1"
    echo "${entry%%|*}"
}

# --- 設定ファイル書き込み ---

# エントリを追加
add_config_entry() {
    local section="$1"
    local filename="$2"
    local target="$3"
    
    # セクションが存在するか確認
    if grep -q "^\[${section}\]" "$DOTS_CONFIG" 2>/dev/null; then
        # セクション内の最後に追加
        # 次のセクションまたはファイル末尾を探す
        local temp_file=$(mktemp)
        local in_section=0
        local added=0
        
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" == \[${section}\] ]]; then
                in_section=1
                echo "$line" >> "$temp_file"
                continue
            fi
            
            if [[ $in_section -eq 1 && "$line" == \[*\] ]]; then
                # 次のセクションに到達、その前にエントリを追加
                if [[ $added -eq 0 ]]; then
                    echo "${filename} = ${target}" >> "$temp_file"
                    added=1
                fi
                in_section=0
            fi
            
            echo "$line" >> "$temp_file"
        done < "$DOTS_CONFIG"
        
        # ファイル末尾で追加されていない場合
        if [[ $added -eq 0 ]]; then
            echo "${filename} = ${target}" >> "$temp_file"
        fi
        
        mv "$temp_file" "$DOTS_CONFIG"
    else
        # 新しいセクションを追加
        echo "" >> "$DOTS_CONFIG"
        echo "[${section}]" >> "$DOTS_CONFIG"
        echo "${filename} = ${target}" >> "$DOTS_CONFIG"
    fi
}

# エントリを削除
remove_config_entry() {
    local section="$1"
    local filename="$2"
    
    local temp_file=$(mktemp)
    local in_section=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == \[${section}\] ]]; then
            in_section=1
            echo "$line" >> "$temp_file"
            continue
        fi
        
        if [[ "$line" == \[*\] ]]; then
            in_section=0
        fi
        
        if [[ $in_section -eq 1 ]]; then
            # このセクション内のエントリをチェック
            local entry_filename=""
            if [[ "$line" == *=* ]]; then
                entry_filename="${line%%=*}"
                entry_filename="${entry_filename#"${entry_filename%%[![:space:]]*}"}"
                entry_filename="${entry_filename%"${entry_filename##*[![:space:]]}"}"
            fi
            
            if [[ "$entry_filename" == "$filename" ]]; then
                # このエントリをスキップ（削除）
                continue
            fi
        fi
        
        echo "$line" >> "$temp_file"
    done < "$DOTS_CONFIG"
    
    mv "$temp_file" "$DOTS_CONFIG"
    
    # 空セクションをクリーンアップ
    cleanup_empty_sections
}

# 空のセクションを削除
cleanup_empty_sections() {
    local temp_file=$(mktemp)
    local current_section=""
    local section_content=""
    local has_entries=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == \[*\] ]]; then
            # 前のセクションを処理
            if [[ -n "$current_section" ]]; then
                if [[ $has_entries -eq 1 ]]; then
                    echo "$current_section" >> "$temp_file"
                    echo -n "$section_content" >> "$temp_file"
                fi
            fi
            
            # 新しいセクション開始
            current_section="$line"
            section_content=""
            has_entries=0
            continue
        fi
        
        if [[ -n "$current_section" ]]; then
            section_content+="$line"$'\n'
            # エントリ（= を含む行）があるか確認
            if [[ "$line" == *=* ]]; then
                has_entries=1
            fi
        else
            # セクション外の行はそのまま出力
            echo "$line" >> "$temp_file"
        fi
    done < "$DOTS_CONFIG"
    
    # 最後のセクションを処理
    if [[ -n "$current_section" && $has_entries -eq 1 ]]; then
        echo "$current_section" >> "$temp_file"
        echo -n "$section_content" >> "$temp_file"
    fi
    
    mv "$temp_file" "$DOTS_CONFIG"
}

# エントリのファイル名を変更
update_config_entry_filename() {
    local section="$1"
    local old_filename="$2"
    local new_filename="$3"
    
    local temp_file=$(mktemp)
    local in_section=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == \[${section}\] ]]; then
            in_section=1
            echo "$line" >> "$temp_file"
            continue
        fi
        
        if [[ "$line" == \[*\] ]]; then
            in_section=0
        fi
        
        if [[ $in_section -eq 1 && "$line" == *=* ]]; then
            local entry_filename="${line%%=*}"
            local entry_target="${line#*=}"
            entry_filename="${entry_filename#"${entry_filename%%[![:space:]]*}"}"
            entry_filename="${entry_filename%"${entry_filename##*[![:space:]]}"}"
            
            if [[ "$entry_filename" == "$old_filename" ]]; then
                echo "${new_filename} =${entry_target}" >> "$temp_file"
                continue
            fi
        fi
        
        echo "$line" >> "$temp_file"
    done < "$DOTS_CONFIG"
    
    mv "$temp_file" "$DOTS_CONFIG"
}

# --- ファイル操作ヘルパー ---

# ファイル内容をプレビュー表示
preview_file() {
    local file="$1"
    local label="$2"
    local max_lines="${3:-20}"
    
    echo "--- ${label} ---"
    if [[ -f "$file" ]]; then
        head -n "$max_lines" "$file"
        local total_lines=$(wc -l < "$file")
        if [[ $total_lines -gt $max_lines ]]; then
            echo "... ($((total_lines - max_lines)) more lines)"
        fi
    else
        echo "(file does not exist)"
    fi
    echo "---"
}

# バックアップファイル名を生成
generate_backup_name() {
    local file="$1"
    local timestamp=$(date +"%y%m%d_%H%M%S")
    echo "${file}.bak.${timestamp}"
}

# 確認プロンプト
confirm() {
    local message="$1"
    local response
    
    echo -n "$message [y/n]: "
    read -r response
    
    [[ "$response" =~ ^[Yy]$ ]]
}

# 4択プロンプト（Backup+Overwrite/Overwrite/OverwriteRepo/Skip）
prompt_conflict() {
    local existing_file="$1"
    local repo_file="$2"
    local response
    
    echo "" >&2
    echo "${EMOJI_WARNING} File already exists: $(shorten_path "$existing_file")" >&2
    echo "" >&2
    
    preview_file "$existing_file" "Existing file content" >&2
    echo "" >&2
    preview_file "$repo_file" "Repository file content" >&2
    echo "" >&2
    
    echo "[1] Backup target and overwrite with repository file (default)" >&2
    echo "[2] Overwrite target with repository file" >&2
    echo "[3] Overwrite repository file with current target" >&2
    echo "[4] Skip this file" >&2
    echo "    Backup path: ${existing_file}.bak.YYMMDD_HHMMSS" >&2
    echo "" >&2
    
    while true; do
        echo -n "Choice [1/2/3/4] (default: 1): " >&2
        read -r response
        [[ -z "$response" ]] && response="1"
        
        case "$response" in
            1|b|B) echo "backup_overwrite"; return ;;
            2|o|O) echo "overwrite"; return ;;
            3|r|R) echo "overwrite_repo"; return ;;
            4|s|S) echo "skip"; return ;;
            *) echo "Invalid choice. Please enter 1, 2, 3, or 4." >&2 ;;
        esac
    done
}
