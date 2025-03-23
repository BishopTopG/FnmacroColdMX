#Requires AutoHotkey v2.0.19
#SingleInstance Force
#MaxThreadsPerHotkey 3  ; Allow multiple threads for smoother operation with rapid edits
SetKeyDelay(0, 5)  ; Minimal key delay for faster input processing

/*
COLDMX EDIT ENGINE - PROTECTED VERSION
Unauthorized use, modification, or distribution is prohibited.
All rights reserved (c) 2025
*/

/*
ColdMX Edit Engine - Premium Edition
This script automates tile selection during building edits.
It addresses issues with timing, reliability, and usability.

Features:
- Fast and reliable edit automation
- Premium GUI with tabs for settings, advanced options, and help
- Real-time hotkey updates without script reload
- Performance tuning options
- Automatic game detection
- Debug mode for troubleshooting
- Secure webhook-based authentication
*/

; ===== Initialize global variables =====
global editKey := "e"              ; Default edit key
global tileSelectKey := "p"        ; Default tile select key
global toggleKey := "F3"           ; Default toggle key
global isActive := false           ; Script inactive until login
global editMode := false           ; Track if currently in edit mode
global editInProgress := false     ; Additional state tracking for safety
global lastEditTime := 0           ; Track time of last edit
global editCooldown := 50          ; Cooldown in ms to prevent edit conflicts
global antiGhostingMode := true    ; Anti-ghosting mode enabled by default
global editInputMethod := 1        ; 1 = Standard, 2 = Double Tap, 3 = Hybrid
global settingsFile := A_ScriptDir . "\ColdMX_Settings.ini"
global settingsGui := ""           ; Will hold our GUI object
global loginGui := ""              ; Will hold our login GUI object
global statusText := ""            ; Will hold our status display object
global debugMode := false          ; Debug mode for troubleshooting
global processingInput := false    ; For preventing overlapping hotkey processing
global loginAttempts := 0          ; Track failed login attempts
global maxLoginAttempts := 5       ; Maximum allowed login attempts
global authenticated := false      ; Track if user is authenticated
global securityTokenFile := A_ScriptDir . "\.secure_token"  ; Hidden security token file
global activeHotkeys := Map()      ; Track currently active hotkeys

; ===== Webhook Authentication Variables =====
global webhookUrl := "https://discordapp.com/api/webhooks/1353119264256688240/bLxgZ7GJqNN8qb5fI8QMV_pzoOG5z8qj8_feMwv2lkuNgcVg1n4SDxIhlBRC2TAwJh82"
global verificationChannel := "verification-channel"  ; Name of the channel where verification codes are sent
global verificationCode := ""      ; Will store the current verification code

; ===== Initialization =====
; Check for saved security token first
if (CheckSecurityToken()) {
    ; Skip login if valid token exists
    authenticated := true
    InitializeScript()
} else {
    ; Create login GUI
    CreateLoginGUI()
    
    ; Show login GUI
    loginGui.Show("w700 h500")  ; Increased window size for more space
}

; Function to initialize script after successful login
InitializeScript() {
    ; Create GUI first
    CreateSettingsGUI()

    ; Load settings from file if it exists
    LoadSettings()

    ; Setup hotkeys
    SetupHotkeys()

    ; Display initial notification
    ShowNotification("ColdMX Engine Activated", "Press " . toggleKey . " to toggle")

    ; Show GUI on startup
    settingsGui.Show("w800 h650")  ; Increased window size for more space
    
    ; Activate script
    isActive := false  ; Start with inactive to ensure proper toggle on first run
    ToggleScript("")   ; Toggle to active
    UpdateStatus()
}

; ===== Webhook Authentication Functions =====

; Function to create the authentication GUI
CreateLoginGUI() {
    global loginGui
    
    ; Create a new GUI for login with intimidating styling
    loginGui := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox", "ColdMX Secure Authentication")
    loginGui.SetFont("s9", "Consolas")  ; Reduced font size
    loginGui.BackColor := "0x121212"  ; Dark theme
    
    ; Add title with more intimidating styling
    titleText := loginGui.Add("Text", "w660 Center y25 c0xE00000", "ColdMX™ ENGINE")
    titleText.SetFont("s12 Bold", "Consolas")  ; Reduced from s16
    
    ; Add subtitle
    subtitle := loginGui.Add("Text", "w660 Center y+20 c0xAAAAAA", "Discord Verification Required")
    subtitle.SetFont("s10", "Consolas")  ; Reduced from s12
    
    ; Add security warning
    warning := loginGui.Add("Text", "w660 Center y+15 c0xFF3333", "Please complete verification to continue")
    warning.SetFont("s9", "Consolas")  ; Reduced from s11
    
    ; Add line separator
    loginGui.Add("Text", "w660 h1 y+25 c0x444444 Border Center", "")
    
    ; Step 1
    loginGui.Add("Text", "xm+40 y+35 w620 c0xDDDDDD", "Step 1: Request Verification Code")
    requestButton := loginGui.Add("Button", "xm+250 y+20 w200 h35", "Request Code")  ; Reduced height
    requestButton.SetFont("s9", "Consolas")  ; Reduced from s11
    requestButton.OnEvent("Click", RequestVerificationCode)
    
    ; Step 2 with username input
    loginGui.Add("Text", "xm+40 y+35 w620 c0xDDDDDD", "Step 2: Enter Discord Username (optional)")
    usernameInput := loginGui.Add("Edit", "xm+40 y+15 w620 h30 Background0x222222 c0xEEEEEE", "")  ; Reduced height
    loginGui.usernameInput := usernameInput
    
    ; Step 3 with verification code input
    loginGui.Add("Text", "xm+40 y+30 w620 c0xDDDDDD", "Step 3: Enter Verification Code")
    codeInput := loginGui.Add("Edit", "xm+40 y+15 w620 h30 Background0x222222 c0xEEEEEE", "")  ; Reduced height
    loginGui.codeInput := codeInput
    
    ; Verify button - still prominent but smaller text
    verifyButton := loginGui.Add("Button", "xm+250 y+35 w200 h40 Default c0x00AA00", "VERIFY CODE")  ; Reduced height
    verifyButton.SetFont("s10 Bold", "Consolas")  ; Reduced from s12
    verifyButton.OnEvent("Click", VerifyCode)
    
    ; Status text field (for messages)
    statusText := loginGui.Add("Text", "xm+40 y+30 w620 h30 c0xAAAAAA Center", "")  ; Reduced height
    loginGui.statusText := statusText  ; Store reference directly
    
    ; Handle GUI close
    loginGui.OnEvent("Close", LoginGuiClose)
}

