#Requires AutoHotkey v2.0
#SingleInstance Force

; Batch Folder Creation Tool
class FolderCreator {
    static AppName := "mkdir"
    static Version := "1.0.1"
    static Themes := Map("Light", Map(), "Dark", Map())
    static CurrentTheme := "Light"

    __New() {
        ; Initialize instance properties
        this.MainGUI := ""
        this.PathEdit := ""
        this.BasePathEdit := ""
        this.CreateParents := ""
        this.IgnoreDuplicates := ""
        this.StatusBar := ""
        this.GitHubLink := ""
        this.ThemeTimer := ""

        ; Initialize theme colors
        this.InitThemes()

        ; Set initial theme based on system
        this.UpdateThemeFromSystem()

        TraySetIcon("shell32.dll", 4) ; Use Windows Folder icon
    }

    ; Initialize theme colors
    InitThemes() {
        ; Light theme colors
        FolderCreator.Themes["Light"] := Map(
            "BG", 0xFFFFFF,           ; Background
            "EditBG", 0xFFFFFF,       ; Edit background
            "Text", 0x00000000,         ; Text color
            "EditText", 0x00000000,     ; Edit text
            "Link", 0x0000FF,         ; Link color
        )

        ; Dark theme colors
        FolderCreator.Themes["Dark"] := Map(
            "BG", 0x414559,           ; Background
            "EditBG", 0x414559,       ; Edit background
            "Text", 0xFFFFFFFF,         ; Text color
            "EditText", 0xFFFFFFFF,     ; Edit text
            "Link", 0xCA9EE6,         ; Link color
        )
    }

    ; Check system theme and update
    UpdateThemeFromSystem() {
        isLightTheme := this.DetectSystemTheme()
        FolderCreator.CurrentTheme := isLightTheme ? "Light" : "Dark"
        return FolderCreator.CurrentTheme
    }

    ; Detect current system theme
    DetectSystemTheme() {
        static REG_PATH := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"

        try {
            ; Try to read apps theme setting (most reliable for Windows 10/11)
            appsTheme := RegRead(REG_PATH, "AppsUseLightTheme")
            return (appsTheme = 1)
        } catch {
            ; Fallback: check if high contrast mode is active
            try {
                highContrast := RegRead("HKEY_CURRENT_USER\Control Panel\Accessibility\HighContrast", "Flags")
                if (highContrast = "1") {
                    ; In high contrast mode, use light theme as default
                    return true
                }
            }

            ; Default to light theme
            return true
        }
    }

    ; Apply theme to GUI
    ApplyTheme(themeName) {
        if !FolderCreator.Themes.Has(themeName)
            themeName := "Light"

        FolderCreator.CurrentTheme := themeName
        colors := FolderCreator.Themes[themeName]

        ; Apply theme to main GUI if it exists
        if this.MainGUI {
            try {
                this.MainGUI.BackColor := colors["BG"]
                this.MainGUI.SetFont("c" Format("{:06X}", colors["Text"]), , "Segoe UI")

                ; Apply to all controls
                for hwnd, control in this.MainGUI {
                    this.ApplyThemeToControl(control, colors)
                }

                ; Special handling for GitHub link
                if this.GitHubLink {
                    this.GitHubLink.SetFont("c" Format("{:06X}", colors["Link"]) " Underline")
                }
            } catch as e {
                ; Silent fail on theme application errors
            }
        }
    }

    ; Apply theme to individual control
    ApplyThemeToControl(control, colors) {
        try {
            controlType := Type(control)

            if InStr(controlType, "Edit") {
                ; control.Opt("Background" Format("{:06X}", colors["EditBG"]))
                control.SetFont("c" Format("{:06X}", colors["EditText"]))
            }
            else if InStr(controlType, "Text") {
                control.SetFont("c" Format("{:06X}", colors["Text"]))
            }
            else if InStr(controlType, "CheckBox") {
                control.SetFont("c" Format("{:06X}", colors["Text"]))
            }
            else if InStr(controlType, "GroupBox") {
                control.SetFont("c" Format("{:06X}", colors["Text"]))
            }
            else if InStr(controlType, "Progress") {
                try {
                    control.Opt("Background" Format("{:06X}", colors["EditBG"]))
                }
            }
            else if InStr(controlType, "StatusBar") {
                control.SetFont("c" Format("{:06X}", colors["Text"]))
            }
        }
        catch Error as e {
            ; Optional: log the error for debugging
            ; FileAppend("Theme error: " e.Message "`n", "theme_errors.log")
        }
    }

