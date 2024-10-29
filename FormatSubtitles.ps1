param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,
    [Parameter(Mandatory = $false)]
    [int]$MaxLength = 35,
    [Parameter(Mandatory = $false)]
    [int]$FlexibleRange = 25
)

# Pārbaudām vai fails eksistē
if (-not (Test-Path $InputFile)) {
    Write-Error "Fails '$InputFile' nav atrasts!"
    exit 1
}

# Izveidojam jauna faila nosaukumu
$FileInfo = Get-Item $InputFile
$OutputFile = [System.IO.Path]::Combine(
    $FileInfo.DirectoryName,
    [System.IO.Path]::GetFileNameWithoutExtension($FileInfo.Name) + "_labots" + $FileInfo.Extension
)

function Convert-TimeToMilliseconds {
    param (
        [string]$timeString
    )
    
    if ($timeString -match "(\d{2}):(\d{2}):(\d{2}),(\d{3})") {
        $hours = [int]$Matches[1]
        $minutes = [int]$Matches[2]
        $seconds = [int]$Matches[3]
        $milliseconds = [int]$Matches[4]
        
        return ($hours * 3600000) + ($minutes * 60000) + ($seconds * 1000) + $milliseconds
    }
    
    # Write-Warning "Nekorekts laika formāts: $timeString"
    return 0
}

function Convert-MillisecondsToTime {
    param (
        [long]$milliseconds
    )
    
    $hours = [math]::Floor($milliseconds / 3600000)
    $remainingMilliseconds = $milliseconds % 3600000
    $minutes = [math]::Floor($remainingMilliseconds / 60000)
    $remainingMilliseconds = $remainingMilliseconds % 60000
    $seconds = [math]::Floor($remainingMilliseconds / 1000)
    $ms = $remainingMilliseconds % 1000

    # Formatējam ar padded zeros
    $hoursStr = $hours.ToString("00")
    $minutesStr = $minutes.ToString("00")
    $secondsStr = $seconds.ToString("00")
    $msStr = $ms.ToString("000")
    
    return "$hoursStr`:$minutesStr`:$secondsStr,$msStr"
}

