#!/bin/sh
################################################################################
#
# Author: Nickolay Bunev <nick@bunev.in>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################
#
# Purpose: The purpose of this script is to create an image template for the VS/CCI ID in question in your Softlayer account once a week.
#
################################################################################
# Disclaimer: 
# 1. The author does not take responsibility for any damage you might do to your Softlayer account, your CCIs, currently available images and templates, etc
# 2. Softlayer may apply additional charges to your account for the images that you'll create
# 3. This script doesn't check whether image with the same name already exists while trying to delete or create an image.
#

# General Variables
ADMIN="adminmail@example.com"

# check for sl availability
SL=$(which sl)

if [ ! -x $SL ]; then
	STATUS="sl client is missing. You should install it, before running this script"
	RETVAL=1;
        echo "${STATUS}"
fi

# log file location
LOGFILE="/var/log/softlayer_images.log"
if [ ! -e $LOGFILE ]; then
	STATUS="Log file not found. We will try create one..."
        touch ${LOGFILE}
	echo "${STATUS}"
fi

# we will get the CCI ID as a command-line argument for this script
usage() {
echo "create_image_sl_py.sh - Create Image Template by using SL Python API client"
echo ""
echo "Please provide your Virtal Server /CCI ID"
echo "You can see the ID by running 'sl vs list' or in the Device section on http://control.softlayer.com"
echo "Usage: ./create_image_rest_api.sh <123456>" 
}

if [ -z "$1" ]; then
        STATUS="$(date): No argument given: We need CCI ID"
        RETVAL=1;
        echo "${STATUS}" >> ${LOGFILE}
        usage
        exit $RETVAL
elif [[ "$1" != *[[:digit:]]* ]]; then
        STATUS="$(date): Incorrect argument: $1 The VS/CCI ID should be a number"
        RETVAL=1;
        echo "${STATUS}" >> ${LOGFILE}
        usage
        exit $RETVAL
else
        VSID="$1"
fi

# today's date as MM-DD-YYYY // we'll use it later for our naming
TODAY=$(date +%m-%d-%Y)
# date two weeks ago
TWOWEEK=$(date +%m-%d-%Y --date='-2 week')

# get the VS hostname from SL output. Since we need the hostname later, we will exit if we can't get it.
GETFQDN=$(${SL} vs detail ${VSID} | grep hostname | tr -s ' ' | cut -d ' ' -f2)

if [ -z "$GETFQDN" ]; then
        STATUS="$(date): There was a problem with identifying the VSHOSTTNAME for VSID: ${VSID}"
	RETVAL=1;
        echo "${STATUS}" >> ${LOGFILE}
	exit $RETVAL
else
	VSHOSTNAME=$GETFQDN
	IMGNAME=$(echo image-${VSHOSTNAME}-${TODAY})
	DELIMGNAME=$(echo image-${VSHOSTNAME}-${TWOWEEK})	
fi

# Our retention scheme is two weeks, therefore we can purge images older than two weeks. 
# Since we have consistent image names based on <image>-<fqdn>-<date> we can delete older images based on their name
${SL} image delete ${DELIMGNAME}
echo "$(date): Image ${DELIMGNAME} was deleted!" >> ${LOGFILE}

# creating the new image
${SL} vs capture ${VSID} -n ${IMGNAME}

# send email if the script fails and image is not created
mail_warn ()
{
mail -s "Image validation failed" ${ADMIN} <<MAIL_BODY
Image validation of ${IMGNAME} with ID: ${VALIDATE} for VSID: ${VSID} failed on $(date). Please check the log file!
MAIL_BODY
}

# verify the image creation
VALIDATE=$(${SL} image list --private | grep ${IMGNAME} | tr -s ' ' | cut -d ' ' -f1)
if [ -z "$VALIDATE" ]; then
	STATUS="$(date): There was a problem with validating the creation of ${IMGNAME} for VSID: ${VSID}"
	RETVAL=1;
        echo "${STATUS}" >> ${LOGFILE}
	mail_warn
        exit $RETVAL
else
	STATUS="$(date): Congrats. Image with ID: ${VALIDATE} for VSID: ${VSID} was successfully created"
	RETVAL=0;
	echo "${STATUS}" >> ${LOGFILE}
	exit $RETVAL
fi
