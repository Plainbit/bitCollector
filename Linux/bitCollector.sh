#!/bin/sh
###############################################################################################################
# BitCollector v2.0
###############################################################################################################

#==============================================================================================================
# 셸 스크립트 기본 설정
#==============================================================================================================
set -u

#==============================================================================================================
# 1. 전역 변수 정의
#==============================================================================================================
compPassword=""
systemOS=""
systemVersion=""
systemHostName=""
systemHostIp=""
systemHostMac=""
storePath="Result"
collectLog="Collect.log"
systemDate=""
resultFile=""
Ignore_echo=0
volatitleTasks=""
nonVolatitleTasks=""
success_count=0
warning_count=0
error_count=0
tmpDir=""

###############################################################################################################
# 로고 출력 함수 / Logo Display Function
###############################################################################################################
echo_logo() { 
  printf "\033[94m+=======================================================================+\033[0m\n"
  printf "\033[94m|                                                                       |\033[0m\n"
  printf "\033[94m|           _     _ _    ____      _ _           _                      |\033[0m\n"
  printf "\033[94m|          | |__ (_) |_ / ___|___ | | | ___  ___| |_ ___  _ __          |\033[0m\n"
  printf "\033[94m|          | '_ \| | __| |   / _ \| | |/ _ \/ __| __/ _ \| '__|         |\033[0m\n"
  printf "\033[94m|          | |_) | | |_| |__| (_) | | |  __/ (__| || (_) | |            |\033[0m\n"
  printf "\033[94m|          |_.__/|_|\__|\____\___/|_|_|\___|\___|\__\___/|_|            |\033[0m\n"
  printf "\033[94m|                      | | |   (_)_ __  _   ___  __                     |\033[0m\n"
  printf "\033[94m|                      | | |   | | '_ \| | | \ \/ /                     |\033[0m\n"
  printf "\033[94m|                      | | |___| | | | | |_| |>  <                      |\033[0m\n"
  printf "\033[94m|                      | | ____|_|_| |_|\__,_/_/\_\                     |\033[0m\n"
  printf "\033[94m|                                                                       |\033[0m\n"
  printf "\033[94m|                                                                       |\033[0m\n"
  printf "\033[94m|            A robust artifact collection tool by PLAINBIT              |\033[0m\n" 
  printf "\033[94m+=======================================================================+\033[0m\n\n"
}

###############################################################################################################
# 2. 출력 및 로깅 함수 / Output and Logging Functions
###############################################################################################################

# 색상 메시지 출력 함수 / Colored Message Output Function
ColorPrint() {
  color="$1"
  message="$2"
  if [ "$Ignore_echo" -eq 1 ]; then return; fi
  colorCode=""
  case "$color" in
    red)    colorCode="\033[31m" ;;
    blue)   colorCode="\033[34m" ;;
    yellow) colorCode="\033[33m" ;;
    green)  colorCode="\033[1;32m" ;;
    *)      printf "%s\n" "$message"; return ;;
  esac
  printf "${colorCode}[%s] %s\033[0m\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$message"
}

# 로그 기록 함수 / Log Recording Function
RecordLog() {
  status="$1"
  message="$2"
  printf "[%s] [%s] %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$status" "$message" >> "$collectLog"
}

###############################################################################################################
# 3. 환경 설정 및 검증 함수 / Environment Setup and Validation Functions
###############################################################################################################

# 임시 디렉토리 정리 함수 / Temporary Directory Cleanup Function
Cleanup() {
  if [ -n "$tmpDir" ] && [ -d "$tmpDir" ]; then
    rm -rf "$tmpDir"
    RecordLog Info "Cleanup: Temporary directory '$tmpDir' removed."
  fi
}

# 루트 권한 확인 함수 / Root Permission Check Function
CheckPermission() {
  if [ "$(id -u)" -ne 0 ]; then
    ColorPrint red "This script must be run as root."
    RecordLog Error "CheckPermission: Not running as root."
    exit 1
  fi
}

