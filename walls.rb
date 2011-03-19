=begin
玉転がし 改め Walls version 1.0

今回からオブジェクト指向ってことで自分なりに書いてみようと思う．
まず，次のようなオブジェクトを考える．

 - Stage
 - Pin
 - Wall
 - Curve

Stageは一つのステージを表すオブジェクトで，障害物群@barriers配列に
Pin , Wall , Curveの障害オブジェクトを収納する．
Stageにはステージ作成機能が着いていて，pin,wall,curveをそれぞれ登録できるが，
wall,curveには実質pinが二つ必要なのでこれを自動挿入するように設定してある．

各障害オブジェクトにはオプション属性がある．
fake属性は表示のみの壁，見えない壁を作り出すのに用いる．
オブジェクトで管理するとこういうことがやりやすい．
ちなみに，自動生成されたpinは判定有りの非表示がデフォルトになっている．

壁の反射に関して．
各オブジェクトにhit?というメソッドを持たせて，判定させる．
返り値として，当たっていない場合はfalse，当たっている場合は反射方向のベクトルを
配列で返す．これを元に，反射した後のボール速度を計算するように統一する．

=end

######################## プログラムスタート ########################
require "opengl"
require "glut"

########## クラス定義

class Stage # ステージオブジェクト．障害物を格納する．
  DEG2RAD = Math::PI/180
  def initialize
    @start = nil
    @goal = nil
    @barriers = Array.new
    @ball_size = 0.3
    @wall_height = @ball_size * 2
    @ball_x = nil
    @ball_y = nil
    @speed_x = 0.0
    @speed_y = 0.0
    @theta = 0.0
    @phi = 0.0
    @stage_size = nil
    @reflec = 0.5
    @max_theta = [-45, 45]
    @max_phi = [-45, 45]
    @speed_rate = 0.1
  end
  
  # 初期設定 これをしないと進めない.
  def setting(start_x,start_y,goal_x,goal_y,stage_size = 4.0)
    @start = [start_x,start_y]
    @goal = [goal_x,goal_y]
    @ball_x = @start[0] ; @ball_y = @start[1]
    @stage_size = stage_size
    @barriers.push(Wall.new( @stage_size, @stage_size,-@stage_size, @stage_size,0))
    @barriers.push(Wall.new(-@stage_size, @stage_size,-@stage_size,-@stage_size,0))
    @barriers.push(Wall.new(-@stage_size,-@stage_size, @stage_size,-@stage_size,0))
    @barriers.push(Wall.new( @stage_size,-@stage_size, @stage_size, @stage_size,0))
    @barriers.push(Pin.new( @stage_size, @stage_size,2))
    @barriers.push(Pin.new(-@stage_size, @stage_size,2))
    @barriers.push(Pin.new(-@stage_size,-@stage_size,2))
    @barriers.push(Pin.new( @stage_size,-@stage_size,2))
  end
  
  # option
  def ball_size=(size)
    @ball_size = size
  end
  def wall_height=(height)
    @wall_height = height
  end
  
  def reflec=(reflec)
    @reflec = reflec
  end
  

  
  
  # makeメソッド ステージ作成に使う
  # fakeオプション
  #  0 : 壁
  #  1 : 偽の壁
  #  2 : 見えない壁
  
  def make_pin(x1,y1,fake = 0)
    @barriers.push(Pin.new(x1,y1,fake))
  end

  def make_wall(x1,y1,x2,y2,fake = 0)
    if x1 == x2 and y1 == y2
      @barriers.push(Pin.new(x1,y1,fake))
    else
      unless fake == 1
        @barriers.push(Pin.new(x1,y1,2))
        @barriers.push(Pin.new(x2,y2,2))
      end
      @barriers.push(Wall.new(x1,y1,x2,y2,fake))
    end
  end
  
  def make_curve(x1,y1,r,deg1,deg2,fake = 0)
    if r == 0 or deg1 == deg2
      @barriers.push( Pin.new(x1+r*Math.cos(deg1),y1+r*Math.sin(deg1),fake) )
    else
      unless fake == 1
        @barriers.push( Pin.new(x1+r*Math.cos(deg1*DEG2RAD),
                                y1+r*Math.sin(deg1*DEG2RAD),2) 
                        )
        @barriers.push( Pin.new(x1+r*Math.cos(deg2*DEG2RAD),
                                y1+r*Math.sin(deg2*DEG2RAD),2) 
                        )
      end
      @barriers.push(Curve.new(x1,y1,r,deg1,deg2,fake))
    end
  end

  # clean関数 : 壁の認識順をPinが後になるようにする
  # 理由はPinは反射が不安定だから．
  def clean
    max = @barriers.size ; n = 0
    max.times do 
      if @barriers[n].class == Pin
        pin = @barriers.delete_at(n)
        @barriers.push(pin)
        n -= 1
      end
      n += 1
    end
  end

  ### theta,phi変更用メソッド  基本的に操作はこれだけ．
  
  def theta
    @theta
  end
  def phi
    @phi
  end
  def theta=(deg)
    @theta = deg
  end
  def phi=(deg)
    @phi = deg
  end
  def max_theta
    @max_theta
  end
  def max_phi
    @max_phi
  end
  def max_theta=(max)
    @max_theta = max
  end
  def max_phi=(max)
    @max_phi = max
  end

  def next_stage=(stage)
    @next_stage = stage
  end
  
  # 全てはこのメソッドのために．
  def show
    # まず加速
    @speed_x += @speed_rate * Math.sin(@theta*DEG2RAD)
    @speed_y += @speed_rate * Math.sin(@phi*DEG2RAD)
    # 速度制限
    @speed_x = 2*@ball_size - 0.1 if @speed_x > 2*@ball_size
    @speed_x = -2*@ball_size + 0.1 if @speed_x < -2*@ball_size
    @speed_y = 2*@ball_size - 0.1 if @speed_y > 2*@ball_size
    @speed_y = -2*@ball_size + 0.1 if @speed_y < -2*@ball_size
    # 位置を変更
    @ball_x += @speed_x
    @ball_y += @speed_y
    
    # 接触判定
    double = false
    @barriers.each do |barrier|
      hits = barrier.hit?(@ball_x,@ball_y,@speed_x,@speed_y,@ball_size)
      if hits # 当たった場合
        # 一旦戻る
        while barrier.hit?(@ball_x,@ball_y,@speed_x,@speed_y,@ball_size)
          @ball_x -= @speed_x ; @ball_y -= @speed_y
        end
        # 速度を修正
        x,y = hits
        length = Math.sqrt(x**2 + y**2)
        speed = (@speed_x*x + @speed_y*y).abs / length
        @speed_x += x*speed*(1+@reflec) / length
        @speed_y += y*speed*(1+@reflec) / length
        # 速度制限
        @speed_x = 2*@ball_size - 0.1 if @speed_x > 2*@ball_size
        @speed_x = -2*@ball_size + 0.1 if @speed_x < -2*@ball_size
        @speed_y = 2*@ball_size - 0.1 if @speed_y > 2*@ball_size
        @speed_y = -2*@ball_size + 0.1 if @speed_y < -2*@ball_size
        # 再度ボールを移動
        unless double
          @ball_x += @speed_x ; @ball_y += @speed_y
        end
        double = true
        #p [@speed_x,@speed_y]
      end
    end
    # カメラを向き直す
    GL.LoadIdentity()
    GLU.LookAt(0.0,-EYE_P,EYE_P,0.0,0.0,0.0,0.0,1.0,0.0)

    GL.PushMatrix()
    GL.Rotate(@theta,0.0,1.0,0.0)
    GL.Rotate(@phi,-1.0,0.0,0.0)
    # 床
    GL.Material(GL::FRONT_AND_BACK,GL::AMBIENT,  [0.3,0.3,0.3])
    GL.Material(GL::FRONT_AND_BACK,GL::DIFFUSE,  [0.8,0.8,0.8])
    GL.Material(GL::FRONT_AND_BACK,GL::SPECULAR, [0.0,0.0,0.0])
    GL.Material(GL::FRONT_AND_BACK,GL::SHININESS,1.0)
    GL.Begin(GL::QUADS)
      GL.Normal(0.0,0.0,1.0)
      GL.Vertex( @stage_size, @stage_size,0.0)
      GL.Vertex(-@stage_size, @stage_size,0.0)
      GL.Vertex(-@stage_size,-@stage_size,0.0)
      GL.Vertex( @stage_size,-@stage_size,0.0)
    GL.End()
    
    # 障害
    GL.Material(GL::FRONT_AND_BACK,GL::AMBIENT,  [1.0,0.2,0.0])
    GL.Material(GL::FRONT_AND_BACK,GL::DIFFUSE,  [0.8,0.8,0.8])
    GL.Material(GL::FRONT_AND_BACK,GL::SPECULAR, [0.0,0.0,0.0])
    GL.Material(GL::FRONT_AND_BACK,GL::SHININESS,64.0)
    @barriers.each { |barrier| barrier.show(@wall_height) }
    
    # ゴール
    GL.Disable(GL::LIGHTING)
    GL.Begin(GL::TRIANGLE_FAN)
      GL.Color(0.0,0.0,0.0)
      GL.Vertex(@goal[0],@goal[1],0.05)
    73.times do |i|
      GL.Vertex(@goal[0]+@ball_size*Math.cos(5*i*DEG2RAD),
                @goal[1]+@ball_size*Math.sin(5*i*DEG2RAD),
                0.05)
    end
    GL.End()
    GL.Enable(GL::LIGHTING)
    
    # 玉
    GL.PushMatrix()
    GL.Translate(@ball_x,@ball_y,@ball_size)
    GL.Material(GL::FRONT_AND_BACK,GL::AMBIENT,  [0.5,1.0,0.0])
    GL.Material(GL::FRONT_AND_BACK,GL::DIFFUSE,  [0.3,0.3,0.3])
    GL.Material(GL::FRONT_AND_BACK,GL::SPECULAR, [0.0,0.0,0.0])
    GL.Material(GL::FRONT_AND_BACK,GL::SHININESS,64.0)
    GLUT.SolidSphere(@ball_size,20,20)
    GL.PopMatrix()
    
    GL.PopMatrix()
    
  end

  # ステージ終了処理
  # もう一度ステージを開始するときに，
  # これをしないとゴールした状態からスタートしてしまう．
  def reset
    @speed_x = @speed_y = 0.0
    @ball_x = @start[0] ; @ball_y = @start[1]
    @theta = @phi = 0.0
  end

  # ゴール処理
  def goal?
    if Math.sqrt( (@ball_x - @goal[0])**2 + (@ball_y - @goal[1])**2 ) < @ball_size/2.0
      goal_string(-2.0,0.5)
      GLUT.SwapBuffers()
      sleep(3)
      self.reset
      return @next_stage
    end
    return false
  end
    
