// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
import * as vega from "vega";
import "vega-lite"
import vegaEmbed from "vega-embed"
import TomSelect from "../node_modules/tom-select/dist/js/tom-select.complete"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
import mapboxgl from 'mapbox-gl'
import Alpine from 'alpinejs'
import tippy from 'tippy.js';
import Mark from 'mark.js';
import { InfiniteScroll } from "./infinite_scroll";
import { setupTextboxInteractivity } from "./textbox_interactivity";
import { initialize as initializeKeyboardFormSubmits } from "./keyboard_form_submit";
import { initialize as initializeFormUnloadWarning } from "./form_warnings";

mapboxgl.accessToken = 'pk.eyJ1IjoibWlsZXNtY2MiLCJhIjoiY2t6ZzdzZmY0MDRobjJvbXBydWVmaXBpNSJ9.-aHM8bjOOsSrGI0VvZenAQ';
mapboxgl.setRTLTextPlugin('https://api.mapbox.com/mapbox-gl-js/plugins/mapbox-gl-rtl-text/v0.2.3/mapbox-gl-rtl-text.js');

let Hooks = {};
Hooks.Modal = {
    mounted() {
        window.addEventListener("modal:close", (event) => {
            this.pushEventTo(event.detail.elem, "close_modal", {});
        })
    }
}
Hooks.ScrollToTop = {
    mounted() {
        this.el.addEventListener("click", e => {
            window.scrollToTop()
        })
    }
}
Hooks.InfiniteScroll = InfiniteScroll;

// Used by the pagination button to scroll back up to the top of the page.
window.scrollToTop = () => {
    for (let elem of document.querySelectorAll(".top-scroll-anchor")) {
        elem.scrollIntoView({ behavior: "smooth", block: "start", inline: "nearest" })
    }
    window.scrollTo(0, 0);
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
    dom: {
        onBeforeElUpdated(from, to) {
            if (from._x_dataStack) {
                window.Alpine.clone(from, to);
            }
            if (from._tippy) {
                from._tippy.destroy();
            }
            if(["DIALOG", "DETAILS"].indexOf(from.tagName) >= 0){
                Array.from(from.attributes).forEach(attr => {
                  to.setAttribute(attr.name, attr.value)
                })
              }
        },
    },
    params: { _csrf_token: csrfToken },
    hooks: Hooks,
    metadata: {
        keydown: (event, _element) => {
          return {
            ctrlKey: event.ctrlKey,
            metaKey: event.metaKey,
            shiftKey: event.shiftKey
          }
        }
    }
})

// Setup textboxes
setupTextboxInteractivity();

/**
 * https://stackoverflow.com/questions/494143/creating-a-new-dom-element-from-an-html-string-using-built-in-dom-methods-or-pro
 * 
 * @param {String} HTML representing a single element
 * @return {Element}
 */
function htmlToElement(html) {
    var template = document.createElement('template');
    html = html.trim(); // Never return a text node of whitespace as the result
    template.innerHTML = html;
    return template.content.firstChild;
}

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", () => topbar.show())
window.addEventListener("phx:page-loading-stop", () => topbar.hide())
window.addEventListener("atlos:updating", () => topbar.show())
window.addEventListener("phx:update", () => topbar.hide())
window.topbar = topbar;

// Setup Alpine
window.Alpine = Alpine
Alpine.start()

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

let lockIcon = `<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 m-px mb-1 inline" viewBox="0 0 20 20" fill="currentColor">
<path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd" />
</svg>`;

