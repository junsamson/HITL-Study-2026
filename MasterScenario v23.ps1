# =================================================================
#   HUMAN-AI DECISION MAKING SCENARIO SYSTEM (v22 - Debrief after TIAS)
# =================================================================
#   v22 CHANGES: Updated scoring system.
#   - Debriefing occurs after TIAS has been completed.
# =================================================================
#   v21 CHANGES: Updated scoring system.
#   - When the AI provides an incorrect answer, it does not count against the user.
# =================================================================
#   v20 CHANGES: Removed features.
#   - Removed Scenario Selection Logic.
#   - Changed "Scenario Selection" to "Scenarios."
#   - Changed capability to choose condition to be randomly assigned one.
# =================================================================
#   v19 CHANGES: Combined scenario flow, All/Mixed selection only, no external assistance.
#   - Adds assembly check to ensure GUI libraries can be loaded.
#   - Adds a file permissions check to test for write access before the study begins.
#   - Adds validation to the Age field to ensure it is a number between 18-99.
#   - Adds a check to prevent the use of duplicate Participant IDs.
#   - Removed option for Scenario Versions.
#   - Hid options for individual scenario selection.
#   - Removed ability to use a Search Engine or GenAI.
# =================================================================
#   v18 INTEGRATED CHANGES:
#   - Adds mandatory IRB informed consent screen at startup.
#   - Adds global exit handler ([Q]uit) to all console prompts.
#   - Adds automated post-study debriefing screen explaining AI manipulation.
#   - Implements color-coded output for improved readability.
#   - Adds Clear-Host, section separators, and pauses for better pacing.
#   - Re-displays context (scenario + AI rec) during evaluation prompts.
#   - Retains GUI for initial setup but moves consent/debrief to console.
#   - Edited Participant Choices
#   - Removed Participant ID text box and replaced with random ID issuance.
# =================================================================

# ------------------------------------------------------------
#   INITIAL VALIDATION CHECKS (NEW)
# ------------------------------------------------------------
# 1. Assembly Check: Ensure required .NET libraries for the GUI are available.
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
}
catch {
    Write-Host "FATAL ERROR: Failed to load required .NET assemblies for GUI." -ForegroundColor Red
    Write-Host "Please ensure you are running this script in a Windows PowerShell environment." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit."
    Exit
}

# 2. File Permissions Check: Ensure the script can write log files.
function Test-WritePermissions {
    $testFile = Join-Path (Get-Location) "write_test.tmp"
    try {
        [System.IO.File]::WriteAllText($testFile, "test")
        Remove-Item $testFile -Force
        return $true
    }
    catch {
        Write-Host "FATAL ERROR: Insufficient permissions to write to the script directory." -ForegroundColor Red
        Write-Host "Please run this script from a location where you have write permissions." -ForegroundColor Red
        Write-Host "Directory: $(Get-Location)" -ForegroundColor Red
        Read-Host "Press Enter to exit."
        return $false
    }
}


# ------------------------------------------------------------
#   GLOBAL SETTINGS / FLAGS
# ------------------------------------------------------------
$Global:IsAllScenarios = $false
$Global:IsMixedScenarios = $false
$Global:ScriptTerminated = $false # Global flag for script termination
$Global:GoogleWebAppUrl = "https://script.google.com/macros/s/AKfycbziI-drvcH9o48MOaTHdH9syv0FqibYh4QOW-8-WfmiygENrx2AA8Ecp5xemw-Cic-stg/exec"

# ------------------------------------------------------------
#   PARTICIPANT VARIABLES
# ------------------------------------------------------------
$Global:ParticipantID = ""
$Global:SelectedOccupation = ""
$Global:SelectedCondition = ""
$Global:SelectedVersion = "Combined"
$Global:SelectedScenarioNumber = 1
$Global:ParticipantAge = ""
$Global:ParticipantPosition = ""
$Global:ParticipantEducation = ""
$Global:ParticipantAIExperience = ""
$Global:ParticipantConsent = $false

# ------------------------------------------------------------
#   SCENARIO SCORING SYSTEM
# ------------------------------------------------------------
$Global:Score = [PSCustomObject]@{
    DecisionAccuracy = 0
    ErrorDetection   = 0
    TotalQuestions   = 0
    Condition        = ""
}

# ------------------------------------------------------------
#   EXTERNAL ASSISTANCE VARIABLES
# ------------------------------------------------------------
$script:ExternalAssistanceUsed = $false
$script:ExternalAssistanceType = ""
$script:ExternalAssistanceProvider = ""
$script:ExternalAssistanceQuery = ""
$script:AICorrectness = ""

# ------------------------------------------------------------
#   TRUST SURVEY VARIABLES
# ------------------------------------------------------------
$script:TrustSurveyResponses = @{}
$script:TrustSurveyCompleted = $false
$script:TrustSurveyComment = ""

$script:TrustSurveyItems = @(
    [PSCustomObject]@{ Number = 1; Text = "The system is deceptive." },
    [PSCustomObject]@{ Number = 2; Text = "The system behaves in an underhanded manner." },
    [PSCustomObject]@{ Number = 3; Text = "I am suspicious of the systemâ€™s intent, action, or outputs." },
    [PSCustomObject]@{ Number = 4; Text = "I am wary of the system." },
    [PSCustomObject]@{ Number = 5; Text = "The systemâ€™s actions will have a harmful or injurious outcome." },
    [PSCustomObject]@{ Number = 6; Text = "I am confident in the system." },
    [PSCustomObject]@{ Number = 7; Text = "The system provides security." },
    [PSCustomObject]@{ Number = 8; Text = "The system has integrity." },
    [PSCustomObject]@{ Number = 9; Text = "The system is dependable." },
    [PSCustomObject]@{ Number = 10; Text = "The system is reliable." },
    [PSCustomObject]@{ Number = 11; Text = "I can trust the system." },
    [PSCustomObject]@{ Number = 12; Text = "I am familiar with the system." }
)

