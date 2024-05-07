# PLAINBIT Collector: BitCollector
<div align="center">
	<img src="https://github.com/Plainbit/bitColletor/blob/main/Logo.png" />
</div>

<div align="center">
    <img src="https://img.shields.io/badge/Windows-0078D4?style=for-the-badge&logo=Windows" />
    <img src="https://img.shields.io/badge/Visual_Studio-2015-purple?style=for-the-badge&logo=VisualStudio" />
    <img src="https://img.shields.io/badge/CPP-blue?style=for-the-badge&logo=cplusplus&labelColor=006199" />
</div>

## Release
Current Version is [Bitcollector](https://github.com/Plainbit/BitCollector/releases)


## Bitcollector

### Bitcollector Feature
1. 아티팩트 선택적 수집
2. Full Path / Category Path 수집 방식 지원
3. Zip / VHDX 압축
4. VSC 수집 및 중복 제거 삭제 기능
5. 아티팩트 파일을 자유롭게 수정하여 원하는 아티팩트 수집

### Artifacts
```artifacts``` 폴더에 아티팩트 yaml 파일을 기반으로 파일 수집합니다.\
yaml 파일의 이름 구조는 <수집순서>-<아티팩트이름>.yaml 입니다.\
아티팩트 이름에서 띄어쓰기는 "-"로 구분합니다.

#### yaml 예시 1
```yaml
# 01-Prefetch.yaml
Artifact: Prefetch
Description: Artifacts of execution files
Category: Windows
Default: false
Target:
  -
    Name: Prefetch
    Path: C:\Windows\prefetch\
    File: "*.pf"
    IsRecursive: false
  -
    Name: Prefetch (old)
    Path: C:\Windows.old\Windows\prefetch\
    File: "*.pf"
    IsRecursive: false

```

#### yaml 예시 2
```yaml
# 07-User-Account.yaml
Artifact: User account
Description: User account details
Category: Live
Default: true
Process:
  -
    Name: user account
    Path: C:\Windows\System32\cmd.exe
    Command: /c net user
    SaveAs: net_user.txt
```

#### 아티팩트의 수집 순서
Bitcollector에서는 각 아티팩트 별로 수집 순서를 정해 최대한 대상 PC를 원본 상태를 유지해서 수집합니다.
1. Prefetch
2. Application Compatibility (Recentfilecache.bcf and Amcache.hve)
3. Registry
4. Syscache
5. Live 데이터 (netstat 등)
6. NTFS 파일 시스템
7. Event Log
8. Recent Files (lnk 파일)
9. Jumplist
10. SUM
11. Windows Notification / Defender / Search / Startup / Tasks / Timeline / Setup
12. System Config
13. BITS
14. Powershell
15. Recycle Bin
16. Thumbnail Cache
17. Internet Explorer
18. Web Browser (Chrome, Firefox)
19. WER
20. SRUM
21. Memory Files (hiberfil.sys 등)

### Bitcollector: Command
```bash
Bitcollector.exe -h

Usage:
   BitCollector.exe [options]

Options:
  -l, --list        - Show artifact list
  -a                - Select artifact by entering the "artifact" defined in Yaml
  -s                - Set target source
  -o, --output      - Destination folder path to dump after collection
  -df               - Dump Full path format. It is default mode
  -dc               - Dump category format
  -c, --compress    - Designation of compression method after completion of collection ( "ZIP", "VHDX", "NONE"). Default is "NONE"
  -v                - Choose whether to also parse and collect VSC (Volume Shadow Copy)
  -dd               - Removes files with duplicate SHA-256 hash values in VSC compared to the original drive.
  -h, --help        - Show help and usage information


Press enter to continue!
```

### Bitcollector: GUI
<p align="center">
  <img width="70%" height="70%" src="img/Bitcollector-gui.png">
</p>

### 다른 수집 도구 비교
|         **프로그램 이름**        | **수집 속도** | **아티팩트 커스텀** |      **수집 결과**     |  **지원 OS**  | **VSC 수집** | **설정 파일** | **ADS 영역 수집** | **파일 해시** |
|:--------------------------------:|:-------------:|:-------------------:|:----------------------:|:-------------:|:------------:|:-------------:|:-----------------:|:-------------:|
|         **Bitcollector**         |               |          O          |    Raw / ZIP / VHDX    |   Windos XP+  |       O      |      Yaml     |         O         |       O       |
|             **KAPE**             |               |          O          | Raw / ZIP / VHDX / VHD |   Windows 7+  |       O      |     tkape     |         O         |       O       |
|      **Artifact Collector**      |               |          O          | froensicstore (SQLite) | Windows 2000+ |       X      |      yaml     |         X         |       O       |
| **Cyber Triage Collection Tool** |               |          X          |           gz           |  Windows XP+  |       X      |       X       |         X         |       O       |
|        **Magnet RESPONSE**       |               |          X          |       Zip & zdmp       |   Windows 7+  |       X      |       X       |         X         |       X       |


## How to Build
BitCollector는 Visual Studio 2015 (msvc140_xp 필요)로 x86 빌드
> Visual Studio 2015가 없을 시, **Jetbrains Rider** 대체 가능

1. .sln 파일을 VS2015나 Rider로 빌드
2. "Debug" 폴더에 "artifacts" 폴더와 "lib" 폴더 내 DLL 파일들을 추가
