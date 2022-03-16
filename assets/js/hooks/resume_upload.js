export default {
  mounted() {
    this.handleEvent('resume_upload', ({id}) => {
      console.log(id)
      const dropTarget = document.getElementById(id);
      console.log(dropTarget)
      dropTarget.dispatchEvent(new Event('input', { bubbles: true }));
    });
  }
}