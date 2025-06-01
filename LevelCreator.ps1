# Level generator
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$script:currentLevelFilePath = $null


# File structure..
<# .\JumperShell        #> $sourcePath = (((Get-Content "$ENV:LOCALAPPDATA\JumperShell_Config.txt") | Where-Object {$_ -like "sourcePath=*"}) -split "=",2)[1]
<# |--- JumperShell.ps1 #> $scriptPath = Join-Path -Path $sourcePath "JumperShell.ps1"
<# |----- Textures      #> $texturesPath = Join-Path -Path $sourcePath "Textures"
<# |----- levelsPath      #> $levelsPath = Join-Path -Path $sourcePath "levels"

function Debugs {
    #       $inputter = "editorsession" Debugs -what "platforms"
    param ([string]$what, [string]$color = "yellow")
    $getVar = Get-Variable | Select-Object Name, Value | Where-Object { $_.Name -eq $what }
    Write-Host "[Time - $((Get-Date).ToString("HH:mm:ss"))]" -ForegroundColor Gray
    Write-Host "[DEBUG]: " -ForegroundColor Magenta
    if ($getVar.Value.Count -gt 1) {
        $num = 1
        foreach ($val in $getVar) {
            foreach ($item in $val.Value) {
                Write-Host "$($val.Name)[$num] [$($item)]" -ForegroundColor $color
                $num++
            }
        }
    } else {
        Write-Host "$($getVar.Name) [$($getVar.Value)]" -ForegroundColor $color
    }
    Write-Host "[DEBUG //// END]: " -ForegroundColor Magenta
    
}

function GetLevels {
    return (Get-ChildItem -Path $levelsPath -Filter "*.csv") | Select-Object BaseName, Fullname | Where-Object { $_.BaseName -notlike "*air*" }
}
function GetAirLevels {
    return (Get-ChildItem -Path $levelsPath -Filter "*.csv") | Select-Object BaseName, Fullname | Where-Object { $_.BaseName -like "*air*" }
}

function Show-Form {
    param(
        $form
    )
    [void]$form.ShowDialog()

}

function Clear-LevelUI {
    param ($parent)

    $toRemove = @()
    foreach ($ctrl in $parent.Controls) {
        if ($ctrl.Tag -and $ctrl.Tag -like "leveldata_*") {
            $toRemove += $ctrl
        } elseif ($ctrl.Tag -and $ctrl.Tag -like "levelairdata_*") {
            $toRemove += $ctrl
        }
    }
    foreach ($ctrl in $toRemove) {
        $parent.Controls.Remove($ctrl)
        $ctrl.Dispose()
    }
}

function levelairData {
    param(
        [System.Windows.Forms.Panel]$parent,
        [int]$num,
        [pscustomobject]$data
    )

    # Remove existing controls for this airobject
    $controlsToRemove = @()
    foreach ($ctrl in $parent.Controls) {
        if ($ctrl.Tag -and $ctrl.Tag -like "levelairdata_${num}_*") {
            $controlsToRemove += $ctrl
        }
    }
    foreach ($ctrl in $controlsToRemove) {
        $parent.Controls.Remove($ctrl)
        $ctrl.Dispose()
    }

    $startY = 20 + (($num - 1) * 150)
    $startX = 200
    $spacingY = 30
    $labelWidth = 60
    $textboxWidth = 100
    $height = 25

    # Header Label like "AirZone 1"
    $headerLabel = [System.Windows.Forms.Label]::new()
    $headerLabel.Text = "AirZone $num"
    $headerLabel.Font = [System.Drawing.Font]::new("Arial", 10, [System.Drawing.FontStyle]::Bold)
    $headerLabel.Location = [System.Drawing.Point]::new($startX, $startY)
    $headerLabel.Size = [System.Drawing.Size]::new(200, $height)
    $headerLabel.Tag = "levelairdata_${num}_header"
    $parent.Controls.Add($headerLabel)

    $yLoc = $startY + $spacingY
    $textboxIndex = 1

    foreach ($prop in $data.PSObject.Properties) {
        # Label for property names
        $label = [System.Windows.Forms.Label]::new()
        $label.Text = "$($prop.Name):"
        $label.Size = [System.Drawing.Size]::new($labelWidth, $height)
        $label.Location = [System.Drawing.Point]::new($startX, $yLoc)
        $label.Tag = "levelairdata_${num}_${textboxIndex}_label"
        $parent.Controls.Add($label)

        # Textbox for values
        $textbox = [System.Windows.Forms.TextBox]::new()
        $textbox.Text = "$($prop.Value)"
        $textbox.Width = $textboxWidth
        $textbox.Height = $height
        $textbox.Location = [System.Drawing.Point]::new($startX + $labelWidth + 10, $yLoc)
        $textbox.Tag = "levelairdata_${num}_${textboxIndex}_textbox"
        $parent.Controls.Add($textbox)

        $yLoc += $spacingY
        $textboxIndex++
    }
}

