var Preview = { 
  draw: function(frame_name, preview_name, coord, canvasId) {
    console.log(coord);
    if(typeof(coord) == 'string'){coord = JSON.parse(coord)};
    
    let canvas = document.getElementById(canvasId);
    if (canvas.getContext) {
      let ctx = canvas.getContext("2d");
      ctx.clearRect(0, 0, canvas.width, canvas.height);

      let frame = new Image();
      frame.src = "/images/" + frame_name;

      let cw = canvas.width;
      let ch = canvas.height;

      frame.onload = function(){ // start upload frame
        let frameW = frame.width;
        let frameH = frame.height;
        let kfw = coord[0]/frameW;
        let kfh = coord[1]/frameH;
        let w = coord[6] - coord[0] + 1;
        let h = coord[7] - coord[1] + 1;

        let kw = cw / frameW;
        let kh = ch / frameH;

        let preview = new Image();
        preview.src = Preview.unescape(preview_name);
        preview.onload = function(){ // upload preview
          let width = (w * kw) < 10 && cw || (w * kw);
          let height = (h * kh) < 10 && ch || (h * kh);

          let lty = ch * kfh;
          let ltx = cw * kfw;

          ctx.drawImage(frame, 0, 0, cw, ch);
          ctx.drawImage(preview, ltx, lty, width, height);
        }
      }
    }
  },
  unescape: function(s){
    var re = /&(?:amp|#38|lt|#60|gt|#62|apos|#39|quot|#34);/g;
    var unescaped = {
        '&amp;': '&',
        '&#38;': '&',
        '&lt;': '<',
        '&#60;': '<',
        '&gt;': '>',
        '&#62;': '>',
        '&apos;': "'",
        '&#39;': "'",
        '&quot;': '',
        '&#34;': ''
    };
        return s.replace(re, function (m) {
        return unescaped[m];
    });
  }
}

export default Preview;