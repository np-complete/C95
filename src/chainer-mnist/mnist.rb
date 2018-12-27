#!/usr/bin/env ruby

require 'pry'
require 'chainer'
require 'numo/linalg'

batchsize = 400
epochs = 20

class MLP < Chainer::Chain
  L = Chainer::Links::Connection
  F = Chainer::Functions::Activation::Relu

  def initialize
    super()
    init_scope do
      @l1 = L::Linear.new(nil, out_size: 512)
      @l2 = L::Linear.new(nil, out_size: 256)
      @l3 = L::Linear.new(nil, out_size: 10)
    end
  end

  def call(x)
    h1 = F.relu @l1.call(x)
    h2 = F.relu @l2.call(h1)
    @l3.call h2
  end
end

model = Chainer::Links::Model::Classifier.new(MLP.new)
optimizer = Chainer::Optimizers::Adam.new
optimizer.setup(model)

train, test = Chainer::Datasets::Mnist.get_mnist
train_itr = Chainer::Iterators::SerialIterator.new(train, batchsize)
test_itr = Chainer::Iterators::SerialIterator.new(test, batchsize, repeat: false, shuffle: false)

updater = Chainer::Training::StandardUpdater.new(train_itr, optimizer)
trainer = Chainer::Training::Trainer.new(updater, stop_trigger: [epochs, 'epoch'])
trainer.extend Chainer::Training::Extensions::Evaluator.new(test_itr, model)
trainer.extend Chainer::Training::Extensions::LogReport.new
trainer.extend Chainer::Training::Extensions::PrintReport.new(['epoch', 'main/loss', 'validation/main/loss', 'main/accuracy', 'validation/main/accuracy', 'elapsed_time'])
trainer.extend Chainer::Training::Extensions::ProgressBar.new

trainer.run
