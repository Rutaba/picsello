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

const SizeStyle = Quill.import('attributors/style/size');
SizeStyle.whitelist = ['10px', '18px', '32px'];
Quill.register(SizeStyle, true);

export default {
  mounted() {
    const editorEl = this.el.querySelector('#editor');
    const {
      placeholder = 'Compose message...',
      textFieldName,
      htmlFieldName,
      enableSize,
    } = this.el.dataset;
    const textInput = textFieldName
      ? this.el.querySelector(`input[name="${textFieldName}"]`)
      : null;
    const htmlInput = htmlFieldName
      ? this.el.querySelector(`input[name="${htmlFieldName}"]`)
      : null;

    let toolbarOptions = [
      'bold',
      'italic',
      'underline',
      { list: 'bullet' },
      { list: 'ordered' },
      'link',
    ];

    if (enableSize !== undefined) {
      toolbarOptions = [
        { size: ['10px', false, '18px', '32px'] },
        ...toolbarOptions,
      ];
    }

    const quill = new Quill(editorEl, {
      modules: { toolbar: toolbarOptions },
      placeholder,
      theme: 'snow',
    });

    function textChange() {
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
    }

    quill.on('text-change', textChange);

    this.handleEvent('quill:update', ({ html }) => {
      quill.root.innerHTML = html;
      textChange();
    });

    quill.root.innerHTML = htmlInput.value;
  },
};

export const ClearQuillInput = {
  mounted() {
    this.el.addEventListener('click', () => {
      const element = document.querySelector('.ql-editor');
      element.innerHTML = '';
      element.classList.add('ql-blank');
    });
  },
};
