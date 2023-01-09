export default {
  mounted() {
    const node = document.getElementsByClassName('flash');
    const firstNode = node[0];
    
    if (node.length > 1) {
      firstNode.classList.add('hidden');
    }
    setTimeout(() => {
      this.pushEvent('lv:clear-flash', { key: this.el.dataset.phxValueKey });
    }, 5000);
  },
};
