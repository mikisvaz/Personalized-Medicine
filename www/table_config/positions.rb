require 'helpers'

field "Associated Gene Name", :width => 100, :display => "Gene Name" do
  show do |key, values| 
    if $_table_format == 'html'
      genecard_trigger (values["Associated Gene Name"].first || values["Ensembl Gene ID"].first || "UNKNOWN"), values["Ensembl Gene ID"].first
    else
      values["Associated Gene Name"] * ", "
    end
  end

  sort_by do |key, values| 
    values["Associated Gene Name"].first || values["Ensembl Gene ID"].first || "UNKNOWN"
  end
end

field "Mutation", :width => 100, :display => "Mutation" do
  
  show do |key, values| 
    pm = "#{key}, #{first values["Ref Genome Allele"]}/#{first values["Mutation"]}"
    pm
  end
end

field "Protein Mutation", :width => 150, :display => "Protein Mutation" do
  
  show do |key, values| 
    mutations = values["Protein Mutation"]
    proteins = values["Ensembl Protein ID"]

    data = mutations.zip(proteins).uniq.reject{|mutation, protein| 
      mutation.nil? or mutation.empty? or protein.nil? or protein.empty?
    }.collect do |mutation, protein|
      if $_table_format == 'html'
        "<a target='_blank' href='http://may2009.archive.ensembl.org/Homo_sapiens/Transcript/ProteinSummary?p=#{ protein }'>#{protein} (#{ mutation })</a>"
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

field "Type", :width => 80, :align => 'center' do
  
  show do |key, value| 
    mutations = value["Protein Mutation"].reject{|m| m[0] == m[-1]}
    types = []
    types << "Splicing" if value["Exon Junctures"].reject{|e| e.nil? or e.empty?}.any?
    types << "Nonsense" if mutations.select{|m| m[-1] == "*"[0]}.any?
    types << "Missense" if mutations.select{|m| m[-1] != "*"[0]}.any?

    types * ", "
  end

  sort_by do |key, value| 
    mutations = value["Protein Mutation"].reject{|m| m[0] == m[-1]}
    types = []
    types << "Splicing" if value["Exon Junctures"].reject{|e| e.nil? or e.empty?}.any?
    types << "Nonsense" if mutations.select{|m| m[-1] == "*"}.any?
    types << "Missense" if mutations.select{|m| m[-1] != "*"}.any?

    case
    when types.include?("Splicing")
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

#field "Severity", :width => 50 do
#  show do |key, value|
#    {0 => "Neutral", 1 => "Low", 2 => "Medium", 3 => "High"}[mutation_severity_summary(value)]
#  end
#
#  sort_by do |key, value| 
#    mutation_severity_summary(value)
#  end
#end

field "SIFT:Prediction", :display => "SIFT", :width => 80 do
  show do |key,value|
    case
    when value["SIFT:Prediction"].select{|v| v =~ /DAMAGING/}.any?
      "DAMAGING"
    when value["SIFT:Prediction"].select{|v| v =~ /Low confidence/}.any?
      "Low confidence"
    when value["SIFT:Prediction"].select{|v| v =~ /TOLERATED/}.any?
      "TOLERATED"
    else
      "Not Predicted"
    end
 
  end

  sort_by do |key, value|
    case
    when value["SIFT:Prediction"].select{|v| v =~ /DAMAGING/}.any?
      2
    when value["SIFT:Prediction"].select{|v| v =~ /Low confidence/}.any?
      1
    when value["SIFT:Prediction"].select{|v| v =~ /TOLERATED/}.any?
      -1
    else
      0
    end
  end
end

#field "Polyphen:Prediction", :width => 60, :hide => true do
#  show do |key, value|
#    value["Polyphen:prediction"].first
#  end
#
#  sort_by do |key, value| 
#    if value["Polyphen:prediction"]
#      case 
#      when first(value["Polyphen:prediction"]) =~ /probably/i
#        2
#      when first(value["Polyphen:prediction"]) =~ /possibly/i
#        1
#      when first(value["Polyphen:prediction"]) =~ /benign/i
#        -1
#      else
#        0
#      end
#    else
#      0
#    end
#  end
#end

field "SNPs&GO:Prediction", :width => 60 do
  show do |key, value|
    first(value["SNPs&GO:Prediction"])
  end

  sort_by do |key, value| 
    if value["SNPs&GO:Prediction"]
      case 
      when first(value["SNPs&GO:Prediction"]) =~ /Disease/i
        1
      else
        -1
      end
    else
      0
    end
 
  end
end

#field "FireDB", :width => 40, :align =>'center', :hide => true do
#  show do |key, value|
#    first value["FireDB:Disease?"]
#  end
#
#  sort_by do |key, value| 
#    case 
#    when (value["FireDB:Disease?"].nil? or value["FireDB:Disease?"].empty?)
#      0
#    when first(value["FireDB:Disease?"]) =~ /Y/
#      1
#    else
#      -1
#    end
#  end
#end

field "Pathways", :width => 100 do
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

field "Drugs", :width => 100 do
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

field "Cancers", :width => 100 do
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
