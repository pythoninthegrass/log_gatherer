#!/usr/bin/env bash

#######################################################################################
### OG SOURCE - edited by /u/pythoninthegrass Jan 2020
#######################################################################################
###
### v1.3 Written by Matt Taylor 19/03/19
### This script automates the compression and upload of specified log files
### to a device's inventory record in Jamf Pro as an attachment for troubleshooting
### purposes.  This script is designed to be run as a Self Service Policy.
###
### Recommended to use a Jamf Pro user account with only the following permissions:
### Computers: Create, Read
###
### Specify the Jamf Pro user account username as Parameter 4 and the password
### as Parameter 5 inside the Script payload of the Policy.  More information here:
### https://www.jamf.com/jamf-nation/articles/461/secure-scripts
###
### We *strongly* recommend removing all uploaded attachments from inventory records
### immediately afterwards to prevent unnecessary database size increase.
###
#######################################################################################

# activate verbose standard output (stdout)
set -v
# activate debugging (execution shown)
set -x

# Current user
logged_in_user=$(logname) # posix alternative to /dev/console

# Working directory
# script_dir=$(cd "$(dirname "$0")" && pwd)

# Set $IFS to eliminate whitespace in pathnames
IFS="$(printf '\n\t')"

#Check if a parameter was set for parameter 4 and, if so, assign it to "api_username"
if [[ "$4" != "" ]] && [[ "$api_username" == "" ]]; then
    api_username=$4
fi

#Check if a parameter was set for parameter 5 and, if so, assign it to "api_password"
if [[ "$5" != "" ]] && [[ "$api_password" == "" ]]; then
    api_password=$5
fi

# Create an authentication token for the API Jamf Pro account.
token=$(printf "$api_username:$api_password" | iconv -t ISO-8859-1 | base64 -i -)

# Pull the Jamf Pro URL from the management framework.
jss_url=$(defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url)

# Find the device serial number.
serial_number=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')

# Specify the log files being requested.
jamf_log="/var/log/jamf.log"
install_log="/var/log/install.log"
sys_log="/var/log/system.log"
ss_log="/Users/$logged_in_user/Library/Logs/JAMF/selfservice.log"

# Specify a save location and time stamp.
time_stamp=$(date +%Y%m%d_%H%M)
log_archive="/var/tmp/${time_stamp}_logs.zip"

# Specify a file size limit in bytes that we want to upload.  The default is ~5mb.
byte_size="5000"

## Compress the log files we're uploading and name it with a timestamp.
zip -r $log_archive $jamf_log $install_log $sys_log $ss_log

### Check the file size of the archive prior to upload.  If it's larger than 15mb, fail out and advise the user to contact IT.
file_size=$(du -k $log_archive | cut -f1)
if [[ $file_size -gt $byte_size ]]; then
    /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -description "The log files are too large to upload, please contact IT for further assistance." -icon /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns -button1 "Close" &
    echo "The log archive was larger than the specified limit, as such the upload has been aborted."
    exit 1
fi

## Pull the Jamf Pro computer ID using the serial number.
id=$(curl -H "Accept: text/xml" -H "authorization: Basic $token" -S "$jss_url"JSSResource/computers/serialnumber/$serial_number -X GET | xpath '/computer/general/id/text()')

## Upload the log files to the device inventory record.
http_code=$(/usr/bin/curl -H "authorization: Basic $token" -S "$jss_url"JSSResource/fileuploads/computers/id/$id -X POST -F name=@$log_archive)

## Report on the status code of the curl and throw a jamfHelper window with information.
if [[ "$http_code" -le 200 ]]; then
    /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -description "Your logs have been successfully uploaded, IT will contact you shortly to assist further." -icon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FinderIcon.icns" -button1 "Close" &
else
    /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -description "There was a problem completing the upload, IT will contact you shortly to assist further." -icon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns" -button1 "Close" &
    exit 1
fi

## Cleanup the log archive created.
if [[ -f $log_archive ]]; then
    rm -rf $log_archive
fi

# deactivate verbose and debugging stdout
set +v
set +x

unset IFS

## Exit gracefully.
exit 0
