#!/usr/bin/env ruby

require 'pry'
require 'pycall/import'
include PyCall::Import

PyCall.sys.path.append '.'

pyimport :numpy, as: :np
pyimport :chainer
pyfrom 'chainer.functions', import: :relu
pyfrom 'chainer.links', import: [:Linear, :Classifier]
pyfrom 'chainer', import: :training
pyfrom 'chainer.training', import: :extensions
pyfrom 'mlp', import: :MLP

batchsize = 400
epochs = 20

device = ENV['GPU'] ? 0 : -1

model = Classifier.new(MLP.new)

if ENV['GPU']
  chainer.backends.cuda.get_device_from_id(device).use
  model.to_gpu
end

optimizer = chainer.optimizers.Adam.new
optimizer.setup(model)

train, test = chainer.datasets.get_mnist.to_a
train_itr = chainer.iterators.SerialIterator.new(train, batchsize)
test_itr  = chainer.iterators.SerialIterator.new(test,  batchsize, repeat: false, shuffle: false)

updater = training.updaters.StandardUpdater.new(train_itr, optimizer, device: device)
trainer = training.Trainer.new(updater, PyCall.tuple([epochs, 'epoch']))
PyCall::LibPython::Helpers.define_wrapper_method(trainer, 'extend')

trainer.extend extensions.Evaluator.new(test_itr, model, device: device)
trainer.extend extensions.PrintReport.new(['epoch', 'main/loss', 'validation/main/loss', 'main/accuracy', 'validation/main/accuracy', 'elapsed_time'], log_report = extensions.LogReport.new)

trainer.extend(extensions.ProgressBar.new)

trainer.run
