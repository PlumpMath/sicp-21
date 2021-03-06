SICP 読書ノート#41 - 第3章 まとめ
======================================

ところどころ飛ばしましたが、3章をひと通り読み終えました。この章で学んだことを上手くまとめるのは相当難しいですが、自分なりに整理したいと思います。

1章〜2章では手続きやデータによる抽象化について学びましたが、3章はそれらのモジュールをいかに組み合わせてプログラムを組織化していくかの戦略がテーマでした。さらに大きな観点で言えば、私達がモデル化しようとする現実世界をプログラム上での計算モデルとして如何に構築していくことがテーマとも言えるでしょう。

3章の冒頭でその具体的な戦略について語られています。

> 大きいプログラムを組織化する方法は, われわれがモデル化するシステムをどう認識するかにかなりなところまで左右される. 本章では, いくらか異ったシステム構造の二つの「世界観」から生じる顕著な組織化戦略を研究する. 第一の組織化戦略は オブジェクト(objects)に注目するもので, 巨大システムを, 時間とともに変化するいろいろなオブジェクトの集りと見るものである. もう一つの組織化戦略は,電気技術者が信号処理システムを見るように, システム内を流れる情報の ストリーム(streams)に注目するものである.

オブジェクトとはプログラム上で実現したい概念であり、制御すべき対象を抽象化したものであると言えると思うのですが、その対象がmutableであるなら時と共に変化する状態を持ちます。

§3.1〜3.3ではオブジェクトの状態を変更する手法としての代入、またそれらの状態を保持する環境モデルにスポットをあて、オブジェクトを組織化してプログラムを構築する技法、一種のオブジェクト指向プログラミングについて学びました。しかし、§3.4ではとあるオブジェクトに対し(実行コンテキストという意味での)複数のプロセスから作用されるケースではその一貫性を保つテクニックが必要であり、そのための排他制御等を見ましたが、それらを駆使しても非常に困難であることも分かりました。

§3.5ではもうひとつの技法であるストリームについて学びました。ストリームは時間```t```とともに変化する状態値```s(t)```をリストで保持するため、代入による状態変更も不要ですし、```delay```や```force```によって時間```t```を```t-1```にも```t+1```にもすることができます。遅延評価による複雑さを持ち込みますが、オブジェクトのようなその時に縛られる状態は存在しないため、関数プログラミングのような簡潔なスタイルを保つことができます。

一見して万能に見えるストリームですが、最後の節の共同口座のストリーム化の例のように、2つのストリームの時間的なすり合わせをどう行うかという点で大きな課題が残っています。


3章は以下で締めくくられています。

> 本章は, モデル化しようとする実世界の認識に合致する構造を持つ, 計算モデルを構築するという目的をもって始めた. われわれは, ばらばらで, 時に縛られ, 相互作用する, 状態を持つオブジェクトの集りで世界をモデル化することも出来るし, また単一の, 時に縛られない, 状態のない個体で世界をモデル化することも出来る. どちらの見方も強力な利点があるが, どちらかだけでは完全には満足出来ない. もっとすばらしい統合が現れなければならない.

もっとすばらしい統合とは何でしょうか？ 4章以降でそれが現れるのか、まだ後の楽しみのようです。


次回は「§4 超言語的抽象」から。

--------------------------------

※「SICP読書ノート」の目次は[こちら](/entry/sicp/index)
