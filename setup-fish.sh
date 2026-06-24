#!/usr/bin/env bash
# ============================================================
# Fish Shell + MSYS2 설치 스크립트 (Windows)
# ============================================================
#
# 사용법:
#   1. Git-Bash (관리자 권한) 또는 PowerShell을 연다
#   2. bash setup-fish.sh
#
# 동작:
#   1. MSYS2 설치 (없으면 자동 다운로드 + 설치)
#   2. MSYS2 패키지 업데이트
#   3. fish shell 설치 (pacman -S fish)
#   4. HOME 디렉토리를 Windows 사용자 폴더(C:\Users\누구)로 설정
#      - /etc/nsswitch.conf의 db_home 값을 windows로 변경
#      - 안 하면 cd ~가 /home/누구 로 감
#   5. fish 설정파일(~/.config/fish/config.fish) 생성
#   6. Windows Terminal 프로필에 fish 추가 (선택)
#   7. 설치 확인
#
# 사용:
#   - Windows Terminal 실행 → "fish" 탭 선택
#   - 또는 직접 C:\msys64\usr\bin\fish.exe 실행
#
# 효과:
#   - Windows에 설치한 모든 프로그램(fzf, node, nvim, git 등)을
#     fish shell 안에서 그대로 사용 가능
# ============================================================

set -euo pipefail

# ─── 색상 출력 ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $1"; exit 1; }

# ─── 경로 설정 ──────────────────────────────────────────────
MSYS2_ROOT="${MSYS2_ROOT:-C:/msys64}"
MSYS2_BASH="$MSYS2_ROOT/usr/bin/bash.exe"
MSYS2_FISH="$MSYS2_ROOT/usr/bin/fish.exe"
MSYS2_INSTALLER_URL="https://github.com/msys2/msys2-installer/releases/download/2026-06-11/msys2-x86_64-20260611.exe"

# ─── 1. MSYS2 설치 ──────────────────────────────────────────
install_msys2() {
    echo ""
    echo "============================================"
    echo " 1. MSYS2 설치"
    echo "============================================"

    if [ -f "$MSYS2_BASH" ]; then
        ok "MSYS2가 이미 설치되어 있음: $MSYS2_ROOT"
        return 0
    fi

    log "MSYS2를 찾을 수 없음. 다운로드 + 설치를 시작합니다..."
    log "설치 경로: $MSYS2_ROOT"

    local tmp_dir="/tmp/msys2-installer"
    mkdir -p "$tmp_dir"
    local installer_exe="$tmp_dir/msys2-installer.exe"

    if [ ! -f "$installer_exe" ]; then
        log "MSYS2 인스톨러 다운로드 중..."
        # PowerShell로 다운로드 (git-bash의 curl보다 안정적)
        powershell.exe -Command "
            \$url = '$MSYS2_INSTALLER_URL';
            \$out = '$installer_exe';
            Write-Host 'Downloading...';
            Invoke-WebRequest -Uri \$url -OutFile \$out -UseBasicParsing;
        " || {
            log "PowerShell 다운로드 실패, curl로 재시도..."
            curl -L -o "$installer_exe" "$MSYS2_INSTALLER_URL"
        }
        ok "다운로드 완료"
    else
        ok "인스톨러 캐시 있음: $installer_exe"
    fi

    # MSYS2 무음 설치
    log "MSYS2 설치 중 (약 2~3분 소요)..."
    "$installer_exe" in --confirm-command --accept-messages --root "$MSYS2_ROOT"
    if [ $? -eq 0 ]; then
        ok "MSYS2 설치 완료"
    else
        fail "MSYS2 설치 실패 (exit code: $?)"
    fi
}

# ─── 2. MSYS2 업데이트 ──────────────────────────────────────
update_msys2() {
    echo ""
    echo "============================================"
    echo " 2. MSYS2 패키지 업데이트"
    echo "============================================"

    log "MSYS2 패키지 데이터베이스 동기화 + 업그레이드..."
    "$MSYS2_BASH" --login -c "pacman -Syu --noconfirm"
    if [ $? -eq 0 ]; then
        ok "MSYS2 패키지 업데이트 완료"
    else
        warn "업데이트 중 일부 패키지 실패 (무시 가능)"
    fi
}

