require 'helpers'

field "Associated Gene Name", :width => 100, :display => "Mutated Gene" do
  show do |key, values| 
    if $_table_format == 'html'
      pm = "#{key}, #{first values["Ref Genome Allele"]}/#{first values["Mutation"]}"
      genecard_trigger((values["Associated Gene Name"].first || values["Ensembl Gene ID"].first || "UNKNOWN"), values["Ensembl Gene ID"].first) + "<p>" + pm + "</p>"
    else
      values["Associated Gene Name"] * ", "
    end
  end

  sort_by do |key, values| 
    values["Associated Gene Name"].first || values["Ensembl Gene ID"].first || "UNKNOWN"
  end
end

#field "Mutation", :width => 100, :display => "Mutation" do
#  
#  show do |key, values| 
#    pm = "#{key}, #{first values["Ref Genome Allele"]}/#{first values["Mutation"]}"
#    pm
#  end
#
#  sort_by do |key, values|
#    if key =~ /^\d:/
#      "0" << key
#    else
#      key
#    end
#  end
#end

field "Gene's Pathways", :width => 160 do
  show do |key, value|
    if $_table_format == "html"
      list_summary(kegg_summary(value["KEGG:KEGG Pathway ID"], true))
    else
      kegg_summary(value["KEGG:KEGG Pathway ID"], false).flatten * "|"
    end
  end

  sort_by do |key, value| 
    value["KEGG:KEGG Pathway ID"].size
  end
end

field "Gene's Drugs", :width => 160 do
  show do |key, value|
    if $_table_format == "html"
      list_summary(
        matador_summary(TSV.zip_fields(value.values_at("Matador:Chemical", "Matador:Matador ID", "Matador:Score", "Matador:Annotation", "Matador:Mesh_Score", "Matador:Mesh_Annotation", "Matador:Matador_Score", "Matador:Matador_Annotation")), true) +
        pharmagkb_summary(TSV.zip_fields(value.values_at("PharmaGKB:Drug Name")), true) +
        nci_drug_summary(TSV.zip_fields(value.values_at("NCI:Drugs", "NCI:Drug Concepts")), true)
      ) 
    else
      (
        matador_summary(TSV.zip_fields(value.values_at("Matador:Chemical", "Matador:Matador ID", "Matador:Score", "Matador:Annotation", "Matador:Mesh_Score", "Matador:Mesh_Annotation", "Matador:Matador_Score", "Matador:Matador_Annotation")), false) +
        pharmagkb_summary(TSV.zip_fields(value.values_at("PharmaGKB:Drug Name")), false) +
        nci_drug_summary(TSV.zip_fields(value.values_at("NCI:Drugs", "NCI:Drug Concepts")), false)
      ) * "|"
    end
  end

  sort_by do |key, value| 
    (
        matador_summary(TSV.zip_fields(value.values_at("Matador:Chemical", "Matador:Matador ID", "Matador:Score", "Matador:Annotation", "Matador:Mesh_Score", "Matador:Mesh_Annotation", "Matador:Matador_Score", "Matador:Matador_Annotation")), false) +
        pharmagkb_summary(TSV.zip_fields(value.values_at("PharmaGKB:Drug Name")), false) +
        nci_drug_summary(TSV.zip_fields(value.values_at("NCI:Drugs", "NCI:Drug Concepts")), false)
    ).size
  end
end

field "Gene's Cancers", :width => 160 do
  show do |key, value|
    if $_table_format == "html"
      list_summary(cancer_genes_summary(value.values_at("Cancer:Tumor Type", "NCI:Diseases"), true))
    else
      cancer_genes_summary(value.values_at("Cancer:Tumor Type", "NCI:Diseases"), false).flatten * "|"
    end
  end

  sort_by do |key, value| 
    value.values_at("Cancer:Tumor Type", "NCI:Diseases").flatten.compact.size
  end
end

field "Mutated Protein Isoforms", :width => 150, :display => "Mutated Protein Isoforms" do
  
  show do |key, values| 
    mutations = values["Protein Mutation"]
    proteins = values["Ensembl Protein ID"]
    transcripts = values["Ensembl Transcript ID"]

    trans = Hash[*proteins.zip(transcripts).flatten]
    data = mutations.zip(proteins).uniq.reject{|mutation, protein| 
      mutation.nil? or mutation.empty? or protein.nil? or protein.empty?
    }.collect do |mutation, protein|
      transcript = trans[protein]
      if $_table_format == 'html'
        # "<a target='_blank' href='http://may1609.archive.ensembl.org/Homo_sapiens/Transcript/ProteinSummary?p=#{ protein }'>#{protein} (#{ mutation })</a>"
        #"<a target='_blank' href='http://www.uniprot.org/uniprot/?query=taxonomy%3A9606+AND+reviewed%3Ayes+AND+database%3A%28type%3Aensembl+#{ protein }%29&sort=score'>#{protein} (#{ mutation })</a>"
        #"<a target='_blank' href='http://www.ensembl.org/Homo_sapiens/Component/Transcript/Web/TranslationImage?_rmd=e0aa;db=core;t=#{transcript};export=png;download=0'>#{protein} (#{ mutation })</a>"
        "<a target='_blank' href='http://#{$ensembl_url}/Homo_sapiens/Transcript/ProteinSummary?db=core;t=#{transcript}'>#{protein} (#{ mutation })</a>"

      else
        "#{protein}(#{ mutation })"
      end
    end

    if $_table_format == 'html'
      data * "<br>"
    else
      data * ",\n"
    end
  end