function Split-LineAtBestPosition {
    param(
        [string]$line,
        [int]$maxLength
    )

    if ($line.Length -le $maxLength) {
        return @($line)
    }

    # Meklējam viduspunktu, ja rinda ir maxLength līdz maxLength+FlexibleRange gara
    if ($line.Length -le ($maxLength + $FlexibleRange)) {
        $middlePosition = [math]::Floor($line.Length / 2)
        $searchStart = [math]::Max(0, $middlePosition - 10)
        $searchEnd = [math]::Min($line.Length, $middlePosition + 15)
        $searchText = $line.Substring($searchStart, $searchEnd - $searchStart)
        
        # Meklējam tuvāko punktu, komatu vai atstarpi vidusdaļā (prioritātes secībā)
        $dotPos = $searchText.IndexOf('.')
        $commaPos = $searchText.IndexOf(',')
        $colonPos = $searchText.IndexOf(':')
        $spacePos = $searchText.IndexOf(' ')
        
        $splitPos = if ($dotPos -ne -1) {
            $searchStart + $dotPos + 1  # +1 lai iekļautu punktu pirmajā daļā
        }
        elseif ($commaPos -ne -1) {
            $searchStart + $commaPos + 1  # +1 lai iekļautu komatu pirmajā daļā
        }
        elseif ($colonPos -ne -1) {
            $searchStart + $colonPos + 1  # +1 lai iekļautu komatu pirmajā daļā
        }
        elseif ($spacePos -ne -1) {
            $searchStart + $spacePos
        }
        else {
            $middlePosition
        }

        return @(
            $line.Substring(0, $splitPos).TrimEnd(),
            $line.Substring($splitPos).TrimStart()
        )
    }

    # Standarta dalīšana garām rindām
    $lastDotPos = $line.Substring(0, [Math]::Min($line.Length, $maxLength)).LastIndexOf('.')
    $lastCommaPos = $line.Substring(0, [Math]::Min($line.Length, $maxLength)).LastIndexOf(',')
    $lastColonPos = $line.Substring(0, [Math]::Min($line.Length, $maxLength)).LastIndexOf(':')
    $lastSpacePos = $line.Substring(0, [Math]::Min($line.Length, $maxLength)).LastIndexOf(' ')
    
    if ($lastDotPos -gt 0) {
        $firstPart = $line.Substring(0, $lastDotPos + 1).TrimEnd()  # +1 lai iekļautu punktu
        $remainingPart = $line.Substring($lastDotPos + 1).TrimStart()
    }
    elseif ($lastCommaPos -gt 0) {
        $firstPart = $line.Substring(0, $lastCommaPos + 1).TrimEnd()  # +1 lai iekļautu komatu
        $remainingPart = $line.Substring($lastCommaPos + 1).TrimStart()
    }
    elseif ($lastColonPos -gt 0) {
        $firstPart = $line.Substring(0, $lastColonPos + 1).TrimEnd()  # +1 lai iekļautu komatu
        $remainingPart = $line.Substring($lastColonPos + 1).TrimStart()
    }
    elseif ($lastSpacePos -gt 0) {
        $firstPart = $line.Substring(0, $lastSpacePos).TrimEnd()
        $remainingPart = $line.Substring($lastSpacePos + 1).TrimStart()
    }
    else {
        $firstPart = $line.Substring(0, $maxLength)
        $remainingPart = $line.Substring($maxLength)
    }

    $result = @($firstPart)
    if ($remainingPart.Length -gt 0) {
        $result += Split-LineAtBestPosition -line $remainingPart -maxLength $maxLength
    }
    
    return $result
}

function Count-Words {
    param (
        [string]$text
    )
    
    return ($text.Trim() -split '\s+').Count
}


function Parse-SrtFile {
    param (
        [string]$content
    )
    
    $subtitles = @()
    $currentSubtitle = @{
        Number    = ""
        StartTime = ""
        EndTime   = ""
        Text      = [System.Collections.ArrayList]@()
    }
    
    $lines = $content -split "`r`n|`n"
    $state = "number"
    
    foreach ($line in $lines) {
        $line = $line.Trim()
        
        if ([string]::IsNullOrEmpty($line)) {
            if ($currentSubtitle.Number -ne "") {
                $subtitles += $currentSubtitle
                $currentSubtitle = @{
                    Number    = ""
                    StartTime = ""
                    EndTime   = ""
                    Text      = [System.Collections.ArrayList]@()
                }
            }
            $state = "number"
            continue
        }
        
        switch ($state) {
            "number" {
                $currentSubtitle.Number = $line
                $state = "timing"
            }
            "timing" {
                if ($line -match "(\d{2}:\d{2}:\d{2},\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2},\d{3})") {
                    $currentSubtitle.StartTime = $Matches[1]
                    $currentSubtitle.EndTime = $Matches[2]
                }
                $state = "text"
            }
            "text" {
                [void]$currentSubtitle.Text.Add($line)
            }
        }
    }
    
    if ($currentSubtitle.Number -ne "") {
        $subtitles += $currentSubtitle
    }
    
    return $subtitles
}


# Pievienojiet šo pirms Format-SrtFile izsaukuma:
$subtitles | ForEach-Object {
    Write-Host "DEBUG: Processing subtitle:"
    Write-Host "Number: $($_.Number)"
    Write-Host "Time: $($_.StartTime) --> $($_.EndTime)"
    Write-Host "Text:" 
    $_.Text | ForEach-Object { Write-Host "`t$_" }
    Write-Host "---"
}



