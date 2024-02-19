param(
    [Alias("u")]
    [string]$url = "",

    [Alias("w")]
    [string]$wordlistPath = "db/dicc.txt",

    [Alias("e")]
    [string[]]$extensions = @("php", "aspx", "jsp", "html", "js"),

    [Alias("x")]
    [string]$excludeStatus = "404",

    [string]$customHeader,
    [string]$includeStatus = "",
    
    [string]$ExcludeSizes = "",

    [int]$threads = 10,

    [switch]$Help
)

function Show-HelpDocumentation {
    Write-Host "`nUsage:" -ForegroundColor Cyan
    Write-Host "    -u <URL>" -ForegroundColor Yellow
    Write-Host "        The target URL to scan." -ForegroundColor White
    Write-Host "    -w <Wordlist Path>" -ForegroundColor Yellow
    Write-Host "        The path to the wordlist file. Default is 'db/dicc.txt'." -ForegroundColor White
    Write-Host "    -e <Extensions>" -ForegroundColor Yellow
    Write-Host "        Comma-separated list of file extensions to check. Default is 'php,aspx,jsp,html,js'." -ForegroundColor White
    Write-Host "    -x <Exclude Status>" -ForegroundColor Yellow
    Write-Host "        Comma-separated list of HTTP status codes to exclude from the output. Default is '404'." -ForegroundColor White
    Write-Host "    -threads <Number>" -ForegroundColor Yellow
    Write-Host "        Number of threads to use. Default is 10." -ForegroundColor White
    Write-Host "    -ExcludeSizes SIZES" -ForegroundColor Yellow
    Write-Host "        Exclude responses by sizes, separated by commas (e.g. 0B,4KB)." -ForegroundColor White
    Write-Host ""
    Write-Host "Example:" -ForegroundColor Cyan
    Write-Host "    .\dirsearch.ps1 -u https://example.com -w db/dicc.txt -e php,html,js -x 404,500 -ExcludeSizes ""873B""" -ForegroundColor Green
    exit
}

# Check for help request or no parameters
if (-not $url) {
    Write-Host "URL target is missing, try using -u <url>." -ForegroundColor Red
    Show-HelpDocumentation
    exit
}
function Get-SizeInBytes {
    param([string]$size)
    switch -Regex ($size) {
        '(\d+)KB' { return [int]$matches[1] * 1KB }
        '(\d+)MB' { return [int]$matches[1] * 1MB }
        '0B' { return 0 }
        Default { return $null }
    }
}

# Convert excluded sizes from string to an array of byte values
function Get-ExcludedSizesToBytes {
    param(
        [string] $ExcludeSizes
    )
    $bytesArray = @()
    foreach ($size in $ExcludeSizes -split ',') {
        switch -Regex ($size.Trim()) {
            '(\d+)B$'  { $bytesArray += [int]$matches[1] }
            '(\d+)KB$' { $bytesArray += [int]$matches[1] * 1KB }
            '(\d+)MB$' { $bytesArray += [int]$matches[1] * 1MB }
        }
    }
    return $bytesArray
}

$excludedSizeBytes = Get-ExcludedSizesToBytes -ExcludeSizes $ExcludeSizes
#Write-Host "Excluded sizes in bytes: $($excludedSizeBytes -join ', ')"
#Write-Host "User input: $ExcludeSizes"
function Get-StatusCodes {
    param([string]$codes)
    $result = @()
    foreach ($code in $codes -split ",") {
        if ($code -contains "-") {
            $range = $code -split "-"
            $result += [int]$range[0]..[int]$range[1]
        } else {
            $result += $code
        }
    }
    return $result
}