[int]$window_Width = 1280
[int]$window_Height = 975
$window = [System.Windows.Forms.Form]::New()
$window.Size = [System.Drawing.Size]::New($window_Width,$window_Height)
$window.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$window.MaximizeBox = $false
$window.StartPosition = "Manual"
$window.Location = [System.Drawing.Point]::new(100,50)
$window.KeyPreview = $true
$window.ShowIcon = $false
$window.Text = "JumperShell Level Creator"
$window_Background_1 = [System.Drawing.Image]::FromFile("$texturesPath\Base_Background.png")
$window.BackgroundImage = $window_Background_1
$doubleBufferedProperty = $window.GetType().GetProperty("DoubleBuffered", [Reflection.BindingFlags] "Instance, NonPublic")
$doubleBufferedProperty.SetValue($window, $true, $null)
$backBuffer = New-Object System.Drawing.Bitmap $window_Width, $window_Height
###################

$editor = [System.Windows.Forms.Form]::new()
$editor.Text = "JumperShell Editor"
$editor.ShowIcon = $false
$editor.StartPosition = "Manual"
$editor.Height = $window_Height
$editor.Width = $window_Width / 3
$editor.Location = [System.Drawing.Point]::new($window_Width + 90,50)

$editor_scrollPanel = [System.Windows.Forms.Panel]::new()
$editor_scrollPanel.Location = [System.Drawing.Point]::new(0, 100)
$editor_scrollPanel.Size = [System.Drawing.Size]::new($editor.Width - 20, $editor.Height - 120)
$editor_scrollPanel.AutoScroll = $true
$editor_scrollPanel.BackColor = "SlateGray"
$editor.Controls.Add($editor_scrollPanel)


$editor_button_AddPlatform = [System.Windows.Forms.Button]::new()
$editor_button_AddPlatform.Text = "Add Platform"
$editor_button_AddPlatform.Location = [System.Drawing.Point]::new(10,10)
$editor_button_AddPlatform.Width = 100
$editor_button_AddPlatform.Height = 25
$editor_button_AddPlatform.Add_Click({
    if ($editor_button_FindAllLevels.Text -eq "Select Level"){[System.Windows.Forms.MessageBox]::Show("Select level first"); return}

# This is for making a new platform
    $fakeObject = @( @{x=400; y=400; width=100; height=20} )
    $psco = [PSCustomObject]@{
        x = $fakeObject[0].x
        y = $fakeObject[0].y
        width = $fakeObject[0].width
        height = $fakeObject[0].width
    }
    $psco | export-csv -Path $script:currentLevelFilePath -nti -Append

    # Reload and refresh editor
    $script:platforms = Import-Csv -Path $script:currentLevelFilePath
    Clear-LevelUI -parent $editor_scrollPanel

    $rowNums = 1
    foreach ($row in $script:platforms) {
        LevelData -parent $editor_scrollPanel -num $rowNums -data $row
        $rowNums++
    }

    $rowAirNums = 1
    foreach ($row in $script:airJumpZones) {
        levelairData -parent $editor_scrollPanel -num $rowAirNums -data $row
        $rowAirNums++
    }

    $editor_scrollPanel.Refresh()
    $window.Refresh()

})


$editor_button_AddAirZone = [System.Windows.Forms.Button]::new()
$editor_button_AddAirZone.Text = "Add AirZone"
$editor_button_AddAirZone.Location = [System.Drawing.Point]::new(10, 34)
$editor_button_AddAirZone.Width = 100
$editor_button_AddAirZone.Height = 25
$editor_button_AddAirZone.Add_Click({
    if ($editor_button_FindAllLevels.Text -eq "Select Level"){[System.Windows.Forms.MessageBox]::Show("Select level first"); return}
    if (-not $script:currentLevelAirFilePath) {
        $newAirZone = [PSCustomObject]@{
            x = 300
            y = 300
            radius = 50
            used = $false
        }
        $newAirZonePath = ($script:currentLevelFilePath -split "\.")[0] + "air.csv"
        $newAirZone | Export-Csv -Path $newAirZonePath -NoTypeInformation
    }

    $newAirZone = [PSCustomObject]@{
        x = 300
        y = 300
        radius = 50
        used = $false
    }

    $newAirZone | Export-Csv -Path $script:currentLevelAirFilePath -Append -NoTypeInformation -Force

    # Reload and refresh editor
    $script:airJumpZones = Import-Csv -Path $script:currentLevelAirFilePath
    Clear-LevelUI -parent $editor_scrollPanel

    $rowNums = 1
    foreach ($row in $script:platforms) {
        LevelData -parent $editor_scrollPanel -num $rowNums -data $row
        $rowNums++
    }

    $rowAirNums = 1
    foreach ($row in $script:airJumpZones) {
        levelairData -parent $editor_scrollPanel -num $rowAirNums -data $row
        $rowAirNums++
    }

    $editor_scrollPanel.Refresh()
    $window.Refresh()
})


