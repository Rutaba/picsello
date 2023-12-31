import { processProfileImage } from './index.js';
import { PubSub } from '@google-cloud/pubsub';
import process from 'process';
import { randomUUID } from 'crypto';

const VERSION_ID = randomUUID();

new PubSub()
  .subscription(process.env.PHOTO_PROCESSING_OUTPUT_SUBSCRIPTION)
  .on('message', (message) => {
    const data = JSON.parse(message.data.toString());
    console.log(data);
    console.log(
      `processed image url: https://${process.env.GOOGLE_PUBLIC_IMAGE_HOST}/${data.path}`
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
    ['out-filename']: `sdfsfsf/logo/${VERSION_ID}.png`,
  },
  contentType: 'image/png',
}).then(({ metadata, ...event }) => {
  // again when resize is written. this time no metadata
  processProfileImage(event);
});
