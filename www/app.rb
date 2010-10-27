$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'phgx'
require 'rbbt/sources/go'
require 'rbbt/sources/entrez'


def join_hash_fields(list)
  return [] if list.nil? || list.empty?
  list[0].zip(*list[1..-1])
end

helpers do

  def matador_summary(matador_drugs)
    if matador_drugs != nil  
      join_hash_fields(matador_drugs).collect do |d|
        name, score, annot, mscore, mannot = d
        css_class = (mannot == 'DIRECT')?'red':'normal';
        "<span class='#{css_class}'>#{name}</span> [M],"
      end
    else
      []  
    end  
  end
  
  def pharmagkb_summary(pgkb_drugs)
    if pgkb_drugs != nil
      pgkb_drugs.collect do |d|
        "<a target='_blank' href='http://www.pharmgkb.org/search/search.action?typeFilter=Drug&exactMatch=true&query=#{d}'>#{d}</a> [PGKB], "
      end
    else
      []  
    end
  end
  
  def kegg_summary(pathways)
    if pathways != nil
      pathways.collect do |k|
        name = '<span '
  
        join_hash_fields(@anais[k]).each do |p|
          cancer, score = p
          css_class = (score != nil and score.to_f <= 0.1)?'red':'green';
          name += "class='#{ css_class }'>#{k} [#{ cancer } cancer]</span>"
        end
        "<a target='_blank' href='http://www.genome.jp/kegg-bin/show_pathway?#{k}'>#{ name }</a>"
      end
    else
      []
    end  
  end
  
  def cancer_genes_summary(cancers)
    if cancers != nil
      cancers.collect do |c|
        "<span>#{c}</span>, "
      end
    else
      []  
    end
  end


  def go_link(id)
    puts id
    name = GO.id2name(id)
    puts name
    
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

post '/' do
  genes = params[:genes].split(/\n/).collect{|l| l.chomp.split(/\s/,-1)}


  @info = marshal_cache('info', :genes => genes) do
    PhGx.analyze(genes)
  end

  @anais = PhGx::CancerAnnotations.load_data

  @scores = marshal_cache('scores', :genes => genes) do
    PhGx.gene_scores(@info)
  end

  @ordered_genes = @info.keys.sort do |gene1,gene2|
    diff = 0
    %w(snp cancer drugs snp_score ).each do |type|
      next if diff != 0
      type = type.to_sym
      if @scores[gene1][type] != @scores[gene2][type]
        diff = (@scores[gene2][type] || 0) <=> (@scores[gene1][type] || 0)
      end
    end
    diff
  end

  @entrez_codes = marshal_cache('entrez', :genes => genes) do
    trans = {}
    entrez = PhGx.translate(genes, 'Hsa', "Entrez Gene ID")
    genes.zip(entrez).each do |p|
      gene, entrez = p
      trans[gene] = entrez.first
    end

    trans
  end

  @entrez_descriptions = marshal_cache('entrez_desc', :genes => genes) do
    descriptions = {}
    Entrez.get_gene(@entrez_codes.values_at(*genes.compact)).each do |name, gene|
      descriptions[name] = gene.description
    end
    #genes.each do |gene|
    #  next if @entrez_codes[gene].nil? || @entrez_codes[gene] == "MISSING"
    #  descriptions[gene] = Entrez.get_gene(@entrez_codes[gene]).description
    #end

    descriptions
  end

  haml :results
end