    ; Start theme monitoring
    StartThemeMonitoring() {
        ; Check for theme changes every 2 seconds
        this.ThemeTimer := SetTimer(() => this.CheckThemeChange(), 2000)
    }

    ; Stop theme monitoring
    StopThemeMonitoring() {
        if this.ThemeTimer {
            SetTimer(this.ThemeTimer, 0)
            this.ThemeTimer := ""
        }
    }

    ; Check if theme has changed
    CheckThemeChange() {
        static lastTheme := FolderCreator.CurrentTheme

        currentSystemTheme := this.UpdateThemeFromSystem()
        if (currentSystemTheme != lastTheme) {
            lastTheme := currentSystemTheme
            this.ApplyTheme(currentSystemTheme)
        }
    }

    ; Display main interface
    ShowGUI() {
        this.MainGUI := Gui("+Resize +MinSize600x400", FolderCreator.AppName " v" FolderCreator.Version)
        this.MainGUI.OnEvent("Close", (*) => ExitApp())
        this.MainGUI.SetFont("s10", "Segoe UI")

        ; Apply current theme before creating controls
        this.ApplyTheme(FolderCreator.CurrentTheme)

        ; Create controls
        this.CreateControls()

        ; Set up hotkeys
        this.SetupHotkeys()

        ; Start monitoring theme changes
        this.StartThemeMonitoring()

        this.MainGUI.Show("w700 h500")
    }

    ; Handle GUI close
    OnClose() {
        this.StopThemeMonitoring()
        ExitApp()
    }

    ; Set up hotkeys
    SetupHotkeys() {
        ; Global hotkeys that work when the GUI has focus
        this.MainGUI.OnEvent("Escape", (*) => ExitApp())

        ; Use HotIf to make hotkeys specific to this GUI
        HotIf (*) => WinActive("ahk_id " this.MainGUI.Hwnd)

        ; Shift+Enter or Alt+Enter to execute Start Creation
        Hotkey("+Enter", (*) => this.StartCreation())
        Hotkey("!Enter", (*) => this.StartCreation())

        ; Ctrl+Shift+F to focus on path edit
        Hotkey("^+F", (*) => this.PathEdit.Focus())

        HotIf  ; Reset HotIf condition
    }

