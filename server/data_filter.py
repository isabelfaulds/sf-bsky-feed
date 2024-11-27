from collections import defaultdict

from atproto import models

from server.logger import logger
from server.database import db, Post
import re


def operations_callback(ops: defaultdict) -> None:
    posts_to_create = []
    for created_post in ops[models.ids.AppBskyFeedPost]['created']:
        author = created_post['author']
        record = created_post['record']

        # for testing stream
        log = True
        post_with_images = isinstance(record.embed, models.AppBskyEmbedImages.Main)
        inlined_text = record.text.replace('\n', ' ')

        if log:
            logger.info(
                f'NEW POST '
                f'[CREATED_AT={record.created_at}]'
                f'[AUTHOR={author}]'
                f'[WITH_IMAGE={post_with_images}]'
                f': {inlined_text}'
            )

        sf_coded = {'name':['san francisco', 'san fran', 'sfo', 'bay area', 'silicon valley', 'cerebral valley'
                            ],
                    'neighborhoods': ['duboce triangle', 'castro', 'noe valley', 'potrero hill', 'soma', 
                                      'tenderloin', 'twin peaks', 'western addition', 'hayes valley', 
                                      'pacific heights', 'presidio', 'richmond', 'inner sunset', 'outer sunset', 
                                      'north beach', 'telegraph hill', 'financial district', 'nob hill', 'russian hill', 
                                      'south beach', 'south of market'
                                      'rincon hill'
                                      ],
                    'parks': ['dolores park', 'duboce park', 'alamo square', 'mission dolores park', 'corona heights', 
                              'glen canyon park', 'mount davidson', 'sutro heights park', 'sutro forest', 
                              'sutro park', 'sutro baths', 'sutro sam', 'sutro tower', 'sutro tunnel',
                                'sutro terrace', 'sutro trail', 'sutro walk','sutro woods','alcatraz',
                                  'angel island','treasure island', 'yuerba buena island', 'marina green',
                                   'golden gate bridge' ]}
        unnested_values = [item for sublist in sf_coded.values() for item in sublist]

        sf_coded = [fr'\b{item}\b' for sublist in sf_coded.values() for item in sublist]


        if re.search( '|'.join(sf_coded) , record.text.lower()) is not None:
            reply_root = reply_parent = None
            if record.reply:
                reply_root = record.reply.root.uri
                reply_parent = record.reply.parent.uri

            post_dict = {
                'uri': created_post['uri'],
                'cid': created_post['cid'],
                'reply_parent': reply_parent,
                'reply_root': reply_root,
            }
            posts_to_create.append(post_dict)
            logger.info(
                f'NEW FEED POST '
                f'[CREATED_AT={record.created_at}]'
                f'[AUTHOR={author}]'
                f'[WITH_IMAGE={post_with_images}]'
                f'[URI={created_post["uri"]}]'
                f': {inlined_text}'
            )

    posts_to_delete = ops[models.ids.AppBskyFeedPost]['deleted']
    if posts_to_delete:
        post_uris_to_delete = [post['uri'] for post in posts_to_delete]
        Post.delete().where(Post.uri.in_(post_uris_to_delete))
        logger.info(f'Deleted from feed: {len(post_uris_to_delete)}')

    if posts_to_create:
        with db.atomic():
            for post_dict in posts_to_create:
                Post.create(**post_dict)
                logger.info(f'Added to feed: {post_dict["uri"]}')
        logger.info(f'Length Added to feed: {len(posts_to_create)}')
