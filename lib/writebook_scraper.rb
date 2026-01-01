# frozen_string_literal: true

require "nokogiri"
require "httparty"
require "reverse_markdown"
require "fileutils"

class WritebookScraper
  def initialize(book_url)
    @book_url = book_url
    @base_url = URI.parse(book_url).then { |uri| "#{uri.scheme}://#{uri.host}" }
    @chapters = []
    @book_title = nil
  end

  def scrape
    puts "Fetching book index: #{@book_url}"
    fetch_chapters
    puts "Found #{@chapters.size} chapters"

    output_dir = create_output_directory
    download_all_chapters(output_dir)
    create_index_file(output_dir)

    puts "\nDone! Output saved to: #{output_dir}"
  end

  private

  def fetch_chapters
    response = HTTParty.get(@book_url)
    doc = Nokogiri::HTML(response.body)

    # Extract book title from the page - look for h1 with specific class
    # The book title h1 often has sibling elements with author info, so just get direct text
    title_h1 = doc.at_css("h1.txt-large--responsive")
    if title_h1
      # Get only the direct text content, not nested element text
      @book_title = title_h1.children.select { |c| c.text? }.map(&:text).join.strip
      @book_title = title_h1.text.strip if @book_title.empty?
    else
      @book_title = book_slug.gsub("-", " ").split.map(&:capitalize).join(" ")
    end
    @book_title = @book_title.gsub(/\s*#\s*$/, "")

    # Extract chapter links from the index page
    # Writebook uses links within list items for chapters
    doc.css("a[href*='/#{book_path}/']").each do |link|
      href = link["href"]
      next if href == @book_url.gsub(@base_url, "") # Skip self-reference

      # Extract chapter info from URL pattern: /book_id/book_slug/chapter_id/chapter_slug
      if href =~ %r{/\d+/[^/]+/(\d+)/([^/]+)}
        chapter_id = $1
        chapter_slug = $2

        next if @chapters.any? { |c| c[:id] == chapter_id }

        # Derive title from slug (will be overwritten when we fetch the page)
        title = chapter_slug.gsub("-", " ").split.map(&:capitalize).join(" ")

        @chapters << {
          id: chapter_id,
          slug: chapter_slug,
          title: title,
          url: "#{@base_url}#{href}"
        }
      end
    end

    # Sort by ID to maintain order
    @chapters.sort_by! { |c| c[:id].to_i }
  end

  def book_path
    # Extract book path from URL (e.g., "1/my-book")
    @book_url.gsub(@base_url, "").sub(%r{^/}, "")
  end

  def book_slug
    book_path.split("/").last || "book"
  end

  def create_output_directory
    dir = File.join(Dir.pwd, "output", book_slug)
    FileUtils.mkdir_p(File.join(dir, "images"))
    dir
  end

  def download_all_chapters(output_dir)
    @chapters.each_with_index do |chapter, index|
      puts "  [#{index + 1}/#{@chapters.size}] #{chapter[:title]}"
      download_chapter(chapter, output_dir)
    end
  end

  def download_chapter(chapter, output_dir)
    response = HTTParty.get(chapter[:url])
    doc = Nokogiri::HTML(response.body)

    # Extract the actual title from the page's h1
    # Some pages have multiple h1s - find the one with actual content (skip book title)
    # The chapter title h1 usually comes first, before the book title h1
    page_title = nil
    doc.css("h1").each do |h1|
      text = h1.text.strip.gsub(/\s*#\s*$/, "")
      # Skip book title, empty titles, or titles that are just the book title class
      next if text.empty?
      next if text == @book_title
      next if h1["class"]&.include?("txt-large--responsive") # This is the book title
      page_title = text
      break
    end
    chapter[:title] = page_title || chapter[:title]

    # Find the main content area - Writebook typically uses article or main content divs
    content = extract_main_content(doc)

    # Download images and update references
    content = process_images(content, output_dir, chapter[:slug])

    # Convert to markdown
    markdown = convert_to_markdown(content, chapter[:title])

    # Write to file
    filename = "#{chapter[:slug]}.md"
    File.write(File.join(output_dir, filename), markdown)
  end

  def extract_main_content(doc)
    # Try various selectors for main content
    selectors = [
      "article",
      "main article",
      "[data-controller*='content']",
      ".prose",
      ".content",
      "main"
    ]

    selectors.each do |selector|
      element = doc.at_css(selector)
      return element if element
    end

    # Fallback: find the largest content block
    doc.css("div").max_by { |div| div.text.length } || doc.at_css("body")
  end

  def process_images(content, output_dir, chapter_slug)
    images_dir = File.join(output_dir, "images")

    content.css("img").each do |img|
      src = img["src"]
      next unless src

      # Handle relative URLs
      image_url = src.start_with?("http") ? src : "#{@base_url}#{src}"

      # Generate local filename
      original_filename = File.basename(URI.parse(image_url).path)
      local_filename = "#{chapter_slug}-#{original_filename}"
      local_path = File.join(images_dir, local_filename)

      # Download image
      begin
        download_image(image_url, local_path)
        img["src"] = "images/#{local_filename}"
      rescue => e
        puts "    Warning: Failed to download image #{image_url}: #{e.message}"
      end
    end

    content
  end

  def download_image(url, local_path)
    return if File.exist?(local_path)

    response = HTTParty.get(url)
    File.binwrite(local_path, response.body)
  end

  def convert_to_markdown(content, title)
    # Remove navigation elements, sidebars, etc.
    content.css("nav, .sidebar, .navigation, [data-controller='navigation']").each(&:remove)

    # Remove book title h1 (keep chapter title h1)
    content.css("h1").each do |h1|
      text = h1.text.strip.gsub(/\s*#\s*$/, "")
      h1.remove if text.empty? || text == @book_title || h1["class"]&.include?("txt-large--responsive")
    end

    # Remove anchor links (the # links next to headings)
    content.css("a[href^='#']").each do |anchor|
      anchor.remove if anchor.text.strip == "#"
    end

    # Fix image wrapper links that still point to original URLs
    content.css("a").each do |link|
      href = link["href"]
      # If link wraps an image and points to external/original URL, make it point to local image
      if href && link.at_css("img")
        img = link.at_css("img")
        # If link points to original image location, update to local path
        if href.include?("/u/") || href.start_with?("http")
          link["href"] = img["src"] if img["src"]&.start_with?("images/")
        end
      end
    end

    # Convert HTML to Markdown
    markdown = ReverseMarkdown.convert(content.to_html, unknown_tags: :bypass, github_flavored: true)

    # Clean up the markdown
    markdown = clean_markdown(markdown, title)

    markdown
  end

  def clean_markdown(markdown, title)
    markdown = markdown
      .gsub(/\n{3,}/, "\n\n")                    # Reduce multiple newlines
      .gsub(/^\s+$/, "")                          # Remove whitespace-only lines
      .gsub(/\[([^\]]+)\]\(\s*\)/, '\1')          # Remove empty links
      .gsub(/\s*\[#\]\(#[^)]*\)/, "")             # Remove [#](#anchor) patterns
      .gsub(%r{\]\(/u/[^)]+\)}, ")")              # Fix links still pointing to /u/
      .gsub(/^# #{Regexp.escape(title)}\n+# #{Regexp.escape(title)}/, "# #{title}") # Remove duplicate titles
      .strip + "\n"

    # Ensure file starts with title
    unless markdown.start_with?("# ")
      markdown = "# #{title}\n\n#{markdown}"
    end

    markdown
  end

  def create_index_file(output_dir)
    index_content = "# #{@book_title}\n\n## Table of Contents\n\n"

    @chapters.each_with_index do |chapter, index|
      index_content += "#{index + 1}. [#{chapter[:title]}](#{chapter[:slug]}.md)\n"
    end

    File.write(File.join(output_dir, "index.md"), index_content)
  end
end
