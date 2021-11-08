import {Modal} from './shared';

export default {
    mounted() {
        const {el} = this;
        let dropArea = document.getElementById(el.id);
        let content = dropArea.closest('.dragDrop__wrapper');

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

        this.modal = Modal({onClose, onOpen, el, isClosed});
    },

    destroyed() {
        this.modal.destroyed();
    },

    updated() {
        this.modal.updated();
        let errorElements = document.querySelectorAll('.photoUploadingIsFailed');
        let errorElementsArray = Array.from(errorElements);

        if(errorElementsArray.length){
            errorElementsArray.forEach(el=> document.getElementById(el.dataset.name).querySelector('progress').style.display = 'none');
        }
    },
};

