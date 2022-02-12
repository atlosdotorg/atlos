import Head from 'next/head'
import mapboxgl from 'mapbox-gl';
import { useState, useEffect } from 'react';

mapboxgl.accessToken = 'pk.eyJ1IjoibWlsZXNtY2MiLCJhIjoiY2t6ZzdzZmY0MDRobjJvbXBydWVmaXBpNSJ9.-aHM8bjOOsSrGI0VvZenAQ';

function easing(t) {
  return t * (2 - t);
}

export default function Home() {
  const [pageIsMounted, setPageIsMounted] = useState(false)

  useEffect(() => {
    setPageIsMounted(true)
    const map = new mapboxgl.Map({
      container: 'map', // container ID
      style: 'mapbox://styles/milesmcc/ckzj5rkva001c15p77j25ox5l', // style URL
      center: [32.1456235, 48.518858], // starting position [lng, lat]
      zoom: 9, // starting zoom
      pitch: 60,
      interactive: false,
    });
    map.on("load", () => {
      setInterval(() => {
        map.panBy([3, -3], {
          easing: easing
        });
      }, 100);
    });
  }, []);

  return (
    <div className='min-h-full'>
      <Head>
        <title>Atlos</title>
        <meta name="description" content="Atlos is a non-profit collaborative mapping platform to help OSINT researchers analyze conflict." />
        <link rel="icon" href="/icon.svg" />
      </Head>

      <main>
        <div className="w-full h-full -z-1">
          <div id="map" className="absolute w-full h-full top-0 left-0 bg-zinc-700 -z-1 max-h-screen overflow-hidden"></div>
        </div>
        <section className='z-10 fixed bottom-0 mx-auto p-6 pt-12 md:m-12 lg:m-36 md:max-w-md'>
          <p className="heading text-6xl md:text-8xl text-white">Atlos</p>
          <p className="text-lg md:text-2xl text-white mt-6">
            We're building a non-profit collaborative mapping platform to help OSINT researchers analyze conflict. Coming soon.
          </p>
          <p className="text-gray-200 mt-6">
            <a href="mailto:contact@atlos.org">contact@atlos.org &rarr;</a>
          </p>
        </section>
      </main>
    </div>
  )
}
