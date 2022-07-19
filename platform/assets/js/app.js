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
import TomSelect from "../node_modules/tom-select/dist/js/tom-select.complete"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
import mapboxgl from 'mapbox-gl'
import Alpine from 'alpinejs'

mapboxgl.accessToken = 'pk.eyJ1IjoibWlsZXNtY2MiLCJhIjoiY2t6ZzdzZmY0MDRobjJvbXBydWVmaXBpNSJ9.-aHM8bjOOsSrGI0VvZenAQ';

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
    dom: {
        onBeforeElUpdated(from, to) {
            if (from._x_dataStack) {
                window.Alpine.clone(from, to);
            }
        },
    },
    params: { _csrf_token: csrfToken }
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

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

function initializeMultiSelects() {
    // Make multi-selects interactive
    document.querySelectorAll("select:not(.ts-ignore *)").forEach(s => {
        if (s.tomselect) {
            return;
        }

        let prompt = "Select...";
        if (s.hasAttribute("multiple")) {
            prompt = "Select all that apply..."
        }
        let descriptions = JSON.parse(s.getAttribute("data-descriptions")) || {};

        let x = new TomSelect(`#${s.id}`, {
            maxOptions: null,
            placeholder: prompt,
            allowEmptyOption: true,
            hideSelected: false,
            hidePlaceholder: true,
            create: s.hasAttribute("data-allow-user-defined-options"),
            closeAfterSelect: !s.hasAttribute("multiple"),
            onItemAdd(_a, _b) {
                setTimeout(() => x.control_input.value = "", 1);
            },
            plugins: s.hasAttribute("multiple") ? [
                "remove_button", "checkbox_options"
            ] : [],
            render: {
                option: function (data, escape) {
                    let desc = descriptions[data.value] || "";
                    if (desc.length != 0) {
                        desc = "— " + desc;
                    }
                    return '<div class="lg:flex"><div><span>' + escape(data.text) + '</span><span class="text-gray-400">&nbsp;' + escape(desc) + '</span></div></div>';
                },
                item: function (data, escape) {
                    return '<div>' + escape(data.text) + '</div>';
                }
            }
        });
        x.control_input.setAttribute("phx-debounce", "blur");
    });
}

function initializeMaps() {
    document.querySelectorAll("map-pin").forEach(s => {
        if (s.classList.contains("mapboxgl-map")) {
            return;
        }

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

        console.log(map);
    });

    document.querySelectorAll("map-events").forEach(s => {
        if (s.classList.contains("mapboxgl-map")) {
            return;
        }

        let lon = parseFloat(s.getAttribute("lon"));
        let lat = parseFloat(s.getAttribute("lat"));

        let map = new mapboxgl.Map({
            container: s.id,
            style: 'mapbox://styles/mapbox/light-v10',
            center: [lon, lat],
            zoom: 6
        });

        map.on('load', function () {
            map.resize();
        });

        window.addEventListener("resize", () => {
            map.resize();
        });

        let data = JSON.parse(s.getAttribute("data"));
        for (let incident of data) {
            let popup = new mapboxgl.Popup({ offset: 30, closeButton: false }).setHTML(`
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
            `).setMaxWidth("600px");
            new mapboxgl.Marker({ color: "#60a5fa90" })
                .setLngLat([incident.lon, incident.lat])
                .setPopup(popup)
                .addTo(map);
        }
    });
}

window.toggleClass = (id, classname) => {
    let elem = document.getElementById(id);
    elem.classList.toggle(classname);
}

document.addEventListener("phx:update", initializeMultiSelects);
document.addEventListener("load", initializeMultiSelects);

document.addEventListener("phx:update", initializeMaps);
document.addEventListener("load", initializeMaps);
