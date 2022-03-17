export default {
  mounted() {
    const { el } = this
  
    this.el.addEventListener('click', () => {
      const classes = getClasses(el)
      const elements = el.closest(classes[0]).querySelectorAll(classes[1])
      elements.forEach((e, i) => {
        e.classList.add('hidden')
      })
      const selector = el.querySelector(classes[1])
      console.log(el)
      selector.classList.remove('hidden')
      console.log(selector)
    })
  }
}

function getClasses(e) {
  const parent = '.' + e.getAttribute('parent-class')
  console.log(parent)
  console.log(e.closest(parent))
  const target = '.' + e.getAttribute('target-class')
  return [parent, target]
}