# 운영체제 정보 확인 함수 / Operating System Information Check Function
CheckOS() {
    if ! command -v uname >/dev/null 2>&1; then
        RecordLog Error "CheckOS: 'uname' command not found."
        ColorPrint red "Cannot determine OS because the required 'uname' command was not found."
        exit 1
    fi
    tmp=$(uname -a)

    if command -v oslevel >/dev/null 2>&1; then systemOS="AIX"; systemVersion=$(oslevel -s);
    elif echo "$tmp" | grep -qiF "raspberry"; then systemOS="Raspbian"; systemVersion=$(echo "$tmp" | sed -n 's/.*\([0-9]\{1,\}\.[0-9]\{1,\}\).*/\1/p' | head -1);
    elif echo "$tmp" | grep -qiF "amzn2"; then systemOS="AML2"; systemVersion="2";
    else
        for file in /etc/os-release /etc/centos-release /etc/redhat-release /etc/SuSE-release; do
            if [ -f "$file" ]; then
                if [ -z "$systemOS" ]; then
                    if grep -qiF "ubuntu" "$file"; then systemOS="Ubuntu";
                    elif grep -qiF "centos" "$file"; then systemOS="CentOS";
                    elif grep -qiF "red" "$file"; then systemOS="RedHat";
                    elif grep -qiF "suse" "$file"; then systemOS="SUSE";
                    elif grep -qiF "amazon linux" "$file"; then systemOS="AML2";
                    elif grep -qiF "aix" "$file"; then systemOS="AIX"; fi
                fi
                if [ -f "/etc/os-release" ]; then
                    systemVersion=$(grep "^VERSION_ID=" "/etc/os-release" | cut -d'=' -f2 | tr -d '"')
                else
                    systemVersion=$(sed -n 's/.*\([0-9]\{1,\}\.[0-9]\{1,\}\(\.[0-9]\{1,\}\)*\).*/\1/p' "$file" | head -1)
                fi
                [ -n "$systemOS" ] && break
            fi
        done
    fi

    if [ -z "$systemOS" ] || [ -z "$systemVersion" ]; then
        RecordLog Error "CheckOS: Could not determine OS or version."
        ColorPrint red "Unsupported OS or OS information could not be determined."
        exit 1
    fi

    systemHostName=$(hostname)
    if [ "$systemOS" = "AIX" ]; then
        systemHostMac=$(lsattr -El "$(lsdev -Cc adapter | grep -i ethernet | head -1 | awk '{print $1}')" 2>/dev/null | grep -i "network_address" | awk '{print $2}')
        systemHostIp=$(ifconfig -a | grep -E 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -n1)
    else
        systemHostMac=$(ip link 2>/dev/null | grep -A1 "state UP" | awk '/ether/ {print $2}' | head -n1)
        if [ -z "$systemHostMac" ] && command_exists ifconfig; then
            systemHostMac=$(ifconfig -a 2>/dev/null | awk '/ether|HWaddr/ {print $NF}' | head -n1)
        fi
        
        systemHostIp=$(hostname -I 2>/dev/null | awk '{print $1}')
        if [ -z "$systemHostIp" ]; then
            if command_exists ip; then
                 systemHostIp=$(ip a | grep -E 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1 | head -n1)
            elif command_exists ifconfig; then
                 systemHostIp=$(ifconfig -a 2>/dev/null | grep -E 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -n1)
            fi
        fi
    fi
    RecordLog Success "CheckOS: System information collected. OS: $systemOS $systemVersion"
}

