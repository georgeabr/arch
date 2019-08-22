#!/bin/sh

# git clone https://github.com/georgeabr/arch.git
# git config --global user.email "email@gmail.com"
# git config --global user.name "georgeabr"

# to save passwords
# git config credential.helper store

# commit the code
# git add .; git commit -m "added"; git push -u origin master

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
