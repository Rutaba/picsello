export default {
  mounted() {
    let scrollpos = window.scrollY
    const header = document.querySelector("#page-scroll")

    const add_class_on_scroll = () => header.classList.add("scroll-shadow")
    const remove_class_on_scroll = () => header.classList.remove("scroll-shadow")

    window.addEventListener('scroll', function() {
      scrollpos = window.scrollY;

      if (scrollpos >= 13) {
        add_class_on_scroll()
      } else {
        remove_class_on_scroll()
      }
    })
  },
};
