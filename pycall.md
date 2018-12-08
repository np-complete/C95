# PyCall

まず、RubyからPythonを使う **[pycall](https://github.com/mrkn/pycall)** を使ってみましょう。
pycallを使うには `libpython.so` が必要なので、 `apt install python-dev` や、pyenvを使っている場合は `PYTHON_CONFIGURE_OPTS=--enable-shared` の環境変数をセットしてビルドする必要があります。

READMEにあるように、`pyimport` メソッドを使ってpythonのライブラリを読み込むことができます。

    [1] pry(main)> pyimport :numpy
    => :numpy
    [2] pry(main)> numpy
    => <module 'numpy' from '/home/masaki/.pyenv/versions/3.7.1/lib/python3.7/site-packages/numpy/__init__.py'>
    [3] pry(main)> numpy.class
    => Module

インストールされたnumpyを参照しているのがわかります。
当然、あらかじめ `pip install numpy` などでpythonのライブラリをインストールしておく必要があります。

## Hello World

numpyを使った簡単なコードを書いてみましょう。

```python
# python

import numpy as np
array1 = np.np.array([[1, 2, 3],
                   [30, 20, 10]])
array2 = np.array([[3, 4],
                   [5, 6],
                   [7, 8]])
res = array1.dot(array2)
print(res)
```

これをRubyで書くと

```ruby
#ruby

require 'pycall/import'
include PyCall::Import

pyimport :numpy, as: :np

array1 = np.array([[1, 2, 3],
                   [30, 20, 10]])
array2 = np.array([[3, 4],
                   [5, 6],
                   [7, 8]])
res = array1.dot array2
p res
```

ほぼ同じ感覚で書けます。
もちろん実行結果も同じです。
カッコの省略や、 **インデントがめんどくさくない** などのRubyのメリットが活かせます。

ただ、`np.dot` の演算子表記である `array1 @ array2` という表記はRubyではできませんでした。 `array1.send(:@, array2)` でもダメでした。

## Benchmark

次に実行結果を比較してみましょう。
先程のコードから、

`np.array([1, 2, 3], [30, 20, 10]]` と、 `array1.dot(array2)` をそれぞれ1万回繰り返す時間を測定します。

|        |  init |   dot |
|--------|------:|------:|
| python | 0.013 | 0.007 |
| ruby   | 0.055 | 0.045 |

initに比べてdotのほうが時間の差が大きいことがわかります。
およそ5〜6倍くらい遅いと考えておけば良さそうです。

## 中身を読む

Rubyの世界からPythonのオブジェクト同士を計算できているのはなかなか不思議な光景です。
その仕組みを探ってみましょう。

まず `pyimport` が何をしているのか調べます。
辿っていくと、 `PyCall` の中で `PyCall::LibPython::Helpers.import_module` が呼ばれていることがわかります。
これはC拡張の `ext/pycall/pycall.c` で定義された `pycall_import_module` などの関数にだどり付きます。

その中身を抜粋すると、

```c
PyObject *pymod = Py_API(PyImport_ImportModule)(name);
return pycall_pyobject_to_ruby(pymod);
```

という2つの処理から成り立っています。
この中で、 `PyImport_ImportModule` はlibpython.soで用意されたAPIで、引数 `name` をとって `PyObject` を返す関数のようです。
Py_APIは、単純に関数テーブルから該当する名前の関数を探すマクロです。

`pycall_pyobject_to_ruby` は名前の通り `PyObject` をRubyのオブジェクトに変換する関数で、この中で一番重要な役割を担っています。
大量のif文で `PyObject` の属性を調べ、適切なRubyオブジェクトに変換しています。
例えばpythonの文字列はRubyのStringに変換されてしまうようです。
これとは対になる `pycall_pyobject_from_ruby` という関数もあり、Ruby世界とPython世界の橋渡しをしているようです。

さて、`PyObject` がモジュールの場合は、`pycall_pymodule_to_ruby` によって変換されるようです。その中身は、 `pycall_pyptr_new` で `PyPtr` オブジェクトを作って、 `wrap_module` を実行しているようです。
`PyPtr` はPyObjectのアドレスが格納されたオブジェクトで、`wrap_moduel` はそのオブジェクトを持った新しいモジュールを作ります。
この新しいモジュールが先程の `numpy` の実体のようです。

    pry(main)> numpy.__pyptr__
    => #<PyCall::PyPtr:0x0000000004c301c8 type=module addr=0x00007f20454b0868>

見事に見つかりました!

次に、 `numpy.array` がどのように動いているのか調べましょう。
おそらく `method_missing` を使っているんだろうと予想します。
`pry` 上で `ls numpy` を実行してみると、 `PyCall::PyObjectWrapper` に `method_missing` が定義されているのを発見しました。
`numpy.array` で作られたオブジェクトにも、同じモジュールがincludeされているのも確認しました。

`PyCall::PyObjectWrapper#method_missing` は、なかなかおもしろい処理をしています。
メソッドが演算子の場合、Pythonの特別なメソッド(例えば `+` なら `__add__` ) に名前を変換します。そして、`Pycall::LibPython::Helpers.define_wrapper_method` で該当する名前のメソッドを作ります。
ここでCの世界に戻ってきました。
最終的に、 `pycall_call_python_callable` という関数がPythonオブジェクトのメソッド呼び出しを処理することになります。
この関数の中で、引数に与えられたRubyオブジェクトを `pycall_pyobject_from_ruby` を使って `PyObject` に変換し、libpython.soの `PyObject_Call` を呼んでいます。
もちろん `PyObject_Call` の返り値をまたRubyオブジェクトに変換しています。

さて、これで `numpy.array([1, 2]) + 2` の処理がどのように行われるかわかりました。
それでは、`2 + numpy.array([1,2])` はどう処理されるのでしょうか。

Rubyの数値クラスには、知らない相手と計算するための `coerce` という仕組みがあります。
相手が `coerce` を実装している場合、 `coerce` を呼んだ結果に対して同じ演算子で計算します。
同じような仕組みがPythonにもあり、 `__radd__` などの特殊なメソッドを定義しておくと、組み込みの数値の演算子を拡張することができます。
最終的に、 `2 + numpy.array([1, 2])` は、 `numpy.array([1, 2]}.__radd__(2)` が呼ばれることになり、これはPythonの内部と全く同じなので上手く動作しているわけです。
