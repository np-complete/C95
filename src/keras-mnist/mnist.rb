#!/usr/bin/env ruby

require 'pry'
require 'pycall/import'
include PyCall::Import

pyfrom 'keras.datasets', import: :mnist
pyfrom 'keras.models', import: :Sequential
pyfrom 'keras.layers.core', import: [:Dense, :Dropout, :Activation]
pyfrom 'keras.utils', import: :np_utils
pyfrom 'keras.utils.np_utils', import: :to_categorical

epochs = 20

train_data, test_data = mnist.load_data.to_a
xxx, yyy = train_data.to_a.zip(test_data.to_a)

x_train, x_test = xxx.map do |x|
  x.reshape(x.shape[0], x.shape[1] * x.shape[2]).astype('float32') / 255
end

y_train, y_test= yyy.map do |y|
  np_utils.to_categorical(y, 10)
end

model = Sequential.new
model.add Dense.new(512, activation: 'relu', input_shape: PyCall.tuple([784,]))
model.add Dropout.new(0.2)
model.add Dense.new(256, activation: 'relu')
model.add Dropout.new(0.2)
model.add Dense.new(10, activation: 'softmax')

model.compile(loss: 'categorical_crossentropy', optimizer: 'adam', metrics: ['accuracy'])
model.summary

validation_data = PyCall.tuple([x_test, y_test])

model.fit(x_train, y_train, epochs: epochs, validation_data: validation_data)