$editor_button_FindAllLevels = [System.Windows.Forms.ComboBox]::new()
$editor_button_FindAllLevels.Text = "Select Level"
$editor_button_FindAllLevels.Location = [System.Drawing.Point]::new(140,10)
$editor_button_FindAllLevels.Width = 240
$editor_button_FindAllLevels.Font = "Arial,10"
$editor_GetLevels = GetLevels
$editor_GetLevelsAir = GetAirLevels
foreach ($lvl in $editor_GetLevels) {

    [void]$editor_button_FindAllLevels.Items.Add($lvl.BaseName)

}

$editor_button_LoadLevel = [System.Windows.Forms.Button]::new()
$editor_button_LoadLevel.Text = "Load level"
$editor_button_LoadLevel.Width = 100
$editor_button_LoadLevel.Height = 25
$editor_button_LoadLevel.Location = [System.Drawing.Point]::new(10,60)
function LevelData {
    param(
        [System.Windows.Forms.Panel]$parent,
        [int]$num,
        [pscustomobject]$data
    )

    # Remove controls for platforms
    $controlsToRemove = @()
    foreach ($ctrl in $parent.Controls) {
        if ($ctrl.Tag -and $ctrl.Tag -like "leveldata_${num}_*") {
            $controlsToRemove += $ctrl
        }
    }
    foreach ($ctrl in $controlsToRemove) {
        $parent.Controls.Remove($ctrl)
        $ctrl.Dispose()
    }

    $startY = 20 + (($num - 1) * 150)
    $startX = 20
    $spacingY = 30
    $labelWidth = 60
    $textboxWidth = 100
    $height = 25

    # Header Label lik "Platform 1"
    $headerLabel = [System.Windows.Forms.Label]::new()
    $headerLabel.Text = "Platform $num"
    $headerLabel.Font = [System.Drawing.Font]::new("Arial", 10, [System.Drawing.FontStyle]::Bold)
    $headerLabel.Location = [System.Drawing.Point]::new($startX, $startY)
    $headerLabel.Size = [System.Drawing.Size]::new(150, $height)
    $headerLabel.Tag = "leveldata_${num}_header"
    $parent.Controls.Add($headerLabel)

    $yLoc = $startY + $spacingY
    $textboxIndex = 1

    foreach ($prop in $data.PSObject.Properties) {
        # Label for property names
        $label = [System.Windows.Forms.Label]::new()
        $label.Text = "$($prop.Name):"
        $label.Size = [System.Drawing.Size]::new($labelWidth, $height)
        $label.Location = [System.Drawing.Point]::new($startX, $yLoc)
        $label.Tag = "leveldata_${num}_${textboxIndex}_label"
        $parent.Controls.Add($label)

        # Textbox for values
        $textbox = [System.Windows.Forms.TextBox]::new()
        $textbox.Text = "$($prop.Value)"
        $textbox.Width = $textboxWidth
        $textbox.Height = $height
        $textbox.Location = [System.Drawing.Point]::new($startX + $labelWidth + 10, $yLoc)
        $textbox.Tag = "leveldata_${num}_${textboxIndex}_textbox"
        $parent.Controls.Add($textbox)

        $yLoc += $spacingY
        $textboxIndex++
    }
}