    ; Create interface controls
    CreateControls() {
        colors := FolderCreator.Themes[FolderCreator.CurrentTheme]

        ; Title and description
        this.MainGUI.Add("Text", Format("xm y10 w680 Center c{}", colors["Text"]), "Batch Folder Creator - Supports Multi-level Directory Structure")
        this.MainGUI.Add("Text", "xm y+5 w680 Center cGray", "Enter one folder path per line, supports multi-level directories and absolute paths")

        ; Path input area
        this.MainGUI.Add("GroupBox", Format("xm y+10 w680 h300 c{}", colors["Text"]), "Folder Path List")
        this.PathEdit := this.MainGUI.Add("Edit", "xp+10 yp+25 w660 h250 Multi VScroll", "")
        this.PathEdit.Opt("Background" Format("{:06X}", colors["EditBG"]))
        this.PathEdit.SetFont("s16", "Lucida Console")
        this.PathEdit.SetFont("c" Format("{:06X}", colors["EditText"]))
        ; Button area
        btnY := 340
        createBtn := this.MainGUI.Add("Button", "xm y" btnY " w120 h35", "Start Creation")
        createBtn.OnEvent("Click", (*) => this.StartCreation())

        clearBtn := this.MainGUI.Add("Button", "x+10 yp w120 h35", "Clear List")
        clearBtn.OnEvent("Click", (*) => this.ClearList())

        ; Base path selection
        this.MainGUI.Add("Text", "x+20 y" . (btnY + 5) . " w80 c" . colors["Text"], "Base Path:")

        ; Set default base path from command line argument or current directory
        defaultBasePath := this.GetDefaultBasePath()
        this.BasePathEdit := this.MainGUI.Add("Edit", "x+5 yp-3 w250", defaultBasePath)
        this.BasePathEdit.Opt("Background" Format("{:06X}", colors["EditBG"]))
        this.BasePathEdit.SetFont("s10", "Lucida Console")
        this.BasePathEdit.SetFont("c" Format("{:06X}", colors["EditText"]))
        browseBtn := this.MainGUI.Add("Button", "x+5 yp w80", "Browse...")
        browseBtn.OnEvent("Click", (*) => this.SelectBasePath())

        ; Options area
        optionsY := btnY + 45
        this.MainGUI.Add("GroupBox", "xm y" optionsY " w680 h60", "Options")
        this.CreateParents := this.MainGUI.Add("CheckBox", "xp+10 yp+25 Checked", "Create Parent Directories")
        this.IgnoreDuplicates := this.MainGUI.Add("CheckBox", "x+20 yp Checked", "Ignore Existing Folders")

        ; Status bar
        this.StatusBar := this.MainGUI.Add("StatusBar", , "Ready - Enter folder paths and click 'Start Creation'")

        ; GitHub link
        tipsY := optionsY + 65
        this.GitHubLink := this.MainGUI.Add("Text", "xm y" tipsY " w680 Right", "H1DDENADM1N/mkdir")
        this.GitHubLink.SetFont("c" Format("{:06X}", colors["Link"]) " Underline")
        this.GitHubLink.OnEvent("Click", (*) => Run("https://github.com/H1DDENADM1N/mkdir"))
        this.GitHubLink.Opt("+BackgroundTrans")
    }

