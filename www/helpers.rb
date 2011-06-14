require 'cgi'
require 'per_med'
require 'rbbt/util/cachehelper'
require 'rbbt/sources/organism'
require 'rbbt/sources/entrez'
require 'rbbt/sources/kegg'
require 'rbbt/sources/cancer'
require 'rbbt/sources/go'


def check_logged_user(user,password)
  
  $users = [
    {:user => 'demo', :password => 'demo', :experiments => ['demo']},
    {:user => 'cll', :password => '123qwe', :experiments => ['CLL-1', 'CLL-2', 'CLL-3', 'CLL-4']},
    {:user => 'mhidalgo', :password => '123qwe', :experiments => ['Exclusive','Metastasis','NoMetastasis', 'Pancreas', 'Pancreas2', 'Neuroendocrine', 'Raquel','Raquel_Patient']},
    {:user => 'preal', :password => '123qwe', :experiments => ['1035','Esp66']}
  ]
  
  if session[:user].include? :user
    return true;
  else
    if (user && password)
       $users.each do |u|
        if (user == u[:user] && password == u[:password])
          session[:user] = u
          return true
        end
       end  
    end 
  end  
  return false    
end

def entrez_info(entrez)
  marshal_cache('entrez_info', entrez) do
    Entrez.get_gene(entrez)
  end
end

def first(array)
  (array || [""]).first
end

def genecard_trigger(text, ensembl)
  gname = [gname] unless Array === gname
  if gname.last =~ /UNKNOWN/
    text
  else
    "<a class='genecard_trigger' href='/ajax/genecard' onclick='update_genecard(\"#{ensembl}\");return(false);'>#{text}</a>"
  end
end

def list_summary(list)
  return list unless Array === list
  code = Digest::MD5.hexdigest(list.inspect)
  if list.length < 3 
    list * ', '
  else
    list[0..1] * ', ' + ', ' +
      "<a id='#{code}' class=expand href='' value='#{URI.escape(list * ', ').gsub(/'/,'"')}' onclick='expand_field(\"#{code}\");return(false)'>#{list.size - 2} more ...<a>"
  end
end


def mutation_severity_summary(mutation)
  count = 0

  count += 1 if first(mutation["SIFT:Prediction"])
  count += 1 if first(mutation["SNP&GO:Disease?"]) == 'Disease'
  count += 1 if first(mutation["Polyphen:prediction"]) =~ /damaging/

  count
end

def kegg_summary(pathways, html = true)
  return [] if pathways.nil?
  pathways.collect do |code|
    desc = $kegg[code]["Pathway Name"].sub(/- Homo sapiens.*/,'')
    cancer = ''
    if html
      entries = if $anais.include? code
                  $anais[code].zip_fields
                else
                  []
                end

      entries.each do |cancer, type, score, desc2|
        #TSV.zip_fields($anais[code]).each do |p|
        #  cancer, type, score, desc2 = p
        css_class = (score != nil and score.to_f <= 0.1)?'red':'green';
        cancer += " <span class='#{ css_class } cancertype'>[#{ cancer }]</span>"
      end if entries
      "<a target='_blank' href='http://www.genome.jp/kegg-bin/show_pathway?#{code}'>#{desc} #{ cancer }</a>"
    else
      "[#{ code }]: #{ desc }"
    end 
  end 
end


def matador_summary(matador_drugs, html = true)
  return [] if matador_drugs.empty?
  matador_drugs.collect do |d|
    name, id, score, annot, mscore, mannot = d
    if html
      css_class = (mannot == 'DIRECT')?'red':'normal';
      "<a target='_blank' href='http://matador.embl.de/drugs/#{id}/'>#{name}</a> [M]"
    else
      name
    end
  end  
end

