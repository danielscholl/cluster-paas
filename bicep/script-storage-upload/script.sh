#!/bin/bash
set -e

echo "Waiting on Identity RBAC replication (${initialDelay})"
sleep ${initialDelay}

# Installing required packages
apk add --no-cache curl zip

# Derive the filename from the URL
url_basename=$(basename ${URL})
echo "Derived filename from URL: ${url_basename}"

# Download the file using curl
echo "Downloading file from ${URL} to ${url_basename}"
curl -so ${url_basename} ${URL}

# Check if the URL indicates a tar.gz file
if [[ ${URL} == *.tar.gz ]]; then
    echo "URL indicates a tar.gz archive. Extracting contents..."
    
    # Create a directory for extracted files
    mkdir -p extracted_files
    
    # Extract the tar.gz file
    tar -xzf ${url_basename} --strip-components=1 -C extracted_files
    
    if [[ ${compress} == "True" ]]; then
        echo "Creating zip of contents of ${FILE} and uploading it compressed up to file share ${SHARE}"
        # Remove the original downloaded tar file
        rm ${url_basename}
        # Create a new zip file with the desired name
        zip_filename="${url_basename%.tar.gz}.zip"

        # Save the current working directory
        original_dir=$(pwd)

        # Navigate to the extracted_files/${FILE} directory
        cd extracted_files/${FILE}

        # Create the zip from the contents without including the extracted_files/${FILE} path itself
        zip -r ${original_dir}/${zip_filename} *
        # Navigate back to the original directory
        cd ${original_dir}
        # Upload the zip file to the blob container
        az storage blob upload --container-name ${CONTAINER} --file ./${zip_filename} --name ${zip_filename} --overwrite true
        echo "Zip file ${zip_filename} uploaded to blob container ${CONTAINER}."
    else
        # Batch upload the extracted files to the blob container using the specified pattern
        echo "Uploading extracted files to blob container ${CONTAINER} with pattern ${FILE}/**"
        az storage blob upload-batch --destination ${CONTAINER} --source extracted_files --pattern "${FILE}/**" --overwrite true
    fi
    echo "Files from ${url_basename} uploaded to blob container ${CONTAINER}."
else
    # Upload the file to the blob container, overwriting if it exists
    echo "Uploading file ${FILE} to blob container ${CONTAINER}"
    az storage blob upload --container-name ${CONTAINER} --file ./${FILE} --name ${FILE} --overwrite true
    echo "File ${FILE} uploaded to blob container ${CONTAINER}, overwriting if it existed."
fi