# 환경 초기화 함수 / Environment Initialization Function
InitEnv() {
    mode="$1"
    configFile=""
    sanitized_config=""
    line=""
    rm -rf "$storePath"
    if ! mkdir -p "$storePath"; then
        ColorPrint red "Failed to create result directory: $storePath"
        RecordLog Error "InitEnv: Failed to create result directory: $storePath"
        exit 1
    fi
    scriptDir=$(cd "$(dirname "$0")" && pwd)
    if [ "$mode" -eq 1 ]; then
        configFile="$scriptDir/Config/${systemOS}.ini"
    elif [ "$mode" -eq 2 ]; then
        configFile="$scriptDir/Config/3rdParty.ini"
    fi
    if [ ! -f "$configFile" ]; then
        RecordLog Error "InitEnv: Configuration file not found: $configFile"
        ColorPrint red "Configuration file not found: $configFile"
        exit 1
    fi
    sanitized_config="$tmpDir/config.sanitized.ini"
    sed 's/\r$//' "$configFile" > "$sanitized_config"
    RecordLog Info "InitEnv: Parsing sanitized configuration file: $sanitized_config"
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            \#* | "") continue ;;
            \[*\]) continue ;;
        esac
        if [ "$(echo "$line" | tr -cd ',' | wc -c)" -ne 4 ]; then
            RecordLog Error "InitEnv: Invalid config format (must have 5 fields): $line"
            warning_count=$((warning_count + 1))
            continue
        fi
        case "$line" in
            Volatile,*)
                if [ -z "$volatitleTasks" ]; then
                    volatitleTasks="$line"
                else
                    volatitleTasks="$volatitleTasks
$line"
                fi
                ;;
            NonVolatile,*)
                if [ -z "$nonVolatitleTasks" ]; then
                    nonVolatitleTasks="$line"
                else
                    nonVolatitleTasks="$nonVolatitleTasks
$line"
                fi
                ;;
            *)
                RecordLog Error "InitEnv: Unknown category in line: $line"
                warning_count=$((warning_count + 1))
                ;;
        esac
    done < "$sanitized_config"
    RecordLog Success "InitEnv: Configuration file parsed successfully."
}

# 비밀번호 입력 및 검증 함수 / Password Input and Validation Function
CheckPassword() {
  password=""
  password2=""
  passwd_len=10
  while true; do
    printf "Enter password for the archive (10+ chars, with letter, number, special char): "
    stty -echo; read password; stty echo; printf "\n"
    printf "Re-enter password for verification: "
    stty -echo; read password2; stty echo; printf "\n"
    if [ "$password" != "$password2" ]; then
      ColorPrint red "Passwords do not match. Please try again."
      continue
    fi
    if [ "${#password}" -lt "$passwd_len" ]; then
      ColorPrint red "Password must be at least $passwd_len characters long."
      continue
    fi
    if ! echo "$password" | grep -q '[[:digit:]]' || \
       ! echo "$password" | grep -q '[[:alpha:]]' || \
       ! echo "$password" | grep -q '[[:punct:]]'; then
      ColorPrint red "Password must contain at least one letter, one number, and one special character."
      continue
    fi
    compPassword="$password"
    break
  done
}

###############################################################################################################
# 4. 데이터 수집 함수 / Data Collection Functions
###############################################################################################################

# 명령어 존재 여부 확인 함수 / Command Existence Check Function
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 명령어 실행 결과 수집 함수 / Command Execution Result Collection Function
CollectCmd() {
    cmd="$1"
    dest="$2"
    cmd=$(echo "$cmd" | sed -e 's/^"//' -e 's/"$//')
    if [ "$(basename "$dest")" = "none" ]; then
        safe_filename=$(echo "$cmd" | tr -c 'a-zA-Z0-9_.-' '_')
        final_dest="$(dirname "$dest")/${safe_filename}"
    else
        final_dest="$dest"
    fi
    firstCmd=$(echo "$cmd" | awk '{print $1}')
    if ! command_exists "$firstCmd"; then
        RecordLog Error "CollectCmd: Command not found: $firstCmd"
        error_count=$((error_count + 1))
        return 1
    fi
    if ! mkdir -p "$(dirname "$final_dest")"; then
        RecordLog Error "CollectCmd: Failed to create directory for $final_dest"
        error_count=$((error_count + 1))
        return 1
    fi
    RecordLog Info "CollectCmd: Executing: $cmd -> $final_dest"
    if eval "$cmd" > "$final_dest" 2>"$tmpDir/stderr.log"; then
        if [ -s "$final_dest" ]; then
            RecordLog Success "CollectCmd: '$cmd' collected successfully."
            success_count=$((success_count + 1))
        else
            RecordLog Warning "CollectCmd: Command '$cmd' executed but the output was empty."
            warning_count=$((warning_count + 1))
        fi
    else
        ret=$?
        stderr_output=$(cat "$tmpDir/stderr.log")
        RecordLog Error "CollectCmd: Execution failed for '$cmd' (Exit: $ret). Error: $stderr_output"
        error_count=$((error_count + 1))
        return 1
    fi
    return 0
}

