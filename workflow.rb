require 'rbbt-util'
require 'rbbt/util/workflow'
require 'rbbt/sources/organism'
require 'rbbt/sources/organism/sequence'
require 'rbbt/sources/cancer'
require 'rbbt/sources/organism'
require 'rbbt/sources/kegg'
require 'rbbt/sources/pharmagkb'
require 'rbbt/sources/matador'
require 'rbbt/sources/string'
require 'rbbt/sources/nci'

module PerMed
  extend WorkFlow

  def get_ids(file, sep = "\t")
    CMD.cmd("cut -f 1 -d'#{sep}' '#{file}'").read.split("\n")
  end

  task_option :organism, "Organism code", :string, "Hsa"
  task :database => :tsv do
    organism = options[:organism]

    step(:ensembl, "Get all ensembl gene IDS")
    all_ensembl_ids = get_ids(Organism.identifiers(organism).produce)
    set_info :total_genes, all_ensembl_ids.length

    step(:prepare, "Prepare initial data store")
    data = TSV.new all_ensembl_ids
    data.key_field = "Ensembl Gene ID"
    data.fields = []
    data.namespace = organism.sub(/\/.*/,'')
    data.identifiers = Organism.identifiers(organism)
    data.type = :double
    data.filename = path

    step(:atachment_start, "Attach data")

    Organism.attach_translations(organism, data, "Associated Gene Name")

    step(:cancer, "Attach Cancer Data")
    data.attach Cancer.anais_annotations, nil, :persist_input => false
    step(:pharmagkb, "Attach PharmaGKB Data")
    data.attach PharmaGKB.gene_drug, nil, :persist_input => true
    data.attach PharmaGKB.gene_disease, nil, :persist_input => true
    data.attach PharmaGKB.gene_pathway, nil, :persist_input => true
    step(:matador, "Attach Matador Data")
    data.attach Matador.protein_drug, nil, :persist_input => true
    step(:nci, "Attach NCI Data")
    data.attach NCI.gene_drug, nil, :persist_input => true
    data.attach NCI.gene_cancer, nil, :persist_input => true

    step(:kegg, "Attach KEGG Data")
    data.attach KEGG.gene_drug, nil, :persist_input => true
    data.attach KEGG.gene_pathway, nil, :persist_input => true
    data.attach KEGG.pathways, nil, :in_namespace => "KEGG", :persist_input => true

    step(:atachment_end, "Attachment done. Saving")

    data.namespace = nil

    data
  end

  task_option :genes, "Genes to annotate", :array
  task_dependencies Proc.new{|job_name, options| PerMed.job(:database, "Default", options)}
  task :annotate_genes => :tsv do |genes|
    database = task.workflow.local_persist(previous_jobs["database"].path, :TSV, :tsv, :persistence_update => false) do |filename,*other|
      TSV.new filename
    end

    step(:translate, "Translate genes into Ensembl Gene ID")
    set_info :original, genes
    organism = previous_jobs["database"].info[:options][:organism]
    translations = Organism.normalize(organism, genes, "Ensembl Gene ID")
    set_info :translations, translations
    translation_index = Hash[*translations.zip(genes).flatten]
    set_info :translation_index, translation_index

    step(:data, "Set initial data")
    data = TSV.new(translations.compact)
    data.key_field = "Ensembl Gene ID"
    data.fields = []
    data.namespace = organism.sub(/\/.*/,'')
    data.identifiers = Organism.identifiers(organism).find
    data.filename = path
    data.add_field "Original Name" do |key,values|
      translation_index[key]
    end

    data.attach database

    data
  end

  task_option :mutations, "Mutation Positions", :tsv
  task_option :organism, "Organism", :string, "Hsa"
  task_dependencies [
    Proc.new{|jobname,run_options| Organism.job(:genomic_mutations_to_genes, jobname, run_options[:mutations], :organism => run_options[:organism])},
    Proc.new{|jobname,run_options| Organism.job(:genomic_mutations_to_protein_mutations, jobname, run_options[:mutations], :organism => run_options[:organism])},
    Proc.new{|job_name, run_options| PerMed.job(:database, "Default", :organism => run_options[:organism])},
  ]
  
  task :annotate_mutations => :tsv do |org,mutations|
    genes_at_positions = TSV.new(Open.open(previous_jobs[0].path), :type => :double)
    protein_mutations = TSV.new(Open.open(previous_jobs[1].path), :type => :double)
    database = task.workflow.local_persist(previous_jobs[2].path, :TSV, :tsv, :persistence_update => false) do |filename,*other|
      TSV.new filename
    end

    genes_at_positions.attach database
    genes_at_positions.attach protein_mutations

    genes_at_positions
  end
end

if __FILE__ == $0
  require 'test/unit'
  class TestClass < Test::Unit::TestCase
    def _test_database
      job = PerMed.run(:database, "Test", {:organism => 'Hsa'})
      job.join
      puts job.load if not job.error?
      job.clean
    end

    def test_genes
      test = %w(CDK5 NR5ANR5A2)
      job = PerMed.run(:annotate_genes, "Test", test, {:organism => 'Hsa'})
      job.clean if job.error?
      assert job.load.include? "CDK5" 
    end
    def _test_mutations
      picmi_test = <<-EOF
5 95787335 M
      EOF

      mutations = picmi_test.split(/\n/).collect{|l| l.chomp.sub(/\s+/,':').split(/\s+/) * "\t"} * "\n"
      job = PerMed.run(:annotate_mutations, "Test13", mutations, :organism => "Hsa/may2009")
      puts job.load
      job.clean if job.error?
      job.clean
    end
  end
end
