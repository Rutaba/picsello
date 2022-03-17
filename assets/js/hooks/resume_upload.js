export default {
  mounted() {
    this.handleEvent('resume_upload', ({id}) => {
      console.log(id)
      const el = document.getElementById('dragDrop-form');
      const dropTarget = el.querySelector('.dragDropInput');
      console.log(el)
      console.log(dropTarget)
      dropTarget.dispatchEvent(new Event('input', { bubbles: true }));
    });
  }
}
