#!/bin/bash

# Variables
CUSTOM_SPELLING_INT_PATH="org/languagetool/resource/en/hunspell/spelling.txt"
CUSTOM_SPELLING_EXT_PATH="/dictionary_files"}
CUSTOM_SPELLING_FILE="en_spelling_additions.txt"
MD5SUM_FILE=${CUSTOM_SPELLING_FILE}.md5

# Install custom dictionary file if true
# Set internal volume location to "/dictionary_files"
if [ "$CUSTOM_DICTIONARY" = true ]; then
    echo "Updating Custom Dictionary file..."

    # Check if the md5sum file exists
    if [ -e "$MD5SUM_FILE" ]; then
        # Read the last recorded md5sum from the file
        LAST_MD5SUM=$(cat "$MD5SUM_FILE")
    else
        # If the md5sum file doesn't exist, create an empty one
        touch "$MD5SUM_FILE"
        LAST_MD5SUM=""
    fi

    # Calculate the current md5sum of the file
    CURRENT_MD5SUM=$(md5sum "${CUSTOM_SPELLING_EXT_PATH}/${CUSTOM_SPELLING_FILE}" | awk '{print $1}')

    # Compare the current and last md5sum
    if [ "$CURRENT_MD5SUM" != "$LAST_MD5SUM" ]; then
        echo "File has changed!"
        (echo; cat "${CUSTOM_SPELLING_EXT_PATH}/${CUSTOM_SPELLING_FILE}") >> "org/languagetool/resource/en/hunspell/spelling.txt"
        
        # Update the md5sum file with the new hash
        echo "$CURRENT_MD5SUM" > "$MD5SUM_FILE"
    else
        echo "Dictionary file has not changed. Not overwriting."
    fi
else
    echo "Custom Dictionary not enabled..."
fi

for varname in ${!langtool_*}
do
    config_injected=true
    echo "${varname#'langtool_'}="${!varname} >> config.properties
done

if [ "$config_injected" = true ] ; then
    echo 'The following configuration is passed to LanguageTool:'
	echo "$(cat config.properties)"
fi

Xms=${Java_Xms:-256m}
Xmx=${Java_Xmx:-512m}

set -x
exec java -Xms$Xms -Xmx$Xmx -cp languagetool-server.jar org.languagetool.server.HTTPServer --port 8010 --public --allow-origin '*' --config config.properties
