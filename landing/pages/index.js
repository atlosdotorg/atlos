import Head from 'next/head'
import Image from 'next/image'
import maplibregl from 'maplibre-gl';
import { useState, useEffect } from 'react';

function easing(t) {
  return t * (2 - t);
}

export default function Home() {
  const [pageIsMounted, setPageIsMounted] = useState(false)

  useEffect(() => {
    setPageIsMounted(true)
    try {
      // This might fail if the user is on a browser without WebGL support
      const map = new maplibregl.Map({
        container: 'map', // container ID
        style: 'https://api.maptiler.com/maps/f500afba-9462-4a87-a22c-11a73e457abb/style.json?key=3MNBcFq8hjQtKnOL3tae', // style URL
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
    } catch (e) { }
  }, []);

  return (
    <div className='min-h-full'>
      <Head>
        <title>Atlos</title>
        <meta name="description" content="Atlos makes large-scale visual investigations faster, easier, and safer." />
        <link rel="icon" href="/icon.svg" />
      </Head>

      <main>
        <div className="w-full h-full -z-1">
          <div id="map" className="fixed w-full h-full top-0 left-0 bg-stone-700 -z-1 max-h-screen overflow-hidden"></div>
        </div>
        <div className="fixed top-0 left-0 w-full h-full z-[100] p-4">
          <div className='text-white text-lg flex flex-wrap gap-4 p-2 border rounded-lg lg:mt-8 lg:max-w-3xl bg-neutral-600/75 backdrop-blur-md mx-auto border-neutral-500 items-center'>
            <p className='text-2xl pl-2'>
              <span className="text-white font-mono font-bold">ATLOS</span>
            </p>
            <span className="grow"></span>
            <a href="https://docs.atlos.org" className="text-sm font-medium shrink text-neutral-300 hover:text-white focus:text-white transition">Docs</a>
            <a href="https://platform.atlos.org" className="text-sm font-medium shrink text-neutral-300 hover:text-white focus:text-white transition">Log in</a>
            <a href="https://platform.atlos.org/invite/MPBXPLUR5C" className="text-sm font-medium shrink transition bg-white text-neutral-700 p-2 rounded">Join Atlos</a>
          </div>
        </div>
        <section className='relative z-10 flex flex-col space-y-6 top-0 mx-auto p-6 lg:max-w-2xl mt-32 lg:mt-40'>
          <p className="text-3xl font-semibold md:text-5xl text-white pt-2 text-center lg:-mx-48">
            Atlos makes large-scale visual investigations faster, easier, and safer.
          </p>
          <section>
            <p className='text-xs text-white/50 text-center uppercase mt-16'>Supported by</p>
            <div className="flex flex-wrap justify-center items-center gap-8 mt-4 opacity-[0.8]">
              <a href='https://www.microsoft.com/en-us/corporate-responsibility/democracy-forward'>
                <Image src="/microsoft.svg" alt="The logo of Microsoft" height={141 / 3} width={520 / 3} />
              </a>
              <a href='https://brown.stanford.edu'>
                <Image src="/brown.png" alt="The logo of the Brown Institute for Media Innovation at Stanford" height={141 / 3} width={520 / 3} />
              </a>
              <a href='https://bellingcat.com/'>
                <Image src="/bellingcat.svg" alt="The logo of Bellingcat" height={150 / 3} width={520 / 3} />
              </a>
            </div>
          </section>
          <section className="lg:-mx-32">
            <Image src="/screenshots/map.jpeg" alt="A photo of the Atlos map" height={1588 / 2} width={2304 / 2} className='mt-16 rounded-lg border border-slate-800 border-2' />
            <p className="text-white/50 text-xs text-center mt-4">The Atlos map view, where you can see your geolocated incidents at a glance.</p>
          </section>
          <div className='text-white prose prose-invert prose-lg marker:text-white/50 blockquote:border-white/50 pb-24'>
            <p className='mt-16'>Anyone can post visual evidence of a war crime online.</p>
            <p>Journalists, human rights investigators, and open source researchers use this media to tell stories, pursue accountability, and document history.</p>
            <p>But they rely on general-purpose tools like Google Sheets to conduct highly-specialized investigations. Today&apos;s tools slow investigations, hamper collaboration, and risk researchers&apos; safety.</p>
            <p>Atlos is a collaborative workspace for large-scale visual investigations. Atlos helps you organize your investigation into searchable incidents, distribute work across your team, track changes, archive source material, and analyze your data&mdash;all while protecting researcher safety.</p>
            <p>We know that your investigations are sensitive, and a landing page on a website isn&apos;t nearly enough to tell you whether Atlos is right for you. So we&apos;ve put together:</p>
            <ul>
              <li>A detailed explanation of <a href="https://docs.atlos.org/overview/what-is-atlos/">who Atlos is for</a>.</li>
              <li>An analysis of our <a href="https://docs.atlos.org/safety-and-security/risk-model/">security and risk model</a>.</li>
              <li>A <a href="https://docs.atlos.org/overview/roadmap/">roadmap</a> for where we&apos;re headed next.</li>
            </ul>
            <p>We are proud to support some of the largest open source visual investigations, such as Bellingcat&apos;s investigation into civilian harm in Ukraine&apos;s war against Russia.</p>
            <blockquote className='border-white/50'>
              Atlos is a game-changer.
              <cite className='block text-xs ml-4 mt-2 font-light'>Giancarlo Fiorella, Director for Research and Training at Bellingcat</cite>
            </blockquote>
            <p>Atlos is a non-profit, open source platform. For more information about Atlos, please see our <a href="https://docs.atlos.org">documentation</a> or <a href="mailto:contact@atlos.org">contact us</a>.</p>
          </div>
        </section>
      </main>
    </div>
  )
}