; Function to generate a verification code and send it to Discord
RequestVerificationCode(*) {
    global loginGui, webhookUrl, verificationCode, verificationChannel
    
    ; Generate a random 6-digit code
    Random(, A_TickCount)  ; Seed with current tick count
    verificationCode := Format("{:06d}", Random(100000, 999999))
    
    ; Get username if provided
    username := loginGui.usernameInput.Value
    usernameText := username ? " for " . username : ""
    
    ; Prepare webhook message
    message := "**ColdMX Authentication Code" . usernameText . "**: ``" . verificationCode . "``"
    message .= "\nThis code will expire in 5 minutes. | Secure Session Request"
    
    ; Create JSON payload
    payload := '{"content":"' . message . '","username":"ColdMX Security"}'
    
    ; Send to Discord via webhook
    try {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("POST", webhookUrl, false)
        http.SetRequestHeader("Content-Type", "application/json")
        http.Send(payload)
        
        if (http.Status = 204) {
            loginGui.statusText.Value := "AUTHORIZATION CODE SENT TO SECURE CHANNEL"
            loginGui.statusText.Opt("c0x00AA00")  ; Green
            
            ; Set expiration timer
            SetTimer(VerificationExpired, -300000)  ; 5 minutes
        } else {
            loginGui.statusText.Value := "ERROR: AUTHORIZATION REQUEST FAILED: " . http.Status
            loginGui.statusText.Opt("c0xFF3333")  ; Red
        }
    } catch Error as e {
        loginGui.statusText.Value := "CONNECTION ERROR: " . e.Message
        loginGui.statusText.Opt("c0xFF3333")  ; Red
    }
}

; Function to verify entered code
VerifyCode(*) {
    global loginGui, verificationCode, authenticated, loginAttempts, maxLoginAttempts
    
    ; Get entered code
    enteredCode := loginGui.codeInput.Value
    
    ; Basic validation
    if (enteredCode = "") {
        loginGui.statusText.Value := "ERROR: AUTHORIZATION CODE REQUIRED"
        loginGui.statusText.Opt("c0xFF3333")  ; Red
        return
    }
    
    ; Check if code matches
    if (enteredCode = verificationCode && verificationCode != "") {
        ; Authentication successful
        authenticated := true
        
        ; Create security token
        CreateSecurityToken()
        
        ; Hide login GUI
        loginGui.Hide()
        
        ; Display success message
        MsgBox("AUTHENTICATION SUCCESSFUL. ACCESS GRANTED.", "ColdMX Security", 64)
        
        ; Initialize the main script
        InitializeScript()
    } else {
        ; Authentication failed
        loginAttempts++
        remainingAttempts := maxLoginAttempts - loginAttempts
        
        if (remainingAttempts <= 0) {
            ; Too many failed attempts
            MsgBox("AUTHENTICATION FAILURE: MAXIMUM ATTEMPTS EXCEEDED. ACCESS DENIED.", "ColdMX Security", 16)
            ExitApp()
        } else {
            ; Authentication failed
            loginGui.statusText.Value := "INVALID CODE. REMAINING ATTEMPTS: " . remainingAttempts
            loginGui.statusText.Opt("c0xFF3333")  ; Red
        }
    }
}

; Function for when verification code expires
VerificationExpired(*) {
    global loginGui, verificationCode
    
    ; Only update if still on verification screen
    if IsObject(loginGui) && WinExist("ahk_id " . loginGui.Hwnd) {
        loginGui.statusText.Value := "AUTHORIZATION CODE EXPIRED. REQUEST NEW CODE."
        loginGui.statusText.Opt("c0xFFA500")  ; Orange
        verificationCode := ""  ; Invalidate the code
    }
}