function Get-Size {
    param([string]$sizes)
    $result = @()
    foreach ($size in $sizes -split ",") {
        if ($size -match "(\d+)(KB|MB)") {
            $value = [int]$matches[1]
            switch ($matches[2]) {
                "KB" { $result += $value * 1KB }
                "MB" { $result += $value * 1MB }
            }
        } elseif ($size -eq "0B") {
            $result += 0
        }
    }
    return $result
}
function Format-Size {
    param([int]$Bytes)
    if ($Bytes -ge 1MB) {
        return '{0:N2}MB' -f ($Bytes / 1MB)
    } elseif ($Bytes -ge 1KB) {
        return '{0:N0}KB' -f ($Bytes / 1KB)
    } else {
        return '{0:N0}B' -f $Bytes
    }
}
$excludeStatusCodes = Get-StatusCodes $excludeStatus
$excludeSizes = Get-Size $excludeSizes
$userAgents = Get-Content -Path "db/user-agents.txt"
$randomUserAgent = $userAgents | Get-Random
$headers = @{}
if ($customHeader) {
    $headerParts = $customHeader -split ':', 2
    $headers[$headerParts[0]] = $headerParts[1]
}

$paths = Get-Content -Path $wordlistPath
$extensionArray = $extensions -split ','
$extensionArray += "" # Include paths without extensions
$wordlistSize = $paths.Count
$totalRequests = $paths.Count * ($extensionArray.Count)

# Initial output with color coding
# Define ANSI escape sequences for bold text
$esc = [char]27
$bold = "${esc}[1m"
$reset = "${esc}[0m"
$magenta = "${esc}[35m"

