import {Modal} from './shared';

export default {
    mounted() {
        const {el} = this;
        const dropArea = document.getElementById(el.id);
        const content = dropArea.closest('.dragDrop__wrapper');

        const preventDefaults = (e) => e.preventDefault();
        const highlight = () => dropArea.classList.add("active");
        const unhighlight = () => dropArea.classList.remove("active");
        const onClose = () => content.classList.add('hidden');
        const onOpen = () => content.classList.remove('hidden');
        const isClosed = () => content.classList.contains('hidden');

        [("dragenter", "dragover", "dragleave", "drop")].forEach((eventName) => {
            dropArea.addEventListener(eventName, preventDefaults, false);
        });

        ["dragenter", "dragover"].forEach((eventName) => {
            dropArea.addEventListener(eventName, highlight, false);
        });

        ["dragleave", "drop"].forEach((eventName) => {
            dropArea.addEventListener(eventName, unhighlight, false);
        });

        this.modal = Modal({onClose, onOpen, el, isClosed});
    },

    destroyed() {
        this.modal.destroyed();
    },

    updated() {
        this.modal.updated();

        const errorElements = document.querySelectorAll('.photoUploadingIsFailed');
        const errorElementsArray = Array.from(errorElements);

        if (errorElementsArray.length) {
            errorElementsArray.forEach(el => document.getElementById(el.dataset.name)
                .querySelector('progress').style.display = 'none');
        }
    },
};

