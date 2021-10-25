export default {
  init_upload_progress() {
    const [uploadProgress] = document.getElementsByTagName("progress");
    
    this.uploadId = this.el.id;
    this.uploadProgress = uploadProgress;
  },
  handle_upload_progress() {
    if (this.uploadProgress.value == 100) {
      this.handle_upload_finish();
    }
  },
  handle_upload_finish () {
    this.pushEvent("save", {id: this.uploadId})
  },
  mounted() {
    this.init_upload_progress();
  },
  updated() {
    console.log(1)
    this.handle_upload_progress();
  }
};
