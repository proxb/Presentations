#----WSUS Configuration

#View the WSUS Configuration
$Config = $wsus.GetConfiguration()

#What can I set?
$Config | Get-Member -Type Property | Where {$_.Definition -match "set;"}

#Save my changes
$Config.Save()

#----WSUS Events

#Viewing WSUS Events
$wsus.GetUpdateEventHistory

#Look at the past 5 days event logs
$5Days = (Get-Date).AddDays(-5)
$wsus.GetUpdateEventHistory($5Days,(Get-Date))

#----WSUS Synchronization History
$wsus.GetSubscription().GetSynchronizationHistory

$wsus.GetSubscription().GetSynchronizationHistory($5Days,(Get-Date))

#Start a synchronization
$wsus.GetSubscription().StartSynchronization()

#View progress of synchronization
$wsus.GetSubscription().GetSynchronizationStatus()
$wsus.GetSubscription().GetSynchronizationProgress()

#----Exploring the Database connection

#View WSUS Database Connection
$wsus.GetDatabaseConfiguration()

#Create connection interface to Database server
$db = $wsus.GetDatabaseConfiguration().CreateConnection()
$db

#Make Connection to Database
$db.connect()
$db #note ConnectionString

#Execute T-SQL command against Database to see available tables
$result = $db.GetDataSet('select * from INFORMATION_SCHEMA.TABLES',[System.Data.CommandType]::Text)
$result

#Result isn't too useful, so we need to do more with it
$result.tables.rows

#Don't forget to close this so another query can be used.
$db.CloseCommand()

#Now lets see some more useful data, like the target computers
$result = $db.GetDataSet('select * from [dbo].[tbComputerTarget]',[System.Data.CommandType]::Text)
$result.tables.rows
$db.CloseCommand() 

#You can event perform update actions against the database,
#in this we can perform some database maintenance using a script
# http://gallery.technet.microsoft.com/scriptcenter/Invoke-WSUSDBMaintenance-af2a3a79
Invoke-WSUSDBMaintenance -UpdateServer DC1 -Port 80 -Verbose