# ------------------------------------------------------------
#   IRB & UX HELPER FUNCTIONS (NEW)
# ------------------------------------------------------------
function Show-ConsentForm {
    Clear-Host
    Write-Host "=========================================================================" -ForegroundColor White
    Write-Host "                       INFORMED CONSENT FOR RESEARCH" -ForegroundColor White
    Write-Host "=========================================================================" -ForegroundColor White
    Write-Host
    Write-Host "Study Title:  Human-AI Decision Making Study" -ForegroundColor Cyan
    Write-Host
    Write-Host "Purpose:      This study aims to understand how people interact with AI" -ForegroundColor Cyan
    Write-Host "              recommendations in professional decision-making scenarios." -ForegroundColor Cyan
    Write-Host
    Write-Host "Procedure:    You will be presented with one or more simulated scenarios." -ForegroundColor Cyan
    Write-Host "              You may be asked to make a decision, evaluate an AI, or both." -ForegroundColor Cyan
    Write-Host "              The session will conclude with a short questionnaire." -ForegroundColor Cyan
    Write-Host
    Write-Host "Voluntary:    Your participation is completely voluntary. You may refuse to" -ForegroundColor Cyan
    Write-Host "              participate or withdraw at any time without penalty." -ForegroundColor Cyan
    Write-Host
    Write-Host "Data:         Your responses will be recorded anonymously. Data logs will not" -ForegroundColor Cyan
    Write-Host "              contain any personally identifiable information (PII)." -ForegroundColor Cyan
    Write-Host
    Write-Host "=========================================================================" -ForegroundColor White

    do {
        $consent = Read-Host "Do you consent to participate in this study? (Y/N)"
        if ($consent -eq 'N' -or $consent -eq 'n') {
            Write-Host "`nThank you. The study will now exit." -ForegroundColor Red
            Start-Sleep -Seconds 3
            Exit
        }
    } until ($consent -eq 'Y' -or $consent -eq 'y')

    $Global:ParticipantConsent = $true
}

function Handle-Exit {
    Clear-Host
    Write-Host "`n--- STUDY EXITED ---" -ForegroundColor Red
    Write-Host "You have chosen to quit the study."

    $logFiles = @("ScenarioResults.csv", "TrustSurveyResults_TIAS.csv")
    $filesExist = $false
    foreach ($file in $logFiles) {
        if (Test-Path $file) {
            $filesExist = $true
            break
        }
    }

    if ($filesExist) {
        $choice = Read-Host "Would you like to delete all data logged in this session? (Y/N)"
        if ($choice -eq 'y' -or $choice -eq 'Y') {
            foreach ($file in $logFiles) {
                if (Test-Path $file) {
                    Remove-Item $file -Force
                    Write-Host "Deleted $file." -ForegroundColor Yellow
                }
            }
            Write-Host "All session logs have been deleted." -ForegroundColor Green
        } else {
            Write-Host "Session logs have been saved." -ForegroundColor Green
        }
    } else {
        Write-Host "No data was logged in this session."
    }

    Write-Host "`nThe script will now close."
    $Global:ScriptTerminated = $true # Set the flag
    Start-Sleep -Seconds 4
}

function Show-Debriefing {
    if ($Global:ScriptTerminated) { return } # Don't show if user quit
    Clear-Host
    Write-Host "=========================================================================" -ForegroundColor White
    Write-Host "                                 DEBRIEFING" -ForegroundColor White
    Write-Host "=========================================================================" -ForegroundColor White
    Write-Host
    Write-Host "Thank you for completing the scenarios." -ForegroundColor Cyan
    Write-Host
    Write-Host "An important part of this study was to understand how trust is affected" -ForegroundColor Cyan
    Write-Host "by AI performance. To achieve this, the AI's recommendations were" -ForegroundColor Cyan
    Write-Host "sometimes programmed to be correct and sometimes programmed to be" -ForegroundColor Red
    Write-Host "incorrect. This was done randomly as part of the experimental design." -ForegroundColor Red
    Write-Host
    Write-Host "This manipulation was necessary to measure how people respond to both" -ForegroundColor Cyan
    Write-Host "reliable and unreliable AI assistance. The AI's performance in this" -ForegroundColor Cyan
    Write-Host "simulation does not reflect the capabilities of any real-world AI system." -ForegroundColor Cyan
    Write-Host
    Write-Host "=========================================================================" -ForegroundColor White
    Read-Host "Press Enter to continue to the final part of the study..."
}

function Write-Banner {
    param([string]$Text)
    Write-Host "`n=========================================================================" -ForegroundColor White
    Write-Host "                         $Text" -ForegroundColor White
    Write-Host "=========================================================================" -ForegroundColor White
}

# ------------------------------------------------------------
#   QUESTION FUNCTION (MODIFIED)
# ------------------------------------------------------------
function Ask-Question {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Question,

        [Parameter(Mandatory=$true)]
        [array]$Options
    )

    Write-Host "`n$Question" -ForegroundColor Green

    for ($i = 0; $i -lt $Options.Count; $i++) {
        Write-Host "[$($i + 1)] $($Options[$i])" -ForegroundColor Cyan
    }

    do {
        $prompt = "Select an option (1-$($Options.Count)) or [Q] to quit"
        $choice = Read-Host $prompt
        if ($choice -eq 'q' -or $choice -eq 'Q') {
            Handle-Exit
            return $null # Signal that the user quit
        }
    } until ($choice -as [int] -and [int]$choice -ge 1 -and [int]$choice -le $Options.Count)

    return [int]$choice
}

# ------------------------------------------------------------
#   SCORING FUNCTIONS (MODIFIED)
# ------------------------------------------------------------
function Update-Accuracy {
    param(
        [int]$UserChoice,
        [int]$CorrectChoice,
        [bool]$SuppressFeedback = $false
    )
    $Global:Score.TotalQuestions++
    if ($UserChoice -eq $CorrectChoice) {
        $Global:Score.DecisionAccuracy++
        if (-not $SuppressFeedback) {
            Write-Host "[OK] Correct decision (Accuracy +1)" -ForegroundColor Green
        }
        return $true
    } else {
        if (-not $SuppressFeedback) {
            Write-Host "[X] Incorrect decision" -ForegroundColor Red
        }
        return $false
    }
}

