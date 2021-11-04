import * as Process from "process";
import {
    aspectStage,
    cleanupStage,
    debugStage,
    downloadStage,
    previewStage,
    responseStage,
    watermarkStage
} from "./stages.js";



const simpleTask = {
    // bucket: "picsello-staging",
    // originalPath: "0279c71f-802b-4242-96d7-5cb844f17878.jpeg",
    // previewPath: "preview_5cb844f17878.jpeg",
    // pubSubTopic: "stagging-processed-photos",

    "bucket": "picsello-staging",
    "originalPath": "5e4a288c-ced8-43a8-84f1-a26e9e526675.jpg",
    "photoId": 58,
    "previewPath": "galleries/3/preview/576ad8c1-9ee7-46ab-b95e-5ea98fcb92a3.jpg",
    "pubSubTopic": "projects/celtic-rite-323300/topics/stagging-processed-photos"
}

const fullTask = {
    bucket: "picsello-staging",
    originalPath: "0279c71f-802b-4242-96d7-5cb844f17878.jpeg",
    previewPath: "preview_5cb844f17878.jpeg",
    watermarkPath: "preview_5cb844f17878.jpeg",
    watermarkedOriginalPath: "preview_5cb844f17878.jpeg",
    watermarkedPreviewPath: "preview_5cb844f17878.jpeg",
}

const watermarkTask = {
    bucket: "picsello-staging",
    originalPath: "0279c71f-802b-4242-96d7-5cb844f17878.jpeg",
}



const context = task => { return {
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

/*********************************************************************************/

const res = await downloadStage(context(simpleTask))
    .then(aspectStage)
    .then(previewStage)
    .then(watermarkStage)
    .then(cleanupStage)
    .then(responseStage)
    // .then(debugStage)
    .catch(error => {
        console.error(error);
        Process.exit(-1);
    })

console.log(res)
