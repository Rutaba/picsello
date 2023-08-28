export default {
  mounted() {
    const { el } = this

    this.el.addEventListener('click', () => {
      const target_class = '.' + el.getAttribute('target-class')
      const elements = getElements(el, target_class)
      if (el.getAttribute('toggle-type') === 'selected-active') {
        elements.forEach((e, i) => {
          e.classList.add('hidden')
        })
        const targetElement = el.querySelector(target_class);
        if (targetElement) {
          targetElement.classList.remove('hidden');
        }
      } else {
        elements.forEach((e, i) => {
          e.classList.toggle('hidden'); // Toggle the 'hidden' class
        })
      }
    })
  }
}

function getElements(e, target_class) {
  const parent = '.' + e.getAttribute('parent-class')
  const parent_element = document.querySelector(parent);
  return parent_element.querySelectorAll(target_class)
}