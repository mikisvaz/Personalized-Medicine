require 'helpers'

field "Patient", :width => 80

field "Top Lost Genes", :width => 300  do
  show do |key,values|
    v = TSV.zip_fields(values)
    list = []
    v.each{|vv| if vv["top5_loss"] == "1";then list << vv.first end}.sort
    if $_table_format == 'html'
      list.collect{|name| genecard_trigger name, name } * ', ' 
    else
      list * ", "
    end
  end

  sort_by do |key,values|
    v = TSV.zip_fields(values)
    list = []
    v.each{|vv| if vv["top5_loss"] == "1";then list << vv.first end}
    list.sort * " "
  end
end

field "# Loss", :width => 40, :align => 'center' do
  show do |key,values|
    v = TSV.zip_fields(values)
    v.select{|vv| vv["type"] == "Loss"}.length
  end

  sort_by do |key,values|
    v = TSV.zip_fields(values)
    v.select{|vv| vv["type"] == "Loss"}.length
  end
end

field "Top Gain Genes", :width => 300 do
  show do |key,values|
    ddd values
    v = TSV.zip_fields(values)
    list = []
    v.each{|vv| if vv["top5_gain"] == "1";then list << vv.first end}.sort
    if $_table_format == 'html'
      list.collect{|name| genecard_trigger name, name } * ', ' 
      genecard_trigger (values["Associated Gene Name"].first || key || "UNKNOWN"), key
    else
      list * ", "
    end
  end

  sort_by do |key,values|
    v = TSV.zip_fields(values)
    list = []
    v.each{|vv| if vv["top5_gain"] == "1";then list << vv.first end}
    list.sort * " "
  end
end

field "# Gain", :width => 40, :align => 'center' do
  show do |key,values|
    v = TSV.zip_fields(values)
    v.select{|vv| vv["type"] == "Gain"}.length
  end
  sort_by do |key,values|
    v = TSV.zip_fields(values)
    v.select{|vv| vv["type"] == "Gain"}.length
  end
end

