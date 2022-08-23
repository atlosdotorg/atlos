module.exports = {
  reactStrictMode: true,
  async redirects() {
    return [
      {
        source: '/waitlist',
        destination: 'https://forms.gle/Hi8ChipVJfMgMrtHA',
        permanent: false,
      },
    ]
  }
}