end


## 障害物オブジェクト
#
#  Pin , Wall , Curve
#  それぞれ，ピン，壁，円周を指す
#  

class Pin
  def initialize(x1,y1,fake)
    @x = x1
    @y = y1
    @fake = fake
  end
  
  def show(height)
    unless @fake == 2
      GL.Color(0.0,0.0,0.0)
      GL.Begin(GL::LINES)
        GL.Vertex(@x,@y,0)
        GL.Vertex(@x,@y,height)
      GL.End()
    end
  end

  def hit?(ball_x,ball_y,speed_x,speed_y,ball_size)
    if @fake == 1
      return false
    else
      r = (ball_x - @x)**2 + (ball_y - @y)**2
      if r < ball_size**2
        vector = [ball_x - @x , ball_y - @y]
        return vector
      else
        return false
      end
    end
  end
  

# class Pin end
end

class Wall
  def initialize(x1,y1,x2,y2,fake)
    @x1 = x1 ; @y1 = y1
    @x2 = x2 ; @y2 = y2
    @fake = fake
  end

  def show(height)
    unless @fake == 2
      GL.Begin(GL::QUADS)
        GL.Vertex(@x1,@y1,0)
        GL.Vertex(@x2,@y2,0)
        GL.Vertex(@x2,@y2,height)
        GL.Vertex(@x1,@y1,height)
      GL.End()
    end
  end

  def hit?(ball_x,ball_y,speed_x,speed_y,ball_size)
    if @fake == 1
      return false
    else
      if !@matrix
        length = Math.sqrt( (@x2 - @x1)**2 + (@y2 - @y1)**2 )
        @n_vector=[-(@y2 - @y1)*ball_size/length , (@x2 - @x1)*ball_size/length]
        # ボールが壁に対してどの位置にあるかを，
        # 壁のベクトルと垂直方向のベクトルを用いて計算する．
        # そのための行列を初期段階で計算する．
        const = (@x2-@x1)*@n_vector[1] - @n_vector[0]*(@y2-@y1)
        @matrix = [[@n_vector[1]/const , -@n_vector[0]/const],
          [(@y1-@y2)/const , (@x2-@x1)/const]]
      end
      # a1 : 壁平行の成分 , a2 : 壁垂直の成分
      a1 = @matrix[0][0]*(ball_x - @x1) + @matrix[0][1]*(ball_y - @y1)
      a2 = @matrix[1][0]*(ball_x - @x1) + @matrix[1][1]*(ball_y - @y1)
      if ( 0 < a1 and a1 < 1 ) and ( -1 < a2 and a2 < 1 )
        s = @matrix[1][0]*speed_x + @matrix[1][1]*speed_y
        if s < 0
          return @n_vector
        else
          return [-@n_vector[0] , -@n_vector[1]]
        end
      end
    end
  end
