#!/bin/bash
# Restart Duplicati server to prevent hanging on "verifying backup data"

sudo pkill -9 -f duplicati-server
sleep 2
sudo envchain duplicati /Applications/Duplicati.app/Contents/MacOS/duplicati-server --webservice-port 8200 --webservice-interface any --server-datafolder /Users/Shared/Duplicati/data --log-file=/Users/Shared/Duplicati/log/duplicati.log --log-level Warning &
