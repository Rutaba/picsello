export default {
  mounted() {
    const { el } = this

    this.el.addEventListener('click', () => {
      const elements = getElements(el)
      elements.forEach((e, i) => {
        if (e.classList.contains('hidden')) {
          e.classList.remove('hidden')
        }else{
          e.classList.add('hidden')
        }
      })
    })
  }
}

function getElements(e) {
  const parent = '.' + e.getAttribute('parent-class')
  const parent_element = document.querySelector(parent);
  const target_class = '.' + e.getAttribute('target-class')
  return parent_element.querySelectorAll(target_class)
}

