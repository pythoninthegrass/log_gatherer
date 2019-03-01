#!/bin/bash
#######################################################################################
### v1.2 Written by Matt Taylor 22/02/19 											###
### This script automates the compression and upload of specified log files         ###
### to a device's inventory record in Jamf Pro as an attachment for troubleshooting ###
### purposes.  This script is designed to be run as a Self Service Policy.          ###
### 																				###
### Recommended to use a Jamf Pro user account with only the following permissions: ###
### Computers: Create, Read															###
### 																				###
### We *strongly* recommend removing all uploaded attachments immediately afterwards###
###																					###
#######################################################################################

## Declare variables ##
# Create an authentication token for the API Jamf Pro account.
token=$(printf "apiUsername:apiPassword" | iconv -t ISO-8859-1 | base64 -i -)

# Specify the Jamf Pro URL.
jssURL="https://organisation.jamfcloud.com"

# Find the device serial number.
serialNumber=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')

# Specify the log files being requested.
jamfLog="/var/log/jamf.log"
installLog="/var/log/install.log"
systemLog="/var/log/system.log"

# Specify a save location and time stamp.
timeStamp=$(date +%Y%m%d_%H%M)
logArchive="/var/tmp/${timeStamp}_logs.zip"

# Specify a file size limit in bytes that we want to upload.  The default is ~5mb.
byteSize="5000"

###################################
### DO NOT EDIT BELOW THIS LINE ###
###################################
## Compress the log files we're uploading and name it with a timestamp.
/usr/bin/zip -r $logArchive $jamfLog $installLog $systemLog

### Check the file size of the archive prior to upload.  If it's larger than 15mb, fail out and advise the user to contact IT.
fileSize=$(/usr/bin/du -k $logArchive | cut -f1)
if [[ $fileSize -gt $byteSize ]]; then
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -description "The log files are too large to upload, please contact IT for further assistance." -icon /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns -button1 "Close" &
/bin/echo "The log archive was larger than the specified limit, as such the upload has been aborted."
exit 1
fi

## Pull the Jamf Pro computer ID using the serial number.
id=$(/usr/bin/curl -H "Accept: text/xml" -H "authorization: Basic $token" -S $jssURL/JSSResource/computers/serialnumber/$serialNumber -X GET | xpath '/computer/general/id/text()')

## Upload the log files to the device inventory record.
http_code=$(/usr/bin/curl -H "authorization: Basic $token" -S $jssURL/JSSResource/fileuploads/computers/id/$id -X POST -F name=@$logArchive)

## Report on the status code of the curl and throw a jamfHelper window with information.
if [[ "$http_code" -le 200 ]]; then
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -description "Your logs have been successfully uploaded, IT will contact you shortly to assist further." -icon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FinderIcon.icns" -button1 "Close" &
else
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -description "There was a problem completing the upload, IT will contact you shortly to assist further." -icon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns" -button1 "Close" &
exit 1
fi

## Cleanup the log archive created.
if [[ -f $logArchive ]]; then
/bin/rm $logArchive
fi

## Exit gracefully.
exit 0
