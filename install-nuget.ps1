Param(
    [Parameter(Mandatory = $true)]
    [System.Version] $Version = "4.9.4"
)
try {
 $FilePath = "${ENV:BUILD_BINARIESDIRECTORY}\nuget.exe"
 Invoke-WebRequest "https://dist.nuget.org/win-x86-commandline/v$Version/nuget.exe" -OutFile "$FilePath"
 Write-Host "Nuget version: $Version, downloaded to '$FilePath'."
 Write-Host "##vso[task.setvariable variable=Path;]${ENV:BUILD_BINARIESDIRECTORY};$env:Path"
}catch {Write-Error -Message "Failed to download nuget.exe from $urlPrefix.  $($_.Exception.Message)" -ErrorAction Stop}
