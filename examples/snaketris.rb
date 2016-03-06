$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/../lib")
require 'interactive_term'

module Snaketris
  GUTTER_WIDTH = 80
end

module Tetris
  module Down
		def down
			@y += 1
      @y = @screen_height - @height if @y > @screen_height - @height
		end		
	end	

	module MoveSideways
		def left
			@x -= 1
			@x = @gutter_left if @x < @gutter_left
		end

    def right
      @x += 1
      @x = @gutter_right - 1 if @x >= @gutter_right
    end
	end
end	

class PieceI < InteractiveTerm::Sprite
	include Tetris::Down
	include Tetris::MoveSideways

  attr_reader :width, :height
  def initialize(x, y, gutter_left, gutter_right)
    bitmap = [
      "#",
      "#",
      "#",
      "#"
    ]
    @width = 1
		@height = 4

		@gutter_left = gutter_left
		@gutter_right = gutter_right
    
    super(x, y, bitmap)
  end
end

class PieceSquare < InteractiveTerm::Sprite
	include Tetris::Down
	include Tetris::MoveSideways

  attr_reader :width, :height
  def initialize(x, y)
    bitmap = [
      "##",
      "##"
    ]
    @width = 2
		@height = 2
		
		@gutter_left = gutter_left
		@gutter_right = gutter_right
    
    super(x, y, bitmap)
  end
end

@interactive_term = InteractiveTerm::Term.new(true)
@interactive_term.debug!

@gutter_left = @interactive_term.width/2 - Snaketris::GUTTER_WIDTH/2
left_panel_bitmap = @interactive_term.height.times.map {|x| @gutter_left.times.map {|y| "#"}.join}
left_panel_sprite = InteractiveTerm::Sprite.new(0, 0, left_panel_bitmap)

@gutter_right = @gutter_left + Snaketris::GUTTER_WIDTH
right_panel_bitmap = @interactive_term.height.times.map {|x| (@interactive_term.width - @gutter_left - Snaketris::GUTTER_WIDTH).times.map {|y| "#"}.join}
right_panel_sprite = InteractiveTerm::Sprite.new(@gutter_right, 0, right_panel_bitmap)

def random_piece
	PieceI.new(@interactive_term.width/2, 0, @gutter_left, @gutter_right)
end	

@active_piece = random_piece
@interactive_term.screen.add_sprite(@active_piece)

@interactive_term.screen.add_sprite(left_panel_sprite)
@interactive_term.screen.add_sprite(right_panel_sprite)

@interactive_term.register_listener do |key|
  if key == 'h'
    @active_piece.left
  elsif key == 'l'
    @active_piece.right    
  end
end

@interactive_term.loop do  
	@active_piece.down
end

@interactive_term.end_session

puts "good game!"
