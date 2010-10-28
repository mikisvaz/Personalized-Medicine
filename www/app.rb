$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'phgx'
require 'rbbt/sources/go'
require 'rbbt/sources/entrez'
require 'digest/md5'
require 'json'

enable :sessions
$anais = PhGx::CancerAnnotations.load_data
$kegg_pathway_index = TSV.new(File.join(Sinatra::Application.root, '../data/KEGG/pathways'), :single => true)

DATA_FILE=ARGV[0]

def join_hash_fields(list)
  return [] if list.nil? || list.empty?
  list[0].zip(*list[1..-1])
end


helpers do

  def make_cookie(genes)
     digest = Digest::MD5.hexdigest(genes.inspect)
     digest
  end
  
  def summary_table(info,page,rp,sortname,sortorder)
    rows    = []
    rstart  = (page.to_i - 1)*rp.to_i
    rend    = rstart + rp.to_i
    
    case sortname
    when 'genename'
      genes = @info.sort_by do |key,value|
        key.last || ""
      end.collect{|p| p.first}.reverse
    when 'pathways'
      genes = @info.sort_by do |key,value|
        (value[:KEGG] || []).size
      end.collect{|p| p.first}.reverse
    when 'drugs'
      genes = @info.sort_by do |key,value|
        ((value[:PharmaGKB] || []) + (value[:Matador] || [])).size
      end.collect{|p| p.first}.reverse  
    when 'cancers'
      genes = @info.sort_by do |key,value|
        (value[:Anais_cancer] || []).size
      end.collect{|p| p.first}.reverse   
    when 'type'
      genes = @info.sort_by do |key,value|
        value[:Mutations].collect{|values| 
          values[3]
        }.sort.first
      end.collect{|p| p.first}.reverse   
    when 'chr'
      genes = @info.sort_by do |key,value|
        value[:Mutations].collect{|values| 
          values[0]
        }.first
      end.collect{|p| p.first}.reverse   
    when 'snp_go'
      genes = @info.sort_by do |key,value|
        value[:Mutations].collect{|values| 
          values[5] ? (values[5][1] =~ /Disease/ ? 1 : -1) : 0
        }.max
      end.collect{|p| p.first}.reverse   
    when 'firedb'
      genes = @info.sort_by do |key,value|
        value[:Mutations].collect{|values| 
          values[7] ? (values[7][4] =~ /Y/ ? 1 : -1) : 0
        }.max
      end.collect{|p| p.first}.reverse   
    when 'polyphen'
      genes = @info.sort_by do |key,value|
        value[:Mutations].collect{|values| 
          case 
          when values[6].nil? || values[6].empty?
            0
          when values[6][5] == 'benign'
            -1
          when values[6][5] == 'possibly damaging'
            1
          when values[6][5] == 'probably damaging'
            2
          else
            puts values[6][5]
            0
          end
        }.max
      end.collect{|p| p.first}.reverse   


    when 'score'
      genes = @info.sort_by do |key,value|
        value[:Mutations].collect{|values| 
          values[4].to_i
        }.sort.last
      end.collect{|p| p.first}.reverse   
 
    else
       genes   = info.keys.sort_by{|list| list[2]}
    end
    
    genes.reverse! if sortorder == "asc"
    
    for i in rstart..rend do
      gname = genes[i]
      gene_info = info[gname]
      (gene_info[:Mutations] || [["NO"] * 5]).each do |mutation|
        row = {
          "id"=>gname,
          "cell"=>[
            genecard_trigger(gname, gname.values_at(2,1,0).reject{|name| name.nil? || name.empty?}.first),
            mutation[0],
            mutation[1],
            mutation[2],
            mutation[3],
            mutation[4],

            mutation[5] ? mutation[5][1] : 'NO',
            mutation[6] ? mutation[6][5] : 'NO',
            mutation[7] ? mutation[7][4] : 'NO',

            kegg_summary(gene_info[:KEGG]).join(', '),
            (matador_summary(info[gname][:Matador]) + pharmagkb_summary(info[gname][:PharmaGKB])).join(', '),
            cancer_genes_summary(info[gname][:Anais_cancer]).join(', ')
        ]}
        rows << row
      end
    end
    
    data = {:page => page, :total => @info.size, :rows =>rows}
    data.to_json
  end

  def genecard_trigger(gname, text)
    "<a class='genecard_trigger' href='/ajax/genecard' onclick='update_genecard(\"#{gname * "_"}\");return(false);'>#{text}</a>"
  end
  
  def matador_summary(matador_drugs)
    return [] if matador_drugs.nil?
    matador_drugs.collect do |d|
      name, score, annot, mscore, mannot = d
      css_class = (mannot == 'DIRECT')?'red':'normal';
      "<span class='#{css_class}'>#{name}</span> [M]"
    end  
  end
  
  def pharmagkb_summary(pgkb_drugs)
    return [] if pgkb_drugs.nil?
    pgkb_drugs.collect do |d|
        "<a target='_blank' href='http://www.pharmgkb.org/search/search.action?typeFilter=Drug&exactMatch=true&query=#{d}'>#{d}</a> [PGKB]"
    end
  end
  
  def kegg_summary(pathways)
    return [] if pathways.nil?
    pathways.collect do |code|
      desc = $kegg_pathway_index[code]
      name = ''
      join_hash_fields($anais[code]).each do |p|
        cancer, type, score, desc2 = p
        css_class = (score != nil and score.to_f <= 0.1)?'red':'green';
        name += " <span class='#{ css_class }'>[#{ cancer } cancer]</span>"
      end
      "<a target='_blank' href='http://www.genome.jp/kegg-bin/show_pathway?#{code}'>#{desc} #{ name }</a>"
    end
  end
  
  def cancer_genes_summary(cancers)
    if cancers != nil
      cancers.collect do |c|
        "<span>#{c}</span>"
      end
    else
      []  
    end
  end


  def go_link(id)
    puts id
    name = GO.id2name(id)
    puts name
    
    join_hash_fields(@anais[id]).each do |p|
      cancer, score = p
      name += "[#{ cancer }:#{ score }]"
    end
    
    "<a href='http://amigo.geneontology.org/cgi-bin/amigo/go.cgi?view=details&query=#{id}'>#{ name }</a>"
  end

  def drug_link(id)
    name = id
    
    "<a href='http://vsearch.nlm.nih.gov/vivisimo/cgi-bin/query-meta?v%3Aproject=medlineplus&query=#{id}'>#{ name }</a>"
  end


  def kegg_link(id)
    name = id

    join_hash_fields(@anais[id]).each do |p|
      cancer, score = p
      name += "[#{ cancer }:#{ score }]"
    end

    "<a href='http://www.genome.jp/kegg-bin/show_pathway?#{id}'>#{ name }</a>"
  end
  
  
