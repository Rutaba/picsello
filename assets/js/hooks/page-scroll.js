export default {
  mounted() {
    let scrollPos = window.scrollY
    const header = document.querySelector("#page-scroll")

    const addClassOnScroll = () => header.classList.add("scroll-shadow")
    const removeClassOnScroll = () => header.classList.remove("scroll-shadow")

    window.addEventListener('scroll', function() {
      scrollPos = window.scrollY;

      if (scrollpos >= 13) {
        addClassOnScroll()
      } else {
        removeClassOnScroll()
      }
    })
  },
};