def pharmagkb_summary(pgkb_drugs, html = true)
  return [] if pgkb_drugs.nil?
  pgkb_drugs.collect do |d|
    if html
      "<a target='_blank' href='http://www.pharmgkb.org/do/serve?objCls=Drug&objId=#{d.first}'>#{$PharmaGKB_drug_index[d.first]["Drug Name"]}</a> [PGKB]"
    else
      $PharmaGKB_drug_index[d.first]["Drug Name"]
    end
  end
end

def nci_drug_summary(nci_drugs, html = true)
  return [] if nci_drugs.nil?
  nci_drugs.reject{|d| d.nil? or d.empty? or d.first.nil? or d.first.empty?}.collect do |d|
    if html
      "<a target='_blank' href='http://ncit.nci.nih.gov/ncitbrowser/pages/concept_details.jsf?dictionary=NCI%20Thesaurus&type=properties&code=#{d[1]}'>#{d.first}</a> [NCI]"
    else
      d.first
    end
  end.uniq
end

def cancer_genes_summary(cancers, html = true)
  return [] if cancers.nil?
  cancers.first.collect do |c|
    if html
      "<span>#{c} [C]</span>"
    else
      c
    end
  end + 
  cancers.last.collect do |c|
    if html
      "<span>#{c} [NCI]</span>"
    else
      c
    end
  end
end

def pathway_details_summary(kegg_pathways)
  return 'No pathways found' if kegg_pathways.nil?
  out =  ''
  kegg_pathways.collect do |code|
    desc = $kegg[code]["Pathway Name"].sub(/- Homo sapiens.*/,'')
    out += "<a href='http://www.genome.jp/kegg/pathway/hsa/#{code}.png'  class='top_up'><img src='http://www.genome.jp/kegg/pathway/hsa/#{code}.png' style='height:50px;float:left;margin-right:10px;margin-botton:10px;' title='Click to enlarge'/></a>";
    out += "<p>#{desc} <a target='_blank' href='http://www.genome.jp/kegg-bin/show_pathway?#{code}'>[+]</a></p>"
    name = ''
    cancers = if $anais.include? code
                TSV.zip_fields($anais[code])
              else
                []
              end
      
    if cancers.any?
      out += '<p>This pathway has more mutations than expected by chance in the following tumour types</p>'
      cancers.each do |p|
        cancer, type, score, desc2 = p
        css_class = (score != nil and score.to_f <= 0.1)?'red':'green';
        out += " <span class='#{ css_class } cancertype'>[#{ cancer }]</span> "
      end
    end
    out += '<div class="clearfix"></div>'
    out += '<div style="height:10px;">&nbsp;</div>'
  end
  out
end

def protein_details_summary(values, chr, pos)
  mutations = values["Protein Mutation"]
  proteins = values["Ensembl Protein ID"]
  transcripts = values["Ensembl Transcript ID"]


  trans = Hash[*proteins.zip(transcripts).flatten]
  out =  ''

  data = mutations.zip(proteins).uniq.reject{|mutation, protein| 
    mutation.nil? or mutation.empty? or protein.nil? or protein.empty?
  }.collect do |mutation, protein|
    transcript = trans[protein]
    out += "<h2>#{ protein } : #{mutation} <span style='font-size:0.6em'><a target='_blank' href='http://www.uniprot.org/uniprot/?query=#{protein}&sort=score'>Query Uniprot</a></span></h2>\n"
    out += "<a  href='http://#{$ensembl_url}/Homo_sapiens/Component/Transcript/Web/TranslationImage?db=core&t=#{transcript}&_rmd=0dce&export=png&download=0' class='_top_up'>"
    out += "<img src='http://#{$ensembl_url}/Homo_sapiens/Component/Transcript/Web/TranslationImage?db=core&t=#{transcript}&_rmd=0dce&export=png&download=0' style='width:90%;float:left;margin-right:10px;margin-botton:10px;' title='Click to enlarge'/></a>"
    out += '<div class="clearfix"></div>'
    out += '<div style="height:10px;">&nbsp;</div>'
  end
  out
end


