$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'phgx'
require 'rbbt/sources/go'
require 'rbbt/sources/entrez'
require 'digest/md5'
require 'json'
require 'spreadsheet'
require 'cgi'

enable :sessions
$anais = PhGx::CancerAnnotations.load_data
$kegg_pathway_index = TSV.new(File.join(Sinatra::Application.root, '../data/KEGG/pathways'), :single => true, :persistence => true)
$PharmaGKB_drug_index = TSV.new(File.join(Sinatra::Application.root, '../data/PharmaGKB/drugs'), :field => 'Name', :single => true, :persistence => true)

def join_hash_fields(list)
  return [] if list.nil? || list.empty?
  list[0].zip(*list[1..-1])
end

TABLE_FIELDS = [ 'GeneName', 'Position', 'Mutation', 'Type', 'Score', 'Severity', 'SIFT', 'Polyphen',
  'SNP&GO', 'FireDB', 'Pathways', 'Drugs', 'Cancers for which it was reported']

def rows2excel(rows, file)
  workbook = Spreadsheet::Workbook.new

  heading = Spreadsheet::Format.new( :color => "green", :bold => true, :underline => true ) 
  data = Spreadsheet::Format.new( :color => "black", :bold => false, :underline => false ) 
  workbook.add_format(heading)  
  workbook.add_format(data)  

  worksheet = workbook.create_worksheet

  worksheet.row(0).concat TABLE_FIELDS
  worksheet.row(0).default_format = heading

  rows.each_with_index do |row,i| 
    worksheet.row(i + 1).concat row['cell'].collect{|v| (v || "").gsub(/<.*?>/,'') }
  end

  workbook.write(file)
end