// Logic specifically for the <.popover> component
function initializePopovers() {
    document.querySelectorAll("[data-popover]").forEach(s => {
        if (s._tippy) {
            return;
        }
        tippy(s, {
            interactive: true,
            allowHTML: true,
            content: "",
            onShow(ref) {
                // Replace `dynamic` tags with their desired elements; this is to prevent things from being
                // loaded and rendered until we want to show the popover. We can't use <template>
                // tags because Phoenix won't update those.
                let content = ref.reference.querySelector("section[role=\"popover\"]");
                for (let elem of content.querySelectorAll("dynamic")) {
                    if (elem.hasAttribute("populated")) {
                        continue;
                    }
                    let newNode = document.createElement(elem.getAttribute("tag"));
                    for (let attr of elem.attributes) {
                        newNode.setAttribute(attr.name, attr.value);
                    }
                    elem.parentElement.appendChild(newNode)
                    elem.setAttribute("populated", "true");
                }
                ref.setContent(content.innerHTML);
            },
            theme: "light",
            delay: [250, 0],
            appendTo: document.querySelector("#tooltips")
        });
    })

    document.querySelectorAll("[data-tooltip]:not(.tooltip-initialized)").forEach(s => {
        if (s._tippy) {
            return;
        }

        tippy(s, {
            allowHTML: true,
            content: s.getAttribute("data-tooltip"),
            delay: [250, 0],
            appendTo: document.querySelector("#tooltips")
        });
    });
}

function triggerSubmitEvent(element) {
    element.dispatchEvent(new Event("submit", { bubbles: true }));
    topbar.show();
}
window.triggerSubmitEvent = triggerSubmitEvent;

function initializeSmartSelects() {
    // Make smart-selects interactive
    document.querySelectorAll("select:not(.ts-ignore *)").forEach(s => {
        if (s.tomselect) {
            return;
        }

        let prompt = "Select...";
        if (s.hasAttribute("multiple")) {
            prompt = "Select all that apply..."
        }
        let descriptions = JSON.parse(s.getAttribute("data-descriptions")) || {};
        let privileged = JSON.parse(s.getAttribute("data-privileged")) || [];
        let required = JSON.parse(s.getAttribute("data-required")) || [];

        let x = new TomSelect(`#${s.id}`, {
            maxOptions: null,
            placeholder: prompt,
            allowEmptyOption: true,
            hideSelected: false,
            hidePlaceholder: true,
            create: s.hasAttribute("data-allow-user-defined-options"),
            closeAfterSelect: !s.hasAttribute("multiple"),
            onItemAdd(_a, _b) {
                x.control_input.value = "";
            },
            plugins: s.hasAttribute("multiple") ? [
                "remove_button", "checkbox_options"
            ] : [],
            render: {
                option: function (data, escape) {
                    var desc = descriptions[data.value] || "";
                    if (desc.length != 0) {
                        desc = "— " + desc;
                    }
                    let requiresPrivilege = privileged.indexOf(data.text) >= 0;

                    let name = data.text == "[Unset]" ? "None" : data.text;

                    return '<div class="flex"><div><span>' + escape(name) + '</span><span class="text-gray-400">' + (requiresPrivilege ? lockIcon : '') + '&nbsp;' + escape(desc) + '</span></div></div>';
                },
            },
            onItemRemove(item) {
                if (required.indexOf(item) >= 0) {
                    alert(`You cannot remove ${item}; it is required.`);
                    // Add it back
                    x.addItem(item);
                }
            }
        });
        x.control_input.setAttribute("phx-debounce", "blur");
        x.control_input.setAttribute("phx-update", "ignore");
    });
}

// Load state from the URL fragment
function _getTotalURLHashState() {
    let hashState = {}
    try {
        hashState = JSON.parse(atob(window.location.hash.slice(1)) || "{}")
    } catch (e) {}
    return hashState
}

// Load state from the URL fragment, narrowed to a specific key
function getURLHashState(key) {
    return _getTotalURLHashState()[key] || {}
}

// Set state from the URL fragment
function setURLHashState(key, value) {
    let currentState = _getTotalURLHashState()
    currentState[key] = value
    window.location.hash = btoa(JSON.stringify(currentState))
}

