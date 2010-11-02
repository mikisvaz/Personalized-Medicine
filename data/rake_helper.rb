require 'rbbt/util/open'
require 'tsv'

SOURCE_DIR = 'source'
def define_source_tasks(sources)
  sources.each do |name, url|
    FileUtils.mkdir SOURCE_DIR unless File.exists? SOURCE_DIR
    file File.join(SOURCE_DIR, name) do |t|
      Open.write(t.name, Open.read(url, :cache => false))
    end
    if name =~ /.zip/
      file File.join(SOURCE_DIR, name.sub(/.zip$/,'')) =>  File.join(SOURCE_DIR, name) do |t|
        `unzip -p #{t.prerequisites.first} > #{ t.name }`
      end
    end
  end
end

$__headers = nil
def headers(values)
  $__headers = values
end

$__data = nil
def data(&block)
  $__data = block
end

$__tsv_tasks = []
def tsv_tasks
  $__tsv_tasks 
end

$__files = []
def add_to_defaults(list)
  $__files = list
end

def process_tsv(file, source, options = {}, &block)

  $__tsv_tasks << file

  file file => File.join(SOURCE_DIR, source) do |t|
    block.call

    d = TSV.new(t.prerequisites.first, options)

    if d.fields != nil
      data_fields = d.fields.dup.unshift d.key_field
      if $__headers.nil?
        $__headers = data_fields
      else
       $__headers = data_fields.zip($__headers).collect{|l| l.compact.last}
      end
    end

    if d.fields
      headers = d.fields.dup.unshift d.key_field
    else
      headers = nil
    end

    File.open(t.name.to_s, 'w') do |f|
      f.puts "#" + $__headers * "\t" if $__headers != nil
      d.each do |key, values|
        if $__data.nil?
          line = values.unshift key
        else
          line = $__data.call key, values
        end

        if Array === line
          key   = line.shift
          fields = line.collect{|elem| Array === elem ? elem * "|" : elem }
          fields.unshift key
          f.puts fields * "\t" 
        else
          f.puts line
        end
      end
    end
  end
end

task :default do |t|
  ($__tsv_tasks + $__files).each do |file| Rake::Task[file].invoke end
end

task :clean do
  ($__tsv_tasks + $__files).each do |file| FileUtils.rm file.to_s if File.exists?(file.to_s) end
end