function Update-ErrorDetection {
    param(
        [bool]$DetectedError,
        [bool]$AIContainsError,
        [bool]$SuppressFeedback = $false
    )
    if ($DetectedError -and $AIContainsError) {
        $Global:Score.ErrorDetection++
        if (-not $SuppressFeedback) {
            Write-Host "[OK] Correctly identified AI error (Error Detection +1)" -ForegroundColor Green
        }
        return $true
    } elseif (-not $DetectedError -and -not $AIContainsError) {
        $Global:Score.ErrorDetection++
        if (-not $SuppressFeedback) {
            Write-Host "[OK] Correctly identified no AI error (Error Detection +1)" -ForegroundColor Green
        }
        return $true
    } elseif (-not $DetectedError -and $AIContainsError) {
        if (-not $SuppressFeedback) {
            Write-Host "[X] Missed an AI error" -ForegroundColor Red
        }
        return $false
    } else {
        if (-not $SuppressFeedback) {
            Write-Host "[X] Incorrectly identified an error (False Alarm)" -ForegroundColor Red
        }
        return $false
    }
}

# ------------------------------------------------------------
#   BASE SCENARIO LIBRARY
# ------------------------------------------------------------
function Get-ScenarioContent {
    param(
        [string]$Occupation,
        [int]$ScenarioNumber
    )

    switch ("$Occupation-$ScenarioNumber") {

        "IT-1" {
            return @{
                Intro = "User reports their password is not working when trying to log into their workstation."
                CriticalQuestion = "What is your next step?"
                Options = @(
                    "Verify username and check account lockout status",
                    "Reset the password",
                    "Tell the user to try again later"
                )
                CorrectOption = 1
                IncorrectOption = 2
                CorrectAIRecommendation = "Verify the user's username and check if the account is locked before taking further action."
                IncorrectAIRecommendation = "Reset the user's password immediately without checking anything."
                StructuredPrompts = @(
                    "Check for account lockout",
                    "Verify username spelling",
                    "Confirm last successful login",
                    "Review security policy for password resets"
                )
            }
        }

        "IT-2" {
            return @{
                Intro = "A user reports their desktop is not connecting to the internet."
                CriticalQuestion = "What is your first troubleshooting step?"
                Options = @(
                    "Check physical network connection and Wi-Fi status",
                    "Reinstall the operating system",
                    "Escalate issue to network engineering"
                )
                CorrectOption = 1
                IncorrectOption = 2
                CorrectAIRecommendation = "Check the physical network cable and the machine's Wi-Fi status first."
                IncorrectAIRecommendation = "Reinstall the operating system to fix connectivity."
                StructuredPrompts = @(
                    "Check network adapter status",
                    "Test connectivity to gateway",
                    "Verify if issue is local or widespread",
                    "Review recent configuration changes"
                )
            }
        }

        "IT-3" {
            return @{
                Intro = "A server outage is affecting multiple departments and critical applications."
                CriticalQuestion = "What is your immediate response?"
                Options = @(
                    "Check monitoring/alerts and identify scope of impact",
                    "Restart all affected servers",
                    "Wait to see if the issue resolves on its own"
                )
                CorrectOption = 1
                IncorrectOption = 2
                CorrectAIRecommendation = "Check monitoring dashboards and alerts to understand the scope and nature of the outage before acting."
                IncorrectAIRecommendation = "Restart all servers immediately to restore service."
                StructuredPrompts = @(
                    "Review monitoring dashboards",
                    "Identify affected services",
                    "Assess risk of restart",
                    "Notify stakeholders if needed"
                )
            }
        }

        "IT-4" {
            return @{
                Intro = "Security tools flag suspicious login attempts from multiple locations for a single user."
                CriticalQuestion = "What is your next step?"
                Options = @(
                    "Temporarily lock the account and investigate",
                    "The alerts may be false positives",
                    "Send a password reset link without investigation"
                )
                CorrectOption = 1
                IncorrectOption = 2
                CorrectAIRecommendation = "Temporarily lock the account to prevent unauthorized access, then investigate the login attempts."
                IncorrectAIRecommendation = "Ignore the alerts; they are likely false positives."
                StructuredPrompts = @(
                    "Review login history",
                    "Check geolocation anomalies",
                    "Consult security policy",
                    "Determine if incident response is needed"
                )
            }
        }

        "IT-5" {
            return @{
                Intro = "A database server shows high disk usage and slow query performance."
                CriticalQuestion = "What is your next step?"
                Options = @(
                    "Review query performance and disk utilization metrics",
                    "Add more disk space",
                    "Restart the database service"
                )
                CorrectOption = 1
                IncorrectOption = 2
                CorrectAIRecommendation = "Analyze the slow query logs and disk I/O metrics to identify the root cause of the performance issue."
                IncorrectAIRecommendation = "Restart the database service immediately."
                StructuredPrompts = @(
                    "Check slow query logs",
                    "Review recent schema changes",
                    "Assess disk I/O patterns",
                    "Evaluate indexing strategy"
                )
            }
        }
    }
}

function New-RandomizedOptions {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Options
    )

    $items = @()

    for ($i = 0; $i -lt $Options.Count; $i++) {
        $items += [PSCustomObject]@{
            OriginalIndex = $i + 1
            Text = [string]$Options[$i]
        }
    }

    $shuffled = $items | Sort-Object { Get-Random }

    $displayOptions = @()
    $displayToOriginal = @{}
    $originalToDisplay = @{}

    for ($displayIndex = 0; $displayIndex -lt $shuffled.Count; $displayIndex++) {
        $displayNumber = $displayIndex + 1
        $originalNumber = $shuffled[$displayIndex].OriginalIndex

        $displayOptions += $shuffled[$displayIndex].Text
        $displayToOriginal[$displayNumber] = $originalNumber
        $originalToDisplay[$originalNumber] = $displayNumber
    }

    return [PSCustomObject]@{
        DisplayOptions = $displayOptions
        DisplayToOriginal = $displayToOriginal
        OriginalToDisplay = $originalToDisplay
    }
}

