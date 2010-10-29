require 'rbbt/sources/organism'
require 'rbbt/util/open'
require 'cachehelper'
require 'tsv'


module PhGx

  ROOT_DIR = File.join(File.dirname(__FILE__), '..')
  DATA_DIR = File.join(ROOT_DIR, 'data')
  TSV.cachedir = File.join(ROOT_DIR, 'cache','tsv')

  def self.translate(orig, org = "Hsa", format = "Entrez Gene ID")
    index = TSV.index(File.join(Organism.datadir(org), 'identifiers'), :field => format, :persistence => true, :data_persistence => true)
    index.values_at(*orig).collect{|name| name.nil? || name.empty? ? nil : name }
  end

  def self.assign(orig, genes, data)
    results = {}

    genes.zip(orig).each do |p|
      gene, original = p
      next if gene.nil? || data[gene].nil?
      results[original] = data[gene]
    end

    results
  end

  module CancerAnnotations
    CANCER_FILE = File.join(DATA_DIR, 'CancerGenes', 'anais-interactions.txt')
    def self.load_data
      TSV.new(CANCER_FILE, :native => 1, :persistence => true)
    end
  end
  def self.get_db_info(gene, path, options)
    format = options.collect{|opt| opt =~ /^field\[(.*?)\]/; $1}.compact.first
    flatten = options.select{|opt| opt == "flatten"}.any?

    tsv = TSV.new(path, :keep_empty => true, :persistence => true, :native => format, :flatten => flatten)

    # Get format to use
    format ||= tsv.key_field # Defaults to first field

    # Get intermetiate ids
    intermediate = options.collect{|opt| opt =~ /^intermediate\[(.*?)\]/; $1}.compact.first


    if intermediate != nil
      path, from, to = intermediate.match(/(.*)<(.*)><(.*)>/).values_at(1,2,3)
      path = File.join(DATA_DIR,path.gsub(/:/,'/'))
      int = TSV.index(File.join(Organism.datadir('Hsa'), 'identifiers'), :field => from, :persistence => true, :data_persistence => true)[gene]
      translation = TSV.index(path, :field => to, :extra => from, :persistence => true, :data_persistence => true)[int]
    else
      translation = TSV.index(File.join(Organism.datadir('Hsa'), 'identifiers'), :field => format, :persistence => true, :data_persistence => true)[gene]
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
     'PharmaGKB#PharmaGKB:gene_drug#zip',
     'NCI#NCI:gene_drug#zip|field[UniProt/SwissProt Accession]',
     'KEGG_DRUG#KEGG:gene_drug#flatten|intermediate[KEGG:genes<Ensembl Gene ID><KEGG Gene ID>]',
     'STITCH#STITCH:gene_chemical#zip',
     'KEGG#KEGG:gene_pathway#flatten|intermediate[KEGG:genes<Ensembl Gene ID><KEGG Gene ID>]',
     'Anais_cancer#CancerGenes:anais-annotations.txt#flatten',
   ].each do |db|
     key, path, options = db.match(/(.*?)#(.*?)#(.*)/).values_at(1,2,3)
     name = path.match(/^(.*?)[:#]/)[1]
       path = File.join(DATA_DIR,path.gsub(/:/,'/'))


     info[key.to_sym] = get_db_info(gene, path, options.split('|'))
   end
   info
  end

  GENE_FIELDS     = ['Protein ID', 'Gene ID', 'Gene Name']
  MUTATION_FIELDS = ['Chr', 'Position','Ref Genome Allele','Variant Allele', 'Substitution', 'SNP Type', 'Ubio Score']
  def self.analyze_NGS(filename)
    gene_fields = ['Protein ID', 'Gene ID', 'Gene Name']
    mutation_fields = ['Chr', 'Position','Ref Genome Allele','Variant Allele', 'Substitution', 'SNP Type', 'Ubio Score']

    data = TSV.new(filename, :native => 'Position1', :keep_empty => true)

    gene_names        = data.slice(*GENE_FIELDS)
    mutations          = data.slice(*MUTATION_FIELDS)


    snp      = TSV.new(File.join(DATA_DIR,'SNP_GO','snp_go.txt'), :native => 'Mutation', :keep_empty => true)
    polyphen = TSV.new(File.join(DATA_DIR,'Polyphen','polyphen'), :native => 'id', :keep_empty => true)
    firedb   = TSV.new(File.join(DATA_DIR,'FireDB','firedb'), :native => 'Mutation', :keep_empty => true)


    gene_data = TSV.new({})
    unknown_genes = 0
    data.keys.each do |position|
      gene_name = gene_names[position].flatten
      if gene_name.reject{|n| n.empty?}.empty?
        gene_name = ["UNKNOWN-#{unknown_genes}"] * 3
        unknown_genes += 1
      end
      gene_data[gene_name] ||= get_gene_info gene_name

      mutation_info = mutations[position].flatten
      code = mutation_info[4]

      snp_info = snp[code] || [[""] * snp.fields.length]
      mutation_info << snp_info.flatten

      poly_info = polyphen[code] || [[""] * polyphen.fields.length]
      mutation_info << poly_info.flatten
 
      firedb_info = firedb[code] || [[""] * firedb.fields.length]
      mutation_info << firedb_info.flatten

     
      gene_data[gene_name][:Mutations] ||= []
      gene_data[gene_name][:Mutations] << mutation_info
    end

    gene_data
  end

  def self.analyze_Raquel(filename)
    genes  = File.open(filename).read.split(/\n/).collect{|l| l.split(/\t/)}
    gene_data = TSV.new({})
    genes.each do |gene|
      gene_data[gene] = get_gene_info gene
    end
    gene_data
  end

end

if __FILE__ == $0
  p PhGx.analyze_NGS '/home/mvazquezg/git/NGS/data/IRS/table.tsv'
end

