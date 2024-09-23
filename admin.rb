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
ROOT_DIR = './'
DATA_DIR = './data'
BLOG_DIR = './source/posts'

configure :development do
  set :server, :webrick
  set :reload_templates, true
  set :show_exceptions, :after_handler
  set :raise_errors, true
end

$state = {}

helpers do
  def articles
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

  def statics_meta
    {
      image: { name: 'Images', type: :image, pattern: /\.(jpg|png|gif|ico|webp)$/, mode: :read_only },
      stylesheet: { name: 'Stylesheets', type: :stylesheet, pattern: /\.(css|scss|sass|less)$/, mode: :read_write },
      javascript: { name: 'Javascripts', type: :javascript, pattern: /\.(js|ts|coffee)$/, mode: :read_write },
      audio: { name: 'Audios', type: :audio, pattern: /\.(mp3|ogg|wav)$/, mode: :read_only },
      video: { name: 'Videos', type: :video, pattern: /\.(webm|mp4|avi)$/, mode: :read_only },
      font: { name: 'Fonts', type: :font, pattern: /\.(woff|woff2|ttf|otf)$/, mode: :read_only },
      unknow: { name: 'Unknow', type: :unknow, pattern: /$/, mode: :read_only }
    }
  end

  def statics
    $state[:statics] ||=
      begin
        type_by_extension_of = lambda { |filename|
          case filename
          when statics_meta.dig(:image, :pattern) then statics_meta.dig(:image, :type)
          when statics_meta.dig(:stylesheet, :pattern) then statics_meta.dig(:stylesheet, :type)
          when statics_meta.dig(:javascript, :pattern) then statics_meta.dig(:javascript, :type)
          when statics_meta.dig(:audio, :pattern) then statics_meta.dig(:audio, :type)
          when statics_meta.dig(:video, :pattern) then statics_meta.dig(:video, :type)
          when statics_meta.dig(:font, :pattern) then statics_meta.dig(:font, :type)
          else statics_meta.dig(:unknow, :type)
          end
        }

        statics =
          Dir.glob("#{ROOT_DIR}/source/{stylesheets,javascripts,images}/**/*.{jpg,png,gif,ico,webp,css,scss,sass,less,mp3,avi,mp4,ogg,webm}").map do |file|
            filename = File.basename(file)
            file_type = type_by_extension_of.call(filename)

            {
              id: Digest::MD5.hexdigest(file),
              filename: filename,
              type: file_type,
              mode: statics_meta.dig(file_type, :mode),
              path: Pathname.new(file).realpath.to_s,
              created_at: File.ctime(file)
            }
          end

        pp statics

        $state[:statics] = statics
      end
  end
end

get '/' do
  redirect 'articles'
end

get '/statics' do
  params[:type] ||= :stylesheet

  @statics = statics
  @statics = @statics.filter { |file| file[:type] == params[:type].to_sym }

  erb :statics
end

get '/statics/:id' do
  @static = statics.find { |static| static[:id] == params[:id] }

  filepath = @static[:path]

  if File.exist?(filepath)
    @static_content = File.read(filepath)
    erb :view_static
  else
    status 404
    'Static file not found!'
  end
end

get '/articles' do
  @articles = articles
  @articles = @articles.filter { |article| article[:published] == (params[:state] != 'draft') }

  erb :articles
end

post '/articles' do
  filename = "#{BLOG_DIR}/#{Time.now.strftime('%Y-%m-%d')}-#{params[:title].downcase.gsub(' ', '-')}.html.markdown"

  File.write(filename, <<~MD, newline: :universal)
    ---
    title: #{params[:title]}
    published: #{params[:published] || 'false'}
    category: #{params[:category]}
    tags: #{params[:tags]}
    ---

    #{params[:content]}
  MD

  redirect "/articles/#{Digest::MD5.hexdigest(File.basename(filename))}"
end

get '/articles/new' do
  erb :new_article
end

