# frozen_string_literal: true

require_relative "test_helper"

class WritebookScraperTest < WritebookScraperTestCase
  def test_extracts_book_title_from_index_page
    stub_index_page

    scraper = WritebookScraper.new("https://example.com/1/test-book")
    scraper.send(:fetch_chapters)

    assert_equal "My Test Book", scraper.instance_variable_get(:@book_title)
  end

  def test_extracts_chapters_from_index_page
    stub_index_page

    scraper = WritebookScraper.new("https://example.com/1/test-book")
    scraper.send(:fetch_chapters)

    chapters = scraper.instance_variable_get(:@chapters)
    assert_equal 3, chapters.size
    assert_equal "10", chapters[0][:id]
    assert_equal "introduction", chapters[0][:slug]
    assert_equal "20", chapters[1][:id]
    assert_equal "getting-started", chapters[1][:slug]
    assert_equal "30", chapters[2][:id]
    assert_equal "advanced-topics", chapters[2][:slug]
  end

  def test_chapters_sorted_by_id
    stub_request(:get, "https://example.com/1/test-book")
      .to_return(body: index_page_with_unordered_chapters, status: 200)

    scraper = WritebookScraper.new("https://example.com/1/test-book")
    scraper.send(:fetch_chapters)

    chapters = scraper.instance_variable_get(:@chapters)
    ids = chapters.map { |c| c[:id].to_i }
    assert_equal ids.sort, ids
  end

  def test_extracts_chapter_title_from_page
    stub_index_page
    stub_request(:get, "https://example.com/1/test-book/10/introduction")
      .to_return(body: chapter_page_html("Introduction", "Welcome to the book!"), status: 200)
    stub_request(:get, "https://example.com/1/test-book/20/getting-started")
      .to_return(body: chapter_page_html("Getting Started", "Let's begin."), status: 200)
    stub_request(:get, "https://example.com/1/test-book/30/advanced-topics")
      .to_return(body: chapter_page_html("Advanced Topics", "Deep dive."), status: 200)

    scraper = WritebookScraper.new("https://example.com/1/test-book")
    scraper.scrape

    chapters = scraper.instance_variable_get(:@chapters)
    assert_equal "Introduction", chapters[0][:title]
    assert_equal "Getting Started", chapters[1][:title]
    assert_equal "Advanced Topics", chapters[2][:title]
  end

  def test_skips_duplicate_chapters
    stub_request(:get, "https://example.com/1/test-book")
      .to_return(body: index_page_with_duplicate_links, status: 200)

    scraper = WritebookScraper.new("https://example.com/1/test-book")
    scraper.send(:fetch_chapters)

    chapters = scraper.instance_variable_get(:@chapters)
    ids = chapters.map { |c| c[:id] }
    assert_equal ids.uniq, ids
  end
end

class OutputStructureTest < WritebookScraperTestCase
  def test_creates_output_directory_structure
    stub_index_page
    stub_all_chapter_pages

    scraper = WritebookScraper.new("https://example.com/1/test-book")
    scraper.scrape

    assert Dir.exist?(@output_dir)
    assert Dir.exist?(File.join(@output_dir, "images"))
  end

  def test_creates_markdown_files_for_chapters
    stub_index_page
    stub_all_chapter_pages

    scraper = WritebookScraper.new("https://example.com/1/test-book")
    scraper.scrape

    assert File.exist?(File.join(@output_dir, "introduction.md"))
    assert File.exist?(File.join(@output_dir, "getting-started.md"))
    assert File.exist?(File.join(@output_dir, "advanced-topics.md"))
  end

  def test_creates_index_file_with_table_of_contents
    stub_index_page
    stub_all_chapter_pages

    scraper = WritebookScraper.new("https://example.com/1/test-book")
    scraper.scrape

    index_content = File.read(File.join(@output_dir, "index.md"))
    assert_includes index_content, "# My Test Book"
    assert_includes index_content, "## Table of Contents"
    assert_includes index_content, "[Introduction](introduction.md)"
    assert_includes index_content, "[Getting Started](getting-started.md)"
    assert_includes index_content, "[Advanced Topics](advanced-topics.md)"
  end
end