; Function to create security token after successful login
CreateSecurityToken() {
    global securityTokenFile
    
    ; Generate a unique machine ID
    machineId := A_ComputerName . "-" . A_UserName
    
    ; Create a hash of the machine ID
    hash := GenerateSecurityHash(machineId)
    
    ; Set expiration date (7 days from now)
    expires := DateAdd(A_Now, 7, "days")
    
    ; Write token to hidden file
    try {
        if (FileExist(securityTokenFile))
            FileDelete(securityTokenFile)
        FileAppend(hash . "|" . expires . "|" . machineId, securityTokenFile)
        
        ; Set file as hidden
        FileSetAttrib("+H", securityTokenFile)
    } catch Error as e {
        ; Token creation failed - not critical, just continue
        if (debugMode)
            ShowNotification("Token Error", e.Message)
    }
}

; Function to check for existing security token
CheckSecurityToken() {
    global securityTokenFile
    
    ; Check if token file exists
    if (!FileExist(securityTokenFile))
        return false
    
    try {
        ; Read token file
        fileContent := FileRead(securityTokenFile)
        parts := StrSplit(fileContent, "|")
        
        if (parts.Length < 3)
            return false
        
        savedToken := parts[1]
        expiryDate := parts[2]
        machineId := parts[3]
        
        ; Check if token has expired
        if (A_Now > expiryDate)
            return false
        
        ; Verify token matches this machine
        currentMachineId := A_ComputerName . "-" . A_UserName
        if (machineId != currentMachineId)
            return false
            
        ; Verify hash
        currentHash := GenerateSecurityHash(machineId)
        
        ; Token valid if it matches current hash
        return (savedToken = currentHash)
    } catch Error as e {
        ; Token validation failed
        return false
    }
}

; Function to generate a hash for security token
GenerateSecurityHash(input) {
    hash := 0
    
    Loop Parse, input {
        hash := (hash * 31 + Ord(A_LoopField)) & 0xFFFFFFFF
    }
    
    return Format("{:x}", hash)
}

; Handle login GUI close
LoginGuiClose(thisGui, *) {
    ; If closed without authentication, exit app
    if (!authenticated)
        ExitApp()
    
    return true
}

; ===== Core Functions =====

; Function to setup all hotkeys
SetupHotkeys() {
    global editKey, tileSelectKey, toggleKey, activeHotkeys, processingInput, debugMode
    
    ; Disable processing during hotkey changes
    processingInput := true
    
    ; First, unregister any existing hotkeys
    UnregisterAllHotkeys()
    
    ; Small delay to ensure keystrokes clear
    Sleep(50)
    
    ; Register the toggle key first - this should always be active
    try {
        Hotkey(toggleKey, ToggleScript)
        activeHotkeys[toggleKey] := true
        
        if (debugMode)
            ShowNotification("Hotkey Registered", "Toggle: " . toggleKey)
    } catch Error as e {
        MsgBox("Failed to register toggle hotkey: " . e.Message, "Error", 16)
    }
    
    ; Only register edit hotkeys if the script is active
    if (isActive) {
        try {
            Hotkey(editKey, EditKeyDown)
            Hotkey(editKey . " Up", EditKeyUp)
            activeHotkeys[editKey] := true
            activeHotkeys[editKey . " Up"] := true
            
            if (debugMode)
                ShowNotification("Hotkeys Registered", "Edit: " . editKey . ", Tile: " . tileSelectKey)
        } catch Error as e {
            MsgBox("Failed to register edit hotkeys: " . e.Message, "Error", 16)
        }
    }
    
    ; Re-enable processing
    processingInput := false
}

; Function to unregister all hotkeys
UnregisterAllHotkeys() {
    global activeHotkeys, debugMode
    
    for hotkeyStr, isActive in activeHotkeys {
        if (isActive) {
            try {
                Hotkey(hotkeyStr, "Off")
                activeHotkeys[hotkeyStr] := false
                
                if (debugMode)
                    ShowNotification("Hotkey Unregistered", hotkeyStr)
            } catch Error as e {
                ; Just log the error if in debug mode
                if (debugMode)
                    ShowNotification("Hotkey Unregister Error", e.Message)
            }
        }
    }
}

; Function for edit key press - start edit mode and hold tile select
EditKeyDown(ThisHotkey) {
    global isActive, editMode, editInProgress, lastEditTime, processingInput
    global editKey, tileSelectKey, editCooldown, debugMode
    
    ; Ignore if script is inactive or we're already processing an input
    if (!isActive || processingInput)
        return
    
    ; Set processing flag to prevent overlapping calls
    processingInput := true
    
    ; Check cooldown to prevent rapid re-entry
    currentTime := A_TickCount
    if (currentTime - lastEditTime < editCooldown) {
        processingInput := false
        return
    }
    
    ; Only initiate edit if not already in edit mode
    if (!editMode && !editInProgress) {
        ; Set flags to prevent re-entry
        editInProgress := true
        
        ; Critical section to prevent interruption
        Critical("On")
        
        ; First, block the initial edit key to prevent game from seeing it
        ; This prevents game from processing edit before we're ready
        BlockInput("On")
        
        ; Use a different method for sending the edit key - more reliable
        ; SendMode is already Input (fastest and most reliable)
        SendEvent("{" . editKey . " down}")
        Sleep(1)  ; Very tiny sleep to ensure key down registers
        SendEvent("{" . editKey . " up}")
        
        ; Small delay to ensure edit mode is activated before tile selection
        Sleep(8)  ; Critical timing - too long and it feels sluggish, too short and ghosting occurs
        
        ; Now activate tile selection
        SendInput("{Blind}{" . tileSelectKey . " down}")
        
        ; Re-enable input
        BlockInput("Off")
        
        ; Set flag that we're in edit mode
        editMode := true
        lastEditTime := A_TickCount
        
        ; End critical section
        Critical("Off")
        
        ; Reset in-progress flag
        editInProgress := false
        
        if (debugMode)
            ShowNotification("Edit Mode", "Entered")
    }
    
    ; Reset processing flag
    processingInput := false
}

