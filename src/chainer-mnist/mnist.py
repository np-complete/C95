#!/usr/bin/env python

import os
import numpy as np
import chainer
import chainer.functions as F
import chainer.links as L
from chainer import training
from chainer.training import extensions
from mlp import MLP

batchsize = 400
epochs = 20

device = -1
if os.getenv('GPU', False):
    device = 0

model = L.Classifier(MLP())

if device == 0:
    chainer.backends.cuda.get_device_from_id(device).use()
    model.to_gpu()

optimizer = chainer.optimizers.Adam()
optimizer.setup(model)

train, test = chainer.datasets.get_mnist()
train_itr = chainer.iterators.SerialIterator(train, batchsize)
test_itr  = chainer.iterators.SerialIterator(test,  batchsize, repeat = False, shuffle = False)

updater = training.updaters.StandardUpdater(train_itr, optimizer, device = device)
trainer = training.Trainer(updater, (epochs, 'epoch'))
trainer.extend(extensions.Evaluator(test_itr, model, device = device))
trainer.extend(extensions.LogReport())
trainer.extend(extensions.PrintReport(['epoch', 'main/loss', 'validation/main/loss', 'main/accuracy', 'validation/main/accuracy', 'elapsed_time']))

trainer.extend(extensions.ProgressBar())

trainer.run()
