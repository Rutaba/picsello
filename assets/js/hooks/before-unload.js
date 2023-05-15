
export default {
    mounted() {
      const { el } = this;
      
      this.beforeUnload = function(e) {
        if (el.dataset.isSave === 'false') {
          e.preventDefault()
          e.returnValue = 'You have unsaved changes. Are you sure you want to leave?'
        }
      }
      window.addEventListener('beforeunload', this.beforeUnload, true)
    }
  };