    ; Get default base path from command line argument or use current directory
    GetDefaultBasePath() {
        ; Check if first command line argument exists and is not /elevate
        if A_Args.Length >= 1 && A_Args[1] != "/elevate" {
            workingDir := A_Args[1]

            ; Handle relative paths
            if !RegExMatch(workingDir, "^[a-zA-Z]:\\") && !RegExMatch(workingDir, "^\\\\") {
                ; It's a relative path, convert to absolute
                workingDir := A_WorkingDir . "\" . workingDir
            }

            ; Normalize the path (remove trailing backslashes, etc.)
            workingDir := RegExReplace(workingDir, "\\+$", "")  ; Remove trailing backslashes
            workingDir := RegExReplace(workingDir, "\\+", "\")  ; Replace multiple backslashes with single

            ; Check if directory exists, if not try to create it
            if !DirExist(workingDir) {
                try {
                    DirCreate(workingDir)
                    this.UpdateStatus("Created working directory: " workingDir)
                } catch as e {
                    this.UpdateStatus("Warning: Could not create working directory, using current directory instead")
                    return A_WorkingDir
                }
            }

            return workingDir
        }

        ; No command line argument provided or it's /elevate, use current directory
        return A_WorkingDir
    }

    ; Select base path
    SelectBasePath() {
        selectedPath := DirSelect("*" this.BasePathEdit.Value, 0, "Select Base Directory")
        if selectedPath != ""
            this.BasePathEdit.Value := selectedPath
    }

    ; Clear list
    ClearList() {
        if MsgBox("Are you sure you want to clear all paths?", FolderCreator.AppName, "YesNo Icon!") = "Yes"
            this.PathEdit.Value := ""
    }

    ; Start folder creation
    StartCreation() {
        basePath := Trim(this.BasePathEdit.Value)
        pathText := Trim(this.PathEdit.Value)

        ; Validate input
        if basePath = "" {
            this.ShowError("Please select a base path!")
            return
        }

        if pathText = "" {
            this.ShowError("Please enter folder paths to create!")
            return
        }

        ; Parse path list
        paths := this.ParsePaths(pathText)
        if paths.Length = 0 {
            this.ShowError("No valid paths to create!")
            return
        }

        ; Start creation process
        this.ExecuteCreation(paths, basePath, this.CreateParents.Value, this.IgnoreDuplicates.Value)
    }

    ; Parse path list
    ParsePaths(pathText) {
        rawPaths := StrSplit(pathText, "`n", "`r")
        validPaths := []

        for lineNum, rawPath in rawPaths {
            path := Trim(rawPath)
            if path = ""
                continue

            ; Validate path legality
            validation := this.ValidatePath(path)
            if validation.IsValid {
                validPaths.Push({
                    Original: path,
                    Normalized: validation.Normalized,
                    IsAbsolute: validation.IsAbsolute,
                    Line: lineNum
                })
            } else {
                this.UpdateStatus("Line " lineNum " invalid path: " path " - " validation.Reason)
            }
        }

        return validPaths
    }

    ; Validate path legality
    ValidatePath(path) {
        ; Remove leading/trailing spaces and invalid characters
        path := Trim(path)
        if path = ""
            return { IsValid: false, Reason: "Empty path" }

        ; Check if it's an absolute path
        isAbsolute := this.IsAbsolutePath(path)

        ; Check for illegal characters (Windows filename restrictions)
        ; For absolute paths, we need to be more careful about checking drive letters
        invalidChars := ["<", ">", "`"", "|", "?", "*"]

        ; Don't check for colon in absolute paths as it's part of the drive letter
        if !isAbsolute {
            invalidChars.Push(":")  ; Only check colon for relative paths
        }

        for char in invalidChars {
            if InStr(path, char) {
                return { IsValid: false, Reason: "Contains illegal character: " char }
            }
        }

        ; Check reserved names - but skip for absolute paths as they contain valid drive letters
        if !isAbsolute {
            reservedNames := ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4",
                "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2",
                "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"]

            ; Split path and check each part
            pathParts := StrSplit(path, "/\")
            for part in pathParts {
                cleanPart := Trim(part)
                if cleanPart = ""
                    continue

                for reserved in reservedNames {
                    if StrCompare(cleanPart, reserved, "Locale") = 0 {
                        return { IsValid: false, Reason: "Uses reserved name: " reserved }
                    }
                }
                ; Check for ending with dot or space
                if RegExMatch(cleanPart, "[\. ]$") {
                    return { IsValid: false, Reason: "Name ends with dot or space" }
                }
            }
        }

        ; Normalize path (unify / and \ to \)
        normalized := StrReplace(path, "/", "\")
        normalized := RegExReplace(normalized, "\\+", "\")  ; Remove consecutive backslashes

        ; For absolute paths, ensure proper format
        if isAbsolute {
            ; Ensure drive letter is uppercase and path starts properly
            if RegExMatch(normalized, "^[a-z]:\\") {
                normalized := Format("{:U}", SubStr(normalized, 1, 1)) . SubStr(normalized, 2)
            }
        }

        return { IsValid: true, Normalized: normalized, IsAbsolute: isAbsolute, Reason: "" }
    }

    ; Check if path is absolute
    IsAbsolutePath(path) {
        ; Check for drive letter path (C:\)
        if RegExMatch(path, "^[a-zA-Z]:\\") {
            return true
        }
        ; Check for UNC path (\\server\share)
        if RegExMatch(path, "^\\\\") {
            return true
        }
        return false
    }

    ; Execute creation process
    ExecuteCreation(paths, basePath, createParents, ignoreDuplicates) {
        ; Create progress window
        progressGUI := this.CreateProgressGUI(paths.Length)

        successCount := 0
        failCount := 0
        needElevation := false
        resultDetails := ""

        ; Display base path information
        this.UpdateStatus("Processing " paths.Length " paths...")

        ; Iterate through creating each path
        for index, pathInfo in paths {
            progressGUI.Progress.Value := index
            progressGUI.Text.Value := "Creating: " pathInfo.Original

            result := this.CreateSingleFolder(basePath, pathInfo, createParents, ignoreDuplicates)

            if result.Success {
                successCount++
                resultDetails .= "✓ " pathInfo.Original "`n"
            } else {
                failCount++
                resultDetails .= "✗ " pathInfo.Original " - " result.Message "`n"

                ; Check if elevation is needed
                if result.NeedElevation {
                    needElevation := true
                }
            }

            Sleep(50) ; Small delay to observe progress
        }

        ; Close progress window
        progressGUI.GUI.Destroy()

        ; Handle results
        this.HandleCreationResult(successCount, failCount, needElevation, resultDetails)
    }

    ; Create single folder
    CreateSingleFolder(basePath, pathInfo, createParents, ignoreDuplicates) {
        ; Determine the full path based on whether it's absolute or relative
        if pathInfo.IsAbsolute {
            fullPath := pathInfo.Normalized
            this.UpdateStatus("Creating absolute path: " fullPath)
        } else {
            ; For relative paths, ensure correct base path is used
            fullPath := basePath "\" pathInfo.Normalized
            this.UpdateStatus("Creating relative path: " pathInfo.Normalized " in " basePath)
        }

        ; Normalize full path to handle .. and . etc.
        fullPath := this.NormalizeFullPath(fullPath)

        ; Check if already exists
        if DirExist(fullPath) {
            if ignoreDuplicates {
                ; If "Ignore Existing Folders" is checked, skip existing folders
                return { Success: true, Message: "Folder already exists (ignored)", NeedElevation: false }
            } else {
                ; If "Ignore Existing Folders" is not checked, return failure
                return { Success: false, Message: "Folder already exists", NeedElevation: false }
            }
        }

        try {
            ; For absolute paths, we don't need to check base path
            if !pathInfo.IsAbsolute {
                ; Check if base path exists for relative paths
                if !DirExist(basePath) {
                    return { Success: false, Message: "Base directory doesn't exist: " basePath, NeedElevation: false }
                }
            }

            ; According to settings, decide whether to create parent directories
            if createParents {
                DirCreate(fullPath)
            } else {
                ; Don't automatically create parent directories, need manual check
                parentDir := RegExReplace(fullPath, "\\[^\\]+$", "")
                if !DirExist(parentDir) {
                    return { Success: false, Message: "Parent directory doesn't exist", NeedElevation: false }
                }
                DirCreate(fullPath)
            }

            return { Success: true, Message: "", NeedElevation: false }

        } catch as e {
            ; Enhanced permission error detection
            errorMsg := e.Message
            if InStr(errorMsg, "Access denied") || InStr(errorMsg, "Access is denied") ||
                InStr(errorMsg, "拒绝访问") || InStr(errorMsg, "权限") ||
                (e.Extra && (InStr(e.Extra, "5") || InStr(e.Extra, "拒绝访问"))) {
                return { Success: false, Message: "Insufficient permissions - need administrator rights", NeedElevation: true }
            }

            return { Success: false, Message: e.Message, NeedElevation: false }
        }
    }

    ; Normalize full path to handle .. and . properly
    NormalizeFullPath(path) {
        ; Split path into components
        parts := StrSplit(path, "\")
        result := []

        for part in parts {
            if part = ".." {
                ; Go up one directory level
                if result.Length > 0 && result[result.Length] != ".." {
                    result.Pop()
                } else {
                    result.Push("..")
                }
            } else if part != "." && part != "" {
                ; Skip current directory and empty parts
                result.Push(part)
            }
        }

        ; Rebuild the path
        normalized := ""
        for i, part in result {
            if i = 1 {
                normalized := part
            } else {
                normalized := normalized "\" part
            }
        }

        return normalized
    }

    ; Create progress window
    CreateProgressGUI(totalItems) {
        progressGUI := Gui("+ToolWindow +AlwaysOnTop", "Creation Progress")
        progressGUI.SetFont("s9", "Segoe UI")

        ; Apply theme to progress window
        colors := FolderCreator.Themes[FolderCreator.CurrentTheme]
        progressGUI.BackColor := colors["BG"]
        progressGUI.SetFont("c" Format("{:06X}", colors["Text"]))

        progressGUI.Add("Text", "w400 Center", "Creating folders in batch...")
        progressText := progressGUI.Add("Text", "yp+30 w400 Center", "Preparing to start...")
        progressBar := progressGUI.Add("Progress", "w400 h20 Range0-" totalItems, 0)
        progressGUI.Add("Text", "yp+30 w400 Center", "Please wait...")

        progressGUI.Show()

        return {
            GUI: progressGUI,
            Progress: progressBar,
            Text: progressText
        }
    }

    ; Handle creation results
    HandleCreationResult(successCount, failCount, needElevation, resultDetails) {
        resultMsg := "Batch creation completed!`n`n"
        resultMsg .= "✅ Success: " successCount " items`n"
        resultMsg .= "❌ Failed: " failCount " items`n"

        ; If elevation is needed and current user is not administrator
        if needElevation && !A_IsAdmin {
            resultMsg .= "`n⚠️  Detected folders with insufficient permissions.`nTry recreating with administrator privileges?"

            if MsgBox(resultMsg, FolderCreator.AppName, "YesNo Icon!") = "Yes" {
                this.RetryWithElevation()
                return
            }
        } else if needElevation && A_IsAdmin {
            resultMsg .= "`n⚠️  Even with administrator privileges, some folders could not be created.`nThis might require higher system permissions."
        }

        ; Show detailed results
        if resultDetails != "" {
            resultMsg .= "`nDetailed results:`n`n" resultDetails
        }

        MsgBox(resultMsg, FolderCreator.AppName, "Iconi")
        this.UpdateStatus("Completed: " successCount " successful, " failCount " failed")
    }

    ; Retry with UAC elevation
    RetryWithElevation() {
        try {
            ; Save current data to temporary file
            tempFile := A_Temp "\" FolderCreator.AppName "_ElevateData.txt"
            data := {
                BasePath: this.BasePathEdit.Value,
                Paths: this.PathEdit.Value,
                CreateParents: this.CreateParents.Value,
                IgnoreDuplicates: this.IgnoreDuplicates.Value
            }

            ; Replace line breaks with special delimiters to avoid parsing issues
            encodedPaths := StrReplace(data.Paths, "`n", "|LINEBREAK|")
            encodedBasePath := StrReplace(data.BasePath, "`n", "|LINEBREAK|")
            encodedWorkingDir := StrReplace(A_WorkingDir, "`n", "|LINEBREAK|")

            fileContent := "BasePath=" . encodedBasePath . "`n"
            fileContent .= "Paths=" . encodedPaths . "`n"
            fileContent .= "CreateParents=" . (data.CreateParents ? "1" : "0") . "`n"
            fileContent .= "IgnoreDuplicates=" . (data.IgnoreDuplicates ? "1" : "0") . "`n"
            ; Save current working directory to properly handle relative paths in elevated mode
            fileContent .= "OriginalWorkingDir=" . encodedWorkingDir

            FileAppend(fileContent, tempFile)

            ; Rerun with administrator privileges
            if A_IsCompiled {
                RunWait('*RunAs "' A_ScriptFullPath '" "' tempFile '" /elevate')
            } else {
                RunWait('*RunAs "' A_AhkPath '" "' A_ScriptFullPath '" "' tempFile '" /elevate')
            }

            ; Clean up temp file after elevation
            FileDelete(tempFile)

        } catch as e {
            this.ShowError("Elevation failed: " e.Message)
        }
    }

    ; Check if started in elevated mode
    CheckElevatedMode() {
        if A_Args.Length > 0 {
            for arg in A_Args {
                if arg = "/elevate" {
                    ; We are in elevated mode, look for data file
                    this.HandleElevatedMode()
                    return true
                }
            }
        }
        return false
    }

    ; Handle elevated mode execution
    HandleElevatedMode() {
        ; Look for data file in arguments or temp location
        dataFile := ""

        ; Check if one of the arguments is a data file
        for arg in A_Args {
            if arg != "/elevate" && FileExist(arg) {
                dataFile := arg
                break
            }
        }

        ; If not found in arguments, check temp location
        if !dataFile {
            tempFile := A_Temp "\" FolderCreator.AppName "_ElevateData.txt"
            if FileExist(tempFile) {
                dataFile := tempFile
            }
        }

        if !dataFile {
            MsgBox("No elevation data found.", FolderCreator.AppName, "Iconx")
            ExitApp(1)
        }

        try {
            ; Use simple key-value parsing to avoid JSON issues
            fileContent := FileRead(dataFile)
            data := Map()

            lines := StrSplit(fileContent, "`n", "`r")
            for line in lines {
                if line = ""
                    continue
                parts := StrSplit(line, "=", "", 2)
                if parts.Length >= 2 {
                    key := Trim(parts[1])
                    value := Trim(parts[2])
                    data[key] := value
                }
            }

            ; Clean up data file
            FileDelete(dataFile)

            ; Validate that required properties exist
            if !data.Has("BasePath") || !data.Has("Paths") {
                throw Error("Invalid data format in elevation file")
            }

            ; Decode data, replace back with line breaks
            basePath := StrReplace(data["BasePath"], "|LINEBREAK|", "`n")
            pathsText := StrReplace(data["Paths"], "|LINEBREAK|", "`n")
            originalWorkingDir := data.Has("OriginalWorkingDir") ? StrReplace(data["OriginalWorkingDir"], "|LINEBREAK|", "`n") : A_WorkingDir

            ; Convert boolean values
            createParents := (data["CreateParents"] = "1")
            ignoreDuplicates := (data["IgnoreDuplicates"] = "1")

            ; Handle base path - if base path is relative, resolve using original working directory
            if !this.IsAbsolutePath(basePath) {
                ; Base path is relative, resolve using original working directory
                basePath := originalWorkingDir . "\" . basePath
                ; Normalize path
                basePath := this.NormalizeFullPath(basePath)
            }

            ; In elevated mode, directly execute creation
            this.ExecuteElevatedCreation(basePath, pathsText, createParents, ignoreDuplicates)
            ExitApp(0)

        } catch as e {
            MsgBox("Elevated mode data read failed: " e.Message, FolderCreator.AppName, "Iconx")
            ExitApp(1)
        }
    }

    ; Execute creation in elevated mode
    ExecuteElevatedCreation(basePath, pathsText, createParents, ignoreDuplicates) {
        ; Create simple interface to show elevated status
        elevateGUI := Gui("+ToolWindow", FolderCreator.AppName " - Administrator Mode")
        elevateGUI.SetFont("s10", "Segoe UI")
        elevateGUI.Add("Text", "w400 Center", "🔐 Creating folders with administrator privileges...")
        elevateGUI.Add("Text", "yp+30 w400 Center", "Do not close this window")
        elevateGUI.Show()

        ; Execute creation
        paths := this.ParsePaths(pathsText)

        successCount := 0
        failCount := 0
        resultDetails := ""

        for index, pathInfo in paths {
            result := this.CreateSingleFolder(basePath, pathInfo, createParents, ignoreDuplicates)
            if result.Success {
                successCount++
                resultDetails .= "✓ " pathInfo.Original "`n"
            } else {
                failCount++
                resultDetails .= "✗ " pathInfo.Original " - " result.Message "`n"
            }
        }

        elevateGUI.Destroy()

        resultMsg := "Administrator privilege creation completed!`n`n"
        resultMsg .= "✅ Success: " successCount " items`n"
        resultMsg .= "❌ Failed: " failCount " items`n"

        if resultDetails != "" {
            resultMsg .= "`nDetailed results:`n`n" resultDetails
        }

        MsgBox(resultMsg, FolderCreator.AppName, "Iconi")
    }

    ; Update status bar
    UpdateStatus(message) {
        try {
            this.StatusBar.Text := message
        }
    }

    ; Show error message
    ShowError(message) {
        MsgBox(message, FolderCreator.AppName, "Iconx")
        this.UpdateStatus("Error: " message)
    }
}

; Main program entry
creator := FolderCreator()

; Check if started in elevated mode first
if !creator.CheckElevatedMode() {
    ; If not in elevated mode, display main interface
    creator.ShowGUI()
}