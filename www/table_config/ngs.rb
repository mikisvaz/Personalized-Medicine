require 'helpers'

field "Gene", :width => 50, :display => "Gene Name" do
  show do |key, values| 
    if $_table_format == 'html'
      genecard_trigger values["Gene"], values["Gene"].compact.reverse.first
    else
      values["Gene"].compact.reverse.first 
    end
  end

  sort_by do |key, values| 
    values["Gene"].compact.reverse.first 
  end
end

field "Position", :width => 100 do
  
  show do |key, values| 
    "#{first(values["Chr"])}:#{first values["Position"]}, #{first values["Ref Genome Allele"]}/#{first values["Variant Allele"]}"
  end

  sort do |a, b| 
    av, bv = a[1], b[1]
    if av["Chr"].first != bv["Chr"].first
      av["Chr"].first.to_i <=> bv["Chr"].first.to_i
    else
      av["Position"].first.to_i <=> bv["Position"].first.to_i
    end
  end
end

field "Substitution", :width => 100 

field "Type", :width => 100 do
  sort_by do |key, value| 
    case first(value["Type"]) 
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

field "Score", :width => 100 do
  sort_by do |key, value| first(value["Score"]).to_i end
end

field "Severity", :width => 100 do
  show do |key, value|
    {0 => "Neutral", 1 => "Low", 2 => "Medium", 3 => "High"}[mutation_severity_summary(value)]
  end

  sort_by do |key, value| 
    mutation_severity_summary(value)
  end
end

field "Polyphen", :width => 100 do
  show do |key, value|
    if value["Polyphen"]
      first value["Polyphen"]["prediction"]
    else
      ""
    end
  end

  sort_by do |key, value| 
    if value["Polyphen"]
      case 
      when first(value["Polyphen"]["prediction"]) =~ /probably/i
        2
      when first(value["Polyphen"]["prediction"]) =~ /possibly/i
        1
      when first(value["Polyphen"]["prediction"]) =~ /benign/i
        -1
      else
        0
      end
    else
      0
    end
  end
end

field "SNP&GO", :width => 100 do
  show do |key, value|
    if value["SNP&GO"]
      first(value["SNP&GO"]["Disease?"])
    else
      ""
    end
  end

  sort_by do |key, value| 
    if value["SNP&GO"]
      case 
      when first(value["SNP&GO"]["Disease?"]) =~ /Disease/i
        1
      else
        -1
      end
    else
      0
    end
 
  end
end


field "FireDB", :width => 100 do
  show do |key, value|
    if value["FireDB"]
      first value["FireDB"]["Disease?"]
    else
      ""
    end
  end

  sort_by do |key, value| 
    if value["FireDB"]
      case 
      when first(value["FireDB"]["Disease?"]) =~ /Y/
        1
      else
        -1
      end
    else
      0
    end
 
  end
end

field "OMIM Disease", :display => "Mutation in OMIM"

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

field "Pathways", :width => 100 do
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

field "Drugs", :width => 100 do
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
