## SubtitleFormatterPS

The script is a PowerShell tool designed for formatting subtitle files with the following features:

### Description
The PowerShell script, `FormatSubtitles.ps1`, processes subtitle files, likely in `.srt` format. It adjusts the length of subtitle lines based on specified parameters, ensuring that subtitles do not exceed a maximum length per line. Additionally, the script offers flexibility by allowing for an adjustable range of characters that subtitles can expand to fit within constraints.

### Key Features
- **Adjustable Line Length**: Ensures subtitles do not exceed the maximum character count per line (`MaxLength`), with optional flexibility for better readability (`FlexibleRange`).
- **Error Handling**: Checks if the provided file exists, preventing errors due to missing files.
- **Output File**: Creates a new subtitle file with a suffix `_labots`, indicating it has been formatted.

### Parameters
- **`-InputFile`**: (Mandatory) Specifies the path of the subtitle file to be formatted.
- **`-MaxLength`**: (Optional) Defines the maximum number of characters allowed per line (default is 35).
- **`-FlexibleRange`**: (Optional) Sets a range for flexible line adjustments (default is 25).

## Usage Instructions

1. **Open PowerShell**: Launch PowerShell on your system.

2. **Run the Script**: Use the following command to run the script with your subtitle file:
   ```powershell
   .\FormatSubtitles.ps1 -InputFile "path\to\your\subtitle.srt" -MaxLength 40 -FlexibleRange 30
