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
     "originalPath": "galleries/8/original/b8b2d70a-b57a-4cfd-a5ad-dd2b2a4685e2.jpg",
     "photoId": 1543,
     "previewPath": "galleries/8/preview/00327dba-2dd3-4fe4-b1ad-51b241fed8ac.jpg",
     "pubSubTopic": "lukianov-processed-photos"
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
     "originalPath": "galleries/8/original/b8b2d70a-b57a-4cfd-a5ad-dd2b2a4685e2.jpg",
     "photoId": 1543,
     "pubSubTopic": "lukianov-processed-photos",
     "watermarkText": "1",
     "watermarkedOriginalPath": "galleries/8/watermarked/4b02a094-46cf-4344-875e-82f0899ad720.jpg",
     "watermarkedPreviewPath": "galleries/8/watermarked_preview/e896b49e-69fe-4abe-827e-2e24345cd41c.jpg"
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