end

class Curve
  DEG2RAD = Math::PI / 180
  def initialize(x1,y1,r,deg1,deg2,fake)
    @center_x = x1
    @center_y = y1
    @radius = r
    if deg1 < deg2
      @deg1 = deg1 ; @deg2 = deg2
    else
      @deg2 = deg1 ; @deg1 = deg2
    end
    @fake = fake
  end
  
  def show(height)
    unless @fake == 2
    GL.Begin(GL::QUAD_STRIP)
    GL.Vertex(@center_x + @radius*Math.cos(@deg1*DEG2RAD),@center_y + @radius*Math.sin(@deg1*DEG2RAD),0)
    GL.Vertex(@center_x + @radius*Math.cos(@deg1*DEG2RAD),@center_y + @radius*Math.sin(@deg1*DEG2RAD),height)
    deg = @deg1 + 3
    while deg < @deg2
      GL.Vertex(@center_x + @radius*Math.cos(deg*DEG2RAD),@center_y + @radius*Math.sin(deg*DEG2RAD),0)
      GL.Vertex(@center_x + @radius*Math.cos(deg*DEG2RAD),@center_y + @radius*Math.sin(deg*DEG2RAD),height)
      deg += 3
    end
    GL.Vertex(@center_x + @radius*Math.cos(@deg2*DEG2RAD),@center_y + @radius*Math.sin(@deg2*DEG2RAD),0)
    GL.Vertex(@center_x + @radius*Math.cos(@deg2*DEG2RAD),@center_y + @radius*Math.sin(@deg2*DEG2RAD),height)
    GL.End()
    end
  end

  def hit?(ball_x,ball_y,speed_x,speed_y,ball_size)

    return false if @fake == 1

    length = Math.sqrt((ball_x - @center_x)**2 + (ball_y - @center_y)**2)
    if (@radius - ball_size) < length and length < (@radius + ball_size)
      rad = Math.acos((ball_x - @center_x)/length)
      rad = Math::PI * 2 - rad if (ball_y - @center_y) < 0
      if @deg1*DEG2RAD < rad and rad < @deg2*DEG2RAD
        if (speed_x*Math.cos(rad) + speed_y*Math.sin(rad)) < 0
          return [Math.cos(rad),Math.sin(rad)]
        else
          return [-Math.cos(rad),-Math.sin(rad)]
        end
      end
    end
    
    return false
  end

