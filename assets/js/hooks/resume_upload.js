export default {
  mounted() {
    this.handleEvent('resume_upload', ({id}) => {
      const dropTarget = document.getElementById(id);
      dropTarget.dispatchEvent(new Event('input', { bubbles: true }));
    });
  }
}