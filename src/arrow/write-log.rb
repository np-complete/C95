#!/usr/bin/env ruby

require 'arrow'
require 'oj'
require 'msgpack'
require 'faker'
require 'benchmark'

record_num = ENV.fetch('RECORDS', 1).to_i
bench_times = ENV.fetch('BENCH', 100).to_i

fields = [
  Arrow::Field.new('ipaddress', :string),
  Arrow::Field.new('timestamp', :uint32),
  Arrow::Field.new('execution', :float),
  Arrow::Field.new('method',    :string),
  Arrow::Field.new('path',      :string),
  Arrow::Field.new('response',  :uint16),
  Arrow::Field.new('body',      :string)
]

schema = Arrow::Schema.new(fields)
responses = [200] * 30 +  [401] + [404] * 3 +  [500] * 2 + [301] * 5
now = Time.now.to_i

records = record_num.times.map do
  [Faker::Internet.ip_v4_address,
   (now * rand).to_i,
   rand,
   %w(GET POST SHOW DELETE).sample,
   '/',
   responses.sample,
   '{"hello": "world"}']
end

columns = [Arrow::StringArray, Arrow::UInt32Array,
           Arrow::FloatArray, Arrow::StringArray,
 Arrow::StringArray, Arrow::UInt16Array,
 Arrow::StringArray].each_with_index.map do |klazz, i|
  klazz.new(records.map {|x| x[i]})
end

Benchmark.bm(10) do |bm|
  bm.report(:redarrow) do
    bench_times.times do
      Arrow::FileOutputStream.open("/tmp/log.arrow", false) do |output|
        Arrow::RecordBatchFileWriter.open(output, schema) do |writer|
          record_batch = Arrow::RecordBatch.new(schema, records.size, columns)
          writer.write_record_batch(record_batch)
        end
      end
    end
  end

  bm.report(:json) do
    bench_times.times do
      File.open('/tmp/log.json', 'w') do |f|
        f.write Oj.dump(records)
      end
    end
  end

  bm.report(:msgpack) do
    bench_times.times do
      File.open('/tmp/log.msgpack', 'w') do |f|
        f.write MessagePack.pack(records)
      end
    end
  end
end
