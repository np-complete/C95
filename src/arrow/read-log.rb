#!/usr/bin/env ruby

require 'pry'
require 'benchmark'
require 'oj'
require 'msgpack'
require 'arrow'

bench_times = ENV.fetch('BENCH', 100).to_i

Benchmark.bm(10) do |bm|
  bm.report(:json) do
    bench_times.times do
      Oj.load(File.read('/tmp/log.json'))
    end
  end

  bm.report(:msgpack) do
    bench_times.times do
      MessagePack.unpack(File.read('/tmp/log.msgpack'))
    end
  end
  bm.report(:arrow) do
    bench_times.times do
      Arrow::MemoryMappedInputStream.open('/tmp/log.arrow') do |input|
        Arrow::RecordBatchFileReader.new(input).each do |x|
          x
        end
      end
    end
  end
end
