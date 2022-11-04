function onKeydown(event) {
    if ((event.ctrlKey || event.metaKey) && event.keyCode == 13 && event.target.closest) {
        let form = event.target.closest("form");
        if (form !== null) {
            if(!form.classList.contains("phx-loading")) {
                form.dispatchEvent(new Event("submit", {bubbles: true, cancelable: true}));
                event.preventDefault();
                event.stopPropagation();
            }
        }
    }
}

export function initialize() {
    document.addEventListener("keydown", onKeydown);
}

