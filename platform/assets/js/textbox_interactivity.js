import Tagify from '@yaireo/tagify'
import "@yaireo/tagify/dist/tagify.css"

async function searchForUser(prefix) {
    let results = (await (await fetch("/spi/users?" + new URLSearchParams({
        query: prefix,
        project_id: document.querySelector("meta[name='active_project_id']").getAttribute("content"),
    }))).json())["results"].map(e => "@" + e.username);

    return results;
}

function truncateString(str, num) {
    if (str.length > num) {
        return str.slice(0, num) + "...";
    } else {
        return str;
    }
}

function iconURL(url) {
    try {
        let u = new URL(url);
        return `https://s2.googleusercontent.com/s2/favicons?domain=${u.hostname}&sz=64`;
    } catch {
        return "";
    }
}

function initialize() {
    document.querySelectorAll("textarea[interactive-urls]").forEach(input => {
        if (input.parentElement.querySelector("tags")) {
            return;
        }

        let feedbackElem = document.getElementById(input.getAttribute("data-feedback"));

        let tagify = new Tagify(input, {
            pasteAsTags: true,
            delimiters: ",|\n|\r",
            keepInvalidTags: true,
            templates: {
                tag(tagData, { settings: _s }) {
                    let text = tagData[_s.tagTextProp] || tagData.value;
                    return `<tag title="${(tagData.title || tagData.value)}"
                                contenteditable='false'
                                spellcheck='false'
                                tabIndex="${_s.a11y.focusableTags ? 0 : -1}"
                                class="${_s.classNames.tag} ${tagData.class}"
                                ${this.getAttributes(tagData)}>
                        <div>
                            <span class="${_s.classNames.tagText}">${text}</span>
                        </div>
                    </tag>`
                },
            }
        });

        tagify.on("change", event => {
            feedbackElem.value = JSON.stringify(event.detail.tagify.value.map(x => x.value));
            feedbackElem.dispatchEvent(new Event("input", { bubbles: true }));
        })
    })

    document.querySelectorAll("textarea[interactive-tags]").forEach(input => {
        if (input.parentElement.querySelector("tags")) {
            return;
        }

        let feedbackElem = document.getElementById(input.getAttribute("data-feedback"));
        let value = JSON.parse(feedbackElem.value || "[]");
        console.log(value)

        let tagify = new Tagify(input, {
            pasteAsTags: true,
            delimiters: ",|\n|\r",
            keepInvalidTags: true,
            templates: {
                tag(tagData, { settings: _s }) {
                    let text = tagData[_s.tagTextProp] || tagData.value;
                    return `<tag title="${(tagData.title || tagData.value)}"
                                contenteditable='false'
                                spellcheck='false'
                                tabIndex="${_s.a11y.focusableTags ? 0 : -1}"
                                class="${_s.classNames.tag} ${tagData.class}"
                                ${this.getAttributes(tagData)}>
                        <div>
                            <span class="${_s.classNames.tagText}">${text}</span>
                        </div>
                    </tag>`
                },
            }
        });

        tagify.addTags(value);

        tagify.on("change", event => {
            feedbackElem.value = JSON.stringify(event.detail.tagify.value.map(x => x.value));
            feedbackElem.dispatchEvent(new Event("input", { bubbles: true }));
        })
    })

    document.querySelectorAll("textarea[interactive-mentions]").forEach(input => {
        let feedbackElem = document.getElementById(input.getAttribute("data-feedback"));

        if (input.parentElement.querySelector("tags")) {
            return;
        }

        // Initialize whitelist with tags currently in the comment (necessary for proper form recovery)
        let whitelist = [...(feedbackElem.value || "").matchAll("@[A-Za-z0-9]+")].map(x => x[0]);

        let tagify = new Tagify(input, {
            mode: 'mix',
            pattern: /@/,
            tagTextProp: 'text',
            whitelist,
            editTags: false,
            duplicates: true,
            originalInputValueFormat: v => v.value,
            mapValueTo: v => {
                return v;
            },
            enforceWhitelist: true,
            dropdown: {
                enabled: 1,
                position: 'text',
                mapValueTo: 'text',
                highlightFirst: true,
            },
            templates: {
                tag(tagData, { settings: _s }) {
                    return `<tag title="${(tagData.title || tagData.value)}"
                                contenteditable='false'
                                spellcheck='false'
                                tabIndex="${_s.a11y.focusableTags ? 0 : -1}"
                                class="${_s.classNames.tag} font-medium"
                                ${this.getAttributes(tagData)}>
                        <div>
                            <span class="${_s.classNames.tagText}">${tagData[_s.tagTextProp] || tagData.value}</span>
                        </div>
                    </tag>`
                },
            }
        })


        // A good place to pull server suggestion list accoring to the prefix/value
        tagify.on('input', async function (e) {
            var prefix = e.detail.prefix;

            if (prefix) {
                if (e.detail.value.length > 0) {
                    let results = await searchForUser(e.detail.value);
                    tagify.whitelist = results;
                    tagify.dropdown.show.call(tagify, e.detail.value);
                }
            }
        });

        tagify.on("change", _event => {
            feedbackElem.value = input.value;
            feedbackElem.dispatchEvent(new Event("input", { bubbles: true }));
        })
    })
}

export function setupTextboxInteractivity() {
    document.addEventListener("phx:update", initialize);
    document.addEventListener("load", initialize);
}