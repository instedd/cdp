source 'https://rubygems.org'

gem 'rails', '4.0.2'
gem 'mysql2'
gem 'sass-rails', '~> 4.0.0'
gem 'uglifier', '>= 1.3.0'
gem 'coffee-rails', '~> 4.0.0'
gem 'jquery-rails'
gem 'haml-rails'
gem 'underscore-rails'
gem 'awesome_nested_set', '~> 3.0.0.rc.3'
gem 'csv_builder'
gem 'decent_exposure'

gem 'foreman'

# A newer version breaks instedd-bootstrap
gem 'bootstrap-sass', '2.3.2.1'

gem 'poirot_rails', git: 'https://github.com/instedd/poirot_rails.git', branch: 'master'
gem 'instedd-bootstrap', git: "https://bitbucket.org/instedd/instedd-bootstrap.git", branch: 'master'
gem 'ruby-openid'
gem 'alto_guisso_rails', github: "instedd/alto_guisso_rails", branch: 'master'
gem 'alto_guisso', github: "instedd/alto_guisso", branch: 'master'
gem 'rails_config'
gem 'rest-client'

gem 'cdx-api-elasticsearch', git: "https://github.com/instedd/cdx-api-elasticsearch.git", branch: 'master'
gem 'cdx-sync-server',  git: "https://github.com/instedd/cdx-sync-server.git", branch: 'master'
gem 'geojson_import', git: "https://github.com/flbulgarelli/geojson_import", branch: 'master'

# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem 'turbolinks'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 1.2'

group :doc do
  # bundle exec rake doc:rails generates the API under doc/api.
  gem 'sdoc', require: false
end

# Use ActiveModel has_secure_password
# gem 'bcrypt-ruby', '~> 3.1.2'

# Use unicorn as the app server
# gem 'unicorn'

group :development do
  gem 'capistrano', '~> 3.1.0', require: false
  gem 'capistrano-rails',   '~> 1.1', require: false
  gem 'capistrano-bundler', '~> 1.1', require: false
  gem 'capistrano-rvm',   '~> 0.1', require: false
end

gem 'devise'
gem 'omniauth'
gem 'omniauth-openid'
gem 'cancan'
gem 'elasticsearch'
gem 'bunny'

gem 'oj'
gem 'guid'
gem 'encryptor'

group :development, :test do
  gem 'pry-byebug'
  gem 'pry-rescue'
  gem 'pry-stack_explorer'
  gem 'pry-clipboard'
end

group :test do
  gem 'tire'
  # gem 'factory_girl_rails'
  gem 'faker'
  gem 'machinist'
  gem 'capybara'
  gem 'guard-rspec'
  gem 'rspec'
  gem 'rspec-rails'
  gem 'vcr'
  gem 'webmock'
  gem 'capybara-mechanize'
  gem 'timecop'
  gem 'shoulda'
end
