#!/bin/bash

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# 
# version 1.2
# Written by: Tommy Dufault
#
# 06-07-24 : Fixed a bunch of random typos and added instructions.
#
# Permission is granted to use this code in any way you want.
# Credit would be nice, but not obligatory.
# Provided "as is", without warranty of any kind, express or implied.
#
# DESCRIPTION
#
# For Self-Service Usage
#
# Creating a Dock Item in Jamf is annoying
#
# This script add a defined application to the end of a dock, using dockutil and Jamf Pro
# source dockutil https://github.com/kcrawford/dockutil/
# 
# Snippets from Mischa van der Bent and Dan K. Snelson
# 
# REQUIREMENTS
# dockutil Version 3.0.0 or higher installed to /usr/local/bin/; script will install if missing
# Compatible with macOS 11.x and higher
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

####################################################################################################
#
# Instructions
#
####################################################################################################

# Step 1 

# Copy Script in Jamf Scripts

# Parameter 4: Organisation Name

# Parameter 5: Logs Path (keep empty or define here)

# Parameter 6: Application Path

# Recommended: Prefix the script name with "Z_" if multiple scripts are set to execute "after" within the same policy, ensuring this script runs last in sequence.


# Step 2

# Create New Policy

# Add Previously Added Script

# Fill Parameter

# Set to run after other actions

# ENABLE SELF-SERVICE

####################################################################################################
#
# Variables
#
####################################################################################################

scriptVersion="1.0"
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin/
# Define the organization name here, either here on in a Jamf Script Function in attribute 45
organisationName="${4:-"acme"}"
# Define the script logs path, either here on in a Jamf Script Function in attribute #5
scriptLog="${5:-"/var/tmp/com.${organisationName}.dockutil.log"}"
dockutilCommandFile=$( mktemp /var/tmp/dialogCommandFile.XXX )
currentUser=$(echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }')
dayOfTheWeek=$( date +'%A' )


# Define the application path, either here on in a Jamf Script Function in Parameter #6

appPath="$6"

####################################################################################################
#
# Pre-flight Checks
#
####################################################################################################

# Confirm script is running as root
if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run as root; exiting."
    exit 1
fi

####################################################################################################
#
# Functions
#
####################################################################################################

# Client-side Script Logging
function updateScriptLog() {
    echo -e "$( date +%Y-%m-%d\ %H:%M:%S ) - ${1}" | tee -a "${scriptLog}"
}

# Create log file if it doesn't exist
if [[ ! -f "${scriptLog}" ]]; then
    touch "${scriptLog}"
    updateScriptLog "*** Created log file via script ***"
fi

# Check for / install dockutil
function dockutilCheck() {
    # Check if dockutil is installed
    if [[ -x "/usr/local/bin/dockutil" ]]; then
        dockutil="/usr/local/bin/dockutil"
        updateScriptLog "dockutil version $(dockutil --version) found; proceeding..."
    else
        updateScriptLog "dockutil not found. Installing..."
        # Get the URL of the latest PKG from the dockutil GitHub repo
        dockutilURL=$(curl --silent --fail "https://api.github.com/repos/kcrawford/dockutil/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
        # Expected Team ID of the downloaded PKG
        expectedDockutilTeamID="Z5J8CJBUWC"
        
        # Create temporary working directory
        workDirectory=$( /usr/bin/basename "$0" )
        tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )
        # Download the installer package
        /usr/bin/curl --location --silent "$dockutilURL" -o "$tempDirectory/Dockutil.pkg"
        # Verify the download
        teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dockutil.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')
        # Install the package if Team ID validates
        if [[ "$expectedDockutilTeamID" == "$teamID" ]]; then
            /usr/sbin/installer -pkg "$tempDirectory/Dockutil.pkg" -target /
            sleep 2
            updateScriptLog "dockutil version $(dockutil --version) installed; proceeding..."
        else
            echo "dockutil Install Failed"
            exit 0
        fi
        # Remove the temporary working directory when done
        /bin/rm -Rf "$tempDirectory"
    fi
}

dockutilCheck

# Run the dockutil command as the current user in a subshell
/usr/bin/su - "$currentUser" -c "bash -c '/usr/local/bin/dockutil -a \"$appPath\" 2>/dev/null'"

# Log the completion of the script
updateScriptLog "dockutil command executed as $currentUser"

exit 0
