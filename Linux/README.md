<div align="center">
	<img src="https://github.com/Plainbit/bitColletor/raw/main/img/Logo.png" />
</div>

<div align="center">
    <img src="https://img.shields.io/badge/linux-FCC624?style=flat&logo=linux&logoColor=white" />
	<img src="https://img.shields.io/badge/gnubash-4EAA25?style=flat&logo=gnubash&logoColor=white" />
	<img src="https://img.shields.io/badge/visualstudiocode-007ACC?style=flat&logo=visualstudiocode&logoColor=white" />
</div>

# bitCollector for Linux DFIR Triage Collector

bitCollector for Linux  is a comprehensive collection tool designed for digital forensics and incident response activities on Linux systems. It allows forensic analysts and security professionals to collect a wide array of system artifacts and logs, aiding in the investigation and analysis of security incidents.

## Features

- **System Artifact Collection**: Gathers critical system artifacts to provide insights into system usage, configurations, and state.
- **Third-party Application Log Collection**: Extends its collection capabilities to third-party applications, gathering essential logs for a thorough investigation.
- **Versatile Configuration**: Supports configuration via `systemOS.ini` for system artifacts and `3rdParty.ini` for third-party application logs, allowing for flexible and targeted data collection.
- **Compatibility Check**: Ensures compatibility with Bash version 3.2 or higher and checks for required permissions to execute.
- **Secure Data Handling**: Offers options to securely compress and password-protect the collected data, ensuring data integrity and confidentiality.
## Prerequisites

- Linux Operating System
- Bash version 3.2 or higher
- Root access (for comprehensive data collection)

## Usage

1. **Download the Triage Collector**: Clone the repository or download the Triage Collector files to your Linux system.

    ```bash
    git clone https://github.com/Plainbit/bitCollector.git
    cd bitCollector/Linux
    ```

2. **Make the Main Script Executable**: Grant execute permissions to the main script if necessary.

    ```bash
    chmod +x bitCollector.sh
    ```

3. **Execute the Triage Collector**: Run the main script. You will be prompted to select the type of collection you wish to perform.

    ```bash
    sudo ./bitCollector.sh
    ```

    Follow the on-screen instructions to select between:
    
    - `1`: Collect system artifacts.
    - `2`: Collect third-party application logs.

4. **Enter the Password for Data Compression**: If prompted, enter a secure password for compressing the collected data. Ensure the password meets the complexity requirements.

5. **Review the Collected Data**: Upon successful completion, the script will output the location of the compressed data file. Use appropriate tools to decompress and analyze the collected data.

## Configuration

The Linux DFIR Triage Collector is highly customizable through its configuration files, allowing users to tailor the data collection process to their specific needs. The Triage Collector supports two primary types of configuration files: `systemOS.ini` for system artifacts and `3rdParty.ini` for third-party application logs. Here, we focus on the structure and customization of the `systemOS.ini` file, exemplified with a configuration tailored for Raspbian OS.

### Configuration File Structure

Each configuration file consists of entries categorized under named sections (denoted by square brackets `[` `]`), representing the target OS or application suite. Under each section, you can define a series of collection tasks, each on a new line. A collection task is composed of five fields, separated by commas:

1. **Major Category (Volatile/NonVolatile)**: Indicates the nature of the data, with "Volatile" data being temporary and potentially changing across reboots, and "NonVolatile" data being more permanent.
2. **Subcategory**: Further classifies the data under the major category, aiding in the organization of collected artifacts.
3. **Storage File Name**: Specifies the filename under which the collected data will be stored. Use "none" if the task is to execute commands without direct file output.
4. **Collection Type (cmd/file/dir/function)**: Defines the method of collection - executing commands (`cmd`), copying files (`file`), copying directories (`dir`), or invoking custom collection functions (`function`).
5. **Collection Command or Path**: Provides the actual command to execute, or the file/directory path for collection. For commands, ensure proper quoting for arguments containing spaces or special characters.

### Customization Example for Raspbian

```ini
[Raspbian]
Volatile, Logon, last, cmd, last
Volatile, Logon, lastb, cmd, lastb
Volatile, OS, release, cmd, cat /etc/*release*
...
NonVolatile, Log, none, dir, /var/log/
NonVolatile, History, none, file, /home/*/.bash_history
NonVolatile, RootDir, none, dir, /root/
```
### Extending with Custom Functions

bitCollector's flexibility extends to the integration of custom functions, facilitating the collection of specialized data beyond predefined configurations. This feature allows forensic analysts to craft tailored functions that capture specific system or application insights critical to their investigations.

#### Example: Process Executable Collection

One practical application of custom functions is the gathering of executables associated with running processes. This can be instrumental in understanding the runtime environment of a system during an incident. Here's how a custom function for this purpose (`CollectProc`) could be defined and utilized within bitCollector:

```bash
function CollectProc() {
    local dest="$1"
    # Additional logic to gather executables of running processes
    # ...
    # Use the 'dest' argument to specify where to store the collected data
}
```

To employ this custom function within a collection operation, it's referenced in the configuration file like so:

```
Volatile, Process, none, function, CollectProc
```

### Adding New Tasks

1. Identify the category and subcategory appropriate for the data you wish to collect.
2. Decide on the storage file name and the collection type.
3. Provide the necessary command or path for the task.

## Contributing

Contributions to the bitCollector for Linux are welcome. Please submit pull requests or issues through GitHub to propose changes or enhancements.

---
