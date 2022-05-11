function draw(canvas) {
  const {
    preview: previewSrc,
    frame: frameSrc,
    coords: coord,
  } = JSON.parse(canvas.dataset.config);

  const w = coord[6] - coord[0] + 1;
  const h = coord[7] - coord[1] + 1;

  const ctx = canvas.getContext('2d');

  const { width: cw, height: ch } = canvas;

  const frame = new Image();

  frame.onload = () => {
    const frameW = frame.width;
    const frameH = frame.height;

    const kfw = coord[0] / frameW;
    const kfh = coord[1] / frameH;

    const preview = new Image();
    preview.onload = () => {
      const kw = cw / frameW;
      const kh = ch / frameH;

      const width = (w * kw < 10 && cw) || w * kw;
      const height = (h * kh < 10 && ch) || h * kh;

      const gk = w / h;
      const sk = preview.width / preview.height;

      if (sk < gk) {
        const preview_width = width;
        const preview_height = width / sk;
        const lty = ch * kfh + (height - preview_height) / 2;
        const ltx = cw * kfw;
        ctx.drawImage(preview, ltx, lty, preview_width, preview_height);
      } else if (gk < sk) {
        const preview_height = height;
        const preview_width = height * sk;
        const lty = ch * kfh;
        const ltx = cw * kfw + (width - preview_width) / 2;
        ctx.drawImage(preview, ltx, lty, preview_width, preview_height);
      }
      ctx.drawImage(frame, 0, 0, cw, ch);
    };

    preview.src = previewSrc;
  };

  frame.src = '/images/' + frameSrc;
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
