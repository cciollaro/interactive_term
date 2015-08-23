module InteractiveTerm
  class Sprite
    attr_reader :x, :y, :bitmap, :needs_redraw

    # bitmap is an array of strings. 
    # (x,y) is the position of the first character.
    # each string represents the next line.
    # newlines in bitmap is undefined behavior.
    def initialize(x, y, bitmap)
      @prev_x = @x = x
      @prev_y = @y = y
      @prev_bitmap = @bitmap = bitmap

      @needs_redraw = true
    end

    def x=(new_x)
      return if new_x == @x

      @x = new_x
      @needs_redraw = true
    end

    def y=(new_y)
      return if new_y == @y

      @y = new_y
      @needs_redraw = true
    end
   
    def bitmap=(new_bitmap)
      return if new_bitmap == @bitmap

      @prev_bitmap = @bitmap
      @bitmap = new_bitmap
      @needs_redraw = true
    end

    def deltas
      res = []
      
      # clearing spaces for old sprite
      Bitmap.iterate(@prev_bitmap) do |b_char, b_x, b_y|
        res << [" ", @prev_x + b_x, @prev_y + b_y]
      end

      # draw new sprite
      Bitmap.iterate(@bitmap) do |b_char, b_x, b_y|
        res << [b_char, @x + b_x, @y + b_y]
      end

      res
    end

    def drawn!
      @prev_x = @x
      @prev_y = @y
      @needs_redraw = false
    end

    def needs_redraw?
      @needs_redraw
    end

    def set_screen_dimensions(screen_width, screen_height)
      @screen_width = screen_width
      @screen_height = screen_height
    end
  end
end
