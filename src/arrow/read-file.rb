#!/usr/bin/env ruby

require 'arrow'
require 'pry'

times = ENV.fetch('TIMES', 1).to_i

times.times do
  Arrow::MemoryMappedInputStream.open('/tmp/python.arrow') do |input|
    reader = Arrow::RecordBatchFileReader.new(input)
    fields = reader.schema.fields
    reader.each_with_index do |record_batch, i|
      next if times > 1

      puts '=' * 48
      puts "record-batch[#{i}]:"
      fields.each do |field|
        values = record_batch.map do |record|
          record[field.name]
        end
        puts "  #{field.name}: #{values.inspect}"
      end
    end
  end
end
