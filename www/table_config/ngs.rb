require 'helpers'

field "Gene", :width => 60, :display => "Gene Name" do
  show do |key, values| 
    if $_table_format == 'html'
      genecard_trigger(values["Associated Gene Name"].first || values["Ensembl Gene ID"].first || "UNKNOWN"), values["Ensembl Gene ID"].first
    else
      values["Associated Gene Name"] * ", "
    end
  end

  sort_by do |key, values| 
    values["Associated Gene Name"].first || values["Ensembl Gene ID"].first || "UNKNOWN"
  end
end

field "Mutation", :width => 130, :display => "Mutation" do
  
  show do |key, values| 
    pm = "#{first(values["Chr"])}:#{key}, #{first values["Ref Genome Allele"]}/#{first values["Variant Allele"]}"
    if (first values["Substitution"]) != ""
       pm << " (#{first values["Substitution"]})"
    end  
    pm
  end

  sort do |a, b| 
    av, bv = a[1], b[1]
    if av["Chr"].first != bv["Chr"].first
      av["Chr"].first.to_i <=> bv["Chr"].first.to_i
    else
      a[0].to_i <=> b[0].to_i
    end
  end
end


field "Type", :width => 30, :align => 'center' do
  
  show do |key, value| 
    case first(value["SNP Type"]) 
    when "Nonsynonymous"
      "N"
    when "NA"
      "NA"
    when "Synonymous"
      "S"
    end
  end

  sort_by do |key, value| 
    case first(value["SNP Type"]) 
    when "Nonsynonymous"
      1
    when "NA"
      0
    when "Synonymous"
      -1
    else
      0
    end
  end
end

field "Ubio Score", :display => "Score", :width => 30, :align=> 'center' do
  sort_by do |key, value| first(value["Ubio Score"]).to_i end
end

field "Severity", :width => 50 do
  show do |key, value|
    {0 => "Neutral", 1 => "Low", 2 => "Medium", 3 => "High"}[mutation_severity_summary(value)]
  end

  sort_by do |key, value| 
    mutation_severity_summary(value)
  end
end

field "SIFT:Prediction", :display => "SIFT", :width => 80 ,:hide => true do
  sort_by do |key, value|
    case
    when value["SIFT:Prediction"].first =~ /Low confidence/
      1
    when value["SIFT:Prediction"].first =~ /DAMAGING/
      2
    when value["SIFT:Prediction"].first =~ /TOLERATED/
      -1
    else
      0
    end
  end
end

field "Polyphen:prediction", :width => 60, :hide => true do
  show do |key, value|
    value["Polyphen:prediction"].first
  end

  sort_by do |key, value| 
    if value["Polyphen:prediction"]
      case 
      when first(value["Polyphen:prediction"]) =~ /probably/i
        2
      when first(value["Polyphen:prediction"]) =~ /possibly/i
        1
      when first(value["Polyphen:prediction"]) =~ /benign/i
        -1
      else
        0
      end
    else
      0
    end
  end
end

field "SNP&GO", :width => 60, :hide => true do
  show do |key, value|
    first(value["SNP&GO:Disease?"])
  end

  sort_by do |key, value| 
    if value["SNP&GO:Disease?"]
      case 
      when first(value["SNP&GO:Disease?"]) =~ /Disease/i
        1
      else
        -1
      end
    else
      0
    end
 
  end
end

field "FireDB", :width => 40, :align =>'center', :hide => true do
  show do |key, value|
    first value["FireDB:Disease?"]
  end

  sort_by do |key, value| 
    case 
    when (value["FireDB:Disease?"].nil? or value["FireDB:Disease?"].empty?)
      0
    when first(value["FireDB:Disease?"]) =~ /Y/
      1
    else
      -1
    end
  end
end

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


field "OMIM Disease", :width => 100, :display => "Mutation in OMIM"

field "Barcode", :width => 100, :display => "Probe Express." do
  sort_by do |key,values|
    if values["Barcode"].empty?
      0
    else
      values["Barcode"].inject(0){|acc,e| acc += e.to_i}.to_f / values["Barcode"].length
    end
  end
end
