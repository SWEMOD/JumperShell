
if ((Test-Path -Path "$ENV:LOCALAPPDATA\JumperShell_Config.txt") -ne $true) {
    Write-Host "[ERROR] Create this file: '$ENV:LOCALAPPDATA\JumperShell_Config.txt' and write: sourcePath= followed by the path to the script"
    return
}

function ConsoleLog {
    param (
        [parameter(mandatory=$true)]$Type,
        [parameter(mandatory=$true)][string]$Msg
    )
    switch ($Type){
        1 {
            $date = $((Get-Date).ToString("HH:mm:ss"))
            $msgVar = Get-Variable | Select-Object Name, Value | Where-Object { $_.Name -like $Msg }
            Write-Host "$date " -NoNewline -ForegroundColor White
            Write-Host "[DEBUG]: " -NoNewline -ForegroundColor Cyan
            Write-Host "$($msgVar.Name) " -NoNewline -ForegroundColor Yellow
            if ($msgVar.Value -eq $true) {
                Write-Host "$($msgVar.Value)" -ForegroundColor Green
            } else {
                Write-Host "$($msgVar.Value)" -ForegroundColor Red
            }
        } # Debug
        #default {return}
        
    }
}

# JumperShell
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


# File structure..
<# .\JumperShell        #> $sourcePath = (((Get-Content "$ENV:LOCALAPPDATA\JumperShell_Config.txt") | Where-Object {$_ -like "sourcePath=*"}) -split "=",2)[1]
<# |--- JumperShell.ps1 #> $scriptPath = Join-Path -Path $sourcePath "JumperShell.ps1"
<# |----- Textures      #> $texturesPath = Join-Path -Path $sourcePath "Textures"
<# |----- Textures      #> $levelsPath = Join-Path -Path $sourcePath "levels"

function Show-Form {
    param(
        $form
    )
    [void]$form.ShowDialog()

}

function IsGrounded {
    if ($script:playerY -ge $floorY) {
        return $true
    }

    foreach ($plat in $platforms) {
        $platTop = $plat.y
        $platLeft = $plat.x
        $platRight = $plat.x + $plat.width
        $playerBottom = $script:playerY + $playerHeight

        if (
            $playerBottom -ge $platTop - 5 -and
            $playerBottom -le $platTop + 10 -and
            $script:playerX + $playerWidth -gt $platLeft -and
            $script:playerX -lt $platRight
        ) {
            return $true
        }
    }

    $playerCenterX = $script:playerX + ($playerWidth / 2)
    $playerCenterY = $script:playerY + ($playerHeight / 2)

    $inAnyZone = $false

    foreach ($zone in $script:airJumpZones) {
        $dx = $playerCenterX - $zone.x
        $dy = $playerCenterY - $zone.y
        $distance = [math]::Sqrt(($dx * $dx) + ($dy * $dy))

        if ($distance -le $zone.radius) {
            $inAnyZone = $true
            if (-not $zone.used) {
                $zone.used = $true
                return $true
            } else {
                return $false
            }
        }
    }

    # Om vi inte är i någon zon, nollställ alla
    if (-not $inAnyZone) {
        foreach ($zone in $script:airJumpZones) {
            $zone.used = $false
        }
    }

    return $false
}


# Window settings
[int]$window_Width = 1280
[int]$window_Height = 975
[System.Windows.Forms.Application]::EnableVisualStyles() # if OS isn't fucking win 95 it's better window than that
$window = [System.Windows.Forms.Form]::New()
$window.Size = [System.Drawing.Size]::New($window_Width,$window_Height)
$window.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$window.MaximizeBox = $false
$window.StartPosition = "CenterScreen"
$window_Background_1 = [System.Drawing.Image]::FromFile("$texturesPath\Base_Background.png")
$window.KeyPreview = $true
$window.ShowIcon = $false
$window.Text = "JumperShell"
#######################

