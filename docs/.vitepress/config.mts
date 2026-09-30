import { defineConfig } from 'vitepress'
import { withMermaid } from 'vitepress-plugin-mermaid'

export default withMermaid(defineConfig({
  lang: 'en-US',
  title: 'Lepus',
  description: 'A native desktop application toolkit for MoonBit.',
  cleanUrls: true,
  lastUpdated: true,
  head: [
    ['meta', { name: 'theme-color', content: '#7c3aed' }],
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/logo.svg' }],
  ],
  mermaid: {
    theme: 'default',
  },
  vite: {
    optimizeDeps: {
      include: ['fastdom', 'fastdom/extensions/fastdom-promised.js'],
    },
  },
  markdown: {
    lineNumbers: true,
    theme: {
      light: 'github-light',
      dark: 'dracula',
    },
    languages: [import('./moonbit.tmLanguage.json') as any],
  },
  themeConfig: {
    logo: '/logo.svg',
    siteTitle: 'Lepus',
    nav: [
      { text: 'Guide', link: '/getting-started' },
      { text: 'Reference', link: '/core-api' },
      { text: 'Plugins', link: '/plugins' },
      { text: 'GitHub', link: 'https://github.com/lepus-apps/lepus' },
    ],
    sidebar: [
      {
        text: 'Guide',
        items: [
          { text: 'Getting Started', link: '/getting-started' },
          { text: 'Windows and Events', link: '/windows' },
          { text: 'Plugins', link: '/plugins' },
          { text: 'CLI', link: '/cli' },
        ],
      },
      {
        text: 'Reference',
        items: [
          { text: 'Core API', link: '/core-api' },
          { text: 'WebView API', link: '/webview' },
          { text: 'Plugin Matrix', link: '/plugin-matrix' },
          { text: 'Platform Support', link: '/platform-support' },
          { text: 'Architecture', link: '/architecture' },
        ],
      },
    ],
    socialLinks: [
      { icon: 'github', link: 'https://github.com/lepus-apps/lepus' },
    ],
    search: {
      provider: 'local',
    },
    editLink: {
      pattern: 'https://github.com/lepus-apps/lepus/edit/main/docs/:path',
    },
    outline: {
      label: 'On this page',
      level: [2, 3],
    },
    docFooter: {
      prev: 'Previous page',
      next: 'Next page',
    },
    footer: {
      message: 'Released under the Apache License 2.0.',
      copyright: 'Copyright © Lepus contributors',
    },
  },
}))