get '/articles/:id' do
  @article = articles.find { |article| article[:id] == params[:id] }

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
  @article = articles.find { |article| article[:id] == params[:id] }
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
  @article = articles.find { |article| article[:id] == params[:id] }
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
  <aside class="navbar navbar-vertical navbar-expand-lg overflow-auto" data-bs-theme="dark">
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
          <li class="nav-item dropdown">
            <a class="nav-link dropdown-toggle" href="#navbar-blogs" data-bs-toggle="dropdown" data-bs-auto-close="false" role="button" aria-expanded="false">
              <span class="nav-link-icon d-md-none d-lg-inline-block">
                <i class="ti ti-article ti-md"></i>
              </span>
              <span class="nav-link-title">Blog</span>
            </a>
            <div class="dropdown-menu hide" data-bs-popper="static">
              <a class="dropdown-item" href="/articles">
                Published
              </a>
              <a class="dropdown-item" href="/articles?state=draft">
                Drafts
              </a>
            </div>
          </li>
          <li class="nav-item dropdown">
            <a class="nav-link dropdown-toggle" href="#navbar-pages" data-bs-toggle="dropdown" data-bs-auto-close="false" role="button" aria-expanded="false">
              <span class="nav-link-icon d-md-none d-lg-inline-block">
                <i class="ti ti-app-window ti-md"></i>
              </span>
              <span class="nav-link-title">Pages</span>
            </a>
            <div class="dropdown-menu hide" data-bs-popper="static">
              <a class="dropdown-item" href="/pages">
                Page Files
              </a>
              <a class="dropdown-item" href="/pages?type=partials">
                Partials
              </a>
              <a class="dropdown-item" href="/pages?type=layouts">
                Layouts
              </a>
            </div>
          </li>
          <li class="nav-item dropdown">
            <a class="nav-link dropdown-toggle" href="#navbar-statics" data-bs-toggle="dropdown" data-bs-auto-close="false" role="button" aria-expanded="false">
              <span class="nav-link-icon d-md-none d-lg-inline-block">
                <i class="ti ti-photo ti-md"></i>
              </span>
              <span class="nav-link-title">Static Files</span>
            </a>
            <div class="dropdown-menu hide" data-bs-popper="static">
              <a class="dropdown-item" href="/statics?type=stylesheet">
                Stylesheets
              </a>
              <a class="dropdown-item" href="/statics?type=javascript">
                Javascripts
              </a>
              <a class="dropdown-item" href="/statics?type=image">
                Images
              </a>
              <a class="dropdown-item" href="/statics?type=audio">
                Audios
              </a>
              <a class="dropdown-item" href="/statics?type=videos">
                Videos
              </a>
              <a class="dropdown-item" href="/statics?type=fonts">
                Fonts
              </a>
            </div>
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

@@statics
<% content_for :page_header do %>
  <div class="row g-2 align-items-center">
    <div class="col">
      <div class="page-pretitle">
        List of all
      </div>
      <h2 class="page-title">
        Static Files
      </h2>
    </div>

    <div class="col-auto ms-auto d-print-none">
      <div class="btn-list">
      <% if statics_meta.dig(params[:type].to_sym, :mode) == :read_only %>
          <a href="#" class="btn btn-primary d-none d-sm-inline-block" data-bs-toggle="modal" data-bs-target="#modal-report">
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="icon"><path stroke="none" d="M0 0h24v24H0z" fill="none"></path><path d="M12 5l0 14"></path><path d="M5 12l14 0"></path></svg>
            Upload Static File
          </a>
        <% else %>
          <a href="#" class="btn btn-primary d-none d-sm-inline-block" data-bs-toggle="modal" data-bs-target="#modal-report">
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="icon"><path stroke="none" d="M0 0h24v24H0z" fill="none"></path><path d="M12 5l0 14"></path><path d="M5 12l14 0"></path></svg>
            Add Static File
          </a>
        <% end %>
      </div>
    </div>
  </div>
<% end %>

