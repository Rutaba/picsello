function cropFill(
  { width: previewW, height: previewH },
  { w: slotW, h: slotH }
) {
  const srcAspectRatio = previewW / previewH;
  const slotAspectRatio = slotW / slotH;

  if (srcAspectRatio > slotAspectRatio) {
    // src too wide, crop right and left edges

    const w = previewH * slotAspectRatio;
    return {
      x: (previewW - w) / 2,
      y: 0,
      w,
      h: previewH,
    };
  } else {
    // src too narrow, crop top and bottom edges

    const h = previewW / slotAspectRatio;
    return {
      x: 0,
      y: (previewH - h) / 2,
      w: previewW,
      h,
    };
  }
}

const loadImage = (src) =>
  new Promise((resolve) => {
    const image = new Image();
    image.addEventListener('load', () => {
      resolve(image);
    });
    image.src = src;
  });

function drawImage(context, image, { src, dest }) {
  context.drawImage(
    image,
    src.x,
    src.y,
    src.w,
    src.h,
    dest.x,
    dest.y,
    dest.w,
    dest.h
  );
}

function drawPreview(context, img, { dest }) {
  drawImage(context, img, { dest, src: cropFill(img, dest) });
}

function draw(canvas) {
  const {
    preview: { url: previewUrl, ...previewBoxes },
    frame: { url: frameUrl, rotate, ...frameBoxes },
  } = JSON.parse(canvas.dataset.config);
  const context = canvas.getContext('2d');

  if (frameUrl) {
    Promise.all([previewUrl, frameUrl].map(loadImage)).then(
      ([previewImg, frameImg]) => {
        drawPreview(context, previewImg, previewBoxes);
        drawImage(context, frameImg, frameBoxes);
      }
    );
  } else {
    loadImage(previewUrl).then((previewImg) => {
      drawPreview(context, previewImg, previewBoxes);
    });
  }
}

const Preview = {
  mounted() {
    draw(this.el);
  },
  updated() {
    draw(this.el);
  },
};

export default Preview;
