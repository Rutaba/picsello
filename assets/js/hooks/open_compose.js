export default {
    mounted() {
      const element = document.getElementById("open-compose");
      if (element) {
        element.addEventListener("click", () => {
          this.pushEvent('open_compose', {});
        });
      }
    }
  };