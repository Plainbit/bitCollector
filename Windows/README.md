<div align="center">
    <img src="https://github.com/Plainbit/bitColletor/raw/main/img/Logo.png" />
</div>

<div align="center">
    <img src="https://img.shields.io/badge/Windows-0078D4?style=flat&logo=Windows" />
    <img src="https://img.shields.io/badge/Visual_Studio-2015-purple?style=flat&logo=VisualStudio" />
    <img src="https://img.shields.io/badge/CPP-blue?style=flat&logo=cplusplus&labelColor=006199" />
</div>

# bitCollector for Windows DFIR Toolkit

bitCollector for Windows is a detailed artifact collection tool crafted for digital forensics and incident response on Windows systems. It enables forensic analysts and security professionals to selectively collect vital system artifacts and configurations, aiding in comprehensive investigations and analyses.

### bitCollector for Windows: GUI
<p align="center">
  <img width="70%" height="70%" src="https://github.com/Plainbit/bitColletor/raw/main/img/Bitcollector-gui.png">
</p>

## Features

- **Selective Artifact Collection**: Allows specific artifact collection based on user-defined parameters.
- **Flexible Path Collection**: Supports both full path and category path collection methodologies.
- **Comprehensive Compression Options**: Provides data compression in ZIP or VHDX formats.
- **Volume Shadow Copy Collection and Deduplication**: Offers Volume Shadow Copy collection with options for deduplication to remove duplicate items.
- **Artifact Customization**: Users can modify artifact definitions to tailor collection processes to specific needs.

## Prerequisites

- Windows Operating System, XP or newer
- Visual Studio 2015 for building
- Administrative privileges for full artifact collection

## Usage

### 1. Download the Collector
- Clone the repository or download the latest release from the GitHub repository to your Windows machine.

    ```bash
    git clone https://github.com/Plainbit/bitCollector.git
    cd bitCollector/Windows
    ```

### 2. Build with Visual Studio
- Open the solution file in Visual Studio 2015 and build the project.
  - bitCollector builds x86 with Visual Studio 2015 (requires msvc140_xp)
    - **If you do not have Visual Studio 2015, Jetbrains Rider can be substituted.**

- **Build the .sln file with VS2015 or Rider and add the DLL files in the “artifacts” folder and “lib” folder to the “Debug” folder.**

### 3. Execute the Collector
- Navigate to the compiled output directory and run the executable with desired options.

```bash
bitCollector.exe -h

Usage:
   bitCollector.exe [options]

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

### 4. Check the Output
-  After the collection process completes, check the specified output directory for the collected data.

## Configuration

The Windows DFIR Toolkit uses YAML configuration files for defining artifacts to be collected. These files are located in the `artifacts` directory and can be edited to match specific collection requirements.

### Example YAML Configuration

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
```

#### Collection order of artifacts
- bitCollector for Windows determines the collection order for each artifact and collects the target PC while maintaining its original state as much as possible.
```
1. Prefetch
2. Application Compatibility (Recentfilecache.bcf and Amcache.hve)
3. Registry
4.Syscache
5. Live data (netstat, etc.)
6. NTFS file system
7.Event Log
8. Recent Files (lnk files)
9.Jumplist
10.SUM
11. Windows Notification / Defender / Search / Startup / Tasks / Timeline / Setup
12. System Config
13.BITS
14. Powershell
15. Recycle Bin
16. Thumbnail Cache
17. Internet Explorer
18. Web Browser (Chrome, Firefox)
19.WER
20. SRUM
21. Memory Files (hiberfil.sys, etc.)
```

## Contributing

Contributions to the bitCollector for Windows are welcome. Please submit pull requests or issues through GitHub to propose changes or enhancements.

---
