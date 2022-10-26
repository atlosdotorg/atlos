import Tagify from '@yaireo/tagify'
import "@yaireo/tagify/dist/tagify.css"

async function searchForUser(prefix) {
    let results = (await (await fetch("/spi/users?" + new URLSearchParams({
        query: prefix
    }))).json())["results"].map(e => e.username);

    return results;
}

function initialize() {
    document.querySelectorAll("textarea[interactive]").forEach(input => {
        if (input.parentElement.querySelector("tags")) {
            return;
        }

        let tagify = new Tagify(input, {
            mode: 'mix',
            pattern: /@/,
            tagTextProp: 'text',
            whitelist: [],
            originalInputValueFormat: v => v.prefix + v.value,
            mapValueTo: v => {
                return v;
            },
            enforceWhitelist: true,
            dropdown: {
                enabled: 1,
                position: 'text',
                mapValueTo: 'text',
                highlightFirst: true
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
                            <span class="${_s.classNames.tagText}">${tagData.prefix}${tagData[_s.tagTextProp] || tagData.value}</span>
                        </div>
                    </tag>`
                },
            }
        })


        // A good place to pull server suggestion list accoring to the prefix/value
        tagify.on('input', async function (e) {
            var prefix = e.detail.prefix;

            if (prefix) {
                tagify.loading = true;
                let results = await searchForUser(e.detail.value);
                tagify.loading = false;
                tagify.whitelist = results;

                if (results.length > 0 && e.detail.value.length > 0) {
                    tagify.dropdown.show();
                    console.log(tagify);
                }
            }
        })
    })
}

export function setupMentions() {
    document.addEventListener("phx:update", initialize);
    document.addEventListener("load", initialize);
}