end

######################## ファイル読み込み部分 ######################
stages = Array.new
stage = nil
if ARGV.size == 1
  open(ARGV[0]) do |file|
    file.readlines.each do |line|
      data_ary = line.scan(/-*\d+\.*\d*/).collect! { |data| data.to_f }
      case line[0]
      when ?%
        if stage
          stages << stage
        end
        stage = Stage.new
      when ?s
        if data_ary.size > 4
          stage.setting(data_ary[0],data_ary[1],data_ary[2],
                        data_ary[3],data_ary[4])
        else
          stage.setting(data_ary[0],data_ary[1],data_ary[2],data_ary[3])
        end
      when ?p # pin
        stage.make_pin(data_ary[0],data_ary[1],data_ary[2])
      when ?w # wall
        stage.make_wall(data_ary[0],data_ary[1],data_ary[2],
                        data_ary[3],data_ary[4])
      when ?c # curve
        stage.make_curve(data_ary[0],data_ary[1],data_ary[2],
                         data_ary[3],data_ary[4],data_ary[5])
      when ?b # ball_size
        stage.ball_size = data_ary[0]
      when ?h # height
        stage.wall_height = data_ary[0]
      when ?r # reflection
        stage.reflec = data_ary[0]
      when ?m # max_angle theta*2 , phi*2
        stage.max_theta = [data_ary[0],data_ary[1]]
        stage.max_phi = [data_ary[2],data_ary[3]]
      end
    end
    stages << stage
  end

