Create this file: 'JumperShell_Config.txt' and write: sourcePath= followed by the path to the directory where you put the script
Make sure to place the file in your %LOCALAPPDATA% folder.

Script wont run properly otherwise as its PATH variables are dependant on it.

# NOTE: 
You might have to change Executionpolicy settings with: Set-ExecutionPolicy Bypass (or-thelike) to be able to run this.
It's also possible that you may have to run PowerShell first, not just run with powershell on Right Click.

So if you launch PowerShell, find the directory you placed your file in with the "cd" function.
From there, run with & .\JumperShell.ps1 OR if you want to edit maps, use: & .\LevelCreator.ps1

# NOTE:
You may need to launch PowerShell as Administrator.
"Set-ExecutionPolicy" SCOPE may need to be set to Current User with:
Set-ExecutionPolicy -Scope CurrentUser

Good luck!

