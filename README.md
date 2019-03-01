# loguploader

This script automates the compression and upload of specified log files to a device's inventory record in Jamf Pro as an attachment for troubleshooting
purposes.  This script is designed to be run as a Self Service Policy.

Recommended to use a Jamf Pro user account with only the following permissions:
- Computers: Create, Read

I strongly recommend removing all uploaded attachments immediately afterwards to prevent unwanted database size increase.
