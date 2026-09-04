#!/usr/bin/env zsh
# dots.conf のパース／書き換え関数の回帰テスト
#
# 実行方法: zsh tests/run_tests.zsh

SCRIPT_DIR="${0:A:h}"
REPO_DIR="${SCRIPT_DIR:h}"

DOTS_DIR="$REPO_DIR"
source "${REPO_DIR}/bin/utils.zsh"

TESTS_RUN=0
TESTS_FAILED=0
TMP_TEST_DIR=""

assert_eq() {
    local actual="$1"
    local expected="$2"
    local message="$3"

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$actual" != "$expected" ]]; then
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "FAIL: ${message}"
        echo "  expected: ${expected}"
        echo "  actual:   ${actual}"
    fi
}

# 一時ディレクトリに dots.conf を作成し、DOTS_CONFIG をそこに切り替える
with_tmp_config() {
    local content="$1"
    TMP_TEST_DIR="$(mktemp -d)"
    DOTS_CONFIG="${TMP_TEST_DIR}/dots.conf"
    print -r -- "$content" > "$DOTS_CONFIG"
}

cleanup_tmp_config() {
    [[ -n "$TMP_TEST_DIR" && -d "$TMP_TEST_DIR" ]] && rm -rf "$TMP_TEST_DIR"
    TMP_TEST_DIR=""
}

# --- parse_config ---

test_parse_config_basic() {
    with_tmp_config "$(cat <<'EOF'
[zsh]
.zshrc = ~/.zshrc

[ghostty]
config = ~/.config/ghostty/config
EOF
)"

    parse_config
    assert_eq "${#DOTS_SECTIONS[@]}" "2" "parse_config: セクション数"
    assert_eq "${DOTS_SECTIONS[1]}" "zsh" "parse_config: 1つ目のセクション名"
    assert_eq "${DOTS_SECTIONS[2]}" "ghostty" "parse_config: 2つ目のセクション名"
    assert_eq "${#DOTS_ENTRIES[@]}" "2" "parse_config: エントリ数"
    assert_eq "$(get_entry_section "${DOTS_ENTRIES[1]}")" "zsh" "parse_config: エントリ1のセクション"
    assert_eq "$(get_entry_filename "${DOTS_ENTRIES[1]}")" ".zshrc" "parse_config: エントリ1のファイル名"
    assert_eq "$(get_entry_target "${DOTS_ENTRIES[1]}")" "~/.zshrc" "parse_config: エントリ1のターゲット"
    assert_eq "$(get_entry_mode "${DOTS_ENTRIES[1]}")" "symlink" "parse_config: mode 省略時は symlink"

    cleanup_tmp_config
}

test_parse_config_mode_attribute() {
    with_tmp_config "$(cat <<'EOF'
[karabiner]
karabiner.json = ~/.config/karabiner/karabiner.json ; mode=copy
EOF
)"

    parse_config
    assert_eq "${#DOTS_ENTRIES[@]}" "1" "parse_config: mode 属性付きエントリ数"
    assert_eq "$(get_entry_filename "${DOTS_ENTRIES[1]}")" "karabiner.json" "parse_config: mode 属性付きファイル名"
    assert_eq "$(get_entry_target "${DOTS_ENTRIES[1]}")" "~/.config/karabiner/karabiner.json" "parse_config: mode 属性を除いたターゲット"
    assert_eq "$(get_entry_mode "${DOTS_ENTRIES[1]}")" "copy" "parse_config: mode=copy を認識する"

    cleanup_tmp_config
}

test_parse_config_ignores_comments_and_blank_lines() {
    with_tmp_config "$(cat <<'EOF'
# これはコメント
[zsh]
# コメント2
.zshrc = ~/.zshrc

EOF
)"

    parse_config
    assert_eq "${#DOTS_ENTRIES[@]}" "1" "parse_config: コメント/空行を無視"

    cleanup_tmp_config
}

# --- add_config_entry ---

test_add_config_entry_new_section() {
    with_tmp_config "$(cat <<'EOF'
[zsh]
.zshrc = ~/.zshrc
EOF
)"

    add_config_entry "vim" ".vimrc" "~/.vimrc"
    parse_config
    assert_eq "${#DOTS_SECTIONS[@]}" "2" "add_config_entry: 新セクション追加後のセクション数"
    assert_eq "${DOTS_SECTIONS[2]}" "vim" "add_config_entry: 新セクション名"
    assert_eq "${#DOTS_ENTRIES[@]}" "2" "add_config_entry: 新セクション追加後のエントリ数"

    cleanup_tmp_config
}

