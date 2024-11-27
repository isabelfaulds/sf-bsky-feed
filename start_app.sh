#!/bin/bash
cd /home/ec2-user/sf-bsky-feed
source venv/bin/activate
sudo /home/ec2-user/sf-bsky-feed/venv/bin/python3 -m pip install --upgrade pip
pip install -r requirements.txt
# Ensure correct permissions for application files
sudo chown -R ec2-user:ec2-user /home/ec2-user/sf-bsky-feed
chmod -R 775 /home/ec2-user/sf-bsky-feed
gunicorn -w 1 -b 0.0.0.0:5000 server.app:app