else
  
  sample1 = Stage.new
  sample1.setting(3.0,-3.0,-3.0,-3.0,5.0)
  sample1.wall_height = 0.6
  sample1.ball_size = 0.5
  
  sample1.make_curve(0.0,0.0,5.0,0,180)
  #sample1.make_wall(3.0,0.0,-3.0,0.0,1)
  sample1.make_wall(3.0,-4.3,-3.0,-4.5)
  sample1.max_phi = [-20,20]
  stages << sample1
end

stages.each_with_index do |stage,num|
  stage.clean
  stage.next_stage = stages[(num+1)%stages.size]
end

stage_now = stages[0]
  

################### 定数 ###########################################

DT     = 0.1    # 回転角単位
EYE_P  = 2.0  # カメラの原点からの距離を決めるパラメタ
EDGE   = 4.0  # ビューボリュームを決めるベースパラメタ

# ビューボリュームのパラメタ(カメラ座標での記述)
LEFT   = -EDGE     # 左側面
RIGHT  = EDGE      # 右側面
BOTTOM = -EDGE     # 底面
TOP    = EDGE      # 上面
NEAR   = -2.0*EDGE # 前面
FAR    = 3.0*EDGE  # 後面

######################## スタート時の文字 ######################

def start_string(x,y)
  GL.PushMatrix()
  GL.LoadIdentity()
  GL.Disable(GL::LIGHTING)
  
  str_width = 0.3
  str_height = 0.5
  str = [
  [[0.0,0.0],[0.0,1.0],[1.0,1.0],[1.0,0.5],[0.0,0.5]],#P
  [[0.0,0.5],[0.0,0.0],[1.0,0.0],[1.0,0.5]],#u
  [[0.0,0.0],[1.0,0.0],[1.0,0.25],[0.0,0.25],[0.0,0.5],[1.0,0.5]],#s
  [[0.0,1.0],[0.0,0.0],[0.0,0.5],[1.0,0.5],[1.0,0.0]],#h
  [],#SPACE
  [[1.0,1.0],[0.5,1.0],[0.5,0.0],[1.0,0.0]],#[
  [[0.0,0.0],[1.0,0.0],[1.0,0.25],[0.0,0.25],[0.0,0.5],[1.0,0.5]],#s
  [[0.0,1.0],[0.5,1.0],[0.5,0.0],[0.0,0.0]],#]
  [],#SPACE
  [[0.0,0.5],[1.0,0.5],[0.5,0.5],[0.5,0.7],[0.5,0.0]],#t
  [[0.0,0.0],[0.0,0.5],[1.0,0.5],[1.0,0.0],[0.0,0.0]],#o
  [],#SPACE
  [[0.0,0.0],[1.0,0.0],[1.0,0.25],[0.0,0.25],[0.0,0.5],[1.0,0.5]],#s
  [[0.0,0.5],[1.0,0.5],[0.5,0.5],[0.5,0.7],[0.5,0.0]],#t
  [[1.0,0.0],[1.0,0.5],[0.0,0.5],[0.0,0.0],[0.6,0.0],[1.0,0.3]],#a
  [[0.0,0.5],[0.0,0.0],[0.0,0.2],[0.4,0.5],[1.0,0.5]],#r
  [[0.0,0.5],[1.0,0.5],[0.5,0.5],[0.5,0.7],[0.5,0.0]]#t
  ]
  n = 0
  str.each do |chara|
    GL.Begin(GL::LINE_STRIP)
      chara.each do |point|
        GL.Vertex(x+str_width*point[0]+n*(str_width+0.1),y+str_height*point[1])
      end
    GL.End()
    n += 1
  end
  
  GL.Enable(GL::LIGHTING)
  GL.PopMatrix()
end

################# ゴール時の文字 ##############################

def goal_string(x,y)
  GL.PushMatrix()
  GL.LoadIdentity()
  GL.Disable(GL::LIGHTING)
  
  str_width = 0.6
  str_height = 1.0
  str = [
  [[1.0,0.7],[1.0,1.0],[0.0,1.0],[0.0,0.0],[1.0,0.0],[1.0,0.5],[0.5,0.5]],#G
  [[0.0,0.0],[0.0,1.0],[1.0,1.0],[1.0,0.0],[0.0,0.0]],#O
  [[0.0,0.0],[0.5,1.0],[1.0,0.0],[0.8,0.4],[0.2,0.4]],#A
  [[0.0,1.0],[0.0,0.0],[1.0,0.0]] #L
  ]
  n = 0
  str.each do |chara|
    GL.Begin(GL::LINE_STRIP)
      chara.each do |point|
        GL.Vertex(x+str_width*point[0]+n*(str_width+0.2),y+str_height*point[1])
      end
    GL.End()
    n += 1
  end
  
  GL.Enable(GL::LIGHTING)
  GL.PopMatrix()
