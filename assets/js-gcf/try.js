import * as Process from "process";
import {
    aspectStage,
    cleanupStage,
    debugStage,
    downloadStage, downloadWatermarkStage, generateTextWatermarkStage,
    previewStage,
    responseStage,
    watermarkStage
} from "./stages.js";
import { buildContext } from "./context.js";


const simpleTask = {
    "bucket": "picsello-staging",
    "originalPath": "5e4a288c-ced8-43a8-84f1-a26e9e526675.jpg",
    "photoId": 58,
    "previewPath": "galleries/3/preview/576ad8c1-9ee7-46ab-b95e-5ea98fcb92a3.jpg",
    "pubSubTopic": "projects/celtic-rite-323300/topics/stagging-processed-photos"
}

const fullTask = {
    "bucket": "picsello-staging",
    "originalPath": "galleries/6/original/dd40d42a-712c-4ab8-acde-076d143a2b37.png",
    "photoId": 156,
    "previewPath": "galleries/6/preview/5db2b5f5-8e69-41ca-a1a4-beafcad77304.png",
    "pubSubTopic": "projects/celtic-rite-323300/topics/lukianov-processed-photos",
    "watermarkPath": "galleries/6/original/902266c8-725c-483f-81ff-5d35f0019d65.png",
    "watermarkedOriginalPath": "galleries/6/watermarked/dd40d42a-712c-4ab8-acde-076d143a2b37.png",
    "watermarkedPreviewPath": "galleries/6/watermarked_preview/dd40d42a-712c-4ab8-acde-076d143a2b37.png",
}

const watermarkTask = {
    "bucket": "picsello-staging",
    "originalPath": "galleries/6/original/dd40d42a-712c-4ab8-acde-076d143a2b37.png",
    "photoId": 156,
    "previewPath": "galleries/6/preview/5db2b5f5-8e69-41ca-a1a4-beafcad77304.png",
    "pubSubTopic": "projects/celtic-rite-323300/topics/lukianov-processed-photos",
    "watermarkText": "Water Mark",
    "watermarkedOriginalPath": "galleries/6/watermarked/dd40d42a-712c-4ab8-acde-076d143a2b37.png",
    "watermarkedPreviewPath": "galleries/6/watermarked_preview/dd40d42a-712c-4ab8-acde-076d143a2b37.png",
}


/*********************************************************************************/

const runTask = async task =>
    await downloadStage(buildContext(task))
    .then(aspectStage)
    .then(previewStage)
    .then(downloadWatermarkStage)
    .then(generateTextWatermarkStage)
    .then(watermarkStage)
    .then(cleanupStage)
    .then(responseStage)
    // .then(debugStage)
    .catch(error => {
        console.error(error);
        Process.exit(-1);
    });

for (let i = 0; i < 1; i++){
  console.log(await runTask(watermarkTask))
  console.log(
    process.memoryUsage().rss / 1024 / 1024,
    process.memoryUsage().heapUsed / 1024 / 1024,

  );
}