# Define the text
$text = @"
  _|. _ _  _  _  _ _|_    vR0b0t3d1t10n
 (_||| _) (/_(_|| (_| )
"@

# Output text with magenta formatting
Write-Host "`n$bold$magenta$text$reset`n"
$extensionsWithSpace = $extensions -replace ",", ", "

# Output text with bold formatting
Write-Host -NoNewline "${bold}Extensions: $reset" -ForegroundColor Yellow
Write-Host -NoNewline ${bold}$extensionsWithSpace$reset -ForegroundColor Cyan
Write-Host -NoNewline "$bold | $reset" -ForegroundColor Magenta
Write-Host -NoNewline "${bold}HTTP method:$reset" -ForegroundColor Yellow
Write-Host -NoNewline "${bold} GET$reset" -ForegroundColor Cyan
Write-Host -NoNewline "$bold | $reset" -ForegroundColor Magenta
Write-Host -NoNewline "${bold}Threads: $reset" -ForegroundColor Yellow
Write-Host -NoNewline ${bold}$threads$reset -ForegroundColor Cyan
Write-Host -NoNewline "$bold | $reset" -ForegroundColor Magenta
Write-Host -NoNewline "${bold}Wordlist size: $reset" -ForegroundColor Yellow
Write-Host -NoNewline ${bold}$wordlistSize$reset -ForegroundColor Cyan
Write-Host -NoNewline "$bold | $reset" -ForegroundColor Magenta
Write-Host -NoNewline "${bold}Total Requests: $reset" -ForegroundColor Yellow
Write-Host ${bold}$totalRequests$reset -ForegroundColor Cyan

Write-Host -NoNewline `n${bold}"Target: "$reset -ForegroundColor Yellow
Write-Host -NoNewline ${bold}$url$reset`n`n -ForegroundColor Cyan
$current_time = Get-Date -Format "HH:mm:ss"
Write-Host -NoNewline "$bold[$current_time] Starting:$reset`n" -ForegroundColor Yellow

$runspacePool = [runspacefactory]::CreateRunspacePool(1, $threads)
$runspacePool.Open()
$runspaces = @()
$allResults = New-Object System.Collections.ArrayList

# Initialize a HashSet to track processed URLs
$processedUrls = New-Object System.Collections.Generic.HashSet[string]

foreach ($path in $paths) {
    foreach ($extension in $extensionArray) {
        # Determine if the path ends with a slash, indicating it's likely a directory
        if ($path -notmatch '/$') {
            # Path does not end with a slash - safe to add extension
            $testPath = if ($extension -eq "") { $path } else { "$path.$extension" }
        } else {
            # Path ends with a slash - skip adding extension
            $testPath = $path
        }

        # Check if the first character of the path is a forward slash
        if ($path.StartsWith('/')) {
            # Craft $fullUrl as $url$testPath to avoid double slashes
            $fullUrl = $url + $testPath
        } else {
            $fullUrl = "$url/$testPath"
        }

        # Normalize URL to ensure consistent formatting
        $normalizedUrl = $fullUrl -replace '(?<=https?:)/+', '/' -replace '/+', '/'

        # Check if the URL has already been processed
        if (-not $processedUrls.Add($normalizedUrl.ToLower())) {
            continue
        }

        $powershell = [powershell]::Create().AddScript({
            param($fullUrl, $userAgent, $headers, $excludeStatusCodes, $excludeSizes)
            $result = @{}
            try {
                $response = Invoke-WebRequest -Uri $fullUrl -Method Get -UserAgent $userAgent -Headers $headers
                $result['URL'] = $fullUrl
                $result['Status'] = $response.StatusCode
                $result['SizeBytes'] = $response.RawContentLength
                $result['Time'] = Get-Date -Format "HH:mm:ss"
                if ($response.StatusCode -eq 301 -or $response.StatusCode -eq 302) {
                    $result['LocationHeader'] = $response.Headers['Location']
                }
            } catch {
                $result = @{}
                $result['URL'] = $fullUrl
                $result['Error'] = "Failed to fetch"
                $result['Time'] = Get-Date -Format "HH:mm:ss"
                if ($_.Exception -is [System.Net.WebException] -and $_.Exception.Response) {
                    $response = $_.Exception.Response
                    $statusCode = [int]$response.StatusCode.value__
                    $result['Status'] = $statusCode
                    # Attempt to get the content length from the response, even in the event of an error
                    $contentLength = $response.Headers["Content-Length"]
                    $result['SizeBytes'] = if ($contentLength -ne $null) { $contentLength } else { 0 }
                } else {
                    $statusCode = 0
                    $result['Status'] = $statusCode
                    $result['SizeBytes'] = 0
                }
                
                # Correctly constructing the PSObject
                $resultObject = New-Object -TypeName PSObject -Property $result
                [void]$allResults.Add($resultObject)
            }
            
            return $result
        }).AddArgument($fullUrl).AddArgument($randomUserAgent).AddArgument($headers).AddArgument($excludeStatusCodes).AddArgument($excludeSizes)

        $powershell.RunspacePool = $runspacePool
        $runspaces += @{
            Pipe = $powershell
            Status = $powershell.BeginInvoke()
        }
    }
}

foreach ($runspaceInfo in $runspaces) {
    $result = $runspaceInfo.Pipe.EndInvoke($runspaceInfo.Status)
    $runspaceInfo.Pipe.Dispose()

    foreach ($output in $result) {
        # Convert the response size for the current output to bytes for comparison
        $currentSizeBytes = $output.SizeBytes
        #Write-Host "Current size: $currentSizeBytes, Excluded: $excludedSizeBytes"
        # Check if the current response size is in the list of excluded sizes
        if ($excludedSizeBytes -contains $currentSizeBytes) {
            continue
        }

        if ($output.Status -notin $excludeStatusCodes) {
            $uri = New-Object System.Uri($output.URL)
            $sizeDisplay = Format-Size -Bytes $output.SizeBytes
            
            # Determine the color and message based on the status code
            $color = switch ($output.Status) {
                200 { "Green" }
                301 { "Cyan" } 
                302 { "Cyan" }
                404 { "Yellow" }
                500 { "Red"; break }
                Default { "White" }
            }

            # Custom output for 500 status code
            if ($output.Status -eq 500) {
                Write-Host "[$($output.Time)] 500 - $sizeDisplay - $($uri.AbsolutePath)" -ForegroundColor Red
            }
            elseif ($output.Error) {
                # error message for other errors
                Write-Host "[$($output.Time)] $($output.Status) - $sizeDisplay - Unknown Endpoint Error for $($uri.AbsolutePath)" -ForegroundColor Red
            }
            else {
                # Output for successful responses or other status codes
                Write-Host "[$($output.Time)] $($output.Status) - $sizeDisplay - $($uri.AbsolutePath) $($output.LocationHeader)" -ForegroundColor $color
            }
        }
    }
}

$runspacePool.Close()
Write-Host -NoNewline `n$bold"Task Completed"$reset`n -ForegroundColor Yellow