end

field "P.M. type", :width => 60, :align => 'center' do
  
  show do |key, value| 
    mutations = value["Protein Mutation"].reject{|m| m[0] == m[-1]}
    types = []
    types << "Exon Juncture" if value["Exon Junctures"].reject{|e| e.nil? or e.empty?}.any?
    types << "Nonsense" if mutations.select{|m| m[-1] == "*"[0]}.any?
    types << "Missense" if mutations.select{|m| m[-1] != "*"[0]}.any?

    types * ", "
  end

  sort_by do |key, value| 
    mutations = value["Protein Mutation"].reject{|m| m[0] == m[-1]}
    types = []
    types << "Exon Juncture" if value["Exon Junctures"].reject{|e| e.nil? or e.empty?}.any?
    types << "Nonsense" if mutations.select{|m| m[-1] == "*"}.any?
    types << "Missense" if mutations.select{|m| m[-1] != "*"}.any?

    case
    when types.include?("Exon Juncture")
      2
    when types.include?("Nonsense")
      1
    when types.include?("Missense")
      0
    else
      -1
    end
  end
end

def severity(values)
  severity = 0
  severity += 1 if values["Exon Junctures"].any?
  severity += 1 if values["SIFT:Prediction"].select{|v| ["DAMAGING", "Low Confidence"].include? v}.any?
  severity += 1 if values["SNPs&GO:Prediction"].select{|v| ["Disease"].include? v}.any?
  severity
end
field "P.M. Severity", :width => 60 do
  show do |key,value|
    ["Low", "Medium", "High", "Very High", "Very High"][severity(value)]
  end

  sort_by do |key,value|
    severity(value)
  end
end

#field "Suspect", :width => 40 do
#  show do |key,value|
#    "%.3f" % (severity(value) * Math.log(value.values_at("Cancer:Tumor Type", "NCI:Diseases").flatten.compact.length + 1))
#  end
#
#  sort_by do |key,value|
#    severity(value) * Math.log(value.values_at("Cancer:Tumor Type", "NCI:Diseases").flatten.compact.length + 1)
#  end
#
#end

#field "Severity", :width => 50 do
#  show do |key, value|
#    {0 => "Neutral", 1 => "Low", 2 => "Medium", 3 => "High"}[mutation_severity_summary(value)]
#  end
#
#  sort_by do |key, value| 
#    mutation_severity_summary(value)
#  end
#end
#

#field "SIFT:Prediction", :display => "SIFT", :width => 80 do
#  show do |key,value|
#    options = ["DAMAGING", "Low Confidence", "TOLERATED", "No Prediction"]
#    value["SIFT:Prediction"].sort_by{|v| 
#      options.index(v)
#    }.first
#  end
#
#  sort_by do |key, value|
#    options = ["DAMAGING", "Low Confidence", "No Prediction", "TOLERATED"].reverse
#    value["SIFT:Prediction"].collect{|v| 
#      options.index(v)
#    }.sort.last
#  end
#end
#
#field "SNPs&GO:Prediction", :width => 60 do
#  show do |key,value|
#    options = ["Disease", "No Prediction", "Neutral"]
#    value["SNPs&GO:Prediction"].sort_by{|v| 
#      options.index(v)
#    }.first
#  end
#
#  sort_by do |key, value|
#    options = ["Disease", "No Prediction", "Neutral"].reverse
#    value["SNPs&GO:Prediction"].collect{|v| 
#      options.index(v)
#    }.sort.last
#  end
#end
#
##field "Polyphen:Prediction", :width => 60, :hide => true do
##  show do |key, value|
##    value["Polyphen:prediction"].first
##  end
##
##  sort_by do |key, value| 
##    if value["Polyphen:prediction"]
##      case 
##      when first(value["Polyphen:prediction"]) =~ /probably/i
##        2
##      when first(value["Polyphen:prediction"]) =~ /possibly/i
##        1
##      when first(value["Polyphen:prediction"]) =~ /benign/i
##        -1
##      else
##        0
##      end
##    else
##      0
##    end
##  end
##end
#
#
##field "FireDB", :width => 40, :align =>'center', :hide => true do
##  show do |key, value|
##    first value["FireDB:Disease?"]
##  end
##
##  sort_by do |key, value| 
##    case 
##    when (value["FireDB:Disease?"].nil? or value["FireDB:Disease?"].empty?)
##      0
##    when first(value["FireDB:Disease?"]) =~ /Y/
##      1
##    else
##      -1
##    end
##  end
##end