# 파일 복사 수집 함수 / File Copy Collection Function
CollectFile() {
    source_pattern="$1"
    dest="$2"
    ls -d $source_pattern 2>/dev/null | while IFS= read -r source; do
        if [ ! -f "$source" ]; then continue; fi
        final_dest="$dest"
        if [ "$(basename "$dest")" = "none" ]; then
            final_dest="$(dirname "$dest")/$(basename "$source")"
        fi
        if ! mkdir -p "$(dirname "$final_dest")"; then
            RecordLog Error "CollectFile: Failed to create directory for $final_dest"
            error_count=$((error_count + 1))
            continue
        fi
        RecordLog Info "CollectFile: Copying: $source -> $final_dest"
        if cp -p "$source" "$final_dest" 2>/dev/null; then
            RecordLog Success "CollectFile: '$source' collected successfully."
            success_count=$((success_count + 1))
        else
            RecordLog Error "CollectFile: Failed to copy '$source'."
            error_count=$((error_count + 1))
        fi
    done
}

# 디렉토리 복사 수집 함수 / Directory Copy Collection Function
CollectDir() {
    source_pattern="$1"
    dest="$2"
    ls -d $source_pattern 2>/dev/null | while IFS= read -r source; do
        if [ ! -d "$source" ]; then continue; fi
        final_dest="$dest"
        if [ "$(basename "$dest")" = "none" ]; then
            final_dest="$(dirname "$dest")/$(basename "$source")"
        fi
        if ! mkdir -p "$final_dest"; then
            RecordLog Error "CollectDir: Failed to create directory $final_dest"
            error_count=$((error_count + 1))
            continue
        fi
        RecordLog Info "CollectDir: Copying: $source -> $final_dest"
        if command_exists rsync; then
            if rsync -a "$source/" "$final_dest" --exclude ".git" >/dev/null 2>&1; then
                RecordLog Success "CollectDir: '$source' (rsync) collected successfully."
                success_count=$((success_count + 1))
            else
                RecordLog Error "CollectDir: Failed to copy '$source' using rsync."
                error_count=$((error_count + 1))
            fi
        else
            if cp -rp "$source/." "$final_dest" 2>/dev/null; then
                RecordLog Success "CollectDir: '$source' (cp) collected successfully."
                success_count=$((success_count + 1))
            else
                RecordLog Error "CollectDir: Failed to copy '$source' using cp."
                error_count=$((error_count + 1))
            fi
        fi
    done
}

# 프로세스 실행 파일 수집 함수 / Process Executable Collection Function
CollectProc() {
    dest="$2"
    final_dest="${dest%/none}/process_dump"
    if ! command_exists readlink; then
        RecordLog Error "CollectProc: 'readlink' command not found, skipping process dump."
        error_count=$((error_count + 1))
        return 1
    fi
    RecordLog Info "CollectProc: Collecting executable files of running processes..."
    ps -eo pid= | while read -r pid; do
        exe_path=$(readlink -f "/proc/${pid}/exe" 2>/dev/null || true)
        if [ -n "$exe_path" ] && [ -e "$exe_path" ]; then
            echo "$exe_path"
        fi
    done | sort | uniq > "$tmpDir/proc_list.txt"
    if [ -s "$tmpDir/proc_list.txt" ]; then
        if tar -P -zcf "${final_dest}.tar.gz" -T "$tmpDir/proc_list.txt" >/dev/null 2>&1; then
            RecordLog Success "CollectProc: Process executables compressed successfully."
            success_count=$((success_count + 1))
        else
            RecordLog Error "CollectProc: Failed to compress process executables."
            error_count=$((error_count + 1))
        fi
    else
        RecordLog Warning "CollectProc: No process executables found to collect."
        warning_count=$((warning_count + 1))
    fi
}