# ─── 3. fish shell 설치 ─────────────────────────────────────
install_fish() {
    echo ""
    echo "============================================"
    echo " 3. Fish Shell 설치"
    echo "============================================"

    if [ -f "$MSYS2_FISH" ]; then
        local version
        version=$("$MSYS2_FISH" --version 2>/dev/null)
        ok "Fish가 이미 설치되어 있음: $version"
        return 0
    fi

    log "fish shell 설치 중..."
    "$MSYS2_BASH" --login -c "pacman -S fish --noconfirm"
    if [ $? -eq 0 ]; then
        local version
        version=$("$MSYS2_FISH" --version 2>/dev/null)
        ok "Fish 설치 완료: $version"
    else
        fail "Fish 설치 실패"
    fi
}

# ─── 4. HOME 디렉토리 설정 ──────────────────────────────────
setup_home_dir() {
    echo ""
    echo "============================================"
    echo " 4. HOME 디렉토리 Windows 폴더로 설정"
    echo "============================================"

    local nsswitch="$MSYS2_ROOT/etc/nsswitch.conf"

    if [ ! -f "$nsswitch" ]; then
        warn "nsswitch.conf 파일 없음: $nsswitch"
        return 0
    fi

    local current
    current=$(grep "^db_home:" "$nsswitch" 2>/dev/null || echo "")

    if echo "$current" | grep -q "windows"; then
        ok "이미 Windows 홈 디렉토리로 설정됨"
        return 0
    fi

    # 백업 후 변경
    local backup="$nsswitch.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$nsswitch" "$backup"
    log "백업 생성: $backup"

    # db_home: cygwin desc → db_home: windows
    #   cygwin:   /home/username  (MSYS2 기본, cd ~ 하면 /home/누구)
    #   windows:  C:\Users\username (Windows 홈, git-bash와 동일)
    sed -i 's/^db_home:.*/db_home: windows/' "$nsswitch"

    if [ $? -eq 0 ]; then
        ok "HOME 디렉토리를 Windows 사용자 폴더로 변경 완료"
        log "변경 내용: $current → db_home: windows"
        log "이제 cd ~ 하면 C:\\Users\\<user>로 이동합니다"
    else
        warn "nsswitch.conf 변경 실패"
        cp "$backup" "$nsswitch"
    fi
}

