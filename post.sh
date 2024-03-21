#!/bin/bash
echo "sf project deploy start -x manifest/$1.xml -o $2 --ignore-conflicts"
sf project deploy start -x manifest/$1.xml -o $2 --ignore-conflicts