# A N T I - F U C K I N G - E P I L E P S I
# ngl, this makes it not flicker like a motherfucker, don't delete. Backup is saved in .txt file
# "F:\PowerShell Tools\JumperShell\backUp\DoubleBuffer.txt"
$doubleBufferedProperty = $window.GetType().GetProperty("DoubleBuffered", [Reflection.BindingFlags] "Instance, NonPublic")
$doubleBufferedProperty.SetValue($window, $true, $null)
$backBuffer = New-Object System.Drawing.Bitmap $window_Width, $window_Height
##############

# Player
$playerImage = [System.Drawing.Image]::FromFile("$texturesPath\Player_Shell.png")
[int]$script:playerX = 600 #placement x axis
[int]$script:playerY = 800 #placement y axis
[int]$speedX = 12.5  # Movement speed
[int]$jumpVelocity = -26 # jump height
[int]$playerWidth = $playerImage.Width 
[int]$playerHeight = $playerImage.Height
$playerBottom = $script:playerY + $playerHeight

<# Air Jump Zone (circular zone for jump reset mid-air)
$script:airJumpZones = @(
    @{ x = 720; y = 400; radius = 17; used = $false },
    @{ x = 400; y = 600; radius = 17; used = $false }
) #>


$window.Add_Paint({
    param($sender, $e)
    $gfx = [System.Drawing.Graphics]::FromImage($backBuffer) # <-- Background
    $gfx.DrawImage($window_Background_1, 0, 0)

    # Draw platforms
    foreach ($plat in $platforms) {
        $gfx.DrawImage($platformTexture, $plat.x, $plat.y, $plat.width, $plat.height)
    }

    $gfx.DrawImage($playerImage, $script:playerX, $script:playerY) # <-- Player

    # air jump zones
    foreach ($zone in $script:airJumpZones) {
        $pen = [System.Drawing.Pen]::New([System.Drawing.Color]::FromArgb(120, 255, 255, 255), 2)
        $gfx.DrawEllipse($pen, $zone.x - $zone.radius, $zone.y - $zone.radius, $zone.radius * 2, $zone.radius * 2)
        $pen.Dispose()
    }



    $gfx.Dispose() # dispose to make powershell less of a laggy mess

    $e.Graphics.DrawImage($backBuffer, 0, 0) # draw to screen position 0,0 is also part of the "anti fucking epilepsi" thing
})


# Track key states
$script:isLeftPressed = $false
$script:isRightPressed = $false
$script:isJumping = $false
$onPlatform = $false

# Input hanlder
$window.Add_KeyDown({
    param($sender, $e)
    switch ($e.KeyCode) {
        'A'  { $script:isLeftPressed = $true }
        'D'  { $script:isRightPressed = $true }
        'Space' {
            if (-not $script:isJumping -and (IsGrounded -or $script:canAirJump)) {
                $script:velocityY = $jumpVelocity
                $script:isJumping = $true

                if (-not (IsGrounded)) {
                    #$script:velocityY = $jumpVelocity
                    # Vi hoppade i luften — inaktivera extra hopp tills landar igen
                    $script:canAirJump = $false
                }
            }
        }
    }
})



# thing to handle that i release left or right to stop moving
$window.Add_KeyUp({
    param($sender, $e)
    switch ($e.KeyCode) {
        'A'  { $script:isLeftPressed = $false }
        'D' { $script:isRightPressed = $false }
    }
})

# Map stuff
$platformTexture = [System.Drawing.Image]::FromFile("$texturesPath\Red_Platform.png") # platform texture

<#
$level_1 = @(
    @{x=100; y=780; width=25; height=100}, #1
    @{x=350; y=720; width=25; height=20}, #2
    @{x=540; y=310; width=25; height=20}, # Fake? -- Was velocity bug, fixed
    @{x=600; y=660; width=25; height=20}, #3

    @{x=850; y=600; width=25; height=20}, #1
    @{x=650; y=460; width=25; height=20}, #2 
    @{x=660; y=170; width=25; height=20}, # Fake? -- Was velocity bug, fixed
    @{x=760; y=310; width=25; height=20}  #3
) | export-csv -path "C:\Users\Marcus\Downloads\JumperShell\levels\level_1.csv" -nti

