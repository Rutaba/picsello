export const buildContext = task => {
  return {
    task: task,
    artifacts: {
      original: {
        downloaded: false,
        filename: false,
        image: false
      },
      aspectRatio: false,
      isPreviewUploaded: false,
      
      watermark: {
        downloaded: false,
        filename: false,
        image: false
      },
      isWatermarkedUploaded: false,


    }};
}
