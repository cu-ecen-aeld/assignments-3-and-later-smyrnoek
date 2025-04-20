#!/bin/sh

filesdir=$1;
searchstr=$2;

if [ -z $filesdir ]; then #string is empty
    echo "Arugment 1 not specified"
    exit 1
else
    if [ -z $searchstr ]; then
        echo "Argument 2 not speciied"
        exit 1
    else
        if [ -d "$filesdir" ]; then # file exists and IS a directory
            countFiles=$(find $filesdir -type f | wc -l)
            countStr=$(grep -r $searchstr $filesdir | wc -l)
            echo "The number of files are $countFiles and the number of matching lines are $countStr"
            exit 0
        else
            echo "filesdir no a directory"
            exit 1
        fi
    fi
fi



