# =====================================================================================================
# Template for generating an opinionated base Rails 4.0.2 project using Ruby 2.1.0
# =====================================================================================================

# ----- Helper functions and variables ----------------------------------------------------------------

require 'securerandom'

def generate_token
  SecureRandom.hex(64)
end

def from_gem(source, destination = nil)
  base_path = "#{File.expand_path File.dirname(__FILE__)}/../includes"
  file_name = source.split('/').last

  if destination.present? && file_name != destination
    if destination.include? '/'
      run "mkdir -p #{destination}"
    end
  end

  run "cp #{base_path}/#{file_name} #{destination}"
end

app_name_upper = app_name.upcase
app_name_class = app_name.humanize

# ----- Create the git repo ----------------------------------------------------------------------------

# Repo exists already
# puts
# say_status  'git', 'Creating a new local git repo...', :yellow
# puts        '-'*80, ''; sleep 0.25

# git :init
# git add: '.'
# git commit: "-m 'Initial commit'"

# ----- Modify the .gitignore file --------------------------------------------------------------------

puts
say_status  'root', 'Modifying the .gitignore file...', :yellow
puts        '-'*80, ''; sleep 0.25

append_to_file '.gitignore' do <<-TEXT

# Ignore OS and editor files.
.DS_Store
*/**.DS_Store
._*
.*.sw*
*~
.idea/

# Ignore the main environment file.
.env
TEXT
end

git add: '.'
git commit: "-m 'Add common OS and editor files to the .gitignore file'"

# ----- Create a few root files -----------------------------------------------------------------------

puts
say_status  'root', 'Creating root files...', :yellow
puts        '-'*80, ''; sleep 0.25

# Don't add the ruby-version
# file '.ruby-version', '2.1.0'

# git add:    '.'
# git commit: "-m 'Add .ruby-version file for common ruby version managers'"

file 'Procfile' do <<-CODE
web: puma -C config/puma.rb
worker: sidekiq -C config/sidekiq.yml
CODE
end

git add:    '.'
git commit: "-m 'Add a basic Procfile to start the puma and sidekiq processes'"

# ----- Create an .env file ---------------------------------------------------------------------------

puts
say_status  'root', 'Creating .env file...', :yellow
puts        '-'*80, ''; sleep 0.25

file '.env' do <<-CODE
#{app_name_upper}_TOKEN_RAILS_SECRET: #{generate_token}

#{app_name_upper}_SMTP_ADDRESS: smtp.gmail.com
#{app_name_upper}_SMTP_PORT: 587
#{app_name_upper}_SMTP_DOMAIN: gmail.com
#{app_name_upper}_SMTP_USERNAME: #{app_name}@gmail.com
#{app_name_upper}_SMTP_PASSWORD: thebestpassword
#{app_name_upper}_SMTP_AUTH: plain
#{app_name_upper}_SMTP_STARTTTLS_AUTO: true

#{app_name_upper}_ACTION_MAILER_HOST: localhost:3000
#{app_name_upper}_ACTION_MAILER_DEFAULT_EMAIL: info@#{app_name}.com

#{app_name_upper}_DATABASE_NAME: #{app_name}
#{app_name_upper}_DATABASE_HOST: localhost
#{app_name_upper}_DATABASE_POOL: 25
#{app_name_upper}_DATABASE_TIMEOUT: 5000
#{app_name_upper}_DATABASE_USERNAME: postgres
#{app_name_upper}_DATABASE_PASSWORD: supersecrets

#{app_name_upper}_CACHE_HOST: localhost
#{app_name_upper}_CACHE_PORT: 6379
#{app_name_upper}_CACHE_DATABASE: 0

#{app_name_upper}_PUMA_THREADS_MIN: 0
#{app_name_upper}_PUMA_THREADS_MAX: 1
#{app_name_upper}_PUMA_WORKERS: 0

#{app_name_upper}_SIDEKIQ_CONCURRENCY: 25
CODE
end

# ----- Modify the secret token -----------------------------------------------------------------------

gsub_file 'config/initializers/secret_token.rb', /'\w{128}'/, "ENV['#{app_name_upper}_TOKEN_RAILS_SECRET']"


# ----- Modify the application file -------------------------------------------------------------------

puts
say_status  'config', 'Modifying the application file...', :yellow
puts        '-'*80, ''; sleep 0.25

inject_into_file 'config/application.rb', after: "automatically loaded.\n" do <<-CODE
    config.x.track.google_analytics = ''
    config.x.track.disqus_shortname = 'test-#{app_name}'
    config.x.email.default_to = ENV['#{app_name_upper}_ACTION_MAILER_DEFAULT_EMAIL']

    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      :address              => ENV['#{app_name_upper}_SMTP_ADDRESS'],
      :port                 => ENV['#{app_name_upper}_SMTP_PORT'].to_i,
      :domain               => ENV['#{app_name_upper}_SMTP_DOMAIN'],
      :user_name            => ENV['#{app_name_upper}_SMTP_USERNAME'],
      :password             => ENV['#{app_name_upper}_SMTP_PASSWORD'],
      :authentication       => ENV['#{app_name_upper}_SMTP_AUTH'].to_sym,
      :enable_starttls_auto => ENV['#{app_name_upper}_SMTP_STARTTTLS_AUTO'] == 'true'
    }

    config.action_mailer.default_url_options = { host: ENV['#{app_name_upper}_ACTION_MAILER_HOST'] }

    config.cache_store = :redis_store, { host: ENV['#{app_name_upper}_CACHE_HOST'],
                                         port: ENV['#{app_name_upper}_CACHE_PORT'].to_i,
                                         db: ENV['#{app_name_upper}_CACHE_DATABASE'].to_i,
                                         namespace: '#{app_name}::cache'
                                       }
CODE
end

gsub_file 'config/application.rb', "# config.time_zone = 'Central Time (US & Canada)'", "config.time_zone = 'Pacific Time (US & Canada)'"

append_file 'config/application.rb' do <<-'FILE'

ActionView::Base.field_error_proc = Proc.new do |html_tag, instance|
  if html_tag =~ /\<label/
    html_tag
  else
    errors = Array(instance.error_message).join(',')
    %(#{html_tag}<p class="validation-error"> #{errors}</p>).html_safe
  end
end
FILE
end

git add:    '.'
git commit: "-m 'Add tweakable settings, update the timezone and change the way validation errors are shown'"

# ----- Modify the config files -----------------------------------------------------------------------

puts
say_status  'config', 'Modifying the config files...', :yellow
puts        '-'*80, ''; sleep 0.25

gsub_file 'config/database.yml', /.*\n/, ''
append_file 'config/database.yml' do <<-FILE
development: &default
  adapter: postgresql
  database: <%= ENV['#{app_name_upper}_DATABASE_NAME'] %>
  host: <%= ENV['#{app_name_upper}_DATABASE_HOST'] %>
  pool: <%= ENV['#{app_name_upper}_DATABASE_POOL'] %>
  timeout: <%= ENV['#{app_name_upper}_DATABASE_TIMEOUT'] %>
  username: <%= ENV['#{app_name_upper}_DATABASE_USERNAME'] %>
  password: <%= ENV['#{app_name_upper}_DATABASE_PASSWORD'] %>

test:
  <<: *default
  database: <%= ENV['#{app_name_upper}_DATABASE_NAME'] %>_test

staging:
  <<: *default

production:
  <<: *default
FILE
end

git add:    '.'
git commit: "-m 'Dry up the database settings'"

file 'config/puma.rb', <<-CODE
threads ENV['#{app_name_upper}_PUMA_THREADS_MIN'].to_i,ENV['#{app_name_upper}_PUMA_THREADS_MAX'].to_i
workers ENV['#{app_name_upper}_PUMA_WORKERS'].to_i

pidfile '/tmp/puma.pid'

if ENV['RAILS_ENV'] == 'production'
  bind 'unix:///tmp/puma.sock'
else
  port '3000'
end

restart_command 'bundle exec puma'

on_worker_boot do
  require 'active_record'
  config_path = File.expand_path('../database.yml', __FILE__)

  ActiveRecord::Base.connection.disconnect! rescue ActiveRecord::ConnectionNotEstablished
  ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'] || YAML.load_file(config_path)[ENV['RAILS_ENV']])
end
CODE

git add:    '.'
git commit: "-m 'Add the puma config'"

file 'config/sidekiq.yml', <<-CODE
---
:pidfile: /tmp/sidekiq.pid
:concurrency: <%= ENV['#{app_name_upper}_SIDEKIQ_CONCURRENCY'].to_i %>
:queues:
  - default
CODE

git add:    '.'
git commit: "-m 'Add the sidekiq config'"

file 'config/sitemap.rb', <<-'CODE'
# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "http://www.app_name.com"

SitemapGenerator::Sitemap.create do
  # Put links creation logic here.
  #
  # The root path '/' and sitemap index file are added automatically for you.
  # Links are added to the Sitemap in the order they are specified.
  #
  # Examples:
  #
  # add root_path
  # add foobar_path, priority: 0.7, changefreq: 'daily'
  #
  # Iteration example:
  #
  # Article.published.find_each do |article|
  #   add article_path("#{article.id}-#{article.permalink}"), priority: 0.9, lastmod: article.updated_at
  # end
end
CODE

gsub_file 'config/sitemap.rb', 'app_name', app_name

git add:    '.'
git commit: "-m 'Add the sitemap config'"

file 'config/schedule.rb', <<-CODE
every 1.day, at: '4:00 am' do
  rake '-s sitemap:refresh'
end
CODE

git add:    '.'
git commit: "-m 'Add a sitemap rake task that occurs at 4am'"

# ----- Modify the environment files ------------------------------------------------------------------

puts
say_status  'Config', 'Modifying the environment files...', :yellow
puts        '-'*80, ''; sleep 0.25

file 'config/environments/staging.rb', <<-CODE
require_relative 'production.rb'

#{app_name_class}::Application.configure do
  config.x.track.google_analytics = ''
  config.x.track.disqus_shortname = 'test-#{app_name}'
end
CODE

git add:    '.'
git commit: "-m 'Add tweakable settings'"

inject_into_file 'config/environments/production.rb', after: "config/application.rb.\n" do <<-"CODE"
    config.x.track.google_analytics = 'YOUR_UA_CODE'
    config.x.track.disqus_shortname = '#{app_name}'
CODE
end

inject_into_file 'config/environments/production.rb', after: "config.log_level = :info\n" do <<-"CODE"
  config.logger = Logger.new(config.paths['log'].first, 'daily')
CODE
end

inject_into_file 'config/environments/production.rb', after: "%w( search.js )\n" do <<-"CODE"
  config.assets.precompile << Proc.new { |path|
    if path =~ /\.(eot|svg|ttf|woff|png)\z/
      true
    end
  }
CODE
end

git add:    '.'
git commit: "-m 'Add tweakable settings, setup daily log rotation and add fonts/pngs to the asset precompiler'"

# ----- Modify the initializer files ------------------------------------------------------------------

puts
say_status  'config', 'Modifying the initializer files...', :yellow
puts        '-'*80, ''; sleep 0.25

file 'config/initializers/sidekiq.rb', <<-'CODE'
Sidekiq.configure_server do |config|
  config.redis = { url: "redis://#{ENV['app_name_CACHE_HOST']}:#{ENV['app_name_CACHE_PORT']}/#{ENV['app_name_CACHE_DATABASE']}", namespace: "ns_app::sidekiq_#{Rails.env}" }
end

Sidekiq.configure_client do |config|
  config.redis = { url: "redis://#{ENV['app_name_CACHE_HOST']}:#{ENV['app_name_CACHE_PORT']}/#{ENV['app_name_CACHE_DATABASE']}", namespace: "ns_app::sidekiq_#{Rails.env}" }
end
CODE

gsub_file 'config/initializers/sidekiq.rb', 'app_name', app_name_upper
gsub_file 'config/initializers/sidekiq.rb', 'ns_app', app_name

git add:    '.'
git commit: "-m 'Add the sidekiq initializer'"

file 'config/initializers/mini_profiler.rb', <<-CODE
if defined? Rack::MiniProfiler
  # Toggle with ALT+p
  Rack::MiniProfiler.config.start_hidden = true
end
CODE

git add:    '.'
git commit: "-m 'Add the rack mini profiler initializer'"

# ----- Modify the routes file ------------------------------------------------------------------------

puts
say_status  'config', 'Modifying the routes file...', :yellow
puts        '-'*80, ''; sleep 0.25

prepend_file 'config/routes.rb', "require 'sidekiq/web'\n\n"

git add:    '.'
git commit: "-m 'Add sidekiq to the routes file'"

inject_into_file 'config/routes.rb', after: "draw do\n" do <<-CODE
  concern :pageable do
    get 'page/:page', action: :index, on: :collection
  end
CODE
end

git add:    '.'
git commit: "-m 'Add a route concern for pagination'"

# ----- Creating application tasks --------------------------------------------------------------------

puts
say_status  'Tasks', 'Creating application tasks...', :yellow
puts        '-'*80, ''; sleep 0.25

file 'lib/tasks/favicon.rake', <<-'CODE'
namespace :assets do
  desc 'Create favicons from a single base png'
  task favicon: :environment do
    require 'favicon_maker'

    options = {
      versions: [:apple_144, :apple_120, :apple_114, :apple_72, :apple_57, :apple_pre, :apple, :fav_png, :fav_ico],
      custom_versions: {
                         apple_extreme_retina: {
                           filename: 'apple-touch-icon-228x228-precomposed.png', dimensions: '228x228', format: 'png'
                         },
                         speeddial: {
                           filename: 'speeddial-160px.png', dimensions: '160x160', format: 'png'
                         }
                       },
      root_dir: Rails.root,
      input_dir: File.join('app', 'assets', 'favicon'),
      base_image: 'favicon_base.png',
      output_dir: File.join('app', 'assets', 'images'),
      copy: true
    }

    FaviconMaker::Generator.create_versions(options) do |filepath|
      puts "Created favicon: #{filepath}"
    end
  end
end
CODE

git add:    '.'
git commit: "-m 'Add a favicon generator task'"

# ----- Creating application helpers ------------------------------------------------------------------

puts
say_status  'helpers', 'Creating application helpers...', :yellow
puts        '-'*80, ''; sleep 0.25

inject_into_file 'app/helpers/application_helper.rb', after: "ApplicationHelper\n" do <<-CODE
  def title(page_title)
    content_for(:title) { page_title }
  end

  def meta_description(page_meta_description)
    content_for(:meta_description) { page_meta_description }
  end

  def heading(page_heading)
    content_for(:heading) { page_heading }
  end

  def link_to_all_favicons
    capture do
      concat favicon_link_tag 'speeddial-160px.png', rel: 'icon', type: 'image/png'
      concat favicon_link_tag 'favicon.ico', rel: 'icon', type: 'image/x-icon'
      concat favicon_link_tag 'favicon.ico', rel: 'shortcut icon', type: 'image/x-icon'
      concat favicon_link_tag 'favicon.png', rel: 'icon', type: 'image/png'
      concat favicon_link_tag 'apple-touch-icon-228x228-precomposed.png', sizes: '72x72', rel: 'apple-touch-icon-precomposed', type: 'image/png'
      concat favicon_link_tag 'apple-touch-icon-144x144-precomposed.png', sizes: '144x144', rel: 'apple-touch-icon-precomposed', type: 'image/png'
      concat favicon_link_tag 'apple-touch-icon-120x120-precomposed.png', sizes: '120x120', rel: 'apple-touch-icon-precomposed', type: 'image/png'
      concat favicon_link_tag 'apple-touch-icon-114x114-precomposed.png', sizes: '114x114', rel: 'apple-touch-icon-precomposed', type: 'image/png'
      concat favicon_link_tag 'apple-touch-icon-72x72-precomposed.png', sizes: '72x72', rel: 'apple-touch-icon-precomposed', type: 'image/png'
      concat favicon_link_tag 'apple-touch-icon-57x57-precomposed.png', sizes: '57x57', rel: 'apple-touch-icon-precomposed', type: 'image/png'
      concat favicon_link_tag 'apple-touch-icon-precomposed.png', sizes: '57x54', rel: 'apple-touch-icon-precomposed', type: 'image/png'
      concat favicon_link_tag 'apple-touch-icon.png', sizes: '57x54', rel: 'apple-touch-icon', type: 'image/png'
    end
  end

  def humanize_boolean(input)
    input ||= ''

    case input.to_s.downcase
    when 't', 'true'
      'Yes'
    else
      'No'
    end
  end

  def css_for_boolean(input)
    if input
      'success'
    else
      'danger'
    end
  end
CODE
end

git add:    '.'
git commit: "-m 'Add favicon and boolean view helpers'"

# ----- Creating view files ---------------------------------------------------------------------------

puts
say_status  'views', 'Creating view files...', :yellow
puts        '-'*80, ''; sleep 0.25

run 'rm -f app/views/layouts/application.html.erb'

file 'app/views/layouts/application.html.haml', <<-HTML
!!!
%html{lang: "en"}
  %head
    %title= yield :title
    %meta{charset: "utf-8"}/
    %meta{content: "IE=edge,chrome=1", "http-equiv" => "X-UA-Compatible"}/
    %meta{content: "width=device-width, initial-scale=1.0", name: "viewport"}/
    %meta{content: yield :meta_description, name: "description"}/
    = stylesheet_link_tag 'application', media: 'all', 'data-turbolinks-track' => true
    = javascript_include_tag '//ajax.googleapis.com/ajax/libs/jquery/1.10.2/jquery.min.js', 'application', 'data-turbolinks-track' => true
    = csrf_meta_tags
    = link_to_all_favicons
    /[if lt IE 9]
      <script src="//cdnjs.cloudflare.com/ajax/libs/html5shiv/3.7/html5shiv.js"></script>
      <script src="//cdnjs.cloudflare.com/ajax/libs/json3/3.3.0/json3.min.js"></script>
      <script src="//cdnjs.cloudflare.com/ajax/libs/respond.js/1.4.2/respond.js"></script>
  %body
    %header= render 'layouts/navigation'
    %main.container{role: "main"}
      .page-header
        %h1= yield :heading
      = render 'layouts/flash'
      = yield
    %footer
      %hr/
      .container
        = render 'layouts/footer'
    - render 'layouts/google_analytics'
HTML

git add:    '.'
git commit: "-m 'Add new layout view'"

file 'app/views/layouts/_flash.html.haml', <<-'HTML'
- flash.each do |key, msg|
  - unless key == :timedout
    = content_tag :div, class: "alert alert-dismissable alert-#{key}" do
      %button.close{"aria-hidden" => "true", "data-dismiss" => "alert", type: "button"}
        \×
      = msg
HTML

git add:    '.'
git commit: "-m 'Add flash message partial'"

file 'app/views/layouts/_navigation.html.haml', <<-HTML
%nav.navbar.navbar-default
  .container
    .navbar-header
      %button.navbar-toggle{"data-target" => ".navbar-collapse", "data-toggle" => "collapse", type: "button"}
        %span.sr-only Toggle navigation
        %span.icon-bar
        %span.icon-bar
        %span.icon-bar
      = link_to '#{app_name}', '#root_path_would_go_here', class: 'navbar-brand'
    .collapse.navbar-collapse
      %ul.nav.navbar-nav= render 'layouts/navigation_links'
HTML

git add:    '.'
git commit: "-m 'Add navigation partial'"

file 'app/views/layouts/_navigation_links.html.haml', <<-HTML
%li.active
  = link_to 'Bar', '#'
HTML

git add:    '.'
git commit: "-m 'Add navigation links partial'"

file 'app/views/layouts/_footer.html.haml', <<-HTML
%p.text-muted &copy; #{Time.now.year.to_s} #{app_name} - All rights reserved
HTML

git add:    '.'
git commit: "-m 'Add footer partial'"

file 'app/views/layouts/_google_analytics.html.haml', <<-HTML
HTML

git add:    '.'
git commit: "-m 'Add google analytics partial'"

# ----- Creating public files -------------------------------------------------------------------------

puts
say_status  'public', 'Creating public files...', :yellow
puts        '-'*80, ''; sleep 0.25

run 'rm -f public/404.html'
run 'rm -f public/422.html'
run 'rm -f public/500.html'

file 'public/404.html', <<-HTML
<!DOCTYPE html>
<html>
<head>
  <title>Error 404</title>
  <meta charset="utf-8" />
  <style>
  </style>
</head>

<body>
  <h1>Error 404</h1>
</body>
</html>
HTML

file 'public/422.html', <<-HTML
<!DOCTYPE html>
<html>
<head>
  <title>Error 422</title>
  <meta charset="utf-8" />
  <style>
  </style>
</head>

<body>
  <h1>Error 422</h1>
</body>
</html>
HTML

file 'public/500.html', <<-HTML
<!DOCTYPE html>
<html>
<head>
  <title>Error 500</title>
  <meta charset="utf-8" />
  <style>
  </style>
</head>

<body>
  <h1>Error 500</h1>
</body>
</html>
HTML

file 'public/502.html', <<-HTML
<!DOCTYPE html>
<html>
<head>
  <title>Error 502</title>
  <meta charset="utf-8" />
  <style>
  </style>
</head>

<body>
  <h1>Error 502</h1>
</body>
</html>
HTML

git add:    '.'
git commit: "-m 'Add public 404, 422, 500 and 502 error pages'"

# ----- Modifying sass files --------------------------------------------------------------------------

puts
say_status  'assets', 'Modifying sass files...', :yellow
puts        '-'*80, ''; sleep 0.25

run 'mv app/assets/stylesheets/application.css app/assets/stylesheets/application.css.scss'

git add:    '.'
git commit: "-m 'Rename application.css to application.scss'"
git add:    '-u'

inject_into_file 'app/assets/stylesheets/application.css.scss',
                 " *= require font-awesome\n",
                 before: " *= require_self\n"

git add:    '.'
git commit: "-m 'Add font-awesome to the application.scss file'"

append_file 'app/assets/stylesheets/application.css.scss' do <<-SCSS

// Core variables and mixins
@import "bootstrap/variables";
@import "bootstrap/mixins";

// Reset
@import "bootstrap/normalize";
@import "bootstrap/print";

// Core CSS
@import "bootstrap/scaffolding";
@import "bootstrap/type";
@import "bootstrap/code";
@import "bootstrap/grid";
@import "bootstrap/tables";
@import "bootstrap/forms";
@import "bootstrap/buttons";

// Components
@import "bootstrap/component-animations";
// @import "bootstrap/glyphicons";
@import "bootstrap/dropdowns";
@import "bootstrap/button-groups";
@import "bootstrap/input-groups";
@import "bootstrap/navs";
@import "bootstrap/navbar";
@import "bootstrap/breadcrumbs";
@import "bootstrap/pagination";
@import "bootstrap/pager";
@import "bootstrap/labels";
@import "bootstrap/badges";
@import "bootstrap/jumbotron";
@import "bootstrap/thumbnails";
@import "bootstrap/alerts";
@import "bootstrap/progress-bars";
@import "bootstrap/media";
@import "bootstrap/list-group";
@import "bootstrap/panels";
@import "bootstrap/wells";
@import "bootstrap/close";

// Components w/ JavaScript
@import "bootstrap/modals";
@import "bootstrap/tooltip";
@import "bootstrap/popovers";
@import "bootstrap/carousel";

// Utility classes
@import "bootstrap/utilities";
@import "bootstrap/responsive-utilities";

.alert-notice {
  @extend .alert-success;
}

.alert-alert {
  @extend .alert-danger;
}

img {
  @extend .img-responsive;
  margin: 0 auto;
}

.validation-error {
  margin-top: 2px;
  color: $brand-danger;
  font-size: $font-size-small;
}
SCSS
end

# ----- Modifying javascript and coffeescript files ------------------------------------------------------------------

puts
say_status  'assets', 'Modifying javascript and coffeescript files...', :yellow
puts        '-'*80, ''; sleep 0.25

# gsub_file 'app/assets/javascripts/application.js', "//= require jquery\n", ''

# git add:    '.'
# git commit: "-m 'Remove jquery from the application.js file because it is loaded from a CDN'"

inject_into_file 'app/assets/javascripts/application.js',
                 "//= require jquery.turbolinks\n",
                 before: "//= require_tree .\n"

git add:    '.'
git commit: "-m 'Add jquery-turbolinks to the application.js file'"

inject_into_file 'app/assets/javascripts/application.js', before: "//= require_tree .\n" do <<-CODE
//= require bootstrap/affix
//= require bootstrap/alert
//= require bootstrap/button
//= require bootstrap/carousel
//= require bootstrap/collapse
//= require bootstrap/dropdown
//= require bootstrap/modal
//= require bootstrap/popover
//= require bootstrap/scrollspy
//= require bootstrap/tab
//= require bootstrap/tooltip
//= require bootstrap/transition
CODE
end

git add:    '.'
git commit: "-m 'Add bootstrap to the application.js file'"

# ----- Modifying gem file ----------------------------------------------------------------------------

puts
say_status  'root', 'Copying Gemfile...', :yellow
puts        '-'*80, ''; sleep 0.25

run 'rm -f Gemfile'
from_gem 'Gemfile', 'Gemfile'

git add:    '.'
git commit: "-m 'Add basic gems to the Gemfile'"
