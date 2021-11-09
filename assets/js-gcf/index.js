import * as Process from "process";
import {
  aspectStage,
  cleanupStage,
  debugStage,
  downloadStage,
  downloadWatermarkStage,
  previewStage,
  responseStage,
  watermarkStage
} from "./stages.js";

const buildContext = task => { return {
  task: task,
  artifacts: {
    original: {
      downloaded: false,
      filename: false,
      image: false
    },
    aspectRatio: false,
    isPreviewUploaded: false,
  }};
}


/**
 * Triggered from a message on a Cloud Pub/Sub topic.
 *
 * @param {!Object} event Event payload.
 * @param {!Object} meta Metadata for the event.
 */
export const doProcessing = async (event, meta) => {
  const message = event.data
      ? Buffer.from(event.data, 'base64').toString()
      : event.data;

  const context = buildContext(JSON.parse(message));
  console.log('context', context)

  await downloadStage(context)
      .then(aspectStage)
      .then(previewStage)
      .then(downloadWatermarkStage)
      .then(watermarkStage)
      .then(cleanupStage)
      .then(responseStage)
      .then(debugStage)
      .catch(error => {
        console.error(error);
        Process.exit(-1);
      })
};
