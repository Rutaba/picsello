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

        function handleFallbackDirectoryPicker() {
            return new Promise((resolve) => {
                const input = document.createElement('input');
                input.type = 'file';
                input.webkitdirectory = true;

                input.addEventListener('change', (event) => resolve(event));

                if ('showPicker' in HTMLInputElement.prototype) {
                    input.showPicker();
                } else {
                    input.click();
                }
            });
        }

        let files = [];
        let subFolders = []
        let folderName = '';

        document.querySelector("#folder-upload").addEventListener('click', async () => {
            // Check if showDirectoryPicker is supported
            // This methodology can be removed in the future when the showDirectoryPicker
            // is supported by all browsers
            const supportsFileSystemAccess =
                "showDirectoryPicker" in window &&
                (() => {
                    try {
                        return window.self === window.top;
                    } catch {
                        return false;
                    }
                })();

            // if showDirectoryPicker is supported by browser
            if (supportsFileSystemAccess) {
                files = [];
                subFolders = []
                folderName = '';

                const types = [{ description: 'Directories', accept: { 'directory': 'application/x-directory' } }];
                const directoryPicker = await window.showDirectoryPicker({ types: types });
                folderName = directoryPicker.name;

                for await (const [key, value] of directoryPicker.entries()) {
                    if (value.kind == 'directory') {
                        let directoryName = `${uuidv4()}-dsp-${value.name}`;
                        subFolders.push(directoryName);

                        for await (const [key2, value2] of value.entries()) {
                            if (value2.kind == 'file') {
                                const fileData = await value2.getFile();
                                const file = renameFile(fileData, `${directoryName}-fsp-${fileData.name}`);
                                files.push(file);
                            }
                        }
                    }
                    else {
                        const fileData = await value.getFile();
                        files.push(fileData);
                    }
                }
            } else {
                // Going on conventional way of inputting directories
                files = [];
                subFolders = []
                folderName = '';

                const directoryPicker = await handleFallbackDirectoryPicker();

                for (const file of directoryPicker.target.files) {
                    const fileNew = null;
                    const filename = file.webkitRelativePath.split('/');

                    folderName = folderName === '' ? filename[0] : folderName;

                    // incase file exists in a subfolder
                    if (filename.length == 3) {
                        let directoryName = `${uuidv4()}-dsp-${filename[1]}`
                        const exists = subFolders.find(x => x.includes(`-dsp-${filename[1]}`))

                        if (!exists) subFolders.push(directoryName);

                        fileNew = renameFile(file, `${exists || directoryName}-fsp-${filename[2]}`);
                    }
                    // incase file exists in the main folder
                    if (filename.length == 2) {
                        fileNew = renameFile(file, `${filename[1]}`);
                    }
                    files.push(fileNew);
                }
            }
            this.pushEvent("folder-information", { 'folder': folderName, 'sub_folders': subFolders })
        });

        this.handleEvent('upload-photos', ({ include_subfolders: includeSubFolders }) => {
            if (!includeSubFolders) { files = rejectFilesOfSubFolders(files, subFolders) }
            files = files.filter((value, i, arr) => { return validateFileType(value) })

            if (files != []) { this.uploadTo(uploadEl, 'photo', files) }
        })
    },
}