$editor_button_ApplyChanges = [System.Windows.Forms.Button]::new()
$editor_button_ApplyChanges.Text = "Apply Changes"
$editor_button_ApplyChanges.Width = 100
$editor_button_ApplyChanges.Height = 25
$editor_button_ApplyChanges.Location = [System.Drawing.Point]::new(200,60)
$editor_button_ApplyChanges.Add_Click({
    if ($editor_button_FindAllLevels.Text -eq "Select Level"){[System.Windows.Forms.MessageBox]::Show("Select level first"); return}

    $controls = $editor_scrollPanel.Controls

    $groupedData = @{}
    $airGroupedData = @{}

    foreach ($control in $controls) {
        if ($control.Tag -like "*header") { continue }

        # === PLATFORM TAGS ===
        if ($control.Tag -match "^leveldata_(\d+)_(\d+)_(label|textbox)$") {
            $group = $matches[1]
            $index = $matches[2]
            $type = $matches[3]

            if (-not $groupedData.ContainsKey($group)) {
                $groupedData[$group] = @{}
            }

            if ($type -eq "label") {
                $keyName = $control.Text.TrimEnd(":")
                $groupedData[$group]["key$index"] = $keyName
            } elseif ($type -eq "textbox") {
                $keyName = $groupedData[$group]["key$index"]
                $groupedData[$group][$keyName] = $control.Text
                $groupedData[$group].Remove("key$index")
            }
        }

        # === AIR ZONE TAGS ===
        elseif ($control.Tag -match "^levelairdata_(\d+)_(\d+)_(label|textbox)$") {
            $group = $matches[1]
            $index = $matches[2]
            $type = $matches[3]

            if (-not $airGroupedData.ContainsKey($group)) {
                $airGroupedData[$group] = @{}
            }

            if ($type -eq "label") {
                $keyName = $control.Text.TrimEnd(":")
                $airGroupedData[$group]["key$index"] = $keyName
            } elseif ($type -eq "textbox") {
                
                $keyName = $airGroupedData[$group]["key$index"]
                if ($null -ne $keyName -and $keyName -ne "") {
                    $airGroupedData[$group][$keyName] = $control.Text
                    $airGroupedData[$group].Remove("key$index")
                }

            }
        }
    }

    $finalObjects = $groupedData.Keys | Sort-Object | ForEach-Object {
        [PSCustomObject]$groupedData[$_]
    }

    $airFinalObjects = $airGroupedData.Keys | Sort-Object | ForEach-Object {
        [PSCustomObject]$airGroupedData[$_]
    }

    if ($script:currentLevelFilePath) {
        $finalObjects | Export-Csv -Path $script:currentLevelFilePath -NoTypeInformation
    }

    if ($script:currentLevelAirFilePath) {
        $airFinalObjects | Export-Csv -Path $script:currentLevelAirFilePath -NoTypeInformation
    }

    $editor_button_LoadLevel.PerformClick()

})




$editor_button_LoadLevel.Add_Click({
    if ($editor_button_FindAllLevels.Text -eq "Select Level"){[System.Windows.Forms.MessageBox]::Show("Select level first"); return}

$script:editor_GetLevels = GetLevels
$script:editor_GetLevelsAir = GetAirLevels
    Clear-LevelUI -parent $editor_scrollPanel
    
    $selectedLevel = $editor_GetLevels | Where-Object { $_.BaseName -eq $editor_button_FindAllLevels.SelectedItem }
    if ($selectedLevel) {
        $script:currentLevelFilePath = $selectedLevel.FullName
        $script:platforms = Import-Csv -Path $selectedLevel.FullName
        # Debugs -what "platforms"
        #$window.Refresh()
        
    }

    $selectedLevelAir = $editor_GetLevelsAir | Where-Object { $_.BaseName -eq "$($editor_button_FindAllLevels.SelectedItem)air" }
    if ($selectedLevelAir) {
        $script:currentLevelAirFilePath = $selectedLevelAir.FullName
        $script:airJumpZones = Import-Csv -Path $selectedLevelAir.FullName
        # Debugs -what "AirJumpZones"
        #$window.Refresh()
    }

    $rowNums = 1
    foreach ($row in $script:platforms) {
        LevelData -parent $editor_scrollPanel -num $rowNums -data $row
        $rowNums++
    }

    $rowAirNums = 1
    foreach ($row in $script:airJumpZones) {
        levelairData -parent $editor_scrollPanel -num $rowAirNums -data $row
        $rowAirNums++
    }
    $window.Refresh()
})




$editor_rightClickMenu = [System.Windows.Forms.ContextMenu]::new()
$editor_rightClickMenu_1 = [System.Windows.Forms.MenuItem]::new()
$editor_rightClickMenu_1.Name = "New Level"
$editor_rightClickMenu_1.Text = "New Level"

$editor_rightClickMenu_2 = [System.Windows.Forms.MenuItem]::new()
$editor_rightClickMenu_2.Name = "Refresh"
$editor_rightClickMenu_2.Text = "Refresh"

