# -*- coding: utf-8 -*-

=begin
Fiver on Cube version 2.02

周辺領域を反転させて全面をONにするゲームFiverのキューブ版
割とよくできたかな。思いついたものと言えば、一つ一つの面を３角形にして
20面体パネルを作ってみるとか、平面を６面体でタイルするとか。難しそう。

今回使用するのはマウスのみです。
マウスでキューブを回転させて、パネルをクリックするとそのパネルと隣り合うパネルが反転します。
これを繰り返してすべての面を明るくすればクリアです。

画面上で右クリックをするとメニューが表示されます。
一手戻る、最初からやり直す、次のレベル、前のレベル、などが選べます。
ゲームの終了もここでできます。

レベル設定ですが、全部が明るい状態を基準として、
レベル１・・・ランダムに１つ押された状態。
レベル２・・・ランダムに２つ押された状態。
となっていって、どんどん複雑になっていきます。
スコア機能がないのがちょっと残念。

################################################ 以下、プログラムの解説
展開図で言うとこんな感じで番号を振ってある。
┌─┬─┬─┐
│６│１｜５｜
└─┼─┼─┘
    │２│
    ├─┤
    │３│
    ├─┤
    │４│
    └─┘
文字の上向きがそのまま上向き。初期位置は１を見ている。

