import { processProfileImage } from './index.js';
import { PubSub } from '@google-cloud/pubsub';
import process from 'process';
import { randomUUID } from 'crypto';

const VERSION_ID = randomUUID();

new PubSub()
  .topic(process.env.PHOTO_PROCESSING_OUTPUT_TOPIC)
  .subscription(process.env.PHOTO_PROCESSING_OUTPUT_SUBSCRIPTION)
  .on('message', (message) => {
    const data = JSON.parse(message.data.toString());
    console.log(data);
    console.log(
      `processed image url: https://${process.env.GOOGLE_PUBLIC_IMAGE_HOST}/${data.path}?${VERSION_ID}`
    );
    if (data.metadata['version-id'] === VERSION_ID) process.exit();
    else console.log('not ours! keep waiting.');
  });

// once when original upload is written
processProfileImage({
  bucket: process.env.PUBLIC_BUCKET,
  name: 'sdfsfsf/logo/original.png',
  metadata: {
    ['version-id']: VERSION_ID,
    ['pubsub-topic']: process.env.PHOTO_PROCESSING_OUTPUT_TOPIC,
    resize: '{"height": 100}',
    ['out-filename']: 'sdfsfsf/logo/test.png',
  },
  contentType: 'image/png',
}).then(
  /* again when resize is written */
  processProfileImage
);
