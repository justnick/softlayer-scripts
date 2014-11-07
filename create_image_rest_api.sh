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
#
# 3. This script doesn't check whether image with the same name already exists while trying to delete or create an image.
#
################################################################################
# All REST URLs follow the format:
# https://<username>:<apiKey>@api.[service.]softlayer.com/rest/v3/<serviceName>/[initializationParameter].<returnDatatype>
# To read more about the Softlayer APIs - http://sldn.softlayer.com
# To load the prviously created image with REST API or create a new server from it you'll need to follow this guideance 
# http://sldn.softlayer.com/reference/services/SoftLayer_Virtual_Guest/createObject

# General variables
ADMIN="adminmail@example.com"
# log file location
LOGFILE="/var/log/softlayer_images.log"
if [ ! -e $LOGFILE ]; then
	echo "Log file not found. We will try create one..."
	touch ${LOGFILE}
fi

# Username and password for Softlayer API
API="SLAPI_VARS"
if [ -f $API ]; then
	echo "Loading user and api key"
	source ${API}
else
	STATUS="$(date): We can't proceed further without api username and key"
	RETVAL=1;
	echo "${STATUS}" >> ${LOGFILE}
	exit $RETVAL
fi

# we will get the CCI ID as a command-line argument for this script
usage() {
echo "create_image_rest_api.sh - Create Image Template with SL REST API"
echo ""
echo "Please provide your Virtal Server /CCI ID"
echo "Add your SL username and API key in the SLAPI_VARS file"
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
# get the date two weeks ago as MM-DD-YYYY
TWOWEEK=$(date +%m-%d-%Y --date='-2 week')

# Softlayer's API createArchiveTransaction is CCI agnostic, therefore we need to set a meaningful name to our image template
# http://sldn.softlayer.com/reference/services/SoftLayer_Virtual_Guest/createArchiveTransaction
# let's get the FQDN first
GETFQDN="$(curl -s -g -u ${SLNAME}:${SLKEY} ${SLAPI}/SoftLayer_Virtual_Guest/${VSID}/getObject.json?objectMask=fullyQualifiedDomainName | cut -d'"' -f4)"

if [ -z "$GETFQDN" ]; then
	STATUS="$(date): There was a problem with getting the VSHOSTNAME from SL API for VSID: ${VSID}"
	RETVAL=1;
	echo "${STATUS}" >> ${LOGFILE}
	exit $RETVAL
# we expect a valid FQDN, if the output contains spaces, we received something else (probably an output error) 
elif [[ "$GETFQDN" = *[[:space:]]* ]]; then
	STATUS="$(date): The supplied string: ${GETFQDN} is not a valid FQDN"
	RETVAL=1;
	echo "${STATUS}" >> ${LOGFILE}
	exit $RETVAL
else    
	VSHOSTNAME=$GETFQDN
	IMG=$(echo image-${VSHOSTNAME}-${TODAY})
# Our retention scheme is two weeks, therefore we can purge images older than two weeks. 
# Since we have consistent image names based on <image>-<fqdn>-<date> we can delete older images based on their name
	DELIMG=$(echo image-${VSHOSTNAME}-${TWOWEEK})
fi

# Deleting the old image
# http://sldn.softlayer.com/reference/datatypes/SoftLayer_Virtual_Guest_Block_Device_Template_Group
DELIMGID="$(curl -s -g -u  ${SLNAME}:${SLKEY} ${SLAPI}/SoftLayer_Account/PrivateBlockDeviceTemplateGroups.json?objectMask='mask[name,id,note]' | json_reformat | awk '/'${DELIMG}'/ {print id }; { id=$0 }' | tr -cd [:digit:])"

if [ -z "$DELIMGID" ]; then
	STATUS="$(date): There was a problem with identifying the DELIMGID which should be deleted from SL API for VSID: ${VSID}"
	echo "${STATUS}" >> ${LOGFILE}
else
# let's proceed and delete the image in question
	curl -s -g -u ${SLNAME}:${SLKEY} ${SLAPI}/SoftLayer_Virtual_Guest_Block_Device_Template_Group/${DELIMGID}/deleteObject
fi

# get block devices and limit the output with offset=1 http://sldn.softlayer.com/article/rest#Using_Result_Limits
# use the getBlockDevices output, and get the id of the 0 device, which is our primary disk. 3 = CD-RW, 1 = swap device
# http://sldn.softlayer.com/reference/services/SoftLayer_Virtual_Guest/getBlockDevices
GETBLOCKDEVICES="$(curl -s -g -u ${SLNAME}:${SLKEY} ${SLAPI}/SoftLayer_Virtual_Guest/${VSID}/getBlockDevices.json?resultLimit=0,1 | json_reformat | grep "[^u]id" | cut -d: -f2 |  tr -cd [:digit:] )"

if [ -z "$GETBLOCKDEVICES" ]; then
	STATUS="$(date): There was a problem with getting the GETBLOCKDEVICES from SL API for VSID: ${VSID}"
	RETVAL=1;
	echo "${STATUS}" >> ${LOGFILE}
	exit $RETVAL
else	
	ID=$GETBLOCKDEVICES	
fi

# creating the actual image
# { "parameters":["test image date", [{"id": 1234567}], "This is a Test Image"]} - https://gist.github.com/underscorephil/6123195
curl -s -g -u $SLNAME:$SLKEY -H "content-type: application/json" -X POST -d  '{ "parameters":["'${IMG}'", [{"id": '${ID}'}], "Standard Image Template created on: '${TODAY}'"]}' ${SLAPI}/SoftLayer_Virtual_Guest/${VSID}/createArchiveTransaction.json

# send email if the script fails and image is not created
mail_warn ()
{
mail -s "Image validation failed" ${ADMIN} <<MAIL_BODY
Image validation of ${IMGID} for VSID: ${VSID} failed on $(date). Please check the log file!
MAIL_BODY
}

# In order to verify image creation and readiness we will need to find the Image ID by using the Image Name set by us on previous step
# but before we do that, we need to wait a bit for the actual image creation which usually takes around 5 minutes
sleep 5m

IMGID="$(curl -s -g -u  ${SLNAME}:${SLKEY} ${SLAPI}/SoftLayer_Account/PrivateBlockDeviceTemplateGroups.json?objectMask='mask[name,id,note]' | json_reformat | awk '/'${IMG}'/ {print id }; { id=$0 }' | tr -cd [:digit:])"

if [ -z "$IMGID" ]; then
	STATUS="$(date): There was a problem with getting the ${IMGID} from SL API for VSID: ${VSID}"
	RETVAL=1;
	echo "${STATUS}" >> ${LOGFILE}
	exit $RETVAL
else
# let's proceed and verify the image
# http://sldn.softlayer.com/reference/services/SoftLayer_Virtual_Guest/validateImageTemplate
VALIDATE="$(curl -s -g -u  ${SLNAME}:${SLKEY} ${SLAPI}/SoftLayer_Virtual_Guest/${VSID}/validateImageTemplate/${IMGID}.json)"
	if [[ -n "$VALIDATE" && "$VALIDATE" = "true" ]]; then
		STATUS="$(date): Congrats. ${IMGID} for VSID: ${VSID} successfully created"
		RETVAL=0;
		echo "${STATUS}" >> ${LOGFILE}
		exit $RETVAL
	else
		STATUS="$(date): There was a problem with validating the creation of ${IMGID} for VSID: ${VSID}"
		RETVAL=1;
		echo "${STATUS}" >> ${LOGFILE}
		mail_warn
		exit $RETVAL
	fi
fi
