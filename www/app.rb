$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'per_med'
require 'table'
require 'digest/md5'
require 'rbbt/util/cachehelper'
require 'helpers'
enable :sessions

def digest(str)
  Digest::MD5.hexdigest(str)
end
SINATRA = Sinatra::Application.root

$anais = Cancer.anais_annotations.tsv(:persistence => true)
$kegg = KEGG.pathways.tsv(:persistence => true, :type => :list)
$PharmaGKB_drug_index = PharmaGKB.drugs.tsv(:persistence => true, :type => :list)

#$PharmaGKB_drug_index = TSV.new(File.join(SINATRA, '../data/PharmaGKB/drugs'),  :single, :field => 'Name',:persistence => true)
#$anais                = TSV.new(File.join(SINATRA, '../data/CancerGenes/anais-annotations.txt'), :single, :persistence => true)
#$kegg_pathway_index   = TSV.new(File.join(SINATRA, '../data/KEGG/pathways'),    :single, :extra => 'Name',:persistence => true)
#$PharmaGKB_drug_index = TSV.new(File.join(SINATRA, '../data/PharmaGKB/drugs'),  :single, :field => 'Name',:persistence => true)

$table_config = {
  'Metastasis'     => [File.join(SINATRA, 'data/Metastasis.tsv'), File.join(SINATRA, 'table_config/ngs.rb')],
  'NoMetastasis'   => [File.join(SINATRA, 'data/NoMetastasis.tsv'), File.join(SINATRA, 'table_config/ngs.rb')],
  'Exclusive'      => [File.join(SINATRA, 'data/Exclusive.tsv'), File.join(SINATRA, 'table_config/ngs.rb')],
  'Raquel'         => [File.join(SINATRA, 'data/Raquel.tsv'), File.join(SINATRA, 'table_config/raquel.rb')],
  'Raquel_Patient' => [File.join(SINATRA, 'data/Raquel.tsv'), File.join(SINATRA, 'table_config/raquel_patient.rb')],
  '1035'           => [File.join(SINATRA, 'data/1035.tsv'), File.join(SINATRA, 'table_config/ngs.rb')],
  'Esp66'          => [File.join(SINATRA, 'data/Esp66.tsv'), File.join(SINATRA, 'table_config/ngs.rb')],
}

def data(file)
  marshal_cache('data', file) do
    case file
    when 'Exclusive'
      [PersonalizedMedicine.NGS($table_config[file].first), $table_config[file].last]
    when 'Metastasis'
      [PersonalizedMedicine.NGS($table_config[file].first), $table_config[file].last]
    when 'NoMetastasis'
      [PersonalizedMedicine.NGS($table_config[file].first), $table_config[file].last]
    when 'Raquel'
      [PersonalizedMedicine.Raquel($table_config[file].first), $table_config[file].last]
    when 'Raquel_Patient'
      [PersonalizedMedicine.Raquel_Patient($table_config[file].first), $table_config[file].last]
    when '1035'
      [PersonalizedMedicine.NGS($table_config[file].first), $table_config[file].last]
    when 'Esp66'
      [PersonalizedMedicine.NGS($table_config[file].first), $table_config[file].last]
    end
  end
end

get '/excel/:file' do
  file = params[:file] || 'Exclusive'

  data, table_config = data(file)

  flextable =  FlexTable.new(data, table_config)

  excelfile = File.join(SINATRA,'/public/spreadsheets/', file + '.xls')

  flextable.excel(excelfile)

  content_type 'application/x-excel'
  attachment excelfile

  File.open(excelfile).read
end

get '/genecard/:file' do 
  file = params[:file] || 'Exclusive'
  gene = params[:gene]
  gene = gene.split(/_/) if gene =~ /_/
 
  file = 'Raquel' if file == 'Raquel_Patient'

  data, table_config = data(file)

 
  locals = {
  	:file => file,
    :entrez => gene, 
    :name => gene, 
    :gene_info => gene_info(data, gene),
    :patient_info => patient_info(data, gene),
    :description => entrez_info(gene).description.flatten.first,
    :summary => entrez_info(gene).summary.flatten.first,
  }
  
  
  haml :_tabs, :layout => false, :locals => locals
end

post '/data/:file' do
  page        = params[:page]      || 1
  rp          = params[:rp]        || 15
  sortname    = params[:sortname]  || 'Position'
  sortorder   = params[:sortorder] || 'desc'
  file        = params[:file]      || 'Exclusive'

  data, table_config = data(file)

  flextable =  FlexTable.new(data, table_config)

  rows = flextable.items(page.to_i, rp.to_i, sortname, sortorder, 'html').
    collect{|row| {:id => digest(row.inspect), :cell => row} }

  content_type :json
  data = {:page => page.to_i, :total => data.size, :rows => rows}.to_json
end

post '/login-user' do
  
  user        = params[:user]      || ''
  passwd      = params[:password]  || ''
  
  if (user != '' and passwd != '')
    
    msg = (check_logged_user(user,passwd))?'Welcome '+user+', please check your <a href="/experiments/">experiments list</a>':'Invalid user or password'
    haml :login, :locals => {:msg => msg} 
  else
    haml :login, :locals => {:msg => 'Please provide your user and password'}
  end     
end


get '/experiments/*' do
  
  if check_logged_user('','')
    
    if params[:splat] and params[:splat].first and not params[:splat].first.empty?
      file = params[:splat].first 
    else
     file = $users.select{|info| info[:user] == session[:user][:user]}.first[:experiments].first
    end
    
    data, table_config = data(file)

  
    @flextable =  FlexTable.new(data, table_config)
    @file = file
  
    haml :experiments, :layout => true
  else
    haml :login, :layout => true , :locals => {:msg => ''}
  end
end

get '/methodology' do
  haml :methodology, :layout => true 
end

get '/' do
  logout       = params[:logout] || ''
  session[:user] = {} if logout
  haml :index, :layout => true 
end