function Write-ScenarioLog {
    param(
        [Parameter(Mandatory=$true)]
        [int]$ScenarioNumber,

        [Parameter(Mandatory=$true)]
        [string]$Condition,

        [Parameter(Mandatory=$true)]
        [string]$Version,

        [Parameter(Mandatory=$true)]
        [string]$ScenarioOccupation,

        [Parameter(Mandatory=$true)]
        [string]$AICorrectness,

        [Parameter(Mandatory=$true)]
        [bool]$AIContainsError,

        [Parameter(Mandatory=$true)]
        [int]$ScenarioAccuracy,

        [Parameter(Mandatory=$true)]
        [int]$ScenarioErrorDetection,

        [Parameter(Mandatory=$true)]
        [int]$ScenarioQuestions,

        [Parameter(Mandatory=$true)]
        [string]$AIViewedDuringDecision,

        [bool]$UserAgreedWithAI,

        [bool]$AIRecommendationCorrect
    )

    $logPath = Join-Path (Get-Location) "ScenarioResults.csv"

    $logEntry = [PSCustomObject]@{
        Timestamp                 = (Get-Date)
        ParticipantID             = $Global:ParticipantID
        Age                       = $Global:ParticipantAge
        PositionTitle             = $Global:ParticipantPosition
        EducationLevel            = $Global:ParticipantEducation
        AIExperience              = $Global:ParticipantAIExperience
        ConsentGiven              = $Global:ParticipantConsent
        Occupation                = $Global:SelectedOccupation
        ScenarioOccupation        = $ScenarioOccupation
        Condition                 = $Condition
        Version                   = $Version
        ScenarioNumber            = $ScenarioNumber
        AICorrectness             = $AICorrectness
        AIContainsError           = $AIContainsError
        ScenarioAccuracy          = $ScenarioAccuracy
        ScenarioQuestions         = $ScenarioQuestions
        ScenarioErrorDetection   = $ScenarioErrorDetection
        CumulativeAccuracy        = $Global:Score.DecisionAccuracy
        CumulativeQuestions       = $Global:Score.TotalQuestions
        CumulativeErrorDetection  = $Global:Score.ErrorDetection
        AIViewedDuringDecision    = $AIViewedDuringDecision
        AssistanceUsed            = $script:ExternalAssistanceUsed
        AssistanceType            = $script:ExternalAssistanceType
        AssistanceProvider        = $script:ExternalAssistanceProvider
        ExternalAssistanceQuery   = $script:ExternalAssistanceQuery
    }

    if (-not (Test-Path $logPath)) {
        $logEntry | Export-Csv -Path $logPath -NoTypeInformation -Encoding UTF8
    }
    else {
        $logEntry | Export-Csv -Path $logPath -NoTypeInformation -Append -Encoding UTF8
    }

    Write-Host "`nScenario results logged to $logPath"
}

function Calculate-TrustScores {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Responses
    )

    $scoredResponses = @{}
    foreach ($itemNumber in 1..12) {
        if (-not $Responses.ContainsKey($itemNumber)) {
            throw "Missing TIAS response for item $itemNumber."
        }

        if ($itemNumber -le 5) {
            $scoredResponses[$itemNumber] = 8 - [int]$Responses[$itemNumber]
        }
        else {
            $scoredResponses[$itemNumber] = [int]$Responses[$itemNumber]
        }
    }

    $mean = ($scoredResponses.Values | ForEach-Object { [double]$_ } | Measure-Object -Average).Average

    return [PSCustomObject]@{
        TrustInAutomationComposite = [Math]::Round($mean, 3)
        ScoredResponses = $scoredResponses
    }
}

function Write-TrustSurveyLog {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Responses,

        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Scores,

        [string]$Comment = ""
    )

    $logPath = Join-Path (Get-Location) "TrustSurveyResults_TIAS.csv"

    $logEntry = [ordered]@{
        Timestamp                     = (Get-Date)
        ParticipantID                 = $Global:ParticipantID
        Age                           = $Global:ParticipantAge
        PositionTitle                 = $Global:ParticipantPosition
        EducationLevel                = $Global:ParticipantEducation
        AIExperience                  = $Global:ParticipantAIExperience
        ConsentGiven                  = $Global:ParticipantConsent
        Occupation                    = $Global:SelectedOccupation
        Condition                     = $Global:SelectedCondition
        Version                       = $Global:SelectedVersion
        ScenarioSelection             = if ($Global:IsAllScenarios) { "All Scenarios (1-5)" } else { "Mixed Scenarios (1-5)" }
        SurveyCompleted               = $true
    }

    foreach ($itemNumber in 1..12) {
        $itemKey = "Item{0:D2}" -f $itemNumber
        $scoredKey = "ScoredItem{0:D2}" -f $itemNumber
        $logEntry[$itemKey] = $Responses[$itemNumber]
        $logEntry[$scoredKey] = $Scores.ScoredResponses[$itemNumber]
    }

    $logEntry["TrustInAutomationComposite"] = $Scores.TrustInAutomationComposite
    $logEntry["ParticipantComment"] = $Comment

    $object = [PSCustomObject]$logEntry

    if (-not (Test-Path $logPath)) {
        $object | Export-Csv -Path $logPath -NoTypeInformation -Encoding UTF8
    }
    else {
        $object | Export-Csv -Path $logPath -NoTypeInformation -Append -Encoding UTF8
    }

    Write-Host "`nTIAS survey results logged to $logPath"
}

