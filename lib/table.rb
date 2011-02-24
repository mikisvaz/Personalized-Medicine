require 'json'
require 'rbbt/util/misc'
require 'rbbt/util/simpleDSL'
require 'spreadsheet'

class FlexTable
  include SimpleDSL

  def self.rows2excel(rows, fields, file)
    workbook = Spreadsheet::Workbook.new

    heading = Spreadsheet::Format.new( :color => "green", :bold => true, :underline => true ) 
    data = Spreadsheet::Format.new( :color => "black", :bold => false, :underline => false ) 
    workbook.add_format(heading)  
    workbook.add_format(data)  

    worksheet = workbook.create_worksheet

    worksheet.row(0).concat fields
    worksheet.row(0).default_format = heading

    rows.each_with_index do |row, i| 
      worksheet.row(i + 1).concat row.collect{|e| 
        @@ic ||= Iconv.new('UTF-8//IGNORE', 'UTF-8')
        @@ic.iconv(e)
      }
    end

    workbook.write(file)
  end

  def configure(name, *args, &block)
    case name.to_sym
    when :show
      @show[@_current_field] = block
    when :sort
      @sort[@_current_field] = block
    when :sort_by
      @sort_by[@_current_field] = block
    end
  end

  def field(name, flexinfo = {}, &block)
    @flexinfo[name] = flexinfo
    @_current_field = name
    @fields << name
    block.call if block
  end

  def initialize(data, configfile = nil)
    @data     = data
    @name     = {}
    @flexinfo = {}
    @sort     = {}
    @sort_by  = {}
    @show     = {}

    if configfile.nil?
      @fields   = ([data.key_field].concat data.fields).compact
    else
      @fields = []
      load_config :configure, configfile
    end
  end

  def default_show(key, values, field)
    if pos = Misc.field_position(values.fields, field, true)
      case
      when String === values[pos]
        values[pos]
      when Array === values[pos]
        values[pos] * "|"
      else
        values[pos].inspect
      end
    else
      key
    end
  end

  def data(sorted, format = nil)
    sorted.collect do |p|
      key, values = p
      values = NamedArray.name values, @data.fields
      $_table_format = format
      res = NamedArray.name @fields.collect{|field| 
        if @show[field]
          @show[field].call key, values
        else
          default_show(key, values, field)
        end
      }, @fields
      $_table_format = nil
      res 
    end
  end

  def default_sort(field)
    @data.sort_by do |key, values|
      values = NamedArray.name values, @data.fields
      if pos = Misc.field_position(values.fields, field, true)
        values[pos].inspect
      else
        key
      end
    end
  end

  def items(page, num, field, direction, format = nil)
    field = @fields.first if field == 'undefined'
    sorted = case
             when @sort[field]
               @data.sort &@sort[field]
             when @sort_by[field]
               @data.sort_by &@sort_by[field]
             else
               default_sort field
             end
    
    sorted.reverse! if direction == 'desc'
    data(sorted[((page - 1) * num)..(page * num)], format)
  end

  def excel(filename)
    FlexTable.rows2excel(items(1, @data.size, 'undefined', 'excel'), @fields, filename)
  end

  def flexicode(url, options = {})
    options = Misc.add_defaults options, 
      :dataType           => 'json',
      :sortorder          => "desc",
      :usepager           => true,
      :singleSelect       => true,
      :title              => "Personalized Medicine",
      :useRp              => true,
      :rp                 => 15,
      :showTableToggleBtn => false,
      :height             => 300,
      :nowrap             => false,
      :resizable          => false


    flexicode = {
      :url =>  url,
      :colModel => @fields.collect{|field| { :name => field, :display => @name[field] || field, :sortable => true}.merge(@flexinfo[field] || {})},
    }.merge options

    flexicode.to_json
  end
end
