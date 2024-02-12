module.exports = {
  reactStrictMode: true,
  async redirects() {
    return [
      {
        source: '/waitlist',
        destination: 'https://forms.gle/Hi8ChipVJfMgMrtHA',
        permanent: false,
      },
      {
        source: '/resilience',
        destination: 'https://docs.atlos.org/safety-and-security/vicarious-trauma/',
        permanent: false,
      },
      {
        source: '/guide',
        destination: 'https://atlos.notion.site/Atlos-Guide-df4d53a882424c75b68e579769542896',
        permanent: false,
      },
    ]
  }
}
