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

$anais = Cancer.anais_interactions.tsv(:persistence => true, :type => :list, :key => 1)

$kegg = KEGG.pathways.tsv(:persistence => true, :type => :list)
$PharmaGKB_drug_index = PharmaGKB.drugs.tsv(:persistence => true, :type => :list)

$table_config = {
  'demo'           => [File.join(SINATRA, 'data/Metastasis.tsv'), File.join(SINATRA, 'table_config/ngs.rb')],
  'Metastasis'     => [File.join(SINATRA, 'data/Metastasis.tsv'), File.join(SINATRA, 'table_config/ngs.rb')],
  'NoMetastasis'   => [File.join(SINATRA, 'data/NoMetastasis.tsv'), File.join(SINATRA, 'table_config/ngs.rb')],
  'Pancreas'       => [File.join(SINATRA, 'data/Pancreas.tsv'), File.join(SINATRA, 'table_config/positions.rb')],
  'Pancreas2'       => [File.join(SINATRA, 'data/Pancreas2.tsv'), File.join(SINATRA, 'table_config/positions.rb')],
  'CLL-1'          => [File.join(SINATRA, 'data/CLL-1.tsv'), File.join(SINATRA, 'table_config/biomart.rb')],
  'CLL-2'         => [File.join(SINATRA, 'data/CLL-2.tsv'), File.join(SINATRA, 'table_config/biomart.rb')],
  'CLL-3'         => [File.join(SINATRA, 'data/CLL-3.tsv'), File.join(SINATRA, 'table_config/biomart.rb')],
  'CLL-4'         => [File.join(SINATRA, 'data/CLL-4.tsv'), File.join(SINATRA, 'table_config/biomart.rb')],
  'Neuroendocrine' => [File.join(SINATRA, 'data/Neuroendocrine.tsv'), File.join(SINATRA, 'table_config/positions.rb')],
  'Exclusive'      => [File.join(SINATRA, 'data/Exclusive.tsv'), File.join(SINATRA, 'table_config/ngs.rb')],
  'Raquel'         => [File.join(SINATRA, 'data/Raquel.tsv'), File.join(SINATRA, 'table_config/raquel.rb')],
  'Raquel_Patient' => [File.join(SINATRA, 'data/Raquel.tsv'), File.join(SINATRA, 'table_config/raquel_patient.rb')],
  '1035'           => [File.join(SINATRA, 'data/1035.tsv'), File.join(SINATRA, 'table_config/ngs.rb')],
  'Esp66'          => [File.join(SINATRA, 'data/Esp66.tsv'), File.join(SINATRA, 'table_config/ngs.rb')],
}

def load_data(file)
  res = marshal_cache('data', file) do
    case file
    when 'demo'
      [PersonalizedMedicine.NGS($table_config[file].first), $table_config[file].last, "Hsa/may2009"]
    when 'Exclusive'
      [PersonalizedMedicine.NGS($table_config[file].first), $table_config[file].last, "Hsa/may2009"]
    when 'Metastasis'
      [PersonalizedMedicine.NGS($table_config[file].first), $table_config[file].last, "Hsa/may2009"]
    when 'NoMetastasis'
      [PersonalizedMedicine.NGS($table_config[file].first), $table_config[file].last, "Hsa/may2009"]
    when 'Pancreas'
      [PersonalizedMedicine.positions($table_config[file].first, "Hsa/may2009", "pancreas"), $table_config[file].last, "Hsa/may2009"]
    when 'Pancreas2'
      [PersonalizedMedicine.positions($table_config[file].first, "Hsa/may2009", "pancreas"), $table_config[file].last, "Hsa/may2009"]
    when 'CLL-1'
      [PersonalizedMedicine.biomart($table_config[file].first, 'Hsa'), $table_config[file].last, "Hsa"]
    when 'CLL-2'
      [PersonalizedMedicine.biomart($table_config[file].first, 'Hsa'), $table_config[file].last, "Hsa"]
    when 'CLL-3'
      [PersonalizedMedicine.biomart($table_config[file].first, 'Hsa'), $table_config[file].last, "Hsa"]
    when 'CLL-4'
      [PersonalizedMedicine.biomart($table_config[file].first, 'Hsa'), $table_config[file].last, "Hsa"]
    when 'Neuroendocrine'
      [PersonalizedMedicine.positions($table_config[file].first), $table_config[file].last, "Hsa/may2009"]
    when 'Raquel'
      [PersonalizedMedicine.Raquel($table_config[file].first), $table_config[file].last, "Hsa/may2009"]
    when 'Raquel_Patient'
      [PersonalizedMedicine.Raquel_Patient($table_config[file].first), $table_config[file].last, "Hsa/may2009"]
    when '1035'
      [PersonalizedMedicine.NGS($table_config[file].first), $table_config[file].last, "Hsa/may2009"]
    when 'Esp66'
      [PersonalizedMedicine.NGS($table_config[file].first), $table_config[file].last, "Hsa/may2009"]
    end
  end

  $org = res.last
  $ensembl_url = case
                 when $org == "Hsa"
                   "www.ensembl.org"
                 else
                   "#{$org.sub(/.*\//,'')}.archive.ensembl.org"
                 end

  res
end

get '/excel/:file' do
  file = params[:file] || 'Exclusive'

  tsv, table_config = load_data(file)

  flextable =  FlexTable.new(tsv, table_config)

  excelfile = File.join(SINATRA,'/public/spreadsheets/', file + '.xls')

  flextable.excel(excelfile)

  content_type 'application/x-excel'
  attachment excelfile

  File.open(excelfile).read
end

get '/ajax/genecard/:file' do 
  file = params[:file] || 'Exclusive'
  gene = params[:gene]

  file = 'Raquel' if file == 'Raquel_Patient'

  tsv, table_config, org = load_data(file)
  
  info      = tsv.select("Ensembl Gene ID" => [gene]).values.first
  select    = tsv.select("Ensembl Gene ID" => [gene])

  info   = select.values.first
  pos    = select.keys.first

  if not file == 'Raquel'
    chr, position = pos.split(/:/)
    ensembl = info["Ensembl Gene ID"].first
  else
    chr, position, ensembl = nil, nil, nil
  end

  entrez = info["Entrez Gene ID"].first

  locals = {
  	:file => file,
    :name => info["Associated Gene Name"],
    :info => info,
    :entrez => entrez,
    :ensembl => ensembl,
    :chr => chr,
    :pos => position,
    :description => entrez_info(entrez).nil? ? "MISSING" : entrez_info(entrez).description.flatten.first,
    :summary => entrez_info(entrez).nil? ? "MISSING" : entrez_info(entrez).summary.flatten.first,
  }
  
  
  haml :_tabs, :layout => false, :locals => locals
end

post '/data/:file' do
  page        = params[:page]      || 1
  rp          = params[:rp]        || 15
  sortname    = params[:sortname]  || 'Position'
  sortorder   = params[:sortorder] || 'desc'
  file        = params[:file]      || 'Exclusive'
  query       = params[:query]      
  qtype       = params[:qtype]      

  tsv, table_config = load_data(file)

  flextable =  FlexTable.new(tsv, table_config)

  rows = flextable.items(page.to_i, rp.to_i, sortname, sortorder, 'html', query, qtype).
    collect{|row| {:id => digest(row.inspect), :cell => row} }

  content_type :json
  {:page => page.to_i, :total => rows.size, :rows => rows}.to_json
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
    
    tsv, table_config = load_data(file)

  
    @flextable =  FlexTable.new(tsv, table_config)
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
