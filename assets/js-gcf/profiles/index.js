import sharp from 'sharp';
import { Storage } from '@google-cloud/storage';
import { PubSub } from '@google-cloud/pubsub';
import { debuglog } from 'util';
import path from 'path';

const debugEvent = debuglog('event');

const resize = (bucketName, inFilename, outFilename, resize, metadata) =>
  new Promise((resolve, reject) => {
    const bucket = new Storage().bucket(bucketName);

    bucket
      .file(inFilename)
      .createReadStream()
      .pipe(sharp().resize(resize))
      .pipe(bucket.file(outFilename).createWriteStream({ metadata }))
      .on('error', (e) => {
        console.error(e);
        reject(e);
      })
      .on('finish', (_) => {
        resolve({ ...metadata, name: outFilename, bucket: bucket.name });
      });
  });

function publish(response, pubSubTopic) {
  const pubSubClient = new PubSub();
  const dataBuffer = Buffer.from(JSON.stringify(response));

  return pubSubClient.topic(pubSubTopic).publish(dataBuffer);
}

/**
 * Triggered when a file is written to the public profile bucket.
 *
 * @param {!Object} event Event payload.
 * @param {!Object} meta Metadata for the event.
 */
export async function processProfileImage(event, _meta) {
  debugEvent(event);

  const { bucket: bucketName, name, metadata, contentType } = event;

  const {
    ['out-filename']: outFilename,
    resize: resizeJson,
    ...publishMetadata
  } = metadata;

  if (outFilename && resizeJson)
    return await resize(bucketName, name, outFilename, JSON.parse(resizeJson), {
      contentType,
      metadata: publishMetadata,
    });

  const { ['pubsub-topic']: topic, ...messageMetadata } = publishMetadata;

  if (topic)
    return await publish(
      { path: path.join(bucketName, name), metadata: messageMetadata },
      topic
    );
  }
}
