export default {
  mounted() {
    this.el.addEventListener("click", e => {
      let html = document.querySelector('#galleryPasswordInput');
      
      html.select();
      html.setSelectionRange(0, 99999); /* For mobile devices */

      /* Copy the text inside the text field */
      navigator.clipboard.writeText(html.value);
    })
  },
};

