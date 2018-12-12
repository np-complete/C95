# PyCallでMNIST

もう少し実践的に、**KerasでMNIST**を学習させるコードをPyCallで移植してみましょう。
[Python版のコード](https://github.com/np-complete/c95/blob/master/src/keras-mnist/mnist.py)は、[Kerasの公式サンプル](https://github.com/keras-team/keras/blob/master/examples/mnist_mlp.py)ほぼそのままです。
それをほぼ素直に[Ruby版](https://github.com/np-complete/c95/blob/master/src/keras-mnist/mnist.rb)に移植してみました。
気になるところを挙げていきます。

まず、Pythonでは `(x_train, y_train), (x_test, y_test) = mnist.load_data()` と一発で複雑な `Tuple` を変数に代入できます。
Rubyでも、同じような文法で **RubyのArray** を変数に代入できるのですが、残念ながらPyCallを使うと戻ってくるのは **PyObject** なので上手く動きません。
とはいえ、学習データと検証データに同じ前処理をする、という部分はRubyのほうが圧倒的に表現力が高いと思います。

もうひとつ、`Sequential()` や `Dense(512)` などは、Rubyistには関数を実行しているように見えますが、これは **Pythonのクラス** でインスタンスを作るコードのようです。
インターネットで見つかるドキュメントでは、Pythonのコードに見た目を似せるためか `Sequential.()` という書き方をしている例が多くあります。
これは、 `Sequential.call` の糖衣構文ですが、正直見た目的にもあまり好きではありません。
むしろ **Rubyらしく** 堂々と `Sequential.new` と呼ぶほうが分かりやすいのではないでしょうか。
我々はPythonなど書きたくないのです。

さて気になるのは実行結果です。
機械学習なのでもちろん少し誤差はあるのですが、Ruby版もPython版と同じ精度が出たので、両者のコードは全く同一で、学習もきちんとできていると判断できそうです。
さらになんと、**GPUを使った場合** も正しく動作しました。
速度に関しても、学習のstepあたりの実行速度を比較すると **ほぼ同じ** どころか環境によって **Rubyのほうが速い** こともありました[^1][^2]。
実際のアプリケーションでもPyCallは十分に実用になるということがわかりました。

[^1]: ラップトップではPythonのほうが速く デスクトップではRubyのほうが速かった
[^2]: GPUの場合は速すぎて誤差が可視化できなかった

それにしても、 **tensorflowが最新のPython 3.7.1で動かないってホントにクソな言語だな** と思いました。
