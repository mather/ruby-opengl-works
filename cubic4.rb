=begin
立体４並べ 一人遊びバージョン。ver.0.3
=end

version = 0.3

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

######### 回転行列の準備 ############
Pi = Math::PI

class Matrix
  def rotate(theta,phi)
    return self *  Matrix[
      [1 , 0                    , 0                    , 0 ],
      [0 , Math.cos(phi*Pi/180) , Math.sin(phi*Pi/180) , 0 ],
      [0 ,-Math.sin(phi*Pi/180) , Math.cos(phi*Pi/180) , 0 ],
      [0 , 0                    , 0                    , 1 ]
    ]*Matrix[
      [ Math.cos(theta*Pi/180) ,-Math.sin(theta*Pi/180) , 0 , 0 ],
      [ Math.sin(theta*Pi/180) , Math.cos(theta*Pi/180) , 0 , 0 ],
      [ 0                      , 0                      , 1 , 0 ],
      [ 0                      , 0                      , 0 , 1 ]
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

################### Field Class ###################

class Field
  CORNER = [
    Vector[ RECT_SIZE, RECT_SIZE, RECT_SIZE,0],
    Vector[ RECT_SIZE,-RECT_SIZE, RECT_SIZE,0],
    Vector[-RECT_SIZE,-RECT_SIZE, RECT_SIZE,0],
    Vector[-RECT_SIZE, RECT_SIZE, RECT_SIZE,0]
  ]
  
  
  def initialize
    # 石の配置
    @stones = Array.new(64).map!{ Stone.new }
    # 手順記録
    @sequances = []
    # 初期化時間
    @time = Time.now
    # 黒から
    @color = 1
    @select = nil
    @matrix = Matrix.I(4).rotate(0,-70)
  end
  
  def drop_area?(x,y)
    # point : マウスポインタの座標を内部座標系に修正
    point = Vector[(x-$display_x/2)/DISPLAY*2*EDGE,-(y-$display_y/2)/DISPLAY*2*EDGE,0,0]
  
    # corner : 上の面の四隅の現在位置をシミュレート
    corner = Array.new
    CORNER.each { |vector| corner << @matrix.t*vector }
    # v_1,v_2 : 2の点を始点とするベクトル。2の位置は１番パネルの左下に当たる。
    v_1 = corner[1]-corner[2]
    v_2 = corner[3]-corner[2]
    # pt : pointを2の点を始点に変更
    pt = point - corner[2]
    # t : pt のx,y座標によるベクトルをv_1,v_2の２つのベクトルに分解したときの係数配列（ベクトル）。
    t = Matrix[ [v_1[0],v_2[0]] , [v_1[1],v_2[1]] ].inverse * Vector[pt[0],pt[1]]
    # 係数がどちらも 0< t < 1 を満たしていれば内部にあると判断し、係数を1/4ごとに区切って
    # 押している番号を決定する。
    if t[0] < 1 && t[1] < 1 && t[0] > 0 && t[1] > 0
      k = 1.0/4.0
      m = (t[0]/k).floor
      n = (t[1]/k).floor
      return [m,n]
    end
    # 押されていないと判断する場合、motionが起動し回転できる。
    return nil
  end

  def drop(m,n)
    4.times do |i|
      if @stones[16*m+4*n+i].color != 0
        next
      else
        @sequances.push([m,n])
        @stones[16*m+4*n+i].coloring(@color,@sequances.size)
        @color *= -1
        judge(m,n,i)
        break
      end
    end
  end

  def back
    if @sequances.size > 0
      @sequances.pop
      @stones.each { |s| s.back_to(@sequances.size) }
      @color *= -1
    end
  end
  
  def draw
    #全体のシェーディング設定
    GL.Material(GL::FRONT_AND_BACK,GL::SPECULAR, [0.0,0.0,0.0])
    GL.Material(GL::FRONT_AND_BACK,GL::SHININESS,100)
    
    GL.LoadMatrix(@matrix)
    
    # 台
    GL.PushMatrix()
      GL.Normal(0.0,0.0,1.0)
      GL.Material(GL::FRONT_AND_BACK,GL::AMBIENT,  [0.8,0.8,0.0]) #パネルの色、シェーディング指定
      GL.Material(GL::FRONT_AND_BACK,GL::DIFFUSE,  [0.8,0.5,0.2]) #
      
      GL.Translate(0.0,0.0,-RECT_SIZE*1.1)
      GL.Scale(2*RECT_SIZE,2*RECT_SIZE,RECT_SIZE*0.1)
      
      GLUT.SolidCube(1.0)
      
    GL.PopMatrix()
    
    # 投下領域
    GL.Disable(GL::LIGHTING)
    GL.Begin(GL::LINES)
      GL.Color(0.8,0.8,0.8)
      5.times do |i|
        GL.Vertex(-RECT_SIZE,-RECT_SIZE+i*RECT_SIZE/2, RECT_SIZE)
        GL.Vertex( RECT_SIZE,-RECT_SIZE+i*RECT_SIZE/2, RECT_SIZE)
        GL.Vertex(-RECT_SIZE+i*RECT_SIZE/2,-RECT_SIZE, RECT_SIZE)
        GL.Vertex(-RECT_SIZE+i*RECT_SIZE/2, RECT_SIZE, RECT_SIZE)
      end
    GL.End()
    GL.Enable(GL::LIGHTING)
    
    
    
    ############### 柱と玉
    
    4.times do |i|
      4.times do |j|
        GL.PushMatrix()
        GL.Translate(RECT_SIZE*(-0.75+0.5*i),RECT_SIZE*(-0.75+0.5*j),0)
        if @select == [i,j]
          GL.Disable(GL::LIGHTING)
          GL.Color(0.0,0.0,0.0) 
          GL.Begin(GL::LINES)
          GL.Vertex(0,0,-RECT_SIZE)
          GL.Vertex(0,0, RECT_SIZE)
          GL.End()
          GL.Enable(GL::LIGHTING)
        end
        GL.Translate(0,0,RECT_SIZE*(-0.75))
        4.times { |k| 
          @stones[16*i+4*j+k].draw
          GL.Translate(0,0,RECT_SIZE/2)
        }
        GL.PopMatrix()
      end
    end
    
    
  end

  def judge(i,j,k)
    tmp = 16*i + 4*j
    if @stones.add_color(tmp,tmp+1,tmp+2,tmp+3).abs == 4 then @stones.full(@sequances.size,tmp,tmp+1,tmp+2,tmp+3) end
    tmp = 16*i + k
    if @stones.add_color(tmp,tmp+1*4,tmp+2*4,tmp+3*4).abs == 4 then @stones.full(@sequances.size,tmp,tmp+1*4,tmp+2*4,tmp+3*4) end
    tmp = 4*j + k
    if @stones.add_color(tmp,tmp+1*16,tmp+2*16,tmp+3*16).abs == 4 then @stones.full(@sequances.size,tmp,tmp+1*16,tmp+2*16,tmp+3*16) end
    
    if i == j # 平面の対角
      if @stones.add_color(k,k+1*20,k+2*20,k+3*20).abs == 4 then @stones.full(@sequances.size,k,k+1*20,k+2*20,k+3*20) end
      if i == k # 立方体の対角
        if @stones.add_color(0,1*21,2*21,3*21).abs == 4 then @stones.full(@sequances.size,0,1*21,2*21,3*21) end
      elsif i == (3 - k)
        if @stones.add_color(3,3+1*19,3+2*19,3+3*19).abs == 4 then @stones.full(@sequances.size,3,3+1*19,3+2*19,3+3*19) end
      end
    elsif i == (3 - j) # 平面の対角
      if @stones.add_color(k+12,k+12+1*12,k+12+2*12,k+12+3*12).abs == 4 then @stones.full(@sequances.size,k+12,k+12+1*12,k+12+2*12,k+12+3*12) end
      if i == k # 立方体の対角
        if @stones.add_color(12,12+1*13,12+2*13,12+3*13).abs == 4 then @stones.full(@sequances.size,12,12+1*13,12+2*13,12+3*13) end
      elsif i == (3 - k)
        if @stones.add_color(15,15+1*11,15+2*11,15+3*11).abs == 4 then @stones.full(@sequances.size,15,15+1*11,15+2*11,15+3*11) end
      end
    end
    
    if i == k # 平面の対角
      if @stones.add_color(4*j,4*j+1*17,4*j+2*17,4*j+3*17).abs == 4 then @stones.full(@sequances.size,4*j,4*j+1*17,4*j+2*17,4*j+3*17) end
    elsif i == (3-k) # 平面の対角
      if @stones.add_color(4*j+3,4*j+3+1*15,4*j+3+2*15,4*j+3+3*15).abs == 4 then @stones.full(@sequances.size,4*j+3,4*j+3+1*15,4*j+3+2*15,4*j+3+3*15) end
    end
    if j == k # 平面の対角
      if @stones.add_color(16*i,16*i+1*5,16*i+2*5,16*i+3*5).abs == 4 then @stones.full(@sequances.size,16*i,16*i+1*5,16*i+2*5,16*i+3*5) end
    elsif j == (3-k) # 平面の対角
      if @stones.add_color(16*i+3,16*i+3+1*3,16*i+3+2*3,16*i+3+3*3).abs == 4 then @stones.full(@sequances.size,16*i+3,16*i+3+1*3,16*i+3+2*3,16*i+3+3*3) end
    end
    
  end
  
  def select(sel)
    @select = sel
  end
  
  def rotate(theta,phi)
    @matrix = Matrix.I(4).rotate(-theta,0).rotate(0,-(70+phi))
  end
  
  def to_coord(x,y,z)
    return [RECT_SIZE*(-0.75+0.5*x),RECT_SIZE*(-0.75+0.5*y),RECT_SIZE*(-0.75+0.5*z)]
  end
  private :to_coord
end # class Field

class Stone
  attr_reader :color
  
  def initialize
    @color = 0
    @color_time = nil
    @judgement = false
    @judgement_time = nil
  end
  
  def draw
    unless @color == 0
      GL.Material(GL::FRONT_AND_BACK,GL::AMBIENT,  [0.5,0.5,0.5])
      GL.Material(GL::FRONT_AND_BACK,GL::DIFFUSE,  [0.2,0.2,0.2])
      GL.Material(GL::FRONT_AND_BACK,GL::DIFFUSE,  [0.5,0.2,0.2]) if @judgement
      if @color == -1
        GL.Material(GL::FRONT_AND_BACK,GL::DIFFUSE,  [1.0,1.0,1.0])
        GL.Material(GL::FRONT_AND_BACK,GL::DIFFUSE,  [1.0,0.7,0.7]) if @judgement
      end
      GL.Material(GL::FRONT_AND_BACK,GL::SPECULAR, [1.0,1.0,1.0])
      
      GLUT.SolidSphere(RECT_SIZE/5,20,10)

    end
  end
  def coloring(c,time)
    @color = c
    @color_time = time
  end
    
  def full(time)
    @judgement = true
    @judgement_time = time unless @judgement_time
  end
  
  def back_to(time)
    if @judgement_time.to_i > time
      @judgement = false
      @judgement_time = nil
    end
    if @color_time.to_i > time
      @color = 0
      @color_time = nil
    end
  end
end

# 今回専用の配列機能
class Array
  def add_color(*num)
    sum = 0
    num.each { |i| sum += self[i].color }
    return sum
  end
  def full(time,*num)
    num.each { |i| self[i].full(time) }
    return nil
  end
end


######### 状態変数 #########
__theta = 30    # x方向の傾き
__phi = 0       # y方向の傾き
tmp_x = 0       # モーション用変数
tmp_y = 0       # モーション用変数

####################################################################################
############################ 定義はここまで、以下コールバック#######################
####################################################################################


# Field 生成
field = Field.new
field.rotate(__theta,__phi)
#### 描画コールバック ########
display = Proc.new {
  GL.Clear(GL::COLOR_BUFFER_BIT|GL::DEPTH_BUFFER_BIT)
  GL.PushMatrix()
  field.draw
  GL.PopMatrix()
  
  GLUT.SwapBuffers()
}

#### アイドルコールバック ########
idle = Proc.new {
  #GLUT.PostRedisplay()
}

#### マウスモーションコールバック #######
motion = Proc.new { |x,y|
  __theta = (__theta + (x-tmp_x)) % 360
  __phi = (__phi - (y-tmp_y)/3.0) 
  __phi = 10 if __phi > 10
  __phi = -70 if __phi < -70
  tmp_x = x
  tmp_y = y
  field.rotate(__theta,__phi)
  GLUT.PostRedisplay()
}

#### パッシブモーションコールバック #####
pmotion = Proc.new { |x,y|
  field.select(field.drop_area?(x,y))
  GLUT.PostRedisplay()
}


#### マウス入力コールバック #######
mouse = Proc.new { |button,state,x,y|
  if button == GLUT::LEFT_BUTTON && state == GLUT::DOWN
    tmp_x = x
    tmp_y = y
    if ary = field.drop_area?(x,y)
      GLUT.MotionFunc(nil)
      field.drop(*ary)
    end
  elsif button == GLUT::LEFT_BUTTON && state == GLUT::UP
    field.rotate(__theta,__phi)
    GLUT.MotionFunc(motion)
  end
  GLUT.PostRedisplay()
}

#### キーボードコールバック ###############
keyboard = Proc.new { |key,x,y|
  case key
  when ?q
    exit 0
  when ?b
    field.back
  when ?n
    __theta = 30 ; __phi = 0
    field = Field.new
    field.rotate(__theta,__phi)
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
  GLU.LookAt(0.0,-EYE_P,EYE_P,0.0,0.0,0.0,0.0,1.0,0.0)

  GLUT.PostRedisplay()
}

##################### ポップアップメニューコールバック ######
menu = Proc.new { |value|
  case value
  when 1
    field.back
  when 2
    __theta = 30 ; __phi = 0
    field = Field.new
    field.rotate(__theta,__phi)
  else
    exit 0
  end
  GLUT.PostRedisplay()
}

################## シェーディングの設定
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
GLUT.CreateWindow("Cubic4 ver.#{version}")
GLUT.DisplayFunc(display)
GLUT.ReshapeFunc(reshape)
GLUT.MouseFunc(mouse)
GLUT.MotionFunc(motion)
GLUT.PassiveMotionFunc(pmotion)
GLUT.KeyboardFunc(keyboard)
#GLUT.IdleFunc(idle)
#メニュー設定
GLUT.CreateMenu(menu)
  GLUT.AddMenuEntry("一手戻る",1)
  GLUT.AddMenuEntry("最初から",2)
#  GLUT.AddSubMenu("レベルメニュー",sub)
  GLUT.AddMenuEntry("終了",999)
  GLUT.AttachMenu(GLUT::RIGHT_BUTTON)

GL.Enable(GL::DEPTH_TEST)
init_shading()
GL.ClearColor(0.3,0.5,0.8,0.0)
GLUT.MainLoop()