$level_2 = @(
    @{x=100; y=780; width=44; height=20}, #1
    @{x=350; y=720; width=44; height=20}, #2
    @{x=540; y=310; width=44; height=20}, # Fake? -- Was velocity bug, fixed
    @{x=600; y=660; width=44; height=20}, #3

    @{x=800; y=600; width=44; height=20}, #1
    @{x=650; y=460; width=44; height=20}, #2 
    @{x=660; y=170; width=44; height=20}, # Fake? -- Was velocity bug, fixed
    @{x=760; y=310; width=44; height=20}  #3
)
#>
#$script:platforms = $level_1



$script:levelSelect = @()
$script:levelGrouper = @()
$script:levelGrouper2 = @()
$script:levelGrouper3 = @()
$getAllLevelObjects = Get-ChildItem -Path $levelsPath -Filter "*.csv" | Select-Object FullName
foreach ($lev in $getAllLevelObjects) {
    if ($script:levelGrouper.Count -eq 0) {
        $script:levelGrouper += $lev
        #Write-Host "GROUPER: $lev"
        continue
        
    }
    if ($script:levelGrouper.Count -eq 1) {
        $script:levelGrouper2 += $lev
        #Write-Host "GROUPER2: $lev"
    }
    if ($script:levelGrouper.Count -eq 1 -and $script:levelGrouper2.Count -eq 1) {
        $script:levelGrouper3 += [PSCustomObject]@{
            platform = $script:levelGrouper[0].FullName
            air = $script:levelGrouper2[0].FullName
        }
        #Write-Host "GROUPER3: $($script:levelGrouper3)"
    }
    
    if ($script:levelGrouper3.Count -eq 1) {
        $script:levelSelect += $script:levelGrouper3

        $script:levelGrouper = @()
        $script:levelGrouper2 = @()
        $script:levelGrouper3 = @()
    }
}

function LoadLevel {
    param ($dataInput = $null)
    if ($dataInput -eq $null) { return }

    $output = @()
    foreach ($i in $dataInput) {
        $output += @{
            x      = [int]$i.x
            y      = [int]$i.y
            width  = [int]$i.width
            height = [int]$i.height
        }
    }
    return $output
}
function LoadLevel_air {
    param ($dataInput = $null)
    if ($dataInput -eq $null) { return }

    $output = @()
    foreach ($i in $dataInput) {
        $output += @{
            x      = [int]$i.x
            y      = [int]$i.y
            radius  = [int]$i.radius
            used = $false
        }
    }
    return $output
}


$level_1 = Import-Csv -path $script:levelSelect[0].platform
$level_1_air = Import-Csv -path $script:levelSelect[0].air
$script:platforms =  LoadLevel -dataInput $level_1
$script:airJumpZones = LoadLevel_air -dataInput $level_1_air
$script:platformCheck = 1


#######################

# Tick/Loop
$window_Timer = [System.Windows.Forms.Timer]::new()
$window_Timer.Interval = 12 #fps 16 is 60, 32 is 30 etc

# Gravity
$script:velocityY = 0
$gravity = 1.75 # gravity speed
$floorY = 880 # floor collider position

#PlayerYPositionChanged?
$script:minY = 10000

