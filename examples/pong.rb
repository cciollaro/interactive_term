$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/../lib")
require 'interactive_term'

class Paddle < InteractiveTerm::Sprite
  def initialize(x, y)
    bitmap = [
      "┏┓",
      "┃┃",
      "┗┛"
    ]
    super(x, y, bitmap)

    @height = 3
    @width = 2
  end
 
  def up
    self.y -= 1
    self.y = 1 if self.y < 1
  end

  def down
    self.y += 1
    self.y = @screen_height - @height - 1 if self.y > @screen_height - @height - 1
  end
end

class Ball < InteractiveTerm::Sprite
  attr_reader :width, :height
  def initialize(x, y, *paddles)
    bitmap = [
      "┏┓",
      "┗┛"
    ]
    @vel_x = 1
    @vel_y = 1

    @width = @height = 2
    
    super(x, y, bitmap)
  end

  def step!
    self.x += @vel_x
    self.y += @vel_y
  end

  def bounce!(dir)
    if dir == :horizontal
      @vel_x = 0 - @vel_x
    elsif dir == :vertical
      @vel_y = 0 - @vel_y
    end
  end
end

@interactive_term = InteractiveTerm::Term.new(true)
@interactive_term.debug!

@paddle = Paddle.new(1, 1)
@ball = Ball.new(@interactive_term.width/2, @interactive_term.height/2)
@my_score_view = InteractiveTerm::Sprite.new(@interactive_term.width/2 - 5, 10, ["0"])
@opp_score_view = InteractiveTerm::Sprite.new(@interactive_term.width/2 + 5, 10, ["0"])

@interactive_term.screen.add_sprite(@paddle)
@interactive_term.screen.add_sprite(@ball)

@interactive_term.register_listener do |key|
  if key == 'k'
    @paddle.up
  elsif key == 'j'
    @paddle.down
  end
end

@my_points = 0
@opp_points = 0

# keeps looping until either @interactive_term.end_session, @interactive_term.break_loop is called, or ctrl+c is caught
# in this program, this is the game loop
@interactive_term.loop do  
  @ball.step!

  if @ball.x < 1 - @ball.width
    @opp_points += 1
    @opp_score_view.bitmap = [@opp_points.to_s]
    @ball.x = @interactive_term.width/2
    @ball.y = @interactie_term.height/2
  elsif @ball.x > @interactive_term.width - 1
    @my_points += 1
    @my_score_view.bitmap = [@my_points.to_s]
    @ball.x = @interactive_term.width/2
    @ball.y = @interactive_term.height/2
  elsif @ball.y < 1 || @ball.y > @interactive_term.height - @ball.height
    @ball.bounce!(:vertical)
  end

  if @my_points == 3 || @opp_points == 3
    @interactive_term.break_loop
  end
end

@interactive_term.end_session


puts "good game!"
