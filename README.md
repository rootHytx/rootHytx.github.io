# root/hytx - Terminal Portfolio

A modern terminal-style portfolio website built with Astro.

## Features

- 🖥️ Terminal-style interface with blinking cursor
- 🎨 Custom color scheme (#e79cfe text on black background)
- ⌨️ Keyboard navigation support (arrow keys + enter)
- 📱 Responsive design
- ⚡ Built with Astro for fast performance

## Development

### Prerequisites

- Node.js 18 or higher
- npm

### Installation

```bash
npm install
```

### Development Server

```bash
npm run dev
```

This will start the development server at `http://localhost:4321`

### Build

```bash
npm run build
```

### Preview

```bash
npm run preview
```

## Deployment

This site is automatically deployed to GitHub Pages via GitHub Actions when changes are pushed to the main branch.

## Project Structure

```
├── src/
│   ├── pages/
│   │   └── index.astro    # Main terminal interface
│   └── components/        # Reusable components
├── public/               # Static assets
├── .github/workflows/    # GitHub Actions workflows
└── astro.config.mjs      # Astro configuration
```

## Customization

To add new projects to the directory listing, edit the `src/pages/index.astro` file and add new directory items in the format:

```html
<div class="directory-item" onclick="window.open('YOUR_URL', '_blank')">
  <span class="folder-icon">📁</span>
  <span class="project-path">/root/YOUR_PROJECT_NAME</span>
</div>
```

## License

MIT