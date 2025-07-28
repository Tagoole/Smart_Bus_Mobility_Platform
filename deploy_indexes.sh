#!/bin/bash

echo "Deploying Firestore indexes..."

# Deploy the indexes
firebase deploy --only firestore:indexes

echo "Indexes deployed successfully!"
echo ""
echo "Note: It may take a few minutes for the indexes to be fully created."
echo "If you still see index errors, please wait a few minutes and try again." 
