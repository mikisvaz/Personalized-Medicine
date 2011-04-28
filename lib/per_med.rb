require 'rbbt-util'
require 'rbbt/sources/cancer'
require 'rbbt/sources/organism'
require 'rbbt/sources/kegg'
require 'rbbt/sources/pharmagkb'
require 'rbbt/sources/matador'
require 'rbbt/sources/string'
require 'rbbt/sources/nci'
require 'rbbt/statistics/hypergeometric'
require 'rbbt/mutation/snps_and_go'
require 'rbbt/mutation/sift'

module PersonalizedMedicine
  ROOT_DIR = File.join(File.dirname(__FILE__), '..')
  DATA_DIR = File.join(ROOT_DIR, 'data')
  TSV_CACHE_DIR = File.join(ROOT_DIR, 'cache','tsv')

  def self.local_persist(*args, &block)
    argsv = *args
    options = argsv.pop
    if Hash === options
      options.merge!(:persistence_dir => TSV_CACHE_DIR)
      argsv.push options
    else
      argsv.push options
      argsv.push({:persistence_dir => TSV_CACHE_DIR})
    end
    Persistence.persist(*argsv, &block)
  end

  def self.chromosome_bed(organism = "Hsa/may2009")
    return @chromosome_bed[organism] if defined? @chromosome_bed and @chromosome_bed.include? organism

    @chromosome_bed ||= {}
    @chromosome_bed[organism] = {}

    %w(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 X Y).collect do |chromosome|
      @chromosome_bed[organism][chromosome] = Persistence.persist(Organism.gene_positions(organism), "Gene_positions[#{chromosome}]", :fwt, :chromosome => chromosome, :range => true) do |file, options|
        tsv = file.tsv(:persistence => true, :type => :list)
        tsv.select("Chromosome Name" => chromosome).collect do |gene, values|
          [gene, values.values_at("Gene Start", "Gene End").collect{|p| p.to_i}]
        end
      end
    end

    @chromosome_bed[organism]
  end

  def self.positions(filename)
    organism = "Hsa/may2009"

    require 'rbbt/sources/organism/sequence'
    tsv = TSV.new filename

    tsv.namespace = "Hsa"
    tsv.identifiers = Organism[organism].identifiers.find

    tsv.attach Organism.job(:genomic_mutations_to_protein_mutations, name, tsv.to_s, :organism => organism ).run.load                 
    tsv.attach Organism.job(:genomic_mutations_to_genes, name, tsv.to_s, :organism => organism ).run.load                 
    tsv.attach Organism.job(:genomic_mutations_in_exon_junctures, name, tsv.to_s, :organism => organism ).run.load                 

    Organism.attach_translations(organism, tsv, "Associated Gene Name")
    Organism.attach_translations(organism, tsv, "Entrez Gene ID")


    ensp_field = tsv.identify_field "Ensembl Protein ID"

    uniprot_index = Organism.protein_identifiers(organism).index :target => "UniProt/SwissProt Accession", :fields => "Ensembl Protein ID"
    tsv.add_field "UniProt/SwissProt Accession" do |key,values|
      (values[ensp_field] || []).collect{|ensp| (uniprot_index[ensp] ||[]).first}
    end

    refseq_index = Organism.protein_identifiers(organism).index :target => "Refseq Protein ID", :fields => "Ensembl Protein ID"
    tsv.add_field "Refseq Protein ID" do |key,values|
      (values[ensp_field] || []).collect{|ensp| (refseq_index[ensp] || []).first}
    end

    SIFT.add_predictions tsv
    SNPSandGO.add_predictions tsv

    tsv.attach KEGG.gene_drug, nil, :persist_input => true
    tsv.attach KEGG.gene_pathway, nil, :persist_input => true
    tsv.attach KEGG.pathways, nil, :in_namespace => "KEGG", :persist_input => true
    tsv.attach Matador.protein_drug, nil, :persist_input => true
    tsv.attach PharmaGKB.gene_drug, nil, :persist_input => true
    tsv.attach PharmaGKB.gene_disease, nil, :persist_input => true
    tsv.attach PharmaGKB.gene_pathway, nil, :persist_input => true
    tsv.attach NCI.gene_drug, nil, :persist_input => true
    tsv.attach NCI.gene_cancer, nil, :persist_input => true
    tsv.attach Cancer.anais_annotations, nil, :persist_input => true

    tsv
  end

  def self.NGS_Preal(filename)
    data = TSV.new(filename, :key => 'Position1', :keep_empty => true)

    gene_names         = data.reorder :key, "Gene Name"
    gene_names.add_field "Ensembl Gene ID" do |key, values|
      [values["Gene Name"].last]
    end

    gene_names.process "Gene Name" do |field_values,key,values|
      [field_values.first.dup]
    end

    mutations          = data.reorder :key, ['Chr', 'Position1','Ref Genome Allele','Variant Allele', 'SNP Type', 'Ubio Score', 'Prediction']

    mutations.add_field "Substitution" do |key, values|
      []
    end

    mutations.add_field "OMIM Disease" do |key, values|
      []
    end


    snp      = TSV.new(File.join(DATA_DIR,'SNP_GO','snp_go.txt'), :key => 'Mutation', :keep_empty => true).select []
    polyphen = TSV.new(File.join(DATA_DIR,'Polyphen','polyphen'), :key => 'id', :keep_empty => true).select []
    firedb   = TSV.new(File.join(DATA_DIR,'FireDB','firedb'), :key => 'Mutation', :keep_empty => true).select []

    mutation_data = TSV.new({})
    gene_data = TSV.new({})
    unknown_genes = 0
    data.keys.each do |position|
      gene_name = gene_names[position].flatten.collect{|name| name =~ /Gene Annotation Error/ ? "" : name }

      if gene_name.reject{|n| n.empty? }.empty?
        gene_name = ["UNKNOWN-#{unknown_genes}"] * 3
        unknown_genes += 1
      end

      gene_data[gene_name] ||= get_gene_info gene_name

      mutation_info = mutations[position]
      code = mutation_info['Substitution']

      snp_info = snp[code] 
      mutation_info << snp_info

      poly_info = polyphen[code]
      mutation_info << poly_info

      firedb_info = firedb[code] 
      mutation_info << firedb_info

      mutation_data[position] = mutation_info
      mutation_data[position] << gene_name
      mutation_data[position] << gene_data[gene_name]
    end

    mutation_data.fields = MUTATION_FIELDS + [ "SNP&GO", "Polyphen", "FireDB", "Gene", "Gene Info"]

    mutation_data
  end

  def self.NGS(filename, organism = "Hsa/may2009")
    fields = ["Chr", "Ref Genome Allele", "Variant Allele", "Ubio Score",  "Substitution", "SNP Type", "SIFT:Prediction", "SIFT:Score", "OMIM Disease"]

    data = local_persist(filename, :Misc, :tsv_string, :persistence => false, :persistence_update => true) do |file, options, filename|
      data = TSV.new(file, :key => 'Position1', :fields => fields, :keep_empty => true)

      data.add_field "Ensembl Gene ID" do |position, values|
        chromosome = values["Chr"].first
        next if chromosome_bed(organism)[chromosome].nil?
        chromosome_bed(organism)[chromosome][position]
      end

      data.namespace = "Hsa"
      data.identifiers = Organism[organism].identifiers.find

      Organism.attach_translations(organism, data, "Associated Gene Name")
      Organism.attach_translations(organism, data, "Entrez Gene ID")

      snp      = TSV.new(File.join(DATA_DIR,'SNP_GO','snp_go.txt'), :key => 'Substitution', :keep_empty => true, :namespace => "SNP&GO")
      polyphen = TSV.new(File.join(DATA_DIR,'Polyphen','polyphen'), :key => 'Substitution', :keep_empty => true, :namespace => "Polyphen")
      firedb   = TSV.new(File.join(DATA_DIR,'FireDB','firedb'), :key => 'Substitution', :keep_empty => true, :namespace => "FireDB")

      data.attach snp
      data.attach polyphen
      data.attach firedb

      expression_data = local_persist('LogRatiosMetvsNoMet.tsv', :TSV, :tsv_string, :persistence => true, :persistence_update => true) do
        expression_data = TSV.new(File.join(File.dirname(filename), 'LogRatiosMetvsNoMet.tsv'), :fields => [1,2,3,4], :type => :double)
        expression_data.attach TSV.new(File.join(File.dirname(filename), 'BarcodePancreas.tsv'), :type => :double)
        index = TSV.index(Organism.identifiers(organism), :target => "Ensembl Gene ID", :persistence => true)
        expression_data.add_field "Ensembl Gene ID" do |key, values|
          index.include?(key)?  index[key].uniq : []
        end

        expression_data = expression_data.reorder "Ensembl Gene ID", expression_data.fields
        expression_data
      end
      data.attach expression_data

      data.attach KEGG.gene_drug,nil, :persist_input => true
      data.attach KEGG.gene_pathway,nil, :persist_input => true
      data.attach KEGG.pathways, nil, :in_namespace => "KEGG",:persist_input => true
      data.attach Matador.protein_drug,nil, :persist_input => true
      data.attach PharmaGKB.gene_drug,nil, :persist_input => true
      data.attach PharmaGKB.gene_disease,nil, :persist_input => true
      data.attach PharmaGKB.gene_pathway,nil, :persist_input => true
      data.attach NCI.gene_drug,nil, :persist_input => true
      data.attach NCI.gene_cancer,nil, :persist_input => true
      data.attach Cancer.anais_annotations,nil, :persist_input => true

      data
    end

    #data.enrichment_for(KEGG.gene_pathway,  "KEGG Pathway ID", :cutoff => 0.05).each do |pathway, pvalue|
    #  puts "----------------------------------------"
    #  puts "Pathway: #{ pathway }. Pvalue #{pvalue}."
    #  puts "Desc: #{KEGG.pathways.tsv(:type => :list)[pathway]["Description"]}"
    #  puts
    #  puts data.select("KEGG:KEGG Pathway ID" => pathway).slice("Associated Gene Name").values.flatten * ", "
    #end


    data
  end


  def self.Raquel(filename, organism = "Hsa/may2009")
    data = local_persist(filename, :Misc, :tsv_string, :persistence_update => true) do |file, options, filename|
      data = TSV.new(file, :key => 'Ensembl Gene ID', :keep_empty => true)

      data.namespace = "Hsa"
      data.identifiers = Organism.identifiers(organism)

      Organism.attach_translations(organism, data, "Associated Gene Name")
      Organism.attach_translations(organism, data, "Entrez Gene ID")

      type_fields = data.fields.select{|f| f =~ /_type/}.collect{|f| data.identify_field f}
      data.add_field "Lost in Patients" do |key, values|
        [values.values_at(*type_fields).flatten.select{|e| e == "Gain"}.length.to_s]
      end

      data.add_field "Gained in Patients" do |key, values|
        [values.values_at(*type_fields).flatten.select{|e| e == "Loss"}.length.to_s]
      end

      loss_fields = data.fields.select{|f| f =~ /_top5_loss/}
      loss_field_positions = loss_fields.collect{|f| data.identify_field f}
      data.add_field "T5 Lost" do |key, values|
        loss_fields.zip(values.values_at(*loss_field_positions).flatten).select{|f,v| v == "1"}.collect{|f,v| f.sub(/_top5_loss/,'')}
      end

      gain_fields = data.fields.select{|f| f =~ /_top5_gain/}  
      gain_field_positions = gain_fields.collect{|f| data.identify_field f}
      data.add_field "T5 Gained" do |key, values|
        gain_fields.zip(values.values_at(*gain_field_positions).flatten).select{|f,v| v == "1"}.collect{|f,v| f.sub(/_top5_gain/,'')}
      end


      data.attach KEGG.gene_drug
      data.attach KEGG.gene_pathway
      data.attach KEGG.pathways, nil, :in_namespace => "KEGG"
      data.attach Matador.protein_drug
      data.attach PharmaGKB.gene_drug
      data.attach PharmaGKB.gene_disease
      data.attach PharmaGKB.gene_pathway
      data.attach NCI.gene_drug
      data.attach NCI.gene_cancer
      data.attach Cancer.anais_annotations


      data
    end
    data
  end  

  def self.Raquel_Patient(filename, organism = "Hsa/may2009")
    field_types = %w(type probability expression top5_loss top5_gain)
    data = TSV.new(filename, :list)

    Organism.attach_translations organism, data, "Associated Gene Name", nil, :type => :list

    patient_fields = {}
    data.fields.each do |field|
      if field =~ /(.*?)_(#{field_types * "|"})/
        patient      = $1
        field_type   = $2
        patient_fields[patient] ||= {}
        patient_fields[patient][field_type] = field
      end
    end

    patients = patient_fields.keys.sort

    patient_table = []
    ensembl = []
    name = []
    data.each do |gene, info|
      ensembl << gene
      name    << info["Associated Gene Name"].first
      row = []
      patients.each do |patient|
        fields = patient_fields[patient].values_at(*field_types)
        patient_data = info.values_at(*fields) * "|"
        row << patient_data
      end
      patient_table << row
    end

    patient_table = patient_table.transpose

    patient_tsv = TSV.new({})

    patients.each_with_index do |patient, i|
      gene_info = []
      patient_table[i].each_with_index{|r,j| 
        gene_info << ensembl[j] + "|" + (name[j] || "") + "|" + r
      }
      gene_info = gene_info.collect{|r| r.split("|")}.transpose
      patient_tsv[patient] = gene_info
    end

    patient_tsv.key_field = "Patient"
    patient_tsv.fields = ["Ensembl Gene ID", "Associated Gene Name"].concat(field_types)


    patient_tsv
  end

  def self.demo(filename)
    new_file = CMD.cmd('sort -R|head -n 100', filename).read
    TmpFile.with_file(new_file) do |f|
      self.NGS(f)
    end
  end 

end

if __FILE__ == $0
  require 'pp'
  #p PersonalizedMedicine.NGS '/home/mvazquezg/git/NGS/data/IRS/table.tsv'
  #require 'rbbt/util/misc'
  t = PersonalizedMedicine.positions File.join(File.dirname(__FILE__), '../www/data/Pancreas.tsv')
  puts t.to_s
  #t = PersonalizedMedicine.NGS File.join(File.dirname(__FILE__), '../www/data/Metastasis.tsv')
  #puts t.slice_namespace("PharmaGKB").to_s
  #Open.write('/tmp/test.tsv', t.to_s)
end

