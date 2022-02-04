import Quill from 'quill';

const Link = Quill.import('formats/link');

class CustomLink extends Link {
  static create(value) {
    let node = super.create(value);
    value = this.sanitize(value);
    if (!value.startsWith('http')) {
      value = `https://${value}`;
    }
    node.setAttribute('href', value);
    return node;
  }
}

Quill.register(CustomLink, true);

export default {
  mounted() {
    const editorEl = this.el.querySelector('#editor');
    const {
      placeholder = 'Compose message...',
      textFieldName,
      htmlFieldName,
    } = this.el.dataset;
    const textInput = textFieldName
      ? this.el.querySelector(`input[name="${textFieldName}"]`)
      : null;
    const htmlInput = htmlFieldName
      ? this.el.querySelector(`input[name="${htmlFieldName}"]`)
      : null;
    const quill = new Quill(editorEl, {
      modules: { toolbar: '#toolbar' },
      placeholder,
      theme: 'snow',
    });
    quill.on('text-change', () => {
      htmlInput.value = quill.root.innerHTML;
      const text = quill.getText();

      if (text && text.trim().length === 0) {
        htmlInput.value = '';
      }
      htmlInput.dispatchEvent(new Event('input', { bubbles: true }));

      if (textInput) {
        textInput.value = text;
        textInput.dispatchEvent(new Event('input', { bubbles: true }));
      }
    });
    quill.root.innerHTML = htmlInput.value;
  },
};
