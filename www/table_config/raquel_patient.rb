require 'helpers'

field "Patient"

field "Top Lost Genes" do
  show do |key,values|
    v = TSV.zip_fields(values)
    list = []
    v.each{|vv| if vv["top5_loss"] == "1";then list << vv.first end}
    list.sort
  end

  sort_by do |key,values|
    v = TSV.zip_fields(values)
    list = []
    v.each{|vv| if vv["top5_loss"] == "1";then list << vv.first end}
    list.sort * " "
  end
end

field "Top Gain Genes" do
  show do |key,values|
    v = TSV.zip_fields(values)
    list = []
    v.each{|vv| if vv["top5_gain"] == "1";then list << vv.first end}
    list.sort
  end

  sort_by do |key,values|
    v = TSV.zip_fields(values)
    list = []
    v.each{|vv| if vv["top5_gain"] == "1";then list << vv.first end}
    list.sort * " "
  end
end

