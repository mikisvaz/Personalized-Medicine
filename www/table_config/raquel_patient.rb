require 'helpers'

field "Patient"

field "Top Lost Genes" do
  show do |key,values|
    v = TSV.zip_fields(values)
    list = []
    v.each{|vv| if vv["top5_loss"] == "1";then list << vv.first end}
    list.sort * ", "
  end

  sort_by do |key,values|
    v = TSV.zip_fields(values)
    list = []
    v.each{|vv| if vv["top5_loss"] == "1";then list << vv.first end}
    list.sort * " "
  end
end

field "Number of Gene Sig. Lost (0.05)" do
  show do |key,values|
    v = TSV.zip_fields(values)
    v.select{|vv| vv["type"] == "Loss" && vv["probability"].to_f.abs > 0.95}.length
  end
end

field "Top Gain Genes" do
  show do |key,values|
    v = TSV.zip_fields(values)
    list = []
    v.each{|vv| if vv["top5_gain"] == "1";then list << vv.first end}
    list.sort * ", "
  end

  sort_by do |key,values|
    v = TSV.zip_fields(values)
    list = []
    v.each{|vv| if vv["top5_gain"] == "1";then list << vv.first end}
    list.sort * " "
  end
end

field "Number of Gene Sig. Gain (0.05)" do
  show do |key,values|
    v = TSV.zip_fields(values)
    v.select{|vv| vv["type"] == "Gain" && vv["probability"].to_f.abs > 0.95}.length
  end
end

