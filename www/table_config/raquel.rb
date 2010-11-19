require 'helpers'

field "Name", :width => 80, :display => "Gene Name" do
  show do |key, values| 
    if $_table_format == 'html'
      genecard_trigger values["Name"], values["Name"].compact.reverse.first
    else
      values["Name"].compact.reverse.first 
    end
  end

  sort_by do |key, values| 
    values["Name"].compact.reverse.first 
  end
end



field "Position", :width => 100 do
  show do |key, values| 
    "#{values["Chromosome"]}:#{values["Start"]}, #{values["End"]}"
  end

  sort do |a, b| 
    av, bv = a[1], b[1]
    if av["Chromosome"].first != bv["Chromosome"].first
      av["Chromosome"].first.to_i <=> bv["Chromosome"].first.to_i
    else
      av["Start"].first.to_i <=> bv["Start"].first.to_i
    end
  end
end


field "Sig. Lost in Patients" , :width => 100 , :align =>'center' do
  show do |key, values| 
    values["Patients"].select do |patient, patient_info|
      first(patient_info["type"]) == "Lost" and first(patient_info["probability"]).to_f.abs  > 0.95
    end.length
  end

  sort_by do |key, values| 
    values["Patients"].select do |patient, patient_info|
       first(patient_info["type"]) == "Lost"  and first(patient_info["probability"]).to_f.abs  > 0.95
    end.length
  end
end


field "Sig. Gained in Patients" , :width => 120, :align =>'center' do
  show do |key, values| 
    values["Patients"].select do |patient, patient_info|
      first(patient_info["type"]) == "Gain" and first(patient_info["probability"]).to_f.abs  > 0.95
    end.length
  end

  sort_by do |key, values| 
    values["Patients"].select do |patient, patient_info|
       first(patient_info["type"]) == "Gain"  and first(patient_info["probability"]).to_f.abs  > 0.95
    end.length
  end

end

field "Cancers", :width => 80 do
  show do |key, value|
    if $_table_format == "html"
      list_summary(cancer_genes_summary(value["Gene Info"][:Anais_cancer], true))
    else
      cancer_genes_summary(value["Gene Info"][:Anais_cancer], false)
    end
  end

  sort_by do |key, value| 
    (value["Gene Info"][:Anais_cancer] || []).size
  end
end

field "Cancers [NCI]", :width => 100 do
  show do |key, value|
    if $_table_format == "html"
      list_summary(nci_diseases_summary(value["Gene Info"][:NCI_cancer], true))
    else
      nci_diseases_summary(value["Gene Info"][:NCI_cancer], false)
    end
  end

  sort_by do |key, value| 
    (value["Gene Info"][:NCI_cancer] || []).size
  end
end


field "Pathways", :width => 120 do
  show do |key, value|
    if $_table_format == "html"
      list_summary(kegg_summary(value["Gene Info"][:KEGG], true))
    else
      kegg_summary(value["Gene Info"][:KEGG], false) * ", "
    end
  end

  sort_by do |key, value| 
    (value["Gene Info"][:KEGG] || []).size
  end
end

field "Drugs", :width => 120 do
  show do |key, value|
    if $_table_format == "html"
      list_summary(matador_summary(value["Gene Info"][:Matador], true) + pharmagkb_summary(value["Gene Info"][:PharmaGKB], true) + nci_drug_summary(value["Gene Info"][:NCI], true))
    else
      (matador_summary(value["Gene Info"][:Matador], false) + pharmagkb_summary(value["Gene Info"][:PharmaGKB], false) + nci_drug_summary(value["Gene Info"][:NCI], false)) * ", "
    end
  end

  sort_by do |key, value| 
    ((value["Gene Info"][:Matador] || []) + (value["Gene Info"][:PharmaGKB] || []) + (value["Gene Info"][:NCI] || [])).size
  end
end
