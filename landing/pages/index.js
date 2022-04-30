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
      style: 'mapbox://styles/milesmcc/cl2mejeca000d14p2wg8hm1eo', // style URL
      center: [36.1457427, 49.9947277], // starting position [lng, lat]
      zoom: 9, // starting zoom
      pitch: 60,
      interactive: false,
    });
    map.on("load", () => {
      setInterval(() => {
        map.panBy([1, -1], {
          easing: easing
        });
      }, 200);
    });
  }, []);

  return (
    <div className='min-h-full'>
      <Head>
        <title>Atlos</title>
        <meta name="description" content="The open source platform for visual investigations" />
        <link rel="icon" href="/icon.svg" />
      </Head>

      <main>
        <div className="w-full h-full -z-1">
          <div id="map" className="absolute w-full h-full top-0 left-0 bg-stone-700 -z-1 max-h-screen overflow-hidden"></div>
        </div>
        <section className='z-10 fixed flex flex-col space-y-6 top-0 mx-auto p-6 md:m-12 lg:m-36 md:max-w-lg'>
          <p className='text-5xl'>
            <span class="bg-white rounded-sm font-mono text-slate-900 py-1 px-2 font-bold">ATLOS</span>
          </p>
          <p className="text-2xl font-semibold md:text-3xl text-white pt-2">
            The open source platform for visual investigations
          </p>
          <div className='text-white text-md flex flex-col space-y-3'>
            <p>
              Geolocate media, build on other researchers' findings, and double-check everyone's work. Search our catalog to piece together the bigger picture.
            </p>
            <p>
              We help OSINT researchers and organizations collaborate so they can focus on content, not coordination. <a href="https://atlos.notion.site/Platform-Overview-46d4723f22ef420fb5ad0e07feba8d79" className='link'>Preview our platform.</a>
            </p>
            <p>
              OSINT research can be taxing; Atlos puts researchers' safety and mental health first. <a href="https://atlos.notion.site/Our-Approach-to-Safety-3c1b9842128a4149b3c60c32773c8e5a" className='link'>Learn about our approach to safety.</a>
            </p>
            <p>
              If you or your organization is interested in working with us, please <a href="mailto:contact@atlos.org" className='link'>reach out</a> or join our mailing list. <a href="https://mailchi.mp/a1de52cd4614/atlos" className='link'>Sign up to receive updates.</a>
            </p>
          </div>
        </section>
      </main>
    </div>
  )
}