function Start-TrustSurvey {

    $script:TrustSurveyResponses = @{}
    $script:TrustSurveyComment = ""
    $script:TrustSurveyCompleted = $false

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Post-Simulation Trust in AI Questionnaire"
    $form.Size = New-Object System.Drawing.Size(1120, 850)
    $form.StartPosition = "CenterScreen"
    $form.MinimizeBox = $false
    $form.MaximizeBox = $false

    $header = New-Object System.Windows.Forms.Label
    $header.Text = "Post-Simulation Trust in AI Questionnaire"
    $header.Font = New-Object System.Drawing.Font("Arial", 16, [System.Drawing.FontStyle]::Bold)
    $header.Location = New-Object System.Drawing.Point(20, 15)
    $header.AutoSize = $true
    $form.Controls.Add($header)

    $instructions = New-Object System.Windows.Forms.Label
    $instructions.Text = "Please consider only the AI-supported system you used during the simulation. For each statement, select the number that best represents how well it describes your experience with that system. There are no right or wrong answers."
    $instructions.Location = New-Object System.Drawing.Point(20, 50)
    $instructions.Size = New-Object System.Drawing.Size(1060, 42)
    $instructions.AutoSize = $false
    $form.Controls.Add($instructions)

    $scaleLabel = New-Object System.Windows.Forms.Label
    $scaleLabel.Text = "Response scale:  1 = Not at all        4 = Moderately        7 = Extremely"
    $scaleLabel.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
    $scaleLabel.Location = New-Object System.Drawing.Point(20, 98)
    $scaleLabel.Size = New-Object System.Drawing.Size(1060, 25)
    $form.Controls.Add($scaleLabel)

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point(15, 130)
    $panel.Size = New-Object System.Drawing.Size(1080, 600)
    $panel.AutoScroll = $true
    $panel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $form.Controls.Add($panel)

    $statementHeading = New-Object System.Windows.Forms.Label
    $statementHeading.Text = "Statement"
    $statementHeading.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Bold)
    $statementHeading.Location = New-Object System.Drawing.Point(10, 8)
    $statementHeading.Size = New-Object System.Drawing.Size(570, 22)
    $panel.Controls.Add($statementHeading)

    $numberHeading = New-Object System.Windows.Forms.Label
    $numberHeading.Text = "Select one response (1-7)"
    $numberHeading.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Bold)
    $numberHeading.Location = New-Object System.Drawing.Point(600, 8)
    $numberHeading.Size = New-Object System.Drawing.Size(430, 22)
    $panel.Controls.Add($numberHeading)

    $y = 38
    $controlsByItem = @{}

    foreach ($item in $script:TrustSurveyItems) {
        $itemLabel = New-Object System.Windows.Forms.Label
        $itemLabel.Text = "$($item.Number). $($item.Text)"
        $itemLabel.Location = New-Object System.Drawing.Point(10, $y)
        $itemLabel.Size = New-Object System.Drawing.Size(570, 42)
        $itemLabel.AutoEllipsis = $false
        $panel.Controls.Add($itemLabel)

        $radioGroupPanel = New-Object System.Windows.Forms.Panel
        $radioGroupPanel.Location = New-Object System.Drawing.Point(600, $y)
        $radioGroupPanel.Size = New-Object System.Drawing.Size(430, 42)
        $panel.Controls.Add($radioGroupPanel)

        $radioButtons = @()
        for ($v = 1; $v -le 7; $v++) {
            $rb = New-Object System.Windows.Forms.RadioButton
            $rb.Text = "$v"
            $rb.Location = New-Object System.Drawing.Point((($v - 1) * 55), 8)
            $rb.Size = New-Object System.Drawing.Size(48, 25)
            $rb.Tag = $v
            $radioGroupPanel.Controls.Add($rb)
            $radioButtons += $rb
        }

        $controlsByItem[$item.Number] = $radioButtons
        $y += 48
    }

    $commentLabel = New-Object System.Windows.Forms.Label
    $commentLabel.Text = "Optional Participant Comment: Please briefly describe any aspect of your experience with the AI system that influenced your level of trust in the system."
    $commentLabel.Location = New-Object System.Drawing.Point(10, $y)
    $commentLabel.Size = New-Object System.Drawing.Size(1020, 38)
    $panel.Controls.Add($commentLabel)
    $y += 42

    $txtComment = New-Object System.Windows.Forms.TextBox
    $txtComment.Location = New-Object System.Drawing.Point(10, $y)
    $txtComment.Size = New-Object System.Drawing.Size(1015, 75)
    $txtComment.Multiline = $true
    $txtComment.ScrollBars = "Vertical"
    $panel.Controls.Add($txtComment)

    $btnSubmit = New-Object System.Windows.Forms.Button
    $btnSubmit.Text = "Submit Post-Simulation Survey"
    $btnSubmit.Location = New-Object System.Drawing.Point(405, 755)
    $btnSubmit.Size = New-Object System.Drawing.Size(280, 35)

    $btnSubmit.Add_Click({
        $missing = @()

        foreach ($item in $script:TrustSurveyItems) {
            $selectedValue = $null

            foreach ($rb in $controlsByItem[$item.Number]) {
                if ($rb.Checked) {
                    $selectedValue = [int]$rb.Tag
                    break
                }
            }

            if ($null -eq $selectedValue) {
                $missing += $item.Number
            }
            else {
                $script:TrustSurveyResponses[$item.Number] = $selectedValue
            }
        }

        if ($missing.Count -gt 0) {
            [System.Windows.Forms.MessageBox]::Show(
                "Please answer all 12 questionnaire items before submitting.`nMissing item(s): $($missing -join ', ')",
                "Incomplete Questionnaire",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }

        $script:TrustSurveyComment = $txtComment.Text
        $script:TrustSurveyCompleted = $true
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })

    $form.Controls.Add($btnSubmit)

    $dialogResult = $form.ShowDialog()

    if (-not $script:TrustSurveyCompleted) {
        Write-Warning "Post-simulation TIAS questionnaire was not completed."
        return $null
    }

    $trustScores = Calculate-TrustScores -Responses $script:TrustSurveyResponses

    Write-TrustSurveyLog `
        -Responses $script:TrustSurveyResponses `
        -Scores $trustScores `
        -Comment $script:TrustSurveyComment

    Write-Host "`n=== Post-Simulation Trust in Automation Scale Complete ==="
    Write-Host "TIAS composite recorded for research analysis."
    Write-Host "Note: The composite score is not displayed to the participant."

    return $trustScores
}