; Function for edit key release - end selection and confirm edit
EditKeyUp(ThisHotkey) {
    global isActive, editMode, editInProgress, processingInput, tileSelectKey, debugMode
    
    ; Ignore if script is inactive or we're already processing an input
    if (!isActive || processingInput)
        return
    
    ; Set processing flag to prevent overlapping calls
    processingInput := true
    
    ; Only process if we're in edit mode
    if (editMode && !editInProgress) {
        ; Set flag to prevent re-entry
        editInProgress := true
        
        ; Critical section to prevent interruption
        Critical("On")
        
        ; Release tile select key
        SendInput("{Blind}{" . tileSelectKey . " up}")
        
        ; Reset edit mode flag
        editMode := false
        
        ; End critical section
        Critical("Off")
        
        ; Reset in-progress flag
        editInProgress := false
    }
    
    ; Reset processing flag
    processingInput := false
}

; Function to toggle the script on/off
ToggleScript(ThisHotkey) {
    global isActive, editMode, editInProgress, tileSelectKey, editKey, debugMode
    
    ; Reset any ongoing edit if toggling off
    if (isActive && (editMode || editInProgress)) {
        ; Safely release any held keys
        try {
            SendInput("{Blind}{" . tileSelectKey . " up}")
        } catch Error as e {
            if (debugMode)
                ShowNotification("Key Release Error", e.Message)
        }
        
        editMode := false
        editInProgress := false
    }
    
    ; Toggle active state
    isActive := !isActive
    
    ; Update hotkey registrations based on new state
    if (isActive) {
        ; Register edit hotkeys
        try {
            Hotkey(editKey, EditKeyDown, "On")
            Hotkey(editKey . " Up", EditKeyUp, "On")
            activeHotkeys[editKey] := true
            activeHotkeys[editKey . " Up"] := true
            ShowNotification("ColdMX Engine Activated", "Engine online")
        } catch Error as e {
            if (debugMode)
                ShowNotification("Hotkey Registration Error", e.Message)
        }
    } else {
        ; Unregister edit hotkeys
        try {
            Hotkey(editKey, "Off")
            Hotkey(editKey . " Up", "Off")
            activeHotkeys[editKey] := false
            activeHotkeys[editKey . " Up"] := false
            ShowNotification("ColdMX Engine Deactivated", "Engine offline")
        } catch Error as e {
            if (debugMode)
                ShowNotification("Hotkey Unregister Error", e.Message)
        }
    }
    
    ; Update status indicator
    UpdateStatus()
}

; ===== Settings Management =====

; Function to save settings to INI file
SaveSettings() {
    global editKey, tileSelectKey, toggleKey, editCooldown, antiGhostingMode, editInputMethod, debugMode
    global webhookUrl, verificationChannel, settingsFile
    
    try {
        ; Create or update settings file
        if (FileExist(settingsFile))
            FileDelete(settingsFile)
            
        IniWrite(editKey, settingsFile, "Settings", "EditKey")
        IniWrite(tileSelectKey, settingsFile, "Settings", "TileSelectKey")
        IniWrite(toggleKey, settingsFile, "Settings", "ToggleKey")
        IniWrite(editCooldown, settingsFile, "Settings", "EditCooldown")
        IniWrite(antiGhostingMode ? 1 : 0, settingsFile, "Settings", "AntiGhostingMode")
        IniWrite(editInputMethod, settingsFile, "Settings", "EditInputMethod")
        IniWrite(debugMode ? 1 : 0, settingsFile, "Settings", "DebugMode")
        
        ; Save Webhook settings
        IniWrite(webhookUrl, settingsFile, "Webhook", "WebhookUrl")
        IniWrite(verificationChannel, settingsFile, "Webhook", "VerificationChannel")
        
        return true
    } catch Error as e {
        MsgBox("Failed to save settings: " . e.Message, "Error", 16)
        return false
    }
}

; Function to load settings from INI file
LoadSettings() {
    global editKey, tileSelectKey, toggleKey, editCooldown, antiGhostingMode, editInputMethod, debugMode
    global webhookUrl, verificationChannel, settingsFile
    
    if FileExist(settingsFile) {
        try {
            editKey := IniRead(settingsFile, "Settings", "EditKey", editKey)
            tileSelectKey := IniRead(settingsFile, "Settings", "TileSelectKey", tileSelectKey)
            toggleKey := IniRead(settingsFile, "Settings", "ToggleKey", toggleKey)
            editCooldown := Integer(IniRead(settingsFile, "Settings", "EditCooldown", editCooldown))
            antiGhostingMode := (IniRead(settingsFile, "Settings", "AntiGhostingMode", antiGhostingMode) = "1")
            editInputMethod := Integer(IniRead(settingsFile, "Settings", "EditInputMethod", editInputMethod))
            debugMode := (IniRead(settingsFile, "Settings", "DebugMode", debugMode) = "1")
            
            ; Load Webhook settings
            webhookUrl := IniRead(settingsFile, "Webhook", "WebhookUrl", webhookUrl)
            verificationChannel := IniRead(settingsFile, "Webhook", "VerificationChannel", verificationChannel)
            
            ; Update GUI controls with loaded settings
            UpdateGUIControls()
            return true
        } catch Error as e {
            if (debugMode)
                ShowNotification("Settings Load Error", e.Message)
            return false
        }
    }
    return false
}