function initializeMaps() {
    document.querySelectorAll("map-pin").forEach(s => {
        if (s.classList.contains("mapboxgl-map")) {
            return;
        }

        // TODO: support persisting map state in the URL fragment for map pins

        let lon = parseFloat(s.getAttribute("lon"));
        let lat = parseFloat(s.getAttribute("lat"));

        let map = new mapboxgl.Map({
            container: s.id,
            style: 'mapbox://styles/mapbox/satellite-streets-v11',
            center: [lon, lat],
            zoom: 14
        });

        new mapboxgl.Marker({ color: "#60a5fa" })
            .setLngLat([lon, lat])
            .addTo(map);
    });

    document.querySelectorAll("map-events").forEach(s => {
        let containerID = s.getAttribute("container-id");
        let persistedMapData = getURLHashState("map-" + containerID);

        let container = document.getElementById(containerID);
        if (container.classList.contains("mapboxgl-map") || container.classList.contains("map-initialized")) {
            return;
        }

        let defaultStyle = "mapbox://styles/milesmcc/cl89ukz84000514oebbd92bjm";

        let lon = persistedMapData["lon"] || parseFloat(s.getAttribute("lon"));
        let lat = persistedMapData["lat"] || parseFloat(s.getAttribute("lat"));

        let zoom = persistedMapData["zoom"] || parseFloat(s.getAttribute("zoom") || 6);
        let style = persistedMapData["style"] || s.getAttribute("style") || defaultStyle;

        if (!style.startsWith("mapbox://")) {
            style = defaultStyle;
        }

        let map = new mapboxgl.Map({
            container: containerID,
            style: style,
            center: [lon, lat],
            zoom: zoom
        });

        let updateMapHashState = () => {
            let center = map.getCenter();
            let zoom = map.getZoom();
            setURLHashState("map-" + containerID, {
                "lon": center.lng,
                "lat": center.lat,
                "zoom": zoom,
                "style": style
            });
        }

        let initializeLayers = () => {
            let elem = document.getElementById(s.id); // 's' might have changed, but its ID hasn't

            if (map.getLayer('incidents')) {
                map.removeLayer('incidents');
            }

            if (map.getSource('incidents')) {
                map.removeSource('incidents');
            }

            if (elem === null) {
                return; // The map has been removed from the page
            }

            let data = JSON.parse(elem.getAttribute("data"));

            let geojson = {
                "type": "geojson",
                "data": {
                    "type": "FeatureCollection",
                    "features": data.map(incident => {
                        return {
                            "type": "Feature",
                            "properties": {
                                "description": `
                                    <div class="fixed w-[350px] h-[190px] flex rounded-lg shadow-lg items-center bg-white justify-around -z-50">
                                        <div class="font-medium text-lg text-md p-4">
                                            <span class="animate-pulse">Loading...</span>
                                        </div>
                                    </div>
                                    <iframe
                                        src='/incidents/${incident.slug}/card'
                                        width="350px"
                                        height="190px"
                                    />
                                `,
                                "slug": incident.slug,
                                "color": incident.color
                            },
                            'geometry': {
                                'type': 'Point',
                                'coordinates': [incident.lon, incident.lat]
                            }
                        }
                    })
                }
            };

            map.addSource('incidents', geojson);

            map.addLayer({
                'id': 'incidents',
                'type': 'circle',
                'source': 'incidents',
                'paint': {
                    'circle-radius': 7,
                    'circle-color': ["get", "color"],
                    'circle-opacity': 0.6,
                },
            });

            // When a click event occurs on a feature in the places layer, open a popup at the
            // location of the feature, with description HTML from its properties.
            map.on('click', 'incidents', (e) => {
                // Copy coordinates array.
                const coordinates = e.features[0].geometry.coordinates.slice();
                const description = e.features[0].properties.description;

                // Ensure that if the map is zoomed out such that multiple
                // copies of the feature are visible, the popup appears
                // over the copy being pointed to.
                while (Math.abs(e.lngLat.lng - coordinates[0]) > 180) {
                    coordinates[0] += e.lngLat.lng > coordinates[0] ? 360 : -360;
                }

                new mapboxgl.Popup({ closeButton: false })
                    .setLngLat(coordinates)
                    .setHTML(description)
                    .setMaxWidth("600px")
                    .addTo(map);
            });

            // Change the cursor to a pointer when the mouse is over the incidents layer.
            map.on('mouseenter', 'incidents', () => {
                map.getCanvas().style.cursor = 'zoom-in';
            });

            // Change it back to a pointer when it leaves.
            map.on('mouseleave', 'incidents', () => {
                map.getCanvas().style.cursor = '';
            });

            // Update the persisted browser state on move
            map.on("move", () => {
                updateMapHashState()
            });
        };

        map.on("load", initializeLayers);
        document.addEventListener("phx:update", initializeLayers);

        document.addEventListener("resize", () => {
            map.resize();
        });

        // Setup layer toggle button
        container.parentElement.querySelector(".layer-toggle-button").addEventListener("click", () => {
            map.on("style.load", initializeLayers);
            if (map.getStyle().name == "Mapbox Satellite Streets") {
                style = 'mapbox://styles/milesmcc/cl89ukz84000514oebbd92bjm'
            } else {
                style = 'mapbox://styles/mapbox/satellite-streets-v11'
            }
            map.setStyle(style)
        })

        s.classList.add("map-initialized");
    });
}

