require 'sinatra'
# require 'middleman-core'
# require 'middleman-blog'
require 'json'
require 'time'
require 'pathname'
require 'sinatra/content_for'

begin
  require 'sinatra/reloader' if development?
rescue LoadError
  warn "Sinatra reloader is not available\n gem install sinatra-contrib"
end

# Carregar Tabler.io via CDN para estilização
TABLER_CSS = 'https://cdn.jsdelivr.net/npm/@tabler/core@1.0.0-beta17/dist/css/tabler.min.css'
TABLER_JS = 'https://cdn.jsdelivr.net/npm/@tabler/core@1.0.0-beta17/dist/js/tabler.min.js'

# Caminho onde estão os artigos
BLOG_DIR = './source/posts'

configure :development do
  set :server, :webrick
  set :reload_templates, true
  set :show_exceptions, :after_handler
  set :raise_errors, true
end

$state = {}

helpers do
  def list_articles
    $state[:articles] ||=
      begin
        articles =
          Dir.glob("#{BLOG_DIR}/*.{md,markdown,html}").map do |file|
            filename = File.basename(file)

            {
              id: Digest::MD5.hexdigest(File.basename(file)),
              title: File.basename(filename, '.*').sub(/^(\d{4}-\d{2}-\d{2}-)/, '').gsub(/(-|\.html)/, ' ').capitalize,
              filename: File.basename(file),
              path: Pathname.new(file).realpath.to_s,
              created_at: Time.parse(filename.scan(/\d{4}-\d{2}-\d{2}/).first)
            }
          end

        articles.each do |article|
          content = File.read(article[:path])

          article[:title] = String(content.scan(/^title: (?<title>.*)$/).flatten.first)
          article[:published] = String(content.scan(/^published: (?<published>.*)/).flatten.first) != 'false'
          article[:category] = String(content.scan(/^category: (?<category>.*)$/).flatten.first)
          article[:tags] = String(content.scan(/^tags: (?<tags>.*)$/).flatten.first).split(',').map(&:strip)
        end

        pp articles

        $state[:articles] = articles
      end
  end
end

get '/' do
  redirect 'articles'
end

get '/articles' do
  @articles = list_articles
  @articles = @articles.filter { |article| article[:published] == (params[:state] != 'draft') }

  erb :articles
end

get '/articles/:id' do
  @article = list_articles.find { |article| article[:id] == params[:id] }

  filepath = @article[:path]

  if File.exist?(filepath)
    @article_content = File.read(filepath)
    erb :view_article
  else
    status 404
    'Article not found!'
  end
end

get '/articles/:id/edit' do
  @article = list_articles.find { |article| article[:id] == params[:id] }
  filepath = @article[:path]

  if File.exist?(filepath)
    @article_content = File.read(filepath)
    erb :edit_article
  else
    status 404
    'Article not found!'
  end
end

# Salvar alterações no artigo
post '/articles/:id/edit' do
  @article = list_articles.find { |article| article[:id] == params[:id] }
  filepath = @article[:path]

  if File.exist?(filepath)
    File.write(filepath, params[:content], newline: :universal)
    @flash = 'Article updated successfully!'
    redirect "/articles/#{params[:id]}/edit"
  else
    status 404
    'Article not found!'
  end
end

__END__

@@layout
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Middleman Admin</title>
  <link href="https://cdn.jsdelivr.net/npm/@tabler/core/dist/css/tabler.min.css" rel="stylesheet">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@latest/dist/tabler-icons.min.css" />
  <link href="https://cdn.jsdelivr.net/npm/@tabler/core/dist/css/tabler-vendors.min.css" rel="stylesheet">
  <style>
    .page-wrapper {
      flex: 1;
      display: flex;
      flex-direction: column;
      margin-left: 15rem;
    }
    header.navbar {
      margin-left: 15rem;
    }
    .ti-xs {
      font-size: .75rem;
    }
    .ti-sm {
      font-size: .875rem;
    }
    .ti-md {
      font-size: 1.3rem;
    }
    .ti-lg {
      font-size: 2rem;
    }

    .ti-xl {
      font-size: 3rem;
    }
  </style>
</head>

