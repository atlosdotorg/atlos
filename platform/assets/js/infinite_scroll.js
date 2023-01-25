export const InfiniteScroll = {
    page() {
        return this.el.dataset.page;
    },
    loadMore(entries) {
        const target = entries[0];
        if (target.isIntersecting && this.pending == this.page()) {
            this.pending = this.page() + 1;
            let target = this.el.getAttribute("phx-target");
            if (target) {
                this.pushEventTo(target, "load_more", {});
            } else {
                this.pushEvent("load_more", {});
            }
        }
    },
    mounted() {
        this.pending = this.page();
        this.observer = new IntersectionObserver(
            (entries) => this.loadMore(entries),
            {
                root: null, // window by default
                rootMargin: "0px",
                threshold: 1.0,
            }
        );
        this.observer.observe(this.el);
    },
    beforeDestroy() {
        this.observer.unobserve(this.el);
    },
    updated() {
        this.pending = this.page();
    },
};