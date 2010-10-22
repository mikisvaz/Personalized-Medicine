$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'phgx'
require 'rbbt/sources/go'
require 'rbbt/sources/entrez'

def join_hash_fields(list)
  return [] if list.nil? || list.empty?
  result = list[0]
  list[1..-1].each{|l| result = result.zip(l)}
  result.collect{|l| l.flatten}
end

helpers do
  def go_link(id)
    name = GO.id2name(id)
    
    join_hash_fields(@anais[id]).each do |p|
      cancer, score = p
      name += "[#{ cancer }:#{ score }]"
    end
    
    "<a href='http://amigo.geneontology.org/cgi-bin/amigo/go.cgi?view=details&query=#{id}'>#{ name }</a>"
  end

  def drug_link(id)
    name = id
    
    "<a href='http://vsearch.nlm.nih.gov/vivisimo/cgi-bin/query-meta?v%3Aproject=medlineplus&query=#{id}'>#{ name }</a>"
  end


  def kegg_link(id)
    name = id

    join_hash_fields(@anais[id]).each do |p|
      cancer, score = p
      name += "[#{ cancer }:#{ score }]"
    end

    "<a href='http://www.genome.jp/kegg-bin/show_pathway?#{id}'>#{ name }</a>"
  end
end

get '/' do
  haml :main
end

post '/' do
  genes = params[:genes].split(/\n/).collect{|l| l.chomp.split(/\s/,-1)}

  @anais = marshal_cache('annotations') do
    PhGx::CancerAnnotations.load
  end

  @info = marshal_cache('info', :genes => genes) do
    PhGx.analyze(genes)
  end

  @scores = marshal_cache('scores', :genes => genes) do
    PhGx.gene_scores(@info)
  end

  @ordered_genes = @info.keys.sort do |gene1,gene2|
    diff = 0
    %w( snp cancer drugs snp_score ).each do |type|
      next if diff != 0
      type = type.to_sym
      if @scores[gene1][type] != @scores[gene2][type]
        diff = (@scores[gene2][type] || 0) <=> (@scores[gene1][type] || 0)
      end
    end
    diff
  end

  @entrez_codes = marshal_cache('entrez', :genes => genes) do
    PhGx.translate(genes, 'Hsa', "Entrez Gene ID")
  end

  @entrez_descriptions = marshal_cache('entrez_desc', :genes => genes) do
    descriptions = {}
    genes.each do |gene|
      descriptions[gene] = Entrez.get_gene(@entrez_codes[gene]).description
    end
    descriptions
  end

  haml :results
end