; Function to update GUI controls with current settings
UpdateGUIControls() {
    global editKey, tileSelectKey, toggleKey, editCooldown, antiGhostingMode, editInputMethod, debugMode
    global webhookUrl, verificationChannel, settingsGui
    
    if IsObject(settingsGui) {
        settingsGui["EditKeyInput"].Value := editKey
        settingsGui["TileSelectKeyInput"].Value := tileSelectKey
        settingsGui["ToggleKeyInput"].Value := toggleKey
        settingsGui["CooldownInput"].Value := editCooldown
        settingsGui["AntiGhostingCheckbox"].Value := antiGhostingMode
        settingsGui["EditInputMethod"].Choose(editInputMethod)
        settingsGui["DebugCheckbox"].Value := debugMode
        
        ; Update Webhook settings if they exist
        if (settingsGui.HasOwnProp("WebhookUrlInput"))
            settingsGui["WebhookUrlInput"].Value := webhookUrl
        if (settingsGui.HasOwnProp("ChannelInput"))
            settingsGui["ChannelInput"].Value := verificationChannel
    }
}

; ===== Utility Functions =====

; Function to show notifications
ShowNotification(title, message, duration := 2000) {
    TrayTip(title, message)
    SetTimer(() => TrayTip(), -duration)
}

; ===== GUI Creation and Management =====

