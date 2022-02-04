import * as Process from "process";
import {
  aspectStage,
  cleanupStage,
  debugStage,
  downloadStage,
  downloadWatermarkStage,
  generateTextWatermarkStage,
  previewStage,
  responseStage,
  watermarkStage
} from "./stages.js";
import { buildContext } from "./context.js";


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

  await downloadStage(context)
      .then(aspectStage)
      .then(previewStage)
      .then(downloadWatermarkStage)
      .then(generateTextWatermarkStage)
      .then(watermarkStage)
      .then(cleanupStage)
      .then(responseStage)
      .then(debugStage)
      .catch(error => {
        console.error(error);
        Process.exit(-1);
      })
};
