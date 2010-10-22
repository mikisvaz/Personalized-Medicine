#!/usr/bin/ruby
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rbbt/sources/organism'
require 'rbbt/util/open'
require 'phgx'
require 'simpleopt'
require 'cachehelper'

include CacheHelper

options = SOPT.parse('-f--format*:-i--in*')
options[:format] ||= "Entrez Gene ID"
options[:in] ||= "-"

if options[:in] == "-"
  genes = STDIN.read.split(/\n/).collect{|l| l.split(/\t/)}
else
  genes = Open.read(options[:in]).split(/\n/).collect{|l| l.split(/\t/)}
end

#genes = genes.collect{|list| list.last}

#p  PhGx.analyze(genes)
#p PhGx::PharmaGKB.variants4genes(genes)
p PhGx::NCI.drugs4genes(genes)