if (-not $script:wasGrounded) { $script:wasGrounded = $false }
$window_Timer.Add_Tick({ #  tick / loop
    if ($script:isLeftPressed) {
        $script:playerX = [Math]::Max(0, $script:playerX - $speedX)
    }
    if ($script:isRightPressed) {
        $script:playerX = [Math]::Min($window_Width - $playerImage.Width, $script:playerX + $speedX)
    }


    if ($script:playerY -lt $script:minY) {
        $script:minY = $script:playerY
        #Write-Host "[DEBUG] New min Y: $($script:minY)"
    }

    $script:velocityY += $gravity # gravity and velocity logic
    $script:playerY += $script:velocityY # apply ^ to player

    $playerBottom = $script:playerY + $playerHeight # check collisions with the floor or platforms
    $onPlatform = $false 
    if ($script:velocityY -ge 2) {
        #ConsoleLog -Type 1 -Msg velocityY
    }
    #ConsoleLog -Type 1 -Msg onPlatform

    foreach ($plat in $platforms) { # Platform collider thing check
        $platTop = $plat.y
        $platLeft = $plat.x
        $platRight = $plat.x + $plat.width

        if (
            $playerBottom -ge $platTop - 5 -and # player near or touch top of platform 
            $playerBottom -le $platTop + 10 -and # player not far below top of platform, number is within pixel amount
            $script:playerX + $playerWidth -gt $platLeft -and # layer right side is past the platform left edge
            $script:playerX -lt $platRight # playr left side is before the right edge of platfomr
        ) {
            $script:playerY = $platTop - $playerHeight # snap to top of platform
            $script:velocityY = 0 # stop falling
            $onPlatform = $true # mark platform collision is true
            #ConsoleLog -Type 1 -Msg onPlatform
            break # stop checking other platforms
        }
    }


    # If not on platform, check floor
    if (-not $onPlatform) {
        if ($script:playerY -ge $floorY) {
            $script:playerY = $floorY
            $script:velocityY = 0
        }
    }

    if ($onPlatform -or $script:playerY -ge $floorY) {
        $script:isJumping = $false
        $script:wasGrounded = $false
        #ConsoleLog -Type 1 -Msg isJumping
        #ConsoleLog -Type 1 -Msg wasGrounded
        #Write-Host "[DEBUG]: isJumping is FALSE and wasGrounded is FALSE" -ForegroundColor Yellow
        }
        elseif (IsGrounded) {
            if (-not $script:wasGrounded) {
                $script:isJumping = $false
                $script:wasGrounded = $true
                #ConsoleLog -Type 1 -Msg velocityY
                $script:velocityY = $jumpVelocity
                #ConsoleLog -Type 1 -Msg wasGrounded

                #Write-Host "[DEBUG]: isJumping is FALSE and wasGrounded is TRUE" -ForegroundColor Cyan
            }
        }
        else {
            $script:wasGrounded = $false
            #ConsoleLog -Type 1 -Msg wasGrounded
            #Write-Host "[DEBUG]: wasGrounded is FALSE" -ForegroundColor Magenta
        }


    if ($script:playerY -le -40) {
        #Write-Host "[DEBUG]: I hit the top: $playerY" -ForegroundColor Green
        $script:playerX = 600
        $script:playerY = 800
        
        if ($script:platformCheck -ge 1 -and $script:platformCheck -le 10) {
            $script:platformCheck++
            ConsoleLog -Type 1 -Msg platformCheck
            #$script:platforms = (Get-Variable -Name $("Level_$platformCheck") | Select-Object Value).Value
            $nextLevel = Import-Csv -path $script:levelSelect[$script:platformCheck - 1].platform
            $nextLevel_air = Import-Csv -path $script:levelSelect[$script:platformCheck -1].air
            $script:platforms =  LoadLevel -dataInput $nextLevel
            $script:airJumpZones = LoadLevel_air -dataInput $nextLevel_air
            #$script:platforms = Set-Variable -Name platforms -Scope script -Value (Get-Variable -Name $("Level_$platformCheck")).Value # -Verbose
            ConsoleLog -Type 1 -Msg platforms
        }
        else {
            # Maybe stop the timer or reset the level check counter
            #$window_Timer.Stop()
            # Or reset platform check to 1 and level 1 platforms if you want loop
             $script:platformCheck = 1
             $script:platforms = $level_1
        }
        $window.Invalidate()
    }


    $window.Invalidate()
})

$window_Timer.Start()


Show-Form $window
