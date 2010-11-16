require 'cgi'
require 'rbbt/sources/entrez'

def gene_info(data, gene)
  data.each do |key, value|
    field_name = value.fields.include?("Gene")? "Gene" : "Name"
    return value["Gene Info"] if value[field_name] == gene 
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

def first(array)
  (array || [""]).first
end

def genecard_trigger(gname, text)
  "<a class='genecard_trigger' href='/ajax/genecard' onclick='update_genecard(\"#{gname * "_"}\");return(false);'>#{text}</a>"
end


def list_summary(list)
  return list unless Array === list
  code = Digest::MD5.hexdigest(list.inspect)
  if list.length < 3 
    list * ', '
  else
    list[0..1] * ', ' + ', ' +
      "<a id='#{code}' class=expand href='' value='#{CGI.escapeHTML(list * ', ').gsub(/'/,'"')}' onclick='expand_field(\"#{code}\");return(false)'>#{list.size - 2} more ...<a>"
  end
end


def mutation_severity_summary(mutation)
  count = 0

  count += 1 if first(mutation["Prediction"])
  count += 1 if mutation["SNP&GO"] and first(mutation["SNP&GO"]["Disease?"]) == 'Disease'
  count += 1 if mutation["Polyphen"] and first(mutation["Polyphen"]["prediction"]) =~ /damaging/

    count
end

def kegg_summary(pathways, html = true)
  return [] if pathways.nil?
  pathways.collect do |code|
    desc = $kegg_pathway_index[code].sub(/- Homo sapiens.*/,'')
    cancer = ''
    if html
      TSV.zip_fields($anais[code]).each do |p|
        cancer, type, score, desc2 = p
        css_class = (score != nil and score.to_f <= 0.1)?'red':'green';
        cancer += " <span class='#{ css_class } cancertype'>[#{ cancer }]</span>"
      end
      "<a target='_blank' href='http://www.genome.jp/kegg-bin/show_pathway?#{code}'>#{desc} #{ cancer }</a>"
    else
      desc 
    end 
  end 
end


def matador_summary(matador_drugs, html = true)
  return [] if matador_drugs.nil?
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
      "<a target='_blank' href='http://www.pharmgkb.org/do/serve?objCls=Drug&objId=#{d.first}'>#{$PharmaGKB_drug_index[d.first]}</a> [PGKB]"
    else
      $PharmaGKB_drug_index[d.first]
    end
  end
end

def nci_drug_summary(nci_drugs, html = true)
  return [] if nci_drugs.nil?
  nci_drugs.reject{|d| d.first.empty?}.collect do |d|
    if html
      "<a target='_blank' href='http://ncit.nci.nih.gov/ncitbrowser/pages/concept_details.jsf?dictionary=NCI%20Thesaurus&type=properties&code=#{d[1]}'>#{d.first}</a> [NCI]"
    else
      d.first
    end
  end.uniq
end

def cancer_genes_summary(cancers, html = true)
  return [] if cancers.nil?
  cancers.collect do |c|
    if html
      "<span>#{c}</span>"
    else
      c
    end
  end
end

def nci_diseases_summary(nci_diseases, html = true)
  return [] if nci_diseases.nil?
  nci_diseases.collect do |c|
    if html
      "<span>#{c.first}</span>"
    else
      c.first
    end
  end.uniq
end

def pathway_details_summary(kegg_pathways)
  return '' if kegg_pathways.nil?
  out =  ''
  kegg_pathways.collect do |code|
    desc = $kegg_pathway_index[code].sub(/- Homo sapiens.*/,'')
    out += "<a href='http://www.genome.jp/kegg/pathway/hsa/#{code}.png'  class='top_up'><img src='http://www.genome.jp/kegg/pathway/hsa/#{code}.png' style='height:50px;float:left;margin-right:10px;margin-botton:10px;' title='Click to enlarge'/></a>";
    out += "<h3>#{desc} <a target='_blank' href='http://www.genome.jp/kegg-bin/show_pathway?#{code}'>[+]</a></h3>"
    name = ''
    cancers = TSV.zip_fields($anais[code])
    if (cancers.size != 0)
      out += '<h4>This pathway has more mutations than expected by chance in the following tumour types</h4>'
      cancers.each do |p|
        cancer, type, score, desc2 = p
        css_class = (score != nil and score.to_f <= 0.1)?'red':'green';
        out += " <span class='#{ css_class } cancertype'>[#{ cancer }]</span> "
      end
    end
    out += '<div style="height:30px;">&nbsp;</div>'
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