# Pārveidotā Format-SrtFile funkcija ar debug info un labojumiem
function Format-SrtFile {
    param (
        [array]$subtitles,
        [int]$maxLength,
        [int]$flexibleRange
    )
    
    $output = [System.Collections.ArrayList]@()
    $newSubtitleNumber = 1
    
    foreach ($subtitle in $subtitles) {
        foreach ($textLine in $subtitle.Text) {
            if ($textLine.Length -gt $maxLength) {
                Write-Host "Processing long line: $textLine"
                $splitLines = Split-LineAtBestPosition -line $textLine -maxLength $maxLength
                
                if ($textLine.Length -le ($maxLength + $flexibleRange)) {
                    Write-Host "Line is within flexible range, keeping in one subtitle"
                    [void]$output.Add($newSubtitleNumber)
                    [void]$output.Add("$($subtitle.StartTime) --> $($subtitle.EndTime)")
                    foreach ($line in $splitLines) {
                        [void]$output.Add($line)
                    }
                    [void]$output.Add("")
                    $newSubtitleNumber++
                }
                else {
                    # Optimizējam sadalītās rindas
                    $optimizedLines = [System.Collections.ArrayList]@()
                    $tempLine = ""
                    
                    foreach ($line in $splitLines) {
                        if ([string]::IsNullOrEmpty($tempLine)) {
                            $tempLine = $line
                        }
                        else {
                            $combinedLine = "$tempLine $line"
                            if ($combinedLine.Length -le ($maxLength + $flexibleRange)) {
                                $tempLine = $combinedLine
                            }
                            else {
                                [void]$optimizedLines.Add($tempLine)
                                $tempLine = $line
                            }
                        }
                    }
                    
                    if (-not [string]::IsNullOrEmpty($tempLine)) {
                        [void]$optimizedLines.Add($tempLine)
                    }
                    
                    # Aprēķinām laika intervālus
                    $startMs = Convert-TimeToMilliseconds -timeString $subtitle.StartTime
                    $endMs = Convert-TimeToMilliseconds -timeString $subtitle.EndTime
                    $totalDuration = $endMs - $startMs
                    $timePerLine = [math]::Floor($totalDuration / $optimizedLines.Count)
                    
                    Write-Host "Creating $($optimizedLines.Count) subtitles from $totalDuration ms"
                    
                    for ($i = 0; $i -lt $optimizedLines.Count; $i++) {
                        [void]$output.Add($newSubtitleNumber)
                        
                        $lineStartMs = $startMs + ($i * $timePerLine)
                        $lineEndMs = if ($i -eq $optimizedLines.Count - 1) {
                            $endMs
                        }
                        else {
                            $lineStartMs + $timePerLine
                        }
                        
                        $startTimeStr = Convert-MillisecondsToTime -milliseconds $lineStartMs
                        $endTimeStr = Convert-MillisecondsToTime -milliseconds $lineEndMs
                        $finalLines = Split-LineAtBestPosition -line $optimizedLines[$i] -maxLength $maxLength

                        [void]$output.Add("$startTimeStr --> $endTimeStr")
                        [void]$output.Add($finalLines)
                        [void]$output.Add("")
                        
                        $newSubtitleNumber++
                    }
                }
            }
            else {
                [void]$output.Add($newSubtitleNumber)
                [void]$output.Add("$($subtitle.StartTime) --> $($subtitle.EndTime)")
                [void]$output.Add($textLine)
                [void]$output.Add("")
                $newSubtitleNumber++
            }
        }
    }
    
    return $output
}



# Nolasām failu
$content = Get-Content $InputFile -Raw -Encoding UTF8

# Parsējam SRT failu
$subtitles = Parse-SrtFile -content $content

# Formatējam subtitrus
$formattedContent = Format-SrtFile -subtitles $subtitles -maxLength $MaxLength -flexibleRange $FlexibleRange

# Saglabājam rezultātu
$formattedContent | Out-File $OutputFile -Encoding UTF8

Write-Host "Fails veiksmīgi apstrādāts! Rezultāts saglabāts: $OutputFile"