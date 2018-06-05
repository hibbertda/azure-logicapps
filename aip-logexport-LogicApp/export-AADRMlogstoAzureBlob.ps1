# Import AADRM PowerShell Module
Write-Output "Loading AADRM Module"
import-module 'D:\Home\site\wwwroot\PSLogCollector\Modules\AADRM\2.13.1.0\AADRM.psd1'

# Make this better. but its ok for now (creds)
$username = "aiploguser@thehibbs.net"
$secPasswd = ConvertTo-SecureString "xx" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($username, $secPasswd)
$AAD_TenantId = '61b05785-0568-4f32-8ea2-4c9c5f27bd7c'

# Directory setup
$workingDirectory = 'D:\Home\site\wwwroot\PSLogCollector'
$logTempDirectory = $workingDirectory+"\AIP_logs"

if (test-path $logTempDirectory){
    write-debug -Message "Removing old temp directory"
    remove-item -Path $logTempDirectory -confirm:$false -force -Recurse
}

# Logs from
$logsFrom = (get-date 00:00:00).AddDays(-1)

# Create temp directory
New-Item -Path $logTempDirectory -ItemType Directory -force | out-null

# Connect to AADRM Service
Connect-AadrmService `
    -Credential $cred `
    -TenantId $AAD_TenantId

# Export AARM logs
Get-AadrmUserLog -Path $logTempDirectory -FromDate $logsFrom

# Consolidate Log files
$captureDate = Get-Date -format MM.dd.yy-ss
$logParse = $workingDirectory+"\AIP_Logs_"+$captureDate+".csv"
$outPutlog = $workingDirectory+"\input.csv"

# Run log parser to convert log files (w3c -> csv)
& 'D:\Home\site\wwwroot\PSLogCollector\Log Parser 2.2\LogParser.exe' –i:w3c –o:csv `
    "SELECT * INTO $LogParse FROM $logTempDirectory\*.log"

$temp_logs = import-csv -Path $logParse
$temp_logs | Export-Csv -NoTypeInformation -Path $outPutlog

# Copy exported log data to Azure blob storage container
$storageAccount_ContainerName = "aip-logs-unprocessed"
$storageAccount_ConnectionString = (Get-ChildItem Env:CUSTOMCONNSTR_aiplogsStorage).value
$storageAccount_Context = New-AzureStorageContext -ConnectionString $storageAccount_ConnectionString

# upload content to storage account
Set-AzureStorageBlobContent `
    -File $outPutlog `
    -Context $storageAccount_Context `
    -Container $storageAccount_ContainerName

# Cleanup
Remove-Item -Path $logTempDirectory -confirm:$false -force -Recurse
Remove-Item -Path $logParse -confirm:$false