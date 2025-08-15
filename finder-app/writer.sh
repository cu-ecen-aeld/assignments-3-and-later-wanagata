if [ "$#" -ne 2 ]; then
    echo "Error: Missing arguments"
    echo "Usage: $0 <writefile> <writestr>"
    exit 1
fi

writefile="$1"
writestr="$2"

dir_path=$(dirname $writefile)
# check file is a directory or make the directory success
{ [ -d "$dir_path" ] || mkdir -p "$dir_path"; } && { echo "$writestr" > "$writefile" || { echo "Error: Cannot create file"; exit 1; }; }

cat $writefile 

exit 0

#Accepts the following arguments: the first argument is a full path to a file (including filename) on the filesystem, referred to below as writefile; the second argument is a text string which will be written within this file, referred to below as writestr

#Exits with value 1 error and print statements if any of the arguments above were not specified

#Creates a new file with name and path writefile with content writestr, overwriting any existing file and creating the path if it doesn’t exist. Exits with value 1 and error print statement if the file could not be created.

git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"