<body>
  <aside class="navbar navbar-vertical navbar-expand-lg" data-bs-theme="dark">
    <div class="container-fluid">
      <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#sidebar-menu" aria-controls="sidebar-menu" aria-expanded="false" aria-label="Toggle navigation">
        <span class="navbar-toggler-icon"></span>
      </button>
      <div class="navbar-brand navbar-brand-autodark">
        <a href="/" class="text-decoration-none text-light" style="text-decoration: none">
          <i class="ti ti-layout-dashboard"></i>
          Middleman
        </a>
      </div>
      <div class="navbar-nav flex-row d-lg-none">
        <div class="nav-item d-none d-lg-flex me-3">
          <div class="btn-list">
            <a href="https://github.com/tabler/tabler" class="btn" target="_blank" rel="noreferrer">
              <!-- Download SVG icon from http://tabler-icons.io/i/brand-github -->
              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="icon"><path stroke="none" d="M0 0h24v24H0z" fill="none"/><path d="M9 19c-4.3 1.4 -4.3 -2.5 -6 -3m12 5v-3.5c0 -1 .1 -1.4 -.5 -2c2.8 -.3 5.5 -1.4 5.5 -6a4.6 4.6 0 0 0 -1.3 -3.2a4.2 4.2 0 0 0 -.1 -3.2s-1.1 -.3 -3.5 1.3a12.3 12.3 0 0 0 -6.2 0c-2.4 -1.6 -3.5 -1.3 -3.5 -1.3a4.2 4.2 0 0 0 -.1 3.2a4.6 4.6 0 0 0 -1.3 3.2c0 4.6 2.7 5.7 5.5 6c-.6 .6 -.6 1.2 -.5 2v3.5" /></svg>
              Source code
            </a>
            <a href="https://github.com/sponsors/codecalm" class="btn" target="_blank" rel="noreferrer">
              <!-- Download SVG icon from http://tabler-icons.io/i/heart -->
              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="icon text-pink"><path stroke="none" d="M0 0h24v24H0z" fill="none"/><path d="M19.5 12.572l-7.5 7.428l-7.5 -7.428a5 5 0 1 1 7.5 -6.566a5 5 0 1 1 7.5 6.572" /></svg>
              Sponsor
            </a>
          </div>
        </div>
      </div>
      <div class="collapse navbar-collapse" id="sidebar-menu">
        <ul class="navbar-nav pt-lg-3">
          <li class="nav-item">
            <a class="nav-link" href="/articles" >
              <span class="nav-link-icon d-md-none d-lg-inline-block">
                <i class="ti ti-article ti-md"></i>
              </span>
              <span class="nav-link-title">Articles</span>
            </a>
          </li>
          <li class="nav-item">
            <a class="nav-link" href="/articles?state=draft" >
              <span class="nav-link-icon d-md-none d-lg-inline-block">
                <i class="ti ti-notes-off ti-md"></i>
              </span>
              <span class="nav-link-title">Drafts</span>
            </a>
          </li>
          <li class="nav-item">
            <a class="nav-link" href="/pages" >
              <span class="nav-link-icon d-md-none d-lg-inline-block">
                <i class="ti ti-app-window ti-md"></i>
              </span>
              <span class="nav-link-title">Pages</span>
            </a>
          </li>
          <li class="nav-item">
            <a class="nav-link" href="/datas" >
              <span class="nav-link-icon d-md-none d-lg-inline-block">
                <i class="ti ti-file-database ti-md"></i>
              </span>
              <span class="nav-link-title">Datas</span>
            </a>
          </li>
          <li class="nav-item">
            <a class="nav-link" href="/datas" >
              <span class="nav-link-icon d-md-none d-lg-inline-block">
                <i class="ti ti-photo ti-md"></i>
              </span>
              <span class="nav-link-title">Static Files</span>
            </a>
          </li>
          <li class="nav-item">
            <a class="nav-link" href="/datas" >
              <span class="nav-link-icon d-md-none d-lg-inline-block">
                <i class="ti ti-settings-2 ti-md"></i>
              </span>
              <span class="nav-link-title">Settings</span>
            </a>
          </li>
        </ul>
      </div>
    </div>
  </aside>

  <header class="navbar navbar-expand-md d-none d-lg-flex d-print-none">
    <div class="container-xl">
      <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbar-menu" aria-controls="navbar-menu" aria-expanded="false" aria-label="Toggle navigation">
        <span class="navbar-toggler-icon"></span>
      </button>
      <div class="navbar-nav flex-row order-md-last">
      </div>
      <div class="collapse navbar-collapse" id="navbar-menu">
        <div>
          <form action="/" method="get" autocomplete="off" novalidate>
            <div class="input-icon">
              <span class="input-icon-addon">
                <!-- Download SVG icon from http://tabler-icons.io/i/search -->
                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="icon"><path stroke="none" d="M0 0h24v24H0z" fill="none"/><path d="M10 10m-7 0a7 7 0 1 0 14 0a7 7 0 1 0 -14 0" /><path d="M21 21l-6 -6" /></svg>
              </span>
              <input type="text" value="" class="form-control" placeholder="Search…" aria-label="Search in website">
            </div>
          </form>
        </div>
      </div>
    </div>
  </header>

  <div class="page-wrapper">
    <div class="page-header d-print-none">
      <div class="container-xl">
        <%= yield_content :page_header %>
      </div>
    </div>
    <div class="page page-body">
      <div class="container-xl">
        <%= yield %>
      </div>
    </div>
  </div>
  <script src="<%= TABLER_JS %>"></script>