; Function to create the settings GUI
CreateSettingsGUI() {
    global settingsGui, statusText, webhookUrl, verificationChannel, toggleKey
    
    ; Create the GUI with improved styling
    settingsGui := Gui("+AlwaysOnTop -MinimizeBox", "ColdMX Control Panel")
    settingsGui.SetFont("s9", "Segoe UI")  ; Reduced font size
    settingsGui.BackColor := "0x1E1E1E"  ; Dark theme
    
    ; Add title with better styling
    titleText := settingsGui.Add("Text", "w780 Center y20 c0xFF3333", "ColdMX™ EDIT ENGINE")
    titleText.SetFont("s12 Bold", "Consolas")  ; Reduced from s16
    
    ; Add subtitle
    subtitle := settingsGui.Add("Text", "w780 Center y+15 c0xCCCCCC", "PREMIUM CONFIGURATION")
    subtitle.SetFont("s10", "Consolas")  ; Reduced from s12
    
    ; Create tabs for better organization
    tabs := settingsGui.Add("Tab3", "w780 h550 y+25 Background0x1E1E1E", ["CONTROLS", "ADVANCED", "GUIDE"])
    
    ; Settings Tab
    tabs.UseTab(1)
    groupBox := settingsGui.Add("GroupBox", "w760 h250 xm+10 y+25 c0xAAAAAA", "HOTKEY CONFIGURATION")
    groupBox.SetFont("s9 Bold", "Consolas")  ; Reduced from s11
    
    ; Add controls with better spacing and layout
    settingsGui.Add("Text", "xm+50 yp+50 w160 h25 c0xDDDDDD", "Edit Key:")
    settingsGui.Add("Edit", "vEditKeyInput x+30 w140 h30 Background0x333333 c0xEEEEEE", editKey)  ; Reduced height
    settingsGui.Add("Text", "x+30 w180 h25 c0xAAAAAA", "(e.g., F, E, T)")
    
    settingsGui.Add("Text", "xm+50 y+35 w160 h25 c0xDDDDDD", "Tile Select Key:")
    settingsGui.Add("Edit", "vTileSelectKeyInput x+30 w140 h30 Background0x333333 c0xEEEEEE", tileSelectKey)  ; Reduced height
    settingsGui.Add("Text", "x+30 w180 h25 c0xAAAAAA", "(e.g., LButton)")
    
    settingsGui.Add("Text", "xm+50 y+35 w160 h25 c0xDDDDDD", "Toggle Key:")
    settingsGui.Add("Edit", "vToggleKeyInput x+30 w140 h30 Background0x333333 c0xEEEEEE", toggleKey)  ; Reduced height
    settingsGui.Add("Text", "x+30 w180 h25 c0xAAAAAA", "(e.g., F3, F4)")
    
    ; Status indicator
    statusBox := settingsGui.Add("GroupBox", "w760 h110 xm+10 y+40 c0xAAAAAA", "ENGINE STATUS")
    statusBox.SetFont("s9 Bold", "Consolas")  ; Reduced from s11
    
    statusText := settingsGui.Add("Text", "xm+50 yp+45 w150 h30 c0x00CC00", "ACTIVE")
    statusText.SetFont("s11 Bold", "Consolas")  ; Reduced from s14
    
    ; Status description
    settingsGui.Add("Text", "x+50 w400 h30 c0xCCCCCC", "Press " . toggleKey . " to toggle on/off")
    settingsGui.Add("Text", "xm+50 y+15 w650 h25 c0xAAAAAA", "Engine will automatically disable when game closes and re-enable when game starts.")
    
    ; Add Save and Reset Buttons
    saveBtn := settingsGui.Add("Button", "xm+180 y+50 w200 h40 Default", "SAVE CONFIG")  ; Reduced height
    saveBtn.SetFont("s9 Bold", "Consolas")  ; Reduced from s11
    saveBtn.OnEvent("Click", SaveButtonClick)
    
    resetBtn := settingsGui.Add("Button", "x+40 w200 h40", "RESET DEFAULTS")  ; Reduced height
    resetBtn.SetFont("s9 Bold", "Consolas")  ; Reduced from s11
    resetBtn.OnEvent("Click", ResetSettings)
    
    ; Advanced Tab
    tabs.UseTab(2)
    advGroupBox := settingsGui.Add("GroupBox", "w760 h320 xm+10 y+25 c0xAAAAAA", "PERFORMANCE SETTINGS")
    advGroupBox.SetFont("s9 Bold", "Consolas")  ; Reduced from s11
    
    ; Cooldown slider
    settingsGui.Add("Text", "xm+50 yp+50 w660 h25 c0xDDDDDD", "Edit Cooldown (ms):")
    cooldownSlider := settingsGui.Add("Slider", "xm+50 y+15 w660 h35 vCooldownInput Range10-200 TickInterval10 Tooltip", editCooldown)  ; Reduced height
    
    ; Add tooltip explaining cooldown
    cooldownTooltip := "Lower values = faster edits but may cause errors.`nHigher values = more reliable but slower.`nRecommended: 40-60ms"
    cooldownSlider.ToolTip := cooldownTooltip
    
    ; Anti-ghosting mode
    antiGhosting := settingsGui.Add("CheckBox", "xm+50 y+35 w660 h30 vAntiGhostingCheckbox c0xDDDDDD", "Enable Anti-Ghosting Mode (prevents edit cancellation)")
    antiGhosting.Value := antiGhostingMode
    antiGhosting.SetFont("s9", "Consolas")  ; Reduced from s11
    
    ; Edit input method
    settingsGui.Add("Text", "xm+50 y+35 w200 h30 c0xDDDDDD", "Edit Input Method:")
    editMethod := settingsGui.Add("DropDownList", "x+30 w250 h200 vEditInputMethod Background0x333333 c0xEEEEEE", ["Standard", "Double Tap", "Hybrid"])
    editMethod.Choose(1)
    editMethod.SetFont("s9", "Consolas")  ; Reduced from s11
    
    ; Debug mode
    debugCheck := settingsGui.Add("CheckBox", "xm+50 y+35 w660 h30 vDebugCheckbox c0xDDDDDD", "Debug Mode (shows extra notifications)")
    debugCheck.Value := debugMode
    debugCheck.SetFont("s9", "Consolas")  ; Reduced from s11
    
    ; Add Apply Button
    applyBtn := settingsGui.Add("Button", "xm+280 y+50 w200 h40", "APPLY CHANGES")  ; Reduced height
    applyBtn.SetFont("s9 Bold", "Consolas")  ; Reduced from s11
    applyBtn.OnEvent("Click", ApplyAdvancedSettings)
    
    ; Help Tab
    tabs.UseTab(3)
    guideGroup := settingsGui.Add("GroupBox", "w760 h450 xm+10 y+25 c0xAAAAAA", "OPERATION MANUAL")
    guideGroup.SetFont("s9 Bold", "Consolas")  ; Reduced from s11
    
    helpText := "COLDMX™ EDIT ENGINE V2.5`n`n"
    helpText .= "PREMIUM EDIT AUTOMATION TECHNOLOGY`n`n"
    helpText .= "USAGE INSTRUCTIONS:`n"
    helpText .= "1. PRESS AND HOLD YOUR EDIT KEY`n"
    helpText .= "2. MOVE CROSSHAIR OVER TILES TO SELECT`n"
    helpText .= "3. RELEASE EDIT KEY TO CONFIRM`n`n"
    helpText .= "TROUBLESHOOTING:`n"
    helpText .= "• EDITS EXIT TOO QUICKLY: INCREASE COOLDOWN`n"
    helpText .= "• FOR FASTER RESPONSE: DECREASE COOLDOWN`n"
    helpText .= "• ENSURE IN-GAME BINDS MATCH SETTINGS`n"
    helpText .= "• TOGGLE ENGINE OFF WHEN TYPING IN CHAT`n`n"
    helpText .= "PRESS " . toggleKey . " AT ANY TIME TO TOGGLE ON/OFF.`n`n"
    helpText .= "ADVANCED FEATURES:`n"
    helpText .= "• ANTI-GHOSTING MODE: PREVENTS ACCIDENTAL EDIT CANCELLATION`n"
    helpText .= "• DEBUG MODE: SHOWS NOTIFICATIONS FOR TROUBLESHOOTING`n"
    helpText .= "• CUSTOM INPUT METHODS: STANDARD, DOUBLE TAP OR HYBRID MODES"
    
    manualText := settingsGui.Add("Text", "xm+50 yp+50 w660 r18 c0xDDDDDD", helpText)
    manualText.SetFont("s9", "Consolas")  ; Reduced from s11
    
    ; Reset to Settings tab
    tabs.UseTab(1)
    
    ; Handle GUI close - don't destroy, just hide
    settingsGui.OnEvent("Close", GuiClose)
}

