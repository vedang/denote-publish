# denote-publish

A package to publish [Denote](https://protesilaos.com/emacs/denote) notes as Markdown files with YAML front matter.

## Features

- Export Denote files to Markdown format while preserving their metadata
- Customizable YAML front matter generation
- Support for Denote-style internal links
- Integration with `org-publish` for batch processing
- Single file publishing capability
- Configurable output formatting

## Installation

### MELPA

!!<TBD>!!

The package will be available on MELPA soon. Once it's there, you can install it via:

```elisp
M-x package-install RET denote-publish RET
```

### Manual Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/vedang/denote-publish.git
   ```

2. Add the following to your Emacs configuration:
   ```elisp
   (add-to-list 'load-path "/path/to/denote-publish")
   (require 'denote-publish)
   ```

## Configuration

### Basic Setup

```elisp
;; Set default directories
(setq denote-publish-default-base-dir "~/notes")
(setq denote-publish-default-output-dir "~/blog/content")

;; Customize link styling
(setq denote-publish-link-class "internal-link")

;; Configure front matter fields
(setq denote-publish-front-matter-fields
      '(title subtitle identifier date last_updated_at
              aliases tags category skip_archive has_code
              og_image og_description og_video_id))
```

### Publishing Project Setup

To set up a publishing project for batch processing:

```elisp
(setq org-publish-project-alist
      '(("my-denotes"
         :base-directory "~/notes/published"
         :publishing-directory "~/blog/content"
         :publishing-function denote-publish-to-md
         :recursive nil
         :exclude-tags ("noexport" "draft")
         :section-numbers nil
         :with-creator nil
         :with-toc nil)))
```

## Usage

### Single File Publishing

To publish a single Denote file:

```elisp
M-x denote-publish-file RET
```

This will prompt you to select a file and publish it to your configured output directory.

### Batch Publishing

To publish all files in your project:

```elisp
M-x org-publish RET my-denotes RET
```

## Front Matter Support

The package supports the following front matter fields by default:

- `title`: The note's title
- `subtitle`: Optional subtitle
- `identifier`: Denote identifier
- `date`: Creation date
- `last_updated_at`: Last modification date
- `aliases`: Alternative names/paths
- `tags`: Org file tags
- `category`: Note category
- `skip_archive`: Whether to skip archiving
- `has_code`: Whether the note contains code
- `og_image`: Open Graph image
- `og_description`: Open Graph description
- `og_video_id`: Open Graph video ID

You can customize which fields appear in the front matter by modifying `denote-publish-front-matter-fields`.

### Example Output

```yaml
---
title: "My Note Title"
date: "2024-01-04"
last_updated_at: "2024-01-04"
tags: ["emacs", "org-mode", "denote"]
category: "programming"
---

Note content here...
```

## Customization

All customizable options can be accessed via:

```elisp
M-x customize-group RET denote-publish RET
```

Key customization options include:

- `denote-publish-default-base-dir`: Default directory for source files
- `denote-publish-default-output-dir`: Default directory for output files
- `denote-publish-link-class`: CSS class for internal links
- `denote-publish-front-matter-fields`: Fields to include in front matter

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the GNU General Public License v3.0 - see the LICENSE file for details.

## Acknowledgments

- The [Denote](https://protesilaos.com/emacs/denote) package by Protesilaos Stavrou
- The [ox-gfm](https://github.com/larstvei/ox-gfm) package for GitHub Flavored Markdown export
