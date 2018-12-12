#!/usr/bin/env python

from keras.datasets import mnist
from keras.models import Sequential
from keras.layers.core import Dense, Dropout, Activation
from keras.utils import np_utils

epochs = 20

(x_train, y_train), (x_test, y_test) = mnist.load_data()

x_train = x_train.reshape(x_train.shape[0], x_train.shape[1] * x_train.shape[2]) / 255.0
x_test  =  x_test.reshape( x_test.shape[0],  x_test.shape[1] *  x_test.shape[2]) / 255.0

y_train = np_utils.to_categorical(y_train, 10)
y_test  = np_utils.to_categorical( y_test, 10)

model = Sequential()
model.add(Dense(512, activation = 'relu', input_shape = (784,)))
model.add(Dropout(0.2))
model.add(Dense(256, activation = 'relu'))
model.add(Dropout(0.2))
model.add(Dense(10, activation = 'softmax'))

model.compile(loss = 'categorical_crossentropy', optimizer = 'adam', metrics = ['accuracy'])
model.summary

validation_data = (x_test, y_test)

model.fit(x_train, y_train, epochs = epochs, validation_data = validation_data)
