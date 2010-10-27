require 'rbbt/sources/organism'
require 'rbbt/util/open'
require 'cachehelper'
require 'genecodis'
require 'tsv'


module PhGx

  ROOT_DIR = File.join(File.dirname(__FILE__), '..')
  DATA_DIR = File.join(ROOT_DIR,'data')

  def self.translate(orig, org = "Hsa", format = "Entrez Gene ID")
    index = TSV.index(File.join(Organism.datadir(org), 'identifiers'), :field => format, :persistence => true, :data_persistence => true)
    index.values_at(*orig).collect{|name| name.nil? || name.empty? ? nil : name }
  end

  module Matador
    DIR = File.join(DATA_DIR, 'Matador')
    PROTEIN_DRUG_FILE = File.join(DIR, 'protein_drug')

    def self.drugs4genes(orig)
      genes = PhGx.translate(orig, 'Hsa', 'Ensembl Protein ID')
      data = TSV.new(PROTEIN_DRUG_FILE, :keep_empty => true, :persistence => true)

      PhGx.assign(orig, genes, data)
    end
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
      TSV.new(CANCER_FILE, :native => 1, :extra => [0,3], :persistence => true)
    end
  end

  module GeneInfo
    GENE_CANCER_FILE = File.join(DATA_DIR, 'CancerGenes', 'anais-annotations.txt')
    def self.genecodis(orig)
      genes = PhGx.translate(orig, 'Hsa', 'Entrez Gene ID')

      Genecodis.analyze('Hsa',nil,genes.flatten)
    end

    def self.go4genes(orig)
      genes = PhGx.translate(orig, 'Hsa', 'Entrez Gene ID')
      data = Organism.goterms('Hsa')

      PhGx.assign(orig, genes, data)
    end

    def self.cancer4genes_anais(orig)
      genes = PhGx.translate(orig, 'Hsa', 'Ensembl Gene ID')
      data = TSV.new(GENE_CANCER_FILE, :keep_empty => true, :persistence => true, :flatten => true)
      PhGx.assign(orig, genes, data)
    end
  end

  module KEGG
    DIR = File.join(DATA_DIR, 'KEGG')
    GENES_FILE = File.join(DIR, 'genes')
    PATHWAY_GENE_FILE = File.join(DIR, 'gene_pathway')

    def self.pathways4genes(orig)
      genes = PhGx.translate(orig, 'Hsa', 'Ensembl Gene ID')
      translations = TSV.new(GENES_FILE, :keep_empty => true, :single => true, :persistence => true)
      kegg = translations.values_at(*genes)

      data = TSV.new(PATHWAY_GENE_FILE, :keep_empty => true, :single => true, :persistence => true)
      PhGx.assign(orig, kegg, data)
    end
  end

  module SNP_GO
    DIR = File.join(DATA_DIR, 'SNP_GO')
    SNP_FILE = File.join(DIR, 'snp_go.txt')
    def self.snp_pred4genes(orig)
      genes = PhGx.translate(orig, 'Hsa', 'UniProt/SwissProt Accession')
      data = TSV.new(SNP_FILE, :keep_empty => true, :persistence => true)

      PhGx.assign(orig, genes, data)
    end
  end

  module Polyphen
    DIR = File.join(DATA_DIR, 'Polyphen')
    SNP_FILE = File.join(DIR, 'polyphen')
    def self.snp_pred4genes(orig)
      genes = PhGx.translate(orig, 'Hsa', 'UniProt/SwissProt Accession')
      data = TSV.new(SNP_FILE, :keep_empty => true, :native => 2, :persistence => true)

      PhGx.assign(orig, genes, data)
    end
  end

  module FireDB
    DIR = File.join(DATA_DIR, 'FireDB')
    SNP_FILE = File.join(DIR, 'firedb')
    def self.snp_pred4genes(orig)
      genes = PhGx.translate(orig, 'Hsa', 'UniProt/SwissProt Accession')
      data = TSV.new(SNP_FILE, :keep_empty => true, :persistence => true)

      PhGx.assign(orig, genes, data)
    end
  end

  module Matador
    DIR = File.join(DATA_DIR, 'Matador')
    PROTEIN_DRUG_FILE = File.join(DIR, 'protein_drug')

    def self.drugs4genes(orig)
      genes = PhGx.translate(orig, 'Hsa', 'Ensembl Protein ID')
      data = TSV.new(PROTEIN_DRUG_FILE, :keep_empty => true, :persistence => true)

      PhGx.assign(orig, genes, data)
    end
  end

  module PharmaGKB
    DIR = File.join(DATA_DIR, 'PharmaGKB')
    PROTEIN_DRUG_FILE = File.join(DIR, 'gene_drug')
    PATHWAY_GENE_FILE = File.join(DIR, 'gene_pathway')
    VARIANTS_FILE = File.join(DIR, 'variants')

    def self.drugs4genes(orig)
      genes = PhGx.translate(orig, 'Hsa', 'Associated Gene Name')
      data = TSV.new(PROTEIN_DRUG_FILE, :keep_empty => true, :persistence => true)

      PhGx.assign(orig, genes, data)
    end

    def self.pathways4genes(orig)
      genes = PhGx.translate(orig, 'Hsa', 'Associated Gene Name')
      data = TSV.new(PATHWAY_GENE_FILE, :keep_empty => true, :native => 2)

      PhGx.assign(orig, genes, data)
    end

    def self.variants4genes(orig)
      genes = PhGx.translate(orig, 'Hsa', 'Associated Gene Name')
      data = TSV.new(VARIANTS_FILE, :keep_empty => true, :native => 1, :extra => [0,2,3,4,5], :persistence => true)

      PhGx.assign(orig, genes, data)
    end

  end

  module STITCH
    DIR = File.join(DATA_DIR, 'STITCH')
    GENE_CHEMICAL_FILE = File.join(DIR, 'gene_chemical')

    def self.drugs4genes(orig)
      genes = PhGx.translate(orig, 'Hsa', 'Ensembl Protein ID')
      data = TSV.new(GENE_CHEMICAL_FILE, :keep_empty => true, :persistence => true)

      PhGx.assign(orig, genes, data)
    end
  end

  module NCI
    DIR = File.join(DATA_DIR, 'NCI')
    GENE_CHEMICAL_FILE = File.join(DIR, 'gene_drug')

    def self.drugs4genes(orig)
      genes = PhGx.translate(orig, 'Hsa', 'UniProt/SwissProt Accession')
      genes.collect!{|name| [name].flatten.compact.collect{|n| n.sub(/_HUMAN/,'') } }
      data = TSV.new(GENE_CHEMICAL_FILE, :keep_empty => true, :native => 2, :extra => [3,4], :persistence => true)

      PhGx.assign(orig, genes, data)
    end

  end

  def self.analyze(genes)
    results = {}
    Matador.drugs4genes(genes).each do |gene, values|
      results[gene] ||= {}
      results[gene][:Matador] = values
    end

    PharmaGKB.drugs4genes(genes).each do |gene, values|
      results[gene] ||= {}
      results[gene][:PharmaGKB] = values
    end

    STITCH.drugs4genes(genes).each do |gene, values|
      results[gene] ||= {}
      results[gene][:STITCH] = values
    end

    NCI.drugs4genes(genes).each do |gene, values|
      results[gene] ||= {}
      results[gene][:NCI] = values
    end

    GeneInfo.go4genes(genes).each do |gene, values|
      results[gene] ||= {}
      results[gene][:GO] = values
    end

    GeneInfo.cancer4genes_anais(genes).each do |gene, values|
      results[gene] ||= {}
      results[gene][:Anais_cancer] = values
    end

    SNP_GO.snp_pred4genes(genes).each do |gene, values|
      results[gene] ||= {}
      results[gene][:SNP_GO] = values
    end

    FireDB.snp_pred4genes(genes).each do |gene, values|
      results[gene] ||= {}
      results[gene][:FireDB] = values
    end

    Polyphen.snp_pred4genes(genes).each do |gene, values|
      results[gene] ||= {}
      results[gene][:Polyphen] = values
    end

    KEGG.pathways4genes(genes).each do |gene, values|
      results[gene] ||= {}
      results[gene][:KEGG] = values
    end

    results
  end

  def self.gene_scores(info)
    scores = {}
    info.each do |gene, info|
      scores[gene] = {
        :cancer    => (info[:Anais_cancer] || [[]]).first.length,
        :snp       => (info[:SNP_GO] || [[],[],[],[]])[1].select{|i| i == "Disease"}.length,
        :snp_score => (info[:SNP_GO] || [[],[],[],[]])[2].collect{|i| i.to_i }.max || 0,
        :drugs     => (info[:Matador]|| [[]]).first.length + (info[:PharmaGKB] || [[]]).first.length
      }
    end
    scores
  end
end

if __FILE__ == $0
  orig  = STDIN.read.split(/\n/).collect{|l| l.split(/\t/)}
  p PhGx::GeneInfo.cancer4genes_anais(orig)
end

