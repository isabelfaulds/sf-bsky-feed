# San Francisco Bluesky Feed

This feed is currently using aws for cloud resources, but may change in the future

## Pre Requisites
- Generate a bluesky app password in bsky.app & store a value for BLUESKY_APP_PASSWORD in aws systems manager
    - ie with cli ```aws ssm put-parameter --name "BLUESKY_APP_PASSWORD" --value "testing123" --type "SecureString"
- Set up AWS CLI & ```aws configure``` for non-root user
- Set up Terraform 
- Create a key pair
    - ```aws ec2 create-key-pair --key-name sf-bsky-feed-key --query 'KeyMaterial' --output text > sf-bsky-feed-key.pem```
    - ```chmod 400 sf-bsky-feed-key.pem```


## List of Deployed Components


   ,     #_
   ~\_  ####_       
  ~~  \_#####\
  ~~     \###|       
  ~~       \#/ ___
   ~~       V~' '->
    ~~~         /    
      ~~._.   _/
         _/ _/      
       _/m/' 

Amazon Linux 2 bird delivering the feed

- vpc
    - subnet
    - security group
- ec2 instance
    - starting with t3 medium for reading 1 million posts a day on bluesky , [jazco bluesky stats](https://bsky.jazco.dev/stats). Will continue monitoring / update based on utilization
    - Recommend changing ami to amazon linux 2023
- cloudfront
- acm
- route 53
- s3 bucket
- permissions
- monitoring


- terraform outputs: feed_server_eip 
    - ie 54.193.25.228 , Save to host in 
    - http://54.219.119.69:5000
    - http://54.219.119.69:5000/xrpc/app.bsky.feed.getFeedSkeleton
    - https://isabelfaulds.com/xrpc/app.bsky.feed.getFeedSkeleton
    - http://origin.isabelfaulds.com:5000/xrpc/app.bsky.feed.getFeedSkeleton
    - https://d3s8u5d4a9zqt2.cloudfront.net/
    - https://isabelfaulds.com/xrpc/app.bsky.feed.getFeedSkeleton?feed=at://did:plc:3gzl324dgmnpfttv7b7mddxq/app.bsky.feed.generator/san-francisco&cursor=abc&limit=10

## Things to Changeg


### Debugging Guide
If changes are made to this repo here are things to check for debugging :-)

- Check if instance has dependencies
    - ssh into ec2 : ```chmod 400 someverypemyfile.pem``` , ```ssh -i someverypemyfile.pem ec2-user@the:ec2's:public:ip:address``` , if prompted```yes``` to permanently add host 
    - activate the venv (```source venv/bin/activate```)
    - check your python version ```python --version``` , an amazon linux 2 will default 3.7 if not specified
    - compare requirements.txt to ```pip list``` , add any new packages to requirements

- Check if instance has started flask
    - check for the process ```ps aux | grep flask``` 
- Check if flask is running on correct port
    - ```flask run &``` if not running , then check with ```sudo netstat -tuln | grep 443```
- Check if ```feed_database.db``` database file is being created properly
    - Running db file ```python server/database.py``` 
    - Check ec2-user (not in root group) permissions for writing to the folder ```ls -ld``` , prefer ```drwxrwxr-x 5 ec2-user```
    - Update permissions as needed with ```sudo chown -R ec2-user:ec2-user /home/ec2-user/sf-bsky-feed``` , ```chmod 775 /home/ec2-user/sf-bsky-feed```
- Check if ```feed_datbase.db``` is writing properly
    - ```ls -l /home/ec2-user/sf-bsky-feed/feed_database.db``` ec2-user needs ownership of file for flask run ```-rw-rw``` for ec2-user
- If eip changed during redeployments check if ec2 HOSTNAME is up to date ```vim /home/ec2-user/sf-bsky-feed/.env```
- Check if data filtering logic is working, test run 


### Compiled References

- https://github.com/MarshalX/bluesky-feed-generator
- https://docs.bsky.app/docs/starter-templates/custom-feeds
    - https://github.com/bluesky-social/feed-generator
- https://blueskyfeeds.com/en
- https://docs.google.com/document/d/1P9CADZ3odqzGnGdqljZMYHgdfxmWZmb8c1sP8HjpgGg/edit?pli=1
- https://www.worm.gay/blog/a-gentleish-intro-to-regex-for-skyfeed