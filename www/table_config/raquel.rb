require 'helpers'

field "Name", :width => 80, :display => "Gene Name" do
  show do |key, values| 
    if $_table_format == 'html'
      genecard_trigger (values["Associated Gene Name"].first || key || "UNKNOWN"), key
    else
      values["Name"] 
    end
  end

  sort_by do |key, values| 
    values["Name"] 
  end
end



# field "Position", :width => 100 do
#   show do |key, values| 
#     "#{values["Chromosome"]}:#{values["Start"]}, #{values["End"]}"
#   end
# 
#   sort do |a, b| 
#     av, bv = a[1], b[1]
#     if av["Chromosome"].first != bv["Chromosome"].first
#       av["Chromosome"].first.to_i <=> bv["Chromosome"].first.to_i
#     else
#       av["Start"].first.to_i <=> bv["Start"].first.to_i
#     end
#   end
# end


field "Lost in Patients", :width => 100, :align => 'center' do
  show do |key, value|
   value["Lost in Patients"].first
  end 

  sort_by do |key, value| 
   value["Lost in Patients"].first.to_i
  end
end

field "Gained in Patients", :width => 100, :align => 'center' do
  show do |key, value|
   value["Gained in Patients"].first
  end 

  sort_by do |key, value| 
   value["Gained in Patients"].first.to_i
  end
end

field "T5 Lost", :width => 100, :align => 'center' do
  show do |key, value|
    value["T5 Lost"].length
  end 

  sort_by do |key, value| 
   value["T5 Lost"].length
  end
end

field "T5 Gained", :width => 100, :align => 'center' do
  show do |key, value|
   value["T5 Gained"].length
  end 

  sort_by do |key, value| 
   value["T5 Gained"].length
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