# ─── 5. fish 설정파일 생성 ──────────────────────────────────
setup_fish_config() {
    echo ""
    echo "============================================"
    echo " 5. Fish 설정파일 생성"
    echo "============================================"

    local config_dir="$HOME/.config/fish"
    local config_file="$config_dir/config.fish"

    mkdir -p "$config_dir"

    if [ -f "$config_file" ]; then
        warn "기존 config.fish 발견: $config_file"
        log "덮어쓰려면 5초 후 계속... (Ctrl+C로 취소)"
        local backup="$config_dir/config.fish.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$config_file" "$backup"
        log "백업 생성: $backup"
    fi

    log "config.fish 작성 중..."

    cat > "$config_file" << 'FISH_CONFIG'
# ============================================================
# Fish Shell 설정 파일
# ~/.config/fish/config.fish
#
# MSYS2 fish + Windows PATH 통합 환경
# ============================================================

# ─── 인터랙티브 모드에서만 실행 ─────────────────────────────
if status is-interactive

    # ── PATH 설정 ──
    # MSYS2 기본 경로를 PATH 앞에 추가
    # Windows 프로그램(fzf, node, nvim 등)은 자동 상속됨
    fish_add_path /mingw64/bin /usr/local/bin /usr/bin /bin

    # ── 단축 명령어 (abbr) ──
    # 입력 후 Space를 누르면 원래 명령어로 확장됨
    abbr -a ll 'ls -l'
    abbr -a la 'ls -la'
    abbr -a ls 'ls -F --color=auto --show-control-chars'
    abbr -a gs 'git status'
    abbr -a ga 'git add'
    abbr -a gc 'git commit'
    abbr -a gp 'git push'
    abbr -a gl 'git log --oneline --graph --all'
    abbr -a gd 'git diff'
    abbr -a gco 'git checkout'

    # ── fzf 연동 ──
    # Ctrl+T: 파일 검색, Ctrl+R: 히스토리 검색, Alt+C: 디렉토리 이동
    if command -sq fzf
        fzf --fish | source
    end

    # ── z (jump around) - 자주 간 디렉토리로 즉시 이동 ──
    # fisher plugin manager로 설치: fisher install jethrokuan/z
    if test -f ~/.config/fish/z.fish
        source ~/.config/fish/z.fish
    end

    # ── 프롬프트 ──
    function fish_prompt
        set -l last_status $status

        set -l pwd (set_color 7dcfff)(prompt_pwd)(set_color normal)

        set -l git_info ''
        if git rev-parse --is-inside-work-tree >/dev/null 2>&1
            set -l branch (git branch --show-current 2>/dev/null)
            if test -n "$branch"
                set git_info (set_color 9ece6a)" ($branch)"(set_color normal)
            end
        end

        echo -n -s $pwd $git_info
        echo

        if test $last_status -eq 0
            echo -n -s (set_color bb9af7) '➜  ' (set_color normal)
        else
            echo -n -s (set_color f7768e) '➜  ' (set_color normal)
        end
    end

    # ── 환영 메시지 ──
    set -q __fish_greeting
    or set -g __fish_greeting "🐟 Fish shell ready"
end
FISH_CONFIG

    if [ $? -eq 0 ]; then
        ok "config.fish 생성 완료: $config_file"
    else
        fail "config.fish 작성 실패"
    fi
}

# ─── 6. Windows Terminal 프로필 추가 ────────────────────────
setup_windows_terminal() {
    echo ""
    echo "============================================"
    echo " 6. Windows Terminal 프로필 추가 (선택)"
    echo "============================================"

    # Windows Terminal 설정 파일 위치
    local settings_files=(
        "$HOME/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
        "$HOME/AppData/Local/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json"
    )

    local settings_file=""
    for f in "${settings_files[@]}"; do
        if [ -f "$f" ]; then
            settings_file="$f"
            break
        fi
    done

    if [ -z "$settings_file" ]; then
        warn "Windows Terminal 설정 파일을 찾을 수 없음"
        warn "직접 추가하려면 Windows Terminal → 설정 → 프로필 추가"
        warn "명령줄: C:\\msys64\\usr\\bin\\fish.exe"
        return 0
    fi

    log "Windows Terminal 설정 파일 발견: $settings_file"

    # GUID 생성 (고정값: 한 번 생성된 fish 프로필 GUID)
    local fish_guid="{b8347c7f-0806-469f-9233-68e1ef4d022b}"

    # 이미 fish 프로필이 있는지 확인
    if grep -q "$fish_guid" "$settings_file" 2>/dev/null; then
        ok "Windows Terminal에 fish 프로필이 이미 있음"
        return 0
    fi

    # 백업
    local backup="$settings_file.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$settings_file" "$backup"
    log "Windows Terminal 설정 백업: $backup"

    # zsh 프로필 다음에 fish 프로필 삽입
    # sed로 "name": "zsh" 블록 다음에 삽입
    local fish_entry='            {
                "commandline": "C:\\\\msys64\\\\usr\\\\bin\\\\fish.exe",
                "font": 
                {
                    "face": "Cascadia Mono, NanumGothic"
                },
                "guid": "'$fish_guid'",
                "hidden": false,
                "icon": "C:\\\\msys64\\\\msys2.ico",
                "name": "fish",
                "startingDirectory": "%USERPROFILE%"
            }'

    # zsh 프로필 닫는 줄 다음에 추가
    sed -i '/^\s*\"name\": \"zsh\"/,/^\s*}/ {
        /^\s*}/a\
        '"$fish_entry"',
    }' "$settings_file"

    if [ $? -eq 0 ]; then
        ok "Windows Terminal에 fish 프로필 추가 완료"
        log "Windows Terminal을 다시 열면 'fish' 탭이 보입니다"
    else
        warn "Windows Terminal 설정 추가 실패"
        warn "직접 추가: 설정 → 프로필 추가 → 명령줄: C:\\msys64\\usr\\bin\\fish.exe"
    fi
}