helpers do

  def make_cookie(genes)
     digest = Digest::MD5.hexdigest(genes.inspect)
     digest
  end
  
  def summary_table(info,page,rp,sortname,sortorder, excel = false)
    rows    = []
    rstart  = (page.to_i - 1)*rp.to_i
    rend    = [info.keys.length - 1, rstart + rp.to_i].min
    
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
        ((value[:PharmaGKB] || []) + (value[:Matador] || []) + (value[:NCI] || []).collect{|f| f.first}.uniq).size
      end.collect{|p| p.first}.reverse  
    when 'nci_diseases'
      genes = @info.sort_by do |key,value|
        (value[:NCI_cancer] || []).size
      end.collect{|p| p.first}.reverse   
    when 'cancers'
      genes = @info.sort_by do |key,value|
        (value[:Anais_cancer] || []).size
      end.collect{|p| p.first}.reverse   
    when 'type'
      genes = @info.sort_by do |key,value|
        (value[:Mutations] || []).collect{|values| 
          values[5] == 'Nonsynonymous' ? 1 : (values[5] == 'Synonymous' ? -1 : 0)
        }.max || "NO"
      end.collect{|p| p.first}.reverse   
    when 'position'
      genes = @info.sort_by do |key,value|
        (value[:Mutations] ||[]).collect{|values| 
          (values[0].to_i < 10 ? "0" << values[0] : values[0]) + values[1]
        }.first || "NO"
      end.collect{|p| p.first}.reverse   
    when 'sift'
      genes = @info.sort_by do |key,value|
        (value[:Mutations] ||[]).collect{|values| 
          values[7] =~ /DAMAGING/ ? (values[7] =~ /Low/ ? 1 : 2) : (values[7] =~ /TOLERATED/ ? -1 : 0)
        }.first || "NO"
      end.collect{|p| p.first}.reverse   
    when 'severity'
      genes = @info.sort_by do |key,value|
        (value[:Mutations] ||[]).collect{|values| 
          mutation_severity_summary(values)
        }.first || "NO"
      end.collect{|p| p.first}.reverse   
    when 'snp_go'
      genes = @info.sort_by do |key,value|
        (value[:Mutations] ||[]).collect{|values| 
          values[9] ? (values[9][1] =~ /Disease/ ? 1 : -1) : 0
        }.max || "NO"
      end.collect{|p| p.first}.reverse   
    when 'firedb'
      genes = @info.sort_by do |key,value|
        (value[:Mutations] ||[]).collect{|values| 
          values[11] ? (values[11][4] =~ /Y/ ? 1 : -1) : 0
        }.max || "NO"
      end.collect{|p| p.first}.reverse   
    when 'polyphen'
      genes = @info.sort_by do |key,value|
        (value[:Mutations] ||[]).collect{|values| 
          case 
          when values[10].nil? || values[6].empty?
            0
          when values[10][5] == 'benign'
            -1
          when values[10][5] == 'possibly damaging'
            1
          when values[10][5] == 'probably damaging'
            2
          else
            0
          end
        }.max || 0
      end.collect{|p| p.first}.reverse   


    when 'score'
      genes = @info.sort_by do |key,value|
        (value[:Mutations] ||[]).collect{|values| 
          values[6].to_i
        }.sort.last || "NO"
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
            "#{mutation[0]}:#{mutation[1]}, #{mutation[2]}/#{mutation[3]}",
            mutation[4],
            mutation[5],
            mutation[6],

            {0 => "Neutral", 1 => "Low", 2 => "Medium", 3 => "High"}[mutation_severity_summary(mutation)],

            mutation[7],

            mutation[10] ? mutation[10][5] : 'NO',
            mutation[9] ? mutation[9][1] : 'NO',
            mutation[11] ? mutation[11][4] : 'NO',

            list_summary(kegg_summary(gene_info[:KEGG]), excel),
            list_summary((matador_summary(info[gname][:Matador]) + pharmagkb_summary(info[gname][:PharmaGKB]) + nci_drug_summary(info[gname][:NCI])), excel),
            mutation[8] || "",
            list_summary(cancer_genes_summary(info[gname][:Anais_cancer]), excel),
            list_summary(nci_diseases_summary(info[gname][:NCI_cancer]), excel)
        ]}
        rows << row
      end
    end
    
    rows
  end

  def list_summary(list, excel = false)
    code = Digest::MD5.hexdigest(list.inspect)
    if list.length < 3 || excel
      list * ', '
    else
      list[0..1] * ', ' + ', ' +
      "<a id='#{code}' class=expand href='' value='#{CGI.escapeHTML(list * ', ').gsub(/'/,'"')}' onclick='expand_field(\"#{code}\");return(false)'>#{list.size - 2} more ...<a>"
    end
  end

  def genecard_trigger(gname, text)
    "<a class='genecard_trigger' href='/ajax/genecard' onclick='update_genecard(\"#{gname * "_"}\");return(false);'>#{text}</a>"
  end
  
  def matador_summary(matador_drugs)
    return [] if matador_drugs.nil?
    matador_drugs.collect do |d|
      name, id, score, annot, mscore, mannot, mmscore, mmannot = d
      direct = [annot, mannot, mmannot].select{|a| a == 'DIRECT'}.any?
      css_class = direct ? 'red' : 'normal';
      "<a target='_blank' class='#{css_class}' href='http://matador.embl.de/drugs/#{id}/'>#{name}</a>"
    end  
  end
  
  def pharmagkb_summary(pgkb_drugs)
    return [] if pgkb_drugs.nil?
    pgkb_drugs.collect do |d|
        "<a target='_blank' href='http://www.pharmgkb.org/do/serve?objCls=Drug&objId=#{d.first}'>#{$PharmaGKB_drug_index[d.first]}</a>"
    end
  end
   
  def nci_drug_summary(nci_drugs)
    return [] if nci_drugs.nil?
    nci_drugs.reject{|d| d.first.empty?}.collect do |d|
        "<a target='_blank' href='http://ncit.nci.nih.gov/ncitbrowser/pages/concept_details.jsf?dictionary=NCI%20Thesaurus&type=properties&code=#{d[1]}'>#{d.first}</a> "
    end.uniq
  end

  def kegg_summary(pathways)
    return [] if pathways.nil?
    pathways.collect do |code|
      desc = $kegg_pathway_index[code].sub(/- Homo sapiens.*/,'')
      "<a target='_blank' href='http://www.genome.jp/kegg-bin/show_pathway?#{code}'>#{desc}</a>"
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
 
  def nci_diseases_summary(nci_diseases)
    if nci_diseases != nil
      nci_diseases.collect do |c|
        "<span>#{c.first}</span>"
      end.uniq
    else
      []  
    end
  end
  
  def pathway_details_summary(kegg_pathways)
    return '' if kegg_pathways.nil?
    out =  ''
     kegg_pathways.collect do |code|
      desc = $kegg_pathway_index[code].sub(/- Homo sapiens.*/,'')
      out += "<a href='http://www.genome.jp/kegg/pathway/hsa/#{code}.png'  class='top_up'><img src='http://www.genome.jp/kegg/pathway/hsa/#{code}.png' style='width:70px;float:left;margin-right:10px;margin-botton:10px;' title='Click to enlarge'/></a>";
      out += '<div style="float:left;width:600px;">'; 
      out += "<p><b>#{desc}</b></p>"
      name = ''
      cancers = join_hash_fields($anais[code])
      if (cancers.size != 0)
        out += '<p>This pathway has more mutations than expected by chance in the following tumour types</p>'
        cancers.each do |p|
            cancer, type, score, desc2 = p
            css_class = (score != nil and score.to_f <= 0.1)?'red':'green';
            out += " <span class='#{ css_class } cancertype'>[#{ cancer }]</span> "
        end
      end
      out += "<p><a target='_blank' href='http://www.genome.jp/kegg-bin/show_pathway?#{code}'>View more</a></p>"
      out += '</div>'
      out += '<div class="clearfix"></div>'
      out += '<div class="height:10px;">&nbsp;</div>' 
    end
    out
  end
  
  def drug_details_summary(matador_drugs,pgkb_drugs,nci_drugs)
    return '' if (matador_drugs.nil? && pgkb_drugs.nil?  && nci_drugs.nil? )

    out =  ''
    if ((matador_drugs || []).any?)
      matadorOut = '<dt><b>MATADOR drugs (Full list)</b></dt><dd>'
      matador_drugs_a = matador_drugs.collect do |d|
        name, id, score, annot, mscore, mannot, mmscore, mmannot = d
        direct = [annot, mannot, mmannot].select{|a| a == 'DIRECT'}.any?
        css_class = direct ? 'red' : 'normal';
        "<a target='_blank' class='#{css_class}' href='http://matador.embl.de/drugs/#{id}/'>#{name}</a>"
      end
      matadorOut << matador_drugs_a * ', '
      matadorOut << '</dd>'
      out << matadorOut  
    end  

    if ((pgkb_drugs || []).any?)
      pgkbOut = '<dt><b>PharmaGKB drugs (Full list)</b></dt><dd>'
      pgkb_drugs_a = pgkb_drugs.collect do |d|
        "<a target='_blank' href='http://www.pharmgkb.org/do/serve?objCls=Drug&objId=#{d.first}'>#{$PharmaGKB_drug_index[d.first]}</a>"
      end
      pgkbOut << pgkb_drugs_a * ', '
      pgkbOut << '</dd>'
      out << pgkbOut  
    end  
    
    if ((nci_drugs || []).any?)
       nciOut = '<dt><b>NCI  drugs (Full list)</b></dt><dd>'
       
       nci_drugs_a = nci_drugs.reject{|d| d.first.empty?}.collect do |d|
         "<a target='_blank' href='http://ncit.nci.nih.gov/ncitbrowser/pages/concept_details.jsf?dictionary=NCI%20Thesaurus&type=properties&code=#{d[1]}'>#{d.first}</a>"
       end.uniq
       
       nciOut << nci_drugs_a * ', '
       out << nciOut
    end    
    out     
  end

  def mutation_severity_summary(mutation)
    count = 0

    count += 1 if mutation[7] && mutation[7] =~ /DAMAGING/
    count += 1 if mutation[9] && mutation[9][1] == 'Disease'
    count += 1 if mutation[10] && mutation[10][5] =~ /damaging/

    count
  end

  def go_link(id)
    name = GO.id2name(id)
    
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
  
  
  haml :_tabs, :layout => false, :locals => locals
end

get '/excel/' do
  cookie      = session["genes"] ||= nil
  
  @info = marshal_cache('info',cookie) do
    raise "Info should be preloaded"
  end
 
  rows = summary_table(@info,1 , @info.size - 1, 'score', 'desc', true)

  FileUtils.mkdir_p File.join(Sinatra::Application.root,'/public/spreadsheets/') unless File.exists? File.join(Sinatra::Application.root,'/public/spreadsheets/')
  file = File.join(Sinatra::Application.root,'/public/spreadsheets/', cookie + '.xls')
  
  rows2excel(rows, file)

  content_type 'application/x-excel'
  attachment 'Mutation_info.xls'

  File.open(file).read
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
  
  content_type :json
  rows = summary_table(@info,page,rp,sortname,sortorder)

  data = {:page => page, :total => @info.size, :rows =>rows}.to_json
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
           File.join(Sinatra::Application.root, '../data/IRS/table.tsv')
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