end




################## 状態変数 #######################################
tmp_x = 0                       # モーション用変数
tmp_y = 0                       # モーション用変数
__anime_on = false              # アニメーション表示

##################################################################
############## 定義はここまで。以下コールバック ##################
##################################################################

######################### 描画コールバック #####################3
display = Proc.new {
  GL.Clear(GL::COLOR_BUFFER_BIT|GL::DEPTH_BUFFER_BIT)
  
  start_string(-3.5,0.0) if __anime_on == false
  
  GL.PushMatrix()
  stage_now.show
  GL.PopMatrix()

  if (stage = stage_now.goal?)
    stage_now = stage
    __anime_on = false
  end
  
  GLUT.SwapBuffers()
}

#### アイドルコールバック ########
idle = Proc.new {
  GLUT.PostRedisplay()
}

#### マウス入力コールバック #######
mouse = Proc.new { |button,state,x,y|
  tmp_x = x
  tmp_y = y
}

#### マウスモーションコールバック #######
motion = Proc.new { |x,y|
  stage_now.theta = (stage_now.theta + (x-tmp_x)/3.0)
  stage_now.phi = (stage_now.phi - (y-tmp_y)/3.0)
  stage_now.theta = stage_now.max_theta[0] if stage_now.theta < stage_now.max_theta[0]
  stage_now.theta = stage_now.max_theta[1] if stage_now.theta > stage_now.max_theta[1]
  stage_now.phi = stage_now.max_phi[0] if stage_now.phi < stage_now.max_phi[0]
  stage_now.phi = stage_now.max_phi[1] if stage_now.phi > stage_now.max_phi[1]
  tmp_x = x
  tmp_y = y
}

#### ウインドウサイズ変更コールバック ########
reshape = Proc.new { |w,h|
  GL.Viewport(0,0,w,h)

  # 投影変換の(再)設定
  GL.MatrixMode(GL::PROJECTION)
  GL.LoadIdentity()
  u = w/300.0
  v = h/300.0
  GL.Ortho(u*LEFT,u*RIGHT,v*BOTTOM,v*TOP,NEAR,FAR) # 平行投影

  GL.MatrixMode(GL::MODELVIEW) 
  # カメラの(再)配置
  GL.LoadIdentity()
  GLU.LookAt(0.0,-EYE_P,EYE_P,0.0,0.0,0.0,0.0,1.0,0.0)

  GLUT.PostRedisplay()
}

#### キーボード入力コールバック ########
keyboard = Proc.new { |key,x,y| 
  case key
  when ?s
    if __anime_on
      GLUT.IdleFunc(nil)
      GLUT.MouseFunc(nil)
      GLUT.MotionFunc(nil)
      __anime_on = false
    else
      GLUT.IdleFunc(idle)
      GLUT.MouseFunc(mouse)
      GLUT.MotionFunc(motion)
      __anime_on = true
    end
  when ?S
    if __anime_on
      GLUT.IdleFunc(nil)
      GLUT.MouseFunc(nil)
      GLUT.MotionFunc(nil)
      __anime_on = false

      stage_now.reset
    else
      GLUT.IdleFunc(idle)
      GLUT.MouseFunc(mouse)
      GLUT.MotionFunc(motion)
      __anime_on = true
    end
  when ?r
    stage_now.reset
  when ?d
    p stage_now
  # [q],[ESC]: 終了する
  when ?q, 0x1b
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
  GL.Light(GL::LIGHT0,GL::POSITION,[0.0,1.0,1.0,100.0]) #無限遠の光源(平行光線)

  # シェーディング処理ON,光源(No.0)の配置
  GL.Enable(GL::LIGHTING)
  GL.Enable(GL::LIGHT0)
end

##############################################
# main
##############################################
GLUT.Init()
GLUT.InitDisplayMode(GLUT::RGB|GLUT::DOUBLE|GLUT::DEPTH)
GLUT.InitWindowSize(400,400) 
GLUT.InitWindowPosition(300,200)
GLUT.CreateWindow("BallBoy")
GLUT.DisplayFunc(display)
GLUT.KeyboardFunc(keyboard)
GLUT.ReshapeFunc(reshape)
GL.Enable(GL::DEPTH_TEST)
init_shading()
GL.ClearColor(0.2,0.2,0.5,0.0)
GLUT.MainLoop()

__END__