# ─── 7. 설치 확인 ───────────────────────────────────────────
verify_installation() {
    echo ""
    echo "============================================"
    echo " 7. 설치 확인"
    echo "============================================"

    local errors=0

    # fish 실행 파일 확인
    if [ -f "$MSYS2_FISH" ]; then
        local version
        version=$("$MSYS2_FISH" -c 'fish --version' 2>/dev/null || "$MSYS2_FISH" --version 2>/dev/null)
        ok "Fish shell: $version"
    else
        warn "Fish 실행 파일 없음: $MSYS2_FISH"
        errors=$((errors + 1))
    fi

    # fish 설정 확인
    if [ -f "$HOME/.config/fish/config.fish" ]; then
        ok "Fish 설정 파일: $HOME/.config/fish/config.fish"
    else
        warn "Fish 설정 파일 없음"
        errors=$((errors + 1))
    fi

    # HOME 설정 확인
    local fish_home
    fish_home=$("$MSYS2_FISH" -c 'echo $HOME' 2>/dev/null || echo "")
    if echo "$fish_home" | grep -qi "users/"; then
        ok "HOME 디렉토리: $fish_home"
    else
        warn "HOME 디렉토리가 Windows 사용자 폴더가 아님: $fish_home"
        warn "/etc/nsswitch.conf에서 db_home: windows로 설정 필요"
    fi

    # fzf 확인 (Windows PATH 연동 검증)
    local fzf_path
    fzf_path=$("$MSYS2_FISH" -c 'which fzf' 2>/dev/null || echo "")
    if [ -n "$fzf_path" ]; then
        ok "Windows PATH 연동 (fzf): $fzf_path"
    else
        warn "fzf를 찾을 수 없음 (Windows PATH 확인 필요)"
    fi

    echo ""
    echo "============================================"
    if [ $errors -eq 0 ]; then
        echo -e " ${GREEN}모든 설치가 완료되었습니다!${NC}"
        echo ""
        echo " 실행 방법:"
        echo "   1. Windows Terminal → 'fish' 탭 선택"
        echo "   2. 또는 직접 실행: C:\\msys64\\usr\\bin\\fish.exe"
        echo ""
        echo " fish 설정 변경:"
        echo "   $HOME/.config/fish/config.fish"
    else
        echo -e " ${YELLOW}$errors개의 항목에 문제가 있습니다.${NC}"
        echo " 위 경고를 확인하세요."
    fi
    echo "============================================"
}

# ─── 실행 ────────────────────────────────────────────────────
main() {
    echo ""
    echo "============================================"
    echo " 🐟 Fish Shell + MSYS2 설치 스크립트"
    echo "============================================"
    echo ""

    install_msys2
    update_msys2
    install_fish
    setup_home_dir
    setup_fish_config

    echo ""
    log "Windows Terminal에 fish 프로필을 추가할까요?"
    read -rp " 추가하려면 y, 건너뛰려면 n (y/N): " add_terminal
    if [ "$add_terminal" = "y" ] || [ "$add_terminal" = "Y" ]; then
        setup_windows_terminal
    else
        echo ""
        log "Windows Terminal 프로필 추가를 건너뜁니다."
        log "직접 추가하려면: 설정 → 프로필 추가 → 명령줄 → C:\\msys64\\usr\\bin\\fish.exe"
    fi

    verify_installation

    echo ""
    echo -e " ${GREEN}✨ 모든 단계 완료! Windows Terminal을 열고 'fish' 탭을 선택하세요.${NC}"
    echo ""
}

main "$@"
