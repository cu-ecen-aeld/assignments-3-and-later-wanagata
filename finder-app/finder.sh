#!/bin/sh
if [ "$#" -ne 2 ]; then
    echo "Any of the parameters above were not specified and first arg should be a directory"
    exit 1
    
elif [ ! -d  "$1" ]; then
    echo "Error: $1 is not a directory"
    exit 1
else
    filesdir=$(find "$1" -type f | wc -l)
    searchstr=$(grep -r "$2" "$1" | wc -l)

    echo "The number of files are $filesdir and the number of matching lines are $searchstr"
fi

exit 0