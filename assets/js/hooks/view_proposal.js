export default {
    mounted() {
      this.handleEvent('ViewClientLink', ({ url: url }) => {
          window.open(url, '_blank');
        });
    },
  };