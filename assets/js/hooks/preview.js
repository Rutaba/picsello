const Preview = {
    frame_name: null,
    preview_name: null,
    coords: null,
    target: null,
    preview: null,
    renderImageWithFrame: null,
    ratio: null,
    mounted() {
        this.handleEvent("set_preview",
            ({preview: preview_name, frame: frame_name, coords: corners0, target: canvasId, ratio}) => {
                this.frame_name = frame_name
                this.preview_name = preview_name
                this.coords = corners0
                this.target = canvasId
                this.ratio = ratio

                this.draw(frame_name, preview_name, corners0, canvasId, ratio);
            })
    },

    draw(frame_name, preview_name, coord, canvasId, ratio) {
        if (typeof (coord) == 'string') {
            coord = JSON.parse(coord)
        }

        const canvas = document.getElementById(canvasId);

        if (canvas.getContext) {
            const ctx = canvas.getContext("2d");
            ctx.clearRect(0, 0, canvas.width, canvas.height);

            const frame = new Image();

            if (canvas.classList.contains('edit')) {
                const selectedImage = document.querySelector('.selected img');
                if (selectedImage) {
                    const selectedImage__height = selectedImage?.height
                    const selectedImage__width = selectedImage?.width
                    ratio = selectedImage__width / selectedImage__height
                }
            }

            const cw = canvas.width;
            const ch = canvas.height;

            canvas.width = cw;

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

                    let gk = w/h;
                    let sk = preview.width/preview.height

                    if(sk < gk){
                        let preview_width = width;
                        let preview_height = width / sk;
                        let lty = (ch * kfh) + (height - (preview_height))/2;
                        let ltx = cw * kfw;
                        ctx.drawImage(preview, ltx, lty, preview_width, preview_height);
                    } else if(gk < sk){
                        let preview_height = height;
                        let preview_width = height * sk;
                        let lty = ch * kfh;
                        let ltx = (cw * kfw) + (width - (preview_width))/2;
                        ctx.drawImage(preview, ltx, lty, preview_width, preview_height);
                    }
                    ctx.drawImage(frame, 0, 0, cw, ch);
                }
                const preview = new Image();
                preview.onload = renderImageWithFrame
                preview.src = preview_name;

                Preview.preview = preview
                Preview.renderImageWithFrame = renderImageWithFrame
            }
            frame.src = "/images/" + frame_name;
        }
    },
    updated() {
        this.handleEvent("set_preview", ({preview: preview_name, frame: frame_name, coords: corners0, target: canvasId}) => {
            this.draw(frame_name, preview_name, corners0, canvasId)
        })
        this.handleEvent("update_print_type", () => {
            this.draw(this.frame_name, this.preview_name, this.coords, this.target, this.ratio)
        })
    }
}

export default Preview;