end
def entrez(gene)
  i = TSV.index(File.join(Organism.datadir('Hsa'), 'identifiers'), :persistence => true)
  i[gene].first
end
def entrez_info(gene)
  entrez = entrez(gene)
  marshal_cache('entrez_info', entrez) do
    Entrez.get_gene(entrez)
  end
end


get '/ajax/genecard' do 
  p params
  p params[:gene]
  gene = params[:gene].split(/_/)
  cookie      = session["genes"] ||= nil
 
  @info = marshal_cache('info',cookie) do
    raise "Info should be preloaded"
  end

  locals = {
    :entrez => entrez(gene), 
    :name => gene, 
    :gene_info => @info[gene],
    :description => entrez_info(gene).description,
    :summary => entrez_info(gene).summary,
  }
  
  
  haml :_gene, :layout => false, :locals => locals
end

post '/ajax/genes' do 
  
  page        = params[:page] ||= 1
  rp          = params[:rp] ||= 15
  sortname    = params[:sortname] ||= 'score'
  sortorder   = params[:sortorder] ||= 'desc'
  cookie      = session["genes"] ||= nil
  
  @info = marshal_cache('info',cookie) do
    raise "Info should be preloaded"
  end
  
  #p summary_table(@info,page,rp,sortname,sortorder)  
  summary_table(@info,page,rp,sortname,sortorder)
end

get '/' do
  file = case params[:file]
         when 'Metastasis'
         File.join(Sinatra::Application.root, '../data/IRS/table.tsv')
         when 'No_Metastasis'
         File.join(Sinatra::Application.root, '../data/LP2/table.tsv')
         when 'Exclusive'
         File.join(Sinatra::Application.root, '../data/Exclusive/table.tsv')
         when 'Raquel'
         File.join(Sinatra::Application.root, '../data/Raquel/raquel.txt')
         else
           file = DATA_FILE
         end



  cookie  = make_cookie(file)
  session["genes"] = cookie

  @info = marshal_cache('info', cookie) do
    if file =~ /raquel/i
      PhGx.analyze_Raquel(file)
    else
      PhGx.analyze_NGS(file)
    end
  end

  haml :results
end

