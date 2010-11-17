require 'rubygems'
require 'compass' #must be loaded before sinatra
require 'sinatra'
require 'haml'    #must be loaded after sinatra
require 'rbbt/util/cachehelper'

CacheHelper.cachedir = File.join(Sinatra::Application.root, 'cache')

def cache(*args, &block)
  CacheHelper::cache *args, &block
end

def marshal_cache(*args, &block)
  CacheHelper::marshal_cache *args, &block
end

# set sinatra's variables
set :app_file, __FILE__
set :root, File.expand_path(File.dirname(__FILE__))
set :views, "views"

configure do
  Compass.add_project_configuration(File.join(Sinatra::Application.root, 'config', 'compass.config'))
end

# at a minimum, the main sass file must reside within the ./views directory. here, we create a ./views/stylesheets directory where all of the sass files can safely reside.
get '/stylesheets/:name.css' do
  content_type 'text/css', :charset => 'utf-8'
  sass(:"stylesheets/#{params[:name]}", Compass.sass_engine_options )
end

load File.join(Sinatra::Application.root,'app.rb')
