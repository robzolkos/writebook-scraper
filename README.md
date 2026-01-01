# Writebook Scraper

A Ruby script that scrapes [Writebook](https://once.com/writebook) sites and converts them to local Markdown files with downloaded images.

## Requirements

- Ruby 3.4+

## Installation

```bash
bundle install
```

## Usage

```bash
bin/writebook_scraper <book_url>
```

### Examples

```bash
# Scrape a Writebook site
bin/writebook_scraper https://books.example.com/1/my-book

# Another example
bin/writebook_scraper https://docs.example.org/2/user-guide
```

## Output

The scraper creates an `output/<book-slug>/` directory containing:

```
output/my-book/
├── index.md                 # Table of contents
├── getting-started.md       # Chapter files
├── hotkeys.md
├── themes.md
├── ...
└── images/
    ├── getting-started-screenshot.png
    ├── themes-tokyo-night.png
    └── ...
```

### What gets converted

- Chapter content with proper Markdown formatting
- Headings (h1, h2, h3, etc.)
- Tables
- Code blocks and inline code
- Links (internal and external)
- Images (downloaded locally)
- Lists (ordered and unordered)

## Summarizing a Book

After scraping, you can generate an LLM-friendly summary:

```bash
bin/summarize output/my-book
```

This creates `my-book.md` with:
- Book overview
- Section summaries with key points
- Quick reference tables (hotkeys, config paths, troubleshooting)

Requires the `claude` CLI to be installed and configured.

### Token Reduction

For a sample 39-chapter technical manual:

| Metric | Full Book | Summary | Reduction |
|--------|-----------|---------|-----------|
| Characters | 89,441 | 9,422 | 89% |
| Words | 11,786 | 1,500 | 87% |
| Est. Tokens | ~22,360 | ~2,355 | **~90%** |

The summary preserves key information, commands, and configuration paths while reducing token usage by approximately 90%.

## Running Tests

```bash
bundle exec rake test
```

## How It Works

1. Fetches the book index page and extracts all chapter links
2. Downloads each chapter page
3. Extracts the main content area
4. Downloads all images to a local `images/` directory
5. Converts HTML to Markdown using `reverse_markdown`
6. Cleans up anchor links and duplicate titles
7. Generates an `index.md` with table of contents
