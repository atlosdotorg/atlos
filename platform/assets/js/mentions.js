import Tribute from "tributejs";

// Initialize tribute (@mention engine)
var tribute = new Tribute({
    values: [
        { key: "Phil Heartman", value: "pheartman" },
        { key: "Gordon Ramsey", value: "gramsey" }
    ],
    noMatchTemplate: "<div class='px-1'>No matches found!</div>"
});

function initializeTribute() {
    tribute.attach(document.querySelectorAll(".mentionable"));
}

export function setupMentions() {
    document.addEventListener("phx:update", initializeTribute);
    document.addEventListener("load", initializeTribute);
}