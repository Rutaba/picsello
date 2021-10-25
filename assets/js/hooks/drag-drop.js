import { Modal } from './shared';

export default {
    mounted() {
        const { el } = this;
        let content = document.getElementById('dragDrop__wrapper');
        let dropArea = document.getElementById(el.id);
        [("dragenter", "dragover", "dragleave", "drop")].forEach((eventName) => {
            dropArea.addEventListener(eventName, preventDefaults, false);
        });
        function preventDefaults(e) {
            e.preventDefault();
        }
        ["dragenter", "dragover"].forEach((eventName) => {
            dropArea.addEventListener(eventName, highlight, false);
        });

        ["dragleave", "drop"].forEach((eventName) => {
            dropArea.addEventListener(eventName, unhighlight, false);
        });
        function highlight(e) {
            dropArea.classList.add("active");
        }

        function unhighlight(e) {
            dropArea.classList.remove("active");
        }

        function onClose() {
            content.classList.add('hidden');
        }

        function onOpen() {
            content.classList.remove('hidden');
        }

        const isClosed = () => content.classList.contains('hidden');

        this.modal = Modal({ onClose, onOpen, el, isClosed });
    },

    destroyed() {
        this.modal.destroyed();
    },

    updated() {
        this.modal.updated();
    },
};