let _searchHighlighter = null;
function applySearchHighlighting() {
    setTimeout(() => {
        if (_searchHighlighter !== null) {
            _searchHighlighter.unmark();
        }
        let query = new URLSearchParams(window.location.search).get("query");
        if (query !== null) {
            _searchHighlighter = new Mark(document.querySelectorAll(".search-highlighting"), { accuracy: "exactly" });
            _searchHighlighter.mark(query)
        }
    }, 25);
}

function applyVegaCharts() {
    document.querySelectorAll("[data-vega]").forEach((elem) => {
        let spec = JSON.parse(elem.getAttribute("data-vega"));
        vegaEmbed(elem, spec, { actions: false });
    })
}

function debounce(func, timeout = 25) {
    let timer;
    return (...args) => {
        clearTimeout(timer);
        timer = setTimeout(() => { func.apply(this, args); }, timeout);
    };
}

// Used to centralize modal closing logic. See Hooks.Modal for core logic.
window.closeModal = debounce(() => {
    // Find the target, if possible.
    let parentModal = document.querySelector("[data-is-modal]");

    if ((parentModal && !document.elementContainsActiveUnsavedForms(parentModal)) || confirm("Are you sure you want to exit? Any unsaved changes will be lost.")) {
        let event = new CustomEvent("modal:close", { detail: { elem: parentModal } });
        window.dispatchEvent(event);
    }
});

window.toggleClass = (id, classname) => {
    let elem = document.getElementById(id);
    elem.classList.toggle(classname);
}

// Scroll to the hash position, if possible
function scrollToHashPosition() {
    if (window.location.hash) {
        let elem = document.querySelector(window.location.hash);
        if (elem) {
            elem.scrollIntoView();
            elem.focus();
        }
    }
}
window.addEventListener("load", scrollToHashPosition);
document.addEventListener("hashchange", scrollToHashPosition);

document.addEventListener("phx:update", initializeSmartSelects);
window.addEventListener("load", initializeSmartSelects);

document.addEventListener("phx:update", initializeMaps);
window.addEventListener("load", initializeMaps);

document.addEventListener("phx:update", initializePopovers);
window.addEventListener("load", initializePopovers);

document.addEventListener("phx:update", applySearchHighlighting);
window.addEventListener("load", applySearchHighlighting);

document.addEventListener("phx:update", applyVegaCharts);
window.addEventListener("load", applyVegaCharts);

// Used to initialize Highlight
window.addEventListener("load", () => {
    let highlightElem = document.querySelector("#highlight-script");
    if (highlightElem != null) {
        window.H.init(highlightElem.getAttribute("data-code"), { privacySetting: "strict", environment: highlightElem.getAttribute("data-environment"), version: highlightElem.getAttribute("data-version") })
    }
});

initializeKeyboardFormSubmits();
initializeFormUnloadWarning();

// Used to set the clipboard when copying hash information
window.setClipboard = (text) => {
    const type = "text/plain";
    const blob = new Blob([text], { type });
    const data = [new ClipboardItem({ [type]: blob })];

    navigator.clipboard.write(data).then(
        () => { },
        () => {
            alert("Unable to write to your clipboard.")
        }
    );
}
