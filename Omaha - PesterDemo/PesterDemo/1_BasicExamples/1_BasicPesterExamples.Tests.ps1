##Creating a Test Environment
#Create a directory to store files
New-Item TestCase -ItemType Directory
#Create the script as well as the .Tests file
New-Fixture -Path TestCase -Name TestCase 