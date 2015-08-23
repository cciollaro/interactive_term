module InteractiveTerm
  class Screen
    attr_reader :sprites

    def initialize(width, height)
      @width = width
      @height = height

      @sprites = []

      @draw_mutex = Mutex.new
    end

    def add_sprite(sprite)
      sprite.set_screen_dimensions(@width, @height)
      @sprites << sprite
    end
   
    def need_redraw?
      @sprites.any?(&:needs_redraw?)
    end
   
    def update!
      @sprites.each do |sprite|
        sprite.deltas.each do |delta|
          self.draw(*delta)
        end
        sprite.drawn!
      end
    end
   
    def draw(char, x, y)
      return if x < 1 || x > @width - 1
      return if y < 1 || y > @height - 1
      @draw_mutex.synchronize do
        puts "\e[#{y};#{x}H#{char}"
      end
    end

    def cleanup
      @draw_mutex.unlock if @draw_mutex.locked?
      #TODO: might want to do a full clean up of screen here
    end
  end
end
