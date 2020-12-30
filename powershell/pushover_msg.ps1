#requires -Version 3
function Send-Pushover 
{
    <#
            .SYNOPSIS
            Sends a push notification alert to a specific user using PushOver.net
 
            .DESCRIPTION
            Use this function to send push notification alerts using the PushOver.net API.
 
            .EXAMPLE
            Send-PushOver -APIToken 'KzGDORePK8gMaC0QOYAMyEEuzJnyUi' -User 'pQiRzpo4DXghDmr9QzzfQu27cmVRsG' -Message "Test Alert"
            Sends message "test alert" to user with token specified
 
            .EXAMPLE
            Send-PushOver -APIToken 'KzGDORePK8gMaC0QOYAMyEEuzJnyUi' -User 'pQiRzpo4DXghDmr9QzzfQu27cmVRsG' -Message "Test Alert" -DeviceID 'droid2'
            Sends a message "Test Alert" to the user and the specified device
 
            .NOTES
            AUTHOR: Kieran Jacobsen <code@poshsecurity.com>
            LASTEDIT: 2016/02/21
 
            .LINK
            http://poshsecurity.com/
 
            .LINK
            http://pushover.net/
 
            .LINK
            https://github.com/PoshSecurity/PowerShellPushOver
 
    #>
    [CMDLetBinding()]
    param (
        # Your application's API token.
        [Parameter(Mandatory = $true, 
                    Position = 0)]
        [ValidateLength(30,30)]
        [String] 
        $Token,

        # The user key (not e-mail address) of your user (or you), viewable when logged into our dashboard (often referred to as USER_KEY).
        [Parameter(Mandatory = $true, 
            ParameterSetName = 'User',
                    Position = 1)]
        [ValidateLength(30,30)]
        [String] 
        $User,

        # The group key (not e-mail address) of your user (or you).
        [Parameter(Mandatory = $true, 
            ParameterSetName = 'Group',
                    Position = 1)]
        [ValidateLength(30,30)]
        [String] 
        $Group,

        # Your message. Cannot be longer than 1024 characters. Can be HTML if -SendAsHTML is specified. Due to limitations with notifications on mobile platforms, HTML tags are stripped out when displaying your message as a notification (leaving just the plain text of your message). Once the device client is opened and your message has been downloaded from our server, we display the full HTML version. HTML tags currently supported: <b>word</b> - display word in bold, <i>word</i> - display word in italics, <u>word</u> - display word underlined, <font color="blue">word</font> - display word in blue text (most colors and hex codes permitted), <a href="http://example.com/">word</a> - display word as a tappable link to http://example.com/ .
        [Parameter(Mandatory = $true, 
                    Position = 2)]
        [ValidateLength(0,1024)]
        [String]
        $Message,

        # Your message's title, otherwise your app's name is used. Cannot be longer than 250 Characters.
        [Parameter(Mandatory = $false, 
                    Position = 3)]
        [ValidateLength(0,250)]
        [String]
        $MessageTitle,

        # Your user's device name to send the message directly to that device, rather than all of the user's devices (multiple devices may be separated by a comma).
        [Parameter(Mandatory = $false, 
                    Position = 4)]
        [ValidateLength(0,25)]
        [String]
        $DeviceID,

        # Priority of the message, either lowest, low, normal, high or emergency.
        [Parameter(Mandatory = $false, 
                    Position = 5)]
        [ValidateSet('Lowest', 'Low', 'Normal', 'High', 'Emergency')]
        [String]
        $priority = 'Normal',

        # A supplementary URL to show with your message.
        [Parameter(Mandatory = $false, 
                    Position = 6)]
        [ValidateLength(0,512)]
        [String]
        $URL,

        # A title for your supplementary URL, otherwise just the URL is shown. (not used unless MessageURL specified).
        [Parameter(Mandatory = $false, 
                    Position = 7)]
        [ValidateLength(0,100)]
        [String]
        $URLTitle,

        # Send the message as HTML (if not specified, message sent as plain text). See comment under Message parameter for valid HTML options.
        [Parameter(Mandatory = $false, 
                    Position = 8)]
        [Switch]
        $SendAsHTML,

        # Time for message, if not specified, this is left to the PushOver servers (current time).
        [Parameter(Mandatory = $false, 
                    Position = 9)]
        [ValidateNotNullOrEmpty()]
        [DateTime] $DateTime,

        # The name of one of the sounds supported by device clients to override the user's default sound choice.
        [Parameter(Mandatory = $false, 
                    Position = 10)]
        [ValidateSet('pushover', 'bike', 'bugle', 'cashregister', 'classical', 'cosmic', 'falling', 'gamelan', 'incoming', 'intermission', 'magic', 'mechanical', 'pianobar', 'siren', 'spacealarm', 'tugboat', 'alien', 'climb', 'persistent', 'echo', 'updown', 'none')]
        [string]
        $sound,

        # For Emergengcy Priority ONLY. Specifies how often (in seconds) the Pushover servers will send the same notification to the user. In a situation where your user might be in a noisy environment or sleeping, retrying the notification (with sound and vibration) will help get his or her attention. This parameter must have a value of at least 30 seconds between retries. Default is 60 seconds.
        [Parameter(Mandatory = $false, 
                    Position = 11)]
        [ValidateRange(30, 86400)]
        [int]
        $ConfirmationRetry = 60,

        # For Emergengcy Priority ONLY. Specifies how many seconds your notification will continue to be retried for (every retry seconds). If the notification has not been acknowledged in expire seconds, it will be marked as expired and will stop being sent to the user. Note that the notification is still shown to the user after it is expired, but it will not prompt the user for acknowledgement. This parameter must have a maximum value of at most 86400 seconds (24 hours). Default is 24 hours.
        [Parameter(Mandatory = $false, 
                    Position = 12)]
        [ValidateRange(0, 86400)]
        [int]
        $Confirmationexpire = 3600,
        
        #For Emergengcy Priority ONLY. Parameter may be supplied with a publicly-accessible URL that our servers will send a request to when the user has acknowledged your notification. Default is not sent.
        [Parameter(Mandatory = $false, 
                    Position = 13)]
        [ValidateNotNullOrEmpty()]
        [string] $ConfirmationCallback
    )

    # Add the default/mandatory parameters
    $Parameters = @{}
    $Parameters.Add('token', $Token)
    if ($PSBoundParameters.ContainsKey('User')) 
    {
        $Parameters.Add('user', $User)
    }
    else
    {
        $Parameters.Add('user', $Group)
    }
    $Parameters.Add('message', $Message)
    
    # If Message title, device id, url or URL title, sound is specified, add those parameters in
    if ($PSBoundParameters.ContainsKey('MessageTitle')) 
    {
        $Parameters.Add('title', $MessageTitle)
    }

    if ($PSBoundParameters.ContainsKey('DeviceID')) 
    {
        $Parameters.Add('device', $DeviceID)
    }
    
    if ($PSBoundParameters.ContainsKey('URL')) 
    {
        $Parameters.Add('url', $URL)
    }

    if ($PSBoundParameters.ContainsKey('URLTitle'))
    {
        $Parameters.Add('url_title', $URLTitle)
    }

    if ($PSBoundParameters.ContainsKey('Sound')) 
    {
        $Parameters.Add('sound', $sound)
    }

    # Determine the correct priority value to send, if the priority is Emergency, add the confirmation retry and expiry, and optional call back.
    $PriorityValue = 0
    switch ($priority)
    {
        'Lowest' 
        {
            $PriorityValue = -2
        }
        'Low' 
        {
            $PriorityValue = -1
        }
        'Normal' 
        {
            $PriorityValue = 0
        }
        'High' 
        {
            $PriorityValue = 1
        }
        'Emergency' 
        {
            $PriorityValue = 2
            $Parameters.Add('retry', $ConfirmationRetry)
            $Parameters.Add('expire', $Confirmationexpire)
            if ($PSBoundParameters.ContainsKey('ConfirmationCallback'))
            {
                $Parameters.Add('callback', $ConfirmationCallback)
            }
        }
    }
    $Parameters.Add('priority', $PriorityValue)
    
    # If specific DateTime required, convert to UNIX format
    if ($PSBoundParameters.ContainsKey('DateTime')) 
    {
        $DateTimeString = [System.Math]::Truncate((Get-Date -Date ($DateTime.ToUniversalTime()) -UFormat %s ))
        $Parameters.Add('timestamp', $DateTimeString)
    }

    # If we are sending a HTML message, handle that accordingly
    if ($SendAsHTML)
    {
        $Parameters.Add('html', 1)
    }   

    #send the request to the pushover server, capture the response, throw any error
    try 
    {
        Write-Verbose -Message "Sending message: $Message"
        $Response = Invoke-RestMethod -Uri 'https://api.pushover.net/1/messages.json' -Body $Parameters -ContentType 'application/x-www-form-urlencoded' -Method POST
    }
    catch 
    {
        $MyError = $_
        if ($null -ne $MyError.Exception.Response)
        { 
            # Recieved an error from the API, lets get it out
            $result = $MyError.Exception.Response.GetResponseStream()
            $reader = New-Object -TypeName System.IO.StreamReader -ArgumentList ($result)
            $responseBody = $reader.ReadToEnd()
            $JSONResponse = $responseBody | ConvertFrom-Json
                
            # Throw the error message from API to caller
            Throw ($JSONResponse.Errors)
        }
        else
        {
            # No response from API, throw the error as is
            Throw $MyError
        }
    }
    
    # Add a boolean value to more easily test if the process was successful
    Add-Member -InputObject $Response -MemberType NoteProperty -Name 'success' -Value ($Response.status -eq 1)

    if ($null -ne (Get-Member -InputObject $Response -Name 'info'))
    {
        Write-Warning -Message ('Pushover.Net API Info - {0}' -f $Response.info)
    }
    
    # Return the reponse object to the caller, they can decide if the want process it
    $Response
}