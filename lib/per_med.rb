require 'rbbt-util'
require 'rbbt/sources/organism'

module PersonalizedMedicine
  ROOT_DIR = File.join(File.dirname(__FILE__), '..')
  DATA_DIR = File.join(ROOT_DIR, 'data')
  Persistence.cachedir = File.join(ROOT_DIR, 'cache','tsv')

  def self.get_db_info(gene, path, options)
    format  = options.collect{|opt| opt =~ /^field\[(.*?)\]/; $1}.compact.first
    list    = options.select{|opt| opt == "list"}.any?

    tsv = TSV.new(path, (list ? :list : :double), :keep_empty => true, :persistence => true, :key => format)

    # Get format to use
    format ||= tsv.key_field # Defaults to first field

    # Get intermetiate ids
    intermediate = options.collect{|opt| opt =~ /^intermediate\[(.*?)\]/; $1}.compact.first

    if intermediate != nil
      path, from, to = intermediate.match(/(.*)<(.*)><(.*)>/).values_at(1,2,3)
      path = File.join(DATA_DIR,path.gsub(/:/,'/'))
      index = Organism::Hsa.identifiers.index :target => from, :persistence => true, :data_persistence => true
      int = index.values_at(*gene).compact.flatten.first
      translation = TSV.index(path, :target => to, :persistence => true, :data_persistence => true).values_at(*int).flatten.first
    else
      index = Organism::Hsa.identifiers.index :target => tsv.key_field, :persistence => true, :data_persistence => true
      translation = index.values_at(*gene).compact.flatten.first
    end

    return nil if translation.nil?

    data = tsv[translation]

    if options.include? "zip"
      TSV.zip_fields data
    else
      data
    end
  end

  def self.get_gene_info(gene)
    info = {}
 
   [ 
     'Matador#Matador:protein_drug#zip',
     'PharmaGKB#PharmaGKB:gene_drug#zip|intermediate[PharmaGKB:genes<Ensembl Gene ID><PhGKB Gene ID>]',
     'NCI#NCI:gene_drug#zip',
     'NCI_cancer#NCI:gene_cancer#zip',
     'KEGG_DRUG#KEGG:gene_drug#list|intermediate[KEGG:genes<Ensembl Gene ID><KEGG Gene ID>]',
#     'STITCH#STITCH:protein_chemical#zip',
    'KEGG#KEGG:gene_pathway#list|intermediate[KEGG:genes<Ensembl Gene ID><KEGG Gene ID>]',
     'Anais_cancer#CancerGenes:anais-annotations.txt#list',
   ].each do |db|
     key, path, options = db.match(/(.*?)#(.*?)#(.*)/).values_at(1,2,3)
     name = path.match(/^(.*?)[:#]/)[1]
     path = File.join(DATA_DIR,path.gsub(/:/,'/'))


     info[key.to_sym] = get_db_info(gene, path, options.split('|'))
   end
   info
  end

  GENE_FIELDS     = ['Protein ID', 'Gene ID', 'Gene Name']
  MUTATION_FIELDS = ['Chr', 'Position1','Ref Genome Allele','Variant Allele', 'Substitution', 'SNP Type', 'Ubio Score', 'Prediction', 'OMIM Disease']
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

  def self.NGS(filename)
    data = TSV.new(filename, :key => 'Position1', :keep_empty => true)


    gene_names        = data.slice(GENE_FIELDS)
    mutations          = data.slice(MUTATION_FIELDS)

    snp      = TSV.new(File.join(DATA_DIR,'SNP_GO','snp_go.txt'), :key => 'Mutation', :keep_empty => true)
    polyphen = TSV.new(File.join(DATA_DIR,'Polyphen','polyphen'), :key => 'id', :keep_empty => true)
    firedb   = TSV.new(File.join(DATA_DIR,'FireDB','firedb'), :key => 'Mutation', :keep_empty => true)

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

  def self.Raquel(filename)
    field_types = %w(type probability expression top5_loss top5_gain)
    data = TSV.new(filename, :list)

    patient_fields = {}
    data.fields.each do |field|
      if field =~ /(.*?)_(#{field_types * "|"})/
        patient      = $1
        field_type   = $2
        patient_fields[patient] ||= {}
        patient_fields[patient][field_type] = field
      end
    end
    
    new_data = TSV.new({})
    data.each do |gene, info|
      new_info = []
      new_info.concat info.values_at(*%w(Name    Chromosome  Start   End))
      new_info << get_gene_info(gene)

      patient_info = {}
      patient_fields.each do |patient, p_fields|
        patient_info[patient] = {}

        field_types.each do |type|
          patient_info[patient][type] = info[p_fields[type]]
        end
      end

      new_info << patient_info
      new_data[gene] = new_info
    end
    new_data.fields =['Name', 'Chromosome', 'Start', 'End', 'Gene Info', 'Patients']

    new_data
  end

  def self.Raquel_Patient(filename)
    field_types = %w(type probability expression top5_loss top5_gain)
    data = TSV.new(filename, :list)

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
    genes = []
    data.each do |gene, info|
      genes << info["Name"]
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
        gene_info << genes[j] + "|" + r
      }
      gene_info = gene_info.collect{|r| r.split("|")}.transpose
      patient_tsv[patient] = gene_info
    end
    
    patient_tsv.key_field = "Patient"
    patient_tsv.fields = ["Gene"].concat(field_types)
    patient_tsv
  end

end

if __FILE__ == $0
  #p PersonalizedMedicine.NGS '/home/mvazquezg/git/NGS/data/IRS/table.tsv'
  #require 'rbbt/util/misc'
  profile do
  t = PersonalizedMedicine.NGS File.join(File.dirname(__FILE__), '../www/data/Metastasis2.tsv')
  p t.fields
  end
end

