require 'helpers'

field "Patient", :width => 80

field "Top Lost Genes", :width => 300  do
  show do |key,values|
    field_pos   = values.positions "top5_loss"
    ensembl_pos = values.positions "Ensembl Gene ID"
    name_pos    = values.positions "Associated Gene Name"
    v = TSV.zip_fields(values)

    list = v.select{|vv| 
      vv[field_pos] == "1"
    }.collect{|vv| [vv[ensembl_pos].first, vv[name_pos].first]}
    if $_table_format == 'html'
      list.collect{|ensembl,name| genecard_trigger name || ensembl || "UNKNOWN", ensembl } * ', ' 
    else
      list.collect{|ensembl,name| name} * ", "
    end
  end

  sort_by do |key,values|
    v = TSV.zip_fields(values[0..values.length - 2])

    field_pos   = values.positions "top5_loss"
    list = v.select{|vv| 
      vv[field_pos] == "1"
    }.collect{|vv| vv[ensembl_pos].first}
    list.sort * " "
  end
end

field "# Lost", :width => 50, :align => 'center' do
  show do |key,values|
    v = TSV.zip_fields(values)
    field_pos   = values.positions "type"
    v.select{|vv| vv[field_pos] == "Loss"}.length
  end

  sort_by do |key,values|
    v = TSV.zip_fields(values[0..values.length - 2])
    field_pos   = values.positions "type"
    v.select{|vv| vv[field_pos] == "Loss"}.length
  end
end

field "Top Gained Genes", :width => 300  do
  show do |key,values|
    field_pos   = values.positions "top5_gain"
    ensembl_pos = values.positions "Ensembl Gene ID"
    name_pos    = values.positions "Associated Gene Name"
    v = TSV.zip_fields(values)

    list = v.select{|vv| 
      vv[field_pos] == "1"
    }.collect{|vv| [vv[ensembl_pos].first, vv[name_pos].first]}
    if $_table_format == 'html'
      list.collect{|ensembl,name| genecard_trigger name || ensembl || "UNKNOWN", ensembl } * ', ' 
    else
      list.collect{|ensembl,name| name} * ", "
    end
  end

  sort_by do |key,values|
    v = TSV.zip_fields(values)

    field_pos   = values.positions "top5_gain"
    list = v.select{|vv| 
      vv[field_pos] == "1"
    }.collect{|vv| vv[ensembl_pos].first}
    list.sort * " "
  end
end

field "# Gained", :width => 50, :align => 'center' do
  show do |key,values|
    v = TSV.zip_fields(values[0..values.length - 2])
    field_pos   = values.positions "type"
    v.select{|vv| vv[field_pos] == "Gain"}.length
  end

  sort_by do |key,values|
    v = TSV.zip_fields(values[0..values.length - 2])
    field_pos   = values.positions "type"
    v.select{|vv| vv[field_pos] == "Gain"}.length
  end
end

