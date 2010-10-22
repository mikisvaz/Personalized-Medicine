require 'rbbt/sources/organism'
require 'rbbt/util/open'
require 'cachehelper'
require 'genecodis'


module PhGx

  ROOT_DIR = File.join(File.dirname(__FILE__), '..')
  DATA_DIR = File.join(ROOT_DIR,'data')

  def self.translate(orig, org = "Hsa", format = "Entrez Gene ID")
    CacheHelper.marshal_cache('PhGx_translate', :orig => orig, :org => org, :format => format) do

      index = Organism.id_index(org, :native => format)

      names = []
      orig.each do |name_list|
        name_list = [name_list] unless Array === name_list
        if name_list.empty?
          names << "MISSING"
          next
        end

        if Array === name_list
          trans = "MISSING"
          name_list.each do |name|
            if index[name]
              trans = index[name]
              next
            end
          end
          names << trans
        else
          names << index[name_list] || "MISSING"
        end
      end

      names
    end
  end

  def self.assign(orig, genes, data)
    results = {}

    genes.zip(orig).each do |p|
      gene, original = p
      next if gene == "MISSING" || data[gene].nil?
      results[original] = data[gene]
    end

    results
  end

  module CancerAnnotations
    CANCER_FILE = File.join(DATA_DIR, 'CancerGenes', 'anais-interactions.txt')
    def self.load
      Open.to_hash(CANCER_FILE, :native => 1, :extra => [0,3])
    end
  end

  module GeneInfo
    GENE_CANCER_FILE = File.join(DATA_DIR, 'CancerGenes', 'anais-annotations.txt')
    def self.genecodis(orig)
       genes = PhGx.translate(orig, 'Hsa', 'Entrez Gene ID')

       Genecodis.analyze('Hsa',nil,genes)
    end

    def self.go4genes(orig)
      genes = PhGx.translate(orig, 'Hsa', 'Entrez Gene ID')
      data = Organism.goterms('Hsa')

      PhGx.assign(orig, genes, data)
    end

    def self.cancer4genes_anais(orig)
      genes = PhGx.translate(orig, 'Hsa', 'Ensembl Gene ID')
      data = Open.to_hash(GENE_CANCER_FILE, :keep_empty => true)
      PhGx.assign(orig, genes, data)
    end
  end

  module KEGG
    DIR = File.join(DATA_DIR, 'KEGG')
    GENES_FILE = File.join(DIR, 'genes')
    PATHWAY_GENE_FILE = File.join(DIR, 'gene_pathway')

    def self.pathways4genes(orig)
      genes = PhGx.translate(orig, 'Hsa', 'Ensembl Gene ID')
      translations = Open.to_hash(GENES_FILE, :keep_empty => true, :single => true)
      kegg = translations.values_at(*genes).collect{|name| name || "MISSING"}

      data = Open.to_hash(PATHWAY_GENE_FILE, :keep_empty => true, :single => true)
      PhGx.assign(orig, kegg, data)
    end
  end

  module SNP_GO
    DIR = File.join(DATA_DIR, 'SNP_GO')
    SNP_FILE = File.join(DIR, 'snp_go.txt')
    def self.snp_pred4genes(orig)
      genes = PhGx.translate(orig, 'Hsa', 'UniProt/SwissProt Accession')
      data = Open.to_hash(SNP_FILE, :keep_empty => true)

      PhGx.assign(orig, genes, data)
    end
  end

  module Matador
    DIR = File.join(DATA_DIR, 'Matador')
    PROTEIN_DRUG_FILE = File.join(DIR, 'protein_drug')

    def self.drugs4genes(orig)
      genes = PhGx.translate(orig, 'Hsa', 'Ensembl Protein ID')
      data = Open.to_hash(PROTEIN_DRUG_FILE, :keep_empty => true)

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
      data = Open.to_hash(PROTEIN_DRUG_FILE, :keep_empty => true)

      PhGx.assign(orig, genes, data)
    end

    def self.pathways4genes(orig)
      genes = PhGx.translate(orig, 'Hsa', 'Associated Gene Name')
      data = Open.to_hash(PATHWAY_GENE_FILE, :keep_empty => true, :native => 2)

      PhGx.assign(orig, genes, data)
    end

    def self.variants4genes(orig)
      genes = PhGx.translate(orig, 'Hsa', 'Associated Gene Name')
      data = Open.to_hash(VARIANTS_FILE, :keep_empty => true, :native => 1, :extra => [0,2,3,4,5])

      PhGx.assign(orig, genes, data)
    end

  end

  module STITCH
    DIR = File.join(DATA_DIR, 'STITCH')
    GENE_CHEMICAL_FILE = File.join(DIR, 'gene_chemical')

    def self.drugs4genes(orig)
      genes = PhGx.translate(orig, 'Hsa', 'Ensembl Protein ID')
      data = Open.to_hash(GENE_CHEMICAL_FILE, :keep_empty => true)

      PhGx.assign(orig, genes, data)
    end
  end

  module NCI
    DIR = File.join(DATA_DIR, 'NCI')
    GENE_CHEMICAL_FILE = File.join(DIR, 'gene_drug')

    def self.drugs4genes(orig)
      genes = PhGx.translate(orig, 'Hsa', 'UniProt/SwissProt Accession')
      genes.collect!{|name| name.sub(/_HUMAN/,'')}
      data = Open.to_hash(GENE_CHEMICAL_FILE, :keep_empty => true, :native => 2, :extra => [3,4])

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
      results[gene][:SNP_pred] = values
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
        :snp       => (info[:SNP_pred] || [[],[],[],[]])[1].select{|i| i == "Disease"}.length,
        :snp_score => (info[:SNP_pred] || [[],[],[],[]])[2].collect{|i| i.to_i }.max || 0,
        :drugs     => (info[:Matador]|| [[]]).first.length + (info[:PharmaGKB] || [[]]).first.length
      }
    end
    scores
  end
end


