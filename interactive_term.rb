require 'thread'
require 'io/console'

module InteractiveTerm
	class Term
		attr_reader :width, :height, :screen

		def initialize(start_session = false)
			@stty_state = @width = @height = @listener_thread = @session_active = @loop_active = nil
			@listeners = []
      @keypress_queue = Queue.new
			@height, @width = IO.console.winsize

			@screen = VirtualScreen.new(@width, @height)

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
				# process up to 5 keypresses (should be fine because happens 60 times per second)
        begin
					5.times do
						keypress = @keypress_queue.pop(true) #nonblock
						@listeners.each {|listener| listener.call(keypress)} if keypress
					end
        rescue ThreadError # nothing to pop
        end
          
        # run loop code
        yield

        # run render code
				if @screen.need_redraw?
					@screen.update!
				end
        
				sleep 1.0/60
      end
    end

    def break_loop
      @loop_active = false
    end

		def end_session
      sleep 1
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
				@listeners << proc {|key| @screen.draw(key, width, height-1)}
				@debug = true
			end
		end
	end

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

	class VirtualScreen
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
