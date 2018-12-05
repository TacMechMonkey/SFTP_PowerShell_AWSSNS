# SFTP_PowerShell_AWSSNS
A simple script to transfer files over S/FTP/S, append a datetime stamp to orginal file, move it to a different folder with AWS SNS for notifications.

 Reference: Using WinSCP .NET Assembly from PowerShell - https://winscp.net/eng/docs/library_powershell
 
What it does:
   1. Creates a S/FTP/S connection
   2. Sends an AWS SNS notification if the connection fails with a reason ie Authentication Failed
   3. Copies a file(s) across
   4. Appends a datetime stamp to the original file(s) name(s)
   5. Moves the file into a different directory
   6. Sends an AWS SNS notification if the job completes

What it doesn't do:  
Include every file name in the body of the email, even though it will transfer and move every file in the nominated folder.  
If you need that, create an array and append all $transfer.FileNames  

If you need SFTP, add:   
> "Protocol = [WinSCP.Protocol]::Sftp" 

> "SshHostKeyFingerprint = "ssh-rsa 2048 xx:xx......."   

to $SessionOptions and delete $Port  