test_add_config_entry_appends_after_last_entry() {
    with_tmp_config "$(cat <<'EOF'
[zsh]
.zshrc = ~/.zshrc

[ghostty]
config = ~/.config/ghostty/config
EOF
)"

    # 同一セクションに3回連続で追加しても、エントリが連続した行として並び、
    # セクション間の空行が増減しないことを確認する（P1-2 の回帰テスト）
    add_config_entry "zsh" ".zprofile" "~/.zprofile"
    add_config_entry "zsh" ".zshenv" "~/.zshenv"
    add_config_entry "zsh" ".aliases" "~/.aliases"

    local expected
    expected=$(cat <<'EOF'
[zsh]
.zshrc = ~/.zshrc
.zprofile = ~/.zprofile
.zshenv = ~/.zshenv
.aliases = ~/.aliases

[ghostty]
config = ~/.config/ghostty/config
EOF
)

    assert_eq "$(<"$DOTS_CONFIG")" "$expected" "add_config_entry: 3回連続実行でエントリが連続して並び、空行が増減しない"

    cleanup_tmp_config
}

test_add_config_entry_with_mode() {
    with_tmp_config "$(cat <<'EOF'
[karabiner]
EOF
)"

    add_config_entry "karabiner" "karabiner.json" "~/.config/karabiner/karabiner.json" "copy"
    parse_config
    assert_eq "$(get_entry_mode "${DOTS_ENTRIES[1]}")" "copy" "add_config_entry: mode=copy を書き込める"

    local expected
    expected=$(cat <<'EOF'
[karabiner]
karabiner.json = ~/.config/karabiner/karabiner.json ; mode=copy
EOF
)
    assert_eq "$(<"$DOTS_CONFIG")" "$expected" "add_config_entry: mode=copy のとき ; mode=copy を追記する"

    cleanup_tmp_config
}

test_add_config_entry_empty_section() {
    with_tmp_config "$(cat <<'EOF'
[zsh]

[ghostty]
config = ~/.config/ghostty/config
EOF
)"

    add_config_entry "zsh" ".zshrc" "~/.zshrc"
    parse_config
    assert_eq "${#DOTS_ENTRIES[@]}" "2" "add_config_entry: エントリが無いセクションへの追加"
    assert_eq "$(get_entry_filename "${DOTS_ENTRIES[1]}")" ".zshrc" "add_config_entry: エントリが無いセクションへの追加内容"

    cleanup_tmp_config
}

# --- remove_config_entry / cleanup_empty_sections ---

test_remove_config_entry() {
    with_tmp_config "$(cat <<'EOF'
[zsh]
.zshrc = ~/.zshrc
.zprofile = ~/.zprofile

[ghostty]
config = ~/.config/ghostty/config
EOF
)"

    remove_config_entry "zsh" ".zshrc"
    parse_config
    assert_eq "${#DOTS_ENTRIES[@]}" "2" "remove_config_entry: 削除後のエントリ数"
    assert_eq "${#DOTS_SECTIONS[@]}" "2" "remove_config_entry: セクションは残る（他にエントリがあるため）"

    cleanup_tmp_config
}

test_remove_config_entry_cleans_up_empty_section() {
    with_tmp_config "$(cat <<'EOF'
[zsh]
.zshrc = ~/.zshrc

[ghostty]
config = ~/.config/ghostty/config
EOF
)"

    remove_config_entry "zsh" ".zshrc"
    parse_config
    assert_eq "${#DOTS_ENTRIES[@]}" "1" "remove_config_entry: 空セクション化後のエントリ数"

    local has_zsh=0
    for s in "${DOTS_SECTIONS[@]}"; do
        [[ "$s" == "zsh" ]] && has_zsh=1
    done
    assert_eq "$has_zsh" "0" "remove_config_entry: 空になったセクションは cleanup で消える"

    cleanup_tmp_config
}

test_cleanup_empty_sections_keeps_non_empty() {
    with_tmp_config "$(cat <<'EOF'
[empty]

[zsh]
.zshrc = ~/.zshrc
EOF
)"

    cleanup_empty_sections
    parse_config
    assert_eq "${#DOTS_SECTIONS[@]}" "1" "cleanup_empty_sections: 空セクションのみ削除される"
    assert_eq "${DOTS_SECTIONS[1]}" "zsh" "cleanup_empty_sections: 非空セクションは残る"

    cleanup_tmp_config
}

# --- 実行 ---

test_parse_config_basic
test_parse_config_ignores_comments_and_blank_lines
test_parse_config_mode_attribute
test_add_config_entry_new_section
test_add_config_entry_appends_after_last_entry
test_add_config_entry_with_mode
test_add_config_entry_empty_section
test_remove_config_entry
test_remove_config_entry_cleans_up_empty_section
test_cleanup_empty_sections_keeps_non_empty

echo ""
echo "---"
echo "${TESTS_RUN} tests run, $((TESTS_RUN - TESTS_FAILED)) passed, ${TESTS_FAILED} failed"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