$editor_rightClickMenu_1.Add_Click({
    try {
        $availableLevelName = Get-ChildItem -Path $levelsPath -Filter "*.csv" | Select-Object BaseName | Sort-Object BaseName
        $availableLevelName = $availableLevelName | Where-Object {$_.BaseName -notlike "*air*"}
        $availableNameNumber = ($availableLevelName[-1].BaseName -split "_",2)[1]
        $levelNum = [int]$availableNameNumber + 1
    } catch {
        $levelNum = 1
    }
    $createNewLevelName = "level_$levelNum"
    # This is for making a new level
    $fakeObject = @( @{x=400; y=400; width=100; height=20} )
    $psco = [PSCustomObject]@{
        x = $fakeObject[0].x
        y = $fakeObject[0].y
        width = $fakeObject[0].width
        height = $fakeObject[0].width
    }
    $psco | export-csv -Path "$levelsPath\$createNewLevelName.csv" -nti

    $pscoAir = [PSCustomObject]@{
        x = 300
        y = 300
        radius = 50
        used = $false
    }
    $pscoAir | Export-Csv -Path "$($levelsPath)\$($createNewLevelName)air.csv" -NoTypeInformation


    $editor_button_FindAllLevels.Items.Clear()
    $editor_GetLevels = GetLevels
    $editor_GetLevelsAir = GetAirLevels
    foreach ($lvl in $editor_GetLevels) {
        [void]$editor_button_FindAllLevels.Items.Add($lvl.BaseName)
    }
    $editor.Refresh()

        

})
<#
$editor_rightClickMenu_2.Add_Click({


    $editor_button_FindAllLevels.Items.Clear()
    $editor_GetLevels = GetLevels
    foreach ($lvl in $editor_GetLevels) {
        [void]$editor_button_FindAllLevels.Items.Add($lvl.BaseName)
    }

    $editor.Refresh()
        

})
#>
$editor_rightClickMenu.MenuItems.AddRange(@(

$editor_rightClickMenu_1
#$editor_rightClickMenu_2

))

$editor.Add_MouseUp({
    param($sender, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
        $editor_rightClickMenu.Show($editor, $e.Location)
    }
})

$editor.Controls.AddRange(@(
    $editor_button_AddPlatform
    $editor_button_AddAirZone
    $editor_button_FindAllLevels
    $editor_button_LoadLevel
    $editor_button_ApplyChanges
))




$rightClickMenu = [System.Windows.Forms.ContextMenu]::new()

$rightClickMenu_item1 = [System.Windows.Forms.MenuItem]::new()
$rightClickMenu_item1.Name = "Toggle Editor"
$rightClickMenu_item1.Text = "Toggle Editor"

$rightClickMenu_item2 = [System.Windows.Forms.MenuItem]::new()
$rightClickMenu_item2.Name = "Save"
$rightClickMenu_item2.Text = "Save"

$rightClickMenu_item1.Add_Click({

   
        Show-Form -form $editor


})
$rightClickMenu_item2.Add_Click({ 

    # Save logic

})

$rightClickMenu.MenuItems.AddRange(@(

$rightClickMenu_item1 #,
#$rightClickMenu_item2

))

$window.Add_MouseUp({
    param($sender, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
        $rightClickMenu.Show($window, $e.Location)
    }
})

$platformTexture = [System.Drawing.Image]::FromFile("$texturesPath\Red_Platform.png") # platform texture


$window.Add_Paint({
    param($sender, $e)
    $gfx = [System.Drawing.Graphics]::FromImage($backBuffer) # <-- Background
    $gfx.DrawImage($window_Background_1, 0, 0)

    # Draw platforms
    foreach ($plat in $platforms) {
        $gfx.DrawImage($platformTexture, $plat.x, $plat.y, $plat.width, $plat.height)
    }

     #air jump zones
    foreach ($zone in $script:airJumpZones) {
        $pen = [System.Drawing.Pen]::New([System.Drawing.Color]::FromArgb(120, 0, 200, 255), 2)
        $gfx.DrawEllipse($pen, [int]$zone.x - [int]$zone.radius, [int]$zone.y - [int]$zone.radius, [int]$zone.radius * 2, [int]$zone.radius * 2)
        $pen.Dispose()
    }




    $gfx.Dispose() # dispose to make powershell less of a laggy mess

    $e.Graphics.DrawImage($backBuffer, 0, 0) # draw to screen position 0,0 is also part of the "anti fucking epilepsi" thing
})




Show-Form -form $window