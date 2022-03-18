export default {
  mounted() {
    console.log("asd");
    let scrollpos = window.scrollY
    const header = document.querySelector("#page-scroll")
    const header_height = header.offsetHeight

    const add_class_on_scroll = () => header.classList.add("scroll-shadow")
    const remove_class_on_scroll = () => header.classList.remove("scroll-shadow")

    window.addEventListener('scroll', function() {
      scrollpos = window.scrollY;

      if (scrollpos >= 13) { add_class_on_scroll() }
      else { remove_class_on_scroll() }

      console.log(scrollpos)
    })
  },
};
