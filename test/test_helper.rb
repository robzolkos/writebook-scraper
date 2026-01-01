# frozen_string_literal: true

require "minitest/autorun"
require "webmock/minitest"
require "fileutils"

require_relative "../lib/writebook_scraper"

class WritebookScraperTestCase < Minitest::Test
  def setup
    @output_dir = File.join(Dir.pwd, "output", "test-book")
    FileUtils.rm_rf(@output_dir)
    WebMock.disable_net_connect!
  end

  def teardown
    FileUtils.rm_rf(@output_dir)
    WebMock.allow_net_connect!
  end

  private

  def index_page_html
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>My Test Book</title></head>
      <body>
        <h1 class="txt-large--responsive">My Test Book</h1>
        <ul>
          <li><a href="/1/test-book/10/introduction">Introduction</a></li>
          <li><a href="/1/test-book/20/getting-started">Getting Started</a></li>
          <li><a href="/1/test-book/30/advanced-topics">Advanced Topics</a></li>
        </ul>
      </body>
      </html>
    HTML
  end

  def index_page_with_unordered_chapters
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>My Test Book</title></head>
      <body>
        <h1 class="txt-large--responsive">My Test Book</h1>
        <ul>
          <li><a href="/1/test-book/30/chapter-c">Chapter C</a></li>
          <li><a href="/1/test-book/10/chapter-a">Chapter A</a></li>
          <li><a href="/1/test-book/20/chapter-b">Chapter B</a></li>
        </ul>
      </body>
      </html>
    HTML
  end

  def index_page_with_duplicate_links
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>My Test Book</title></head>
      <body>
        <h1 class="txt-large--responsive">My Test Book</h1>
        <ul>
          <li><a href="/1/test-book/10/introduction">Introduction</a></li>
          <li><a href="/1/test-book/10/introduction">Introduction Again</a></li>
          <li><a href="/1/test-book/20/getting-started">Getting Started</a></li>
        </ul>
      </body>
      </html>
    HTML
  end

  def chapter_page_html(title, content)
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>#{title}</title></head>
      <body>
        <article>
          <h1>#{title}</h1>
          <p>#{content}</p>
        </article>
        <h1 class="txt-large--responsive">My Test Book</h1>
      </body>
      </html>
    HTML
  end

  def chapter_page_with_image
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>Introduction</title></head>
      <body>
        <article>
          <h1>Introduction</h1>
          <p>Welcome!</p>
          <a href="https://example.com/u/screenshot.png">
            <img src="https://example.com/images/screenshot.png" alt="Screenshot">
          </a>
        </article>
        <h1 class="txt-large--responsive">My Test Book</h1>
      </body>
      </html>
    HTML
  end

  def chapter_page_with_relative_image
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>Introduction</title></head>
      <body>
        <article>
          <h1>Introduction</h1>
          <p>Welcome!</p>
          <img src="/u/relative-image.png" alt="Relative">
        </article>
        <h1 class="txt-large--responsive">My Test Book</h1>
      </body>
      </html>
    HTML
  end

  def chapter_page_with_anchor_links
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>Introduction</title></head>
      <body>
        <article>
          <h1>Introduction <a href="#introduction">#</a></h1>
          <p>Welcome!</p>
          <h2>Section One <a href="#section-one">#</a></h2>
          <p>Content here.</p>
        </article>
        <h1 class="txt-large--responsive">My Test Book</h1>
      </body>
      </html>
    HTML
  end

  def chapter_page_with_book_title_h1
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>Introduction</title></head>
      <body>
        <h1 class="txt-large--responsive">My Test Book</h1>
        <article>
          <h1>Introduction</h1>
          <p>Welcome!</p>
        </article>
      </body>
      </html>
    HTML
  end

  def chapter_page_with_table
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>Introduction</title></head>
      <body>
        <article>
          <h1>Introduction</h1>
          <table>
            <tr><th>Hotkey</th><th>Function</th></tr>
            <tr><td><code>Ctrl+C</code></td><td>Copy</td></tr>
            <tr><td><code>Ctrl+V</code></td><td>Paste</td></tr>
          </table>
        </article>
        <h1 class="txt-large--responsive">My Test Book</h1>
      </body>
      </html>
    HTML
  end

  def chapter_page_with_code
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>Introduction</title></head>
      <body>
        <article>
          <h1>Introduction</h1>
          <p>Run this command: <code>echo hello</code></p>
        </article>
        <h1 class="txt-large--responsive">My Test Book</h1>
      </body>
      </html>
    HTML
  end

  def stub_index_page
    stub_request(:get, "https://example.com/1/test-book")
      .to_return(body: index_page_html, status: 200)
  end

  def stub_all_chapter_pages
    stub_request(:get, "https://example.com/1/test-book/10/introduction")
      .to_return(body: chapter_page_html("Introduction", "Welcome!"), status: 200)
    stub_request(:get, "https://example.com/1/test-book/20/getting-started")
      .to_return(body: chapter_page_html("Getting Started", "Begin."), status: 200)
    stub_request(:get, "https://example.com/1/test-book/30/advanced-topics")
      .to_return(body: chapter_page_html("Advanced Topics", "Deep."), status: 200)
  end
end