; Function to test webhook
TestWebhook(*) {
    global settingsGui, webhookUrl, verificationChannel
    
    ; Get updated values from GUI
    if (IsObject(settingsGui)) {
        webhookUrl := settingsGui["WebhookUrlInput"].Value
        verificationChannel := settingsGui["ChannelInput"].Value
    }
    
    ; Generate a test code
    Random(, A_TickCount)
    testCode := Format("{:06d}", Random(100000, 999999))
    
    ; Prepare webhook message
    message := "**COLDMX WEBHOOK TEST**: ``" . testCode . "``"
    message .= "\nThis is a test of the ColdMX security system."
    
    ; Create JSON payload
    payload := '{"content":"' . message . '","username":"ColdMX Security"}'
    
    ; Send to Discord via webhook
    try {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("POST", webhookUrl, false)
        http.SetRequestHeader("Content-Type", "application/json")
        http.Send(payload)
        
        if (http.Status = 204) {
            MsgBox("TEST SUCCESSFUL: MESSAGE SENT TO WEBHOOK!`n`nCHECK #" . verificationChannel . " TO VERIFY.", "ColdMX Security", 64)
        } else {
            MsgBox("ERROR CODE: " . http.Status . "`n`nRESPONSE: " . http.ResponseText, "ColdMX Security", 16)
        }
    } catch Error as e {
        MsgBox("CONNECTION ERROR: " . e.Message, "ColdMX Security", 16)
    }
}

; Function to update status display
UpdateStatus() {
    global statusText, isActive
    
    if IsObject(statusText) {
        if (isActive) {
            statusText.Value := "ONLINE"
            statusText.Opt("c0x00CC00")
            statusText.SetFont("s12 Bold")
        } else {
            statusText.Value := "OFFLINE"
            statusText.Opt("c0xFF3333")
            statusText.SetFont("s12 Bold")
        }
    }
}

; ===== Button Click Handlers =====

; Save button click event
SaveButtonClick(ctrl, *) {
    global editKey, tileSelectKey, toggleKey, settingsGui, isActive, activeHotkeys
    
    ; Store current state to restore after hotkey changes
    previousActive := isActive
    
    ; Temporarily disable script to safely change hotkeys
    if (isActive) {
        isActive := false
        UpdateStatus()
    }
    
    ; Unregister all existing hotkeys
    UnregisterAllHotkeys()
    
    ; Get values from GUI controls
    newEditKey := settingsGui["EditKeyInput"].Value
    newTileSelectKey := settingsGui["TileSelectKeyInput"].Value
    newToggleKey := settingsGui["ToggleKeyInput"].Value
    
    ; Validate inputs
    if (newEditKey = "" || newTileSelectKey = "" || newToggleKey = "") {
        MsgBox("ERROR: ALL FIELDS MUST BE COMPLETED", "ColdMX Configuration", 16)
        
        ; Re-register previous hotkeys and restore state
        editKey := editKey  ; Use existing values
        tileSelectKey := tileSelectKey
        toggleKey := toggleKey
        SetupHotkeys()
        
        ; Restore previous state
        isActive := previousActive
        UpdateStatus()
        return
    }
    
    ; Check for key conflicts
    if (newEditKey = newTileSelectKey || newEditKey = newToggleKey || newTileSelectKey = newToggleKey) {
        MsgBox("ERROR: HOTKEY CONFLICT DETECTED", "ColdMX Configuration", 16)
        
        ; Re-register previous hotkeys and restore state
        editKey := editKey  ; Use existing values
        tileSelectKey := tileSelectKey
        toggleKey := toggleKey
        SetupHotkeys()
        
        ; Restore previous state
        isActive := previousActive
        UpdateStatus()
        return
    }
    
    ; Update global variables
    editKey := newEditKey
    tileSelectKey := newTileSelectKey
    toggleKey := newToggleKey
    
    ; Re-setup hotkeys with new values
    SetupHotkeys()
    
    ; Restore previous active state
    isActive := previousActive
    
    ; If it was active, ensure edit hotkeys are registered
    if (isActive) {
        try {
            Hotkey(editKey, EditKeyDown, "On")
            Hotkey(editKey . " Up", EditKeyUp, "On")
            activeHotkeys[editKey] := true
            activeHotkeys[editKey . " Up"] := true
        } catch Error as e {
            if (debugMode)
                ShowNotification("Hotkey Registration Error", e.Message)
        }
    }
    
    ; Update status
    UpdateStatus()
    
    ; Save settings to file
    if (SaveSettings())
        ShowNotification("ColdMX Configuration", "SETTINGS SAVED SUCCESSFULLY")
}

