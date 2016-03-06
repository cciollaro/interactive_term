require 'thread'
require 'io/console'

module InteractiveTerm
  class Term
		FPS = 15
    attr_reader :width, :height, :screen

    def initialize(start_session = false)
      @stty_state = @width = @height = @listener_thread = @session_active = @loop_active = nil
      @listeners = []
      @keypress_queue = Queue.new
      @height, @width = IO.console.winsize

      @screen = VirtualScreen.new(@width , @height)

      self.start_session if start_session
    end

    def register_listener(&block)
      @listeners << block
    end

    def start_session
      @session_active = true

      # switch to a new terminal context
      system('tput smcup')

      # hide the cursor
      puts "\e[?25l"

      # clear the screen
      puts "\e[H\e[2J"

      # store the stty state
      @stty_state = `stty -g`

      # raw: keypresses get passed along unprocessed
      # -echo: user doesn't see what they type
      # -icanon: no buffering/delay on keypress
      # isig: enable quit special character (necessary because of raw)
      `stty raw -echo -icanon isig`
      
      @lisen_thread = Thread.new do
        Thread.current.abort_on_exception = true
        loop do
          @keypress_queue.push $stdin.getc
        end
      end

      trap("SIGINT") do 
        self.end_session
      end
    end

    def loop(&block)
      @loop_active = true

      while @loop_active 
        # process up to 5 keypresses (should be fine because happens FPS times per second)
        begin
          5.times do
            keypress = @keypress_queue.pop(true) #nonblock
            @listeners.each {|listener| listener.call(keypress)} if keypress
						@keypress_queue = Queue.new
          end
        rescue ThreadError # nothing to pop
        end
          
        # run loop code
        yield

        @screen.update!
        
        sleep 1.0/FPS
      end
    end

    def break_loop
      @loop_active = false
    end

    def end_session
      #bring back the cursor
      puts "\e[?25h"
      
      #restore stty
      `stty #{@stty_state}`
      
      #return to original terminal context
      system('tput rmcup')

      @session_active = false
      @loop_active = false
    end
    
    def debug!
      unless @debug
        @listeners << proc {|key| @screen.draw(key, width - 1, height - 1)}
        @debug = true
      end
    end
  end

  # TODO: Bitmap should accept array of strings as well as array of array of chars (length one strings)
  class Bitmap
    def self.iterate(bitmap, &block)
      y = 0
      bitmap.each do |str|
        x = 0
        str.each_char do |char|
          yield char, x, y
          x += 1
        end
        y += 1
      end
    end
  end

  class Sprite
    attr_accessor :x, :y, :bitmap

    # bitmap is an array of strings. 
    # (x,y) is the position of the first character.
    # each string represents the next line.
    # newlines in bitmap is undefined behavior.
    def initialize(x, y, bitmap)
      @x = x
      @y = y
      @bitmap = bitmap
    end

    def set_screen_dimensions(screen_width, screen_height)
      @screen_width = screen_width
      @screen_height = screen_height
    end

    def iterate(&block)
      Bitmap.iterate(@bitmap, &block)
    end
  end

  class VirtualScreen
    attr_reader :sprites, :width, :height

    def initialize(width, height)
      @width = width
      @height = height

      @sprites = []

      @draw_mutex = Mutex.new

      @screen_buffer = ScreenBuffer.new(@width, @height)
    end

    def add_sprite(sprite)
      # might want to simply give sprite a reference to screen
      sprite.set_screen_dimensions(@width, @height)
      @sprites << sprite
    end
   
    def update!
      new_buffer = ScreenBuffer.new(@width, @height)
      new_buffer.render(sprites)
      deltas = @screen_buffer.deltas(new_buffer)
      deltas.each {|d| draw(*d)}
      @screen_buffer = new_buffer
    end
   
    def draw(char, x, y)
      @draw_mutex.synchronize do
        print "\e[#{y+1};#{x+1}H#{char}"
      end
    end

    def cleanup
      @draw_mutex.unlock if @draw_mutex.locked?
      #TODO: might want to do a full clean up of screen here
    end
  end

  class ScreenBuffer
    attr_reader :buffer

    def initialize(width, height)
      @width = width
      @height = height
      # There might be a reason to use an actual noop character instead of space
      @buffer = @height.times.map { @width.times.map {" "}}
    end

    def render(sprites)
      sprites.each do |sprite|; x_pos = sprite.x; y_pos = sprite.y;
        sprite.iterate do |char, x, y|
          matrix_safe_insert(@buffer, char, x_pos + x, y_pos + y)
        end
      end
    end

    # Inserts the given char at x, y of matrix
    # Return without doing anything if x y is out of bounds
    def matrix_safe_insert(matrix, char, x, y)
      return if x < 0 || x >= matrix.first.size
      return if y < 0 || y >= matrix.size
      matrix[y][x] = char
    end

    def pretty_print
      @height.times {|y| @width.times {|x| print @buffer[y][x]}; puts nil}
    end

    # Returns the character from other_screen_buffer when a delta is found, so this is not commutative
    # Assumes other_screen_buffer is the same size as @buffer
    def deltas(other_screen_buffer)
      deltas = []
      @height.times do |y|; @width.times do |x|;
        deltas << [other_screen_buffer.buffer[y][x], x, y] if @buffer[y][x] != other_screen_buffer.buffer[y][x]
      end; end;
      deltas
    end  
  end
end
