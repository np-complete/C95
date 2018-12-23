# RedChainer

次に、Preffered Network社が開発しているディープラーニングフレームワーク **Chainer** をRubyに移植した **Red Chainer** を試してみましょう。
このプロダクトは不思議なことにPyCallは一切使われておらず、純粋にゼロからRubyに移植された形になっています。
そのぶん、[Python版のコード](https://github.com/np-complete/c95/blob/master/src/chainer-mnist/mnist.py) の単純な移植よりは [よりRubyらしいコード](https://github.com/np-complete/c95/blob/master/src/chainer-mnist/mnist.rb)が書けるようになって違和感が少なくなります。
とはいえ、そもそもクラス定義をするという点にあまりRubyらしさがなく、記述も冗長で正直Kerasのほうが圧倒的に良いと感じました。
印象としてはまるでJavaみたい。

気になるパフォーマンスですが、ラップトップでGPUを使わず実行してみたところ、pythonのおよそ倍の時間がかかりました。
現在リリースされているバージョン(`0.3.2`)ではGPUは使えないようです。
また、 `numo-linalg` というgemを使わない場合は **絶望的な遅さ** になります。

## PyCall版

さて、もうひとつ気になるパフォーマンス比較があります。
Pythonのコードを[PyCallで移植](https://github.com/np-complete/c95/blob/master/src/chainer-mnist/pycall.rb)した場合のパフォーマンスです。

この作業は大変難航しました。
Kerasの移植のときには気づかなかったPyCallの微妙な仕様をいくつも踏む抜きました。

まず、PyCallは `method_missing` を使っているので、`trainer.extend` というコードが **Rubyのextendを呼ぼうとして** 死にます。
なので、 `method_missing` の内部で使っている `PyCall::LibPython::Helper.define_wrapper_method` で、 `extend` というメソッドはPythonのメソッドを呼ぶんだぞと教えてやります。

```ruby
trainer = training.Trainer.new(updater, PyCall.tuple([epochs, 'epoch']))
PyCall::LibPython::Helpers.define_wrapper_method(trainer, 'extend')
```

突然こんなコードが出てきたら面食らいますね。

次に、PyCallはどうやら **PythonのクラスのサブクラスをRubyで定義できない** という問題があります。
定義はできるんですが、内部で指している **__pyptr__** が共通なので、Pythonから見たら元のクラスに見えます。
Chainerは、Chainクラスを継承して **クラス定義で** ネットワークを構築しなければならないので[^1]、大問題です。

```ruby
class MLP < chainer.Chain
  attr_reader :l1, :l2, :l3

  def initialize
    p :initialize
    super
    init_scope do
      @l1 = Linear.new(nil, 512)
      @l2 = Linear.new(nil, 256)
      @l3 = Linear.new(nil, 10)
    end
  end

  def forward(x)
    h1 = l1.call(x)
    h2 = l2.call(h1)
    l3.call(h2)
  end
end
```

このようにそのままPythonのクラス定義を移植しても、

    MLP
    => <class 'chainer.link.Chain'>

Chainクラスだと認識されています。

    MLP.__pyptr__ == chainer.Chain.__pyptr__
    => true

Chainクラスと同じ `__pyptr__` を見ています。
Pythonから見たら完全にChainクラスのようです。

    mlp = MLP.new
    => <chainer.link.Chain object at 0x7f689f11d080>

`new` するとChainクラスのインスタンスになっています。
`p :initialize` が呼ばれていないであろうことも確認できます。


    mlp.__pyptr__
    => #<PyCall::PyPtr:0x0000557db9437178 type=Chain addr=0x00007f689f11d080>

あーもう完璧にChainのインスタンスだ。
でもちゃんとPython側のインスタンスができてるのは凄いな

    mlp.forward(0.0)
    NoMethodError: undefined method `forward' for <chainer.link.Chain object at 0x7f689f11d080>:Object

どうもRuby側からもおかしな認識されていて `forward` なんてメソッドはないようです。

    mlp.is_a? MLP
    => false

あ〜?? こりゃ完全にRubyでクラス定義を書くのを諦めたほうが良さそうです。

次に、MLPの定義だけ単独のPythonファイルにし、`pyimport` してみたところ、今度はそんなファイルは見つからないと言われます。
Cインタフェイスの `PyImport_ImportModule` まで降りて調べた結果、**カレントディレクトリがロード対象になってない** という仕様のためロードできなかったことが判明しました。

    pyimport 'mlp'
    PyCall::PyError: <class 'ModuleNotFoundError'>: No module named 'mlp'
    PyCall.sys.path.append '.'
    => nil
    pyimport 'mlp'
    => :mlp

`sys.path` にカレントディレクトリを追加して上手くロードできるようになりました。

あとはChainer内部で文字列でクラスを取得する `get_extension` が上手く動かない問題があり、雑に解決しました。

RedChainerは倍くらい遅かったのに対し、PyCall版は **ほぼPython版と同じ速度** になりました。
Kerasのときと同じような傾向です。
とはいえたくさんの罠に引っかかったので辛さはあります。

[^1]: Keras は `Sequential` のインスタンスにメソッド呼び出しで定義を追加し構築していく