# ------------------------------------------------------------
#   GOOGLE APPS SCRIPT UPLOAD FUNCTION (NEW)
# ------------------------------------------------------------
function Send-FileToGoogleWebApp {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [string]$ServerUrl
    )

    if (-not (Test-Path $FilePath)) {
        Write-Warning "File not found: $FilePath"
        return $false
    }

    try {
        $fileName = Split-Path $FilePath -Leaf
        Write-Host "Uploading $fileName to Google Apps Script Server..." -ForegroundColor Cyan

        $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $FilePath).Path)
        $base64Content = [System.Convert]::ToBase64String($bytes)

        $payload = @{
            filename      = $fileName
            file          = $base64Content
            participantId = $Global:ParticipantID
            mimeType      = "text/csv"
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri $ServerUrl -Method Post -Body $payload -ContentType "application/json"
        Write-Host "[OK] Successfully uploaded $fileName." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "ERROR: Failed to upload $FilePath." -ForegroundColor Red
        Write-Host "Error Details: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# ------------------------------------------------------------
#   MASTER SCENARIO ENGINE (MODIFIED)
# ------------------------------------------------------------
function Start-Scenario {
    param(
        [Parameter(Mandatory=$true)] [ValidateSet("AIOnly","AI+HITL")] [string]$Condition,
        [Parameter(Mandatory=$true)] [ValidateSet("Combined")] [string]$Version,
        [Parameter(Mandatory=$true)] [ValidateSet("IT")] [string]$Occupation,
        [Parameter(Mandatory=$true)] [ValidateRange(1,5)] [int]$ScenarioNumber
    )

    if ($Global:ScriptTerminated) { return }

    Clear-Host
    Write-Banner "SCENARIO $ScenarioNumber"
    Write-Host "Condition:  $Condition" -ForegroundColor Cyan
    Write-Host "Occupation: $Occupation" -ForegroundColor Cyan

    $Global:Score.Condition = $Condition

    $script:ExternalAssistanceUsed = $false
    $script:ExternalAssistanceType = ""
    $script:ExternalAssistanceProvider = ""
    $script:ExternalAssistanceQuery = ""
    $script:AICorrectness = ""

    Set-Variable -Name "SelectedScenarioNumber" -Value $ScenarioNumber -Scope Global

    $accuracyBefore = $Global:Score.DecisionAccuracy
    $errorBefore = $Global:Score.ErrorDetection
    $questionsBefore = $Global:Score.TotalQuestions

    $isAICorrect = (Get-Random -Minimum 0 -Maximum 2) -eq 1
    $baseScenario = Get-ScenarioContent -Occupation $Occupation -ScenarioNumber $ScenarioNumber
    $scenario = $baseScenario.PSObject.Copy()

    if ($isAICorrect) {
        $scenario.AIRecommendation = "AI recommendation: $($baseScenario.CorrectAIRecommendation)"
        $scenario.ContainsError = $false
        $scenario.AIChoice = $baseScenario.CorrectOption
        $script:AICorrectness = "Correct"
    } else {
        $scenario.AIRecommendation = "AI recommendation: $($baseScenario.IncorrectAIRecommendation)"
        $scenario.ContainsError = $true
        $scenario.AIChoice = $baseScenario.IncorrectOption
        $script:AICorrectness = "Incorrect"
    }

    $optionMap = New-RandomizedOptions -Options $scenario.Options
    $displayOptions = $optionMap.DisplayOptions
    $correctDisplayChoice = [int]$optionMap.OriginalToDisplay[[int]$scenario.CorrectOption]
    $aiDisplayChoice = [int]$optionMap.OriginalToDisplay[[int]$scenario.AIChoice]

    Write-Host "`n--- Scenario Context ---" -ForegroundColor Cyan
    Write-Host $scenario.Intro -ForegroundColor Cyan
    Read-Host "`nPress Enter to review the task..."
    if ($Global:ScriptTerminated) { return }

    $userDecisionOriginal = $null
    $aiViewedDuringDecision = "Not Applicable"
    $UserAgreesWithAI = $null

    if ($Condition -eq "AIOnly") {
        Clear-Host
        Write-Banner "AI-ONLY CONDITION"
        Write-Host "--- Scenario Context ---" -ForegroundColor Cyan
        Write-Host $scenario.Intro -ForegroundColor Cyan
        Write-Host "`n--- Decision Options ---" -ForegroundColor White
        for ($i = 0; $i -lt $displayOptions.Count; $i++) {
            Write-Host "$($i + 1). $($displayOptions[$i])" -ForegroundColor White
        }
        Write-Host "`nThe AI will now make the decision." -ForegroundColor Cyan
        Write-Host $scenario.AIRecommendation -ForegroundColor Yellow

        $userDecisionOriginal = [int]$scenario.AIChoice

        Write-Host "`nAI has selected option #$aiDisplayChoice`: $($displayOptions[$aiDisplayChoice - 1])" -ForegroundColor Yellow

        $agreeChoice = Ask-Question `
            -Question "Do you agree with the AI recommendation?" `
            -Options @("Yes","No")

        if ($Global:ScriptTerminated) { return }

        $UserAgreesWithAI = ($agreeChoice -eq 1)

        Read-Host "Press Enter to continue"
        if ($Global:ScriptTerminated) { return }
    } else { # AI+HITL Condition
        Clear-Host
        Write-Banner "AI RECOMMENDATION AND STRUCTURED REVIEW"
        Write-Host "--- Scenario Context ---" -ForegroundColor Cyan
        Write-Host $scenario.Intro -ForegroundColor Cyan
        Write-Host "`n--- AI Recommendation ---" -ForegroundColor Yellow
        Write-Host $scenario.AIRecommendation -ForegroundColor Yellow
        Write-Host "`n--- Structured Review Prompts ---" -ForegroundColor White
        foreach ($prompt in $baseScenario.StructuredPrompts) {
            Write-Host " - $prompt" -ForegroundColor Cyan
        }
        Read-Host "`nReview the recommendation and prompts, then press Enter to make your decision..."
        if ($Global:ScriptTerminated) { return }

        Clear-Host
        Write-Banner "YOUR DECISION"
        Write-Host "--- Scenario Context ---" -ForegroundColor Cyan
        Write-Host $scenario.Intro -ForegroundColor Cyan
        Write-Host "`n--- AI's Recommendation ---" -ForegroundColor Yellow
        Write-Host $scenario.AIRecommendation -ForegroundColor Yellow
        Write-Host "`n--- Decision Options ---" -ForegroundColor White
        for ($i = 0; $i -lt $displayOptions.Count; $i++) {
            Write-Host "$($i + 1). $($displayOptions[$i])" -ForegroundColor White
        }

        $displayChoice = Ask-Question -Question "`n$($scenario.CriticalQuestion)" -Options $displayOptions
        if ($Global:ScriptTerminated) { return }
        $userDecisionOriginal = [int]$optionMap.DisplayToOriginal[[int]$displayChoice]
    }

    Clear-Host
    Write-Banner "DECISION & AI EVALUATION"
    if ($Condition -eq "AIOnly") {
        if ($scenario.ContainsError) {
            if (-not $UserAgreesWithAI) {
                $Global:Score.DecisionAccuracy++
                Write-Host "[OK] Correctly rejected incorrect AI recommendation (Accuracy +1)" -ForegroundColor Green
            }
            else {
                Write-Host "[X] Accepted incorrect AI recommendation" -ForegroundColor Red
            }
        }
        else {
            if ($UserAgreesWithAI) {
                $Global:Score.DecisionAccuracy++
                Write-Host "[OK] Correctly accepted valid AI recommendation (Accuracy +1)" -ForegroundColor Green
            }
            else {
                Write-Host "[X] Rejected correct AI recommendation" -ForegroundColor Red
            }
        }
        $Global:Score.TotalQuestions++
    }
    else {
        if ($null -ne $userDecisionOriginal) {
            Update-Accuracy `
                -UserChoice $userDecisionOriginal `
                -CorrectChoice ([int]$scenario.CorrectOption) `
                -SuppressFeedback $false
        }
    }

    Write-Host "`n--- Final AI Evaluation ---" -ForegroundColor White
    Write-Host "`n--- Scenario Context ---" -ForegroundColor Cyan
    Write-Host $scenario.Intro -ForegroundColor Cyan
    Write-Host "`n--- AI's Recommendation Was ---" -ForegroundColor Yellow
    Write-Host $scenario.AIRecommendation -ForegroundColor Yellow
    
    $err = Ask-Question -Question "`nBased on the information, do you believe the AI's recommendation was flawed or erroneous?" -Options @("Yes", "No")
    if ($Global:ScriptTerminated) { return }
    Update-ErrorDetection -DetectedError ($err -eq 1) -AIContainsError ([bool]$scenario.ContainsError) -SuppressFeedback ($Condition -eq "AIOnly")

    $scenarioAccuracy = $Global:Score.DecisionAccuracy - $accuracyBefore
    $scenarioErrorDetection = $Global:Score.ErrorDetection - $errorBefore
    $scenarioQuestions = $Global:Score.TotalQuestions - $questionsBefore

    Write-Host "`n=== Scenario Complete ===" -ForegroundColor White
    Read-Host "Press Enter to log results and continue..."
    if ($Global:ScriptTerminated) { return }

    Write-ScenarioLog `
        -ScenarioNumber $ScenarioNumber `
        -Condition $Condition `
        -Version $Version `
        -ScenarioOccupation $Occupation `
        -AICorrectness $script:AICorrectness `
        -AIContainsError ([bool]$scenario.ContainsError) `
        -ScenarioAccuracy $scenarioAccuracy `
        -ScenarioErrorDetection $scenarioErrorDetection `
        -ScenarioQuestions $scenarioQuestions `
        -AIViewedDuringDecision $aiViewedDuringDecision `
        -UserAgreedWithAI $UserAgreesWithAI `
        -AIRecommendationCorrect $isAICorrect
}

# ------------------------------------------------------------
#   GUI INPUT FORM / ENTRY POINT (MODIFIED)
# ------------------------------------------------------------
function Select-ScenarioOptions {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "IT Support Scenario Configuration"
    $form.Size = New-Object System.Drawing.Size(760,450)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false

    function Add-FieldLabel([string]$t,[int]$y) {
        $l=New-Object System.Windows.Forms.Label
        $l.Text=$t; $l.Location=New-Object System.Drawing.Point(25,$y)
        $l.Size=New-Object System.Drawing.Size(180,25); $form.Controls.Add($l)
    }

    Add-FieldLabel "Participant ID:" 25
    $lblParticipantID = New-Object System.Windows.Forms.Label
    $lblParticipantID.Text = "Automatically assigned when the scenario starts"
    $lblParticipantID.Location = New-Object System.Drawing.Point(210,22)
    $lblParticipantID.Size = New-Object System.Drawing.Size(500,25)
    $form.Controls.Add($lblParticipantID)

    Add-FieldLabel "Age:" 60
    $txtAge=New-Object System.Windows.Forms.TextBox
    $txtAge.Location=New-Object System.Drawing.Point(210,57); $txtAge.Size=New-Object System.Drawing.Size(120,25); $form.Controls.Add($txtAge)

    Add-FieldLabel "Position/Job Title:" 95
    $txtPos=New-Object System.Windows.Forms.TextBox
    $txtPos.Location=New-Object System.Drawing.Point(210,92); $txtPos.Size=New-Object System.Drawing.Size(500,25); $form.Controls.Add($txtPos)

    Add-FieldLabel "Education Level:" 130
    $edu=New-Object System.Windows.Forms.ComboBox
    $edu.Location=New-Object System.Drawing.Point(210,127); $edu.Size=New-Object System.Drawing.Size(300,25)
    $edu.DropDownStyle="DropDownList"; [void]$edu.Items.AddRange(@("High School","Associate Degree","Bachelor's Degree","Master's Degree","Doctoral Degree","Other")); $edu.SelectedIndex=0
    $form.Controls.Add($edu)

    Add-FieldLabel "AI Experience:" 165
    $aiExp=New-Object System.Windows.Forms.ComboBox
    $aiExp.Location=New-Object System.Drawing.Point(210,162); $aiExp.Size=New-Object System.Drawing.Size(300,25)
    $aiExp.DropDownStyle="DropDownList"; [void]$aiExp.Items.AddRange(@("None - I never use AI","Beginner - I use AI seldom","Intermediate - I use AI daily","Advanced - My work/study is embedded with AI","Expert - I design AI")); $aiExp.SelectedIndex=0
    $form.Controls.Add($aiExp)

    $AssignedCondition = @("AIOnly","AI+HITL") | Get-Random

    Add-FieldLabel "Experimental Condition:" 205

    $lblConditionOptions = New-Object System.Windows.Forms.Label
    $lblConditionOptions.Text = "The possible conditions you will be randomly assigned:`r`nâ€¢ AIOnly`r`nâ€¢ AI+HITL"
    $lblConditionOptions.Location = New-Object System.Drawing.Point(210,205)
    $lblConditionOptions.Size = New-Object System.Drawing.Size(300,50)
    $form.Controls.Add($lblConditionOptions)

    Add-FieldLabel "Scenarios:" 255

    $lblScenarios = New-Object System.Windows.Forms.Label
    $lblScenarios.Text = "You will evaluate five scenarios."
    $lblScenarios.Location = New-Object System.Drawing.Point(210,255)
    $lblScenarios.Size = New-Object System.Drawing.Size(350,25)
    $form.Controls.Add($lblScenarios)

    $Global:IsAllScenarios = $true
    $Global:IsMixedScenarios = $false

    $cancel=New-Object System.Windows.Forms.Button
    $cancel.Text="Cancel"; $cancel.Location=New-Object System.Drawing.Point(420,340); $cancel.Size=New-Object System.Drawing.Size(120,35)
    $cancel.Add_Click({$form.Tag="CANCEL";$form.Close()}); $form.Controls.Add($cancel)
    
    $ok=New-Object System.Windows.Forms.Button
    $ok.Text="Start Scenario"; $ok.Location=New-Object System.Drawing.Point(560,340); $ok.Size=New-Object System.Drawing.Size(140,35)
    
    $ok.Add_Click({
        $participantAge = $txtAge.Text.Trim()

        do {
            $participantID = "P-" + [guid]::NewGuid().ToString("N").Substring(0, 12).ToUpper()
            $logPath = Join-Path (Get-Location) "ScenarioResults.csv"
            $existingIDs = @()
            if (Test-Path $logPath) {
                $existingIDs = @(Import-Csv $logPath | Select-Object -ExpandProperty ParticipantID)
            }
        } while ($participantID -in $existingIDs)
        
        if (-not([int32]::TryParse($participantAge, [ref]$null)) -or [int]$participantAge -lt 18 -or [int]$participantAge -gt 99) {
            [Windows.Forms.MessageBox]::Show("Please enter a valid age between 18 and 99.", "Invalid Age"); return
        }

        $form.Tag="OK";$form.Close()
    }); 
    
    $form.Controls.Add($ok)
    $form.AcceptButton=$ok; $form.CancelButton=$cancel
    [void]$form.ShowDialog()
    if($form.Tag -ne "OK"){return "CANCEL"}

    $Global:ParticipantID = $participantID
    $Global:ParticipantAge=$txtAge.Text.Trim()
    $Global:ParticipantPosition=$txtPos.Text.Trim()
    $Global:ParticipantEducation=[string]$edu.SelectedItem
    $Global:ParticipantAIExperience=[string]$aiExp.SelectedItem
    $Global:SelectedCondition = $AssignedCondition
    $Global:SelectedVersion="Combined"
    $Global:IsAllScenarios = $true
    $Global:IsMixedScenarios = $false
    $Global:Score=[PSCustomObject]@{DecisionAccuracy=0;ErrorDetection=0;TotalQuestions=0;Condition=$Global:SelectedCondition}
    return "OK"
}

# ------------------------------------------------------------
#   START PROGRAM (RESTRUCTURED)
# ------------------------------------------------------------

# 1. Run Pre-flight check for write permissions
if (-not (Test-WritePermissions)) {
    Exit
}

# 2. Show console-based consent form
Show-ConsentForm

# 3. Run the GUI to get study parameters
Clear-Host
Write-Host "Loading setup window..."
$setupResult = Select-ScenarioOptions

if ($setupResult -ne "OK") {
    Write-Host "Setup was cancelled. Exiting study." -ForegroundColor Red
    Exit
}

# 4. Run selected scenarios
if ($Global:IsAllScenarios) {
    for ($s = 1; $s -le 5; $s++) {
        if ($Global:ScriptTerminated) { break }
        Start-Scenario -Condition $Global:SelectedCondition -Version "Combined" -Occupation "IT" -ScenarioNumber $s
    }
} elseif ($Global:IsMixedScenarios) {
    $mixedScenarios = 1..5 | Sort-Object { Get-Random }
    foreach ($s in $mixedScenarios) {
        if ($Global:ScriptTerminated) { break }
        Start-Scenario -Condition $Global:SelectedCondition -Version "Combined" -Occupation "IT" -ScenarioNumber $s
    }
}

# 5. Post-Scenario TIAS Survey
if (-not $Global:ScriptTerminated) {
    Clear-Host
    Write-Host "`n============================================================" -ForegroundColor White
    Write-Host "   POST-SIMULATION QUESTIONNAIRE" -ForegroundColor White
    Write-Host "============================================================" -ForegroundColor White
    Write-Host "`nThe Trust in AI questionnaire will now open in a new window." -ForegroundColor Cyan
    Start-Sleep -Seconds 3
    $trustScores = Start-TrustSurvey
}

# 6. Post-Survey Debriefing
if (-not $Global:ScriptTerminated -and $script:TrustSurveyCompleted) {
    Show-Debriefing
}

# 7. Upload results to Google Apps Script Server
if (-not $Global:ScriptTerminated) {
    Write-Banner "TRANSMITTING RESULTS TO SERVER"
    $scenarioFile = Join-Path (Get-Location) "ScenarioResults.csv"
    $trustFile = Join-Path (Get-Location) "TrustSurveyResults_TIAS.csv"

    Send-FileToGoogleWebApp -FilePath $scenarioFile -ServerUrl $Global:GoogleWebAppUrl
    Send-FileToGoogleWebApp -FilePath $trustFile -ServerUrl $Global:GoogleWebAppUrl
}

# 8. Final summary
if (-not $Global:ScriptTerminated) {
    Write-Host "`n============================================================" -ForegroundColor White
    Write-Host "                   STUDY SESSION COMPLETE" -ForegroundColor White
    Write-Host "============================================================" -ForegroundColor White
    Write-Host "`nThank you for your participation." -ForegroundColor Green
} else {
    Write-Host "`nScript was terminated by the user." -ForegroundColor Yellow
}