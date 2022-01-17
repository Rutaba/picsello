const Preview = {
    frame_name: null,
    preview_name: null,
    coords: null,
    target: null,
    preview: null,
    renderImageWithFrame: null,
    mounted() {
        this.handleEvent("set_preview",
            ({preview: preview_name, frame: frame_name, coords: corners0, target: canvasId}) => {
                this.frame_name = frame_name
                this.preview_name = preview_name
                this.coords = corners0
                this.target = canvasId

                this.draw(frame_name, preview_name, corners0, canvasId);
            })
    },

    draw(frame_name, preview_name, coord, canvasId) {

        if (typeof (coord) == 'string') {
            coord = JSON.parse(coord)
        }

        const screenWidth = window.innerWidth;
        const canvas = document.getElementById(canvasId);

        if (canvas.getContext) {
            const ctx = canvas.getContext("2d");
            ctx.clearRect(0, 0, canvas.width, canvas.height);

            const frame = new Image();
            frame.src = "/images/" + frame_name;

            if (screenWidth < 640) {
                canvas.width = 120
                canvas.height = 80
            }

            const cw = canvas.width;
            const ch = canvas.height;

            frame.onload = function () {
                const frameW = frame.width;
                const frameH = frame.height;
                const kfw = coord[0] / frameW;
                const kfh = coord[1] / frameH;
                const w = coord[6] - coord[0] + 1;
                const h = coord[7] - coord[1] + 1;

                const kw = cw / frameW;
                const kh = ch / frameH;

                const renderImageWithFrame = function () {
                    const width = (w * kw) < 10 && cw || (w * kw);
                    const height = (h * kh) < 10 && ch || (h * kh);

                    const lty = ch * kfh;
                    const ltx = cw * kfw;

                    ctx.drawImage(frame, 0, 0, cw, ch);
                    ctx.drawImage(preview, ltx, lty, width, height);
                }

                const preview = new Image();
                preview.src = preview_name;
                preview.onload = renderImageWithFrame

                Preview.preview = preview
                Preview.renderImageWithFrame = renderImageWithFrame
            }
        }
    },
    updated() {
        this.draw(this.frame_name, this.preview_name, this.coords, this.target);
        if (this.preview) {
            this.renderImageWithFrame()
        }
    }
}

export default Preview;
