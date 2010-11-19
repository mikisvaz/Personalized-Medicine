$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'per_med'
require 'table'
require 'digest/md5'
require 'rbbt/util/cachehelper'

require 'helpers'

def digest(str)
  Digest::MD5.hexdigest(str)
end
SINATRA = Sinatra::Application.root

$anais                = TSV.new(File.join(Sinatra::Application.root, '../data/CancerGenes/anais-annotations'), :single => true, :persistence => true)
$kegg_pathway_index   = TSV.new(File.join(Sinatra::Application.root, '../data/KEGG/pathways'), :extra => 'Name', :single => true, :persistence => true)
$PharmaGKB_drug_index = TSV.new(File.join(Sinatra::Application.root, '../data/PharmaGKB/drugs'), :field => 'Name', :single => true, :persistence => true)

$table_config = {
  'Metastasis'   => [File.join(SINATRA, 'data/Metastasis.tsv'), 'table_config/ngs.rb'],
  'NoMetastasis' => [File.join(SINATRA, 'data/NoMetastasis.tsv'), 'table_config/ngs.rb'],
  'Exclusive'    => [File.join(SINATRA, 'data/Exclusive.tsv'), 'table_config/ngs.rb'],
  'Raquel'       => [File.join(SINATRA, 'data/Raquel.tsv'), 'table_config/raquel.rb'],
  'Raquel_Patient'       => [File.join(SINATRA, 'data/Raquel.tsv'), 'table_config/raquel_patient.rb'],
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
    end
  end
end

get '/excel/:file' do
  file = params[:file] || 'Exclusive'

  data, table_config = data(file)

  flextable =  FlexTable.new(data, table_config)

  excelfile = File.join(Sinatra::Application.root,'/public/spreadsheets/', file + '.xls')

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
    :entrez => entrez(gene), 
    :name => gene, 
    :gene_info => gene_info(data, gene),
    :patient_info => patient_info(data, gene)
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

get '/*' do
  file = params[:splat].first 
  file = 'Exclusive' if file.empty?

  data, table_config = data(file)

  @flextable =  FlexTable.new(data, table_config)
  @file = file

  haml :index
end

