# Reference: Using WinSCP .NET Assembly from PowerShell - https://winscp.net/eng/docs/library_powershell
# 
# This is a simple, down and dirty script which does the following:
# 1. Creates a S/FTP/S connection
# 2. Sends an AWS SNS notification if the connection fails with a reason ie Authentication Failed
# 3. Copies a file(s) across
# 4. Appends a datetime stamp to the original file(s) name(s)
# 5. Moves the file into a different directory
# 6. Sends an AWS SNS notification if the job completes
# 
# What it doesn't do: Include every file name in the body of the email, even though it will transfer and move every file   
# in the nominated folder.
# If you need that, create an array and append all $transfer.FileNames
# If you need SFTP, add "Protocol = [WinSCP.Protocol]::Sftp" and   
# "SshHostKeyFingerprint = "ssh-rsa 2048 xx:xx......." to $SessionOptions, and delete "$Port = 21"


Function SFTPTransfer {

    param (
        # Enter your AWS SNS Parameters
        $TopicArn = 'YOU_AWS_SNS_ARN',
	    $Region = 'YOUR_REGION',
	    $Subject = "Warning: FTP Transfer Failed",

        # Enter your WinSCP Parameters        
        $IP = "123.11.22.33",
        $UserName = "SFTP username",
        $Password = "SFTP password",
        $localPath = "\\internal file share\Transfer\*",
        $remotePath = "/",
        $backupPath = "\\internal file share\Transfer_Complete",
        $Port = 21

    )

    #AWS SNS Function
    Function AWSSNS_SendEmail($TopicArn, $Subject, $Message, $Region)
        {
            Publish-SNSMessage -TopicArn $TopicArn -Subject $Subject -Message $Message -Region $Region
        }

    try
    {
        # Load WinSCP .NET assembly
        Add-Type -Path "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"

        # Set up session options.
        $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
            Protocol = [WinSCP.Protocol]::Ftp
            HostName = $IP
            PortNumber = $Port
            UserName = $UserName
            Password = $Password
        }
 
        $session = New-Object WinSCP.Session
 
        try
        {
            # Connect
            $session.Open($sessionOptions)
 
            # Upload files, collect results
            $transferResult = $session.PutFiles($localPath, $remotePath)
 
            # Iterate over every transfer
            foreach ($transfer in $transferResult.Transfers)
            {
                # Success or error?
                if ($transfer.Error -eq $Null)
                {
                    # If upload succeeded
                    Write-Host "Upload of $($transfer.FileName) succeeded, moving to backup"
                    # Rename file in current path
                    Get-ChildItem $localPath | % {rename-item –path $_.Fullname –Newname ($_.basename + (get-date -format ' dd-MM-yy_hh-mm-ss') + $_.extension)}
                    # Move the item to the backup path
                    Move-Item $localPath $backupPath
                    if ($move.Error -eq $null)
                    {
                        # Send AWS SNS Notification
                        Write-Host "SNS should be sent" 
                        $message = ("Upload of $($transfer.FileName) complete. $_" | ConvertTo-Json) -replace '["{}]',''
                        AWSSNS_SendEmail -TopicArn $TopicArn -Subject "SFTP Tranfer Complete" -Region $Region -Message $message
                        exit 1
                    }
                }
                else
                {
                    Write-Host "Upload of $($transfer.FileName) failed: $($transfer.Error.Message)"
                }
            }
        }
        finally
        {
            # Disconnect, clean up
            $session.Dispose()
        }
 
        exit 0
    }
    catch
    {
        # Send AWS SNS Notification
        $message = ("Warning: Please notify your SysAdmin. Your upload failed. $_" | ConvertTo-Json) -replace '[\\"{}]',''
        AWSSNS_SendEmail -TopicArn $TopicArn -Subject $Subject -Region $Region -Message $message
        exit 1
    }
}

SFTPTransfer
