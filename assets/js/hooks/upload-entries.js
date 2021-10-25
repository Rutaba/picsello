export default {
  init_upload_progress() {
    const [uploadProgress] = document.getElementsByTagName("progress");
    
    this.uploadId = this.el.id;
    this.uploadProgress = uploadProgress;
    return
  },
  handle_upload_progress() {
    if (this.uploadProgress.value == 100) {
      console.log(this.uploadProgress.value)
      this.handle_upload_finish();
    }
  },
  handle_upload_finish () {
    this.pushEvent("111", {id: this.uploadId})
  },
  init() {
    this.entries = [] 
  },
  handle_entries_list () {
    const entries = this.el.getElementsByTagName("div");
    console.log(entries);
    console.log(this.entries);
  },
  mounted() {
    this.init();
  },
  beforeUpdate() {
    this.handle_entries_list();
  },
  updated() {
    //const entries = 
    //this.handle_upload_progress();
    //console.log(this.entries)
  }
};
