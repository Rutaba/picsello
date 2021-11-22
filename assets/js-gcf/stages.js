import sharp from "sharp";
import fs from "fs";
import Path from "path";
import {tmpdir} from "os";
import {Storage} from "@google-cloud/storage";
import {PubSub} from "@google-cloud/pubsub";
import {loadFont, convert} from "./font.js"

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


export const downloadWatermarkStage = context => {
    if (context.task && context.task.bucket && context.task.watermarkPath) {
        const filename = tmpFileName(context.task.watermarkPath)
        return downloadInto(context.task.bucket, context.task.watermarkPath, filename)
            .then(() => {
                context.artifacts.watermark.downloaded = true;
                context.artifacts.watermark.filename = filename;
                context.artifacts.watermark.image = sharp(filename);

                return context;
            })
    }

    return context;
}

export const generateTextWatermarkStage = async context => {
    
    if (context.task && context.task.watermarkText) {
        const text = context.task.watermarkText;
        const font = loadFont('BeVietnam-Bold')
        const watermarkFile = tmpFileName(text + ".textWatermark.png")
        
        await convert(font, text, 0, -60, 100, {padding: 0}).then(buffer => {
            fs.writeFileSync(watermarkFile, buffer)
        })
        
        context.artifacts.watermark.downloaded = true;
        context.artifacts.watermark.filename = watermarkFile;
        context.artifacts.watermark.image = sharp(watermarkFile);

        return context;
    }

    return context
}


export const watermarkStage = async context => {
    const ratio = 0.8;
    const task = context.task;
    const original = context.artifacts.original;
    const watermark = context.artifacts.watermark;

    if (task
        && task.bucket
        && task.watermarkedOriginalPath
        && task.watermarkedPreviewPath
        && original.filename
        && watermark.image
    ) {
        const watermarkedFilename = tmpFileName(task.watermarkedOriginalPath)
        const watermarkedPreviewFilename = tmpFileName(task.watermarkedPreviewPath)
        const wmPattern = tmpFileName(task.watermarkPath + ".pattern.png")
        const wmLayer = tmpFileName(task.watermarkPath + ".layer.png")

        const originalMeta = await original.image.metadata()

        await watermark.image
            .linear(0, 0)
            .resize(
                Math.floor(originalMeta.width * ratio),
                Math.floor(originalMeta.height * ratio),
                {
                    fit: 'contain',
                    background: { r: 0, g: 0, b: 0, alpha: 0 }
                }
            )
            .toFile(wmPattern)


        await sharp({
                create: {
                    width: originalMeta.width,
                    height: originalMeta.height,
                    channels: 4,
                    background: { r: 255, g: 255, b: 255, alpha: 1 }
                }
            })
            .png()
            .composite([{input: wmPattern}])
            .removeAlpha()
            .linear(-1, 255)
            .ensureAlpha(0.25)
            .toFile(wmLayer)

        await original.image
            .resize({width: originalMeta.width})
            .composite([{input: wmLayer}])
            .toFile(watermarkedFilename)

        await sharp(watermarkedFilename)
            .resize(previewWidth)
            .toFile(watermarkedPreviewFilename)

        await uploadTo(watermarkedFilename, task.bucket, task.watermarkedOriginalPath)
        await uploadTo(watermarkedPreviewFilename, task.bucket, task.watermarkedPreviewPath)

        context.artifacts.isWatermarkedUploaded = true;

        return context;

    }


    return context;

};

export const cleanupStage = context => {
    const original = context.artifacts.original;
    const watermark = context.artifacts.watermark;
    if (original.filename) {
        fs.unlinkSync(original.filename);

        context.artifacts.original.filename = null;
        context.artifacts.original.image = null;
        context.artifacts.original.downloaded = null;
    }
    if (watermark.filename) {
        fs.unlinkSync(watermark.filename);

        context.artifacts.watermark.filename = null;
        context.artifacts.watermark.image = null;
        context.artifacts.watermark.downloaded = null;
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
