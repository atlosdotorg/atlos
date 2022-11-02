function onKeydown(event) {
    if ((event.ctrlKey || event.metaKey) && event.keyCode == 13) {
        if (document.activeElement.form) {
            let form = document.activeElement.form;
            if(!form.classList.contains("phx-loading") && !form.disabled) {
                console.log("Submitting!");
                form.dispatchEvent(new Event("submit", {bubbles: true, cancelable: true}));
            }
        }
    }
}

export function initialize() {
    document.addEventListener("keydown", onKeydown);
}

