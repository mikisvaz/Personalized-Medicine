$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'phgx'

get '/' do
  haml :main
end

post '/' do
  genes = params[:genes].split(/\n/).collect{|l| l.chomp.split(/\s/,-1)}
  @info = marshal_cache('info', :genes => genes) do
    PhGx.analyze(genes)
  end

  haml :results
end
