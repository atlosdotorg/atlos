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

mapboxgl.accessToken = 'pk.eyJ1IjoibWlsZXNtY2MiLCJhIjoiY2t6ZzdzZmY0MDRobjJvbXBydWVmaXBpNSJ9.-aHM8bjOOsSrGI0VvZenAQ';

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, { params: { _csrf_token: csrfToken } })

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

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

        let x = new TomSelect(`#${s.id}`, {
            maxOptions: null,
            placeholder: prompt,
            allowEmptyOption: true,
            onItemAdd(_a, _b) {
                setTimeout(() => x.control_input.value = "", 1);
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

        const marker = new mapboxgl.Marker()
            .setLngLat([lon, lat])
            .addTo(map);

        console.log(map);
    })
}

window.toggleClass = (id, classname) => {
    let elem = document.getElementById(id);
    elem.classList.toggle(classname);
}

document.addEventListener("phx:update", initializeMultiSelects);
document.addEventListener("load", initializeMultiSelects);

document.addEventListener("phx:update", initializeMaps);
document.addEventListener("load", initializeMaps);
