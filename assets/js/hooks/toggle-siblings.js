import { Modal } from './shared';

export default {
  mounted() {
    const { el } = this;
    // const attr = '.' + el.getAttribute('target-class');
    // const content = el.querySelector(attr);
    let siblings = getSiblings(el)
    
    function onClose() {
      siblings.forEach((e, i) => {
        if (e.classList.contains('hidden')) {
          e.classList.remove('hidden');
        }else{
          e.classList.add('hidden');
        }
      });
    }

    const isClosed = () => el.classList.add('hidden');

    this.modal = Modal({ el, onClose, isClosed });
  },

  destroyed() {
    this.modal.destroyed();
  },

  updated() {
    this.modal.updated();
  },
};

function getSiblings(e) {
  let siblings = []; 
  
  if(!e.parentNode) {
      return siblings;
  }
  
  let sibling  = e.parentNode.firstChild;
  
  while (sibling) {
      if (sibling.nodeType === 1 && sibling !== e) {
          siblings.push(sibling);
      }
      sibling = sibling.nextSibling;
  }
  return siblings;
};