###############################################################################################################
# 5. 메인 로직 함수 / Main Logic Functions
###############################################################################################################

# 데이터 수집 메인 함수 / Main Data Collection Function
CollectData() {
    RecordLog Info "========== Data Collection Start =========="
    ColorPrint blue "Starting data collection for [$systemOS] system."
    
    total_tasks=0
    [ -n "$volatitleTasks" ] && total_tasks=$((total_tasks + $(echo "$volatitleTasks" | wc -l)))
    [ -n "$nonVolatitleTasks" ] && total_tasks=$((total_tasks + $(echo "$nonVolatitleTasks" | wc -l)))
    
    RecordLog Info "Total tasks to collect: $total_tasks"

    current_task_count=0
    if [ -n "$volatitleTasks" ]; then
        RecordLog Info "--- Collecting Volatile Data ---"
        printf "%s\n" "$volatitleTasks" > "$tmpDir/volatile_tasks.txt"
        
        while IFS= read -r line; do
            current_task_count=$((current_task_count + 1))
            
            line_remainder="$line"
            field1=$(echo "$line_remainder" | cut -d',' -f1)
            line_remainder=$(echo "$line_remainder" | cut -d',' -f2-)
            field2=$(echo "$line_remainder" | cut -d',' -f1)
            line_remainder=$(echo "$line_remainder" | cut -d',' -f2-)
            field3=$(echo "$line_remainder" | cut -d',' -f1)
            line_remainder=$(echo "$line_remainder" | cut -d',' -f2-)
            action=$(echo "$line_remainder" | cut -d',' -f1)
            data=$(echo "$line_remainder" | cut -d',' -f2-)
            
            field1=$(echo "$field1" | xargs)
            field2=$(echo "$field2" | xargs)
            field3=$(echo "$field3" | xargs)
            action=$(echo "$action" | xargs)
            data=$(echo "$data" | sed -e 's/^[[:space:]]*//')

            progress_message=""
            case "$action" in
                cmd)      progress_message="[$field1/$field2] Executing: $data" ;;
                file)     progress_message="[$field1/$field2] Copying file: $data" ;;
                dir)      progress_message="[$field1/$field2] Copying dir: $data" ;;
                function) progress_message="[$field1/$field2] Running function: $data" ;;
            esac

            percent=0
            if [ "$total_tasks" -gt 0 ]; then
                percent=$(( (current_task_count * 100) / total_tasks ))
            fi
            PrintProgressBar "$percent" "$progress_message"

            case "$action" in
                cmd)      CollectCmd "$data" "$storePath/$field1/$field2/$field3" ;;
                file)     CollectFile "$data" "$storePath/$field1/$field2/$field3" ;;
                dir)      CollectDir "$data" "$storePath/$field1/$field2/$field3" ;;
                function) "$data" "$data" "$storePath/$field1/$field2/$field3" ;;
                *)
                    RecordLog Error "Unknown action: '$action' in line: $line"
                    error_count=$((error_count + 1))
                    ;;
            esac
        done < "$tmpDir/volatile_tasks.txt"
    fi
    
    if [ -n "$nonVolatitleTasks" ]; then
        RecordLog Info "--- Collecting Non-Volatile Data ---"
        printf "%s\n" "$nonVolatitleTasks" > "$tmpDir/nonvolatile_tasks.txt"
        
        while IFS= read -r line; do
            current_task_count=$((current_task_count + 1))

            line_remainder="$line"
            field1=$(echo "$line_remainder" | cut -d',' -f1)
            line_remainder=$(echo "$line_remainder" | cut -d',' -f2-)
            field2=$(echo "$line_remainder" | cut -d',' -f1)
            line_remainder=$(echo "$line_remainder" | cut -d',' -f2-)
            field3=$(echo "$line_remainder" | cut -d',' -f1)
            line_remainder=$(echo "$line_remainder" | cut -d',' -f2-)
            action=$(echo "$line_remainder" | cut -d',' -f1)
            data=$(echo "$line_remainder" | cut -d',' -f2-)

            field1=$(echo "$field1" | xargs)
            field2=$(echo "$field2" | xargs)
            field3=$(echo "$field3" | xargs)
            action=$(echo "$action" | xargs)
            data=$(echo "$data" | sed -e 's/^[[:space:]]*//')

            progress_message=""
            case "$action" in
                cmd)      progress_message="[$field1/$field2] Executing: $data" ;;
                file)     progress_message="[$field1/$field2] Copying file: $data" ;;
                dir)      progress_message="[$field1/$field2] Copying dir: $data" ;;
                function) progress_message="[$field1/$field2] Running function: $data" ;;
            esac

            percent=0
            if [ "$total_tasks" -gt 0 ]; then
                percent=$(( (current_task_count * 100) / total_tasks ))
            fi
            PrintProgressBar "$percent" "$progress_message"

            case "$action" in
                cmd)      CollectCmd "$data" "$storePath/$field1/$field2/$field3" ;;
                file)     CollectFile "$data" "$storePath/$field1/$field2/$field3" ;;
                dir)      CollectDir "$data" "$storePath/$field1/$field2/$field3" ;;
                function) "$data" "$data" "$storePath/$field1/$field2/$field3" ;;
                *)
                    RecordLog Error "Unknown action: '$action' in line: $line"
                    error_count=$((error_count + 1))
                    ;;
            esac
        done < "$tmpDir/nonvolatile_tasks.txt"
    fi
    
    RecordLog Info "========== Data Collection Finished =========="
}

