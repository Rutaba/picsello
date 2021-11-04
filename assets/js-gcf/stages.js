import sharp from "sharp";
import fs from "fs";
import Path from "path";
import {tmpdir} from "os";
import {Storage} from "@google-cloud/storage";
import {PubSub} from "@google-cloud/pubsub";


const previewWidth = 760;


/*******************************************************************************/

const hashCode = function(str) {
    let hash = 0;
    if (str.length === 0) {
        return hash;
    }
    for (var i = 0; i < str.length; i++) {
        var char = str.charCodeAt(i);
        hash = ((hash<<5)-hash)+char;
        hash = hash & hash; // Convert to 32bit integer
    }
    return hash;
}

const tmpFileName = (name) => Path.join(tmpdir(), hashCode(name).toString())

const downloadInto = async (bucket, path, destination) => {
    const storage = new Storage();
    const options = {
        destination: destination,
    };

    await storage.bucket(bucket).file(path).download(options);
}
const uploadTo = async (filename, bucket, path) => {
    const storage = new Storage();

    await storage.bucket(bucket).upload(filename, {destination: path});
}


const sendResponseToPubSub = (response, pubSubTopic) => {
    const pubSubClient = new PubSub();
    const dataBuffer = Buffer.from(JSON.stringify(response));

    return pubSubClient.topic(pubSubTopic).publish(dataBuffer);
}


/************************************************************************************/



export const downloadStage = context => {
    if (context.task && context.task.bucket && context.task.originalPath) {
        const filename = tmpFileName(context.task.originalPath)
        return downloadInto(context.task.bucket, context.task.originalPath, filename)
            .then(() => {
                context.artifacts.original.downloaded = true;
                context.artifacts.original.filename = filename;
                context.artifacts.original.image = sharp(filename);

                return context;
            })
    }

    return context;
}

export const aspectStage = context => {
    if (context.task && context.task.previewPath && context.artifacts.original.image) {
        return context.artifacts.original.image
            .metadata()
            .then(data => {
                context.artifacts.aspectRatio = data.width / data.height;

                return context;
            })
    }

    return context;
}

export const previewStage = context => {
    const task = context.task;
    const original = context.artifacts.original;
    if (task && task.previewPath && original.image && task.bucket) {
        const previewFilename = tmpFileName(task.previewPath)
        return original.image
            .resize({width: previewWidth})
            .toFile(previewFilename)
            .then(() => {
                return uploadTo(previewFilename, task.bucket, task.previewPath)
                    .then(() => {
                        context.artifacts.isPreviewUploaded = true;
                        fs.unlinkSync(previewFilename);

                        return context;
                    })
            })
    }

    return context;
}

export const watermarkStage = context => context;

export const cleanupStage = context => {
    const original = context.artifacts.original;
    if (original.filename) {
        fs.unlinkSync(original.filename);

        context.artifacts.original.filename = null;
        context.artifacts.original.image = null;
        context.artifacts.original.downloaded = null;

        return context;
    }

    return context;
};

export const responseStage = context => {
    if (context.task.pubSubTopic) {
        return sendResponseToPubSub(context, context.task.pubSubTopic)
            .then(() => context)
    }

    return context;
};

export const debugStage = context => {console.log(JSON.stringify(context)); return context;}