def drug_details_summary(matador_drugs, pgkb_drugs, nci_drugs)
  return 'No drugs found' if (!(matador_drugs || []).any? && !(pgkb_drugs || []).any? && !(nci_drugs || []).any? )
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

    nci_drugs_a = nci_drugs.reject{|d| d.nil? or d.empty? or d.first.nil? or d.first.empty?}.collect do |d|
      "<a target='_blank' href='http://ncit.nci.nih.gov/ncitbrowser/pages/concept_details.jsf?dictionary=NCI%20Thesaurus&type=properties&code=#{d[1]}'>#{d.first}</a>"
    end.uniq

    nciOut << nci_drugs_a * ', '
    out << nciOut
  end    
  out     
end

def patients_details_top5_patient_list(info, gained = true)
  return "Sorry, no information about patients found" if info.nil?
  field_types = %w(type probability expression top5_loss top5_gain)
  plist  = []

  patient_info = {}
  info.fields.each do |field|
    if field =~ /(.*?)_(#{field_types * "|"})/
      patient      = $1
      field_type   = $2
      patient_info[patient] ||= {}
      patient_info[patient][field_type] = info[field]
    end
  end

  patient_info.select{|name, patient| (patient['type'] == 'Gain') == gained }.sort_by{|name, patient| name}.collect do |name,patient|
    if patient['top5_gain'].first != "0"
      plist << '<span class="gain">' + name + '</span>'
    elsif patient['top5_loss'].first != "0"
      plist << '<span class="loss">' + name + '</span>'
    else
      plist << name
    end
  end    
  plist * ', '    
end

def patients_details_expression(info)
  return "Sorry, no information about patients found" if info.nil?
  field_types = %w(type probability expression top5_loss top5_gain)
  plist  = []

  patient_info = {}
  info.fields.each do |field|
    if field =~ /(.*?)_(#{field_types * "|"})/
      patient      = $1
      field_type   = $2
      patient_info[patient] ||= {'pos' => patient_info.size.to_s}
      patient_info[patient][field_type] = info[field]
    end
  end

  out  = 'var expression = [';
  points = []
  patient_info.sort_by{|name, patient| name }.collect do |name,patient|
    points << '["' + patient['pos'] + '",' + patient['expression'].first + ']'
  end 
  out << points * ',' 
  out << '];'
end

require 'soap/wsdlDriver'               
require 'base64'

def sent_analysis(genes, format = nil)
  PersonalizedMedicine.local_persist(genes.sort, "SENT", :marshal, :genes => genes.sort) do |genes, options|
    format ||= Organism::Hsa.guess_id genes

    tsv = TSV.new({})
    tsv.type = :double
    tsv.namespace = "Hsa"
    tsv.identifiers = Organism::Hsa.identifiers
    tsv.key_field = format
    tsv.fields = []

    genes.each do |gene| tsv[gene] = [] end

    Organism::Hsa.attach_translations tsv, "Entrez Gene ID"

    tsv.attach Organism::Hsa.gene_pmids

    factors = case 
              when genes.length < 100
                genes.length / 10
              when genes.length < 200
                genes.length / 20
              when genes.length < 500
                genes.length / 50
              else
                20
              end
    driver = SOAP::WSDLDriverFactory.new("http://sent.dacya.ucm.es/wsdl/SentWS.wsdl").create_rpc_driver

    job = driver.custom(tsv.reorder("Entrez Gene ID", "PMID").to_s(false).sub(/^#.*\n/,''), factors, "PerMed")
    #job = "PerMed-13"
    while not driver.done job
      puts driver.status job
      sleep 3
    end

    raise driver.messages(job).last if driver.error job

    literature_job = driver.build_index(job, "PerMed_literature[#{job}]")
    #literature_job = "PerMed_literature[#{job}]"
    results = driver.results job

    summary = YAML.load(Base64.decode64 driver.result(results[0]))
    gene_profiles = TSV.new(StringIO.new(Base64.decode64 driver.result(results[2])), :list, :cast => 'to_f')
    word_profiles = TSV.new(StringIO.new(Base64.decode64 driver.result(results[3])), :list, :cast => 'to_f')

    literature_info = {}
    index = tsv.index :target => "Ensembl Gene ID", :fields => "Entrez Gene ID"
    genes.each do |gene|
      entrez = tsv[gene]["Entrez Gene ID"].first
      next if entrez.nil? 

      info = {}
      info[:articles] = tsv[gene]["PMID"]

      info[:group] = summary.index do |group| group[:genes].include? entrez end
      if not info[:group].nil?
        info[:other_genes] = summary[info[:group]][:genes].collect{|e| (index[e] || []).first}
        info[:words] = summary[info[:group]][:words]

        profile = gene_profiles[entrez]
        info[:gene_words] = word_profiles.collect do |word,scores|
          [word, scores.zip(profile).collect{|s,p| s * p}.inject(0){|acc,e| acc += e}]

        end.sort_by{|w,scores| scores}.reverse[0..15].collect{|w,score| w}
      end
      literature_info[gene] = info
    end

    while not driver.done literature_job
      sleep 3
    end
    raise driver.messages(literature_job).last if driver.error literature_job

    literature_info.each do |gene,info|
      articles = info[:articles]
      if info.include? :gene_words
        ranks = TSV.new(StringIO.new(driver.search_literature(job, info[:gene_words])), :single, :cast => 'to_f')
        info[:scores] = articles.collect{|pmid| ranks[pmid] || 0.0}
      else
        info[:scores] = articles.collect{|pmid| pmid.to_i }
      end
      info[:sorted_articles] = articles.zip(info[:scores]).sort_by{|pmid,score| score}.reverse.collect{|pmid,score| pmid}
    end

    literature_info
  end
end

def job_literature_info(tsv, format = "Ensembl Gene ID")
  genes = tsv.slice(format).values.flatten.compact.uniq
  sent_analysis(genes, format)
end

SENT_URL = "http://sent.dacya.ucm.es/"
def gene_entrez_literature_info(gene, job = nil)
  info = PersonalizedMedicine.local_persist(gene, "GeneLiterature", :marshal,  :job => job) do |gene,options|
    job = options[:job]
    info = {}

    info[:articles] = Organism::Hsa.gene_pmids.tsv(:persistence => true, :type => :flat)[gene] || []
    info[:articles] = info[:articles].sort_by{|pmid| pmid.to_i}.reverse

    if not job.nil?
      job_url = File.join(SENT_URL, 'results', job.sub("=",'.'))
      summary = YAML.load(Open.read(job_url + '.summary'))
      
      group = summary.select do |group| group[:genes].include? gene end.first


      if not group.nil?
        info[:scores] = PersonalizedMedicine.local_persist(group[:words], "Literature", :tsv_string, :job => job) do |words, options|
          TSV.new(StringIO.new(SOAP::WSDLDriverFactory.new("http://sent.dacya.ucm.es/wsdl/SentWS.wsdl").create_rpc_driver.search_literature(job.sub(/=.*/,''), words)), :single)
        end

        info[:articles] = info[:articles].sort{|a,b| 
          case 
          when (info[:scores][a].nil? and info[:scores][b].nil?)
            a.to_i <=> b.to_i
          when info[:scores][a].nil?
            -1
          when info[:scores][b].nil?
            1
          else
            info[:scores][a].to_f <=> info[:scores][b].to_f
          end
        }.reverse
        info[:words] = group[:words]
        info[:genes] = group[:genes]
      end
    end

    info
  end

  info
end

if __FILE__ == $0
  genes = TSV.new(Open.open(File.join(File.dirname(__FILE__), 'data/Exclusive.tsv')), :key => "Gene ID", :fields => []).keys
  ddd sent_analysis(genes, "Ensembl Gene ID")
end