class MarkdownConversionTest < WritebookScraperTestCase
  def test_markdown_file_contains_title_and_content
    stub_index_page
    stub_request(:get, "https://example.com/1/test-book/10/introduction")
      .to_return(body: chapter_page_html("Introduction", "Welcome to the book!"), status: 200)
    stub_request(:get, "https://example.com/1/test-book/20/getting-started")
      .to_return(body: chapter_page_html("Getting Started", "Begin."), status: 200)
    stub_request(:get, "https://example.com/1/test-book/30/advanced-topics")
      .to_return(body: chapter_page_html("Advanced Topics", "Deep."), status: 200)

    scraper = WritebookScraper.new("https://example.com/1/test-book")
    scraper.scrape

    content = File.read(File.join(@output_dir, "introduction.md"))
    assert_includes content, "# Introduction"
    assert_includes content, "Welcome to the book!"
  end

  def test_removes_anchor_links_from_headings
    stub_index_page
    stub_request(:get, "https://example.com/1/test-book/10/introduction")
      .to_return(body: chapter_page_with_anchor_links, status: 200)
    stub_request(:get, "https://example.com/1/test-book/20/getting-started")
      .to_return(body: chapter_page_html("Getting Started", "Begin."), status: 200)
    stub_request(:get, "https://example.com/1/test-book/30/advanced-topics")
      .to_return(body: chapter_page_html("Advanced Topics", "Deep."), status: 200)

    scraper = WritebookScraper.new("https://example.com/1/test-book")
    scraper.scrape

    content = File.read(File.join(@output_dir, "introduction.md"))
    refute_includes content, "[#]"
    refute_includes content, "(#introduction)"
  end

  def test_removes_book_title_h1_from_chapter_content
    stub_index_page
    stub_request(:get, "https://example.com/1/test-book/10/introduction")
      .to_return(body: chapter_page_with_book_title_h1, status: 200)
    stub_request(:get, "https://example.com/1/test-book/20/getting-started")
      .to_return(body: chapter_page_html("Getting Started", "Begin."), status: 200)
    stub_request(:get, "https://example.com/1/test-book/30/advanced-topics")
      .to_return(body: chapter_page_html("Advanced Topics", "Deep."), status: 200)

    scraper = WritebookScraper.new("https://example.com/1/test-book")
    scraper.scrape

    content = File.read(File.join(@output_dir, "introduction.md"))
    assert_includes content, "# Introduction"
    refute_match(/^# My Test Book$/m, content)
  end

  def test_preserves_tables_in_markdown
    stub_index_page
    stub_request(:get, "https://example.com/1/test-book/10/introduction")
      .to_return(body: chapter_page_with_table, status: 200)
    stub_request(:get, "https://example.com/1/test-book/20/getting-started")
      .to_return(body: chapter_page_html("Getting Started", "Begin."), status: 200)
    stub_request(:get, "https://example.com/1/test-book/30/advanced-topics")
      .to_return(body: chapter_page_html("Advanced Topics", "Deep."), status: 200)

    scraper = WritebookScraper.new("https://example.com/1/test-book")
    scraper.scrape

    content = File.read(File.join(@output_dir, "introduction.md"))
    assert_includes content, "| Hotkey | Function |"
    assert_includes content, "| `Ctrl+C` | Copy |"
  end

  def test_preserves_code_blocks_in_markdown
    stub_index_page
    stub_request(:get, "https://example.com/1/test-book/10/introduction")
      .to_return(body: chapter_page_with_code, status: 200)
    stub_request(:get, "https://example.com/1/test-book/20/getting-started")
      .to_return(body: chapter_page_html("Getting Started", "Begin."), status: 200)
    stub_request(:get, "https://example.com/1/test-book/30/advanced-topics")
      .to_return(body: chapter_page_html("Advanced Topics", "Deep."), status: 200)

    scraper = WritebookScraper.new("https://example.com/1/test-book")
    scraper.scrape

    content = File.read(File.join(@output_dir, "introduction.md"))
    assert_includes content, "`echo hello`"
  end
end

class ImageHandlingTest < WritebookScraperTestCase
  def test_downloads_images_locally
    stub_index_page
    stub_request(:get, "https://example.com/1/test-book/10/introduction")
      .to_return(body: chapter_page_with_image, status: 200)
    stub_request(:get, "https://example.com/1/test-book/20/getting-started")
      .to_return(body: chapter_page_html("Getting Started", "Begin."), status: 200)
    stub_request(:get, "https://example.com/1/test-book/30/advanced-topics")
      .to_return(body: chapter_page_html("Advanced Topics", "Deep."), status: 200)
    stub_request(:get, "https://example.com/images/screenshot.png")
      .to_return(body: "fake-image-data", status: 200)

    scraper = WritebookScraper.new("https://example.com/1/test-book")
    scraper.scrape

    image_path = File.join(@output_dir, "images", "introduction-screenshot.png")
    assert File.exist?(image_path)
    assert_equal "fake-image-data", File.read(image_path)
  end

  def test_updates_image_references_to_local_paths
    stub_index_page
    stub_request(:get, "https://example.com/1/test-book/10/introduction")
      .to_return(body: chapter_page_with_image, status: 200)
    stub_request(:get, "https://example.com/1/test-book/20/getting-started")
      .to_return(body: chapter_page_html("Getting Started", "Begin."), status: 200)
    stub_request(:get, "https://example.com/1/test-book/30/advanced-topics")
      .to_return(body: chapter_page_html("Advanced Topics", "Deep."), status: 200)
    stub_request(:get, "https://example.com/images/screenshot.png")
      .to_return(body: "fake-image-data", status: 200)

    scraper = WritebookScraper.new("https://example.com/1/test-book")
    scraper.scrape

    content = File.read(File.join(@output_dir, "introduction.md"))
    assert_includes content, "images/introduction-screenshot.png"
    refute_includes content, "https://example.com/images/screenshot.png"
  end

  def test_handles_relative_image_urls
    stub_index_page
    stub_request(:get, "https://example.com/1/test-book/10/introduction")
      .to_return(body: chapter_page_with_relative_image, status: 200)
    stub_request(:get, "https://example.com/1/test-book/20/getting-started")
      .to_return(body: chapter_page_html("Getting Started", "Begin."), status: 200)
    stub_request(:get, "https://example.com/1/test-book/30/advanced-topics")
      .to_return(body: chapter_page_html("Advanced Topics", "Deep."), status: 200)
    stub_request(:get, "https://example.com/u/relative-image.png")
      .to_return(body: "relative-image-data", status: 200)

    scraper = WritebookScraper.new("https://example.com/1/test-book")
    scraper.scrape

    image_path = File.join(@output_dir, "images", "introduction-relative-image.png")
    assert File.exist?(image_path)
  end
end
