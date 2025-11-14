## v 1.0.1
function Set-DesktopImage {
<#
 .SYNOPSIS
  Set image at image path (with expansion) at PowerShell module

 .DESCRIPTION
  v. 1
  Set image at image path (with expansion) at PowerShell module. 
  This module can set your image as walpaper, change WallpaperStyle, and set timer, before the changes are applied.
  Original script: https://stackoverflow.com/questions/28180893/how-to-change-wall-paper-by-using-powershell

 .PARAMETER ImagePath
  [MANDATORY]
  The full path to your image. 
  WARNING! 
  You must set full path with exapnsion of file! 
  You can do this by right-clicking on the file and clicking "Copy as path"

 .PARAMETER WaitBefore
  Set timer, before the changes are applied. This parameter in second.

 .PARAMETER WallpaperStyle
  [ValidateSet]
  Change wallpaper style. For usage only the specified list of options is allowed:
        Fill
        Fit
        Stretch
        Center

 .EXAMPLE
   # Basicly set image
   Set-DesktopImage -ImagePath "C:\Path\To\Your\Image.jpg"

 .EXAMPLE
   # Set image with delay
   Set-DesktopImage -ImagePath "C:\Path\To\Your\Image.jpg" -WaitBefore 30

 .EXAMPLE
   # Set image with wallpaper style
   Set-DesktopImage -ImagePath "C:\Path\To\Your\Image.jpg" -WaitBefore 30 -WallpaperStyle Center
#>
    param (
        [Parameter(mandatory=$true)][string]$ImagePath,
        [Parameter(Mandatory=$false)][int16]$WaitBefore = 0,
        [Parameter(Mandatory=$false)]
            [ValidateSet("Fill","Fit","Stretch","Center")]$WallpaperStyle="Fill"
    )
## Start dealy
Write-Host "Waitng before start $WaitBefore second ..."
Start-Sleep -Seconds $WaitBefore


## Start desktop changing
Write-Host "Applying desktop image ..."
[int]$WallpaperStyleCode = 0
switch ($WallpaperStyle) {
    "Fill"{
        $WallpaperStyleCode = 10
    }
    "Fit" {
        $WallpaperStyleCode = 6
    }
    "Stretch" {
        $WallpaperStyleCode = 2
    }
    "Center" {
        $WallpaperStyleCode = 0
    } 
}

## Set WallpaperType "Fill"
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -Value $WallpaperStyleCode
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "TileWallpaper" -Value 0

## Call funstion desktop change image
Add-Type -TypeDefinition @" 
using System; 
using System.Runtime.InteropServices;

public class Params
{ 
    [DllImport("User32.dll",CharSet=CharSet.Unicode)] 
    public static extern int SystemParametersInfo (Int32 uAction, 
                                                   Int32 uParam, 
                                                   String lpvParam, 
                                                   Int32 fuWinIni);
}
"@ 

## Set Parameters and start function
$SPI_SETDESKWALLPAPER = 0x0014
$UpdateIniFile = 0x01
$SendChangeEvent = 0x02

$fWinIni = $UpdateIniFile -bor $SendChangeEvent 

$Result = [Params]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $ImagePath, $fWinIni)

if ($Result -eq 1) {
    Write-Host Well done!
}
}
Export-ModuleMember -Function Set-DesktopImage