2005/04/01更新：
・画面左上に「現在のレベル」を表示。
・わかりにくいですが、アイドルコールバックを止めました。
こちらからの操作がなければ何も処理しないことになります。
CPU処理の軽減になればいいなぁ。
・微妙な話ですが、ウィンドウのリサイズに対応。
キューブは大きくなりませんが周りの空間が大きくなります。
文字は動きません(^^ゞ

以下、2005/3/31更新分 #############################################
マウスクリックで反転できるようにした。
細かい仕組みは（意外と簡単だったが）下のtouch?関数を見てください。
あと、GLUTの機能でGLUT.CreateMenuがあったのでコレを使って
マウスのみで操作できるようにした。
ん〜、処理が追っつかない場合にキーボードから終了できるくらいには
しといた方がいいかな。多分大丈夫だと踏んでるんだけど。

以下、2005/3/28更新分 #############################################
回転方法を角度を変更する方法から行列の積で表現する方法に変更。
マウスで操作するにはこちらがよさそうだ。

######################### 後々のための解説 #########################
マウスで操作するときの回転系は２次元方向の角度変更型だが、
それは局所的には有効であって、角度変更後に再度局所座標系変更のためには
行列を使うのが有効。
具体的にはGL.Rotateを行列表示してGL.LoadMatrixを使うことで
行列表現を保存することを可能にした。
このようにすると回転後、マウスボタンをリリースしたときに回転行列の積が保存され、
状態行列として保存される。これによって新たに視点座標系を中心とする局所座標が
できあがるために、上下左右のスライドがそのまま"視点からの"上下左右の回転になる。

数式表示だとこんな感じ？
M = matrix_now , T = matrix_tmp , I = Identity
[ MI →回転→ ( MTM^(-1) ) MI = MTI ]

当然ながら、マウスモーション時は局所座標のままなので、
右に大きくスライドした後に上にスライドしたりすると
大きなずれが生じる。２次元で近似してるんだからそれはしょうがない(^-^;
####################################################################

行列の積計算のために添付ライブラリmatrix.rbを使用。なくてもできるとは思うけど定義が大変。
あと、GL.MultMatrixが有効そうだが、よく分からなかったのでmatrix.rbで積計算を目に見える形で
実行している。できることならOpenGL内部で処理したいなぁ。

#########################################Exerb用の注記
matrix.rb内部でe2mmap.rbを読み込んでいる。

カウンタも変更。操作するとカウントダウンされていきます。
0になるまでにクリアしなければリセットされます。
クリアできれば次のレベルへ。（瞬間的に変化する。味気ない。）

############## 所感 ########################
局所回転系表示がうまくできたことに今回は感激。
離れた面とのリンク関係を記述するのが面倒くさかった。
システムとしては面白いんじゃない？
=end

require "rubygems"

require "opengl"
require "glut"
require "matrix"

###################################### 定数
DT     = 0.1    # 回転角単位
EYE_P  = 2.0  # カメラの原点からの距離を決めるパラメタ
EDGE   = 4.0  # ビューボリュームを決めるベースパラメタ
DISPLAY = 400.0
$display_x = $display_y = DISPLAY
RECT_SIZE = 2.0
FLOOT = 0.01

########################## ビューボリュームのパラメタ(カメラ座標での記述)
LEFT   = -EDGE     # 左側面
RIGHT  = EDGE      # 右側面
BOTTOM = -EDGE     # 底面
TOP    = EDGE      # 上面
NEAR   = -2*EDGE     # 前面
FAR    = 2*EDGE      # 後面

#######################各面の左上頂点の座標を2次元で指定
RECTS = [
[-RECT_SIZE    ,-RECT_SIZE/3.0], #1
[-RECT_SIZE/3.0,-RECT_SIZE/3.0], #2
[ RECT_SIZE/3.0,-RECT_SIZE/3.0], #3
[-RECT_SIZE    , RECT_SIZE/3.0], #4
[-RECT_SIZE/3.0, RECT_SIZE/3.0], #5
[ RECT_SIZE/3.0, RECT_SIZE/3.0], #6
[-RECT_SIZE    , RECT_SIZE    ], #7
[-RECT_SIZE/3.0, RECT_SIZE    ], #8
[ RECT_SIZE/3.0, RECT_SIZE    ]  #9
]

################### デジタル表示部分 ##############
SEG_WIDTH = RECT_SIZE/12  #セグメントの幅
SEG_LENGTH = RECT_SIZE/4 #セグメントの長さ

def make_v_segment(x1,y1) #垂直のセグメント
  GL.Begin(GL::TRIANGLE_STRIP)
    GL.Vertex(x1+SEG_WIDTH/2,y1,FLOOT)
    GL.Vertex(x1            ,y1-SEG_WIDTH/2,FLOOT)
    GL.Vertex(x1+SEG_WIDTH  ,y1-SEG_WIDTH/2,FLOOT)
    GL.Vertex(x1            ,y1-SEG_LENGTH+SEG_WIDTH/2,FLOOT)
    GL.Vertex(x1+SEG_WIDTH  ,y1-SEG_LENGTH+SEG_WIDTH/2,FLOOT)
    GL.Vertex(x1+SEG_WIDTH/2,y1-SEG_LENGTH,FLOOT)
  GL.End()
end

def make_h_segment(x1,y1) #水平のセグメント
  GL.Begin(GL::TRIANGLE_STRIP)
    GL.Vertex(x1            ,y1-SEG_WIDTH/2,FLOOT)
    GL.Vertex(x1+SEG_WIDTH/2,y1,FLOOT)
    GL.Vertex(x1+SEG_WIDTH/2,y1-SEG_WIDTH,FLOOT)
    GL.Vertex(x1+SEG_LENGTH-SEG_WIDTH/2,y1,FLOOT)
    GL.Vertex(x1+SEG_LENGTH-SEG_WIDTH/2,y1-SEG_WIDTH,FLOOT)
    GL.Vertex(x1+SEG_LENGTH,y1-SEG_WIDTH/2,FLOOT)
  GL.End()
end

PATTERN = [
  [1,1,1,1,1,0,1],
  [0,0,1,1,0,0,0],
  [0,1,1,0,1,1,1],
  [0,0,1,1,1,1,1],
  [1,0,1,1,0,1,0],
  [1,0,0,1,1,1,1],
  [1,1,0,1,1,1,1],
  [1,0,1,1,1,0,0],
  [1,1,1,1,1,1,1],
  [1,0,1,1,1,1,1]
]

def make_number(number,x,y) ## 左上の座標を指定
  array = PATTERN[number].dup
  onoff = array.shift
  make_v_segment(x,y-SEG_WIDTH/2) if onoff == 1
  onoff = array.shift
  make_v_segment(x,y-SEG_WIDTH/2-SEG_LENGTH) if onoff == 1
  onoff = array.shift
  make_v_segment(x+SEG_LENGTH,y-SEG_WIDTH/2) if onoff == 1
  onoff = array.shift
  make_v_segment(x+SEG_LENGTH,y-SEG_WIDTH/2-SEG_LENGTH) if onoff == 1
  onoff = array.shift
  make_h_segment(x+SEG_WIDTH/2,y) if onoff == 1
  onoff = array.shift
  make_h_segment(x+SEG_WIDTH/2,y-SEG_LENGTH) if onoff == 1
  onoff = array.shift
  make_h_segment(x+SEG_WIDTH/2,y-SEG_LENGTH*2) if onoff == 1
end

################### デジタル表示部分 終わり ##############

class Matrix
  def rotate(theta,phi)
    return self * Matrix[
      [1 , 0                    , 0                    , 0 ],
      [0 , Math.cos(phi*Pi/180) , Math.sin(phi*Pi/180) , 0 ],
      [0 ,-Math.sin(phi*Pi/180) , Math.cos(phi*Pi/180) , 0 ],
      [0 , 0                    , 0                    , 1 ]
    ]*Matrix[
      [ Math.cos(theta*Pi/180) , 0 ,-Math.sin(theta*Pi/180) , 0 ],
      [ 0                      , 1 , 0                      , 0 ],
      [ Math.sin(theta*Pi/180) , 0 , Math.cos(theta*Pi/180) , 0 ],
      [ 0                      , 0 , 0                      , 1 ]
    ]
  end
end

class Vector
  def rotate(theta,phi)
    return Matrix[
      [1 , 0                    , 0                    , 0 ],
      [0 , Math.cos(phi*Pi/180) ,-Math.sin(phi*Pi/180) , 0 ],
      [0 , Math.sin(phi*Pi/180) , Math.cos(phi*Pi/180) , 0 ],
      [0 , 0                    , 0                    , 1 ]
    ]*Matrix[
      [ Math.cos(theta*Pi/180) , 0 , Math.sin(theta*Pi/180) , 0 ],
      [ 0                      , 1 , 0                      , 0 ],
      [-Math.sin(theta*Pi/180) , 0 , Math.cos(theta*Pi/180) , 0 ],
      [ 0                      , 0 , 0                      , 1 ]
    ] * self
  end
  def []=(i,x)
    @elements[i]=x
  end
end

################### ９個の面の表示 #######################
def draw_rects(number,state,matrix)
  #全体のシェーディング設定
  GL.Material(GL::FRONT_AND_BACK,GL::SPECULAR, [0.0,0.0,0.0])
  GL.Material(GL::FRONT_AND_BACK,GL::SHININESS,640)

  ###  面を描く
  9.times do |i|
    GL.Begin(GL::QUADS)
      #state[i]で色を決定。draw_rectsの時点で描画面を一つに絞っている。残り９面。
      GL.Normal(0.0,0.0,1.0)
      GL.Material(GL::FRONT_AND_BACK,GL::AMBIENT,  [0.8,0.8,0.0]) #パネルの色、シェーディング指定
      GL.Material(GL::FRONT_AND_BACK,GL::DIFFUSE,  [0.8,0.8,0.0])                  #ONの状態
      GL.Material(GL::FRONT_AND_BACK,GL::DIFFUSE,  [0.0,0.0,0.0]) if state[i] == 0 #OFFの状態
      GL.Vertex(RECTS[i][0],RECTS[i][1],0.0)
      GL.Vertex(RECTS[i][0]+RECT_SIZE/1.5,RECTS[i][1],0.0)
      GL.Vertex(RECTS[i][0]+RECT_SIZE/1.5,RECTS[i][1]-RECT_SIZE/1.5,0.0)
      GL.Vertex(RECTS[i][0],RECTS[i][1]-RECT_SIZE/1.5,0.0)
    GL.End()

    ### 数字を描く
    #GL.Material(GL::FRONT_AND_BACK,GL::AMBIENT,  [0.3,0.3,0.5]) #数字の色、シェーディング指定
    #GL.Material(GL::FRONT_AND_BACK,GL::DIFFUSE,  [0.3,0.3,1.0])
    #make_number(i+1,RECTS[i][0]+RECT_SIZE/6,RECTS[i][1]-RECT_SIZE/24)
  end

  ### 線を描く
  GL.Disable(GL::LIGHTING)
  GL.Color(0.0,0.0,0.0)
  GL.Begin(GL::LINES)
    GL.Vertex(-RECT_SIZE/3.0, RECT_SIZE,FLOOT)
    GL.Vertex(-RECT_SIZE/3.0,-RECT_SIZE,FLOOT)
    GL.Vertex( RECT_SIZE/3.0, RECT_SIZE,FLOOT)
    GL.Vertex( RECT_SIZE/3.0,-RECT_SIZE,FLOOT)
    GL.Vertex( RECT_SIZE,-RECT_SIZE/3.0,FLOOT)
    GL.Vertex(-RECT_SIZE,-RECT_SIZE/3.0,FLOOT)
    GL.Vertex( RECT_SIZE, RECT_SIZE/3.0,FLOOT)
    GL.Vertex(-RECT_SIZE, RECT_SIZE/3.0,FLOOT)
  GL.End()
  GL.Enable(GL::LIGHTING)

end


################# 面を６個あわせてキューブにする #################

def draw_cube(matrix,state)
  GL.LoadMatrix(matrix) ### 回転した状態の行列を読み込む。

  GL.PushMatrix()
  GL.Translate(0.0,0.0,RECT_SIZE)
  draw_rects(0,state[0],matrix)
  GL.PopMatrix()
  GL.PushMatrix()
  GL.Rotate(90,1.0,0.0,0.0)
  GL.Translate(0.0,0.0,RECT_SIZE)
  draw_rects(1,state[1],matrix)
  GL.PopMatrix()
  GL.PushMatrix()
  GL.Rotate(180,1.0,0.0,0.0)
  GL.Translate(0.0,0.0,RECT_SIZE)
  draw_rects(2,state[2],matrix)
  GL.PopMatrix()
  GL.PushMatrix()
  GL.Rotate(270,1.0,0.0,0.0)
  GL.Translate(0.0,0.0,RECT_SIZE)
  draw_rects(3,state[3],matrix)
  GL.PopMatrix()

  GL.PushMatrix()
  GL.Rotate(90,0.0,1.0,0.0)
  GL.Translate(0.0,0.0,RECT_SIZE)
  draw_rects(4,state[4],matrix)
  GL.PopMatrix()
  GL.PushMatrix()
  GL.Rotate(270,0.0,1.0,0.0)
  GL.Translate(0.0,0.0,RECT_SIZE)
  draw_rects(5,state[5],matrix)
  GL.PopMatrix()

  ## 六面体の辺
  GL.Disable(GL::LIGHTING)
  GL.Color(0,0,0)
  GL.Begin(GL::LINE_LOOP)
    GL.Vertex( RECT_SIZE, RECT_SIZE, RECT_SIZE+FLOOT)
    GL.Vertex( RECT_SIZE,-RECT_SIZE, RECT_SIZE+FLOOT)
    GL.Vertex(-RECT_SIZE,-RECT_SIZE, RECT_SIZE+FLOOT)
    GL.Vertex(-RECT_SIZE, RECT_SIZE, RECT_SIZE+FLOOT)
  GL.End()
  GL.Begin(GL::LINE_LOOP)
    GL.Vertex( RECT_SIZE, RECT_SIZE,-RECT_SIZE-FLOOT)
    GL.Vertex( RECT_SIZE,-RECT_SIZE,-RECT_SIZE-FLOOT)
    GL.Vertex(-RECT_SIZE,-RECT_SIZE,-RECT_SIZE-FLOOT)
    GL.Vertex(-RECT_SIZE, RECT_SIZE,-RECT_SIZE-FLOOT)
  GL.End()
  GL.Begin(GL::LINES)
    GL.Vertex( RECT_SIZE, RECT_SIZE+FLOOT, RECT_SIZE)
    GL.Vertex( RECT_SIZE, RECT_SIZE+FLOOT,-RECT_SIZE)

    GL.Vertex( RECT_SIZE,-RECT_SIZE-FLOOT, RECT_SIZE)
    GL.Vertex( RECT_SIZE,-RECT_SIZE-FLOOT,-RECT_SIZE)

    GL.Vertex(-RECT_SIZE,-RECT_SIZE-FLOOT, RECT_SIZE)
    GL.Vertex(-RECT_SIZE,-RECT_SIZE-FLOOT,-RECT_SIZE)

    GL.Vertex(-RECT_SIZE, RECT_SIZE+FLOOT, RECT_SIZE)
    GL.Vertex(-RECT_SIZE, RECT_SIZE+FLOOT,-RECT_SIZE)
  GL.End()
  GL.Enable(GL::LIGHTING)
end

################## レベル表示 #################################
DIGIT_SIZE = SEG_LENGTH + 2*SEG_WIDTH
def draw_level(x,y,level) # x,y : 数字の左上座標
  GL.PushMatrix()
  GL.LoadIdentity()
  GL.Disable(GL::LIGHTING)
    GL.Translate(x,y,RECT_SIZE)
    make_number( (level%100)/10 ,0,0) if (level%100)/10 != 0
    make_number(  level%10 ,DIGIT_SIZE,0)
  GL.Enable(GL::LIGHTING)
  GL.PopMatrix()
end

################## 現在指定中の面を表示 ########################
Pi = Math::PI

CORNER = [
    Vector[ RECT_SIZE, RECT_SIZE, RECT_SIZE,0],
    Vector[ RECT_SIZE,-RECT_SIZE, RECT_SIZE,0],
    Vector[-RECT_SIZE,-RECT_SIZE, RECT_SIZE,0],
    Vector[-RECT_SIZE, RECT_SIZE, RECT_SIZE,0]
]
ROTATE = [
  [  0,  0],
  [  0, 90],
  [  0,180],
  [  0,270],
  [ 90,  0],
  [270,  0]
]
#################### マウスクリックの判定関数 ###############################
def touch?(x,y,matrix)
  # point : マウスポインタの座標を内部座標系に修正
  point = Vector[(x-$display_x/2)/DISPLAY*2*EDGE,-(y-$display_y/2)/DISPLAY*2*EDGE,0,0]
  # front : 今どの面が前を向いているかを３つ取り出す。
  front = Array.new
  matrix.t.column(0)[2] > 0 ? front << 4 : front << 5
  matrix.t.column(1)[2] > 0 ? front << 3 : front << 1
  matrix.t.column(2)[2] > 0 ? front << 0 : front << 2

  front.each do |n|
    # corner : その面の四隅の現在位置をシミュレート
    corner = Array.new
    CORNER.each { |vector| corner << matrix.t*vector.rotate(ROTATE[n][0],ROTATE[n][1]) }
    # v_1,v_2 : 2の点を始点とするベクトル。2の位置は１番パネルの左下に当たる。
    v_1 = corner[1]-corner[2]
    v_2 = corner[3]-corner[2]
    # pt : pointを2の点を始点に変更
    pt = point - corner[2]
    # t : pt のx,y座標によるベクトルをv_1,v_2の２つのベクトルに分解したときの係数配列（ベクトル）。
    t = Matrix[ [v_1[0],v_2[0]] , [v_1[1],v_2[1]] ].inverse * Vector[pt[0],pt[1]]
    # 係数がどちらも 0< t < 1 を満たしていれば内部にあると判断し、係数を1/3ごとに区切って
    # 押している番号を決定する。
    if t[0] < 1 && t[1] < 1 && t[0] > 0 && t[1] > 0
      k = 1.0/3.0
      key = (t[0]/k).floor
      key += (t[1]/k).floor*3
      return [n,key]
    end
  end
  # どの面も押されていないと判断する場合、motionが起動し回転できる。
  return false
end
########################### ランプを一つ指定して変化させる ######################
def change(number,key,state)
  state[number][key] = (state[number][key]+1)%2
end

############# ランプの連鎖変化のパターン ################################
def chain(number,key,state)
  #まずはその位置を変える。
  change(number,key,state)
  #次に、押されたキーに応じて隣接部分を割り当てる。
  case key
  when 0 ################################################### 1
    change(number,1,state)
    change(number,3,state)
    case number
    when 0
      change(1,6,state)
      change(5,2,state)
    when 1
      change(2,6,state)
      change(5,0,state)
    when 2
      change(3,6,state)
      change(5,6,state)
    when 3
      change(0,6,state)
      change(5,8,state)
    when 4
      change(0,2,state)
      change(1,8,state)
    when 5
      change(1,0,state)
      change(2,6,state)
    end
  when 1 ################################################### 2
    change(number,0,state)
    change(number,2,state)
    change(number,4,state)
    case number
    when 0
      change(1,7,state)
    when 1
      change(2,7,state)
    when 2
      change(3,7,state)
    when 3
      change(0,7,state)
    when 4
      change(1,5,state)
    when 5
      change(1,3,state)
    end
  when 2 ################################################### 3
    change(number,1,state)
    change(number,5,state)
    case number
    when 0
      change(1,8,state)
      change(4,0,state)
    when 1
      change(2,8,state)
      change(4,2,state)
    when 2
      change(3,8,state)
      change(4,8,state)
    when 3
      change(0,8,state)
      change(4,6,state)
    when 4
      change(1,2,state)
      change(2,8,state)
    when 5
      change(0,0,state)
      change(1,6,state)
    end
  when 3  ################################################### 4
    change(number,0,state)
    change(number,4,state)
    change(number,6,state)
    case number
    when 0
      change(5,5,state)
    when 1
      change(5,1,state)
    when 2
      change(5,3,state)
    when 3
      change(5,7,state)
    when 4
      change(0,5,state)
    when 5
      change(2,3,state)
    end
  when 4 ################################################### 5
    change(number,1,state)
    change(number,3,state)
    change(number,5,state)
    change(number,7,state)
  when 5 ################################################### 6
    change(number,2,state)
    change(number,4,state)
    change(number,8,state)
    case number
    when 0
      change(4,3,state)
    when 1
      change(4,1,state)
    when 2
      change(4,5,state)
    when 3
      change(4,7,state)
    when 4
      change(2,5,state)
    when 5
      change(0,3,state)
    end
  when 6 ################################################### 7
    change(number,3,state)
    change(number,7,state)
    case number
    when 0
      change(3,0,state)
      change(5,8,state)
    when 1
      change(0,0,state)
      change(5,2,state)
    when 2
      change(1,0,state)
      change(5,0,state)
    when 3
      change(2,0,state)
      change(5,6,state)
    when 4
      change(0,8,state)
      change(3,2,state)
    when 5
      change(2,0,state)
      change(3,6,state)
    end
  when 7 ################################################### 8
    change(number,4,state)
    change(number,6,state)
    change(number,8,state)
    case number
    when 0
      change(3,1,state)
    when 1
      change(0,1,state)
    when 2
      change(1,1,state)
    when 3
      change(2,1,state)
    when 4
      change(3,5,state)
    when 5
      change(3,3,state)
    end
  when 8 ################################################### 9
    change(number,5,state)
    change(number,7,state)
    case number
    when 0
      change(3,2,state)
      change(4,6,state)
    when 1
      change(0,2,state)
      change(4,0,state)
    when 2
      change(1,2,state)
      change(4,2,state)
    when 3
      change(2,2,state)
      change(4,8,state)
    when 4
      change(3,8,state)
      change(2,2,state)
    when 5
      change(0,6,state)
      change(3,0,state)
    end
  end
end

#################### レベル変更用の関数 ##################
def level_next(level,level_array,state)
  if state.to_s.include?("0")
    state.each { |rect|
      rect.fill(1)
    }
  else
    level += 1
    level_array.clear
    level.times {
      level_array << [rand(6),rand(9)]
    }
    level_array.uniq!
    while level_array.size < level
      level_array << [rand(6),rand(9)]
      level_array.uniq!
    end
  end
  level_array.each { |array|
    chain(array[0],array[1],state)
  }
  return level
end



################## 状態変数 #########################
__theta = 0                     # x方向の傾き
__phi = 0                       # y方向の傾き
tmp_x = 0                       # モーション用変数
tmp_y = 0                       # モーション用変数
level = 3                       # レベル用の変数
count = level                   # カウンタ用の変数
matrix_now = Matrix.I(4).rotate(45,45)  # MotionFuncがnilの時の回転状態行列

undo_buff = Array.new           # undo操作用の履歴保存配列

##    各面の状態(初期状態は全て1)
__state = Array.new(6)
6.times do |i|
  __state[i] = Array.new(9,1)
end

level_array = Array.new
count = level = level_next(level,level_array,__state)


####################################################################################
############################ 定義はここまで、以下コールバック#######################
####################################################################################

#### 描画コールバック ########
display = Proc.new {
  GL.Clear(GL::COLOR_BUFFER_BIT|GL::DEPTH_BUFFER_BIT)
  GL.PushMatrix()
  draw_cube(matrix_now.rotate(__theta,__phi),__state)
  GL.Color(0.3,0.3,0)
  draw_level(EDGE-2*DIGIT_SIZE,EDGE,count)
  GL.Color(0,0.3,0.3)
  draw_level(-EDGE,EDGE,level)
  GL.PopMatrix()

  GLUT.SwapBuffers()

  if count == 0
    exit 0 if level > 54
    sleep 1
    level = level_next(level,level_array,__state)
    count = level
    undo_buff.clear
    GLUT.PostRedisplay()
  end
}

#### アイドルコールバック ########
idle = Proc.new {
  GLUT.PostRedisplay()
}

#### マウスモーションコールバック #######
motion = Proc.new { |x,y|
  __theta = (__theta + (x-tmp_x)/3.0) % 360
  __phi = (__phi + (y-tmp_y)/3.0) % 360
  tmp_x = x
  tmp_y = y
  GLUT.PostRedisplay()
}

#### マウス入力コールバック #######
mouse = Proc.new { |button,state,x,y|
  if button == GLUT::LEFT_BUTTON && state == GLUT::DOWN
    tmp_x = x
    tmp_y = y
    if ary = touch?(x,y,matrix_now)
      GLUT.MotionFunc(nil)
      chain(ary[0],ary[1],__state)
      undo_buff << ary.dup
      count -= 1
    end
  elsif button == GLUT::LEFT_BUTTON && state == GLUT::UP
    matrix_now = matrix_now.rotate(__theta,__phi)
    __theta = __phi = 0
    GLUT.MotionFunc(motion)
  end
  GLUT.PostRedisplay()
}


#### ウインドウサイズ変更コールバック ########
reshape = Proc.new { |w,h|
  GL.Viewport(0,0,w,h)
  $display_x = w ; $display_y = h
  # 投影変換の(再)設定
  GL.MatrixMode(GL::PROJECTION)
  GL.LoadIdentity()
  u = w/DISPLAY
  v = h/DISPLAY
  GL.Ortho(u*LEFT,u*RIGHT,v*BOTTOM,v*TOP,NEAR,FAR) # 平行投影

  GL.MatrixMode(GL::MODELVIEW)
  # カメラの(再)配置
  GL.LoadIdentity()
  GLU.LookAt(0.0,0.0,EYE_P,0.0,0.0,0.0,0.0,1.0,0.0)

  GLUT.PostRedisplay()
}

##################### ポップアップメニューコールバック ######
menu = Proc.new { |value|
  case value
  when 1
    unless undo_buff.empty?
      chain(undo_buff[-1][0],undo_buff[-1][1],__state)
      undo_buff.delete_at(-1)
      count += 1
    end
  when 2
    count = 0
  when 11
    if level < 54
      __state.each { |rect|
        rect.fill(1)
      }
      count = level = level_next(level,level_array,__state)
    end
  when 12
    __state.each { |rect|
      rect.fill(1)
    }
    count = level = level_next(level-2,level_array,__state)
  when 999
    exit 0
  end

  GLUT.PostRedisplay()
}

# シェーディングの設定
def init_shading()
  # 光源の環境光，拡散，鏡面成分と位置の設定
  GL.Light(GL::LIGHT0,GL::AMBIENT, [0.1,0.1,0.1])
  GL.Light(GL::LIGHT0,GL::DIFFUSE, [1.0,1.0,1.0])
  GL.Light(GL::LIGHT0,GL::SPECULAR,[1.0,1.0,1.0])
  GL.Light(GL::LIGHT0,GL::POSITION,[0.0,0.0,1.0,0.0]) # 無限遠の光源(平行光線)

  # シェーディング処理ON,光源(No.0)の配置
  GL.Enable(GL::LIGHTING)
  GL.Enable(GL::LIGHT0)
end


##############################################
# main
##############################################
GLUT.Init()
GLUT.InitDisplayMode(GLUT::RGB|GLUT::DOUBLE|GLUT::DEPTH)
GLUT.InitWindowSize(DISPLAY,DISPLAY)
GLUT.InitWindowPosition(300,200)
GLUT.CreateWindow("Touch! Fiver on Cube")
GLUT.DisplayFunc(display)
GLUT.ReshapeFunc(reshape)
GLUT.MouseFunc(mouse)
GLUT.MotionFunc(motion)
#GLUT.IdleFunc(idle)
# メニュー設定
sub = GLUT.CreateMenu(menu)
  GLUT.AddMenuEntry("次のレベル",11)
  GLUT.AddMenuEntry("前のレベル",12)
GLUT.CreateMenu(menu)
  GLUT.AddMenuEntry("一手戻る",1)
  GLUT.AddMenuEntry("最初から",2)
  GLUT.AddSubMenu("レベルメニュー",sub)
  GLUT.AddMenuEntry("終了",999)
  GLUT.AttachMenu(GLUT::RIGHT_BUTTON)

GL.Enable(GL::DEPTH_TEST)
init_shading()
GL.ClearColor(0.3,0.5,0.8,0.0)
GLUT.MainLoop()
