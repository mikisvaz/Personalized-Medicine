require 'helpers'

field "Name", :width => 80, :display => "Gene Name" do
  show do |key, values| 
    if $_table_format == 'html'
      genecard_trigger values["Name"], values["Name"]
    else
      values["Name"] 
    end
  end

  sort_by do |key, values| 
    values["Name"] 
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


field "Lost in Patients", :width => 100, :align => 'center' do
  show do |key, values| 
    values["Patients"].select do |patient, patient_info|
      first(patient_info["type"]) == "Loss"
    end.length
  end

  sort_by do |key, values| 
    values["Patients"].select do |patient, patient_info|
       first(patient_info["type"]) == "Loss"
    end.length
  end
end

field "T5 Lost", :width => 40, :align => 'center' do
  show do |key, values| 
    values["Patients"].select do |patient, patient_info|
      first(patient_info["top5_loss"]) == "1"
    end.length
  end

  sort_by do |key, values| 
    values["Patients"].select do |patient, patient_info|
      first(patient_info["top5_loss"]) == "1"
    end.length
  end
end



field "Gained in Patients", :width => 120, :align =>'center'do
  show do |key, values| 
    values["Patients"].select do |patient, patient_info|
      first(patient_info["type"]) == "Gain"
    end.length
  end

  sort_by do |key, values| 
    values["Patients"].select do |patient, patient_info|
       first(patient_info["type"]) == "Gain"
    end.length
  end

end

field "T5 Gain", :width => 40, :align => 'center' do
  show do |key, values| 
    values["Patients"].select do |patient, patient_info|
      first(patient_info["top5_gain"]) == "1"
    end.length
  end

  sort_by do |key, values| 
    values["Patients"].select do |patient, patient_info|
      first(patient_info["top5_gain"]) == "1"
    end.length
  end
end

field "Cancers", :width => 100 do
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

field "Cancers [NCI]", :width => 150 do
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


field "Pathways", :width => 150 do
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

field "Drugs", :width => 150 do
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
