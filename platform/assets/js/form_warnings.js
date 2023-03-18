function onInput(event) {
    if (event.target.closest && event.target.closest("form") !== null) {
        let form = event.target.closest("form");
        if (!document._unsavedForms.includes(form) && !form.getAttribute("data-no-warn")) {
            document._unsavedForms.push(form);
        }
    }
}

function onSave(event) {
    if (event.target.closest && event.target.closest("form") !== null) {
        let form = event.target.closest("form")
        document._unsavedForms = document._unsavedForms.filter(f => f !== form);
    }
}

document.cancelFormEvent = function (event) {
    if (event.target.closest && event.target.closest("form") !== null) {
        let form = event.target.closest("form");
        document._unsavedForms = document._unsavedForms.filter(f => f !== form);
    }
}

document.elementContainsActiveUnsavedForms = (elem) => {
    return document._unsavedForms.some(form => elem.contains(form));
}

function hasActiveUnsavedForms() {
    return false;
    // We will enable this once we have a better way to detect if a form is dirty; right now this is unreliable
    // return document._unsavedForms.some(form => document.body.contains(form));
}

function onUnload(event) {
    // If they have unsaved changes, show a warning
    if (hasActiveUnsavedForms()) {
        event.preventDefault();
        let message = "You have unsaved changes. Are you sure you want to close the page?";
        return event.returnValue = message;
    }
}

export function initialize() {
    document._unsavedForms = [];
    window.addEventListener("beforeunload", onUnload);
    document.addEventListener("input", onInput);
    document.addEventListener("submit", onSave);
}
