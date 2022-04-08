export default {
  mounted() {
    this.handleEvent('resume_upload', ({id}) => {
      const el = document.getElementById('dragDrop-form');
      const dropTarget = el.querySelector('.dragDropInput');
      dropTarget.dispatchEvent(new Event('input', { bubbles: true }));
    });
  }
}
