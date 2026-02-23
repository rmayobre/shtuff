#!/bin/bash

source ../shtuff.sh

mkdir testdir

for i in {1..10}; do
    touch "test-$i.txt"
    echo "Hello, world!" > "test-$i.txt"
done

copy test-1.txt test-2.txt test-3.txt test-4.txt test-5.txt testdir
move test-6.txt test-7.txt test-8.txt test-9.txt test-10.txt testdir
delete test-1.txt test-2.txt test-3.txt test-4.txt test-5.txt

for i in {1..10}; do
    FILE_NAME="test-$i.txt"
    FILE_PATH="testdir/$FILE_NAME"
    # Use -f to check if it is a regular file
    if [ ! -f "$FILE_PATH" ]; then
        echo "Test FAILED: Missing file '$FILE_NAME' in testdir." >&2
        exit 1
    fi
done

echo "File Operation Functions - Passed!"

rm -rf testdir
