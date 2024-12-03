# San Francisco Bluesky Feed

 Bluesky feed using AWS & python atproto [feed template](https://github.com/MarshalX/bluesky-feed-generator) & package

## Pre Requisites
- Generate a bluesky app password in bsky.app & store a value for BLUESKY_APP_PASSWORD in aws systems manager
    - ie with cli ```aws ssm put-parameter --name "BLUESKY_APP_PASSWORD" --value "testing123" --type "SecureString"
- Set up AWS CLI & ```aws configure``` for non-root user
- Set up Terraform 
- Create a key pair
    - ```aws ec2 create-key-pair --key-name sf-bsky-feed-key --query 'KeyMaterial' --output text > sf-bsky-feed-key.pem```
    - ```chmod 400 sf-bsky-feed-key.pem```


## List of Deployed Components

```ascii
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
```

Amazon Linux 2 bird delivering the feed

- vpc
    - 1 subnet
    - 1 security group
- ec2 instance
    - testing with t3 medium
    - stats on bluesky posts [jazco bluesky stats](https://bsky.jazco.dev/stats)
- acm
- route 53
- cloudfront
- iam permissions
- monitoring
- terraform outputs: feed_server_eip 

## Things to Change
- Update terraform.tfvars.example to terraform.tfvars , include [your ip address for ssh](https://whatismyipaddress.com/)
- Update filtering logic in data_filter.py
- Update route 53 zone to a usable domain

## Debugging Checks
If any issues some key things to check for debugging :-)

- ssh into ec2 , ```ssh -i somepem.pem ec2-user@elasticipaddress```
- move into feed folder ,```cd sf-bsky-feed```
- activate the venv (```source venv/bin/activate```)
- Check dependencies
    - check your python version ```python --version``` , an amazon linux 2 will default 3.7 if not specified
    - compare requirements.txt to ```pip list``` , add any new packages to requirements
- Check gunicorn
    - check for the process ```ps aux | grep gunicorn``` 
- Check ec2 permissions
    - Check ec2-user (not in root group) permissions for writing to the folder ```ls -ld``` , prefer ```drwxrwxr-x 5 ec2-user```
    - Check feed_database writing permissions ```ls -l /home/ec2-user/sf-bsky-feed/feed_database.db``` ec2-user needs ownership of file for flask run ```-rw-rw...``` for ec2-user
- In Browser:
    - Check the elastic ip address of the server
        - http://NN.NNN.NNN.NN:5000
        - http://NN.NNN.NNN.NN:5000/xrpc/app.bsky.feed.getFeedSkeleton
    - Check the route 53 routing of eip to subdomain
        - http://origin.isabelfaulds.com:50w00/xrpc/app.bsky.feed.getFeedSkeleton
    - Check if cloudfront is pointing to subdomain (note: now in https)
        - https://d3s8u5d4a9zqt2.cloudfront.net/
    - Check the routing of cloudfront to domain
        - https://isabelfaulds.com/xrpc/app.bsky.feed.getFeedSkeleton
    - Check the bluesky query of the feed
        - https://isabelfaulds.com/xrpc/app.bsky.feed.getFeedSkeleton?feed=at://did:plc:3gzl324dgmnpfttv7b7mddxq/app.bsky.feed.generator/san-francisco&cursor=abc&limit=10

## Compiled Bluesky Feed Generation References

- https://github.com/MarshalX/bluesky-feed-generator
- https://docs.bsky.app/docs/starter-templates/custom-feeds
    - https://github.com/bluesky-social/feed-generator
- https://blueskyfeeds.com/en
- https://docs.google.com/document/d/1P9CADZ3odqzGnGdqljZMYHgdfxmWZmb8c1sP8HjpgGg/edit?pli=1
- https://www.worm.gay/blog/a-gentleish-intro-to-regex-for-skyfeed