# 데이터 압축 함수 / Data Compression Function
CompData() {
    zip_is_available="$1" 

    RecordLog Info "========== Compression Start =========="
    ColorPrint blue "Compressing collected information."

    if [ "$zip_is_available" -eq 1 ]; then
        zip -P "$compPassword" -r -q "$resultFile.zip" "./$storePath" "$collectLog" >/dev/null 2>&1
        ColorPrint green "Compression complete: $resultFile.zip"
        ColorPrint blue "Verifying archive integrity..."
        
        if unzip -tP "$compPassword" "$resultFile.zip" >/dev/null 2>&1; then
            ColorPrint green "Integrity check successful."
            RecordLog Success "CompData: Archive integrity check successful."
            
            if command_exists sha256sum; then
                sha256=$(sha256sum "$resultFile.zip" | awk '{print $1}')
                ColorPrint blue "SHA256: $sha256"
                RecordLog Info "Archive SHA256: $sha256"
            else
                ColorPrint yellow "sha256sum command not found. Skipping hash calculation."
                RecordLog Warning "CompData: sha256sum not found. Hash calculation skipped."
            fi
        else
            ColorPrint red "Integrity check failed! The archive may be corrupted."
            RecordLog Error "CompData: Archive integrity check failed."
            error_count=$((error_count + 1))
        fi
    else
        tar -cf "$resultFile.tar" "$storePath" "$collectLog" >/dev/null 2>&1
        ColorPrint green "Compression complete (tar, no password): $resultFile.tar"
        
        if command_exists sha256sum; then
            sha256=$(sha256sum "$resultFile.tar" | awk '{print $1}')
            ColorPrint blue "SHA256: $sha256"
            RecordLog Info "Archive SHA256: $sha256"
        else
            ColorPrint yellow "sha256sum command not found. Skipping hash calculation."
            RecordLog Warning "CompData: sha256sum not found. Hash calculation skipped."
        fi
    fi
    RecordLog Info "========== Compression Finished =========="
}

# 환경 정리 함수 / Environment Cleanup Function
CleanEnv(){
    rm -rf "$storePath"
    RecordLog Info "CleanEnv: Result directory ($storePath) has been removed."
}