<div class="card">
  <div class="card-header">
    <h3 class="card-title">Static Files</h3>
  </div>
  <div class="card-body">

    <% if @statics.count > 0 %>
      <table class="table table-hover">
        <thead>
          <tr>
            <th>Filename</th>
            <th>Type</th>
            <th>Created At</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <% @statics.each do |static| %>
            <tr>
              <td><a href="/statics/<%= static[:id]%>" title="<%= static[:filename] %>"><%= static[:filename] %></a></td>
              <td> <span class="badge badge-sm text-light bg-primary"><%= static[:type] %></span </td>
              <td><%= static[:created_at].strftime("%Y-%m-%d %H:%M") %></td>
              <td>
                <a href="/statics/<%= static[:id] %>/edit" class="btn btn-sm btn-secondary">Edit</a>
                <a href="/statics/<%= static[:id] %>/delete" class="btn btn-sm btn-danger">Edit</a>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    <% else %>
      <div class="empty">
        <p class="empty-title h3 text-info">No static files found</p>
        <p class="empty-subtitle text-muted">
          Static files are files that are not processed by Middleman.
        </p>
      </div>
    <% end %>
  </div>
</div>

@@view_static
<% content_for :page_header do %>
  <div class="row g-2 align-items-center">
    <div class="col">
      <!-- Page pre-title -->
      <div class="page-pretitle">
        View Article
      </div>
      <h2 class="page-title">
      Static File "<%= @static[:filename] %>"
      </h2>
    </div>
    <!-- Page title actions -->
    <div class="col-auto ms-auto d-print-none">
      <div class="btn-list">
        <span class="d-none d-sm-inline">
          <a href="/statics" class="btn">
            Back to List
          </a>
        </span>
        <% if @static[:mode] == :read_write %>
          <a href="/statics/<%= @static[:id] %>/edit" class="btn btn-primary d-none d-sm-inline-block">
            <i class="ti ti-pencil"></i>
            Edit Static File
          </a>
        <% end %>
      </div>
    </div>
  </div>
<% end %>

<div class="card">
  <div class="card-header">
    <h3 class="card-title">File Content</h3>
  </div>
  <div class="card-body">
    <% if @static[:mode] == :read_write %>
      <pre><%= @static_content %></pre>
    <% elsif @static[:type] == :image %>
      <img src="<%= @static[:path] %>" class="card-img-top" alt="<%= @static[:filename] %>" />
    <% elsif @static[:type] == :audio %>
      <audio controls>
        <source src="<%= @static[:path] %>" />
        Your browser does not support the audio element.
      </audio>
    <% elsif @static[:type] == 'video' %>
      <video controls>
        <source src="<%= @static[:path] %>" />
      </video>
    <% end %>
    <p>
      <a href="/statics" class="btn btn-primary">Back to List</a>
    </p>
  </div>
</div>


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
        <a href="/articles/new" class="btn btn-primary d-none d-sm-inline-block">
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

@@new_article
<% content_for :page_header do %>
  <div class="row g-2 align-items-center">
    <div class="col">
      <!-- Page pre-title -->
      <div class="page-pretitle">
        Creating a New
      </div>
      <h2 class="page-title">
        Article
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
    <h3 class="card-title">New Article</h3>
  </div>
  <div class="card-body">
    <form action="/articles" method="POST">
      <div class="mb-3">
        <label for="title" class="form-label mb-1">Title</label>
        <input type="text" class="form-control" id="title" name="title" value="">
      </div>
      <div class="mb-3">
        <label for="category" class="form-label mb-1">Category</label>
        <input type="text" class="form-control" id="category" name="category" value="">
      </div>
      <div class="mb-3">
        <label for="tags" class="form-label mb-1">Tags</label>
        <input type="text" class="form-control" id="tags" name="tags" value="">
      </div>
      <div class="mb-3">
        <label for="published" class="form-label mb-1">Published</label>
        <input type="checkbox" class="form-check-input" id="published" name="published" value="true" >
      </div>
      <div class="mb-3">
        <label for="content" class="form-label mb-1">Article Content</label>
        <textarea class="form-control" id="content" name="content" rows="20"></textarea>
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