</body>
</html>

@@articles
<% content_for :page_header do %>
  <div class="row g-2 align-items-center">
    <div class="col">
      <!-- Page pre-title -->
      <div class="page-pretitle">
        List of all
      </div>
      <h2 class="page-title">
        Articles
      </h2>
    </div>
    <!-- Page title actions -->
    <div class="col-auto ms-auto d-print-none">
      <div class="btn-list">
        <!-- span class="d-none d-sm-inline">
          <a href="#" class="btn">
            New view
          </a>
        </span -->
        <a href="#" class="btn btn-primary d-none d-sm-inline-block" data-bs-toggle="modal" data-bs-target="#modal-report">
          <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="icon"><path stroke="none" d="M0 0h24v24H0z" fill="none"></path><path d="M12 5l0 14"></path><path d="M5 12l14 0"></path></svg>
          New Article
        </a>
      </div>
    </div>
  </div>
<% end %>

<div class="card">
  <div class="card-header">
    <h3 class="card-title">Articles</h3>
  </div>
  <div class="card-body">
    <table class="table table-hover">
      <thead>
        <tr>
          <th>Title</th>
          <th>State</th>
          <th>Created</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>
        <% @articles.each do |article| %>
          <tr>
            <td><a href="/articles/<%= article[:id]%>" title="<%= article[:filename] %>"><%= article[:title] %></a></td>
            <td>
              <% if article[:published] %>
                <span class="badge badge-sm text-light bg-primary">published</span>
              <% else %>
                <span class="badge badge-sm text-light bg-secondary">draft</span>
              <% end %>
            </td>
            <td><%= article[:created_at].strftime("%Y-%m-%d %H:%M") %></td>
            <td>
              <!-- a href="/articles/<%= article[:id] %>" class="btn btn-sm btn-primary">View</a -->
              <a href="/articles/<%= article[:id] %>/edit" class="btn btn-sm btn-secondary">Edit</a>
              <a href="/articles/<%= article[:id] %>/delete" class="btn btn-sm btn-danger">Edit</a>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
</div>

@@view_article
<% content_for :page_header do %>
  <div class="row g-2 align-items-center">
    <div class="col">
      <!-- Page pre-title -->
      <div class="page-pretitle">
        View Article
      </div>
      <h2 class="page-title">
      Article "<%= @article_content.scan(/^title: (?<title>.*)$/).flatten.first %>"
      </h2>
    </div>
    <!-- Page title actions -->
    <div class="col-auto ms-auto d-print-none">
      <div class="btn-list">
        <span class="d-none d-sm-inline">
          <a href="/articles" class="btn">
            Back to List
          </a>
        </span>
        <a href="/articles/<%= @article[:id] %>/edit" class="btn btn-primary d-none d-sm-inline-block">
          <i class="ti ti-pencil"></i>
          Edit Article
        </a>
      </div>
    </div>
  </div>
<% end %>

<div class="card">
  <div class="card-header">
    <h3 class="card-title">File Content</h3>
  </div>
  <div class="card-body">
    <pre><%= @article_content %></pre>
    <a href="/admin/articles" class="btn btn-primary">Back to List</a>
  </div>
</div>

@@edit_article
<% content_for :page_header do %>
  <div class="row g-2 align-items-center">
    <div class="col">
      <!-- Page pre-title -->
      <div class="page-pretitle">
        Edit Article
      </div>
      <h2 class="page-title">
      Article "<%= @article_content.scan(/^title: (?<title>.*)$/).flatten.first %>"
      </h2>
    </div>
    <!-- Page title actions -->
    <div class="col-auto ms-auto d-print-none">
      <div class="btn-list">
        <span class="d-none d-sm-inline">
          <a href="/articles" class="btn">
            Back to List
          </a>
        </span>
      </div>
    </div>
  </div>
<% end %>

<div class="card">
  <div class="card-header">
    <h3 class="card-title">File Content: <code><%= @article[:filename] %></code></h3>
  </div>
  <div class="card-body">
    <form action="/articles/<%= @article[:id] %>/edit" method="POST">
      <div class="mb-3">
        <textarea class="form-control" id="content" name="content" rows="20"><%= @article_content %></textarea>
      </div>
      <button type="submit" class="btn btn-primary">Save Changes</button>
      <a href="/articles" class="btn btn-secondary">Cancel</a>
    </form>
  </div>
</div>

<link rel="stylesheet" href="https://cdn.jsdelivr.net/simplemde/latest/simplemde.min.css">
<script src="https://cdn.jsdelivr.net/simplemde/latest/simplemde.min.js"></script>

<script>
  var simplemde = new SimpleMDE({ element: document.getElementById("content") });
</script>
