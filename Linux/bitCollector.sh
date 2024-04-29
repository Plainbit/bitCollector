#!/bin/bash
# PLAINBIT - bitCollector for Linux
# Version: 1.0.0
###############################################################################################################
function echo_logo { 
  echo -e "\e[94m+=======================================================================+\e[0m"
  echo -e "\e[94m|                                                                       |\e[0m"
  echo -e "\e[94m|  _     _ _    ____      _ _           _                __             |\e[0m"
  echo -e "\e[94m| | |__ (_) |_ / ___|___ | | | ___  ___| |_ ___  _ __   / _| ___  _ __  |\e[0m"
  echo -e "\e[94m| | '_ \| | __| |   / _ \| | |/ _ \/ __| __/ _ \| '__| | |_ / _ \| '__| |\e[0m"
  echo -e "\e[94m| | |_) | | |_| |__| (_) | | |  __/ (__| || (_) | |    |  _| (_) | |    |\e[0m"
  echo -e "\e[94m| |_.__/|_|\__|\____\___/|_|_|\___|\___|\__\___/|_|    |_|  \___/|_|    |\e[0m"
  echo -e "\e[94m| | |   (_)_ __  _   ___  __                                            |\e[0m"
  echo -e "\e[94m| | |   | | '_ \| | | \ \/ /                                            |\e[0m"
  echo -e "\e[94m| | |___| | | | | |_| |>  <                                             |\e[0m"
  echo -e "\e[94m| |_____|_|_| |_|\__,_/_/\_\                                            |\e[0m"
  echo -e "\e[94m|                                                                       |\e[0m"
  echo -e "\e[94m+=======================================================================+\e[0m"
  echo -e "\n"
}
###############################################################################################################
#1. 전역 변수 정의
###############################################################################################################
declare -a volatitleTasks
declare -a nonVolatitleTasks
compPassword=""
systemOS=""
systemVersion=""
systemHostName=""
systemHostIp=""
systemHostMac=""
storePath="Result"
collectLog="collect.log"
systemDate=""
resultFile=""
collectSize="0"
availableSize="0"
###############################################################################################################
#2. 출력 함수
# 색상을 가진 메세지 출력을 위한 함수
# Function for outputting colored messages
# Usage: ColorPrint $color $text
###############################################################################################################
function ColorPrint {
  local color="$1"
  local message="$2"

  if [[ $Ignore_echo -eq 1 ]]; then return; fi

  local colorCode=""
  case $color in
    red)    colorCode="\033[31m" ;;
    blue)   colorCode="\033[34m" ;;
    yellow) colorCode="\033[33m" ;;
    green)  colorCode="\033[1;32m" ;;
    *)      echo "$message"; return ;;
  esac
  echo -e "${colorCode}[$(date +'%Y-%m-%d %H:%M:%S')] $message\033[0m"
}
###############################################################################################################
#3. 로깅 함수
# 성공, 실패 관련 로그 기록을 위한 함수
# Function for recording logs related to success and failure
# Usage: RecordLog $status $text
###############################################################################################################
function RecordLog {
  local status="$1"
  local message="$2"
  local logFile=""

  # Bash 버전 3에서 대문자 변환을 제외
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$status] $message" >> "$collectLog"
}
###############################################################################################################
#4. 실행 권한 확인
# 원활한 수집 스크립트 동작을 위한 root 권한 확인
# Check root permissions for smooth collection script operation
# Usage : CheckPermission
###############################################################################################################
function CheckPermission {
  if [[ $UID -ne 0 ]]; then
    echo -ne '\n'
    ColorPrint red "Should run as root."
    echo -ne '\n'
    RecordLog Error "CheckPermission: Root permission not confirmed."
    exit 1
  fi
}
###############################################################################################################
#5. 수집 대상 시스템 정보 수집
# Collection of target system information
# Usage: CheckOS
###############################################################################################################
function CheckOS {
    # uname 및 hostname 명령의 존재 여부 확인
    if ! command_exists uname; then
        RecordLog Error "CheckOS: uname command not found."
        return
    fi

    local tmp=$(uname -a)
    local osVersionPattern='[0-9]+\.[0-9]+(\.[0-9]+)?(-[0-9]+)?'

    # OS 명 파싱
    if echo "$tmp" | grep -qiF "raspberry"; then
        systemOS="Raspbian"
        systemVersion=$(echo "$tmp" | grep -oE "$osVersionPattern" | head -1)
    else
        declare -a osFiles=("/etc/os-release" "/etc/centos-release" "/etc/redhat-release" "/etc/SuSE-release")
        for file in "${osFiles[@]}"; do
            if [[ -f "$file" ]]; then
                case "$file" in
                    "/etc/os-release")
                        systemVersion=$(grep "^VERSION_ID=" "$file" | cut -d'=' -f2 | tr -d '"')
                        ;;
                    "/etc/centos-release" | "/etc/redhat-release" | "/etc/SuSE-release")
                        systemVersion=$(grep -oE "$osVersionPattern" "$file" | head -1)
                        ;;
                esac

                if [[ -z "$systemOS" ]]; then
                    if grep -qiF "ubuntu" "$file"; then systemOS="Ubuntu"
                    elif grep -qiF "centos" "$file"; then systemOS="CentOS"
                    elif grep -qiF "red" "$file"; then systemOS="RedHat"
                    elif grep -qiF "suse" "$file"; then systemOS="SUSE"
                    fi
                fi

                [[ -n "$systemOS" ]] && break
            fi
        done
    fi

    # OS 또는 버전 정보가 없을 경우 에러 로깅
    if [[ -z "$systemOS" || -z "$systemVersion" ]]; then
        RecordLog Error "CheckOS: Unable to determine OS or version."
        return
    fi

    # 호스트 이름, MAC, IP 주소 수집
    if ! command_exists hostname; then
        RecordLog Error "CheckOS: hostname command not found."
    else
        systemHostName=$(hostname)
        systemHostMac=$(ip link | grep -B1 "state UP" | awk '/ether/ {print $2}' | head -n1)
        systemHostIp=$(hostname -I 2>/dev/null | awk '{print $1}')
        [[ "$systemOS" == "SUSE" ]] && systemHostIp=$(ip a | grep -E 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1 | head -n1)
    fi

    RecordLog Success "CheckOS: System information collected successfully."
}
###############################################################################################################
#6. 초기 환경 설정 함수
# 수집 결과 폴더 생성 및 Config 파일 검증 수행
# Create collection result folder and perform Config file verification
# Usage: InitEnv 1
# Args: 1(System Artifact), 2(3rd party Artifact)
###############################################################################################################
function InitEnv() {
    local mode="$1"
    local currentSection=""
    local configFile=""
    local line=""
    local inOSBlock=false

    # 저장 디렉토리 삭제 및 생성
    rm -rf "$storePath"
    mkdir "$storePath"

    # 설정 파일 경로 설정 및 존재 여부 검증
    scriptDir=$(cd "$(dirname "$0")" && pwd)
    if [[ "$mode" -eq 1 ]]; then
        configFile="$scriptDir/Config/${systemOS}.ini"
    elif [[ "$mode" -eq 2 ]]; then
        configFile="$scriptDir/Config/3rdParty.ini"
    else
        return 2
    fi

    if [[ ! -f "$configFile" ]]; then
        return 3
    fi

    # 설정 파일 파싱 시작
    while IFS= read -r line || [[ -n "$line" ]]; do
        line=$(echo "$line" | tr -d '\r')  # CRLF를 LF로 변환

        # 주석 또는 빈 줄 무시
        if [[ "$line" =~ ^# ]] || [[ -z "$line" ]]; then
            continue
        fi

        # 섹션 이름 파싱
        if [[ "$line" =~ ^\[.+\]$ ]]; then
            currentSection=$(echo "$line" | sed 's/[\[\]]//g')  # 대괄호([]) 제거
            inOSBlock=true
            continue
        fi

        if [[ "$inOSBlock" == true ]]; then
            IFS=',' read -ra components <<< "$line"
            # 필요한 경우 추가 처리 (예: 공백 제거)

            # Confirm that exactly five components exist per line
            if [[ ${#components[@]} -ne 5 ]]; then
                return 4
            fi

            for i in "${!components[@]}"; do
                components[$i]=$(echo "${components[$i]}" | xargs)
            done

            local primaryCategory="${components[0]}"
            local secondaryCategory="${components[1]}"

            # NonVolatile 작업에 대한 폴더 생성
            if [[ "$primaryCategory" == "NonVolatile" ]]; then
                mkdir -p "$storePath/$primaryCategory"
            else
                mkdir -p "$storePath/$primaryCategory/$secondaryCategory"
            fi

            # 작업 목록에 추가
            if [[ ${components[0]} == "Volatile" ]]; then
              volatitleTasks+=("$(IFS=,; echo "${components[*]:0}")")
            else
              nonVolatitleTasks+=("$(IFS=,; echo "${components[*]:0}")")
            fi
        fi
    done < "$configFile"

    return 0
}
###############################################################################################################
#7. 저장 공간 확인
# Check storage space
# Usage : calculate_size
###############################################################################################################
function CheckDriveSize() {
    local total_size=0
    local file_path=""
    
    # Iterate through nonVolatitleTasks array for file paths
    for task in "${nonVolatitleTasks[@]}"; do
        IFS=',' read -ra ADDR <<< "$task"
        file_path="${ADDR[4]}"  # File path is the fifth column
        
        # Calculate file size and add to total
        if [ -f "$file_path" ]; then
            file_size=$(stat -c %s "$file_path")
            collectSize=$((collectSize + file_size))
        fi
    done
    
    # Check available space in the current partition
    availableSize=$(df "$(pwd)" | awk 'NR==2 {print $4}')
    availableSize=$((availableSize * 1024))  # Convert KB to Bytes
    # Check if there is enough space
    if [ $((collectSize * 2)) -lt $availableSize ]; then
        return 1
    else
        return 2
    fi
}
###############################################################################################################
#8. 비밀번호 입력 및 검증
# Usage : CheckPassword
###############################################################################################################
function CheckPassword() {
  local password password2
  local passwd_len=10

  # 비밀번호 복잡성 및 일치성 검증
  while true; do
    # 비밀번호 입력
    read -r -s -p "Enter password (10 or more digits, including at least one letter, one number, and one special character): " password
    echo
    read -r -s -p "Re-enter password for verification: " password2
    echo

    # 비밀번호 일치 확인
    if [[ "$password" != "$password2" ]]; then
      echo -e "\033[31mPasswords do not match. Please try again.\033[0m"
      continue
    fi

    # 비밀번호 길이 검증
    if [[ ${#password} -lt $passwd_len ]]; then
      echo -e "\033[31mInput password must be at least $passwd_len characters long.\033[0m"
      continue
    fi

    # 비밀번호 복잡성 검증
    if ! [[ "$password" =~ [[:digit:]] ]] || ! [[ "$password" =~ [[:alpha:]] ]] || ! [[ "$password" =~ [[:punct:]] ]]; then
      echo -e "\033[31mPassword must contain at least one letter, one number, and one special character.\033[0m"
      continue
    fi

    # 비밀번호 검증 성공
    compPassword="$password"
    break
  done
}
###############################################################################################################
#9. 데이터 수집
###############################################################################################################
#9.1 시스템 지원 명령어 여부 확인
# 해당 운영체제에서 사용가능한 Command 인지 확인
# Check whether the command is available in the operating system
# Usage: command_exists $command
###############################################################################################################
function command_exists() {
    type "$1" >/dev/null 2>&1
}
###############################################################################################################
#9.2 명렁어 데이터 수집
# 명령어 출력 결과를 사전 정의된 파일로 저장
# Save command output results to a predefined file
# Usage : CollectCmd $command $destpath
###############################################################################################################
function CollectCmd() {
  # 명령어를 괄호로 묶인 부분 제거 없이 직접 실행
  local cmd="$1"
  local dest="$2"
  local final_dest=""
  local ret=0

  # Destination이 "/none"으로 끝나는 경우의 처리
  if [[ "$(basename "$dest")" == "none" ]]; then
    dest="${dest%/none}"
    final_dest="${dest}/${cmd}"
  else
    final_dest="$dest"
  fi

  # 명령어의 첫 단어(실제 실행 파일)만을 사용하여 존재 여부 확인
  local firstCmd=$(echo $cmd | awk '{print $1}')
  if ! command_exists "$firstCmd"; then
    RecordLog Error "CollectCmd: Command $firstCmd not found."
    return 1
  fi

  # 명령어 실행 및 결과 리다이렉션
  eval "$cmd" > "$final_dest" 2>/dev/null
  ret=$?
  if [ $ret -ne 0 ]; then
    RecordLog Error "CollectCmd: Execution failed for command: $cmd."
  else
    RecordLog Success "CollectCmd: Command $cmd collected successfully."
  fi

  return $ret
}
###############################################################################################################
#9.3 파일 데이터 수집
# 파일을 복사하여 저장, 와일드카드의 경우 폴더를 생성하여 모두 복사
# MetaData를 유지하여 복사
# Copy and save the file, in case of wildcard, create a folder and copy all
# Copy by maintaining MetaData
# Usage : CollectFile $srcpath $destpath
###############################################################################################################
function CollectFile() {
  local source_pattern="$1"
  local dest="$2"
  local ret=0

  # Destination이 "/none"으로 끝나는 경우의 처리
  local replace_none=false
  if [[ "$(basename "$dest")" == "none" ]]; then
    replace_none=true
    dest="${dest%/none}"
  fi

  # Wildcard patterns 대응
  shopt -s nullglob
  local files_matched=($source_pattern)
  shopt -u nullglob

  for source in "${files_matched[@]}"; do
    if [[ -f "$source" ]]; then
      local final_dest=""
      
      # "/none"을 대체하는 로직
      if [[ "$replace_none" == true ]]; then
        final_dest="${dest}/$(dirname "${source#/home/}")"
        mkdir -p "$final_dest"
      else
        final_dest="$dest"
      fi

      if cp --preserve=all "$source" "$final_dest" 2>/dev/null; then
        sleep 0.2
        RecordLog Success "CollectFile: $source is collected successfully."
      else
        RecordLog Error "CollectFile: An error occurred while collecting $source"
      fi
    else
      RecordLog Error "CollectFile: File $source not found."
      return 0
    fi
  done

  return $ret
}
###############################################################################################################
#9.4 폴더 데이터 수집
# 폴더를 복사하여 저장, 와일드카드의 경우 폴더를 생성하여 모두 복사
# MetaData를 유지하여 복사
# Copy and save the folder, in case of wildcard, create a folder and copy all
# Copy by maintaining MetaData
# Usage : CollectDir $srcpath $destpath
###############################################################################################################
function CollectDir() {
  local source_pattern="$1"
  local dest="$2"
  local replace_none=false

  # Destination이 "/none"으로 끝나는 경우의 처리
  if [[ "$(basename "$dest")" == "none" ]]; then
    replace_none=true
    dest="${dest%/none}"
  fi

  # Wildcard patterns 대응
  shopt -s nullglob
  local dirs_matched=($source_pattern)
  shopt -u nullglob

  for source in "${dirs_matched[@]}"; do
    if [[ -d "$source" ]]; then
      local final_dest=""

      # "/none"을 대체하는 로직
      if [[ "$replace_none" == true ]]; then
        final_dest="${dest}/$(dirname "${source#/home/}")"
        mkdir -p "$final_dest"
      else
        final_dest="$dest"
      fi

      # rsync가 있는 경우와 없는 경우를 구분하여 처리
      # if command -v rsync >/dev/null; then
      #   rsync -avh --progress "$source/" "$final_dest" --exclude ".git" 2>&1 | while read line; do
      #     echo $line
      #   done
      #   RecordLog Success "CollectDir: $source is collected successfully using rsync."
      # else
        cp -r --preserve=all "$source" "$final_dest" 2>/dev/null
        if [ $? -eq 0 ]; then
          RecordLog Success "CollectDir: $source is collected successfully using cp."
        else
          RecordLog Error "CollectDir: An error occurred while collecting $source using cp."
          return 1
        fi
      # fi
    else
      RecordLog Error "CollectDir: Directory $source not found."
      return 0 # 에러 없음으로 처리
    fi
  done

  return 0 # 모든 디렉터리 처리 후 성공
}
###############################################################################################################
#9.5 프로세스 데이터 수집
# /proc/{exe}/ 데이터 수집
# 악성 프로세스 식별 및 분석 용도
# /proc/{exe}/ Data collection
# For malicious process identification and analysis purposes
###############################################################################################################
function CollectProc() {
    local source="$1"
    local dest="$2"
    local final_dest=""

    # Destination이 "/none"으로 끝나는 경우의 처리
    if [[ "$(basename "$dest")" == "none" ]]; then
      final_dest="${dest%/none}/$(source)"
    else
      final_dest="$dest"
    fi

    # 필요한 도구가 있는지 확인
    if ! command -v stat &>/dev/null || ! command -v readlink &>/dev/null; then
        RecordLog Error "CollectProc: Required commands (stat or readlink) not found."
        return 1
    fi

    # 실행 가능한 파일의 리스트를 생성
    local exec_files=()
    while read -r pid; do
        local exe_link="/proc/${pid}/exe"
        local target
        if target=$(readlink -f "$exe_link" 2>/dev/null); then
            [[ -n "$target" && -e "$target" ]] && exec_files+=("$target")
        fi
    done < <(ps -e -o pid=)

    # 중복을 제거하고 결과를 파일에 저장
    printf "%s\n" "${exec_files[@]}" | sort | uniq | tar -P -zcf "${final_dest}.tar.gz" -T - && \
    RecordLog Success "CollectProc: Compression of ${final_dest} was successfully." || \
    RecordLog Error "CollectProc: An error occurred in ${final_dest} compression."
}

###############################################################################################################
#9.6 데이터 수집 함수
# config.ini 데이터를 읽어 알맞는 함수에 인자 전달
# Read config.ini data and pass arguments to the appropriate function
# Usage : CollectData
###############################################################################################################
function CollectData() {
  RecordLog Info "Start CollectData"
  # destination path는 dir 경로로 전달되어야함.
  ColorPrint blue "CollectData: Start collecting $systemOS system data"
  RecordLog Info "CollectData: [SystemOS] $systemOS"
  RecordLog Info "CollectData: [SystemVersion] $systemVersion"
  RecordLog Info "CollectData: [HostName] $systemHostName"
  RecordLog Info "CollectData: [IP Address] $systemHostIp"
  RecordLog Info "CollectData: [Mac Address] $systemHostMac"

  local total_tasks=$(( ${#volatitleTasks[@]} + ${#nonVolatitleTasks[@]} ))
  local current_task=0

  # 모든 작업을 하나의 배열로 병합
  all_tasks=("${volatitleTasks[@]}" "${nonVolatitleTasks[@]}")

  # task_types 배열 생성
  local task_types=()
  for i in $(seq 1 ${#volatitleTasks[@]}); do
      task_types+=("Volatile")
  done
  for i in $(seq 1 ${#nonVolatitleTasks[@]}); do
      task_types+=("NonVolatile")
  done

  # 모든 작업을 순회
  for index in "${!all_tasks[@]}"; do
      IFS=',' read -ra components <<< "${all_tasks[$index]}"
      local action="${components[3]}"
      local data=$(echo "${components[4]}" | tr -d '\n\r')
      local currentPath=$(pwd)
      local destPath="$currentPath/$storePath/${components[0]}/${components[1]}/${components[2]}"
      PrintProgressBar $(( (index * 100) / ${#all_tasks[@]} )) "${components[0]} data collection through ${data}"
      case $action in
          cmd)
              RecordLog Info "Start CollectCmd for $data"
              CollectCmd "$data" "$destPath"
              RecordLog Info "End CollectCmd"
              ;;
          file)
              RecordLog Info "Start CollectFile for $data"
              CollectFile "$data" "$destPath"
              RecordLog Info "End CollectFile"
              ;;
          dir)
              RecordLog Info "Start CollectDir for $data"
              CollectDir "$data" "$destPath"
              RecordLog Info "End CollectDir"
              ;;
          function)
              RecordLog Info "Start UserFunction for $data"
              $data "$data" "$destPath"
              RecordLog Info "End $data"
              ;;
          *)
              ;;
      esac
      ((current_task++))
  done
  RecordLog Info "End CollectData"
}
###############################################################################################################
###############################################################################################################
#10. 압축 함수
# 스크립트 파일 실행 경로에 생성된 Result/ 폴더를 압축
# zip 명령을 지원할 경우, password를 포함하여 zip으로 압축 및 무결성 검사 수행
# zip 명령이 없을 경우, tar 명렁어를 활용해 password 없이 압축 진행
# Compress the Result/ folder created in the script file execution path.
# If the zip command is supported, perform compression and integrity checking with zip, including password.
# If there is no zip command, use the tar command to compress without password
# Usage : CompData
###############################################################################################################
function CompData() {
  # $1(password check result)
  RecordLog Info "Start CompData"
  ColorPrint blue "Compressing Collected Informations."

  case "$1" in
    0)
      if command_exists zip; then
        zip -P "$compPassword" -r -q "$resultFile.zip" "./$storePath" 2>/dev/null
        ColorPrint blue "Compression is successfully."
        ColorPrint blue "Compression Integrity Checking..."
        OUTPUT=$(unzip -tP "$compPassword" "$resultFile.zip" 2>&1)
        # 압축파일 무결성 검사
        if echo "$OUTPUT" | grep -q "No errors detected"; then
            ColorPrint blue "Compression Integrity check is Successfully."
            RecordLog Success "CompData: Compression Integrity check is Successfully."
            zip -r -P "$compPassword" "$resultFile.zip" "$collectLog" 2>/dev/null
            SHA256=$(sha256sum "$resultFile.zip" | cut -d ' ' -f1)
            ColorPrint blue "SHA256: $SHA256"
            RecordLog Info "SHA256 of compressed file: $SHA256"
        else
            ColorPrint red "Integrity check error : $OUTPUT" | grep "error:"  # 오류가 발생한 파일을 출력합니다.
            RecordLog Error "CompData: The integrity check of the $OUTPUT file failed."
        fi
      else
        # CollectDir error ($source not exist)
        tar -zcf "$resultFile.tar.gz" "./$storePath" "$collectLog" 2>/dev/null
        ColorPrint blue "Compression was successfully."
        SHA256=$(sha256sum "$resultFile.tar.gz" | cut -d ' ' -f1)
        ColorPrint blue "SHA256: $SHA256"
        RecordLog Info "SHA256 of compressed file: $SHA256"
      fi
      ;;
    255) # User pressed escape
      ColorPrint red "No Compression."
      ;;
    *) # Any other error
      RecordLog Error "CompData: An unknown error occurred during compression."
      ColorPrint red "CompData: An unknown error occurred during compression."
      ;;
  esac
  RecordLog Info "End CompData"
}

###############################################################################################################
#11. 환경 초기화 함수
# 수집 폴더 및 전역 변수 메모리 할당 해제
# Deallocate collection folder and global variable memory
###############################################################################################################
function CleanEnv(){
    # Result 디렉토리 삭제
    rm -rf "$storePath"
    rm -rf "$collectLog"

    # 전역 변수 해제
    unset systemOS
    unset systemVersion
    unset systemHostName
    unset systemHostIp
    unset systemHostMac
    unset storePath
    unset collectLog
    unset systemDate
    unset resultFile
    unset volatitleTasks
    unset nonVolatitleTasks
    unset compPassword
    unset collectSize
    unset availableSize
}
###############################################################################################################
#12. 진행률 표시 함수
# (현재 작업 / 총 작업)에 따라 출력
# output based on (current tasks/total tasks)
# Usage : PrintProgressBar $1(percent value) $2(current processing task name)
###############################################################################################################
function PrintProgressBar() {
  clear
  # $1(percent value) $2(current processing task name)
  Current_Progress=${Current_Progress:-0}
  Param_Progress=${Param_Progress:-0}
  Param_Progress=$1
  Phase=$2
  tmp=$Ignore_echo
  Ignore_echo=0

  # Progress bar 업데이트
  local progress_bar="["
  local total_dots=50
  local filled_dots=$(($Param_Progress * total_dots / 100))
  local remaining_dots=$(($total_dots - filled_dots))

  for ((i=0; i<filled_dots; i++)); do
    progress_bar+="#"
  done
  for ((i=0; i<remaining_dots; i++)); do
    progress_bar+="."
  done
  progress_bar+="]"

  if [[ $Ignore_echo -eq 1 ]]; then
    return
  fi
  text="${progress_bar} ($Param_Progress%) $Phase \r"
  # green
  echo_logo
  echo -ne "\033[1;32m${text}\033[0m"
  sleep 0.2

  echo -ne '\n'

  Ignore_echo=$tmp
  Current_Progress=$Param_Progress

  unset Phase
  unset Param_Progress
  unset tmp
}
###############################################################################################################
#13. Bash버전 확인
# 조건: Bash >= 3.2
# Condition: Bash >= 3.2
# Usage : CheckBash
###############################################################################################################
function CheckBash() {
    local major=$(echo "$BASH_VERSION" | cut -d'.' -f1)
    local minor=$(echo "$BASH_VERSION" | cut -d'.' -f2)

    # Bash 3.2 이상인지 확인합니다.
    if ((major >= 3 && minor >= 2)) || ((major > 3)); then
        return 1
    else
        return 2
    fi
}
###############################################################################################################
#14. 메인 함수
###############################################################################################################
function main()
{
  echo_logo
  # Ctrl+c, Ctrl+z, Ctrl+\ 사용 제한
  #trap '' SIGINT SIGTSTP SIGQUIT
  local messages=""
  # 수집 에러로그 파일 삭제
  rm -rf "$collectLog"

  # 루트 권한 확인
  CheckPermission

  # 시스템 정보 확인
  CheckOS
  local ret=$?
  # 지원하지 않는 OS일 경우
  if [ "$ret" -eq 2 ]; then
    messages="CheckOS: This system is not supported."
    RecordLog Error "$messages"
    ColorPrint red "$messages"
    CleanEnv
    exit 1
  fi

  # Bash 버전이 3.2 이상인가?
  CheckBash
  ret=$?
  # 3.2 미만일 경우
  if [ "$ret" -eq 2 ]; then
    messages="Incompatible Bash version: $BASH_VERSION. This script requires Bash 3.2 or higher."
    RecordLog Error "$messages"
    ColorPrint red "$messages"
    CleanEnv
    exit 1
  fi

  # 사용자 입력을 통한 InitEnv 호출
  echo -e "\e[92m     1. Collect system artifacts\e[0m\n"
  echo -e "\e[92m     2. Collect 3rd-party application artifacts\e[0m\n"
  read -r -p "     Please select an option (1 or 2): " userChoice

  case $userChoice in
    1|2)
      InitEnv "$userChoice"
      ;;
    *)
      ColorPrint red "Invalid option selected."
      exit 1
      ;;
  esac
  ret=$?
  
  # 파일이 없는 경우
  if [ "$ret" -eq 3 ]; then
    messages="InitEnv: Config File does not exist."
    RecordLog Error "$messages"
    ColorPrint red "$messages"
    CleanEnv
    exit 1
  # 설정 파일에 필요 인자가 부족한 경우
  elif [ "$ret" -eq 4 ]; then
    messages="InitEnv: Config File validation failed. Each line must have 5 fields."
    RecordLog Error "$messages"
    ColorPrint red "$messages"
    CleanEnv
    exit 1
  else
    messages="InitEnv: Config File verification is successfully."
    RecordLog Success "$messages"
    ColorPrint green "$messages"
  fi
  sleep 3

  # 수집 대상 파일이 저장될 공간이 충분한지 확인
  CheckDriveSize
  ret=$?
  if [ "$ret" -eq 2 ]; then
    messages="CheckDriveSize: currently insufficient space on the drive to store the collection data. / Collection data size: $collectSize, free space: $availableSize"
    RecordLog Error "$messages"
    ColorPrint red "$messages"
    CleanEnv
    exit 1
  fi

  sleep 3
  clear
  CollectData
  clear
  # 패스워드 인자는 임의로 0000으로 처리, 필요한 경우 아래 주석 해제

  systemDate=$(date '+%Y-%m-%d')
  if [ "$userChoice" == "1" ]; then
    resultFile="${systemDate}_${systemOS}_${systemHostName}_${systemHostIp}"
  else
    resultFile="${systemDate}_${systemOS}_${systemHostName}_${systemHostIp}_3rdParty"
  fi

  CheckPassword
  ret=$?
  CompData "$ret"

  messages="End collecting $systemOS system data !!!"
  RecordLog Info "$messages"
  ColorPrint green "$messages"

  CleanEnv

  trap - SIGINT SIGTSTP SIGQUIT
}
###############################################################################################################
## 프로그램 시작 부
###############################################################################################################
main