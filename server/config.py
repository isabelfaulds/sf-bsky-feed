import os

# SERVICE_DID = os.environ.get('SERVICE_DID', None)
# HOSTNAME = os.environ.get('HOSTNAME', None)
# You can obtain it by publishing of feed (run publish_feed.py)

# Set this to the hostname that you intend to run the service at
HOSTNAME="isabelfaulds.com"
SERVICE_DID= None

if HOSTNAME is None:
    raise RuntimeError('You should set "HOSTNAME" environment variable first.')

if SERVICE_DID is None:
    SERVICE_DID = f'did:web:{HOSTNAME}'


SF_FEED_URI = os.environ.get('SF_FEED_URI')
SF_FEED_URI="at://did:plc:3gzl324dgmnpfttv7b7mddxq/app.bsky.feed.generator/san-francisco"
if SF_FEED_URI is None:
    raise RuntimeError('Publish your feed first (run publish_feed.py) to obtain Feed URI. '
                       'Set this URI to "SF_FEED_URI" environment variable.')
