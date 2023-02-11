import { v4 as uuidv4 } from 'uuid';
import 'regenerator-runtime/runtime';

export default {
    mounted() {
        let { uploadElId } = this.el.dataset
        const uploadEl = document.getElementById(uploadElId)
        const allowedTypes = ['.jpg', '.jpeg', '.png', 'image/jpeg', 'image/png']

        function renameFile(file, name) {
            try {
                return new File([file], name, { type: file.type })
            } catch (e) {
                var myBlob = new Blob([file], { type: file.type })
                myBlob.lastModified = new Date()
                myBlob.name = name

                return myBlob
            }
        };

        function validateFileType(file) { return allowedTypes.includes(file.type) }

        function rejectFilesOfSubFolders(files, subFolders) {
            return files.filter((file, i, arr) => {
                const isFileOfSubFolder = subFolders.find((value, i, array) => {
                    return file.name.includes(value);
                });

                return !isFileOfSubFolder
            })
        }

        let files
        let subFolders

        document.querySelector("#folder-upload").addEventListener('click', async () => {
            const types = [{ description: 'Directories', accept: { 'directory': 'application/x-directory' } }]
            const directoryPicker = await window.showDirectoryPicker({ types: types })
            files = []
            subFolders = []

            for await (const [key, value] of directoryPicker.entries()) {
                if (value.kind == 'directory') {
                    let directoryName = `${uuidv4()}-dsp-${value.name}`
                    subFolders.push(directoryName)

                    for await (const [key2, value2] of value.entries()) {
                        if (value2.kind == 'file') {
                            const fileData = await value2.getFile()
                            const file = renameFile(fileData, `${directoryName}-fsp-${fileData.name}`)
                            files.push(file)
                        }
                    }
                }
                else {
                    const fileData = await value.getFile()
                    files.push(fileData)
                }
            }
            this.pushEvent("folder-information", { 'folder': directoryPicker.name, 'sub_folders': subFolders })
        });

        this.handleEvent('upload-photos', ({ include_subfolders: includeSubFolders }) => {
            if (!includeSubFolders) { files = rejectFilesOfSubFolders(files, subFolders) }
            files = files.filter((value, i, arr) => { return validateFileType(value) })

            if (files != []) { this.uploadTo(uploadEl, 'photo', files) }
        })
    },
}