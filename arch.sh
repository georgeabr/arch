#!/bin/sh

# a comment

# will check if any arguments were passed to the program
if [ $# -lt 3 ]
    then
	echo "No arguments supplied\nProvide 3 arguments" 
#    else
#	echo "$#"
fi

if [ $# -ge 3 ]
then
    echo "Script has at least 3 arguments:\n$1, $2, $3"
fi

# test
