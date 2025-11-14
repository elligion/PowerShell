# Set-DesktopImage

Set image at image path (with expansion) at PowerShell module.

This module can set your image as walpaper, change WallpaperStyle, and set timer, before the changes are applied.

The repository contains script and module for personal use.

Original script: [Link to StackOverflow](https://stackoverflow.com/questions/28180893/how-to-change-wall-paper-by-using-powershell)

## Additional help
For additional help you can
```PowerShell
Get-Help Set-DesktopImage
```

For reload, you must remove first, then  import module. Important: function Remove-Module doesn't delete module from disk
```PowerShell
Remove-Module Set-DesktopImage
```
```PowerShell
Import-Module Set-DesktopImage
```