# 진행률 표시 바 함수 / Progress Bar Display Function
PrintProgressBar() {
  percent="$1"
  phase="$2"
  
  progress_bar="["
  total_dots=40
  filled_dots=$((percent * total_dots / 100))ㄷㄷㄷㄷㄷㄷㄷㄷㄷ
  
  i=0
  while [ $i -lt $filled_dots ]; do
    progress_bar="$progress_bar="
    i=$((i + 1))
  done
  [ $percent -ne 100 ] && progress_bar="${progress_bar}>" || progress_bar="${progress_bar}="
  
  i=$((i + 1))
  while [ $i -le $total_dots ]; do
    progress_bar="$progress_bar "
    i=$((i + 1))
  done
  progress_bar="$progress_bar]"
  
  printf "\033c"
  echo_logo
  printf "\033[1;32m%s (%d%%)\033[0m\n%s\n" "$progress_bar" "$percent" "$phase"
}

# 결과 요약 출력 함수 / Result Summary Display Function
PrintSummary() {
    printf "\n"
    ColorPrint blue "================== Collection Summary =================="
    ColorPrint green "  Success: $success_count"
    ColorPrint yellow "  Warnings: $warning_count"
    ColorPrint red "  Failures: $error_count"
    ColorPrint blue "======================================================"
    
    RecordLog Info "========== Collection Summary =========="
    RecordLog Info "Success: $success_count, Warnings: $warning_count, Failures: $error_count"
    RecordLog Info "========================================"

    if [ "$error_count" -gt 0 ]; then
        printf "\n"
        ColorPrint red "There were $error_count errors during collection."
        ColorPrint red "Please check 'collect.log' for details and perform manual collection for the failed items."
    fi
    printf "\n"
}

###############################################################################################################
# 6. 메인 함수 / Main Function
###############################################################################################################
main() {
    trap Cleanup EXIT
    
    if command_exists mktemp; then
        tmpDir=$(mktemp -d "/tmp/bitcollector.XXXXXX")
    else
        tmpDir="/tmp/bitcollector.$$"
        if [ -e "$tmpDir" ]; then
            echo "[ERROR] Temporary path '$tmpDir' already exists. Aborting."
            exit 1
        fi
        mkdir "$tmpDir"
    fi

    zip_is_available=0
    if command_exists zip; then
        zip_is_available=1
    fi

    rm -f "$collectLog"
    RecordLog Info "========== BitCollector Script Start (PID: $$) =========="

    echo_logo
    CheckPermission
    CheckOS

    printf "\033[92m     1. Collect system artifacts\033[0m\n"
    printf "\033[92m     2. Collect 3rd-party application artifacts\033[0m\n\n"
    printf "     Select an option to collect (1 or 2): "
    read -r userChoice

    case "$userChoice" in
        1|2) InitEnv "$userChoice" ;;
        *) ColorPrint red "Invalid option selected."; exit 1 ;;
    esac

    CollectData
    PrintProgressBar 100 "Collection complete. Preparing for compression."
    sleep 1
    
    PrintSummary

    systemDate=$(date '+%Y-%m-%d')
    if [ "$userChoice" = "1" ]; then
        resultFile="${systemDate}_${systemOS}_${systemHostName}_${systemHostIp}"
    else
        resultFile="${systemDate}_${systemOS}_${systemHostName}_${systemHostIp}_3rdParty"
    fi

    if [ "$zip_is_available" -eq 1 ]; then
        CheckPassword
    else
        ColorPrint yellow "zip command not found. The result will be compressed using tar.gz without a password."
        RecordLog Warning "Main: zip command not found, skipping password prompt."
    fi
    
    CompData "$zip_is_available"
    
    CleanEnv
    
    ColorPrint green "All collection procedures are complete!"
    RecordLog Info "========== BitCollector Script Finished =========="
}

#==============================================================================================================
# 프로그램 시작 / Program Start
#==============================================================================================================
main