; Apply advanced settings
ApplyAdvancedSettings(ctrl, *) {
    global editCooldown, antiGhostingMode, editInputMethod, debugMode, settingsGui
    
    ; Get values from GUI controls
    newCooldown := settingsGui["CooldownInput"].Value
    newAntiGhosting := settingsGui["AntiGhostingCheckbox"].Value
    newEditInputMethod := settingsGui["EditInputMethod"].Value
    newDebugMode := settingsGui["DebugCheckbox"].Value
    
    ; Update global variables
    editCooldown := newCooldown
    antiGhostingMode := newAntiGhosting
    editInputMethod := newEditInputMethod
    debugMode := newDebugMode
    
    ; Save settings to file
    if (SaveSettings())
        ShowNotification("ColdMX Configuration", "ADVANCED SETTINGS APPLIED")
}

; Reset settings to default
ResetSettings(ctrl, *) {
    if (MsgBox("RESET ALL SETTINGS TO DEFAULT VALUES?", "Confirm Reset", 4) = "Yes") {
        global editKey, tileSelectKey, toggleKey, editCooldown, antiGhostingMode, editInputMethod, debugMode
        global isActive, activeHotkeys
        
        ; Store current state to restore after hotkey changes
        previousActive := isActive
        
        ; Temporarily disable script to safely change hotkeys
        if (isActive) {
            isActive := false
            UpdateStatus()
        }
        
        ; Unregister all existing hotkeys
        UnregisterAllHotkeys()
        
        ; Reset to defaults
        editKey := "e"
        tileSelectKey := "p"
        toggleKey := "F3"
        editCooldown := 50
        antiGhostingMode := true
        editInputMethod := 1
        debugMode := false
        
        ; Update GUI controls
        UpdateGUIControls()
        
        ; Re-setup hotkeys
        SetupHotkeys()
        
        ; Restore previous active state
        isActive := previousActive
        
        ; If it was active, ensure edit hotkeys are registered
        if (isActive) {
            try {
                Hotkey(editKey, EditKeyDown, "On")
                Hotkey(editKey . " Up", EditKeyUp, "On")
                activeHotkeys[editKey] := true
                activeHotkeys[editKey . " Up"] := true
            } catch Error as e {
                if (debugMode)
                    ShowNotification("Hotkey Registration Error", e.Message)
            }
        }
        
        ; Update status
        UpdateStatus()
        
        ; Save to file
        SaveSettings()
        
        ShowNotification("ColdMX Configuration", "DEFAULT VALUES RESTORED")
    }
}

; Handle GUI close
GuiClose(thisGui, *) {
    thisGui.Hide()
    return true  ; Prevents the GUI from being destroyed
}

; ===== Tray Menu =====

; Setup tray menu
A_TrayMenu.Delete() ; Clear default menu
A_TrayMenu.Add("OPEN CONTROL PANEL", ShowSettings)
A_TrayMenu.Add("TOGGLE ENGINE", ToggleScriptMenu)
A_TrayMenu.Add()  ; Separator
A_TrayMenu.Add("EXIT", ExitScript)
A_TrayMenu.Default := "OPEN CONTROL PANEL"

; Function to show settings GUI
ShowSettings(*) {
    global settingsGui
    if IsObject(settingsGui) {
        settingsGui.Show()
    }
}

; Function for tray menu toggle
ToggleScriptMenu(*) {
    ToggleScript("")
}

; Function to exit the script
ExitScript(*) {
    global editMode, tileSelectKey
    
    ; Clean up any held keys before exiting
    if (editMode) {
        try {
            SendInput("{Blind}{" . tileSelectKey . " up}")
        }
        catch Error as e {
            ; Ignore errors on exit
        }
    }
    
    ; Unregister all hotkeys for clean exit
    UnregisterAllHotkeys()
    
    ExitApp()
}

; ===== Game Monitoring =====

; Monitor for game process changes
MonitorGameProcess() {
    static lastGameRunning := false
    global isActive, debugMode
    
    ; Check if Fortnite is running
    fortniteRunning := ProcessExist("FortniteClient-Win64-Shipping.exe") > 0
    
    if (fortniteRunning != lastGameRunning) {
        lastGameRunning := fortniteRunning
        
        if (fortniteRunning) {
            ; Game started
            if (debugMode)
                ShowNotification("ColdMX Status", "GAME DETECTED - ENGINE READY")
        } else {
            ; Game closed
            if (isActive) {
                ; Automatically disable script when game closes
                isActive := false
                UpdateStatus()
                
                ; Unregister edit hotkeys
                try {
                    Hotkey(editKey, "Off")
                    Hotkey(editKey . " Up", "Off")
                    activeHotkeys[editKey] := false
                    activeHotkeys[editKey . " Up"] := false
                } catch Error as e {
                    ; Ignore errors when turning off hotkeys
                }
                
                if (debugMode)
                    ShowNotification("ColdMX Status", "GAME CLOSED - ENGINE DISABLED")
            }
        }
    }
}

; ===== Cleanup function =====
; Ensure no keys are left pressed if script is interrupted
CleanupHeldKeys(*) {
    global editMode, tileSelectKey
    
    if (editMode) {
        try {
            SendInput("{Blind}{" . tileSelectKey . " up}")
        }
        catch Error as e {
            ; Ignore errors during cleanup
        }
    }
    
    ; Unregister all hotkeys for clean exit
    UnregisterAllHotkeys()
}

; Register cleanup function
OnExit(CleanupHeldKeys)

; ===== Set up timers =====
SetTimer(UpdateStatus, 1000)
SetTimer(MonitorGameProcess, 5000)
