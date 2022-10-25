import Tribute from "tributejs";

// Initialize tribute (@mention engine)
var tribute = new Tribute({
    values: function (text, cb) {
        remoteSearch(text, users => cb(users));
    },
    lookup: 'username',
    fillAttr: 'username',
    noMatchTemplate: "<div class='px-1'>No matches found!</div>",
    menuItemTemplate: function (item) {
        return "@" + item.string;
    },
});

function initializeTribute() {
    tribute.attach(document.querySelectorAll(".mentionable:not([data-tribute])"));
}

function remoteSearch(text, cb) {
    var url = "/spi/users";
    xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function () {
        if (xhr.readyState === 4) {
            if (xhr.status === 200) {
                var data = JSON.parse(xhr.responseText);
                console.log(data.results);
                cb(data.results);
            } else if (xhr.status === 403) {
                cb([]);
            }
        }
    };
    xhr.open("GET", url + "?query=" + text, true);
    xhr.send();
}

export function setupMentions() {
    document.addEventListener("phx:update", initializeTribute);
    document.addEventListener("load", initializeTribute);
}